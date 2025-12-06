describe("glacier.dbus.proxy", function()
    local cqueues = require("cqueues")

    local Proxy = require("glacier.dbus.proxy")
    local Connection = require("glacier.dbus.connection")
    local Types = require("glacier.dbus.type")

    local test_service = "test.glacier.Proxy"
    local test_object = "/test/glacier/test_object1"
    local test_interface = "test.proxy.Interface"
    local test_signal = "TestSignal"

    local method_spies = {}

    ---@return glacier.dbus.object.Interface
    local function build_interface()
        local Interface = require("glacier.dbus.object.interface")
        local Method = require("glacier.dbus.object.method")
        local Signal = require("glacier.dbus.object.signal")
        local Property = require("glacier.dbus.object.property")

        method_spies.get_name = spy.new(function(_)
            return Types.String(test_interface)
        end)

        local mbuilder = assert(Method.builder("GetName"))
        assert(mbuilder:add_output("Name", Types.String))
        assert(mbuilder:with_handler(function(_, ...)
            return method_spies.get_name(...)
        end))
        local get_name = assert(mbuilder:build())

        local sbuilder = assert(Signal.builder(test_signal))
        assert(sbuilder:add_argument("TestString", Types.String))
        assert(sbuilder:add_argument("TestInt", Types.Int32))
        local signal = assert(sbuilder:build())

        local p1 = assert(Property.builder("FirstProp"):build(Types.String("one")))
        local p2 = assert(Property.builder("IntProp"):build(Types.Int32(12)))
        local p3 =
            assert(Property.builder("ConstProp"):with_policy("const"):build(Types.String("Const")))
        local p4 = assert(
            Property.builder("InvalidatedProp"):with_policy("invalidates"):build(Types.Int32(150))
        )

        local builder = assert(Interface.builder(test_interface))
        assert(builder:with_method(get_name))

        assert(builder:with_property(p1))
        assert(builder:with_property(p2))
        assert(builder:with_property(p3))
        assert(builder:with_property(p4))

        assert(builder:with_signal(signal))
        return assert(builder:build())
    end

    local function make_proxy(connection)
        return assert(
            Proxy.builder(connection)
                :with_destination(test_service)
                :with_path(test_object)
                :with_interface(test_interface)
                :build()
        )
    end

    local function main_loop(cq, connection)
        cq:wrap(function()
            while not connection:stopping() do
                connection:step()
            end
        end)
    end

    ---@type glacier.dbus.Connection
    local connection
    before_each(function()
        local iface = build_interface()

        connection = assert(
            Connection.session()
                :with_name(test_service)
                :with_interface_at(test_object, iface)
                :build()
        )
    end)

    after_each(function()
        ---@diagnostic disable-next-line:cast-local-type
        connection = nil
        method_spies = {}
        collectgarbage()
    end)

    describe("glacier.dbus.proxy.Builder", function() end)

    describe("glacier.dbus.Proxy #integration", function()
        it("can call method", function()
            local cq = cqueues.new()
            cq:wrap(function()
                while not connection:stopping() do
                    connection:step()
                end
            end)

            ---@type glacier.dbus.message.CallResult
            local res
            local prox = make_proxy(connection)
            cq:wrap(function()
                res = prox:call("GetName")
                connection:shutdown()
            end)

            assert_loop(cq, TEST_TIMEOUT)
            assert.equal(test_interface, res:ok()[1]:get())
        end)

        it("can receive signals", function()
            local signal_body
            local signal_name
            local spy_handler = spy.new(function(name, body)
                signal_name = name
                signal_body = body
            end)
            local prox = make_proxy(connection)

            local cq = cqueues.new()
            cq:wrap(function()
                while not connection:stopping() do
                    connection:step()
                end
            end)
            cq:wrap(function()
                prox:on_signal(test_signal, function(_, name, body)
                    spy_handler(name, body)
                    connection:shutdown()
                end)
            end)

            local expected = Types.Struct({
                Types.String("TestString"),
                Types.Int32(1234),
            })

            cq:wrap(function()
                cqueues.poll(0)

                local router = connection:router()
                local iface = assert(router:get_interface(test_object, test_interface))
                local emitter = assert(router:emitter_for(test_object))

                ---@diagnostic disable-next-line:param-type-mismatch
                assert(iface:emit(emitter, test_signal, expected))
            end)

            assert_loop(cq, TEST_TIMEOUT)

            assert.spy(spy_handler).was.called(1)
            assert.same(expected, signal_body)
            assert.equal(test_signal, signal_name)
        end)

        it("can read all properties", function()
            local prox = make_proxy(connection)

            local cq = cqueues.new()
            main_loop(cq, connection)

            local ret
            cq:wrap(function()
                ret = prox:get_all_properties()
                connection:shutdown()
            end)

            assert_loop(cq, TEST_TIMEOUT)

            local expected = Types.Dict({
                [Types.String("FirstProp")] = Types.Variant(Types.String("one")),
                [Types.String("IntProp")] = Types.Variant(Types.Int32(12)),
                [Types.String("ConstProp")] = Types.Variant(Types.String("Const")),
                [Types.String("InvalidatedProp")] = Types.Variant(Types.Int32(150)),
            })
            assert.same(expected, ret)
        end)

        it("can read property", function()
            local prox = make_proxy(connection)

            local cq = cqueues.new()
            main_loop(cq, connection)

            local ret
            cq:wrap(function()
                ret = prox:get_property("FirstProp")
                connection:shutdown()
            end)

            assert_loop(cq, TEST_TIMEOUT)

            local expected = Types.String("one")
            assert.same(expected, ret)
        end)

        it("can write property", function()
            local prox = make_proxy(connection)

            local cq = cqueues.new()
            main_loop(cq, connection)

            local ret
            cq:wrap(function()
                prox:set_property("FirstProp", Types.String("Two"))
                ret = prox:get_property("FirstProp")
                connection:shutdown()
            end)

            assert_loop(cq, TEST_TIMEOUT)

            local expected = Types.String("Two")
            assert.same(expected, ret)
        end)

        it("Is updated on property changes", function()
            local prox = make_proxy(connection)

            local ret
            local spy_handler = spy.new(function(_, value)
                ret = value
            end)

            prox:on_property_change("FirstProp", function(name, v)
                spy_handler(name, v)
            end)

            local cq = cqueues.new()
            main_loop(cq, connection)

            cq:wrap(function()
                prox:set_property("FirstProp", Types.String("Two"))
                cqueues.poll(0)
                connection:shutdown()
            end)

            assert_loop(cq, TEST_TIMEOUT)

            assert.spy(spy_handler).was.called(1)
            local expected = Types.String("Two")
            assert.same(expected, ret)
        end)

        it("Is updated on property invalidation", function()
            local prox = make_proxy(connection)

            local ret
            local cq = cqueues.new()
            local spy_handler = spy.new(function(name, value)
                assert.is_nil(value)

                cq:wrap(function()
                    ret = prox:get_property(name)
                    connection:shutdown()
                end)
            end)

            prox:on_property_change("InvalidatedProp", function(name, v)
                spy_handler(name, v)
            end)

            main_loop(cq, connection)

            cq:wrap(function()
                prox:set_property("InvalidatedProp", Types.Int32(100))
            end)

            assert_loop(cq, TEST_TIMEOUT)

            assert.spy(spy_handler).was.called(1)
            local expected = Types.Int32(100)
            assert.same(expected, ret)
        end)

        it("can detect name changes", function()
            local new_service = test_service .. "2"

            local history = {}
            local spy_handler = spy.new(function(old, new)
                table.insert(history, { old = old, new = new })
            end)

            local builder = Proxy.builder(connection)
            builder:with_destination(new_service)
            builder:with_path(test_object)
            builder:with_interface(test_interface)
            local proxy = assert(builder:build())

            proxy:on_owner_changed(function(old, new)
                spy_handler(old, new)
            end)

            local cq = cqueues:new()

            cq:wrap(function()
                while not connection:stopping() do
                    connection:step()
                end
            end)

            cq:wrap(function()
                cqueues.poll(0)
                connection:request_name(new_service)
                cqueues.poll(0)
                connection:release_name(new_service)
                cqueues.poll(0)
                connection:shutdown()
            end)

            assert_loop(cq, TEST_TIMEOUT)
            assert.spy(spy_handler).was.called(2)
            local expect = {
                { old = "", new = connection:unique_name():str() },
                { old = connection:unique_name():str(), new = "" },
            }
            assert.same(expect, history)
        end)
    end)
end)
