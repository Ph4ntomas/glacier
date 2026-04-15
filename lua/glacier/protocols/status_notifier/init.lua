local host = require("glacier.protocols.status_notifier.host")

---@class glacier.protocols.status_notifier
local status_notifier = {
    dbusmenu = require("glacier.protocols.status_notifier.dbusmenu"),
    item = require("glacier.protocols.status_notifier.item"),
    watcher = require("glacier.protocols.status_notifier.watcher"),
    host = host,
    Host = host.Host,
}

return status_notifier
