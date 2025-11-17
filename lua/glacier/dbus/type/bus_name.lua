local errors = require("glacier.dbus.errors")
local _utils = require("glacier.dbus.type.utils")

------------------------------
-- UNIQUE NAME              --
------------------------------

---@class glacier.dbus.type.UniqueName
---@field private repr string
local UniqueName = {}
UniqueName.__index = UniqueName
UniqueName.__name = "dbus.type.UniqueName"

---@package
---Constructs a new `UniqueName`.
---
---@param name string
---@return glacier.dbus.type.UniqueName
local function UniqueName_new(name)
    return setmetatable({ repr = name }, UniqueName)
end

---Gets the `UniqueName` as a string.
---@return string
function UniqueName:str()
    return self.repr
end

function UniqueName:__tostring()
    return ("UniqueName{%s}"):format(self.repr)
end

function UniqueName.__eq(lhs, rhs)
    if lhs == nil and rhs == nil then
        return true
    elseif getmetatable(lhs) == UniqueName and getmetatable(rhs) == UniqueName then
        ---@cast lhs glacier.dbus.type.UniqueName
        ---@cast rhs glacier.dbus.type.UniqueName
        return lhs.repr == rhs.repr
    end

    return false
end

---@class glacier.dbus.type.unique_name
local unique_name = {}

---Checks if a string is a valid `UniqueName`.
---
---@param name string
---@return boolean? # Returns `true` if `name` is a valid `UniqueName`.
---@return string? # On error, returns the error description.
function unique_name.validate(name)
    --Because making an undocumented exception is always nice.
    if name == "org.freedesktop.DBus" then
        return true
    end

    if string.len(name) > 255 then
        return nil, errors.validation.NameTooLong
    end

    local matches = 0

    name, matches = string.gsub(name, "^:[%a%d_-]+", "")

    if matches == 0 then
        return nil, errors.validation.InvalidUniqueName
    end

    name, matches = string.gsub(name, "%.[%a%d_-]+", "")

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

    return UniqueName_new(name)
end

---Converts a string into a `UniqueName`
---
---@param name? string
---@return glacier.dbus.type.UniqueName? # Returns `nil` if `name` is not a valid `UniqueName`.
---@return string? # On error, returns the error description.
function unique_name.try_from_str(name)
    if not name then
        return nil
    end

    local ok, err = unique_name.validate(name)

    if not ok then
        return nil, err
    end

    return UniqueName_new(name), nil
end

------------------------------
-- WELL KNOWN NAME          --
------------------------------

---@class glacier.dbus.type.WellKnownName
---@field private repr string
local WellKnownName = {}
WellKnownName.__index = WellKnownName
WellKnownName.__name = "dbus.type.WellKnownName"

---@package
---Constructs a new `WellKnownName`.
---
---@param name string
---@return glacier.dbus.type.WellKnownName
local function WellKnownName_new(name)
    return setmetatable({ repr = name }, WellKnownName)
end

---Gets the `WellKnownName` as a string.
---@return string
function WellKnownName:str()
    return self.repr
end

function WellKnownName:__tostring()
    return ("WellKnownName{%s}"):format(self.repr)
end

---@class glacier.dbus.type.well_known_name
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

    name, matches = string.gsub(name, "%.[%a_-][%a%d_-]*", "")
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

    return WellKnownName_new(name)
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

    return WellKnownName_new(name), nil
end

------------------------------
-- BUS NAME                 --
------------------------------

---@class glacier.dbus.type.BusName
---@field unique_name? glacier.dbus.type.UniqueName
---@field well_known_name? glacier.dbus.type.WellKnownName
local BusName = {}
BusName.__index = BusName
BusName.__name = "dbus.type.BusName"

---@package
---Construct a new `BusName`.
---
---This function only initialize the metatable. You should call `BusName:unique` or `BusName:well_known` instead.
---@param bus glacier.dbus.type.BusName
---@return glacier.dbus.type.BusName
local function BusName_new(bus)
    return setmetatable(bus, BusName)
end

---Construct a new `BusName` containing a `UniqueName`.
---
---@param name glacier.dbus.type.UniqueName
---@return glacier.dbus.type.BusName
local function BusName_unique(name)
    return BusName_new({ unique_name = name })
end

---Construct a new `BusName` containing a `WellKnownName`.
---
---@param name glacier.dbus.type.WellKnownName
---@return glacier.dbus.type.BusName
local function BusName_wellknown(name)
    return BusName_new({ well_known_name = name })
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

function BusName:is_unique()
    return self.unique_name ~= nil
end

function BusName:unique()
    return self.unique_name
end

function BusName:wellknown()
    return self.wellknown
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
        return BusName_unique(unique_name.from_str(name))
    else
        return BusName_wellknown(well_known_name.from_str(name))
    end
end

---@param unique glacier.dbus.type.UniqueName
---@return glacier.dbus.type.BusName
function bus_name.from_unique(unique)
    return BusName_unique(unique)
end

---@param wellknown glacier.dbus.type.WellKnownName
---@return glacier.dbus.type.BusName
function bus_name.from_wellknown(wellknown)
    return BusName_wellknown(wellknown)
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
            return BusName_unique(unique), nil
        end
    else
        local well_known, err = well_known_name.try_from_str(name)

        if not well_known then
            return nil, err
        else
            return BusName_wellknown(well_known), nil
        end
    end
end

---@alias glacier.dbus.type.ToBusName string|glacier.dbus.type.WellKnownName|glacier.dbus.type.UniqueName|glacier.dbus.type.BusName

---@param value glacier.dbus.type.ToBusName
---@return glacier.dbus.type.BusName?
---@return string?
function bus_name.try_from(value)
    if type(value) == "string" then
        return bus_name.try_from_str(value)
    elseif _utils.is(value, BusName) then
        ---@cast value glacier.dbus.type.BusName
        return value, nil
    elseif _utils.is(value, UniqueName) then
        ---@cast value glacier.dbus.type.UniqueName
        return bus_name.from_unique(value), nil
    elseif _utils.is(value, WellKnownName) then
        ---@cast value glacier.dbus.type.WellKnownName
        return bus_name.from_wellknown(value), nil
    end

    return nil, errors.type.Invalid
end

bus_name.unique_name = unique_name
bus_name.well_known_name = well_known_name

bus_name.BusName = BusName
bus_name.UniqueName = UniqueName
bus_name.WellKnownName = WellKnownName

return bus_name
