# Glacier's Design

This document aims to regroup some of Glacier's design choices both from the
existing implementation and some planned feature. Since the library is
implemented in two vastly different language, there might be some differences in
the actual implementation, but the documentation should gives the reader a broad
understanding of how various part are meant to interact and explains some of the
implementation choices.

While reading this, keep in mind that Glacier is very young, and inherently
unstable. As such, this document may fall out of date, and the architecture may
need to change to adapt to Snowcap's internals changing.

## Acknowledgements

Glacier is based on top of Snowcap, a Widget system built for [Pinnacle]
compositor, without which nothing in this document would exists.

While the implementation was made from scratch, Glacier's is heavily inspired by
the following projects:
- [AwesomeWM](https://awesomewm.org/) - A X11 Window Manager
- [lain](https://github.com/lcpz/lain) - A widget library for Awesome
- [modalawesome](https://github.com/potamides/modalawesome) - A library
  implementing modal (VI-like) behavior for awesome.
- [zbus](https://docs.rs/zbus/latest/zbus/) - A DBus library, written in Rust.

## Surfaces, Bar & Widgets

Snowcap exposes an API to create Wayland surfaces implementing the
wlr-layer-shell protocol, along with widgets to control the rendering. The user
is expected to implement a Program, composed of a view and an update function.
The view function return a tree of Snowcaps Widgets describing what should be
rendered, and the update function receive message defined in the view, and is
tasked with updating the program internal state.

Glacier's build upon this to provides standardized Surfaces capable of working
with pre-made Widgets, while conserving the ability for users to easily
customize how things are rendered.

### Widget

Contrary to Snowcap's, Glacier's widgets are self contained and act as
mini-program with a view and update function. While there's nothing wrong with
Snowcap's implementation (and the underlying iced framework), users need to
write an update function purpose-built for the specific use-case. Glacier's
design allow for a better separation of concern. Surfaces handle how the Widgets
are position relative to each-others, while widgets are specialized and add
their own functionality to the surface.

#### Standard Widgets

Glaciers provides a few pre-made widgets, which all follow the same design
principles. Their update function is private, and focus on a single behavior.
Their view function is private as well, but provide extension points, usually in
the form of a callback to override the default rendering and allow the user to
implement the look & feel they want for their config.

All widget implements the same interface, provided here in (rust inspired)
pseudo-code:

```rust
trait Widget {
    fn view() -> Option<WidgetDef>;
    fn update(message, parent);
}
```

The `view` function may return a tree of Snowcap's widgets. If that's the case,
the parent surface view function will show the widget, otherwise, the widget is
hidden.

The `update` function receive a message forwarded by its parent surface, and a
handle to the parent surface.</br>
At the time of writing this, any unknown message are forwarded to all widget,
and the widgets are expected to ignore the ones not meant to them. This may
changes in the future, but it allows some amount of nesting (the parent widget
can forward the message to its child widgets, without knowing what they
expect).</br>
The second parameter is an object allowing access to the remote surface handle
that can be used to create surface necessitating a parent surface (e.g.
Popups/Menu).

As an example of how the customization points works, here is how the TagList is
currently implemented.

The TagList is composed of two parts:
- Tag:
  Small widgets-like objects handling on-click events to changes which tags are
  active, and (by default) displaying the tag label in a textbox whose
  background depend on the tag status.
- TagList:
  Display a list of Tag, and handle scroll events to shift active Tags.

To support the behavior, both TagList view and TagView must contains
`mousearea`s widget. The user can however override the content of said
`mousearea`s using the following functions:

```rust
type TagViewCallback = Fn(&Tag, TagStyle) -> Option<WidgetDef>;
type ListViewCallback = Fn(Vec<WidgetDef<Msg>>, Style) -> Option<WidgetDef>;

impl TagList {
    pub fn default_tag_view(tag, style) -> Option<WidgetDef>;
    pub fn default_list_view(list, style) -> Option<WidgetDef>;
}
```

When `TagList::view` is called, it will call the user callback or fallback to
`default_tag_view`. The result from this function, if available, will then be
wrapped inside a `mousearea` which will be used to receive mouse-event signals.
The list of `mousearea`-wrapped views is then passed to the list rendering
callback and its result is wrapped in another `mousearea` for the scroll events.

NOTE: TagList's current implementation doesn't depends on ext-workspace, and
must have a way to trigger a re-render of its parent surface if some external
events changes the Tags state. This is done using a `Signal` all Surfaces are
expected to listen to (in this case it just sends a "Redraw Needed" signal).
This is a good example of what signal are used for (in this case, to react to
external changes that would not have triggered a redraw otherwise).

### Surface

A `Surface` is an object implementing the `WidgetProgram` interface from
Snowcap, holding a handle on the server-side Snowcap Surface (e.g. Layer,
Popups, ...) as well as a collection of Widgets. When the view function is
called, the surface will forward this call to its widgets, then use the
resulting collection of `WidgetDef` in it's own rendering logic.

When the update function is called, the surface will do the following:
- If the message is empty or aimed at the surface itself, the update function
  performs the required action and return
- If the message is unknown, it is forwarded to every widgets the surface holds.

A surface should also register itself to listen to its widgets signals (at least
the standard ones). The rational behind using signals here is that it allows
widgets to interact with their parent surface without holding a (potentially
weak) handle to it, which limit what a widget can do to its parent surface.

NOTE: There's currently only one Surface type, the Bar. For this reason, most of
the code isn't generic over the concept of Surface, but that's a planned
feature.

#### Bar

The Bar is implemented using a Layer surface, and holds three collections of
widget with the central one filling the available space. As with widgets, each
section has its own callback to override the bar's look & feel, which are then
place inside a `Row` (or `Column`, once that gets implemented).

It listen to the following signals:
- Redraw Request: When received, the bar will trigger a self-refresh by sending
  an empty message to the remote Layer's surface.
- Focus(id): When received, the bar will request keyboard focus by updating it's
  Layer's KeyboardExclusivity. It will then request a specific widget to be
  focused.
- Unfocus: When received, the bar will drop its KeyboardExclusivity, and request
  for any focused widget to lose focus.
- Message(msg): When received, `msg` is forwarded to the `Layer`. This can be
  used by widgets to trigger a self-update followed by a new render, as a
  response to an external trigger. An example of this is for a widget to update
  some state when it's popup's is closed.

## Signals

Signals are meant to propagate some events. The feature is based around a signal
`Emitter` which hold a collection of callbacks. When a signal is emitted, all
callbacks tied to it will be called synchronously in the order in which they
were registered.

Callbacks can be registered at any point. Registering a callback return an
handle that can be used to un-register it later one. Callbacks can also return
their own retention policy, which can be used in case calling the callback again
could cause error, or would not work (e.g. a weak resource is pointing to dead
data, or the callback was called on a close event.)

## Menu

TODO.

## Interfacing with DBus

TODO.

[Pinnacle]: https://github.com/pinnacle-comp
