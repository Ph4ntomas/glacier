local ldbus = require("ldbus") --[[@as ldbus]]
local errors = require("glacier.dbus.errors")
local types = require("glacier.dbus.type")

---@class glacier.dbus.message
local message = {}

---@class glacier.dbus.message.Header
---@field type glacier.dbus.type.MessageType
---@field no_autostart boolean
---@field no_reply boolean
---@field serial? integer
---@field path? glacier.dbus.type.ObjectPath
---@field interface? glacier.dbus.type.InterfaceName
---@field member? glacier.dbus.type.MemberName
---@field error_name? glacier.dbus.type.InterfaceName
---@field reply_serial? integer
---@field destination? glacier.dbus.type.BusName
---@field sender? glacier.dbus.type.UniqueName
---@field signature? glacier.dbus.type.Signature
--unix fds
local MessageHeader = {}
MessageHeader.__name = "dbus.message.Header"
MessageHeader.__index = MessageHeader

---@param h? glacier.dbus.message.Header
---@return glacier.dbus.message.Header
function MessageHeader:new(h)
    h = h or {}

    h.no_autostart = h.no_autostart or false
    h.no_reply = h.no_reply or false

    return setmetatable(h, self)
end

local function _assert_signal_fields(header)
    assert(header.path)
    assert(header.interface)
    assert(header.member)
end

local function _assert_method_call_fields(header)
    assert(header.path)
    assert(header.member)
end

local function _assert_method_return_fields(header)
    assert(header.reply_serial ~= 0)
end

local function _assert_error_fields(header)
    assert(header.reply_serial ~= 0)
    assert(header.error_name)
end

local _mandatory_field_assert = {
    method_call = _assert_method_call_fields,
    method_return = _assert_method_return_fields,
    signal = _assert_signal_fields,
    error = _assert_error_fields,
}

---Convert a `MessageHeader` to a `ldbus.DBusMessage`.
---
---@return ldbus.DBusMessage
function MessageHeader:to_ldbus()
    local type = assert(self.type:str())
    _mandatory_field_assert[type](self)

    local msg = ldbus.message.new(self.type:str())

    ---@diagnostic disable-next-line: param-type-mismatch
    msg:set_no_reply(self.no_reply) -- TODO: add a field to the header for method call ?
    msg:set_auto_start(not self.no_autostart)

    local path = self.path and self.path:get()
    msg:set_path(path)

    local interface = self.interface and self.interface:str()
    msg:set_interface(interface)

    local member = self.member and self.member:str()
    msg:set_member(member)

    if self.error_name then
        msg:set_error_name(self.error_name:str())
    end

    if self.reply_serial then
        msg:set_reply_serial(self.reply_serial)
    end

    local destination = self.destination and self.destination:str()
    msg:set_destination(destination)

    local sender = self.sender and self.sender:str()
    msg:set_sender(sender)

    return msg
end

---@class glacier.dbus.message.header
local header = {}

---@param msg ldbus.DBusMessage
function header.from_ldbus(msg)
    local type = msg:get_type()
    local path = msg:get_path()
    local interface = msg:get_interface()
    local member = msg:get_member()
    local destination = msg:get_destination()
    local sender = msg:get_sender()
    local signature = msg:get_signature()
    local error_name = msg:get_error_name()
    --unix fds

    signature = signature ~= "" and signature or nil

    ---@type glacier.dbus.message.Header
    local h = {
        type = types.message_type.from_str(type),
        no_autostart = not msg:get_auto_start(),
        no_reply = msg:get_no_reply(),
        serial = msg:get_serial(),
        path = path and types.object_path.from_str(path),
        interface = interface and types.interface_name.from_str(interface),
        member = member and types.member_name.from_str(member),
        error_name = error_name and types.interface_name.from_str(error_name),
        reply_serial = msg:get_reply_serial(),
        destination = destination and types.bus_name.from_str(destination),
        sender = sender and types.unique_name.from_str(sender),
        signature = signature and types.signature.from_str(signature),
        --unix fds
    }

    return MessageHeader:new(h)
end

---@class glacier.dbus.message.Body
local Body = {}

---@class glacier.dbus.message.body
local body = {}

---@param signature glacier.dbus.type.Signature
---@param typestr  ldbus.DBusValueType?
local function _assert_type_match(signature, typestr)
    ---@diagnostic disable-next-line
    typestr = typestr or ""
    assert(
        signature:code() == typestr,
        "Signature mismatch: Expected "
            .. tostring(signature:code())
            .. ", got: "
            .. tostring(typestr)
    )
end

---Extract a basic type from a `DBusMessageIter`
---@param signature glacier.dbus.type.Signature
---@param msg_iter ldbus.DBusMessageIter
---@return glacier.dbus.type.StrongType
function body._basic_from_ldbus(signature, msg_iter)
    assert(signature:is_basic(), "Not a basic type")
    _assert_type_match(signature, msg_iter:get_arg_type())

    local basic = msg_iter:get_basic()

    local Type = types.sig_to_type(signature)

    return Type(basic)
end

---Extract an array from a `DBusMessageIter`
---@param signature glacier.dbus.type.Signature
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a integer
---@param depth_s integer
---@return glacier.dbus.type.Array
function body._array_from_ldbus(signature, msg_iter, depth_a, depth_s)
    assert(signature:is_array(), "Not an array")
    depth_a = depth_a + 1
    assert(depth_a < 32, errors.type.TooNested)
    _assert_type_match(signature, msg_iter:get_arg_type())
    _assert_type_match(signature:get_array(), msg_iter:get_element_type())

    local ret = {} -- types.Array(InnerType)
    local sub = msg_iter:recurse()
    local inner = signature:get_array()

    -- get_arg_type returns nil when the array is empty.
    while sub:get_arg_type() do
        table.insert(ret, body._from_ldbus_impl(inner, sub, depth_a, depth_s))
        sub:next()
    end

    if #ret ~= 0 then
        return types.Array(ret)
    else
        return types.sig_to_type(signature) --[[@as glacier.dbus.type.Array]]
    end
end

---Extract a `Struct` from a `DBusMessageIter`.
---
---@param signature glacier.dbus.type.Signature
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a integer
---@param depth_s integer
---@return glacier.dbus.type.Struct
function body._struct_from_ldbus(signature, msg_iter, depth_a, depth_s)
    assert(signature:is_struct(), "Not a struct")
    depth_s = depth_s + 1
    assert(depth_s < 32, errors.type.TooNested)
    _assert_type_match(signature, msg_iter:get_arg_type())

    local ret = {}
    local sub = msg_iter:recurse()

    -- Empty structs are disallowed
    for _, v in ipairs(signature:get_field()) do
        assert(sub:get_arg_type(), "Signature mismatch: Not enough field in struct.")
        table.insert(ret, body._from_ldbus_impl(v, sub, depth_a, depth_s))
        sub:next()
    end

    if sub:has_next() then
        error("Signature mismatch: Too many field in struct.")
    end

    return types.Struct(ret)
end

---@param signature glacier.dbus.type.Signature
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a integer
---@param depth_s integer
function body._dict_entry_from_ldbus(signature, msg_iter, depth_a, depth_s)
    assert(signature:is_dict_entry(), "Not a dict_entry")
    _assert_type_match(signature, msg_iter:get_arg_type())

    local sub = msg_iter:recurse()

    if not sub:get_arg_type() then
        error("dict_entry must have a key.")
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    local key = body._basic_from_ldbus(signature:get_key(), sub)

    if not sub:next() then
        error("Dict Entries must have a value.")
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    local value = body._from_ldbus_impl(signature:get_value(), sub, depth_a, depth_s)

    if sub:has_next() then
        error("Dict Entries are a KeyValue pair.")
    end

    return key, value
end

---Extracts a dict from a `ldbus.DBusMessageIter`
---
---@param signature glacier.dbus.type.Signature
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a integer
---@param depth_s integer
---@return glacier.dbus.type.Dict
function body._dict_from_ldbus(signature, msg_iter, depth_a, depth_s)
    assert(signature:is_dict(), "Not a dict")
    depth_a = depth_a + 1
    assert(depth_a < 32, errors.type.TooNested)
    _assert_type_match(signature, msg_iter:get_arg_type())
    _assert_type_match(signature:get_array(), msg_iter:get_element_type())

    local ret = nil
    local sub = msg_iter:recurse()
    local inner = signature:get_array()

    -- get_arg_type returns nil when the array is empty.
    while sub:get_arg_type() do
        local k, value = body._dict_entry_from_ldbus(inner, sub, depth_a, depth_s)
        ret = ret or {}
        ret[k] = value
        sub:next()
    end

    if ret then
        return types.Dict(ret)
    else
        return types.sig_to_type(signature) --[[@as glacier.dbus.type.Dict]]
    end
end

---Extracts a variant from a `ldbus.DBusMessageIter`.
---@param signature glacier.dbus.type.Signature
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a? integer
---@param depth_s? integer
---@return glacier.dbus.type.Variant
function body._variant_from_ldbus(signature, msg_iter, depth_a, depth_s)
    assert(signature:is_variant())
    _assert_type_match(signature, msg_iter:get_arg_type())

    local v_iter = msg_iter:recurse()
    local v_sig = assert(v_iter:get_signature(), "Variant should have a content")
    assert(not v_iter:has_next(), "Variant should contain a single value.")

    ---@diagnostic disable-next-line: redefined-local
    local v_sig = types.signature.from_str(v_sig)
    local fields = v_sig:get_field()

    assert(#fields == 1, "Variant should contain a single value.")
    local field = fields[1]

    local v_val = body._from_ldbus_impl(field, v_iter, depth_a, depth_s)
    return types.Variant(v_val)
end

---Peek into the signature, and dispatch to the de-serialize function accordingly.
---@param signature glacier.dbus.type.Signature
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a? integer
---@param depth_s? integer
---@return glacier.dbus.type.StrongType
function body._from_ldbus_impl(signature, msg_iter, depth_a, depth_s)
    depth_a = depth_a or 0
    depth_s = depth_s or 0

    if signature:is_basic() then
        return body._basic_from_ldbus(signature, msg_iter)
    elseif signature:is_dict() then
        return body._dict_from_ldbus(signature, msg_iter, depth_a, depth_s)
    elseif signature:is_array() then
        return body._array_from_ldbus(signature, msg_iter, depth_a, depth_s)
    elseif signature:is_struct() then
        return body._struct_from_ldbus(signature, msg_iter, depth_a, depth_s)
    elseif signature:is_variant() then
        return body._variant_from_ldbus(signature, msg_iter, depth_a, depth_s)
    end

    error("unreacheable")
end

---@param signature? glacier.dbus.type.Signature
---@param msg ldbus.DBusMessage
---@return glacier.dbus.type.Struct?
function body.from_ldbus(signature, msg)
    if not signature or signature == "" then
        return nil
    end

    assert(signature:is_struct(), "Was expecting a struct at toplevel")
    local iter = assert(msg:iter_init(), "Could not get message body")

    local ret = {}
    for _, field in ipairs(signature:get_field()) do
        assert(iter:get_arg_type(), "Signature mismatch: Not enough field in struct.")
        table.insert(ret, body._from_ldbus_impl(field, iter))
        iter:next()
    end

    return types.Struct(ret)
end

---@param field glacier.dbus.type.StrongType
---@param msg_iter ldbus.DBusMessageIter
function body._basic_to_ldbus(field, msg_iter)
    local sig = field:signature() --[[@as glacier.dbus.type.Signature]]

    ---@diagnostic disable-next-line: param-type-mismatch
    msg_iter:append_basic(field:get(), sig:code())
end

---comment
---@param field glacier.dbus.type.Dict
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a integer
---@param depth_s integer
function body._dict_to_ldbus(field, msg_iter, depth_a, depth_s)
    local main_sig = field:signature() --[[@as glacier.dbus.type.Signature]]
    local entry_sig = main_sig:get_array()

    assert(depth_a < 32, errors.type.TooNested)
    depth_a = depth_a + 1

    local dict_iter = msg_iter:open_container(ldbus.types.array, entry_sig:get())
    local KeyType = field:key_type()

    for k, v in pairs(field:get()) do
        local entry_iter = dict_iter:open_container(ldbus.types.dict_entry)

        ---@diagnostic disable-next-line:param-type-mismatch
        entry_iter:append_basic(k, KeyType:signature():code())
        body._to_ldbus_impl(v, entry_iter, depth_a, depth_s)

        dict_iter:close_container(entry_iter)
    end

    msg_iter:close_container(dict_iter)
end

---@param field glacier.dbus.type.Array
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a integer
---@param depth_s integer
function body._array_to_ldbus(field, msg_iter, depth_a, depth_s)
    local array_sig = field:signature() --[[@as glacier.dbus.type.Signature]]
    local entry_sig = array_sig:get_array()

    assert(depth_a < 32, errors.type.TooNested)
    depth_a = depth_a + 1

    -- entry_sig:get() will not add marker around structs.
    local array_iter = msg_iter:open_container(ldbus.types.array, entry_sig:compute_str(1))

    for _, f in ipairs(field:get()) do
        body._to_ldbus_impl(f, array_iter, depth_a, depth_s)
    end

    msg_iter:close_container(array_iter)
end

---@param field glacier.dbus.type.Struct
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a integer
---@param depth_s integer
function body._struct_to_ldbus(field, msg_iter, depth_a, depth_s)
    local struct_iter = msg_iter:open_container(ldbus.types.struct)

    assert(depth_s < 32, errors.type.TooNested)
    depth_s = depth_s + 1

    for _, f in ipairs(field:get()) do
        body._to_ldbus_impl(f, struct_iter, depth_a, depth_s)
    end

    msg_iter:close_container(struct_iter)
end

---@param field glacier.dbus.type.Variant
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a integer
---@param depth_s integer
function body._variant_to_ldbus(field, msg_iter, depth_a, depth_s)
    local value = field:get()
    local inner_sig = value:signature() --[[@as glacier.dbus.type.Signature]]

    local variant_iter = msg_iter:open_container(ldbus.types.variant, inner_sig:compute_str(1))

    body._to_ldbus_impl(value, variant_iter, depth_a, depth_s)

    msg_iter:close_container(variant_iter)
end

---@param field glacier.dbus.type.StrongType
---@param msg_iter ldbus.DBusMessageIter
---@param depth_a? integer
---@param depth_s? integer
function body._to_ldbus_impl(field, msg_iter, depth_a, depth_s)
    depth_a = depth_a or 0
    depth_s = depth_s or 0

    if not field:is_container() then
        body._basic_to_ldbus(field, msg_iter)
    elseif field:is(types.Dict) then
        ---@cast field glacier.dbus.type.Dict
        body._dict_to_ldbus(field, msg_iter, depth_a, depth_s)
    elseif field:is(types.Array) then
        ---@cast field glacier.dbus.type.Array
        body._array_to_ldbus(field, msg_iter, depth_a, depth_s)
    elseif field:is(types.Struct) then
        ---@cast field glacier.dbus.type.Struct
        body._struct_to_ldbus(field, msg_iter, depth_a, depth_s)
    elseif field:is(types.Variant) then
        ---@cast field glacier.dbus.type.Variant
        body._variant_to_ldbus(field, msg_iter, depth_a, depth_s)
    end
end

---@param b glacier.dbus.type.Struct
---@param msg ldbus.DBusMessage
---@return ldbus.DBusMessage
function body.to_ldbus(b, msg)
    local msg_iter = msg:iter_init_append()

    local fields = b:get()

    for _, field in ipairs(fields) do
        local sig = field:signature() --[[@as glacier.dbus.type.Signature]]
        local _, matches_a = string.gsub(sig:compute_str(1), "a", "")
        local _, matches_r = string.gsub(sig:compute_str(1), "%(", "")

        assert(matches_a < 33 and matches_r < 33, errors.type.TooNested)

        body._to_ldbus_impl(field, msg_iter)
    end

    return msg
end

---@class glacier.dbus.Message
---@field header glacier.dbus.message.Header
---@field body? glacier.dbus.type.Struct
local Message = {}
Message.__name = "Message"

---Create a new `Message`.
---
---@param m glacier.dbus.Message
---@return glacier.dbus.Message
function Message:new(m)
    m = m or {}
    m.header = MessageHeader:new(m.header)

    self.__index = self
    return setmetatable(m, self)
end

---Get this `Message` type.
---
---@return glacier.dbus.type.MessageType
function Message:type()
    return self.header.type
end

---Get `no_reply` flag state.
---
---@return boolean
function Message:no_reply()
    return self.header.no_reply == true
end

---Set the `no_reply` flag.
---
---@param no_reply boolean
function Message:set_no_reply(no_reply)
    self.header.no_reply = no_reply == true
end

---Get the `no_autostart` flag.
---
---@return boolean
function Message:no_autostart()
    return self.header.no_autostart == true
end

---Set the `no_autostart` flag.
---
---@param no_autostart boolean
function Message:set_no_autostart(no_autostart)
    self.header.no_autostart = no_autostart == true
end

---Get this `Message` sender.
---
---@return glacier.dbus.type.UniqueName?
function Message:sender()
    return self.header.sender
end

---Set this `Message` sender.
---
---@param sender glacier.dbus.type.UniqueName?
function Message:set_sender(sender)
    self.header.sender = sender
end

---Get this `Message` interface.
---
---@return glacier.dbus.type.InterfaceName?
function Message:interface()
    return self.header.interface
end

---Set this `Message` interface.
---
---@param iface glacier.dbus.type.InterfaceName|string?
function Message:set_interface(iface)
    if not iface then
        if self.header.type ~= types.message_type.Signal then
            self.header.interface = nil
            return self
        else
            return nil, errors.type.Invalid
        end
    end

    if type(iface) == "string" then
        ---@cast iface string
        local ok, err = types.interface_name.try_from_str(iface)
        if not ok then
            return nil, err
        else
            iface = ok
        end
    elseif not types.is(iface, types.interface_name.InterfaceName) then
        return nil, errors.type.Invalid
    end

    ---@cast iface glacier.dbus.type.InterfaceName
    self.header.interface = iface
    return self
end

---Get this `Message` member.
---
---@return glacier.dbus.type.MemberName?
function Message:member()
    return self.header.member
end

---Get this `Message` path
---
---@return glacier.dbus.type.ObjectPath?
function Message:path()
    return self.header.path
end

---Get this `Message` destination
---
---@return glacier.dbus.type.BusName?
function Message:destination()
    return self.header.destination
end

---Get the error's name on error `Message`
---
---@return string?
function Message:error_name()
    if not self.header.error_name then
        return nil
    end

    return self.header.error_name:str()
end

---Get the `Message` signature.
---
---@return glacier.dbus.type.Signature?
function Message:signature()
    if not self.body then
        return nil
    end

    return self.body:signature()
end

---@package
---@diagnostic disable-next-line:duplicate-doc-alias
---@alias BusName glacier.dbus.type.BusName
---@diagnostic disable-next-line:duplicate-doc-alias
---@alias UniqueName glacier.dbus.type.UniqueName
---@diagnostic disable-next-line:duplicate-doc-alias
---@alias WellKnown glacier.dbus.type.WellKnownName

---Set this `Message` destination
---
---@param dest? BusName|UniqueName|WellKnown|string
---@return glacier.dbus.Message?
---@return string?
function Message:set_destination(dest)
    if not dest then
        self.header.destination = nil
        return self
    end

    if type(dest) == "string" then
        local ok, err = types.bus_name.try_from_str(dest)
        if not ok then
            return nil, err
        end

        dest = ok
    elseif types.is(dest, types.bus_name.UniqueName) then
        ---@cast dest glacier.dbus.type.UniqueName
        dest = types.bus_name.from_unique(dest)
    elseif types.is(dest, types.bus_name.WellKnownName) then
        ---@cast dest glacier.dbus.type.WellKnownName
        dest = types.bus_name.from_wellknown(dest)
    elseif not types.is(dest, types.bus_name.BusName) then
        return nil, errors.type.Invalid
    end

    ---@cast dest glacier.dbus.type.BusName
    self.header.destination = dest
    return self
end

---Get the argument at the specified index.
---
---@param pos integer # Index of the argument, in DBus notation (0 based indexing)
---@return glacier.dbus.type.StrongType? # Return nil if the message doesn't have a body, or if
---there are no argument at the specified index.
function Message:arg(pos)
    if not self.body then
        return nil
    end

    return self.body:get()[pos + 1]
end

---Reply to a method call.
---
---@param body? glacier.dbus.type.Struct
function Message:method_return(body) ---@diagnostic disable-line:redefined-local
    assert(self.header.type:str() == "method_call")

    local dest = self.header.sender and types.bus_name.from_unique(self.header.sender)

    local head = {
        type = types.message_type.MethodReturn,
        destination = dest,
        reply_serial = self.header.serial,
    }

    return Message:new({
        header = head,
        body = body,
    })
end

---Reply to a method call with an error.
---
---@param name string|glacier.dbus.type.InterfaceName
---@param error_msg? string
function Message:reply_error(name, error_msg)
    assert(self.header.type:str() == "method_call")
    if not types.is(name, types.interface_name.InterfaceName) then
        ---@diagnostic disable-next-line:param-type-mismatch
        name = types.interface_name.from_str(name)
    end

    local dest = self.header.sender and types.bus_name.from_unique(self.header.sender)

    local head = {
        type = types.message_type.Error,
        no_reply = true,
        destination = dest,
        reply_serial = self.header.serial,
        error_name = name,
    }

    local b = nil
    if error_msg ~= nil then
        b = types.Struct({ types.String(error_msg) })
    end

    return Message:new({
        header = head,
        body = b,
    })
end

---Convert a `Message` to `ldbus.DBusMessage`.
---
---@return ldbus.DBusMessage
function Message:to_ldbus()
    local msg = self.header:to_ldbus()

    if self.body then
        body.to_ldbus(self.body, msg)
    end

    return msg
end

---Create a new `Message` from a `ldbus.DBusMessage`.
---
---@param msg ldbus.DBusMessage
function message.from_ldbus(msg)
    local head = header.from_ldbus(msg)
    local b = body.from_ldbus(head.signature, msg)

    return Message:new({ header = head, body = b })
end

---Create a new `Message` to emit a signal.
---
---@param path glacier.dbus.type.ObjectPath|string
---@param interface glacier.dbus.type.InterfaceName|string
---@param member glacier.dbus.type.MemberName|string
---@param body? glacier.dbus.type.Struct
---@return glacier.dbus.Message
function message.signal(path, interface, member, body) ---@diagnostic disable-line:redefined-local
    if type(path) == "string" then
        path = types.ObjectPath(path)
    end

    if type(interface) == "string" then
        interface = types.interface_name.from_str(interface)
    end

    if type(member) == "string" then
        member = types.member_name.from_str(member)
    end

    local h = {
        type = types.message_type.Signal,
        path = path,
        interface = interface,
        member = member,
    }

    return Message:new({
        header = h,
        body = body,
    })
end

---Create a new `Message` to call a method.
---
---@param destination? glacier.dbus.type.BusName|string
---@param path glacier.dbus.type.ObjectPath|string
---@param interface? glacier.dbus.type.InterfaceName|string
---@param member glacier.dbus.type.MemberName|string
---@param body? glacier.dbus.type.Struct
---@return glacier.dbus.Message
function message.method_call(destination, path, interface, member, body) ---@diagnostic disable-line:redefined-local
    if type(destination) == "string" then
        destination = types.bus_name.from_str(destination)
    end

    if type(path) == "string" then
        path = types.ObjectPath(path)
    end

    if type(member) == "string" then
        member = types.member_name.from_str(member)
    end

    if type(interface) == "string" then
        interface = types.interface_name.from_str(interface)
    end

    local h = {
        type = types.message_type.MethodCall,
        destination = destination,
        path = path,
        member = member,
        interface = interface,
    }

    return Message:new({
        header = h,
        body = body,
    })
end

message.header = header
message.body = body

---@class glacier.dbus.message.Flags
---@field no_reply? boolean
---@field no_autostart? boolean

return message
