describe("match_rule", function()
    ---@type glacier.dbus.match_rule
    local match_rule
    local errors = require("glacier.dbus.errors")
    ---@type glacier.dbus.message
    local messages
    ---@type glacier.dbus.type
    local types

    setup(function()
        _G._TEST = true
        match_rule = require("glacier.dbus.match_rule")
        messages = require("glacier.dbus.message")
        types = require("glacier.dbus.type")
    end)

    teardown(function()
        _G._TEST = nil
    end)

    local example_match_rule =
        "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='Foo',path='/bar/foo',destination=':452345.34',arg2='bar'"

    local valid_unique = {
        "org.freedesktop.DBus", -- This is a special case.
        ":1.10",
    }

    local bad_sender = {
        ":",
        ":.10",
        ":1/10",
    }

    local bad_unique = {
        "",
        ":",
        ":.10",
        ":1/10",
        "org.badunique.DBus",
    }

    local bad_wellknown = {
        "",
        "org",
        ".",
        "org.",
        ".org.freedesktop.DBus",
        "1org.freedesktop.DBus",
        "org.1freedesktop.DBus",
        "org.freedesktop/DBus",
    }

    local bad_interface = {
        "",
        "org",
        "org.",
        ".org",
        ".org.freedesktop",
        "1org.freedesktop.DBus",
        "org.1freedesktop.DBus",
        "org.freedesktop.DBus-",
        "org.free-desktop.DBus",
    }

    local bad_arg0ns = {
        "", -- cannot be empty
        "org.", -- cannot end with .
        ".org", -- cannot start with .
        ".org.freedesktop", -- cannot start with .
        "1org.freedesktop.DBus", -- cannot start with digit
        "org.1freedesktop.DBus", -- subelement cannot start with digit
        "org.freedesktop.DBus-", -- cannot contain -
        "org.free-desktop.DBus", -- cannot contain -
    }

    local bad_member = {
        "",
        "TestMember-",
        "Test-Member",
        "-Test-Member",
        "1TestMember",
        "Test.Member",
    }

    local valid_path = {
        "/",
        "/org",
        "/org/freedesktop/DBus1",
    }

    local invalid_path = {
        "",
        "org/",
        "/org/",
        "/org//freedesktop",
        "/org/free-desktop",
    }

    local valid_argpath = {
        "/",
        "/aa",
        "/aa/",
        "/aa/bb/",
    }

    describe("match_rule.parse", function()
        it("accepts example rule", function()
            assert(match_rule.parse(example_match_rule))
        end)

        it("rejects invalid rule key", function()
            local ok, err = match_rule.parse("test='this should not work'")
            assert.falsy(ok)
            assert.equal(errors.validation.InvalidKey, err)
        end)

        it("accepts valid message type", function()
            for k, _ in pairs(match_rule._private.valid_msg_type) do
                assert.truthy(match_rule.parse(("type='%s'"):format(k)))
            end
        end)

        it("rejects invalid message type", function()
            local ok, err = match_rule.parse("type='bad_type'")
            assert.falsy(ok)
            assert.equal(errors.validation.InvalidMessageType, err)
        end)

        it("accepts sender with unique names", function()
            local unique = ":1.10"
            assert(match_rule.parse(("sender='%s'"):format(unique)))
        end)

        for _, v in ipairs(bad_sender) do
            it(("rejects sender with invalid unique names: '%s'"):format(v), function()
                local ok, err = match_rule.parse(("sender='%s'"):format(v))
                assert.falsy(ok)
                assert.equal(errors.validation.InvalidUniqueName, err)
            end)
        end

        it("accepts sender with well-known names", function()
            local well_known = "org.freedesktop.DBus1"
            assert(match_rule.parse(("sender='%s'"):format(well_known)))
        end)

        for _, v in ipairs(bad_wellknown) do
            it(("rejects sender with invalid well-known names: '%s'"):format(v), function()
                local ok, err = match_rule.parse(("sender='%s'"):format(v))
                assert.falsy(ok)
                assert.equal(errors.validation.InvalidBusName, err)
            end)
        end

        it("accepts valid interface", function()
            assert(match_rule.parse("interface='org.freedesktop.Interface'"))
        end)

        for _, v in ipairs(bad_interface) do
            it(("rejects invalid interface: '%s'"):format(v), function()
                local ok, err = match_rule.parse(("interface='%s'"):format(v))

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidInterfaceName, err)
            end)
        end

        it("accepts valid members", function()
            assert(match_rule.parse("member='TestMemeber'"))
        end)

        for _, v in ipairs(bad_member) do
            it(("rejects invalid members: '%s'"):format(v), function()
                local ok, err = match_rule.parse(("member='%s'"):format(v))

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidMemberName, err)
            end)
        end

        for _, v in ipairs(valid_path) do
            it(("accepts valid path: '%s'"):format(v), function()
                assert(match_rule.parse(("path='%s'"):format(v)))
            end)
        end

        for _, v in ipairs(invalid_path) do
            it(("rejects invalid path: '%s'"):format(v), function()
                local ok, err = match_rule.parse(("path='%s'"):format(v))

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidObjectPath, err)
            end)
        end

        for _, v in ipairs(valid_path) do
            it(("accepts valid path_namespace: '%s'"):format(v), function()
                assert(match_rule.parse(("path_namespace='%s'"):format(v)))
            end)
        end

        for _, v in ipairs(invalid_path) do
            it(("rejects invalid path_namespace: '%s'"):format(v), function()
                local ok, err = match_rule.parse(("path_namespace='%s'"):format(v))

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidObjectPath, err)
            end)
        end

        for _, v in ipairs(valid_unique) do
            it(("accepts valid destination: '%s'"):format(v), function()
                assert(match_rule.parse(("destination='%s'"):format(v)))
            end)
        end

        for _, v in ipairs(bad_unique) do
            it(("rejects invalid destination: '%s'"):format(v), function()
                local ok, err = match_rule.parse(("destination='%s'"):format(v))

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidUniqueName, err)
            end)
        end

        it("accepts valid args", function()
            assert(match_rule.parse("arg0='test'"))
        end)

        it("accepts several args", function()
            assert(match_rule.parse("arg0='test0',arg5='test5',arg63='test63'"))
        end)

        it("rejects too many args", function()
            local ok, err = match_rule.parse("arg64='toomany'")
            assert.falsy(ok)
            assert.equal(errors.validation.InvalidKey, err)

            ok, err = match_rule.parse("arg68='toomany'")
            assert.falsy(ok)
            assert.equal(errors.validation.InvalidKey, err)

            ok, err = match_rule.parse("arg0='ok',arg68='toomany'")
            assert.falsy(ok)
            assert.equal(errors.validation.InvalidKey, err)
        end)

        for _, v in ipairs(valid_argpath) do
            it(("accepts valid argspath: '%s'"):format(v), function()
                assert(match_rule.parse(("arg0path='%s'"):format(v)))
            end)
        end

        it("accepts several argspath", function()
            assert(match_rule.parse("arg0path='/',arg1path='/aa',arg63path='/aa/'"))
        end)

        it("rejects too many argspath", function()
            local ok, err = match_rule.parse("arg0path='/',arg64path='/aa',arg68path='/aa/'")

            assert.falsy(ok)
            assert.equal(errors.validation.InvalidKey, err)
        end)

        it("accepts valid arg0namespace: 'org'", function()
            assert(match_rule.parse("arg0namespace='org'"))
        end)

        it("accepts valid arg0namespace: 'org.freedesktop'", function()
            assert(match_rule.parse("arg0namespace='org.freedesktop'"))
        end)

        for _, v in ipairs(bad_arg0ns) do
            it(("rejects invalid arg0namespace: '%s'"):format(v), function()
                local ok, err = match_rule.parse(("arg0namespace='%s'"):format(v))

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidArgNamespace, err)
            end)
        end

        it("accepts valid eavesdrop", function()
            assert(match_rule.parse("eavesdrop='true'"))
            assert(match_rule.parse("eavesdrop='false'"))
        end)

        it("rejects invalid eavesdrop", function()
            local ok, err = match_rule.parse("eavesdrop='foo'")

            assert.falsy(ok)
            assert.equal(errors.validation.InvalidBoolean, err)
        end)
    end)

    describe("MatchRule:str", function()
        it("produces example rule", function()
            local rule = assert(match_rule.parse(example_match_rule))
            local output = assert(rule:str())
            assert.equal(example_match_rule, output)
        end)
    end)

    describe("MatchRule:match", function()
        it("matches message type", function()
            local signal = assert(messages.signal("/", "org.signal.Test", "TestSignal"))
            local method_call =
                assert(messages.method_call(nil, "/", "org.signal.Test", "TestSignal"))

            local builder = match_rule.builder()
            assert(builder:with_type(types.message_type.Signal))

            local rule = builder:build()

            assert.truthy(rule:match(signal))
            assert.falsy(rule:match(method_call))
        end)

        it("matches message unique sender", function()
            local unique_str = ":0.10"
            local other_unique = ":1.10"

            local signal = assert(messages.signal("/", "org.signal.Test", "TestSignal"))
            signal.header.sender = types.unique_name.from_str(unique_str)

            local rule = assert(match_rule.parse(("sender='%s'"):format(unique_str)))

            assert.truthy(rule:match(signal))
            signal.header.sender = assert(types.unique_name.from_str(other_unique))
            assert.falsy(rule:match(signal))
        end)

        it("ignores message wellknown sender", function()
            local unique_str = ":0.10"
            local sender = "org.testsender.WellKnown"

            local signal = assert(messages.signal("/", "org.signal.Test", "TestSignal"))
            signal.header.sender = types.unique_name.from_str(unique_str)

            local rule = assert(match_rule.parse(("sender='%s'"):format(sender)))

            assert.truthy(rule:match(signal))
        end)

        it("matches message interface", function()
            local interface = "org.testiface.Interface"
            local signal = assert(messages.signal("/", interface, "TestSignal"))

            local rule = assert(match_rule.parse(("interface='%s'"):format(interface)))

            assert.truthy(rule:match(signal))

            assert(signal:set_interface("org.other.InterfaceName"))
            assert.falsy(rule:match(signal))
        end)

        it("rejects message without interface", function()
            local interface = "org.testiface.Interface"
            local method_call = assert(messages.method_call(nil, "/", nil, "TestMethod"))

            local rule = assert(match_rule.parse(("interface='%s'"):format(interface)))
            assert.falsy(rule:match(method_call))
        end)

        it("matches message member", function()
            local member = "TestMember"
            local signal = assert(messages.signal("/", "org.test.Iface", member))

            local rule = assert(match_rule.parse(("member='%s'"):format(member)))
            assert.truthy(rule:match(signal))

            signal.header.member = types.member_name.from_str("TestMember2")
            assert.falsy(rule:match(signal))
        end)

        it("matches path", function()
            local path = "/org/test/signal"
            local signal = assert(messages.signal(path, "org.test.Signal", "TestSignal"))

            local rule = assert(match_rule.parse(("path='%s'"):format(path)))

            assert.truthy(rule:match(signal))

            signal.header.path = types.object_path.from_str("/org/test/other")
            assert.falsy(rule:match(signal))
        end)

        it("rejects path without exact match", function()
            local path = "/org/test"
            local signal = assert(messages.signal(path .. "/sub", "org.test.Signal", "TestSignal"))

            local rule = assert(match_rule.parse(("path='%s'"):format(path)))

            assert.falsy(rule:match(signal))
        end)

        it("matches path inside path_namespace", function()
            local ns = "/org/test"
            local signal = assert(messages.signal(ns, "org.test.Signal", "TestSignal"))

            local rule = assert(match_rule.parse(("path_namespace='%s'"):format(ns)))

            assert.truthy(rule:match(signal))

            signal.header.path = types.object_path.from_str(ns .. "/sub")
            assert.truthy(rule:match(signal))

            signal.header.path = types.object_path.from_str(ns .. "/sub/sub2")
            assert.truthy(rule:match(signal))

            signal.header.path = types.object_path.from_str("/org/foo")
            assert.falsy(rule:match(signal))
        end)

        it("matches unique destination", function()
            local unique = ":0.10"
            local signal = assert(messages.signal("/", "org.test.Signal", "Signal"))
            assert(signal:set_destination(unique))

            local rule = assert(match_rule.parse(("destination='%s'"):format(unique)))
            assert.truthy(rule:match(signal))

            assert(signal:set_destination(":0.5"))
            assert.falsy(rule:match(signal))
        end)

        it("ignores well-known destination", function()
            local wellknown = "org.test.Destination"
            local unique = ":0.10"
            local signal = assert(messages.signal("/", "org.test.Signal", "Signal"))
            assert(signal:set_destination(wellknown))

            local rule = assert(match_rule.parse(("destination='%s'"):format(unique)))
            assert.truthy(rule:match(signal))
        end)

        it("Matches one string arguments", function()
            local pack = {}

            for i = 0, 63 do
                local str = types.String("TestArg" .. tostring(i))
                table.insert(pack, str)
            end

            local body = assert(types.Struct(pack))
            local signal = assert(messages.signal("/", "org.test.Signal", "Signal", body))

            for i = 0, 63 do
                local arg = "TestArg" .. tostring(i)
                local rule = assert(match_rule.parse(("arg%d='%s'"):format(i, arg)))

                assert.truthy(rule:match(signal))
            end

            local rule = assert(match_rule.parse("arg0='foo'"))
            assert.falsy(rule:match(signal))
        end)

        it("Matches several string arguments", function()
            local pack = {
                types.Int32(5),
            }

            for i = 1, 63 do
                local str = types.String("TestArg" .. tostring(i))
                table.insert(pack, str)
            end

            local body = assert(types.Struct(pack))
            local signal = assert(messages.signal("/", "org.test.Signal", "Signal", body))

            local rule =
                assert(match_rule.parse("arg1='TestArg1',arg5='TestArg5',arg63='TestArg63'"))
            assert.truthy(rule:match(signal))

            rule = assert(match_rule.parse("arg0='foo',arg5='TestArg5',arg63='TestArg63'"))
            assert.falsy(rule:match(signal))
        end)

        it("rejects non string for argX", function()
            local body = assert(types.Struct({
                types.String("TestArg"),
                types.ObjectPath("/test/object/Path"),
                types.Int32(5),
            }))

            local signal = assert(messages.signal("/", "org.test.Signal", "Signal", body))

            local rule = assert(match_rule.parse("arg1='/test/object/Path'"))
            assert.falsy(rule:match(signal))

            rule = assert(match_rule.parse("arg2='5'"))
            assert.falsy(rule:match(signal))
        end)

        it("matches argpath exactly", function()
            local body = types.Struct({
                types.String("teststring"),
                types.String("/arg/path"),
                types.String("/arg/wildcard/"),
                types.ObjectPath("/obj/path"),
            })

            local signal = assert(messages.signal("/", "org.test.Signal", "Signal", body))
            local rule = assert(
                match_rule.parse(
                    "arg1path='/arg/path',arg2path='/arg/wildcard/',arg3path='/obj/path'"
                )
            )
            assert.truthy(rule:match(signal))

            rule = assert(
                match_rule.parse(
                    "arg1path='/ar/path',arg2path='/arg/wildcard/',arg3path='/obj/path'"
                )
            )
            assert.falsy(rule:match(signal))
        end)

        --example from the spec
        local wildcard = "/aa/bb/"
        local wildcard_result = {
            { types.ObjectPath("/"), true },
            { types.String("/"), true },
            { types.String("/aa/"), true },
            { types.String("/aa/bb/"), true },
            { types.String("/aa/bb/cc/"), true },
            { types.ObjectPath("/aa/bb/cc"), true },
            { types.String("/aa/bb/cc"), true },
            { types.ObjectPath("/aa"), false },
            { types.String("/aa"), false },
            { types.ObjectPath("/aa/b"), false },
            { types.String("/aa/b"), false },
            { types.ObjectPath("/aa/bb"), false },
            { types.String("/aa/bb"), false },
            { types.ObjectPath("/aa/dd"), false },
            { types.String("/aa/dd"), false },
        }
        for _, v in ipairs(wildcard_result) do
            local pattern = v[1]
            local expectation = v[2]

            it(
                ("handles with wildcard argpaths: '%s' -> %q"):format(pattern:get(), expectation),
                function()
                    local body = types.Struct({
                        pattern,
                        pattern,
                        pattern,
                    })

                    local signal = assert(messages.signal("/", "org.test.Signal", "Signal", body))

                    for i = 0, 2 do
                        local m_str = ("arg%dpath='%s'"):format(i, wildcard)
                        local rule = assert(match_rule.parse(m_str))

                        if expectation then
                            assert.truthy(rule:match(signal))
                        else
                            assert.falsy(rule:match(signal))
                        end
                    end
                end
            )
        end

        it("matches arg0namespace exactly", function()
            local namespace = "org.namespace.Main"
            local body = types.Struct({
                types.String(namespace),
            })
            local signal = assert(messages.signal("/", "org.test.Signal", "Signal", body))
            local rule = assert(match_rule.parse(("arg0namespace='%s'"):format(namespace)))
            assert.truthy(rule:match(signal))

            signal.body[1] = "org.other_namespace.Main"
            assert.falsy(rule:match(signal))
        end)

        it("matches arg0namespace subvalue", function()
            local namespace = "org.namespace.Main"
            local body = types.Struct({
                types.String(namespace .. ".Sub"),
            })
            local signal = assert(messages.signal("/", "org.test.Signal", "Signal", body))
            local rule = assert(match_rule.parse(("arg0namespace='%s'"):format(namespace)))
            assert.truthy(rule:match(signal))
        end)
    end)

    describe("match_rule.Builder", function()
        it("accepts valid message type", function()
            for k, _ in pairs(match_rule._private.valid_msg_type) do
                local builder = match_rule.builder()
                assert(builder:with_type(k))
                local rule = builder:build()
                assert.equal(("type='%s'"):format(k), rule:str())
            end
        end)

        it("rejects invalid message type", function()
            local builder = match_rule.builder()
            local ok, err = builder:with_type("bad_type")
            assert.falsy(ok)
            assert.equal(err, errors.validation.InvalidMessageType)
        end)

        it("accepts sender with unique names", function()
            local unique = ":1.10"

            local builder = match_rule.builder()
            assert(builder:with_sender(unique))
            local rule = builder:build()

            assert.equal(("sender='%s'"):format(unique), rule:str())
        end)

        for _, v in ipairs(bad_sender) do
            it(("rejects sender with invalid unique names: '%s'"):format(v), function()
                local builder = match_rule.builder()
                local ok, err = builder:with_sender(v)

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidUniqueName, err)
            end)
        end

        it("accepts sender with well-known names", function()
            local well_known = "org.freedesktop.DBus1"

            local builder = match_rule.builder()
            assert(builder:with_sender(well_known))

            local rule = builder:build()

            assert.equal(("sender='%s'"):format(well_known), rule:str())
        end)

        for _, v in ipairs(bad_wellknown) do
            it(("rejects sender with invalid well-known names: '%s'"):format(v), function()
                local builder = match_rule.builder()
                local ok, err = builder:with_sender(v)

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidBusName, err)
            end)
        end

        it("accepts valid interface", function()
            local iface = "org.freedesktop.Interface"

            local builder = match_rule:builder()
            assert(builder:with_interface(iface))

            local rule = builder:build()
            assert.equal(("interface='%s'"):format(iface), rule:str())
        end)

        for _, v in ipairs(bad_interface) do
            it(("rejects invalid interface: '%s'"):format(v), function()
                local builder = match_rule:builder()
                local ok, err = builder:with_interface(v)

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidInterfaceName, err)
            end)
        end

        it("accepts valid members", function()
            local member = "TestMember"

            local builder = match_rule.builder()
            assert(builder:with_member(member))

            local rule = builder:build()
            assert.equal(("member='%s'"):format(member), rule:str())
        end)

        for _, v in ipairs(bad_member) do
            it(("rejects invalid members: '%s'"):format(v), function()
                local builder = match_rule:builder()
                local ok, err = builder:with_member(v)

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidMemberName, err)
            end)
        end

        for _, v in ipairs(valid_path) do
            it(("accepts valid path: '%s'"):format(v), function()
                local builder = match_rule.builder()

                assert(builder:with_path(v))
                local rule = builder:build()

                assert(("path='%s'"):format(v), rule:str())
            end)
        end

        for _, v in ipairs(invalid_path) do
            it(("rejects invalid path: '%s'"):format(v), function()
                local builder = match_rule.builder()

                local ok, err = builder:with_path(v)

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidObjectPath, err)
            end)
        end

        for _, v in ipairs(valid_path) do
            it(("accepts valid path_namespace: '%s'"):format(v), function()
                local builder = match_rule.builder()

                assert(builder:with_path_namespace(v))
                local rule = builder:build()

                assert(("path_namespace='%s'"):format(v), rule:str())
            end)
        end

        for _, v in ipairs(invalid_path) do
            it(("rejects invalid path_namespace: '%s'"):format(v), function()
                local builder = match_rule.builder()

                local ok, err = builder:with_path_namespace(v)

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidObjectPath, err)
            end)
        end

        it("discards path_namespace when path is set", function()
            local path_namespace = "/org/freedesktop"
            local path = "/org/freedesktop/DBus"

            local builder = match_rule.builder()
            assert(builder:with_path_namespace(path_namespace))
            assert(builder:with_path("/org/freedesktop/DBus"))

            local rule = builder:build()
            assert.equal(("path='%s'"):format(path), rule:str())
        end)

        it("discards path_namespace when path is set", function()
            local path_namespace = "/org/freedesktop"
            local path = "/org/freedesktop/DBus"

            local builder = match_rule.builder()
            assert(builder:with_path(path))
            assert(builder:with_path_namespace(path_namespace))

            local rule = builder:build()
            assert.equal(("path_namespace='%s'"):format(path_namespace), rule:str())
        end)

        for _, v in ipairs(valid_unique) do
            it(("accepts valid destination: '%s'"):format(v), function()
                local builder = match_rule.builder()

                assert(builder:with_destination(v))

                local rule = builder:build()
                assert.equal(("destination='%s'"):format(v), rule:str())
            end)
        end

        for _, v in ipairs(bad_unique) do
            it(("rejects invalid destination: '%s'"):format(v), function()
                local builder = match_rule.builder()
                local ok, err = builder:with_destination(v)

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidUniqueName, err)
            end)
        end

        it("accepts valid args", function()
            local builder = match_rule.builder()
            assert(builder:with_arg(5, "test5"))

            local rule = builder:build()
            assert.equal("arg5='test5'", rule:str())
        end)

        it("accepts several args", function()
            local builder = match_rule.builder()

            assert(builder:with_arg(5, "test5"))
            assert(builder:with_arg(0, "test0"))
            assert(builder:with_arg(63, "test63"))

            local rule = builder:build()
            assert.equal("arg0='test0',arg5='test5',arg63='test63'", rule:str())
        end)

        it("rejects too many args", function()
            local builder = match_rule.builder()

            local ok, err = builder:with_arg(64, "test64")
            assert.falsy(ok)
            assert.equal(errors.validation.InvalidArgIndex, err)

            ok, err = builder:with_arg(68, "test64")
            assert.falsy(ok)
            assert.equal(errors.validation.InvalidArgIndex, err)
        end)

        for _, v in ipairs(valid_argpath) do
            it(("accepts valid argspath: '%s'"):format(v), function()
                local builder = match_rule.builder()

                assert(builder:with_arg_path(0, v))

                local rule = builder:build()
                assert.equal(("arg0path='%s'"):format(v), rule:str())
            end)
        end

        it("accepts several argspath", function()
            local builder = match_rule.builder()

            assert(builder:with_arg_path(0, "/"))
            assert(builder:with_arg_path(1, "/aa"))
            assert(builder:with_arg_path(63, "/aa/bb"))

            local rule = builder:build()
            assert.equal("arg0path='/',arg1path='/aa',arg63path='/aa/bb'", rule:str())
        end)

        it("rejects too many argspath", function()
            local builder = match_rule.builder()

            local ok, err = builder:with_arg_path(64, "/aa/bb")

            assert.falsy(ok)
            assert.equal(errors.validation.InvalidArgIndex, err)
        end)

        it("accepts valid arg0namespace: 'org'", function()
            local builder = match_rule.builder()

            assert(builder:with_arg0namespace("org"))

            local rule = builder:build()
            assert.equal("arg0namespace='org'", rule:str())
        end)

        it("accepts valid arg0namespace: 'org.freedesktop'", function()
            local builder = match_rule.builder()

            assert(builder:with_arg0namespace("org.freedesktop"))

            local rule = builder:build()
            assert.equal("arg0namespace='org.freedesktop'", rule:str())
        end)

        for _, v in ipairs(bad_arg0ns) do
            it(("rejects invalid arg0namespace: '%s'"):format(v), function()
                local builder = match_rule.builder()

                local ok, err = builder:with_arg0namespace(v)

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidArgNamespace, err)
            end)
        end

        it("accepts valid eavesdrop", function()
            local input = {
                true,
                false,
                "true",
                "false",
            }

            for _, v in ipairs(input) do
                local builder = match_rule.builder()

                assert(builder:with_eavesdrop(v))
                local rule = builder:build()

                assert.equal(("eavesdrop='%s'"):format(v), rule:str())
            end
        end)

        it("discards eavesdrop if nil", function()
            local builder = match_rule.builder()

            assert(builder:with_type("signal"))
            assert(builder:with_eavesdrop(true))
            assert(builder:with_eavesdrop(nil))

            local rule = builder:build()

            assert.equal("type='signal'", rule:str())
        end)

        it("rejects invalid eavesdrop", function()
            local builder = match_rule.builder()

            local ok, err = builder:with_eavesdrop("foo")

            assert.falsy(ok)
            assert.equal(errors.validation.InvalidBoolean, err)
        end)
    end)
end)
