local operation = {}

operation.focusable = {
    FOCUS = "focusable::focus",
    UNFOCUS = "focusable::unfocus",

    Focus = function(id)
        return { operation = operation.focusable.FOCUS, id = id }
    end,
    Unfocus = function()
        return { operation = operation.focusable.UNFOCUS }
    end,
}

return operation
