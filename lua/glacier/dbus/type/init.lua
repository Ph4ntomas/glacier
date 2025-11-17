local errors = require("glacier.dbus.errors")
local strong_type = require("glacier.dbus.type.strong_type")
local signature = require("glacier.dbus.type.signature")

local _utils = require("glacier.dbus.type.utils")

local StrongType = strong_type.StrongType
local StrongContainer = strong_type.StrongContainer

------------------------------
-- Boolean                  --
------------------------------

---@class glacier.dbus.type.Boolean: glacier.dbus.type.StrongType
---@field _value boolean
---
---@overload fun(v: any): glacier.dbus.type.Boolean
local Boolean = StrongType:new_type("Boolean", signature.basic.Boolean) --[[@as glacier.dbus.type.Boolean]]

---Construct a new Boolean
---@param v any
---@return glacier.dbus.type.Boolean
function Boolean:new(v)
    return self:super({ _value = not not v })
end

---Get the boolean
---@return boolean
function Boolean:get()
    return self._value
end

---Set the boolean
---@param v any
function Boolean:set(v)
    self._value = not not v
end

---@return boolean
---@return string?
function Boolean:validate(_)
    return true, nil
end

------------------------------
-- BYTE                     --
------------------------------

---@class glacier.dbus.type.Byte: glacier.dbus.type.StrongType
---@field private _value integer
---
---@overload fun(v: integer): glacier.dbus.type.Byte
local Byte = StrongType:new_type("Byte", signature.basic.Byte) --[[@as glacier.dbus.type.Byte]]

function Byte:new(v)
    assert(self:validate(v))
    return self:super({ _value = v })
end

function Byte:get()
    return self._value
end

---@param v integer
function Byte:set(v)
    assert(self:validate(v))
    self._value = math.floor(v)
end

---@param v any
---@return boolean
---@return string?
function Byte:validate(v)
    if type(v) ~= "number" then
        return false, errors.type.Invalid
    end

    if v < 0 or v > 255 then
        return false, errors.type.Range
    end

    return true
end

------------------------------
-- Int16                    --
------------------------------

---@class glacier.dbus.type.Int16: glacier.dbus.type.StrongType
---@field private _value integer
---
---@overload fun(v: integer): glacier.dbus.type.Int16
local Int16 = StrongType:new_type("Int16", signature.basic.Int16) --[[@as glacier.dbus.type.Int16]]

function Int16:new(v)
    assert(self:validate(v))
    return self:super({ _value = v })
end

function Int16:get()
    return self._value
end

---@param v integer
function Int16:set(v)
    assert(self:validate(v))
    self._value = math.floor(v)
end

---@param v any
---@return boolean
---@return string?
function Int16:validate(v)
    if type(v) ~= "number" then
        return false, errors.type.Invalid
    end

    if v < -2 ^ 15 or v > 2 ^ 15 - 1 then
        return false, errors.type.Range
    end

    return true
end

------------------------------
-- UInt16                   --
------------------------------

---@class glacier.dbus.type.UInt16: glacier.dbus.type.StrongType
---@field private _value integer
---
---@overload fun(v: integer): glacier.dbus.type.UInt16
local UInt16 = StrongType:new_type("UInt16", signature.basic.UInt16) --[[@as glacier.dbus.type.UInt16]]

function UInt16:new(v)
    assert(self:validate(v))
    return self:super({ _value = v })
end

function UInt16:get()
    return self._value
end

---@param v integer
function UInt16:set(v)
    assert(self:validate(v))
    self._value = math.floor(v)
end

---@param v any
---@return boolean
---@return string?
function UInt16:validate(v)
    if type(v) ~= "number" then
        return false, errors.type.Invalid
    end

    if v < 0 or v > 2 ^ 16 then
        return false, errors.type.Range
    end

    return true
end

------------------------------
-- Int32                    --
------------------------------

---@class glacier.dbus.type.Int32: glacier.dbus.type.StrongType
---@field private _value integer
---
---@overload fun(v: integer): glacier.dbus.type.Int32
local Int32 = StrongType:new_type("Int32", signature.basic.Int32) --[[@as glacier.dbus.type.Int32]]

function Int32:new(v)
    assert(self:validate(v))
    return self:super({ _value = v })
end

function Int32:get()
    return self._value
end

---@param v integer
function Int32:set(v)
    assert(self:validate(v))
    self._value = math.floor(v)
end

---@param v any
---@return boolean
---@return string?
function Int32:validate(v)
    if type(v) ~= "number" then
        return false, errors.type.Invalid
    end

    if v < -2 ^ 31 or v > 2 ^ 31 - 1 then
        return false, errors.type.Range
    end

    return true
end

------------------------------
-- UInt32                   --
------------------------------

---@class glacier.dbus.type.UInt32: glacier.dbus.type.StrongType
---@field private _value integer
---
---@overload fun(v: integer): glacier.dbus.type.UInt32
local UInt32 = StrongType:new_type("UInt32", signature.basic.UInt32) --[[@as glacier.dbus.type.UInt32]]

function UInt32:new(v)
    assert(self:validate(v))
    return self:super({ _value = v })
end

function UInt32:get()
    return self._value
end

---@param v integer
function UInt32:set(v)
    assert(self:validate(v))
    self._value = math.floor(v)
end

---@param v any
---@return boolean
---@return string?
function UInt32:validate(v)
    if type(v) ~= "number" then
        return false, errors.type.Invalid
    end

    if v < 0 or v > 2 ^ 32 then
        return false, errors.type.Range
    end

    return true
end

------------------------------
-- Int64                    --
------------------------------

---@class glacier.dbus.type.Int64: glacier.dbus.type.StrongType
---@field private _value integer
---
---@overload fun(v: integer): glacier.dbus.type.Int64
local Int64 = StrongType:new_type("Int64", signature.basic.Int64) --[[@as glacier.dbus.type.Int64]]

function Int64:new(v)
    assert(self:validate(v))
    return self:super({ _value = v })
end

function Int64:get()
    return self._value
end

---@param v integer
function Int64:set(v)
    assert(self:validate(v))
    self._value = math.floor(v)
end

---@param v any
---@return boolean
---@return string?
function Int64:validate(v)
    if type(v) ~= "number" then
        return false, errors.type.Invalid
    end

    -- using hex literal, because lua can't deal with 2^63
    if v < 0x8000000000000000 or v > 0x7FFFFFFFFFFFFFFF then
        return false, errors.type.Range
    end

    return true
end

------------------------------
-- UInt64                   --
------------------------------

---@class glacier.dbus.type.UInt64: glacier.dbus.type.StrongType
---@field private _value integer
---
---@overload fun(v: integer): glacier.dbus.type.UInt64
local UInt64 = StrongType:new_type("UInt64", signature.basic.UInt64) --[[@as glacier.dbus.type.UInt64]]

function UInt64:new(v)
    assert(self:validate(v))
    return self:super({ _value = v })
end

function UInt64:get()
    return self._value
end

---@param v integer
function UInt64:set(v)
    assert(self:validate(v))
    self._value = math.floor(v)
end

---@param v integer
---@return boolean
---@return string?
function UInt64:validate(v)
    if type(v) ~= "number" then
        return false, errors.type.Invalid
    end

    local ok, _ = pcall(function()
        return math.ult(v, 0xFFFFFFFFFFFFFFFF) or v == 0xFFFFFFFFFFFFFFFF
    end)

    if not ok then
        return false, errors.type.Range
    end

    return true
end

------------------------------
-- Double                   --
------------------------------

---@class glacier.dbus.type.Double: glacier.dbus.type.StrongType
---@field private _value number
---
---@overload fun(v: number): glacier.dbus.type.Double
local Double = StrongType:new_type("Double", signature.basic.Double) --[[@as glacier.dbus.type.Double]]

function Double:new(v)
    assert(self:validate(v))
    return self:super({ _value = v })
end

function Double:get()
    return self._value
end

function Double:set(v)
    assert(self:validate(v))
    self._value = v
end

function Double:validate(v)
    if type(v) ~= "number" then
        return false, errors.type.Invalid
    end

    return true
end

------------------------------
-- STRING                   --
------------------------------

---@class glacier.dbus.type.String: glacier.dbus.type.StrongType
---@field private _value string
---
---@overload fun(v: string): glacier.dbus.type.String
local String = StrongType:new_type("String", signature.basic.String) --[[@as glacier.dbus.type.String]]

function String:new(v)
    assert(self:validate(v))
    return self:super({ _value = v })
end

function String:get()
    return self._value
end

function String:set(v)
    assert(self:validate(v))
    self._value = v
end

function String:validate(v)
    if type(v) ~= "string" then
        return false, errors.type.Invalid
    end

    return true
end

function String.__eq(lhs, rhs)
    if lhs == nil and rhs == nil then
        return true
    elseif getmetatable(lhs) == String and getmetatable(rhs) == String then
        ---@cast lhs glacier.dbus.type.String
        ---@cast rhs glacier.dbus.type.String
        return lhs._value == rhs._value
    end

    return false
end

------------------------------
-- OBJECT PATH              --
------------------------------

---@class glacier.dbus.type.object_path
local object_path = {}

---@class glacier.dbus.type.ObjectPath: glacier.dbus.type.StrongType
---@field private _value string
---
---@overload fun(v: string): glacier.dbus.type.ObjectPath
local ObjectPath = StrongType:new_type("ObjectPath", signature.basic.ObjectPath) --[[@as glacier.dbus.type.ObjectPath]]

---Construct a new `ObjectPath`
---
---@param path string
---@return glacier.dbus.type.ObjectPath
function ObjectPath:new(path)
    assert(self:validate(path))
    return self:super({ _value = path })
end

function ObjectPath:get()
    return self._value
end

function ObjectPath:set(v)
    assert(self:validate(v))
    self._value = v
end

function ObjectPath:__tostring()
    return ("ObjectPath{%s}"):format(self._value)
end

function ObjectPath.__eq(lhs, rhs)
    if lhs == nil and rhs == nil then
        return true
    elseif getmetatable(lhs) == ObjectPath and getmetatable(rhs) == ObjectPath then
        ---@cast lhs glacier.dbus.type.ObjectPath
        ---@cast rhs glacier.dbus.type.ObjectPath
        return lhs._value == rhs._value
    end

    return false
end

---Checks if a string is a valid ObjectPath.
---
---@param path string
---
---@return boolean? # Returns `true` if `path` is a valid `ObjectPath`.
---@return string? # On error, returns the error description.
function ObjectPath:validate(path)
    if path == "" then
        return nil, errors.validation.InvalidObjectPath
    end

    if path == "/" then
        return true
    end

    path, _ = string.gsub(path, "/[%a%d_]+", "")

    if path ~= "" then
        return nil, errors.validation.InvalidObjectPath
    end

    return true
end

---Checks if a string is a valid ObjectPath.
---
---@param path string
---
---@return boolean? # Returns `true` if `path` is a valid `ObjectPath`.
---@return string? # On error, returns the error description.
function object_path.validate(path)
    return ObjectPath:validate(path)
end

---Create a new `ObjectPath` from a string.
---
---Throws if `path` is not a valid `ObjectPath`.
---
---@param path string
---
---@return glacier.dbus.type.ObjectPath
function object_path.from_str(path)
    return ObjectPath:new(path)
end

---Create a new `ObjectPath` from a string.
---
---@param path string
---@return glacier.dbus.type.ObjectPath? # Returns nil on error
---@return string? # The error string, if any.
function object_path.try_from_str(path)
    local ok, error = ObjectPath:validate(path)

    if not ok then
        return nil, error
    end

    return ObjectPath:new(path), nil
end

------------------------------
-- Array                    --
------------------------------

---@class glacier.dbus.type.ArrayInner
---@field type glacier.dbus.type.StrongType
---@field sig glacier.dbus.type.Signature
---@field array glacier.dbus.type.StrongType[]

---@class glacier.dbus.type.Array: glacier.dbus.type.StrongContainer
---@field private _inner glacier.dbus.type.ArrayInner
---
---@overload fun(t_or_v: any):glacier.dbus.type.Array
local Array = StrongContainer:new_type("Array") --[[@as glacier.dbus.type.Array]]

---@param fields glacier.dbus.type.StrongType|glacier.dbus.type.StrongType[]
---
---@return glacier.dbus.type.Array
function Array:new(fields)
    local inner = {
        _array = {},
    }

    local value = {}
    if fields and #fields > 0 and strong_type.is_strong_type(fields[1]) then
        inner.type = fields[1]:get_type()
        inner.sig = fields[1]:signature()
        value = fields
    elseif strong_type.is_strong_type(fields) then
        inner.type = fields
        inner.sig = fields:signature()
    else
        error(errors.type.Invalid)
    end

    if inner.sig == nil then
        error(errors.type.NoSignature)
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    local ret = self:super({ _inner = inner }) --[[@as glacier.dbus.type.Array]]

    ret:set(value)

    return ret
end

function Array:signature()
    return signature.Array(self._inner.sig)
end

---@generic T:glacier.dbus.type.StrongType
---
---@param self glacier.dbus.type.Array
---@return glacier.dbus.type.StrongType[]
function Array:get()
    return self._inner.array
end

---@generic T:glacier.dbus.type.StrongType
---
---@param array T[]
function Array:set(array)
    assert(self:validate(array))

    local new_array = {}
    for _, v in ipairs(array) do
        if strong_type.is_strong_type(v) and v:signature() == self._inner.sig then
            table.insert(new_array, v)
        elseif not strong_type:is_strong_type() then
            table.insert(new_array, self._inner.type:new(v))
        else
            error(errors.type.Invalid)
        end
    end

    self._inner.array = new_array
end

---@generic T:glacier.dbus.type.StrongType
---
---@param v T[]
---
---@return boolean
---@return string?
function Array:validate(v) ---@diagnostic disable-line:unused-local
    return true -- We don't validate here.
end

---Get the `Array` length.
---
---@return integer
function Array:__len()
    return #self._inner.array
end

---@param idx integer
---@return glacier.dbus.type.StrongType
function Array:__container_index(idx)
    return self._inner.array[idx]
end

---@param index integer
---@param value glacier.dbus.type.StrongType
function Array:__newindex(index, value)
    if strong_type.is_strong_type(value) and value:signature() == self._inner.sig then
        self._inner.array[index] = value
    elseif not self._inner.type:is_container() and not strong_type:is_strong_type() then
        self._inner.array[index] = self._inner.type:new(value)
    else
        error(errors.type.Invalid)
    end
end

------------------------------
-- Dict                     --
------------------------------

---@package
---@class InnerDict
---@field key_type glacier.dbus.type.StrongType
---@field value_type glacier.dbus.type.StrongType
---@field value_sig glacier.dbus.type.Signature
---@field dict table

---@class glacier.dbus.type.Dict: glacier.dbus.type.StrongContainer
---@field private _inner InnerDict
local Dict = StrongContainer:new_type("Dict")

---@generic K:glacier.dbus.type.StrongType, V:glacier.dbus.type.StrongType
---
---@param key K|table<K, V>
---@param value? V
---
---@return glacier.dbus.type.Dict
function Dict:new(key, value)
    local inner = {
        dict = {},
    }

    if value then
        assert(strong_type.is_basic_type(key), errors.type.InvalidKey)
        assert(strong_type.is_strong_type(value), errors.type.Invalid)

        ---@cast key glacier.dbus.type.StrongType
        ---@cast value glacier.dbus.type.StrongType

        inner.key_type = key
        inner.value_type = value
        inner.value_sig = assert(value:signature(), errors.type.NoSignature)

        return self:super({ _inner = inner })
    end

    local input = key
    key, value = next(input)
    assert(strong_type.is_basic_type(key), errors.type.InvalidKey)
    assert(strong_type.is_strong_type(value), errors.type.Invalid)

    ---@cast key glacier.dbus.type.StrongType
    ---@cast value glacier.dbus.type.StrongType
    inner.key_type = key:get_type()
    inner.value_type = value:get_type()
    inner.value_sig = assert(value:signature(), errors.type.NoSignature)

    ---@type glacier.dbus.type.Dict
    local ret = self:super({ _inner = inner })

    ret:set(input)

    return ret
end

---Returns the `Dict` key type.
---
---@return glacier.dbus.type.StrongType
function Dict:key_type()
    return self._inner.key_type
end

---Returns the `Dict` value type.
function Dict:value_type()
    return self._inner.value_type
end

---Returns the `Dict` value signature
---
---@return glacier.dbus.type.Signature
function Dict:value_sig()
    return self._inner.value_sig
end

---Return the internal dictionary.
---
---@return table<any, glacier.dbus.type.StrongType>
function Dict:get()
    return self._inner.dict
end

---Return the value at a given index.
---
---@param key any
---@return glacier.dbus.type.StrongType
function Dict:get_at(key)
    --assert(self._validate_key(key))

    if strong_type.is_strong_type(key) then
        key = key:get()
    elseif self._inner.key_type == signature.Signature then
        key = self._inner.key_type:new(key):get()
    end

    return self._inner.dict[key]
end

---Sets the whole dictionary data
---
---@param dict table<any, glacier.dbus.type.StrongType>
function Dict:set(dict)
    assert(self:validate(dict))

    local new_dict = {}

    for k, v in pairs(dict) do
        local key, value

        assert(self:_validate_key(k))
        assert(self:_validate_value(v))

        if strong_type.is_basic_type(k) then
            key = k:get()
        else
            key = self._inner.key_type:new(k):get()
        end

        if strong_type.is_strong_type(v) then
            value = v
        else
            value = self._inner.value_type:new(v)
        end

        new_dict[key] = value
    end

    self._inner.dict = new_dict
end

---Set a value at with the given `key`.
---@param key any
---@param value any
function Dict:set_at(key, value)
    assert(self:_validate_key(key))
    assert(self:_validate_value(value))

    if strong_type.is_strong_type(key) then
        key = assert(key:get())
    elseif self._inner.key_type == signature.Signature then
        key = self._inner.key_type:new(key):get()
    end

    if not self._inner.value_type:is_container() and not strong_type.is_strong_type(value) then
        value = self._inner.value_type:new(value)
    elseif not strong_type.is_strong_value(value) or not value:is(self._inner.value_type) then
        error(errors.type.Invalid)
    end

    self._inner.dict[key] = value
end

function Dict:signature()
    return signature.Dict(self._inner.key_type:signature():code(), self._inner.value_sig)
end

---Checks that the given `key` is compatible with the array.
---
---A valid key must either be of the same type than the dictionary key type, or a primitive type
---convertible to the key_type.
---@return boolean
---@return string?
function Dict:_validate_key(key)
    if strong_type.is_basic_type(key) and key:is(self._inner.key_type) then
        return true, nil
    elseif strong_type.is_strong_type(key) then
        return false, errors.type.InvalidKey
    elseif self._inner.key_type ~= signature.Signature then
        return self._inner.key_type:validate(key)
    else
        return true, nil
    end
end

---Checks that the given `value` can be stored in the container.
---
---@return boolean
---@return string?
function Dict:_validate_value(value)
    if strong_type.is_strong_type(value) and value:signature() == self._inner.value_sig then
        return true, nil
    elseif
        not self._inner.value_type:is_container()
        and self._inner.value_type ~= signature.Signature
    then
        return self._inner.value_type:validate(value)
    else
        return false, errors.type.Invalid
    end
end

function Dict:validate(dict) ---@diagnostic disable-line: unused-local
    return true
end

function Dict:__container_index(idx)
    return self:get_at(idx)
end

function Dict:__newindex(idx, value)
    self:set_at(idx, value)
end

------------------------------
-- Struct                   --
------------------------------

---@class glacier.dbus.type.StructInner
---@field types glacier.dbus.type.StrongType[]
---@field signatures glacier.dbus.type.Signature[]
---@field fields glacier.dbus.type.StrongType[]

---@class glacier.dbus.type.Struct: glacier.dbus.type.StrongContainer
---@field private _inner glacier.dbus.type.StructInner
---
---@overload fun(fields:glacier.dbus.type.StrongType[]): glacier.dbus.type.Struct
local Struct = StrongContainer:new_type("Struct") --[[@as glacier.dbus.type.Struct]]

---@param fields glacier.dbus.type.StrongType[]
function Struct:new(fields)
    local inner = {
        types = {},
        signatures = {},
        fields = {},
    }

    for _, field in ipairs(fields) do
        assert(strong_type.is_strong_value(field), errors.type.Invalid)
        local type = field:get_type()

        local sig = assert(field:signature(), errors.type.NoSignature)
        table.insert(inner.types, type)
        table.insert(inner.signatures, sig)
        table.insert(inner.fields, field)
    end

    return self:super({ _inner = inner })
end

function Struct:uninitialized(fields)
    local inner = {
        types = {},
        signatures = {},
        fields = {},
    }

    for _, field in ipairs(fields) do
        assert(strong_type.is_strong_type(field), errors.type.Invalid)
        local sig = assert(field:signature(), errors.type.NoSignature)

        table.insert(inner.types, field)
        table.insert(inner.signatures, sig)
    end

    return self:super({ _inner = inner })
end

function Struct:signature()
    return signature.Struct(self._inner.signatures)
end

---@return glacier.dbus.type.StrongType[]
function Struct:get()
    return self._inner.fields
end

---@param fields glacier.dbus.type.StrongType[]
function Struct:set(fields)
    assert(self:validate(fields))

    self._inner.fields = fields
end

---@param fields any[]
---
---@return boolean
---@return string?
function Struct:validate(fields)
    if #self._inner ~= #fields then
        return false, errors.type.FieldsDontMatch
    end

    for k, f in pairs(fields) do
        if not strong_type.is_strong_type(f) or f:signature() ~= self._inner.signatures[k] then
            return false, errors.type.Invalid
        end
    end

    return true, nil
end

---@param idx integer
---@return glacier.dbus.type.StrongType
function Struct:__container_index(idx)
    return self._inner.fields[idx]
end

---@param index integer
---@param value any
function Struct:__newindex(index, value)
    if not self._inner.types[index] then
        error(errors.type.Range)
    end

    if strong_type.is_strong_type(value) and value:signature() == self._inner.signatures[index] then
        self._inner.fields[index] = value
    elseif not self._inner.types[index]:is_container() and not strong_type:is_strong_type() then
        self._inner.fields[index] = self._inner.types[index]:new(value)
    else
        error(errors.type.Invalid)
    end
end

function Struct:is_value()
    return #self._inner.fields == #self._inner.types
end

------------------------------
-- Variant                  --
------------------------------

-- This is a special container, that does not act as one and cannot be index.
-- Let's make it a StrongType.

---@class glacier.dbus.type.Variant:glacier.dbus.type.StrongType
---@field value glacier.dbus.type.StrongType
---
---@overload fun(value:any):glacier.dbus.type.Variant
local Variant = StrongType:new_type("Variant", signature.Variant) --[[@as glacier.dbus.type.Variant]]

---@generic T: glacier.dbus.type.StrongType
---@param value T
function Variant:new(value)
    assert(self:validate(value))

    return self:super({ value = value })
end

---@return glacier.dbus.type.StrongType
function Variant:get()
    return self.value
end

---@generic T: glacier.dbus.type.StrongType
---@param v T
function Variant:set(v)
    assert(self:validate(v))
    self.value = v
end

---Get then held value type.
---@return glacier.dbus.type.StrongType
function Variant:get_inner_type()
    return self.value:get_type()
end

---Check that the held value is of type `type`.
---
---@generic T:glacier.dbus.type.StrongType
---@param type T
---@return boolean
function Variant:inner_is(type)
    return self.value:is(type)
end

---Check if a value can be set in a variant.
---@param value any
---@return boolean
---@return string?
function Variant:validate(value)
    return strong_type.is_strong_value(value), errors.type.ExpectedValue
end

---@return boolean # Always return true.
function Variant:is_container()
    return true
end

------------------------------
-- MODULE DEFINITION        --
------------------------------

local _sig_to_type = {
    ["b"] = Boolean --[[@as glacier.dbus.type.Boolean]],
    ["y"] = Byte --[[@as glacier.dbus.type.Byte]],
    ["n"] = Int16 --[[@as glacier.dbus.type.Int16]],
    ["q"] = UInt16 --[[@as glacier.dbus.type.UInt16]],
    ["i"] = Int32 --[[@as glacier.dbus.type.Int32]],
    ["u"] = UInt32 --[[@as glacier.dbus.type.UInt32]],
    ["x"] = Int64 --[[@as glacier.dbus.type.Int64]],
    ["t"] = UInt64 --[[@as glacier.dbus.type.UInt64]],
    ["s"] = String --[[@as glacier.dbus.type.String]],
    ["o"] = ObjectPath --[[@as glacier.dbus.type.ObjectPath]],
    ["g"] = signature.Signature --[[@as glacier.dbus.type.Signature]],
    ["v"] = Variant --[[@as glacier.dbus.type.Variant]],
}

---@param sig glacier.dbus.type.Signature
---@return glacier.dbus.type.StrongType
local function sig_to_type(sig)
    local ret = _sig_to_type[sig:code()]

    if ret then
        return ret
    end

    if sig:is_dict() then
        ---@diagnostic disable-next-line: param-type-mismatch
        local KeyType = sig_to_type(sig:get_key())
        ---@diagnostic disable-next-line: param-type-mismatch
        local ValueType = sig_to_type(sig:get_value())

        return Dict:new(KeyType, ValueType)
    elseif sig:is_array() then
        local inner = sig_to_type(sig:get_array())
        return Array:new(inner)
    elseif sig:is_struct() then
        local inner = {}
        for _, f in ipairs(sig:get_field()) do
            table.insert(inner, sig_to_type(f))
        end

        return Struct:uninitialized(inner)
    end

    error("unreacheable")
end

local message_type = require("glacier.dbus.type.message_type")
local bus_name = require("glacier.dbus.type.bus_name")
local interface_name = require("glacier.dbus.type.interface_name")
local member_name = require("glacier.dbus.type.member_name")

---@class glacier.dbus.type
local _type = {
    message_type = message_type,
    object_path = object_path,
    interface_name = interface_name,
    member_name = member_name,
    unique_name = bus_name.unique_name,
    well_known_name = bus_name.well_known_name,
    bus_name = bus_name,
    signature = signature,
    sig_to_type = sig_to_type,
    is = _utils.is,
    is_strong_type = strong_type.is_strong_type,

    -- Is the following weird with all the --[[]] ? Yep. But it prevent spurious warning from luals.
    -- Maybe I'll revisit the type system at some point, which will resolve this, who knows.
    Boolean = Boolean --[[@as glacier.dbus.type.Boolean]],
    Byte = Byte --[[@as glacier.dbus.type.Byte]],
    Int16 = Int16 --[[@as glacier.dbus.type.Int16]],
    UInt16 = UInt16 --[[@as glacier.dbus.type.UInt16]],
    Int32 = Int32 --[[@as glacier.dbus.type.Int32]],
    UInt32 = UInt32 --[[@as glacier.dbus.type.UInt32]],
    Int64 = Int64 --[[@as glacier.dbus.type.Int64]],
    UInt64 = UInt64 --[[@as glacier.dbus.type.UInt64]],
    String = String --[[@as glacier.dbus.type.String]],
    ObjectPath = ObjectPath --[[@as glacier.dbus.type.ObjectPath]],
    Signature = signature.Signature --[[@as glacier.dbus.type.Signature]],
    Array = Array --[[@as glacier.dbus.type.Array]],
    Dict = Dict --[[@as glacier.dbus.type.Dict]],
    Struct = Struct --[[@as glacier.dbus.type.Struct]],
    Variant = Variant --[[@as glacier.dbus.type.Variant]],

    MessageType = message_type.MessageType,
    BusName = bus_name.BusName,
    UniqueName = bus_name.UniqueName,
    WellKnownName = bus_name.WellKnownName,
    InterfaceName = interface_name.InterfaceName,
    MemberName = member_name.MemberName,
}

if _TEST then
    _type._private = {
        valid_msg_type = message_type._private.valid_msg_type,
        strong_type = strong_type,
    }
end

return _type
