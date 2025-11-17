describe("glacier.dbus.type", function()
    ---@type glacier.dbus.type
    local types
    local errors = require("glacier.dbus.errors")

    setup(function()
        _G._TEST = true
        types = require("glacier.dbus.type")
    end)

    describe("glacier.dbus.type.signature", function()
        for k, v in pairs(types.signature.basic_type) do
            it("supports basic type: " .. k, function()
                local sign = assert(types.signature.try_from_str(v))
                assert.equal(v, sign:str())
            end)
        end

        it("rejects unkown types", function()
            local sig = "z"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.UnknownType, err)
        end)

        it("supports variant", function()
            local sign = assert(types.signature.try_from_str("v"))
            assert.equal("v", sign:str())
        end)

        it("supports simple array", function()
            local sig = "ai"
            local sign = types.signature.from_str(sig)
            assert.equal(sig, sign:str())
        end)

        it("supports nested array", function()
            local sig = "aai"
            local sign = types.signature.from_str(sig)

            assert.equal(sig, sign:str())
        end)

        it("supports 32 deep nested array", function()
            local sig = string.rep("a", 32) .. "i"
            local sign = types.signature.from_str(sig)

            assert.equal(sig, sign:str())
        end)

        it("rejects array without types", function()
            local sig = "a"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.MissingType, err)
        end)

        it("rejects #array without types", function()
            local sig = "az"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.UnknownType, err)
        end)

        it("rejects nested array without types", function()
            local sig = string.rep("a", 3)

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.MissingType, err)
        end)

        it("rejects array too deep", function()
            local sig = string.rep("a", 33) .. "i"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.TooNested, err)
        end)

        it("supports simple struct", function()
            local sign = types.signature.from_str("(i)")
            assert.equal("(i)", sign:str())
        end)

        it("rejects empty strucs", function()
            local sig = "()"

            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equal(errors.signature.EmptyStruct, err)
        end)

        it("rejects #struct with unknowntype ", function()
            local sig = "(z)"

            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equal(errors.signature.UnknownType, err)
        end)

        it("rejects unterminated struct: single", function()
            local sig = "(ii"
            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equal(errors.signature.IncompleteType, err)
        end)

        it("rejects unterminated struct: nested", function()
            local sig = "(i(ii)i"
            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equal(errors.signature.IncompleteType, err)
        end)

        it("supports nested struct", function()
            local sig = "(i((i)i))"

            local sign = types.signature.from_str(sig)
            assert.equal(sig, sign:str())
        end)

        it("supports up to 32 deep struct", function()
            local lpar = string.rep("(i", 32)
            local rpar = string.rep("i)", 32)
            local sig = lpar .. rpar

            local sign = types.signature.from_str(sig)
            assert.equal(sig, sign:str())
        end)

        it("rejects struct that are too deep", function()
            local lpar = string.rep("(i", 33)
            local rpar = string.rep("i)", 33)
            local sig = lpar .. rpar

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.TooNested, err)
        end)

        it("supports array in struct", function()
            local sig = "(bay)"

            local sign = types.signature.from_str(sig)

            assert.equal(sig, sign:str())
        end)

        it("supports struct in array", function()
            local sig = "a(by)"

            local sign = types.signature.from_str(sig)
            assert.equal(sig, sign:str())
        end)

        it("accepts complex nested types: max array & struct", function()
            local lpar = string.rep("a(i", 32)
            local rpar = string.rep("i)", 32)
            local sig = lpar .. rpar

            local sign = types.signature.from_str(sig)
            assert.equal(sig, sign:str())
        end)

        it("rejects complex nested types: too many array", function()
            local sig = "a" .. "(i(y(" .. string.rep("a", 32) .. "(yii))))"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.TooNested, err)
        end)

        it("rejects complex nested types: too many struct", function()
            local nested = string.rep("(i", 32) .. string.rep("i)", 32)
            local sig = "(iaaa" .. nested .. ")"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.TooNested, err)
        end)

        it("supports simple #dict", function()
            local sign = types.signature.from_str("a{ii}")
            assert.equal("a{ii}", sign:str())
        end)

        it("rejects #dict enty with one element", function()
            local sig = "a{i}"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.InvalidEntry, err)
        end)

        it("rejects #dict entry with more than 2 elements", function()
            local sig = "a{iii}"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.InvalidEntry, err)
        end)

        it("rejects #dict entry with unknown keys", function()
            local sig = "a{zi}"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.NonBasicKey, err)
        end)

        it("rejects #dict entry with unknown values", function()
            local sig = "a{iz}"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.UnknownType, err)
        end)

        it("rejects unterminated #dict entries", function()
            local sig = "a{ii"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equal(errors.signature.IncompleteType, err)
        end)

        local reject_dict_keys = {
            ["variant"] = "a{vi}",
            ["array"] = "a{aii}",
            ["struct"] = "a{(ii)i}",
        }
        for k, v in pairs(reject_dict_keys) do
            it("#dict rejects compound key: " .. k, function()
                local sig = v

                local ok, err = types.signature.try_from_str(sig)

                assert.falsy(ok)
                assert.equal(errors.signature.NonBasicKey, err)
            end)
        end

        local dict_tests = {
            ["Standalone"] = "{ii}",
            ["In struct"] = "({ii})",
            ["After Array"] = "(ai{ii})",
            ["In array of struct"] = "a({ii})",
        }
        for case, sigstr in pairs(dict_tests) do
            it("#dict rejects dict_entry outside array: " .. case, function()
                local ok, err = types.signature.try_from_str(sigstr)

                assert.falsy(ok)
                assert.equal(errors.signature.DictEntryOutsideArray, err)
            end)
        end

        it("reject mismatch #struct #dict ending: dict in struct", function()
            local sig = "(a{ii)}"
            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equal(errors.signature.IncompleteType, err)
        end)

        it("reject mismatch #struct #dict ending: struct in dict", function()
            local sig = "a{i(i})"
            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equal(errors.signature.IncompleteType, err)
        end)

        it("accept uncontained sequences (`ii`)", function()
            local sig = "ii"
            local sign, _ = types.signature.from_str(sig)

            assert.equal(sig, sign:str())
        end)

        it("accepts up to 255 chars", function()
            local sig = ("(%s)"):format(string.rep("i", 253))
            local sign = assert(types.signature.try_from_str(sig))

            assert.equal(sig, sign:str())
        end)

        it("rejects empty signature", function()
            local sig, err = types.signature.try_from_str("")

            assert.falsy(sig)
            assert.equal(errors.signature.MissingType, err)
        end)

        it("rejects too long signature", function()
            local sig = ("(%s)"):format(string.rep("i", 254))

            local sign, err = types.signature.try_from_str(sig)

            assert.falsy(sign)
            assert.equal(errors.validation.SignatureTooLong, err)
        end)
    end)

    describe("glacier.dbus.type.StrongType", function()
        local TestType = types._private.strong_type.StrongType:new_type("TestType")

        function TestType:new(v)
            return self:super({ value = v })
        end

        it("isnt value when uninitialized", function()
            assert.falsy(TestType:is_value())
        end)

        it("is value when initialized", function()
            assert.truthy(TestType(10):is_value())
        end)
    end)

    describe("glacier.dbus.type.StrongContainer", function()
        ---@class TestType:glacier.dbus.type.StrongContainer
        local TestType = types._private.strong_type.StrongContainer:new_type("TestType")

        function TestType:new(v)
            return self:super({ value = v })
        end

        it("isnt value when uninitialized", function()
            assert.falsy(TestType:is_value())
        end)

        it("is value when initialized", function()
            assert.truthy(TestType(10):is_value())
        end)
    end)

    describe("glacier.dbus.type.Boolean", function()
        it("is a strong type", function()
            local b = types.Boolean(true)

            assert.truthy(types.is_strong_type(b))
        end)

        it("checks the object type: Boolean", function()
            local b = types.Boolean(false)
            assert.truthy(b:is(types.Boolean))
        end)

        it("has the correct signature", function()
            local b = types.Boolean(false)

            local sig = assert(b:signature())

            assert.same(types.signature.basic.Boolean, sig)
            assert.equal(types.signature.basic_type.boolean, sig:str())
        end)
    end)

    describe("glacier.dbus.type.Byte", function()
        it("is a strong type", function()
            local b = types.Byte(0)

            assert.truthy(types.is_strong_type(b))
        end)

        it("checks the object type: Byte", function()
            local b = types.Byte(0)
            assert.truthy(b:is(types.Byte))
        end)

        it("has the correct signature", function()
            local b = types.Byte(0)

            local sig = assert(b:signature())

            assert.same(types.signature.basic.Byte, sig)
            assert.equal(types.signature.basic_type.byte, sig:str())
        end)

        it("Fails if constructed with incorrect type", function()
            assert.has_error(function()
                types.Byte("test")
            end, errors.type.Invalid)
        end)

        it("Fails if set with incorrect type", function()
            local b = types.Byte(0)

            assert.has_error(function()
                ---@diagnostic disable-next-line: param-type-mismatch
                b:set("test")
            end, errors.type.Invalid)
        end)

        it("rejects negative values", function()
            assert.has_error(function()
                types.Byte(-1)
            end, errors.type.Range)

            local b = types.Byte(0)
            assert.has_error(function()
                b:set(-5)
            end, errors.type.Range)
        end)

        it("rejects out of range values", function()
            assert.has_error(function()
                types.Byte(256)
            end, errors.type.Range)

            local b = types.Byte(0)
            assert.has_error(function()
                b:set(256)
            end, errors.type.Range)
        end)
    end)

    describe("glacier.dbus.type.Int16", function()
        it("is a strong type", function()
            local b = types.Int16(0)

            assert.truthy(types.is_strong_type(b))
        end)

        it("checks the object type: Int16", function()
            local b = types.Int16(0)
            assert.truthy(b:is(types.Int16))
        end)

        it("has the correct signature", function()
            local b = types.Int16(0)

            local sig = assert(b:signature())

            assert.same(types.signature.basic.Int16, sig)
            assert.equal(types.signature.basic_type.int16, sig:str())
        end)

        it("Fails if constructed with incorrect type", function()
            assert.has_error(function()
                types.Int16("test")
            end, errors.type.Invalid)
        end)

        it("Fails if set with incorrect type", function()
            local b = types.Int16(0)

            assert.has_error(function()
                ---@diagnostic disable-next-line: param-type-mismatch
                b:set("test")
            end, errors.type.Invalid)
        end)

        it("rejects out of range values", function()
            assert.has_error(function()
                types.Int16(2 ^ 15)
            end, errors.type.Range)
            assert.has_error(function()
                types.Int16(-2 ^ 15 - 1)
            end, errors.type.Range)

            local b = types.Int16(0)
            assert.has_error(function()
                b:set(2 ^ 15)
            end, errors.type.Range)
            assert.has_error(function()
                b:set(-2 ^ 15 - 1)
            end, errors.type.Range)
        end)
    end)

    describe("glacier.dbus.type.UInt16", function()
        it("is a strong type", function()
            local b = types.UInt16(0)

            assert.truthy(types.is_strong_type(b))
        end)

        it("checks the object type: UInt16", function()
            local b = types.UInt16(0)
            assert.truthy(b:is(types.UInt16))
        end)

        it("has the correct signature", function()
            local b = types.UInt16(0)

            local sig = assert(b:signature())

            assert.same(types.signature.basic.UInt16, sig)
            assert.equal(types.signature.basic_type.uint16, sig:str())
        end)

        it("Fails if constructed with incorrect type", function()
            assert.has_error(function()
                types.UInt16("test")
            end, errors.type.Invalid)
        end)

        it("Fails if set with incorrect type", function()
            local b = types.UInt16(0)

            assert.has_error(function()
                ---@diagnostic disable-next-line: param-type-mismatch
                b:set("test")
            end, errors.type.Invalid)
        end)

        it("rejects negative values", function()
            assert.has_error(function()
                types.UInt16(-1)
            end, errors.type.Range)

            local b = types.UInt16(0)
            assert.has_error(function()
                b:set(-5)
            end, errors.type.Range)
        end)

        it("rejects out of range values", function()
            assert.has_error(function()
                types.UInt16(2 ^ 16 + 1)
            end, errors.type.Range)

            local b = types.UInt16(0)
            assert.has_error(function()
                b:set(2 ^ 16 + 1)
            end, errors.type.Range)
        end)
    end)

    describe("glacier.dbus.type.Int32", function()
        it("is a strong type", function()
            local b = types.Int32(0)

            assert.truthy(types.is_strong_type(b))
        end)

        it("checks the object type: Int32", function()
            local b = types.Int32(0)
            assert.truthy(b:is(types.Int32))
        end)

        it("has the correct signature", function()
            local b = types.Int32(0)

            local sig = assert(b:signature())

            assert.same(types.signature.basic.Int32, sig)
            assert.equal(types.signature.basic_type.int32, sig:str())
        end)

        it("Fails if constructed with incorrect type", function()
            assert.has_error(function()
                types.Int32("test")
            end, errors.type.Invalid)
        end)

        it("Fails if set with incorrect type", function()
            local b = types.Int32(0)

            assert.has_error(function()
                ---@diagnostic disable-next-line: param-type-mismatch
                b:set("test")
            end, errors.type.Invalid)
        end)

        it("rejects out of range values", function()
            assert.has_error(function()
                types.Int32(2 ^ 31)
            end, errors.type.Range)
            assert.has_error(function()
                types.Int32(-2 ^ 31 - 1)
            end, errors.type.Range)

            local b = types.Int32(0)
            assert.has_error(function()
                b:set(2 ^ 31)
            end, errors.type.Range)
            assert.has_error(function()
                b:set(-2 ^ 31 - 1)
            end, errors.type.Range)
        end)
    end)

    describe("glacier.dbus.type.UInt32", function()
        it("is a strong type", function()
            local b = types.UInt32(0)

            assert.truthy(types.is_strong_type(b))
        end)

        it("checks the object type: UInt32", function()
            local b = types.UInt32(0)
            assert.truthy(b:is(types.UInt32))
        end)

        it("has the correct signature", function()
            local b = types.UInt32(0)

            local sig = assert(b:signature())

            assert.same(types.signature.basic.UInt32, sig)
            assert.equal(types.signature.basic_type.uint32, sig:str())
        end)

        it("Fails if constructed with incorrect type", function()
            assert.has_error(function()
                types.UInt32("test")
            end, errors.type.Invalid)
        end)

        it("Fails if set with incorrect type", function()
            local b = types.UInt32(0)

            assert.has_error(function()
                ---@diagnostic disable-next-line: param-type-mismatch
                b:set("test")
            end, errors.type.Invalid)
        end)

        it("rejects negative values", function()
            assert.has_error(function()
                types.UInt32(-1)
            end, errors.type.Range)

            local b = types.UInt32(0)
            assert.has_error(function()
                b:set(-5)
            end, errors.type.Range)
        end)

        it("rejects out of range values", function()
            assert.has_error(function()
                types.UInt32(2 ^ 32 + 1)
            end, errors.type.Range)

            local b = types.UInt32(0)
            assert.has_error(function()
                b:set(2 ^ 32 + 1)
            end, errors.type.Range)
        end)
    end)

    describe("glacier.dbus.type.Int64", function()
        it("is a strong type", function()
            local b = types.Int64(0)

            assert.truthy(types.is_strong_type(b))
        end)

        it("checks the object type: Int64", function()
            local b = types.Int64(0)
            assert.truthy(b:is(types.Int64))
        end)

        it("has the correct signature", function()
            local b = types.Int64(0)

            local sig = assert(b:signature())

            assert.same(types.signature.basic.Int64, sig)
            assert.equal(types.signature.basic_type.int64, sig:str())
        end)

        it("Fails if constructed with incorrect type", function()
            assert.has_error(function()
                types.Int64("test")
            end, errors.type.Invalid)
        end)

        it("Fails if set with incorrect type", function()
            local b = types.Int64(0)

            assert.has_error(function()
                ---@diagnostic disable-next-line: param-type-mismatch
                b:set("test")
            end, errors.type.Invalid)
        end)

        it("rejects out of range values", function()
            assert.has_error(function()
                types.Int64(2 ^ 64)
            end, errors.type.Range)
            assert.has_error(function()
                types.Int64(-2 ^ 64)
            end, errors.type.Range)

            local b = types.Int64(0)
            assert.has_error(function()
                b:set(2 ^ 64)
            end, errors.type.Range)
            assert.has_error(function()
                b:set(-2 ^ 64 - 1)
            end, errors.type.Range)
        end)
    end)

    describe("glacier.dbus.type.UInt64", function()
        it("is a strong type", function()
            local b = types.UInt64(0)

            assert.truthy(types.is_strong_type(b))
        end)

        it("checks the object type: UInt64", function()
            local b = types.UInt64(0)

            assert.truthy(b:is(types.UInt64))
        end)

        it("has the correct signature", function()
            local b = types.UInt64(0)

            local sig = assert(b:signature())

            assert.same(types.signature.basic.UInt64, sig)
            assert.equal(types.signature.basic_type.uint64, sig:str())
        end)

        it("Fails if constructed with incorrect type", function()
            assert.has_error(function()
                types.UInt64("test")
            end, errors.type.Invalid)
        end)

        it("Fails if set with incorrect type", function()
            local b = types.UInt64(0)

            assert.has_error(function()
                ---@diagnostic disable-next-line: param-type-mismatch
                b:set("test")
            end, errors.type.Invalid)
        end)

        it("rejects out of range values", function()
            assert.has_error(function()
                types.UInt64(2 ^ 64 + 1)
            end, errors.type.Range)

            local b = types.UInt64(0)
            assert.has_error(function()
                b:set(2 ^ 64 + 1)
            end, errors.type.Range)
        end)
    end)

    describe("glacier.dbus.type.Array", function()
        it("is a strong type", function()
            local a = types.Array(types.Int32)

            assert.truthy(types.is_strong_type(a))
        end)

        it("is a container", function()
            local a = types.Array(types.Int32)

            assert.truthy(a:is_container())
        end)

        it("can be built from an array of strong types", function()
            local _ = types.Array({ types.Int32(0), types.Int32(1) })
        end)

        it("can convert standard array", function()
            local a = assert(types.Array(types.Int32))

            a:set({ 1, 2, 3, 4, 5 })
        end)

        it("supports indexing", function()
            local a = assert(types.Array({ types.Int32(0), types.Int32(1) }))

            assert.same(types.Int32(0), a[1])
            assert.same(types.Int32(1), a[2])
        end)

        it("support assignment", function()
            local a = types.Array({ types.Int32(0) })
            a[1] = 2

            local inner = a:get()

            assert.same(types.Int32(2), inner[1])
        end)

        it("supports inserting", function()
            local a = types.Array({ types.Int32(0) })

            table.insert(a, 1, types.Int32(1))

            assert.same(types.Int32(1), a[1])
            assert.same(types.Int32(0), a[2])
        end)

        it("supports appending", function()
            local a = types.Array({ types.Int32(0) })
            table.insert(a, types.Int32(1))

            assert.same(types.Int32(0), a[1])
            assert.same(types.Int32(1), a[2])
        end)

        it("fails if constructed from disjointed types", function()
            assert.has_error(function()
                types.Array({ types.Int32(0), types.Boolean(true) })
            end, errors.type.Invalid)
        end)

        it("can be nested", function()
            local _ = types.Array({
                types.Array({ types.Int32(0) }),
            })
        end)

        it("has the correct signature", function()
            local a = types.Array({
                types.Array({ types.Int32(0) }),
            })

            local sig = types.signature.Array(types.signature.Array(types.signature.basic.Int32))

            assert.equal(sig, a:signature())
            assert.equal("aai", a:signature():str())
        end)
    end)

    describe("glacier.dbus.type.Struct", function()
        it("is a strong type", function()
            local s = types.Struct({ types.Int32(0) })

            assert.truthy(types.is_strong_type(s))
        end)

        it("is a container", function()
            local s = types.Struct({ types.Int32(0) })

            assert.truthy(s:is_container())
        end)

        it("can be nested", function()
            local _ = types.Struct({ types.Struct({ types.Int32(0) }), types.Int32(1) })
        end)

        it("has the correct signature", function()
            local s = types.Struct({ types.Struct({ types.Int32(0) }), types.Int32(1) })

            local sig = types.signature.Struct({
                types.signature.Struct({ types.signature.basic.Int32 }),
                types.signature.basic.Int32,
            })

            assert.equal(sig, s:signature())
            assert.equal("(i)i", s:signature():str())
        end)
    end)

    describe("glacier.dbus.type.Dict", function()
        it("is a strong type", function()
            local d = types.Dict(types.String, types.Int32)

            assert.truthy(types.is_strong_type(d))
        end)

        it("is a container", function()
            local d = types.Dict(types.String, types.Int32)

            assert.truthy(d:is_container())
        end)

        it("can be created from table", function()
            local _ = types.Dict({
                [types.String("test")] = types.Int32(4),
                [types.String("foo")] = types.Int32(3),
            })
        end)

        it("can contain containers as value", function()
            local String = types.String
            local Struct = types.Struct
            local Int32 = types.Int32

            local _ = types.Dict({
                [String("test")] = Struct({ Int32(0), String("zero") }),
                [String("foo")] = Struct({ Int32(1), String("one") }),
                [String("bar")] = Struct({ Int32(2), String("two") }),
            })
        end)

        it("has the correct signature", function()
            local String = types.String
            local Struct = types.Struct
            local Int32 = types.Int32

            local d = types.Dict({
                [String("test")] = Struct({ Int32(0), String("zero") }),
                [String("foo")] = Struct({ Int32(1), String("one") }),
                [String("bar")] = Struct({ Int32(2), String("two") }),
            })

            local sig = types.signature.from_str("a{s(is)}"):get_field()[1]

            assert.equal(sig, d:signature())
            assert.equal("a{s(is)}", d:signature():str())
        end)

        it("can be indexed", function()
            local String = types.String
            local Int32 = types.Int32

            local d = types.Dict({
                [String("foo")] = Int32(0),
                [String("bar")] = Int32(1),
                [String("baz")] = Int32(2),
            })

            assert.same(Int32(0), d["foo"])
            assert.same(Int32(1), d["bar"])
            assert.same(Int32(2), d["baz"])
        end)
    end)

    describe("glacier.dbus.type.Variant", function()
        it("is a strong type", function()
            local v = types.Variant(types.String("variant"))

            assert.truthy(types.is_strong_type(v))
        end)

        it("is a container", function()
            local v = types.Variant(types.String("variant"))

            assert.truthy(types.is_strong_type(v))
        end)

        it("has the expected signature", function()
            local v = types.Variant(types.String("variant"))
            local sig = types.signature.Variant

            assert.equal(sig, v:signature())
            assert.equal("v", v:signature():str())
        end)

        it("Can check the inner type", function()
            local v = types.Variant(types.String("variant"))
            assert.truthy(v:inner_is(types.String))
        end)

        it("Can return the inner type", function()
            local v = types.Variant(types.String("variant"))
            assert.equal(types.String, v:get_inner_type())
        end)

        it("can hold another type after creation", function()
            local v = types.Variant(types.String("variant"))
            assert.truthy(v:inner_is(types.String))
            v:set(types.Int32(0))
            assert.truthy(v:inner_is(types.Int32))
        end)
    end)

    describe("glacier.dbus.type.UniqueName", function()
        it("Accept bus name", function()
            local _ = types.unique_name.from_str("org.freedesktop.DBus")
            assert(types.unique_name.try_from_str("org.freedesktop.DBus"))
        end)

        local bad_unique = {
            "",
            ":1/10",
            ":1.10/",
        }

        for _, v in ipairs(bad_unique) do
            it(("rejects invalid name: %s"):format(v), function()
                local ok, err = types.unique_name.try_from_str(v)
                assert.falsy(ok)
                assert.equal(err, errors.validation.InvalidUniqueName)
            end)
        end
    end)

    describe("glacier.dbus.type.WellKnownName", function()
        local bad_name = {
            "",
            "org",
            ".",
            "org.",
            ".org.freedesktop.DBus",
            "1org.freedesktop.DBus",
            "org.freedesktop/DBus",
        }

        for _, v in ipairs(bad_name) do
            it(("rejects invalid well-known names: '%s'"):format(v), function()
                local ok, err = types.well_known_name.try_from_str(v)
                assert.falsy(ok)
                assert.equal(err, errors.validation.InvalidBusName)
            end)
        end
    end)

    describe("glacier.dbus.type.ObjectPath", function()
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

        for _, v in ipairs(valid_path) do
            it(("accepts valid path: '%s'"):format(v), function()
                assert(types.object_path.try_from_str(v))
            end)
        end

        for _, v in ipairs(invalid_path) do
            it(("rejects invalid path: '%s'"):format(v), function()
                local ok, err = types.object_path.try_from_str(v)

                assert.falsy(ok)
                assert.equal(errors.validation.InvalidObjectPath, err)
            end)
        end
    end)
end)
