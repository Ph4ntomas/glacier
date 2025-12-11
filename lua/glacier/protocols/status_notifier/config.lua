---@class glacier.status_notifier.config
local config = {
    protocol_version = 0,
    ---@class glacier.status_notifier.config.watcher
    watcher = {
        ---Service Name
        service = "org.kde.StatusNotifierWatcher",
        ---Path to the Watcher object
        object = "/StatusNotifierWatcher",
        ---SNI Watcher interface
        interface = "org.kde.StatusNotifierWatcher",
    },
    items = {
        ---Path to the Item object.
        object = "/StatusNotifierItem",
        ---SNI Item interface.
        interface = "org.kde.StatusNotifierItem",
    },
    dbusmenu = {
        interface = "com.canonical.dbusmenu",
    },
}

return config
