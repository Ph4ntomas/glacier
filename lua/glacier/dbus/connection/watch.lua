local ldbus = require("ldbus")

---Short lived object to poll a `Watch`.
---
---`PollableWatch` implements the cqueues polling convention.
---
---@package
---@class glacier.dbus.connection.PollableWatch
---@field fd integer
---@field flags integer
---@field impl ldbus.DBusWatch
local PollableWatch = {}
PollableWatch.__index = PollableWatch
PollableWatch.__name = "dbus.connection.PollableWatch"

---@package
---Initialize a new `PollableWatch`
---
---@param fd integer File descriptor to watch
---@param flags integer Which direction to watch.
---@param impl ldbus.DBusWatch
---
---@return glacier.dbus.connection.PollableWatch
local function PollableWatch_new(fd, flags, impl)
    local has_flags = (flags & ldbus.watch.READABLE) | (flags & ldbus.watch.WRITABLE)
    assert(has_flags ~= 0, "PollableWatch must have something to poll")

    return setmetatable({
        fd = assert(fd, "PollableWatch should have a filedescriptor"),
        flags = flags,
        impl = assert(impl),
    }, PollableWatch)
end

---Returns the file descriptor associated with this `PollableWatch`.
---
---@return integer
function PollableWatch:pollfd()
    return self.fd
end

---Returns "PollableWatch".
---
---@return string
function PollableWatch:type()
    return "PollableWatch"
end

---Call this `ldbus.Watch` handler..
---
---@return boolean # Return `false` if there wasn't enough memory.
function PollableWatch:handle()
    return self.impl:handle(self.flags)
end

---Returns a string composed of r, w or rw, based on which events should be monitored.
---
---@return string? # "r", "w" or "rw" depending on which event should be monitored.
function PollableWatch:events()
    local read = ldbus.watch.READABLE & self.flags ~= 0
    local write = ldbus.watch.WRITABLE & self.flags ~= 0

    local events = nil

    if read then
        events = "r"
    end

    if write then
        events = (events or "") .. "w"
    end

    return events
end

---@return nil
function PollableWatch:timeout()
    return nil
end

---Wrapper around `ldbus.DBusWatch`.
---
---@class glacier.dbus.connection.Watch
---@field inner ldbus.DBusWatch
---@field enable boolean
local Watch = {}
Watch.__index = Watch
Watch.__name = "dbus.connection.Watch"

---Wrap a `ldbus.DBusWatch` into a pollable `glacier.dbus.Watch`
---
---@param watch ldbus.DBusWatch
---@return glacier.dbus.connection.Watch
local function Watch_new(watch)
    local ret = {
        inner = watch,
        enable = watch:get_enabled(),
    }

    setmetatable(ret, Watch)

    return ret
end

---Function called when the `enabled` value for the inner DBusWatch changed.
function Watch:enable_changed()
    self.enable = self.inner:get_enabled()
end

---Checks if the `Watch` is currently enabled.
---
---@return boolean # True if this Watch is enabled.
function Watch:enabled()
    return self.enable
end

---Create a pollable object from this watch.
---
---@return glacier.dbus.connection.PollableWatch? # A PollableWatch, or nil if this watch is disabled.
function Watch:pollable()
    local flags = self.inner:get_flags()
    local fd = self:get_fd()

    if not self.enable or flags == 0 or not fd then
        return nil
    end

    return PollableWatch_new(fd, flags, self.inner)
end

---Returns a pollable file descriptor.
---
---@return integer?
function Watch:get_fd()
    return self.inner:get_unix_fd() or self.inner:get_socket()
end

---@class glacier.dbus.connection.watch
local watch = {
    Watch = Watch,
    PollableWatch = PollableWatch,
}

---Create a `Watch` to monitor a connection.
---
---@param watch ldbus.DBusWatch # A ldbus `DBusWatch`.
---
---@return glacier.dbus.connection.Watch
function watch.from_ldbus(watch) ---@diagnostic disable-line:redefined-local
    return Watch_new(watch)
end

return watch
