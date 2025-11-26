describe("glacier.dbus.object.method", function()
    local _errors = require("glacier.dbus.errors")
    local _types = require("glacier.dbus.type")
    local _method = require("glacier.dbus.object.method")
    local _message = require("glacier.dbus.message")
    local _call_res = require("glacier.dbus.message.call_result")

    describe("glacier.dbus.object.method.Builder", function()
        it("can build method without args", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))
            assert.is_nil(method:input_signature())
            assert.is_nil(method:output_signature())
            assert.equal(_types.member_name.from_str("TestMethod"), method:name())
        end)

        it("can build method with one basic input arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_input("Input0", _types.Int32)
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))
            assert.equal(
                _types.signature.Struct({ _types.signature.basic.Int32 }),
                method:input_signature()
            )
            assert.is_nil(method:output_signature())
        end)

        it("can build method with one array input arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_input("Input0", _types.Array(_types.Int32))
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))
            assert.equal(
                _types.signature.Struct({ _types.signature.Array(_types.signature.basic.Int32) }),
                method:input_signature()
            )
            assert.is_nil(method:output_signature())
        end)

        it("can build method with one struct input arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_input(
                "Input0",
                _types.Struct:uninitialized({ _types.Int32, _types.String })
            )
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))
            local expected_sig = _types.signature.Struct({
                _types.signature.Struct({
                    _types.signature.basic.Int32,
                    _types.signature.basic.String,
                }),
            })

            assert.equal(expected_sig, method:input_signature())
            assert.is_nil(method:output_signature())
        end)

        it("can build method with one dict input arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_input("Input0", _types.Dict(_types.Int32, _types.String))
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))
            local expected_sig = _types.signature.Struct({
                _types.signature.Dict(_types.signature.basic.Int32, _types.signature.basic.String),
            })

            assert.equal(expected_sig, method:input_signature())
            assert.is_nil(method:output_signature())
        end)

        it("can build method with one variant input arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_input("Input0", _types.Variant)
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))

            local expected_sig = _types.signature.Struct({
                _types.signature.Variant,
            })

            assert.equal(expected_sig, method:input_signature())
            assert.is_nil(method:output_signature())
        end)

        it("can build method with several input args", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_input("Input0", _types.Variant)
            builder:add_input("Input1", _types.Array(_types.Int32))
            builder:add_input(
                "Input2",
                _types.Struct:uninitialized({ _types.Int32, _types.String })
            )
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))

            local expected_sig = _types.signature.Struct({
                _types.signature.Variant,
                _types.signature.Array(_types.signature.basic.Int32),
                _types.signature.Struct({
                    _types.signature.basic.Int32,
                    _types.signature.basic.String,
                }),
            })

            assert.equal(expected_sig, method:input_signature())
            assert.is_nil(method:output_signature())
        end)

        it("supports unnamed input args", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_input("Input0", _types.Variant)
            builder:add_input(_types.Array(_types.Int32)) ---@diagnostic disable-line:param-type-mismatch
            builder:add_input(
                "Input2",
                _types.Struct:uninitialized({ _types.Int32, _types.String })
            )
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))

            local expected_sig = _types.signature.Struct({
                _types.signature.Variant,
                _types.signature.Array(_types.signature.basic.Int32),
                _types.signature.Struct({
                    _types.signature.basic.Int32,
                    _types.signature.basic.String,
                }),
            })

            assert.equal(expected_sig, method:input_signature())
            assert.is_nil(method:output_signature())
        end)

        it("reject invalid input arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_input("Input0", _types.Variant)

            ---@diagnostic disable-next-line:param-type-mismatch
            local ok, err = builder:add_input(10)

            assert.falsy(ok)
            assert.equal(_errors.type.Invalid, err)

            ok, err = builder:add_input("test")

            assert.falsy(ok)
            assert.equal(_errors.type.Invalid, err)

            ---@diagnostic disable-next-line:param-type-mismatch
            ok, err = builder:add_input("test", "foo")

            assert.falsy(ok)
            assert.equal(_errors.type.Invalid, err)
        end)

        it("can build method with one basic output arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_output("Output0", _types.Int32)
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))
            assert.equal(
                _types.signature.Struct({ _types.signature.basic.Int32 }),
                method:output_signature()
            )
            assert.is_nil(method:input_signature())
        end)

        it("can build method with one array output arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_output("Output0", _types.Array(_types.Int32))
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))

            local expected_sig = _types.signature.Struct({
                _types.signature.Array(_types.signature.basic.Int32),
            })

            assert.equal(expected_sig, method:output_signature())
            assert.is_nil(method:input_signature())
        end)

        it("can build method with one struct output arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_output(
                "Output0",
                _types.Struct:uninitialized({ _types.Int32, _types.String })
            )
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))
            local expected_sig = _types.signature.Struct({
                _types.signature.Struct({
                    _types.signature.basic.Int32,
                    _types.signature.basic.String,
                }),
            })

            assert.equal(expected_sig, method:output_signature())
            assert.is_nil(method:input_signature())
        end)

        it("can build method with one dict output arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_output("Output0", _types.Dict(_types.Int32, _types.String))
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))
            local expected_sig = _types.signature.Struct({
                _types.signature.Dict(_types.signature.basic.Int32, _types.signature.basic.String),
            })

            assert.equal(expected_sig, method:output_signature())
            assert.is_nil(method:input_signature())
        end)

        it("can build method with one variant output arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_output("Output0", _types.Variant)
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))

            local expected_sig = _types.signature.Struct({
                _types.signature.Variant,
            })

            assert.equal(expected_sig, method:output_signature())
            assert.is_nil(method:input_signature())
        end)

        it("can build method with several output args", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_output("Output0", _types.Variant)
            builder:add_output("Output1", _types.Array(_types.Int32))
            builder:add_output(
                "Output2",
                _types.Struct:uninitialized({ _types.Int32, _types.String })
            )
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))

            local expected_sig = _types.signature.Struct({
                _types.signature.Variant,
                _types.signature.Array(_types.signature.basic.Int32),
                _types.signature.Struct({
                    _types.signature.basic.Int32,
                    _types.signature.basic.String,
                }),
            })

            assert.equal(expected_sig, method:output_signature())
            assert.is_nil(method:input_signature())
        end)

        it("can build method with several input & output args", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)

            builder:add_input(
                "Input0",
                _types.Struct:uninitialized({ _types.Int32, _types.String })
            )
            builder:add_input("Input1", _types.String)
            builder:add_input("Input2", _types.Array(_types.Int32))

            builder:add_output("Output0", _types.Variant)
            builder:add_output("Output1", _types.Array(_types.Int32))
            builder:add_output(
                "Output2",
                _types.Struct:uninitialized({ _types.Int32, _types.String })
            )
            local method = assert(builder:build())

            local expected_in = _types.signature.Struct({
                _types.signature.Struct({
                    _types.signature.basic.Int32,
                    _types.signature.basic.String,
                }),
                _types.signature.basic.String,
                _types.signature.Array(_types.signature.basic.Int32),
            })

            local expected_out = _types.signature.Struct({
                _types.signature.Variant,
                _types.signature.Array(_types.signature.basic.Int32),
                _types.signature.Struct({
                    _types.signature.basic.Int32,
                    _types.signature.basic.String,
                }),
            })

            assert.equal(expected_in, method:input_signature())
            assert.equal(expected_out, method:output_signature())
        end)

        it("supports unnamed output args", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_output("Output0", _types.Variant)
            builder:add_output(_types.Array(_types.Int32)) ---@diagnostic disable-line:param-type-mismatch
            builder:add_output(
                "Output2",
                _types.Struct:uninitialized({ _types.Int32, _types.String })
            )
            local method = assert(builder:build())

            assert.truthy(_types.is(method, _method.Method))

            local expected_sig = _types.signature.Struct({
                _types.signature.Variant,
                _types.signature.Array(_types.signature.basic.Int32),
                _types.signature.Struct({
                    _types.signature.basic.Int32,
                    _types.signature.basic.String,
                }),
            })

            assert.equal(expected_sig, method:output_signature())
            assert.is_nil(method:input_signature())
        end)

        it("reject invalid output arg", function()
            local builder = _method.builder("TestMethod")
            builder:with_handler(function() end)
            builder:add_output("Output0", _types.Variant)

            ---@diagnostic disable-next-line:param-type-mismatch
            local ok, err = builder:add_output(10)

            assert.falsy(ok)
            assert.equal(_errors.type.Invalid, err)

            ok, err = builder:add_output("test")

            assert.falsy(ok)
            assert.equal(_errors.type.Invalid, err)

            ---@diagnostic disable-next-line:param-type-mismatch
            ok, err = builder:add_output("test", "foo")

            assert.falsy(ok)
            assert.equal(_errors.type.Invalid, err)
        end)

        it("rejects non-function handler", function()
            local builder = _method.builder("TestMethod")
            local ok, err = builder:with_handler("handler")

            assert.falsy(ok)
            assert.equal(_errors.type.Invalid, err)
        end)

        it("requires a name", function()
            local builder, err = _method.builder()

            assert.falsy(builder)
            assert.equal(_errors.type.Invalid, err)
        end)

        it("requires a valid member_name", function()
            local builder, err = _method.builder("1TestMethod")

            assert.falsy(builder)
            assert.equal(_errors.validation.InvalidMemberName, err)
        end)
    end)

    describe("glacier.dbus.object.Method", function()
        local destination = "org.testobject.Test"
        local path = "/"
        local interface = "org.testobject.Test"
        local member = "TestMethod"

        it("can be called with no input/output", function()
            local builder = _method.builder("TestMethod")
            local called = false
            builder:with_handler(function()
                called = true
            end)

            local msg = _message.method_call(destination, path, interface, member)
            local method = builder:build()

            local res = method:call(msg)
            assert.equal(_types.message_type.MethodReturn, res:type())
            assert.truthy(called)
        end)

        it("can be called with no output", function()
            local called
            local builder = _method.builder("TestMethod")

            local arg = _types.String("Test")

            builder:add_input("input", _types.String)
            builder:with_handler(function(arg0)
                assert.truthy(_types.is(arg0, _types.String))
                assert.same(arg, arg0)
                called = arg0:get()
            end)

            local body = _types.Struct({
                arg,
            })
            local msg = _message.method_call(destination, path, interface, member, body)
            local method = builder:build()

            local res = method:call(msg)
            assert.equal(_types.message_type.MethodReturn, res:type())
            assert.equal("Test", called)
        end)

        it("can a return value", function()
            local builder = _method.builder("TestMethod")

            builder:add_input("input", _types.ObjectPath)
            builder:add_output("output", _types.String)
            builder:with_handler(function(arg0)
                return _types.String(arg0:get())
            end)

            local body = _types.Struct({
                _types.ObjectPath("/Test"),
            })
            local msg = _message.method_call(destination, path, interface, member, body)
            local method = builder:build()

            local res = method:call(msg)
            assert.equal(_types.message_type.MethodReturn, res:type())

            local expected = _types.Struct({
                _types.String("/Test"),
            })
            assert.same(expected, res.body)
        end)

        it("can be called with several value", function()
            local builder = _method.builder("TestMethod")

            builder:add_input("rhs", _types.Int32)
            builder:add_input("lhs", _types.Int32)
            builder:add_output("sum", _types.Int32)

            builder:with_handler(function(lhs, rhs)
                return _types.Int32(lhs:get() + rhs:get())
            end)

            local body = _types.Struct({
                _types.Int32(10),
                _types.Int32(15),
            })
            local msg = _message.method_call(destination, path, interface, member, body)
            local method = builder:build()

            local res = method:call(msg)
            assert.equal(_types.message_type.MethodReturn, res:type())

            local expected = _types.Struct({
                _types.Int32(25),
            })
            assert.same(expected, res.body)
        end)

        it("can return several value", function()
            local builder = _method.builder("TestMethod")

            builder:add_input("lhs", _types.Int32)
            builder:add_input("rhs", _types.Int32)
            builder:add_output("sum", _types.Int32)
            builder:add_output("tostr", _types.String)

            builder:with_handler(function(lhs, rhs)
                local sum = lhs:get() + rhs:get()

                return _types.Int32(sum), _types.String(tostring(sum))
            end)

            local body = _types.Struct({
                _types.Int32(10),
                _types.Int32(15),
            })
            local msg = _message.method_call(destination, path, interface, member, body)
            local method = builder:build()

            local res = method:call(msg)
            assert.equal(_types.message_type.MethodReturn, res:type())

            local expected = _types.Struct({
                _types.Int32(25),
                _types.String("25"),
            })
            assert.same(expected, res.body)
        end)

        it("can return arbitrary errors", function()
            local error_name = "org.test.Error.Arbitrary"
            local error_message = "Test Error Message"
            local builder = _method.builder("TestMethod")

            builder:with_handler(function()
                return _call_res.CallError.new(error_name, error_message)
            end)

            local method = builder:build()

            local msg = _message.method_call(destination, path, interface, member)

            local res = method:call(msg)
            assert.equal(_types.message_type.Error, res:type())
            assert.equal(error_name, res:error_name())
            assert.equal(error_message, res.body[1]:get())
        end)

        it("Returns Unimplemented error when there is no handler", function()
            local builder = _method.builder("TestMethod")
            builder:add_input("value", _types.Int32)
            local method = builder:build()

            local body = _types.Struct({
                _types.Int32(0),
            })

            local msg = _message.method_call(destination, path, interface, member, body)
            local res = method:call(msg)

            assert.equal(_types.message_type.Error, res:type())
            assert.equal(_errors.dbus.Failed, res:error_name())
            assert.equal(_errors.Unimplemented, res.body[1]:get())
        end)

        it("Rejects call with invalid input", function()
            local called = false

            local builder = _method.builder("TestMethod")
            builder:add_input("value", _types.Int32)
            builder:with_handler(function()
                called = true
            end)
            local method = builder:build()

            local body = _types.Struct({
                _types.String("test"),
            })
            local msg = _message.method_call(destination, path, interface, member, body)

            local res = method:call(msg)

            assert.falsy(called)
            assert.equal(_types.message_type.Error, res:type())
            assert.equal(_errors.dbus.InvalidArgs, res:error_name())
            assert.equal("Signature mismatch. Expected 'i', got 's'", res.body[1]:get())
        end)

        it("Fails on unexpected output", function()
            local builder = _method.builder("TestMethod")
            builder:add_output("value", _types.Int32)
            builder:with_handler(function()
                return _types.Int32(10), _types.String("bad_output")
            end)
            local method = builder:build()

            local msg = _message.method_call(destination, path, interface, member)

            local res = method:call(msg)

            assert.equal(_types.message_type.Error, res:type())
            assert.equal(_errors.dbus.Failed, res:error_name())
            assert.equal("Internal Error", res.body[1]:get())
        end)

        it("Fails on error thrown", function()
            local error_message = "Failed successfully"
            local builder = _method.builder("TestMethod")
            builder:add_output("value", _types.Int32)
            builder:with_handler(function()
                error(error_message)
                return _types.Int32(10)
            end)

            local method = builder:build()

            local msg = _message.method_call(destination, path, interface, member)

            local res = method:call(msg)

            assert.equal(_types.message_type.Error, res:type())
            assert.equal(_errors.dbus.Failed, res:error_name())
            assert.equal(_errors.InternalError, res.body[1]:get())
        end)

        it("handles thrown CallError", function()
            local error_name = "org.test.Error.Thrown"
            local error_message = "Failed successfully"
            local builder = _method.builder("TestMethod")
            builder:add_output("value", _types.Int32)
            builder:with_handler(function()
                error(_call_res.CallError.new(error_name, error_message))
                return _types.Int32(10)
            end)

            local method = builder:build()

            local msg = _message.method_call(destination, path, interface, member)

            local res = method:call(msg)

            assert.equal(_types.message_type.Error, res:type())
            assert.equal(error_name, res:error_name())
            assert.equal(error_message, res.body[1]:get())
        end)
    end)
end)
