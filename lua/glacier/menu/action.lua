local message = require("glacier.menu.message")

local Message = message.Message

---@class glacier.menu.action
local action = {}

---@enum glacier.menu.action.Entry
action.entry = {
    ENTER = "entry::enter",
    --LEAVE = "entry::leave",
    SUBMIT = "entry::submit",
    OPEN_MENU = "entry::open_menu",

    ---Emitted when an entry's mouse_area is entered.
    ---@param entry glacier.menu.Entry
    ---@return glacier.menu.Message
    Enter = function(entry)
        return Message.new({
            action = action.entry.ENTER,
            entry = entry:key(),
        })
    end,

    ---Emitted when an entry's should be submitted.
    ---@return glacier.menu.Message
    Submit = function()
        return Message.new({
            action = action.entry.SUBMIT,
        })
    end,

    ---Emitted when an entry's menu should be opened.
    OpenMenu = function()
        return Message.new({
            action = action.entry.OPEN_MENU,
        })
    end,
}

---@enum glacier.menu.action.Menu
action.menu = {
    NEXT = "menu::next",
    PREV = "menu::previous",
    CLOSE_SUB = "menu::close_submenu",
    CLOSE = "menu::close",

    ---Emitted when the previous entry should be selected.
    ---@return glacier.menu.Message
    Prev = function()
        return Message.new({
            action = action.menu.PREV,
        })
    end,
    ---Emitted when the next entry should be selected.
    ---@return glacier.menu.Message
    Next = function()
        return Message.new({
            action = action.menu.NEXT,
        })
    end,
    ---Emitted when the submenu should be closed.
    CloseSub = function()
        return Message.new({
            action = action.menu.CLOSE_SUB,
        })
    end,
    ---Emitted when the menu should be closed.
    ---@return glacier.menu.Message
    Close = function()
        return Message.new({
            action = action.menu.CLOSE,
        })
    end,
}

return action
