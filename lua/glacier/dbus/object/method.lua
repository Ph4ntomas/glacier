local _errors = require("glacier.dbus.errors")
local _types = require("glacier.dbus.type")
local _call_res = require("glacier.dbus.message.call_result")
local _args = require("glacier.dbus.object.argument")

---@alias glacier.dbus.object.method.Handler fun(ctx:glacier.dbus.object.MethodContext, ...:glacier.dbus.type.StrongType):...

---@class glacier.dbus.object.Method
---@field _name glacier.dbus.type.MemberName
---@field _handler glacier.dbus.object.method.Handler
---@field _input_sig? glacier.dbus.type.Signature
---@field _input_args glacier.dbus.object.Arg[]
---@field _output_sig glacier.dbus.type.Signature
---@field _output_args glacier.dbus.object.Arg[]
local Method = {}
Method.__index = Method
Method.__name = "dbus.object.Method"

local function Method_new(name, handler, input_args, output_args)
    local ret = setmetatable({
        _name = name,
        _handler = handler,
        _input_sig = _args.signature(input_args),
        _input_args = input_args,
        _output_sig = _args.signature(output_args),
        _output_args = output_args,
    }, Method)

    return ret
end

---@return glacier.dbus.type.Signature?
function Method:input_signature()
    return self._input_sig
end

---@return glacier.dbus.type.Signature?
function Method:output_signature()
    return self._output_sig
end

---@return glacier.dbus.type.MemberName # Return the method name
function Method:name()
    return self._name
end

---@param context glacier.dbus.object.MethodContext
---@param message glacier.dbus.Message
---
---@return glacier.dbus.Message
function Method:call(context, message)
    if message:signature() ~= self._input_sig then
        local sig = message:signature()
        local msg = ("Signature mismatch. Expected '%s', got '%s'"):format(
            self._input_sig and self._input_sig:str() or "",
            sig and sig:str() or ""
        )
        return message:reply_error(_errors.dbus.InvalidArgs, msg)
    end

    if not self._handler then
        return message:reply_error(_errors.dbus.Failed, _errors.Unimplemented)
    end

    local args = message.body and message.body:get() or {}

    --TODO: Handler may need access to something to send signals.
    local ok, ret = pcall(function()
        return { self._handler(context, table.unpack(args)) }
    end)
    if not ok then
        if _types.is(ret, _call_res.CallError) then
            return message:reply_error(ret:name(), ret:message())
        else
            warn(tostring(ret))
            return message:reply_error(_errors.dbus.Failed, _errors.InternalError)
        end
    end

    if _types.is(ret[1], _call_res.CallError) then
        ---@type glacier.dbus.message.CallError
        local call_err = ret[1]
        return message:reply_error(call_err:name(), call_err:message())
    end

    local body = nil
    if #ret > 0 then
        body = _types.Struct(ret)

        if body:signature() ~= self._output_sig then
            return message:reply_error(_errors.dbus.Failed, _errors.InternalError)
        end
    elseif self._output_sig then
        return message:reply_error(_errors.dbus.Failed, _errors.InternalError)
    end

    return message:method_return(body)
end

---@class glacier.dbus.object.method.Builder
---@field name glacier.dbus.type.MemberName
---@field handler? fun(...:any): ...
---@field input_args? glacier.dbus.object.Arg[]
---@field output_args? glacier.dbus.object.Arg[]
local Builder = {}
Builder.__index = Builder
Builder.__name = "dbus.object.method.Builder"

local function Builder_new()
    return setmetatable({}, Builder)
end

---Set the name of a `Method`.
---@param name string|glacier.dbus.type.MemberName
---
---@return glacier.dbus.object.method.Builder?
---@return string?
function Builder:with_name(name)
    local err
    ---@diagnostic disable-next-line:cast-local-type
    name, err = _types.member_name.try_from(name)
    if not name then
        return nil, err
    end

    ---@cast name glacier.dbus.type.MemberName
    self.name = name
    return self
end

---Add an input argument to the `Method`.
---@param name string
---@param input_type glacier.dbus.type.StrongType
---
---@return glacier.dbus.object.method.Builder?
---@return string?
---
---@overload fun(input_type:glacier.dbus.type.StrongType):glacier.dbus.object.method.Builder?,string?
function Builder:add_input(name, input_type)
    ---@type string|nil
    local arg_name = name

    if input_type == nil then
        input_type = name --[[@as glacier.dbus.type.StrongType]]
        arg_name = nil
    end

    if not _types.is_strong_type(input_type) or arg_name and type(arg_name) ~= "string" then
        return nil, _errors.type.Invalid
    end

    self.input_args = self.input_args or {}
    table.insert(self.input_args, _args.new(arg_name, input_type, _args.Direction.In))

    return self
end

---Add an output argument to the `Method`.
---@param name string
---@param output_type? glacier.dbus.type.StrongType
---
---@return glacier.dbus.object.method.Builder?
---@return string?
---
---@overload fun(type: glacier.dbus.type.StrongType):glacier.dbus.object.method.Builder
function Builder:add_output(name, output_type)
    ---@type string|nil
    local arg_name = name

    if output_type == nil then
        output_type = name --[[@as glacier.dbus.type.StrongType]]
        arg_name = nil
    end

    if not _types.is_strong_type(output_type) then
        return nil, _errors.type.Invalid
    end

    self.output_args = self.output_args or {}
    table.insert(self.output_args, _args.new(arg_name, output_type, _args.Direction.Out))

    return self
end

---Sets the `Method` handler.
---@param handler glacier.dbus.object.method.Handler
function Builder:with_handler(handler)
    if handler and type(handler) ~= "function" then
        return nil, _errors.type.Invalid
    end

    self.handler = handler
    return self
end

---Build the `Method`.
---
---@return glacier.dbus.object.Method
function Builder:build()
    return Method_new(self.name, self.handler, self.input_args, self.output_args)
end

---@class glacier.dbus.object.method
local method = {
    Method = Method,
}

function method.builder(name)
    local ret = Builder_new()

    return ret:with_name(name)
end

return method
