package = "glacier"
version = "0.0.1-1"
source = {
    url = "git+https://git.sr.ht/~phantomas/glacier",
    dir = "glacier/lua",
}
description = {
    homepage = "https://git.sr.ht/~phantomas/glacier",
    license = "GPL-3.0-or-later"
}
dependencies = {
    "lua >= 5.2",
    "cqueues ~> 20200726",
    "pinnacle-api",
}
build = {
    type = "builtin",
    modules = {
        glacier = "glacier/init.lua",
        ["glacier.bar"] = "glacier/bar/init.lua",
        ["glacier.bar.child"] = "glacier/bar/child.lua",

        ["glacier.internals.event_loop"] = "glacier/internals/event_loop.lua",

        ["glacier.keygrabber"] = "glacier/keygrabber/init.lua",

        ["glacier.misc.color"] = "glacier/misc/color.lua",
        ["glacier.misc.image"] = "glacier/misc/image.lua",
        ["glacier.misc.separators"] = "glacier/misc/separators.lua",

        ["glacier.modal"] = "glacier/modal/init.lua",

        ["glacier.signal"] = "glacier/signal/init.lua",
        ["glacier.signal.signal_table"] = "glacier/signal/signal_table.lua",

        ["glacier.utils"] = "glacier/utils/init.lua",
        ["glacier.utils.timer"] = "glacier/utils/timer.lua",

        ["glacier.widget"] = "glacier/widget/init.lua",
        ["glacier.widget.base"] = "glacier/widget/base.lua",
        ["glacier.widget.clock"] = "glacier/widget/clock.lua",
        ["glacier.widget.operation"] = "glacier/widget/operation.lua",
        ["glacier.widget.prompt"] = "glacier/widget/prompt.lua",
        ["glacier.widget.signal"] = "glacier/widget/signal.lua",
        ["glacier.widget.taglist"] = "glacier/widget/taglist.lua",
        ["glacier.widget.textbox"] = "glacier/widget/textbox.lua",

        --- Meta files for luaLS
        ["glacier.meta.cqueues"] = "glacier/meta/cqueues.lua",
        ["glacier.meta.cqueues.condition"] = "glacier/meta/cqueues.condition.lua",
        ["glacier.meta.cqueues.promise"] = "glacier/meta/cqueues.promise.lua",
    }
}
