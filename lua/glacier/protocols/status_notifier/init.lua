---@class glacier.status_notifier
local status_notifier = {
    ItemProxy = require("glacier.protocols.status_notifier.item_proxy"),
    Watcher = require("glacier.protocols.status_notifier.watcher"),
    WatcherProxy = require("glacier.protocols.status_notifier.watcher_proxy"),
}

return status_notifier
