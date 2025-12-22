local message = require("glacier.menu.message")

local Message = message.Message

---@class glacier.menu.action
local action = {}

---@enum glacier.menu.action.Item
action.item = {
    ENTER = "item::enter",
    --LEAVE = "item::leave",
    SUBMIT = "item::submit",
    OPEN_MENU = "item::open_menu",

    ---Emitted when an item's mouse_area is entered.
    ---@param item glacier.menu.Item
    ---@return glacier.menu.Message
    Enter = function(item)
        return Message.new({
            action = action.item.ENTER,
            item = item:key(),
        })
    end,

    ---Emitted when an item's should be submitted.
    ---@return glacier.menu.Message
    Submit = function()
        return Message.new({
            action = action.item.SUBMIT,
        })
    end,

    ---Emitted when an item's menu should be opened.
    OpenMenu = function()
        return Message.new({
            action = action.item.OPEN_MENU,
        })
    end,
}

---@enum glacier.menu.action.Menu
action.menu = {
    NEXT = "menu::next",
    PREV = "menu::previous",
    CLOSE_SUB = "menu::close_submenu",
    CLOSE = "menu::close",

    ---Emitted when the previous item should be selected.
    ---@return glacier.menu.Message
    Prev = function()
        return Message.new({
            action = action.menu.PREV,
        })
    end,
    ---Emitted when the next item should be selected.
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
