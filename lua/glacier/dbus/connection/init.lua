local cqueues = require("cqueues") --[[@as cqueues]]
local condvar = require("cqueues.condition") --[[@as cqueues.conditionlib]]
local ldbus = require("ldbus") --[[@as ldbus]]

local types = require("glacier.dbus.type")
local messages = require("glacier.dbus.message")

local _errors = require("glacier.dbus.errors")
local _watch = require("glacier.dbus.connection.watch")
local _timeout = require("glacier.dbus.connection.timeout")
local _pending = require("glacier.dbus.connection.pending_call")

---@alias glacier.dbus.connection.Filter fun(con: glacier.dbus.Connection, msg: glacier.dbus.Message):boolean?
---@alias glacier.dbus.connection.MatchHandler fun(con: glacier.dbus.Connection, msg: glacier.dbus.Message):boolean

---@class glacier.dbus.connection.Matcher
---@field rule glacier.dbus.MatchRule
---@field handler glacier.dbus.connection.MatchHandler
local Matcher = {}
Matcher.__index = Matcher
Matcher.__name = "dbus.connection.Matcher"

---@param rule glacier.dbus.MatchRule
---@param handler glacier.dbus.connection.MatchHandler
---
---@return glacier.dbus.connection.Matcher
local function Matcher_new(rule, handler)
    assert(type(handler) == "function", "Expected function, got:" .. type(handler))

    return setmetatable({
        rule = rule,
        handler = handler,
    }, Matcher)
end

---@param handler glacier.dbus.connection.MatchHandler
---@return glacier.dbus.connection.MatchHandler
function Matcher:set_handler(handler)
    local prev = self.handler

    self.handler = handler

    return prev
end

---@param msg glacier.dbus.Message
function Matcher:match(msg)
    return self.rule:match(msg)
end

---@class glacier.dbus.WeakConnection
---@field _connection glacier.dbus.Connection
local WeakConnection = {}
WeakConnection.__index = WeakConnection
WeakConnection.__name = "glacier.dbus.WeakConnection"
WeakConnection.__mode = "v"

function WeakConnection.new(connection)
    return setmetatable({
        _connection = connection,
    }, WeakConnection)
end

function WeakConnection:upgrade()
    return self._connection
end

---@class glacier.dbus.Connection
---@field _names string[]
---@field watches glacier.dbus.connection.Watch[]
---@field timeouts glacier.dbus.connection.Timeout[]
---@field matchers table<string, glacier.dbus.connection.Matcher[]>
---@field filters glacier.dbus.connection.Filter[]
---@field wakeup_cv cqueues.condition
---@field _stopping boolean
---@field inner ldbus.DBusConnection
local Connection = {}
Connection.__index = Connection
Connection.__name = "dbus.Connection"

---@param inner ldbus.DBusConnection
---@param filters glacier.dbus.connection.Filter[]
local function Connection_new(inner, filters)
    local ret = {
        _names = {},
        watches = {},
        timeouts = {},
        matchers = {},
        filters = filters or {},
        wakeup_cv = condvar.new(),
        _stopping = false,
        inner = inner,
    }

    local weak = WeakConnection.new(ret)

    ret = setmetatable(ret, Connection)

    ret.inner:set_watch_functions(function(watch)
        local c = weak:upgrade()
        if c then
            c:_add_watch(watch)
        end
    end, function(watch)
        local c = weak:upgrade()
        if c then
            c:_remove_watch(watch)
        end
    end, function(watch)
        local c = weak:upgrade()
        if c then
            c:_toggle_watch(watch)
        end
    end)

    ret.inner:set_timeout_functions(function(timeout)
        local c = weak:upgrade()
        if c then
            c:_add_timeout(timeout)
        end
    end, function(timeout)
        local c = weak:upgrade()
        if c then
            c:_remove_timeout(timeout)
        end
    end, function(timeout)
        local c = weak:upgrade()
        if c then
            c:_toggle_timeout(timeout)
        end
    end)

    ret.inner:set_wakeup_main_function(function()
        local c = weak:upgrade()
        if c then
            c:_wakeup()
        end
    end)

    ret.inner:register_fallback("/", function(message)
        local c = weak:upgrade()
        if c then
            return c:_fallback_message_handler(message)
        end
    end)

    return ret
end

local nil_fun = function() end
function Connection:__gc()
    self.inner:unregister_object_path("/")

    self.inner:set_wakeup_main_function(nil_fun)
    self.inner:set_timeout_functions(nil_fun, nil_fun, nil_fun)
    self.inner:set_watch_functions(nil_fun, nil_fun, nil_fun)

    for _, w in pairs(self.watches) do
        cqueues.cancel(w:get_fd())
    end

    for k, _ in pairs(self.matchers) do
        ldbus.bus.remove_match(self.inner, k)
    end
    self.matchers = nil

    for _, name in ipairs(self._names) do
        ldbus.bus.release_name(self.inner, name)
    end
    self._names = nil

    self.inner = nil
end

---Close the connection and stop handling messages.
function Connection:shutdown()
    self._stopping = true
    self.wakeup_cv:signal()
end

--TODO: Implement a more graceful shutdown.

---Check if this connection is being closed.
function Connection:stopping()
    return self._stopping
end

function Connection:_wakeup()
    self.wakeup_cv:signal()
end

---@param message ldbus.DBusMessage
function Connection:_fallback_message_handler(message)
    local ok = true
    ok, message = pcall(messages.from_ldbus, message) ---@diagnostic disable-line: cast-local-type

    if not ok then
        warn("Failed to deserialize message: ", tostring(message))
        return
    end

    for _, v in ipairs(self.filters) do
        if v(self, message) then
            return true
        end
    end

    local matched = nil
    for _, matchers in pairs(self.matchers) do
        for _, matcher in ipairs(matchers) do
            if matcher:match(message) then
                if matcher.handler(self, message) then
                    matched = true
                end
            end
        end
    end

    return matched
end

---@package
---Add a new `ldbus.DBusWatch` to this `Connection`.
---
---@param watch ldbus.DBusWatch
function Connection:_add_watch(watch)
    self.watches[watch] = _watch.from_ldbus(watch)
end

---@package
---Remove a `ldbus.DBusWatch` from this `Connection`.
---
---@param watch ldbus.DBusWatch
function Connection:_remove_watch(watch)
    self.watches[watch] = nil
end

---@package
---Toggle the enable state of a given `ldbus.DBusWatch`
---
---@param watch ldbus.DBusWatch
function Connection:_toggle_watch(watch)
    self.watches[watch]:enable_changed()
end

---@package
---Add a new `ldbus.DNusTimeout` to this `Connection`.
---
---@param timeout ldbus.DBusTimeout
function Connection:_add_timeout(timeout)
    self.timeouts[timeout] = _timeout.from_ldbus(timeout)
end

---@package
---Remove a `ldbus.DBusTimeout` from this `Connection`.
---
---@param timeout ldbus.DBusTimeout
function Connection:_remove_timeout(timeout)
    self.timeouts[timeout] = nil
end

---@package
---Toggle the enable state of a givern`ldbus.DBusTimeout`.
---
---@param timeout ldbus.DBusTimeout
function Connection:_toggle_timeout(timeout)
    self.timeouts[timeout]:enable_changed()
end

---@param match_rule glacier.dbus.MatchRule
---@param handler glacier.dbus.connection.MatchHandler
---
---@return glacier.dbus.connection.Matcher
function Connection:add_matcher(match_rule, handler)
    local str = match_rule:str()

    local new_matcher = Matcher_new(match_rule, handler)

    if not self.matchers[str] then
        assert(ldbus.bus.add_match(self.inner, str))
        self.matchers[str] = {}
    end

    table.insert(self.matchers[str], new_matcher)

    return new_matcher
end

---@param matcher glacier.dbus.connection.Matcher
function Connection:remove_matcher(matcher)
    local str = matcher.rule:str()
    local matchers = self.matchers[str]

    if matchers then
        local at
        for k, v in ipairs(matchers) do
            if rawequal(v, matcher) then
                at = k
                break
            end
        end

        if at then
            table.remove(matchers, at)
        end

        if #matchers == 0 then
            self.matchers[str] = nil
            ldbus.bus.remove_match(self.inner, str)
        end
    end
end

---Broadcast a signal.
---
---@param path string|glacier.dbus.type.ObjectPath
---@param interface string|glacier.dbus.type.InterfaceName
---@param member string|glacier.dbus.type.MemberName
---@param body? glacier.dbus.type.Struct
function Connection:broadcast_signal(path, interface, member, body)
    self:emit_signal(nil, path, interface, member, body)
end

---Emit a signal.
---
---If `destination` is set, the message will be a unicast message. Otherwise, it's broadcast by the bus.
---
---@param destination string|glacier.dbus.type.BusName|nil # If set send the message to this destination only.
---@param path string|glacier.dbus.type.ObjectPath
---@param interface string|glacier.dbus.type.InterfaceName
---@param member string|glacier.dbus.type.MemberName
---@param body? glacier.dbus.type.Struct
function Connection:emit_signal(destination, path, interface, member, body)
    local msg = messages.signal(path, interface, member, body)

    msg:set_sender(self:unique_name())
    msg:set_destination(destination)
    msg.body = body

    self:send(msg)
end

---Send a method call.
---
---@param destination string|glacier.dbus.type.BusName|nil
---@param path string|glacier.dbus.type.ObjectPath
---@param interface string|glacier.dbus.type.InterfaceName|nil
---@param member string|glacier.dbus.type.MemberName
---@param body? glacier.dbus.type.Struct
---
---@return glacier.dbus.connection.PendingCall
function Connection:call_method(destination, path, interface, member, body)
    local msg = messages.method_call(destination, path, interface, member, body)

    msg:set_sender(self:unique_name())
    msg.body = body

    local pending = self.inner:send_with_reply(msg:to_ldbus())

    return _pending.from_ldbus(pending)
end

---Send a method call with the given flags
---
---@param destination glacier.dbus.type.BusName|nil
---@param path glacier.dbus.type.ObjectPath
---@param interface glacier.dbus.type.InterfaceName|nil
---@param member glacier.dbus.type.MemberName
---@param flags? glacier.dbus.message.Flags
---@param body? glacier.dbus.type.Struct
---
---@return glacier.dbus.connection.PendingCall?
function Connection:_call_method_with_flags(destination, path, interface, member, flags, body)
    local msg = messages.method_call(destination, path, interface, member)

    msg:set_sender(self:unique_name())

    if flags then
        msg:set_no_reply(flags.no_reply)
        msg:set_no_autostart(flags.no_autostart)
    end

    msg.body = body

    if msg:no_reply() then
        self.inner:send(msg:to_ldbus())
        return nil
    else
        return _pending.from_ldbus(self.inner:send_with_reply(msg:to_ldbus()))
    end
end

---Send a Message.
---
---@param message glacier.dbus.Message
function Connection:send(message)
    local ldbus_msg = message:to_ldbus()

    self.inner:send(ldbus_msg)
end

---Returns this `Connection` unique name, if set.
---
---@return glacier.dbus.type.UniqueName?
function Connection:unique_name()
    local name = ldbus.bus.get_unique_name(self.inner)

    return types.unique_name.try_from_str(name)
end

---@class (exact) glacier.dbus.connection.RequestNameFlags
---@field allow_replacement? boolean # Another requestor can take the name away with `replace_existing`
---@field do_not_queue? boolean # If the name is already taken, do not place caller in a queue to get it.
---@field replace_existing? boolean # If the name has an owner, and replacement is allowed, replace it.
---
---TODO: Make this into a integer enum with bit-or ?

---@enum glacier.dbus.connection.RequestNameResponse
local RequestNameReply = {
    primary_owner = 1,
    in_queue = 2,
    exists = 3,
    already_owner = 4,
}

---@enum glacier.dbus.connection.ReleaseNameResponse
local ReleaseNameReply = {
    released = 1,
    non_existent = 2,
    non_owner = 3,
}

---Request a well-known name for this connection.
---
---@param name string|glacier.dbus.type.WellKnownName
---@param flags? glacier.dbus.connection.RequestNameFlags
---@return glacier.dbus.connection.RequestNameResponse
function Connection:request_name(name, flags)
    if type(name) == "string" then
        name = types.well_known_name.from_str(name)
    end

    local ret = assert(
        ldbus.bus.request_name(self.inner, name:str(), flags --[[@as ldbus.bus.RequestNameFlags?]])
    )

    --- TODO: change this to get the name status.
    if ret == "primary_owner" or ret == "in_queue" then
        table.insert(self._names, name:str())
    end

    return RequestNameReply[ret]
end

---Release a well-known name for this connection.
---
---@param name string|glacier.dbus.type.WellKnownName
function Connection:release_name(name)
    if type(name) == "string" then
        name = types.well_known_name.from_str(name)
    end

    local str = name:str()
    local ret = assert(ldbus.bus.release_name(self.inner, str))

    if ret == "released" then
        local at
        for k, n in ipairs(self._names) do
            if str == n then
                at = k
            end
        end

        if at then
            table.remove(self._names)
        end
    end

    return ReleaseNameReply[ret]
end

---Set the message_handler for unhandled messages.
---
---@param handler fun(self:glacier.dbus.Connection, message:glacier.dbus.Message)
function Connection:message_handler(handler)
    self.on_unhandled = handler
end

---Dispatch all pending data & complete message in the incoming queue.
function Connection:dispatch_all()
    local status = self.inner:get_dispatch_status()

    while status == "data_remains" do
        status = self.inner:dispatch()
    end
end

---Poll all Pollable objects, calling their handle function when ready.
function Connection:poll()
    local pollable = {}

    for _, w in pairs(self.watches) do
        if w:enabled() then
            table.insert(pollable, w:pollable())
        end
    end

    for _, timeout in pairs(self.timeouts) do
        if timeout:enabled() then
            table.insert(pollable, timeout)
        end
    end

    table.insert(pollable, self.wakeup_cv)

    local ready = { assert(cqueues.poll(table.unpack(pollable))) }
    if ready[#ready] == self.wakeup_cv then
        table.remove(ready)
    end

    for _, r in ipairs(ready) do
        local ret = r:handle()

        if ret == false and r:type() == "PollableWatch" then
            warn("A Watch is lacking memory: ", tostring(r.impl))
            ---TODO: Use a callback to increase memory ?
        end
    end
end

---Run the `Connection` event loop once.
---
---The `Connection` event loop consist of dispatching any pending message and data,
---polling every sockets and timeout, and handling any action that should be taken.
function Connection:step()
    ---Usually, this will do nothing. On the first call, it flushes the connection if needed.
    self:dispatch_all()

    self:poll()
    self:dispatch_all()
end

---@class glacier.dbus.ConnectionBuilder
---@field type string
--@field connection ldbus.DBusConnection
---@field names glacier.dbus.type.WellKnownName[]
---@field name_flags glacier.dbus.connection.RequestNameFlags
---@field filters glacier.dbus.connection.Filter[]
local ConnectionBuilder = {}
ConnectionBuilder.__index = ConnectionBuilder
ConnectionBuilder.__name = "dbus.connection.Builder"

---@param type string
local function ConnectionBuilder_new(type)
    local ret = {
        type = type,
        names = {},
        name_flags = {
            allow_replacement = false,
            replace_existing = false,
            do_not_queue = false,
        },
        filters = {},
    }

    return setmetatable(ret, ConnectionBuilder)
end

---Add a well known name to request when building the `Connection`
---
---@param name string
---@return glacier.dbus.ConnectionBuilder? # `nil` if name isn't a valid well-known name.
---@return string? # Return the error string on error.
function ConnectionBuilder:with_name(name)
    local wellknown, err = types.well_known_name.try_from_str(name)

    if not name then
        return nil, err
    end

    table.insert(self.names, wellknown)

    return self
end

---@param allow boolean
function ConnectionBuilder:allow_name_replacement(allow)
    self.name_flags.allow_replacement = allow
end

---@param replace boolean
function ConnectionBuilder:replace_existing_name(replace)
    self.name_flags.replace_existing = replace
end

---@param f glacier.dbus.connection.Filter
---@return glacier.dbus.ConnectionBuilder?
---@return string?
function ConnectionBuilder:add_filter(f)
    if type(f) == "function" then
        table.insert(self.filters, f)
    else
        return nil, _errors.type.Invalid
    end

    return self
end

---Build a new `Connection`
---
---@return glacier.dbus.Connection?
---@return string?
function ConnectionBuilder:build()
    local conn, err = ldbus.bus.get_private(self.type)

    if not conn then
        return nil, err
    end

    local ret = Connection_new(conn, self.filters)

    for _, name in ipairs(self.names) do
        ret:request_name(name, self.name_flags)
    end

    return ret
end

---@class glacier.dbus.connection
local connection = {
    RequestNameReply = RequestNameReply,
    ReleaseNameReply = ReleaseNameReply,
    Connection = Connection,
    WeakConnection = WeakConnection,
    watch = _watch,
    timeout = _timeout,
}

function connection.system()
    return ConnectionBuilder_new("system")
end

function connection.session()
    return ConnectionBuilder_new("session")
end

return connection
