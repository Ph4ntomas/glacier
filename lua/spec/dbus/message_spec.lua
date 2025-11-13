describe("glacier.dbus.message", function()
    local errors = require("glacier.dbus.errors")
    ---@type glacier.dbus.message
    local message
    local types = require("glacier.dbus.type")

    ---@type ldbus
    local ldbus = require("ldbus")

    setup(function()
        _G._TEST = true
        message = require("glacier.dbus.message")
    end)

    teardown(function()
        _G._TEST = nil
    end)

    describe("glacier.dbus.message.body.from_ldbus", function()
        it("extracts basic type", function()
            local msg = ldbus.message.new("signal")
            local iter_mut = msg:iter_init_append()

            iter_mut:append_basic("test", "s")

            local iter = assert(msg:iter_init())

            local sig = types.signature.from_str(assert(msg:get_signature()))
            local body = message.body._basic_from_ldbus(sig:get_field()[1], iter)

            assert.same(types.String("test"), body)
        end)

        it("extracts empty array", function()
            local msg = ldbus.message.new("signal")
            local iter_mut = msg:iter_init_append()
            local sub = iter_mut:open_container("a", "i")
            iter_mut:close_container(sub)

            local iter = assert(msg:iter_init())

            local sig = types.signature.from_str(assert(msg:get_signature()))
            local body = message.body._array_from_ldbus(sig:get_field()[1], iter, 0, 0)

            assert.same(types.Array(types.Int32), body)
        end)

        it("extracts array of basic", function()
            local msg = ldbus.message.new("signal")
            local iter_mut = msg:iter_init_append()

            local sub = iter_mut:open_container("a", "i")
            sub:append_basic(10, "i")
            sub:append_basic(15, "i")
            sub:append_basic(20, "i")
            iter_mut:close_container(sub)

            local iter = assert(msg:iter_init())

            local sig = types.signature.from_str(assert(msg:get_signature()))
            local body = message.body._array_from_ldbus(sig:get_field()[1], iter, 0, 0)

            local arr = types.Array(types.Int32)
            arr:set({ 10, 15, 20 })
            assert.same(arr, body)
        end)

        it("extracts struct of basic", function()
            local msg = ldbus.message.new("signal")

            local iter_mut = msg:iter_init_append()

            local sub = iter_mut:open_container("r")
            sub:append_basic("test")
            sub:append_basic(10)
            iter_mut:close_container(sub)

            local iter = assert(msg:iter_init())

            local sig = types.signature.from_str(assert(msg:get_signature()))
            local body = message.body._struct_from_ldbus(sig:get_field()[1], iter, 0, 0)

            local expect = types.Struct({
                types.String("test"),
                types.Int64(10),
            })
            assert.same(expect, body)
        end)

        it("extracts struct of struct", function()
            local msg = ldbus.message.new("signal")

            local iter_mut = msg:iter_init_append()

            local sub = iter_mut:open_container("r")
            sub:append_basic("test")

            local sub2 = sub:open_container("r")
            sub2:append_basic("inner")
            sub:close_container(sub2)

            sub:append_basic(10)
            iter_mut:close_container(sub)

            local iter = assert(msg:iter_init())

            local sig = types.signature.from_str(assert(msg:get_signature()))
            local body = message.body._struct_from_ldbus(sig:get_field()[1], iter, 0, 0)

            local expect = types.Struct({
                types.String("test"),
                types.Struct({
                    types.String("inner"),
                }),
                types.Int64(10),
            })

            assert.same(expect, body)
        end)

        it("extracts array of struct", function()
            local msg = ldbus.message.new("signal")
            local iter_mut = msg:iter_init_append()

            local sub = iter_mut:open_container("a", "(ii)")
            local inner = sub:open_container("r")
            inner:append_basic(10, "i")
            inner:append_basic(15, "i")
            sub:close_container(inner)

            inner = sub:open_container("r")
            inner:append_basic(20, "i")
            inner:append_basic(25, "i")
            sub:close_container(inner)
            iter_mut:close_container(sub)

            local iter = assert(msg:iter_init())

            local sig = types.signature.from_str(assert(msg:get_signature()))
            local body = message.body._array_from_ldbus(sig:get_field()[1], iter, 0, 0)

            local expect = types.Array({
                types.Struct({ types.Int32(10), types.Int32(15) }),
                types.Struct({ types.Int32(20), types.Int32(25) }),
            })

            assert.same(expect, body)
        end)

        it("extracts dict_entry", function()
            local msg = ldbus.message.new("signal")

            local iter_mut = msg:iter_init_append()

            local sub = iter_mut:open_container("e")
            sub:append_basic(10, "i")
            sub:append_basic("ten")
            iter_mut:close_container(sub)

            local iter = assert(msg:iter_init())

            local sig = types.signature.Dict("i", types.signature.basic.String)
            local body = { message.body._dict_entry_from_ldbus(sig:get_array(), iter, 0, 0) }

            assert.same({ types.Int32(10), types.String("ten") }, body)
        end)

        it("extracts dict", function()
            local msg = ldbus.message.new("signal")

            local iter_mut = msg:iter_init_append()

            local dict = iter_mut:open_container("a", "{si}")
            local entry = dict:open_container("e")
            entry:append_basic("ten")
            entry:append_basic(10, "i")
            dict:close_container(entry)
            iter_mut:close_container(dict)

            local iter = assert(msg:iter_init())

            local sig = types.signature.from_str(assert(msg:get_signature()))

            local body = message.body._dict_from_ldbus(sig:get_field()[1], iter, 0, 0)

            local expect = types.Dict(types.String, types.Int32)
            expect["ten"] = 10
            assert.same(expect, body)
        end)

        it("extracts empty dict", function()
            local msg = ldbus.message.new("signal")

            local iter_mut = msg:iter_init_append()

            local dict = iter_mut:open_container("a", "{si}")
            iter_mut:close_container(dict)

            local iter = assert(msg:iter_init())

            local sig = types.signature.from_str(assert(msg:get_signature()))

            local body = message.body._dict_from_ldbus(sig:get_field()[1], iter, 0, 0)

            assert.same(types.Dict(types.String, types.Int32), body)
        end)

        it("extracts dict of struct", function()
            local msg = ldbus.message.new("signal")

            local iter_mut = msg:iter_init_append()
            local dict = iter_mut:open_container("a", "{i(is)}")

            local entry = dict:open_container("e")
            entry:append_basic(1, "i")
            local struct = entry:open_container("r")
            struct:append_basic(1, "i")
            struct:append_basic("one", "s")
            entry:close_container(struct)
            dict:close_container(entry)

            entry = dict:open_container("e")
            entry:append_basic(2, "i")
            struct = entry:open_container("r")
            struct:append_basic(2, "i")
            struct:append_basic("two", "s")
            entry:close_container(struct)
            dict:close_container(entry)

            iter_mut:close_container(dict)

            local iter = assert(msg:iter_init())
            local sig = types.signature.from_str(assert(msg:get_signature()))

            local body = message.body._dict_from_ldbus(sig:get_field()[1], iter, 0, 0)

            local expect = types.Dict({
                [types.Int32(1)] = types.Struct({
                    types.Int32(1),
                    types.String("one"),
                }),
                [types.Int32(2)] = types.Struct({
                    types.Int32(2),
                    types.String("two"),
                }),
            })

            assert.same(expect, body)
        end)

        it("extracts array of dict", function()
            local msg = ldbus.message.new("signal")

            local iter_mut = msg:iter_init_append()
            local array = iter_mut:open_container("a", "a{i(is)}")

            local dict = array:open_container("a", "{i(is)}")

            local entry = dict:open_container("e")
            entry:append_basic(1, "i")
            local struct = entry:open_container("r")
            struct:append_basic(1, "i")
            struct:append_basic("one", "s")
            entry:close_container(struct)
            dict:close_container(entry)

            entry = dict:open_container("e")
            entry:append_basic(2, "i")
            struct = entry:open_container("r")
            struct:append_basic(2, "i")
            struct:append_basic("two", "s")
            entry:close_container(struct)
            dict:close_container(entry)

            array:close_container(dict)

            dict = array:open_container("a", "{i(is)}")

            entry = dict:open_container("e")
            entry:append_basic(3, "i")
            struct = entry:open_container("r")
            struct:append_basic(3, "i")
            struct:append_basic("three", "s")
            entry:close_container(struct)
            dict:close_container(entry)

            entry = dict:open_container("e")
            entry:append_basic(4, "i")
            struct = entry:open_container("r")
            struct:append_basic(4, "i")
            struct:append_basic("four", "s")
            entry:close_container(struct)
            dict:close_container(entry)

            array:close_container(dict)

            iter_mut:close_container(array)

            local iter = assert(msg:iter_init())
            local sig = types.signature.from_str(assert(msg:get_signature()))

            local body = message.body._array_from_ldbus(sig:get_field()[1], iter, 0, 0)
            local expect = types.Array({
                types.Dict({
                    [types.Int32(1)] = types.Struct({
                        types.Int32(1),
                        types.String("one"),
                    }),
                    [types.Int32(2)] = types.Struct({
                        types.Int32(2),
                        types.String("two"),
                    }),
                }),
                types.Dict({
                    [types.Int32(3)] = types.Struct({
                        types.Int32(3),
                        types.String("three"),
                    }),
                    [types.Int32(4)] = types.Struct({
                        types.Int32(4),
                        types.String("four"),
                    }),
                }),
            })

            assert.same(expect, body)
        end)

        it("extracts variant", function()
            local msg = ldbus.message.new("signal")

            local iter_mut = msg:iter_init_append()

            local variant = iter_mut:open_container("v", "(iis)")
            local struct = variant:open_container("r")
            struct:append_basic(10, "i")
            struct:append_basic(15, "i")
            struct:append_basic("test", "s")

            variant:close_container(struct)
            iter_mut:close_container(variant)

            local iter = assert(msg:iter_init())

            local sig = types.signature.from_str(assert(msg:get_signature()))
            local body = message.body._variant_from_ldbus(sig:get_field()[1], iter, 0)

            local expect = types.Variant(types.Struct({
                types.Int32(10),
                types.Int32(15),
                types.String("test"),
            }))

            assert.same(expect, body)
        end)

        it("rejects struct in deep variant", function()
            local msg = ldbus.message.new("signal")

            local iter_mut = msg:iter_init_append()

            local variant = iter_mut:open_container("v", "(iis)")
            local struct = variant:open_container("r")
            struct:append_basic(10, "i")
            struct:append_basic(15, "i")
            struct:append_basic("test", "s")

            variant:close_container(struct)
            iter_mut:close_container(variant)

            local iter = assert(msg:iter_init())

            local sig = types.signature.from_str(assert(msg:get_signature()))
            local get_body = function()
                return message.body._variant_from_ldbus(sig:get_field()[1], iter, 0, 31)
            end

            assert.has_error(get_body, "Message too deep")
        end)

        it("extracts message without body", function()
            local signal = ldbus.message.new_signal("/test/Object", "test.object.Source", "Signal")

            local deser = message.from_ldbus(signal)

            assert.is_nil(deser.body)
        end)

        it("extracts message with a single argument", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")

            local iter_mut = msg:iter_init_append()
            iter_mut:append_basic(10, "i")

            local deser = message.from_ldbus(msg)

            local expect = types.Struct({
                types.Int32(10),
            })

            assert.same(expect, deser.body)
        end)

        it("extracts message with a single compount argument", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")

            local iter_mut = msg:iter_init_append()
            local struct = iter_mut:open_container("r")
            struct:append_basic(10, "i")
            iter_mut:close_container(struct)

            local deser = message.from_ldbus(msg)

            local expect = types.Struct({
                types.Struct({
                    types.Int32(10),
                }),
            })

            assert.same(expect, deser.body)
        end)

        it("extracts message with multiple arguments", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")

            local iter_mut = msg:iter_init_append()
            iter_mut:append_basic("pre", "s")
            local struct = iter_mut:open_container("r")
            struct:append_basic(10, "i")
            struct:append_basic(20, "i")
            struct:append_basic("test", "s")
            iter_mut:close_container(struct)
            iter_mut:append_basic("/org/freedesktop/DBus", "o")

            local deser = message.from_ldbus(msg)

            local expect = types.Struct({
                types.String("pre"),
                types.Struct({
                    types.Int32(10),
                    types.Int32(20),
                    types.String("test"),
                }),
                types.ObjectPath("/org/freedesktop/DBus"),
            })

            assert.same(expect, deser.body)
        end)
    end)

    describe("glacier.dbus.message.body.to_ldbus", function()
        it("serialize basic type", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._basic_to_ldbus(types.Int32(5), iter_mut)

            local iter = assert(msg:iter_init())

            local expect_sig = "i"
            assert.equal(expect_sig, msg:get_signature())

            assert.equal("i", iter:get_arg_type())
            assert.equal(5, iter:get_basic())
            assert.falsy(iter:has_next())
        end)

        it("serialize empty array", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._array_to_ldbus(types.Array(types.Int32), iter_mut, 0, 0)

            local iter = assert(msg:iter_init())

            local expect_sig = "ai"
            assert.equal(expect_sig, msg:get_signature())

            assert.equal("a", iter:get_arg_type())
            assert.equal("i", iter:get_element_type())

            local rec = iter:recurse()
            assert.falsy(rec:get_arg_type())
            assert.falsy(iter:has_next())
        end)

        it("serialize array of basic", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._array_to_ldbus(
                types.Array({
                    types.Int32(0),
                    types.Int32(1),
                    types.Int32(2),
                }),
                iter_mut,
                0,
                0
            )

            local iter = assert(msg:iter_init())

            local expect_sig = "ai"
            assert.equal(expect_sig, msg:get_signature())

            assert.equal("a", iter:get_arg_type())
            assert.equal("i", iter:get_element_type())

            local rec = iter:recurse()

            assert.equal("i", rec:get_arg_type())

            assert.equal(0, rec:get_basic())
            assert(rec:next())
            assert.equal(1, rec:get_basic())
            assert(rec:next())
            assert.equal(2, rec:get_basic())

            assert.falsy(rec:has_next())
            assert.falsy(iter:has_next())
        end)

        it("rejects array too deep", function()
            local array = types.Array({ types.Int32(5) })

            for _ = 2, 32 do
                array = types.Array({ array })
            end

            local body_ok = types.Struct({ array })
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            message.body.to_ldbus(body_ok, msg) -- this one should work

            local body_ko = types.Struct({ types.Array({ array }) })
            msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local should_fail = function()
                message.body.to_ldbus(body_ko, msg)
            end

            assert.has_error(should_fail, errors.type.TooNested)
        end)

        it("serialize a struct of basic", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._struct_to_ldbus(
                types.Struct({
                    types.Int32(0),
                    types.String("foo"),
                    types.Boolean(true),
                }),
                iter_mut,
                0,
                0
            )

            local iter = assert(msg:iter_init())

            local expect_sig = "(isb)"
            assert.equal(expect_sig, msg:get_signature())

            assert.equal("r", iter:get_arg_type())

            local rec = iter:recurse()

            assert.equal("i", rec:get_arg_type())
            assert.equal(0, rec:get_basic())
            assert(rec:next())

            assert.equal("s", rec:get_arg_type())
            assert.equal("foo", rec:get_basic())
            assert(rec:next())

            assert.equal("b", rec:get_arg_type())
            assert.equal(true, rec:get_basic())
            assert.falsy(rec:has_next())

            assert.falsy(iter:has_next())
        end)

        it("serialize struct of struct", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._struct_to_ldbus(
                types.Struct({
                    types.Int32(0),
                    types.Struct({
                        types.String("foo"),
                        types.ObjectPath("/org/freedesktop"),
                    }),
                    types.Byte(8),
                }),
                iter_mut,
                0,
                0
            )

            local iter = assert(msg:iter_init())
            local expect_sig = "(i(so)y)"
            assert.equal(expect_sig, msg:get_signature())

            assert.equal("r", iter:get_arg_type())

            local rec = iter:recurse()

            assert.equal("i", rec:get_arg_type())
            assert.equal(0, rec:get_basic())
            assert(rec:next())

            assert.equal("r", rec:get_arg_type())

            local inner = rec:recurse()

            assert.equal("s", inner:get_arg_type())
            assert.equal("foo", inner:get_basic())
            assert(inner:next())

            assert.equal("o", inner:get_arg_type())
            assert.equal("/org/freedesktop", inner:get_basic())
            assert.falsy(inner:next())

            assert(rec:next())

            assert.equal("y", rec:get_arg_type())
            assert.equal(8, rec:get_basic())
            assert.falsy(rec:next())
        end)

        it("rejects struct too deep", function()
            local struct = types.Struct({ types.Int32(5) })

            for _ = 2, 32 do
                struct = types.Struct({ struct })
            end

            local body_ok = types.Struct({ struct })
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            message.body.to_ldbus(body_ok, msg) -- this one should work

            local body_ko = types.Struct({ types.Struct({ struct }) })
            msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local should_fail = function()
                message.body.to_ldbus(body_ko, msg)
            end

            assert.has_error(should_fail, errors.type.TooNested)
        end)

        it("serialize deepest construct", function()
            local struct = types.Struct({ types.Int32(5) })

            for _ = 2, 32 do
                struct = types.Struct({ struct })
            end

            ---@type glacier.dbus.type.StrongType
            local array = struct
            for _ = 1, 32 do
                array = types.Array({ array })
            end

            local body_ok = types.Struct({ array })
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            message.body.to_ldbus(body_ok, msg) -- this one should work

            ---lets ensure that one more struct make the whole thing fail.
            struct = types.Struct({ struct })
            array = struct
            for _ = 1, 32 do
                array = types.Array({ array })
            end

            local body_ko = types.Struct({ array })
            msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            message.body.to_ldbus(body_ok, msg) -- this one should work
            local should_fail = function()
                message.body.to_ldbus(body_ko, msg)
            end

            assert.has_error(should_fail, errors.type.TooNested)
        end)

        it("serialize array of struct", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._array_to_ldbus(
                types.Array({
                    types.Struct({
                        types.String("foo"),
                        types.ObjectPath("/org/freedesktop"),
                    }),
                    types.Struct({
                        types.String("bar"),
                        types.ObjectPath("/org/freedesktop/bar"),
                    }),
                }),
                iter_mut,
                0,
                0
            )

            local iter = assert(msg:iter_init())
            local expect_sig = "a(so)"
            assert.equal(expect_sig, msg:get_signature())

            assert.equal("a", iter:get_arg_type())

            local array = iter:recurse()

            assert.equal("r", array:get_arg_type())

            local struct = array:recurse()

            assert.equal("s", struct:get_arg_type())
            assert.equal("foo", struct:get_basic())
            assert(struct:next())

            assert.equal("o", struct:get_arg_type())
            assert.equal("/org/freedesktop", struct:get_basic())
            assert.falsy(struct:next())

            assert(array:next())

            assert.equal("r", array:get_arg_type())

            struct = array:recurse()

            assert.equal("s", struct:get_arg_type())
            assert.equal("bar", struct:get_basic())
            assert(struct:next())

            assert.equal("o", struct:get_arg_type())
            assert.equal("/org/freedesktop/bar", struct:get_basic())
            assert.falsy(struct:next())

            assert.falsy(array:next())
        end)

        it("serialize empty dict", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._dict_to_ldbus(types.Dict(types.Int32, types.Int32), iter_mut, 0, 0)

            local iter = assert(msg:iter_init())
            local expect_sig = "a{ii}"
            assert.equal(expect_sig, msg:get_signature())

            assert.equal("a", iter:get_arg_type())
            local dict = assert(iter:recurse())

            assert.falsy(dict:get_arg_type())
            assert.falsy(iter:has_next())
        end)

        it("serialize dict of basic", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._dict_to_ldbus(
                types.Dict({
                    [types.Int32(1)] = types.String("foo"),
                    [types.Int32(2)] = types.String("bar"),
                }),
                iter_mut,
                0,
                0
            )

            local iter = assert(msg:iter_init())
            local expect_sig = "a{is}"
            assert.equal(expect_sig, msg:get_signature())

            assert.equal("a", iter:get_arg_type())
            local dict = assert(iter:recurse())

            assert.equal("e", dict:get_arg_type())
            local entry = assert(dict:recurse())

            assert.equal("i", entry:get_arg_type())
            assert.equal(1, entry:get_basic())
            assert(entry:next())

            assert.equal("s", entry:get_arg_type())
            assert.equal("foo", entry:get_basic())

            assert.falsy(entry:next())

            assert(dict:next())

            assert.equal("e", dict:get_arg_type())
            entry = assert(dict:recurse())

            assert.equal("i", entry:get_arg_type())
            assert.equal(2, entry:get_basic())
            assert(entry:next())

            assert.equal("s", entry:get_arg_type())
            assert.equal("bar", entry:get_basic())

            assert.falsy(entry:next())
            assert.falsy(dict:next())

            assert.falsy(iter:has_next())
        end)

        it("serialize dict of struct", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._dict_to_ldbus(
                types.Dict({
                    [types.Int32(1)] = types.Struct({
                        types.String("foo"),
                        types.ObjectPath("/foo"),
                    }),
                    [types.Int32(2)] = types.Struct({
                        types.String("bar"),
                        types.ObjectPath("/bar"),
                    }),
                }),
                iter_mut,
                0,
                0
            )

            local iter = assert(msg:iter_init())
            local expect_sig = "a{i(so)}"
            assert.equal(expect_sig, msg:get_signature())

            assert.equal("a", iter:get_arg_type())
            local dict = assert(iter:recurse())

            assert.equal("e", dict:get_arg_type())
            local entry = assert(dict:recurse())

            assert.equal("i", entry:get_arg_type())
            assert.equal(1, entry:get_basic())
            assert(entry:next())

            assert.equal("r", entry:get_arg_type())
            local struct = entry:recurse()

            assert.equal("s", struct:get_arg_type())
            assert.equal("foo", struct:get_basic())
            assert(struct:next())

            assert.equal("o", struct:get_arg_type())
            assert.equal("/foo", struct:get_basic())
            assert.falsy(struct:next())

            assert.falsy(entry:next())

            assert(dict:next())

            assert.equal("e", dict:get_arg_type())
            entry = assert(dict:recurse())

            assert.equal("i", entry:get_arg_type())
            assert.equal(2, entry:get_basic())
            assert(entry:next())

            assert.equal("r", entry:get_arg_type())
            struct = entry:recurse()

            assert.equal("s", struct:get_arg_type())
            assert.equal("bar", struct:get_basic())
            assert(struct:next())

            assert.equal("o", struct:get_arg_type())
            assert.equal("/bar", struct:get_basic())
            assert.falsy(struct:next())

            assert.falsy(entry:next())

            assert.falsy(dict:next())
            assert.falsy(iter:next())
        end)

        it("serialize variant basic", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._variant_to_ldbus(types.Variant(types.Int32(5)), iter_mut, 0, 0)

            local iter = assert(msg:iter_init())
            local expect_sig = "v"
            assert.equal(expect_sig, msg:get_signature())

            local var = assert(iter:recurse())

            assert.equal("i", var:get_arg_type())
            assert.equal(5, var:get_basic())
            assert.falsy(var:next())
            assert.falsy(iter:next())
        end)

        it("serialize variant compound", function()
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local iter_mut = msg:iter_init_append()

            message.body._variant_to_ldbus(
                types.Variant(types.Struct({
                    types.Int32(5),
                    types.String("foo"),
                })),
                iter_mut,
                0,
                0
            )

            local iter = assert(msg:iter_init())
            local expect_sig = "v"
            assert.equal(expect_sig, msg:get_signature())

            local var = assert(iter:recurse())

            assert.equal("r", var:get_arg_type())
            local struct = assert(var:recurse())

            assert.equal("i", struct:get_arg_type())
            assert.equal(5, struct:get_basic())
            assert(struct:next())

            assert.equal("s", struct:get_arg_type())
            assert.equal("foo", struct:get_basic())
            assert.falsy(struct:next())

            assert.falsy(var:next())
            assert.falsy(iter:next())
        end)

        it("reject structs in deep variant", function()
            ---@type glacier.dbus.type.StrongType
            local struct = types.Variant(types.Struct({
                types.Int32(0),
            }))

            for _ = 1, 31 do
                struct = types.Struct({ struct })
            end

            local body_ok = types.Struct({ struct })
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            message.body.to_ldbus(body_ok, msg) -- this one should work

            local body_ko = types.Struct({ types.Struct({ struct }) })
            msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local should_fail = function()
                message.body.to_ldbus(body_ko, msg)
            end

            assert.has_error(should_fail, errors.type.TooNested)
        end)

        it("reject array in deep variant", function()
            ---@type glacier.dbus.type.StrongType
            local array = types.Variant(types.Array({
                types.Int32(0),
            }))

            for _ = 1, 31 do
                array = types.Array({ array })
            end

            local body_ok = types.Struct({ array })
            local msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            message.body.to_ldbus(body_ok, msg) -- this one should work

            local body_ko = types.Struct({ types.Array({ array }) })
            msg = ldbus.message.new_signal("/test/object", "test.object.Source", "Signal")
            local should_fail = function()
                message.body.to_ldbus(body_ko, msg)
            end

            assert.has_error(should_fail, errors.type.TooNested)
        end)
    end)
end)
