local errors = require("glacier.dbus.errors")

------------------------------
-- MESSAGE TYPE             --
------------------------------

---@class glacier.dbus.type.MessageType
---@field private repr string
local MessageType = {}

---@package
---Construct a new `MessageType`.
---
---@param type string
---@return glacier.dbus.type.MessageType
function MessageType:new(type)
    self.__index = self
    return setmetatable({ repr = type }, self)
end

---Gets the `MessageType` as a string.
---@return string
function MessageType:str()
    return self.repr
end

function MessageType:__tostring()
    return ("MessageType{%s}"):format(self.repr)
end

---@class glacier.dbus.type.message_type
local message_type = {
    MethodCall = MessageType:new("method_call"),
    MethodReturn = MessageType:new("method_return"),
    Signal = MessageType:new("signal"),
    Error = MessageType:new("error"),
}

---@package
---@enum ValidMessageType
local valid_msg_type = {
    method_call = "method_call",
    method_return = "method_return",
    signal = "signal",
    error = "error",
}

---Checks if a string is a valid `MessageType`
---
---@param type string
---@return boolean? # Returns `true` if `type` is a valid `MessageType`.
---@return string? # On error, the error description.
function message_type.validate(type)
    if not valid_msg_type[type] then
        return nil, errors.validation.InvalidMessageType
    end

    return true
end

---Converts a string to a `MessageType`.
---
---Throws if `type` is not a valid `MessageType`.
---@param type string
---@return glacier.dbus.type.MessageType
function message_type.from_str(type)
    assert(message_type.validate(type))

    return MessageType:new(type)
end

---Converts a string to a `MessageType`.
---@param type string
---@return glacier.dbus.type.MessageType? # Returns `nil` on error.
---@return string? # One error, returns the error description.
function message_type.try_from_str(type)
    local ok, err = message_type.validate(type)

    if not ok then
        return nil, err
    end

    return MessageType:new(type), nil
end

------------------------------
-- OBJECT PATH              --
------------------------------

---@class glacier.dbus.type.object_path
local object_path = {}

---@class glacier.dbus.type.ObjectPath
---@field private repr string
local ObjectPath = {}

---@package
---Construct a new `ObjectPath`
---
---@param path string
---@return glacier.dbus.type.ObjectPath
function ObjectPath:new(path)
    self.__index = self
    return setmetatable({ repr = path }, self)
end

---Gets the `ObjectPath`, as a string.
---@return string
function ObjectPath:str()
    return self.repr
end

function ObjectPath:__tostring()
    return ("ObjectPath{%s}"):format(self.repr)
end

---Checks if a string is a valid ObjectPath.
---
---@param path string
---
---@return boolean? # Returns `true` if `path` is a valid `ObjectPath`.
---@return string? # On error, returns the error description.
function object_path.validate(path)
    if path == "/" then
        return true
    end

    path, _ = string.gsub(path, "/[%a%d_]+", "")

    if path ~= "" then
        return nil, errors.validation.InvalidObjectPath
    end

    return true
end

---Create a new `ObjectPath` from a string.
---
---Throws if `path` is not a valid `ObjectPath`.
---
---@param path string
---
---@return glacier.dbus.type.ObjectPath
function object_path.from_str(path)
    assert(object_path.validate(path))

    return ObjectPath:new(path)
end

---Create a new `ObjectPath` from a string.
---
---@param path string
---@return glacier.dbus.type.ObjectPath? # Returns nil on error
---@return string? # The error string, if any.
function object_path.try_from_str(path)
    local ok, error = object_path.validate(path)

    if not ok then
        return nil, error
    end

    return ObjectPath:new(path), nil
end

------------------------------
-- INTERFACE NAME           --
------------------------------

---@class glacier.dbus.type.InterfaceName
---@field private repr string
local InterfaceName = {}

---@package
---Consructs a new `InterfaceName`.
---
---@param name string
---@return glacier.dbus.type.InterfaceName
function InterfaceName:new(name)
    self.__index = self
    return setmetatable({ repr = name }, self)
end

---Gets the `InterfaceName`, as a string.
---@return string
function InterfaceName:str()
    return self.repr
end

function InterfaceName:__tostring()
    return ("InterfaceName{%s}"):format(self.repr)
end

---@class glacier.dbus.type.interface_name
local interface_name = {}

---Checks if a string is a valid `InterfaceName`.
---@param name string
---@return boolean? # True if the string is valid
---@return string? # String decribing the error.
function interface_name.validate(name)
    if string.len(name) > 255 then
        return nil, errors.validation.NameTooLong
    end

    ---@diagnostic disable-next-line: redefined-local
    local name, matches = string.gsub(name, "^[%a_][%a%d_]*", "")

    if matches == 0 then
        return nil, errors.validation.InvalidInterfaceName
    end

    ---@diagnostic disable-next-line: redefined-local
    local name, matches = string.gsub(name, ".[%a_][%a%d_]*", "")

    if matches == 0 or name ~= "" then
        return nil, errors.validation.InvalidInterfaceName
    end

    return true
end

---Construct a new `InterfaceName` from a string.
---
---This function throws if `name` is not a valid string.
---
---@param name string
---@return glacier.dbus.type.InterfaceName
function interface_name.from_str(name)
    assert(interface_name.validate(name))

    return InterfaceName:new(name)
end

---Construct a new `InterfaceName` from a string.
---
---@param name string
---@return glacier.dbus.type.InterfaceName? # Returns `nil` if the `name` wasn't a valid `InterfaceName`.
---@return string? # The error if `name` was rejected.
function interface_name.try_from_str(name)
    local ok, err

    if not ok then
        return nil, err
    end

    return InterfaceName:new(name), nil
end

------------------------------
-- MEMBER NAME              --
------------------------------

---@class glacier.dbus.type.MemberName
---@field private repr string
local MemberName = {}

---@package
---Construct a new `MemberName` from a string.
---
---@param name string
---@return glacier.dbus.type.MemberName
function MemberName:new(name)
    self.__index = self
    return setmetatable({ repr = name }, self)
end

---Gets the `MemberName`, as a string.
---@return string
function MemberName:str()
    return self.repr
end

function MemberName:__tostring()
    return ("MemberName{%s}"):format(self.repr)
end

---@class glacier.dbus.type.member_name
local member_name = {}

---Checks that a string is a valide `MemberName`
---@param name string
---@return boolean? # Returns `true` if `name` is a valid `MemberName`
---@return string? # On error, the error string.
function member_name.validate(name)
    if string.len(name) > 255 then
        return nil, errors.validation.NameTooLong
    end

    local match = string.match(name, "^[%a_][%a%d_]*$")
    if not match then
        return nil, errors.validation.InvalidMemberName
    end
    return true
end

---Converts a string to a `MemberName`.
---
---This function throws if `name` isn't valid.
---@param name string
---@return glacier.dbus.type.MemberName
function member_name.from_str(name)
    assert(member_name.validate(name))

    return MemberName:new(name)
end

---Converts a string to a `MemberName`.
---
---@param name string
---@return glacier.dbus.type.MemberName? # Returns `nil` on error.
---@return string? # On error, returns the error description.
function member_name.try_from_str(name)
    local ok, err = member_name.validate(name)

    if not ok then
        return nil, err
    end

    return MemberName:new(name), nil
end

------------------------------
-- UNIQUE NAME              --
------------------------------

---@class glacier.dbus.type.UniqueName
---@field private repr string
local UniqueName = {}

---@package
---Constructs a new `UniqueName`.
---
---@param name string
---@return glacier.dbus.type.UniqueName
function UniqueName:new(name)
    self.__index = self
    return setmetatable({ repr = name }, self)
end

---Gets the `UniqueName` as a string.
---@return string
function UniqueName:str()
    return self.repr
end

function UniqueName:__tostring()
    return ("UniqueName{%s}"):format(self.repr)
end

---@class glacier.dbus.type.UniqueName
local unique_name = {}

---Checks if a string is a valide `UniqueName`.
---
---@param name string
---@return boolean? # Returns `true` if `name` is a valid `UniqueName`.
---@return string? # On error, returns the error description.
function unique_name.validate(name)
    if string.len(name) > 255 then
        return nil, errors.validation.NameTooLong
    end

    local matches = 0

    name, matches = string.gsub(name, "^:[%a%d_-]+", "")

    if matches == 0 then
        return nil, errors.validation.InvalidUniqueName
    end

    name, matches = string.gsub(name, ".[%a%d_-]+", "")

    if matches == 0 or name ~= "" then
        return nil, errors.validation.InvalidUniqueName
    end

    return true
end

---Converts a string into a `UniqueName`.
---
---Throws if `name` is not a valid `UniqueName`.
---
---@param name string
---@return glacier.dbus.type.UniqueName
function unique_name.from_str(name)
    assert(unique_name.validate(name))

    return UniqueName:new(name)
end

---Converts a string into a `UniqueName`
---
---@param name string
---@return glacier.dbus.type.UniqueName? # Returns `nil` if `name` is not a valid `UniqueName`.
---@return string? # On error, returns the error description.
function unique_name.try_from_str(name)
    local ok, err = unique_name.validate(name)

    if not ok then
        return nil, err
    end

    return UniqueName:new(name), nil
end

------------------------------
-- WELL KNOWN NAME          --
------------------------------

---@class glacier.dbus.type.WellKnownName
---@field private repr string
local WellKnownName = {}

---@package
---Constructs a new `WellKnownName`.
---
---@param name string
---@return glacier.dbus.type.WellKnownName
function WellKnownName:new(name)
    self.__index = self
    return setmetatable({ repr = name }, self)
end

---Gets the `WellKnownName` as a string.
---@return string
function WellKnownName:str()
    return self.repr
end

function WellKnownName:__tostring()
    return ("WellKnownName{%s}"):format(self.repr)
end

---@class glacier.dbus.type.WellKnownName
local well_known_name = {}

---Checks if a string is a valide `WellKnownName`.
---
---@param name string
---@return boolean? # Returns `true` if `name` is a valid `WellKnownName`.
---@return string? # On error, returns the error description.
function well_known_name.validate(name)
    if string.len(name) > 255 then
        return nil, errors.validation.NameTooLong
    end

    local matches = 0

    name, matches = string.gsub(name, "^[%a_-][%a%d_-]*", "")
    if matches == 0 then
        return nil, errors.validation.InvalidBusName
    end

    name, matches = string.gsub(name, ".[%a_-][%a%d_-]*", "")
    if matches == 0 or name ~= "" then
        return nil, errors.validation.InvalidBusName
    end

    return true
end

---Converts a string into a `WellKnownName`.
---
---Throws if `name` is not a valid `WellKnownName`.
---
---@param name string
---@return glacier.dbus.type.WellKnownName
function well_known_name.from_str(name)
    assert(well_known_name.validate(name))

    return WellKnownName:new(name)
end

---Converts a string into a `WellKnownName`
---
---@param name string
---@return glacier.dbus.type.WellKnownName? # Returns `nil` if `name` is not a valid `WellKnownName`.
---@return string? # On error, returns the error description.
function well_known_name.try_from_str(name)
    local ok, err = well_known_name.validate(name)

    if not ok then
        return nil, err
    end

    return WellKnownName:new(name), nil
end

------------------------------
-- BUS NAME                 --
------------------------------

---@class glacier.dbus.type.BusName
---@field unique_name? glacier.dbus.type.UniqueName
---@field well_known_name? glacier.dbus.type.WellKnownName
local BusName = {}

---@package
---Construct a new `BusName`.
---
---This function only initialize the metatable. You should call `BusName:unique` or `BusName:well_known` instead.
---@param bus glacier.dbus.type.BusName
---@return glacier.dbus.type.BusName
function BusName:new(bus)
    self.__index = self
    return setmetatable(bus, self)
end

---Construct a new `BusName` containing a `UniqueName`.
---
---@param name glacier.dbus.type.UniqueName
---@return glacier.dbus.type.BusName
function BusName:unique(name)
    return self:new({ unique_name = name })
end

---Construct a new `BusName` containing a `WellKnownName`.
---
---@param name glacier.dbus.type.WellKnownName
---@return glacier.dbus.type.BusName
function BusName:well_known(name)
    return self:new({ well_known_name = name })
end

---Gets this `BusName` as a string.
---
---@return string
function BusName:str()
    if self.unique_name then
        return self.unique_name:str()
    else
        return self.well_known_name:str()
    end
end

function BusName:__tostring()
    local inner = self.unique_name or self.well_known_name

    return ("BusName{%s}"):format(tostring(inner))
end

---@class glacier.dbus.type.bus_name
local bus_name = {}

---Checks that a string is a valid `BusName`.
---
---@param name string
---@return boolean? # Returns `true` if the `name` is a valid `BusName`.
---@return string? # On error, returns the error description
function bus_name.validate(name)
    if string.sub(name, 1, 1) == ":" then
        return unique_name.validate(name)
    else
        return well_known_name.validate(name)
    end
end

---Converts a string into a `BusName`.
---
---Throws if `name` isn't a valid `BusName`.
---
---@param name string
---@return glacier.dbus.type.BusName
function bus_name.from_str(name)
    if string.sub(name, 1, 1) == ":" then
        return BusName:unique(unique_name.from_str(name))
    else
        return BusName:well_known(well_known_name.from_str(name))
    end
end

---Converts a string into a `BusName`.
---
---@param name string
---@return glacier.dbus.type.BusName? # Returns `nil` if `name` isn't a valid `BusName`.
---@return string? # On error, return the error description.
function bus_name.try_from_str(name)
    if string.sub(name, 1, 1) == ":" then
        local unique, err = unique_name.try_from_str(name)

        if not unique then
            return nil, err
        else
            return BusName:unique(unique), nil
        end
    else
        local well_known, err = well_known_name.try_from_str(name)

        if not well_known then
            return nil, err
        else
            return BusName:well_known(well_known), nil
        end
    end
end

------------------------------
-- SIGNATURE                --
------------------------------

---@enum glacier.dbus.type.signature.BasicType
local basic_type = {
    byte = "y",
    boolean = "b",
    int16 = "n",
    uint16 = "q",
    int32 = "i",
    uint32 = "u",
    int64 = "x",
    uint64 = "t",
    double = "d",
    unixfd = "h",
    string = "s",
    objectpath = "o",
    signature = "g",
}

local _rev_basic_type = {
    ["y"] = "byte",
    ["b"] = "boolean",
    ["n"] = "int16",
    ["q"] = "uint16",
    ["i"] = "int32",
    ["u"] = "uint32",
    ["x"] = "int64",
    ["t"] = "uint64",
    ["d"] = "double",
    ["h"] = "unixfd",
    ["s"] = "string",
    ["o"] = "objectpath",
    ["g"] = "signature",
}

---@enum glacier.dbus.type.signature.CompoundType
local compound_type = {
    array = "a",
    struct = "r",
    variant = "v",
    dict_entry = "e",
}

---@alias glacier.dbus.type.signature.SignatureCode
---| glacier.dbus.type.signature.BasicType
---| glacier.dbus.type.signature.CompoundType

---@class glacier.dbus.type.Signature
---@field private _code glacier.dbus.type.signature.SignatureCode
---@field private _array_inner? glacier.dbus.type.Signature
---@field private _struct_inner? glacier.dbus.type.Signature[]
---@field private _dict_key? glacier.dbus.type.signature.BasicType
---@field private _dict_value? glacier.dbus.type.Signature
local Signature = {}

---@package
---Constructs a new signature
---@param sig any
---@return any
function Signature:new(sig)
    self.__index = self

    return setmetatable(sig, self)
end

---Constructs a new `Signature` for a `BasicType`
---@param basic glacier.dbus.type.signature.BasicType
---@return glacier.dbus.type.Signature
function Signature:basic(basic)
    return Signature:new({ _code = basic })
end

---Constructs a new `Signature` for a struct.
---@param signatures glacier.dbus.type.Signature[]
---@return any
function Signature:struct(signatures)
    return Signature:new({ _code = compound_type.struct, _struct_inner = signatures })
end

---Constructs a new `Signature` for an array.
---@param signature glacier.dbus.type.Signature
---@return glacier.dbus.type.Signature
function Signature:array(signature)
    return Signature:new({ _code = compound_type.array, _array_inner = signature })
end

---Constructs a new `Signature` for a variant.
---@return glacier.dbus.type.Signature
function Signature:variant()
    return Signature:new({ _code = compound_type.variant })
end

---@package
---Constructs a new `Signature` for a dict_entry.
---
---@param key glacier.dbus.type.signature.BasicType
---@param value glacier.dbus.type.Signature
---@return glacier.dbus.type.Signature
function Signature:dict_entry(key, value)
    return Signature:new({ _code = compound_type.dict_entry, _dict_key = key, _dict_value = value })
end

---Constructs a new `Signature` for a dict.
---
---@param key glacier.dbus.type.signature.BasicType
---@param value glacier.dbus.type.Signature
---@return glacier.dbus.type.Signature
function Signature:dict(key, value)
    return Signature:array(Signature:dict_entry(key, value))
end

function Signature:str_rec(depth)
    if self._code == "a" then
        return ("a%s"):format(self._array_inner:str_rec(depth + 1))
    elseif self._code == "e" then
        return ("{%s%s}"):format(self._dict_key, self._dict_value:str_rec(depth + 1))
    elseif self._code == "r" then
        local inner = ""
        for _, v in ipairs(self._struct_inner) do
            inner = inner .. v:str_rec(depth + 1)
        end

        if depth == 0 then
            return inner
        else
            return ("(%s)"):format(inner)
        end
    else
        return self._code
    end
end

function Signature:str()
    return self:str_rec(0)
end

---@return glacier.dbus.type.signature.BasicType|glacier.dbus.type.signature.CompoundType
function Signature:code()
    return self._code
end

---@return boolean
function Signature:is_basic()
    return _rev_basic_type[self._code] ~= nil
end

function Signature:is_variant()
    return self._code == compound_type.variant
end

function Signature:is_array()
    return self._code == compound_type.array
end

function Signature:get_array()
    return self._array_inner
end

function Signature:is_struct()
    return self._struct_inner
end

function Signature:get_field()
    return self._struct_inner
end

function Signature:is_dict_entry()
    return self._code == compound_type.dict_entry
end

function Signature:get_key()
    return Signature:basic(self._dict_key)
end

function Signature:get_value()
    return self._dict_value
end

function Signature:is_dict()
    return self:is_array() and self._array_inner:is_dict_entry()
end

function Signature:__tostring()
    return "Signature"
end

---@class glacier.dbus.type.signature
local signature = {
    basic = {
        Byte = Signature:basic("y"),
        Boolean = Signature:basic("b"),
        Int16 = Signature:basic("n"),
        UInt16 = Signature:basic("q"),
        Int32 = Signature:basic("i"),
        UInt32 = Signature:basic("u"),
        Int64 = Signature:basic("x"),
        UInt64 = Signature:basic("t"),
        Double = Signature:basic("d"),
        UnixFd = Signature:basic("h"),
        String = Signature:basic("s"),
        ObjectPath = Signature:basic("o"),
        Signature = Signature:basic("g"),
    },

    ---@param signatures glacier.dbus.type.Signature[]
    ---@return glacier.dbus.type.Signature
    Struct = function(signatures)
        return Signature:struct(signatures)
    end,
    ---@param inner glacier.dbus.type.Signature
    ---@return glacier.dbus.type.Signature
    Array = function(inner)
        return Signature:array(inner)
    end,
    Variant = Signature:variant(),

    ---@param key glacier.dbus.type.signature.BasicType
    ---@param value glacier.dbus.type.Signature
    ---@return glacier.dbus.type.Signature
    Dict = function(key, value)
        return Signature:dict(key, value)
    end,

    basic_type = basic_type,
    compount_type = compound_type,
}

---Checks that a string is a valid `signature`.
---
---WARNING: This function only perform minimal validation. Due to the complexity of Signatures,
---validating them requires to parse them, so the correct validation is to call `try_from_str`.
function signature.validate(sigstr)
    if not sigstr then
        return nil, errors.validation.BadFormat
    end

    if sigstr:len() > 255 then
        return nil, errors.validation.SignatureTooLong
    end

    return true
end

local function make_basic_type_pattern()
    local pat_arr = {}
    for _, basic in pairs(basic_type) do
        table.insert(pat_arr, basic)
    end

    return ("^[%s]"):format(table.concat(pat_arr, ""))
end

local basic_type_pattern = make_basic_type_pattern()

---Parse a `Signature` representing a basic type.
---
---@param sigstr string
---@return string? # The parsed signature, if any.
---@return string # The string being parsed. If one basic signature was found, the string returned
---will be shorter by one character.
local function parse_signature_basic(sigstr)
    local sig

    sigstr, _ = string.gsub(sigstr, basic_type_pattern, function(basic)
        sig = basic
        return ""
    end)

    return sig, sigstr
end

---Parse a `Signature`.
---
---@param sigstr string
---@param arr_depth integer
---@param struct_depth integer
---@return glacier.dbus.type.Signature?
---@return string
local function parse_signature(sigstr, arr_depth, struct_depth)
    arr_depth = arr_depth or 0
    struct_depth = struct_depth or 0

    local ret = {}

    --- todo authorize for depth 0 ?
    if sigstr == "" then
        return nil, errors.signature.MissingType
    end

    if arr_depth > 32 or struct_depth > 32 then
        return nil, errors.signature.TooNested
    end

    if string.match(sigstr, "^{") then
        return nil, errors.signature.DictEntryOutsideArray
    end

    while sigstr ~= "" do
        local matches = 0
        local sig = nil

        sig, sigstr = parse_signature_basic(sigstr)
        if sig then
            sig = Signature:basic(sig)
        end

        ---Parse Dict
        if not sig then
            local match = string.match(sigstr, "^a{")
            if match then
                local substr = nil
                sigstr, _ = string.gsub(sigstr, "^a(%b{})", function(capture)
                    substr = string.sub(capture, 2, -2)
                    return ""
                end)

                if not substr then
                    return nil, errors.signature.IncompleteType
                elseif string.len(substr) < 2 then
                    return nil, errors.signature.InvalidEntry
                end

                local key
                key, substr = parse_signature_basic(substr)

                if not key then
                    return nil, errors.signature.NonBasicKey
                end

                local entry
                entry, substr = parse_signature(substr, arr_depth + 1, struct_depth)
                if not entry then
                    return nil, substr
                elseif substr ~= "" then
                    return nil, errors.signature.InvalidEntry
                end

                sig = Signature:dict(key, entry)
            end
        end

        --- Parse array
        if not sig then
            sigstr, matches = string.gsub(sigstr, "^a", "")
            if matches > 0 then
                sig, sigstr = parse_signature(sigstr, arr_depth + 1, struct_depth)

                if sig then
                    sig = Signature:array(sig)
                else
                    return nil, sigstr
                end
            end
        end

        --- Parse struct
        if not sig then
            local match = string.match(sigstr, "^%(")
            if match then
                local substr = nil
                sigstr, _ = string.gsub(sigstr, "^%b()", function(capture)
                    substr = string.sub(capture, 2, -2)

                    return ""
                end)

                if not substr then
                    return nil, errors.signature.IncompleteType
                elseif substr == "" then
                    return nil, errors.signature.EmptyStruct
                else
                    local sigarr = {}
                    local subsig
                    while substr ~= "" do
                        subsig, substr = parse_signature(substr, arr_depth, struct_depth + 1)
                        if not subsig then
                            return nil, substr
                        else
                            table.insert(sigarr, subsig)
                        end
                    end

                    sig = Signature:struct(sigarr)
                end
            end
        end

        --- Parse variant
        if not sig then
            sigstr, matches = string.gsub(sigstr, "^v", "")
            if matches > 0 then
                sig = Signature:variant()
            end
        end

        if not sig then
            return nil, errors.signature.UnknownType
        end

        if arr_depth == 0 and struct_depth == 0 then
            table.insert(ret, sig)
        else
            return sig, sigstr
        end
    end

    return Signature:struct(ret), sigstr
end

---Converts a string into a `Signature`.
---@param sig string
---
---@return glacier.dbus.type.Signature? # Returns `nil` if `sig` isn't a valid `Signature`.
---@return string? # On error, returns the error description.
function signature.try_from_str(sig)
    local ok, err = signature.validate(sig)

    if not ok then
        return nil, err
    end

    return parse_signature(sig, 0, 0)
end

---Converts a string into a `Signature`.
---
---Throws if `sig` isn't a valid `Signature`.
---@param sig string
---@return glacier.dbus.type.Signature
function signature.from_str(sig)
    return assert(signature.try_from_str(sig))
end

------------------------------
-- VARIANT                  --
------------------------------

---@class glacier.dbus.type.Variant
---@field _signature glacier.dbus.type.Signature
---@field _value? any
local Variant = {}

---@package
---
---Construct a new variant
---@param v glacier.dbus.type.Variant
---@return glacier.dbus.type.Variant
function Variant:new(v)
    self.__index = self
    return setmetatable(v, self)
end

function Variant:signature()
    return self._signature()
end

function Variant:value()
    return self._value
end

---@class glacier.dbus.type.variant
local variant = {}

---Build a new variant.
---
---@param sig glacier.dbus.type.Signature|string
---@param value any
---@return glacier.dbus.type.Variant
---
---@diagnostic disable-next-line: redefined-local
function variant.new(sig, value)
    if type(sig) == "string" then
        sig = signature.from_str(sig)
    end

    return Variant:new({ _signature = sig, _value = value })
end

------------------------------
-- MODULE DEFINITION        --
------------------------------

---@class glacier.dbus.type
local type = {
    message_type = message_type,
    object_path = object_path,
    interface_name = interface_name,
    member_name = member_name,
    unique_name = unique_name,
    well_known_name = well_known_name,
    bus_name = bus_name,
    signature = signature,
    variant = variant,
}

if _TEST then
    type._private = {
        valid_msg_type = valid_msg_type,
    }
end

return type
