# Glacier

## About
Glacier is a companion library for [Pinnacle](https://github.com/pinnacle-comp/pinnacle) Wayland
compositor.

It's somewhat similar to what `vain` and `lain` were for AwesomeWM. A companion lib with stuff I
personally use and I'm willing to maintain.

## Warning
For the time being, Glacier is a playground for my own experimentation. I uses it for my own config
and to test new (sometime unmerged) pinnacle features. Some of these may or may not land in
Pinnacle in which case I'll remove them from Glacier (or build a thin wrapper when it make sense).

No effort is currently made to maintain a stable API. I'm targeting Pinnacle's main branch with my
own PR on top. Since these PR are inherently unstable until merged, it wouldn't make any sense to
try to have a stable API.

The DBus wrapper for lua is working, but is highly experimental. It also depends on ldbus, whose 
rockspec cannot be installed normally. See https://github.com/daurnimator/ldbus for more information.

## Features

- A Bar to host widget
- A timer api for easy asynchronous operation
- Customizable widgets recipe
- Signals
- An input grabbing API
- Modal behavior
- A zbus inspired dbus library for lua integrated within cqueues.
- StatusNotifierItem implementation.
- Menus
- Other goodies

## License exception

Glacier's code is licensed under GPLv3 (see LICENSE file). An exception is granted to
[Pinnacle](https://github.com/pinnacle-comp/pinnacle) and Snowcap copyright owners to re-use part of
the code and re-license it under the terms MPLv2.0 for the purpose of upstreaming features.

## Feature Requests, Bug Reports, Contributions & Questions
Feedback is more than welcome.
I'm open to contributions, but I feel it might be a bit too soon for that. In any case, I usually
roam on Pinnacle's discord/matrix, so feel free ask away.

<h3>By contributing to Glacier, you acknowledge that you have rights to the code you provide, and you
agree to license your work under the GNU General Public License v3.0, as well as the exception
granted to Pinnacle and Snowcap copyright owners.</h3>
