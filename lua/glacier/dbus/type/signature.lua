local strong_type = require("glacier.dbus.type.strong_type")
local errors = require("glacier.dbus.errors")

local StrongType = strong_type.StrongType

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

---@class glacier.dbus.type.signature
local signature = {}

---@class glacier.dbus.type.Signature: glacier.dbus.type.StrongType
---@field private _code glacier.dbus.type.signature.SignatureCode
---@field private _str? string
---@field private _array_inner? glacier.dbus.type.Signature
---@field private _struct_inner? glacier.dbus.type.Signature[]
---@field private _dict_key? glacier.dbus.type.signature.BasicType
---@field private _dict_value? glacier.dbus.type.Signature
---
---@overload fun(v: string): glacier.dbus.type.Signature
local Signature = StrongType:new_type("Signature") --[[@as glacier.dbus.type.Signature]]

---@package
---Constructs a new signature
---@param sig glacier.dbus.type.Signature|string
---@return glacier.dbus.type.Signature
function Signature:new(sig)
    if type(sig) == "string" then
        sig = signature.from_str(sig)
    end

    return self:super(sig)
end

---@return string
function Signature:get()
    return self:str()
end

---@param sig string
function Signature:set(sig)
    local s = signature.from_str(sig)

    self._code = s._code
    self._array_inner = s._array_inner
    self._struct_inner = s._struct_inner
    self._dict_key = s._dict_key
    self._dict_value = s._dict_value
end

function Signature:signature()
    return "g"
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
---@param inner glacier.dbus.type.Signature
---@return glacier.dbus.type.Signature
function Signature:array(inner)
    return Signature:new({ _code = compound_type.array, _array_inner = inner })
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

function Signature:compute_str(depth)
    if self._code == "a" then
        return ("a%s"):format(self._array_inner:compute_str(depth + 1))
    elseif self._code == "e" then
        return ("{%s%s}"):format(self._dict_key, self._dict_value:compute_str(depth + 1))
    elseif self._code == "r" then
        local inner = ""
        for _, v in ipairs(self._struct_inner) do
            inner = inner .. v:compute_str(depth + 1)
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
    if self._str == nil then
        self._str = self:compute_str(0)
    end

    return self._str
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

---Get the inner signature for an array.
---@return glacier.dbus.type.Signature
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
    if self:is_dict_entry() then
        return Signature:basic(self._dict_key)
    elseif self:is_dict() then
        return self._array_inner:get_key()
    else
        return nil
    end
end

function Signature:get_value()
    if self:is_dict_entry() then
        return self._dict_value
    elseif self:is_dict() then
        return self._array_inner:get_value()
    else
        return nil
    end
end

function Signature:is_dict()
    return self:is_array() and self._array_inner:is_dict_entry()
end

---@param lhs glacier.dbus.type.Signature
---@param rhs glacier.dbus.type.Signature
---
---@return boolean
function Signature.__eq(lhs, rhs)
    if lhs == nil and rhs == nil then
        return true -- This should not be possible
    elseif getmetatable(lhs) == Signature and getmetatable(rhs) == Signature then
        return lhs:compute_str(1) == rhs:compute_str(1)
    end

    return false
end

function Signature:__tostring()
    return "Signature"
end

---@class glacier.dbus.type.signature
---local signature = {

signature.basic = {
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
}

---@param signatures glacier.dbus.type.Signature[]
---@return glacier.dbus.type.Signature
function signature.Struct(signatures)
    return Signature:struct(signatures)
end

---@param inner glacier.dbus.type.Signature
---@return glacier.dbus.type.Signature
function signature.Array(inner)
    return Signature:array(inner)
end

signature.Variant = Signature:variant()

---@param key glacier.dbus.type.signature.BasicType|glacier.dbus.type.Signature
---@param value glacier.dbus.type.Signature
---@return glacier.dbus.type.Signature
function signature.Dict(key, value)
    if getmetatable(key) == Signature then
        key = key:code()
    end

    assert(_rev_basic_type[key])

    ---@cast key glacier.dbus.type.signature.BasicType
    return Signature:dict(key, value)
end

signature.basic_type = basic_type
signature.compount_type = compound_type

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

signature.Signature = Signature

return signature
