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
                assert.equals(v, sign:str())
            end)
        end

        it("rejects unkown types", function()
            local sig = "z"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.UnknownType, err)
        end)

        it("supports variant", function()
            local sign = assert(types.signature.try_from_str("v"))
            assert.equals("v", sign:str())
        end)

        it("supports simple array", function()
            local sig = "ai"
            local sign = types.signature.from_str(sig)
            assert.equals(sig, sign:str())
        end)

        it("supports nested array", function()
            local sig = "aai"
            local sign = types.signature.from_str(sig)

            assert.equals(sig, sign:str())
        end)

        it("supports 32 deep nested array", function()
            local sig = string.rep("a", 32) .. "i"
            local sign = types.signature.from_str(sig)

            assert.equals(sig, sign:str())
        end)

        it("rejects array without types", function()
            local sig = "a"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.MissingType, err)
        end)

        it("rejects #array without types", function()
            local sig = "az"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.UnknownType, err)
        end)

        it("rejects nested array without types", function()
            local sig = string.rep("a", 3)

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.MissingType, err)
        end)

        it("rejects array too deep", function()
            local sig = string.rep("a", 33) .. "i"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.TooNested, err)
        end)

        it("supports simple struct", function()
            local sign = types.signature.from_str("(i)")
            assert.equals("(i)", sign:str())
        end)

        it("rejects empty strucs", function()
            local sig = "()"

            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equals(errors.signature.EmptyStruct, err)
        end)

        it("rejects #struct with unknowntype ", function()
            local sig = "(z)"

            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equals(errors.signature.UnknownType, err)
        end)

        it("rejects unterminated struct: single", function()
            local sig = "(ii"
            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equals(errors.signature.IncompleteType, err)
        end)

        it("rejects unterminated struct: nested", function()
            local sig = "(i(ii)i"
            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equals(errors.signature.IncompleteType, err)
        end)

        it("supports nested struct", function()
            local sig = "(i((i)i))"

            local sign = types.signature.from_str(sig)
            assert.equals(sig, sign:str())
        end)

        it("supports up to 32 deep struct", function()
            local lpar = string.rep("(i", 32)
            local rpar = string.rep("i)", 32)
            local sig = lpar .. rpar

            local sign = types.signature.from_str(sig)
            assert.equals(sig, sign:str())
        end)

        it("rejects struct that are too deep", function()
            local lpar = string.rep("(i", 33)
            local rpar = string.rep("i)", 33)
            local sig = lpar .. rpar

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.TooNested, err)
        end)

        it("supports array in struct", function()
            local sig = "(bay)"

            local sign = types.signature.from_str(sig)

            assert.equals(sig, sign:str())
        end)

        it("supports struct in array", function()
            local sig = "a(by)"

            local sign = types.signature.from_str(sig)
            assert.equals(sig, sign:str())
        end)

        it("accepts complex nested types: max array & struct", function()
            local lpar = string.rep("a(i", 32)
            local rpar = string.rep("i)", 32)
            local sig = lpar .. rpar

            local sign = types.signature.from_str(sig)
            assert.equals(sig, sign:str())
        end)

        it("rejects complex nested types: too many array", function()
            local sig = "a" .. "(i(y(" .. string.rep("a", 32) .. "(yii))))"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.TooNested, err)
        end)

        it("rejects complex nested types: too many struct", function()
            local nested = string.rep("(i", 32) .. string.rep("i)", 32)
            local sig = "(iaaa" .. nested .. ")"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.TooNested, err)
        end)

        it("supports simple #dict", function()
            local sign = types.signature.from_str("a{ii}")
            assert.equals("a{ii}", sign:str())
        end)

        it("rejects #dict enty with one element", function()
            local sig = "a{i}"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.InvalidEntry, err)
        end)

        it("rejects #dict entry with more than 2 elements", function()
            local sig = "a{iii}"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.InvalidEntry, err)
        end)

        it("rejects #dict entry with unknown keys", function()
            local sig = "a{zi}"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.NonBasicKey, err)
        end)

        it("rejects #dict entry with unknown values", function()
            local sig = "a{iz}"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.UnknownType, err)
        end)

        it("rejects unterminated #dict entries", function()
            local sig = "a{ii"

            local ok, err = types.signature.try_from_str(sig)
            assert.falsy(ok)
            assert.equals(errors.signature.IncompleteType, err)
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
                assert.equals(errors.signature.NonBasicKey, err)
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
                assert.equals(errors.signature.DictEntryOutsideArray, err)
            end)
        end

        it("reject mismatch #struct #dict ending: dict in struct", function()
            local sig = "(a{ii)}"
            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equals(errors.signature.IncompleteType, err)
        end)

        it("reject mismatch #struct #dict ending: struct in dict", function()
            local sig = "a{i(i})"
            local ok, err = types.signature.try_from_str(sig)

            assert.falsy(ok)
            assert.equals(errors.signature.IncompleteType, err)
        end)

        it("accept uncontained sequences (`ii`)", function()
            local sig = "ii"
            local sign, err = types.signature.from_str(sig)

            assert.equals(sig, sign:str())
        end)

        it("accepts up to 255 chars", function()
            local sig = ("(%s)"):format(string.rep("i", 253))
            local sign = assert(types.signature.try_from_str(sig))

            assert.equals(sig, sign:str())
        end)

        it("rejects empty signature", function()
            local sig, err = types.signature.try_from_str("")

            assert.falsy(sig)
            assert.equals(errors.signature.MissingType, err)
        end)

        it("rejects too long signature", function()
            local sig = ("(%s)"):format(string.rep("i", 254))

            local sign, err = types.signature.try_from_str(sig)

            assert.falsy(sign)
            assert.equals(errors.validation.SignatureTooLong, err)
        end)
    end)
end)
