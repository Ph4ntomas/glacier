describe("glacier.dbus.object.interface", function()
    local _errors = require("glacier.dbus.errors")
    local _types = require("glacier.dbus.type")
    local _message = require("glacier.dbus.message")
    local _method = require("glacier.dbus.object.method")
    local _interface = require("glacier.dbus.object.interface")
    local _call_res = require("glacier.dbus.message.call_result")

    local interface_name = "org.test.Interface"

    ---@type glacier.dbus.object.MethodContext
    local method_ctx

    local test_methods
    local called
    setup(function()
        test_methods = {
            GetName = assert(_method
                .builder("GetName")
                :add_output("Name", _types.String)
                :with_handler(function()
                    return _types.String(interface_name)
                end)
                :build()),
            Failing = assert(_method
                .builder("Failing")
                :with_handler(function()
                    error(_call_res.CallError.new("org.test.Failing", "FailingMethod"))
                end)
                :build()),
            CallCheck = assert(_method
                .builder("CallCheck")
                :with_handler(function()
                    called = true
                end)
                :build()),
        }
    end)

    before_each(function()
        called = false
    end)

    describe("glacier.dbus.object.interface.Builder", function()
        it("can build empty interface", function()
            local builder = assert(_interface.builder("org.test.Interface"))
            assert(builder:build())
        end)

        it("accepts InterfaceName", function()
            assert(_interface.builder(_types.interface_name.from_str("org.test.Interface")))
        end)

        it("rejects wrong typed name", function()
            ---@diagnostic disable-next-line:param-type-mismatch
            local ok, err = _interface.builder(10)
            assert.falsy(ok)
            assert.equal(_errors.type.Invalid, err)
        end)

        it("rejects invalid InterfaceName", function()
            local ok, err = _interface.builder("org")
            assert.falsy(ok)
            assert.equal(_errors.validation.InvalidInterfaceName, err)
        end)

        it("can add methods", function()
            local builder = assert(_interface.builder(interface_name))
            assert(builder:with_method(test_methods.GetName))
            local iface = assert(builder:build())

            assert.equal(test_methods.GetName, iface._methods["GetName"])
        end)

        it("rejects wrong type in add_method", function()
            local builder = assert(_interface.builder(interface_name))
            ---@diagnostic disable-next-line:param-type-mismatch
            local ok, err = builder:with_method("not a method")

            assert.falsy(ok)
            assert.equal(_errors.type.Invalid, err)
        end)
    end)

    describe("glacier.dbus.object.Interface", function()
        local test_message = function(method, body)
            return assert(_message.method_call("org.test.Dest", "/", interface_name, method, body))
        end

        ---@type glacier.dbus.object.Interface
        local test_interface
        before_each(function()
            local builder = assert(_interface.builder(interface_name))

            for _, v in pairs(test_methods) do
                assert(builder:with_method(v))
            end

            test_interface = assert(builder:build())
        end)

        it("Dispatch method correctly", function()
            local msg = test_message("CallCheck")

            test_interface:call(method_ctx, msg)

            assert.truthy(called)
        end)

        it("forward method return", function()
            local msg = test_message("GetName")

            local res = test_interface:call(method_ctx, msg)

            assert.equal(_types.message_type.MethodReturn, res:type())

            local expected = _types.Struct({
                _types.String(interface_name),
            })
            assert.same(expected, res.body)
        end)

        it("forward errors", function()
            local msg = test_message("Failing")

            local res = test_interface:call(method_ctx, msg)

            assert.equal(_types.message_type.Error, res:type())
            assert.equal("org.test.Failing", res:error_name())
        end)

        it("return error on unknown method", function()
            local method_name = "UndefinedMethod"
            local msg = test_message(method_name)

            local res = test_interface:call(method_ctx, msg)

            assert.equal(_types.message_type.Error, res:type())
            assert.equal(_errors.dbus.UnknownMethod, res:error_name())

            local expected = _types.Struct({
                _types.String(method_name),
            })
            assert.same(expected, res.body)
        end)
    end)
end)
