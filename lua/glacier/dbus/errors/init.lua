---@class glacier.dbus.errors
local errors = {
    InternalError = "Internal Error",
    Expired = "Object expired",
    MissingParameter = "Missing Parameter",
    ObjectNotFound = "Object not found",
    InterfaceNotFound = "Interface not found",
    Unimplemented = "Unimplemented",
    UnknownSignal = "Unknown signal",
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

---Standard DBus Errors
---@enum glacier.dbus.errors.DBus
errors.dbus = {
    Failed = "org.freedesktop.DBus.Error.Failed",
    NoMemory = "org.freedesktop.DBus.Error.NoMemory",
    ServiceUnknown = "org.freedesktop.DBus.Error.ServiceUnknown",
    NameHasNoOwner = "org.freedesktop.DBus.Error.NameHasNoOwner",
    NoReply = "org.freedesktop.DBus.Error.NoReply",
    IoError = "org.freedesktop.DBus.Error.IOError",
    BadAddress = "org.freedesktop.DBus.Error.BadAddress",
    NotSupported = "org.freedesktop.DBus.Error.NotSupported",
    LimitsExceeded = "org.freedesktop.DBus.Error.LimitsExceeded",
    AccessDenied = "org.freedesktop.DBus.Error.AccessDenied",
    AuthFailed = "org.freedesktop.DBus.Error.AuthFailed",
    NoServer = "org.freedesktop.DBus.Error.NoServer",
    Timeout = "org.freedesktop.DBus.Error.Timeout",
    NoNetwork = "org.freedesktop.DBus.Error.NoNetwork",
    AddressInUse = "org.freedesktop.DBus.Error.AddressInUse",
    Disconnected = "org.freedesktop.DBus.Error.Disconnected",
    InvalidArgs = "org.freedesktop.DBus.Error.InvalidArgs",
    FileNotFound = "org.freedesktop.DBus.Error.FileNotFound",
    FileExists = "org.freedesktop.DBus.Error.FileExists",
    UnknownMethod = "org.freedesktop.DBus.Error.UnknownMethod",
    UnknownObject = "org.freedesktop.DBus.Error.UnknownObject",
    UnknownInterface = "org.freedesktop.DBus.Error.UnknownInterface",
    UnknownProperty = "org.freedesktop.DBus.Error.UnknownProperty",
    PropertyReadOnly = "org.freedesktop.DBus.Error.PropertyReadOnly",
    TimedOut = "org.freedesktop.DBus.Error.TimedOut",
    MatchRuleNotFound = "org.freedesktop.DBus.Error.MatchRuleNotFound",
    MatchRuleInvalid = "org.freedesktop.DBus.Error.MatchRuleInvalid",
    ---@enum glacier.dbus.errors.DBus.Spawn
    spawn = {
        ExecFailed = "org.freedesktop.DBus.Error.Spawn.ExecFailed",
        ForkFailed = "org.freedesktop.DBus.Error.Spawn.ForkFailed",
        ChildExited = "org.freedesktop.DBus.Error.Spawn.ChildExited",
        ChildSignaled = "org.freedesktop.DBus.Error.Spawn.ChildSignaled",
        Failed = "org.freedesktop.DBus.Error.Spawn.Failed",
        SetupFailed = "org.freedesktop.DBus.Error.Spawn.FailedToSetup",
        ConfigInvalid = "org.freedesktop.DBus.Error.Spawn.ConfigInvalid",
        ServiceInvalid = "org.freedesktop.DBus.Error.Spawn.ServiceNotValid",
        ServiceNotFound = "org.freedesktop.DBus.Error.Spawn.ServiceNotFound",
        PermissionsInvalid = "org.freedesktop.DBus.Error.Spawn.PermissionsInvalid",
        FileInvalid = "org.freedesktop.DBus.Error.Spawn.FileInvalid",
        NoMemory = "org.freedesktop.DBus.Error.Spawn.NoMemory",
    },
    UnixProcessIdUnknown = "org.freedesktop.DBus.Error.UnixProcessIdUnknown",
    InvalidSignature = "org.freedesktop.DBus.Error.InvalidSignature",
    InvalidFileContent = "org.freedesktop.DBus.Error.InvalidFileContent",
    SelinuxSecurityContextUnknown = "org.freedesktop.DBus.Error.SELinuxSecurityContextUnknown",
    AdtAuditDataUnknown = "org.freedesktop.DBus.Error.AdtAuditDataUnknown",
    ObjectPathInUse = "org.freedesktop.DBus.Error.ObjectPathInUse",
    InconsistentMessage = "org.freedesktop.DBus.Error.InconsistentMessage",
    InteractiveAuthorizationRequired = "org.freedesktop.DBus.Error.InteractiveAuthorizationRequired",
    NotContainer = "org.freedesktop.DBus.Error.NotContainer",
}

return errors
