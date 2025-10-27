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

## Features

For now, these features are only implemented in lua due to the shorter design/dev/fix loop. I have
a few more features I want to implement before porting everything to Rust, as well as some changes
I want to send to Pinnacle which will heavily impact the library, so I may delay porting to rust
until then.

- A Bar to host widget
- A timer api for easy asynchronous operation
- Customizable widgets recipe
- Signals
- An input grabbing API
- Modal behavior
- Other goodies

## Feature Requests, Bug Reports, Contributions & Questions
Feedback is more than welcome.
I'm open to contributions, but I feel it might be a bit too soon for that. In any case, I usually
roam on Pinnacle's discord/matrix, so feel free ask away.
