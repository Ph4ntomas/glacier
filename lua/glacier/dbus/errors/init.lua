---@class glacier.dbus.errors
local errors = {
    MissingParameter = "Missing Parameter.",
}

---@enum glacier.dbus.errors.validation
errors.validation = {
    InvalidKey = "Invalid Key.",
    InvalidMessageType = "Invalid Message Type.",
    InvalidInterfaceName = "InvalidInterfaceName.",
    InvalidMemberName = "Invalid Member name.",
    InvalidArgIndex = "Only argument indexes from 0 to 63 are valid.",
    InvalidObjectPath = "Invalid Object Path.",
    InvalidUniqueName = "Invalid Unique Name.",
    InvalidWellKnownName = "Invalid WellKnown Name.",
    InvalidBusName = "Invalid Bus Name.",
    InvalidArgNamespace = "Invalid Arg0Namespace.",
    InvalidBoolean = "Invalid Boolean.",
    SignatureTooLong = "Signature too long. Signatures are restricted to 255 cahracters.",
    NameTooLong = "Name too long. Names are restricted to 255 characters.",
    BadFormat = "Invalid format.",
}

local sig_prefix = "Invalid Signature: "

---@enum glacier.dbus.errors.signature
errors.signature = {
    TrailingCharacter = "Invalid Signature: Unexpected trailing characters.",
    UnknownType = "Invalid Signature: Unknown Type.",
    MissingType = "Invalid Signature: Missing Type.",
    IncompleteType = "Invalid Signature: Incomplete Type.",
    EmptyStruct = "Invalid Signature: Empty Structure.",
    NonBasicKey = "Invalid Signature: Only basic types are allowed in DictEntry.",
    InvalidEntry = "Invalid Signature: DictEntry should have exactly two elements.",
    DictEntryOutsideArray = sig_prefix .. "DictEntry cannot appear outside array.",
    TooNested = "Invalid Signature: Maximum depth of container nesting is 32.",
}

---@enum glacier.dbus.errors.type
errors.type = {
    ExpectedValue = "ExpectedValue.",
    Invalid = "InvalidType",
    InvalidKey = "InvalidKey. Dict Keys must be basic types.",
    FieldsDontMatch = "Fields don't match",
    NoSignature = "Inner type signature must be known at that point.",
    Range = "RangeError",
    TooNested = "Message too deep",
}

return errors
