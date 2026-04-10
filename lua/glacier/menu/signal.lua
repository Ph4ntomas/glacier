---@enum glacier.menu.signal
---Signal set used by `Menu` and their child entries/submenu.
local signal = {
    ---Request the parent menu to close its Submenu.
    ---
    ---This signal has no payload
    REQUEST_SUBMENU_CLOSE = "glacier::menu::signal::request_submenu_close",
}

return signal
