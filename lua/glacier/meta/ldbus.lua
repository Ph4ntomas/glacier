---@meta ldbus

---@class ldbus
local ldbus = {}

---@enum ldbus.types
ldbus.types = {
    byte = "y", -- byte
    boolean = "b", -- boolean
    int16 = "n", -- 16-bit integer
    uint16 = "q", -- 16-bit unsigned
    int32 = "i", -- 32-bit integer
    uint32 = "u", -- 32-bit unsigned
    int64 = "x", -- 64-bit integer
    uint64 = "t", -- 64-bit unsigned
    double = "d", -- double
    string = "s", -- string
    object_path = "o", -- object path
    signature = "g", -- signature
    --unix_fd = "h", -- unix file descriptor
    array = "a", -- array
    variant = "v", -- variant
    struct = "r", -- record (struct)
    dict_entry = "e", -- dictionary entry.
}

---@enum ldbus.basic_types
ldbus.basic_types = {
    byte = "y", -- byte
    boolean = "b", -- boolean
    int16 = "n", -- 16-bit integer
    uint16 = "q", -- 16-bit unsigned
    int32 = "i", -- 32-bit integer
    uint32 = "u", -- 32-bit unsigned
    int64 = "x", -- 64-bit integer
    uint64 = "t", -- 64-bit unsigned
    double = "d", -- double
    string = "s", -- string
    object_path = "o", -- object path
    signature = "g", -- signature
    --unix_fd = "h", -- unix file descriptor
}

---@class ldbus.errors
---@field Failed string
---@field NoMemory string
---@field ServiceUnknown string
---@field NameHasNoOwner string
---@field NoReply string
---@field IOError string
---@field BadAddress string
---@field NotSupported string
---@field LimitsExceeded string
---@field AccessDenied string
---@field AuthFailed string
---@field NoServer string
---@field Timeout string
---@field NoNetwork string
---@field AddressInUse string
---@field Disconnected string
---@field InvalidArgs string
---@field FileNotFound string
---@field FileExists string
---@field UnknownMethod string
---@field TimedOut string
---@field MatchRuleNotFound string
---@field MatchRuleInvalid string
---@field Spawn ldbus.errors.spawn
---@field UnixProcessIdUnknown string
---@field InvalidSignature string
---@field InvalidFileContent string
---@field SELinuxSecurityContextUnknown string
--- Unnoficial but common
---@field UnknownObject string
--@field FdoUnknownMethod string
ldbus.errors = {}

---@class ldbus.errors.spawn
---@field ExecFailed string
---@field ForkFailed string
---@field ChildExited string
---@field ChildSignaled string
---@field Failed string
---@field FailedToSetup string
---@field ConfigInvalid string
---@field ServiceNotValid string
---@field ServiceNotFound string
---@field PermissionsInvalid string
---@field FileInvalid string
---@field NoMemory string
ldbus.errors.spawn = {}
----------------------------------------------
--                                          --
-- BUS DOCUMENTATION                        --
--                                          --
----------------------------------------------

---@class ldbus.bus
ldbus.bus = {}

---@alias ldbus.BusType
---| "session" # Connect to the session bus.
---| "system" # Connect to the system bus.
---| "starter" # Connect to the bus that started us, if any.

---Connects to a bus daemon and registers the client with it.
---
---If a connection to the bus already exists, then that connection is returned. The caller of this
---function owns a reference to the bus.
---@param type ldbus.BusType?
---@return ldbus.DBusConnection? # A DBusConnection registered to the bus, or nil on error.
---@return string? # On error, the error message.
function ldbus.bus.get(type) end

---Connects to a bus daemon and registers the client with it as with ldbus.bus.register().
---
---Unlike ldbus.bus.get(), always creates a new connection.
---@param type ldbus.BusType?
---@return ldbus.DBusConnection? # A DBusConnection registered to the bus, or nil on error.
---@return string? # On error, the error message.
function ldbus.bus.get_private(type) end

---Registers a connection with the bus.
---@return boolean? ok `true` on success
---@return string? msg Error message.
function ldbus.bus.register() end

---Sets the unique name of the connection, as assigned by the message bus.
---
---@param connection ldbus.DBusConnection
---@return boolean ok `false` if not enough memory.
function ldbus.bus.set_unique_name(connection) end

---Gets the unique name of the connection as assigned by the message bus.
---
---@param connection ldbus.DBusConnection
---@return string? name
function ldbus.bus.get_unique_name(connection) end

---@class (exact) ldbus.bus.RequestNameFlags
---@field allow_replacement? boolean # Another requestor can take the name away with `replace_existing`
---@field do_not_queue? boolean # If the name is already taken, do not place caller in a queue to get it.
---@field replace_existing? boolean # If the name has an owner, and replacement is allowed, replace it.

---@alias ldbus.bus.RequestNameResult
---| "primary_owner" # Name had no existing owner.
---| "in_queue" # In a queue to own the name.
---| "exists" # Name already has an owner, and either can't be replaced, or queueing was disabled
---| "already_owner" # Application was already owner of the name.

---Asks the bus to assign the given name to this connection by invoking the RequestName method on the bus.
---@param conn ldbus.DBusConnection
---@param name string
---@param flags? ldbus.bus.RequestNameFlags
---@return ldbus.bus.RequestNameResult?
---@return string # On error, returns the error message.
function ldbus.bus.request_name(conn, name, flags) end

---@alias ldbus.bus.ReleaseNameResult
---| "released" # Name was owned and has been released.
---| "non_existent" # Name was owned by someone else, and can't be released.
---| "not_owner" # Nobody owned the name

---Asks the bus to unassign the given name from this connection by invoking the ReleaseName method
---on the bus.
---@param conn ldbus.DBusConnection
---@param name string
---@return ldbus.bus.ReleaseNameResult?
---@return string? # On error, the error message.
function ldbus.bus.release_name(conn, name) end

---Asks the bus whether a certain name has an owner.
---
---@param conn ldbus.DBusConnection
---@param name string
---
---@return boolean? ok `true` if the name exists, `false` if not. Returns `nil` on error.
---@return string? msg Error message, if any.
function ldbus.bus.name_has_owner(conn, name) end

---@alias ldbus.bus.StartServiceResult
---| "success" # Service was auto started.
---| "already_running" # Service was already running.

---Starts a service that will request ownership of the given name.
---
---@param conn ldbus.DBusConnection
---@param name string
---
---@return ldbus.bus.StartServiceResult? result Return `nil` on error
---@return string msg Error message, if any.
function ldbus.bus.start_service_by_name(conn, name) end

---@alias ldbus.bus.MatchResult
---| "success"
---| "already_running"

---Adds a match rule to match messages going through the message bus.
---
---The "rule" argument is the string form of a match rule.
---@param conn ldbus.DBusConnection
---@param rule string
---@return boolean?
---@return string # Error message.
function ldbus.bus.add_match(conn, rule) end

---Removes a previously-added match rule "by value" (the most recently-added identical rule gets removed).
---
---@param conn ldbus.DBusConnection
---@return boolean? ok `nil` on error, `true` otherwise.
---@return string? msg Error string, if any.
function ldbus.bus.remove_match(conn, rule) end

----------------------------------------------
--                                          --
-- CONNECTION DOCUMENTATION                 --
--                                          --
----------------------------------------------

---@class ldbus.connection
ldbus.connection = {}

---Gets a connection to a remote address.
---
---@param address string
---
---@return ldbus.DBusConnection? conn # New connection, or `nil`.
---@return string? msg Error message, if any.
function ldbus.connection.open(address) end

---Connection to another application.
---@class ldbus.DBusConnection
local DBusConnection = {}

---Gets whether the connection is currently open.
---
---@return boolean ok `true` if the connection is currently open.
function DBusConnection:get_is_connected() end

---Gets whether the connection was authenticated.
---
---@return boolean ok `true` if the connection was ever authenticated.
function DBusConnection:get_is_authenticated() end

---Gets whether the connection is not authenticated as a specific user.
---
---@return boolean ok `true` if not authenticated, or authenticated as anonymous.
function DBusConnection:get_is_anonymous() end

---Gets the ID of the server address we are authenticated to, if this connection is on the client side.
---
---@return string? id Server ID, if available.
function DBusConnection:get_server_id() end

---Adds a message to the outgoing message queue.
---
---@param msg ldbus.DBusMessage
---
---@return integer? serial
function DBusConnection:send(msg) end

---Queues a message to send, as with `DBusConnection:send()`, but also returns a
---`ldbus.DBusPendingCall` used to receive a reply to the message.
---
---@param msg ldbus.DBusMessage
---@param timeout? number Timeout in seconds
---
---@return ldbus.DBusPendingCall
function DBusConnection:send_with_reply(msg, timeout) end

---Sends a message and blocks a certain time while waiting for a reply.
---
---@param msg ldbus.DBusMessage
---@param timeout number Timeout in seconds
---
---@return ldbus.DBusMessage? response
---@return string msg Error Message, if any.
function DBusConnection:send_with_reply_and_block(msg, timeout) end

---Blocks until the outgoing message queue is empty.
function DBusConnection:flush() end

---Iterate a standalone event loop.
---
---This function is intended for use with applications that don't want to write a main loop and
---deal with `ldbus.DBusWatch` and `ldbus.DBusTimeout`.
---
---If there are messages to dispatch, this function will dbus_connection_dispatch() once, and
---return. If there are no messages to dispatch, this function will block until it can read or
---write, then read or write, then return.
---
---@param timeout integer Timeout in milliseconds.
---@return boolean # `true` if the disconnect message has not been processed.
function DBusConnection:read_write_dispatch(timeout) end

---Handle reading and writing on the transport layer.
---
---The difference between this function and `ldbus.DBusConnection:read_write_dispatch()` is that it
---will not dispatch the incoming messages.
---
---@param timeout integer Timeout in millisections.
---@return boolean # Return `true` if the disconnect message has not been processed.
function DBusConnection:read_write(timeout) end

---@alias ldbus.connection.DispatchStatus
---| "data_remains" # Message queue may contain messages
---| "complete" # Incoming queue is empty
---| "need_memory" # There could be data but we need more memory

---Returns the first-received message from the incoming message queue, removing it from the queue.
---
---@return ldbus.DBusMessage? msg If the incomming queue is empty, returns `nil`.
function DBusConnection:pop_message() end

---Gets the current state of the incoming message queue.
---
---@return ldbus.connection.DispatchStatus
function DBusConnection:get_dispatch_status() end

---Processes any incoming data.
---
---If there's incoming raw data that has not yet been parsed, it is parsed, which may result in
---adding messages to the incoming queue.
---
---If there are complete messages in the incoming queue, the first one is removed and processed, in
---the following order:
---1. Methods replies are passed to their handler (`ldbus.DBusPendingCall`, or
---   `ldbus.send_with_reply_and_block`) to complete the method call.
---2. Any registered filters are run.
---3. If the message is a method call, it is forwarded to any registered object path handlers.
---
---A single call will process at most one message.
---
---@return ldbus.connection.DispatchStatus
function DBusConnection:dispatch() end

---@alias ldbus.DBusWatchFn fun(watch: ldbus.DBusWatch)

---Sets the watch functions for the connection.
---
---@param add ldbus.DBusWatchFn # Called when libdbus needs a new watch to be monitored by the main loop.
---@param remove ldbus.DBusWatchFn # Called when libdbus no longer needs a watch to be monitored by the main loop.
---@param toggled? ldbus.DBusWatchFn # Called when DBusWatch:get_enabled() may return a different value than it did before.
function DBusConnection:set_watch_functions(add, remove, toggled) end

---@alias ldbus.DBusTimeoutFn fun(watch: ldbus.DBusTimeout)

---Sets the watch functions for the connection.
---
---@param add ldbus.DBusTimeoutFn # Called when libdbus needs a new watch to be monitored by the main loop.
---@param remove ldbus.DBusTimeoutFn # Called when libdbus no longer needs a watch to be monitored by the main loop.
---@param toggled? ldbus.DBusTimeoutFn # Called when DBusWatch:get_enabled() may return a different value than it did before.
function DBusConnection:set_timeout_functions(add, remove, toggled) end

---@alias ldbus.DBusDispatchStatusFn fun(new_status: ldbus.connection.DispatchStatus)

---Sets a function to be invoked when the dispatch status changes.
---
---@param handler ldbus.DBusDispatchStatusFn
function DBusConnection:set_dispatch_status_function(handler) end

---@alias ldbus.DBusWakeupFn fun()

---Sets the mainloop wakeup function for the connection.
---
---@param wakeup ldbus.DBusWakeupFn
function DBusConnection:set_wakeup_main_function(wakeup) end

---@alias ldbus.ObjectPathMessageFn fun(msg: ldbus.DBusMessage): boolean?

---Registers a handler for a given path in the object hierarchy.
---
---The handler will receive message that exacly matches the given path.
---
---@param path string a '/' delimited string of path elements.
---@param handler ldbus.ObjectPathMessageFn
---@return boolean ok `true` if the object_path was successfully registered.
function DBusConnection:register_object_path(path, handler) end

---Registers a fallback handler for a given subsection of the object hierarchy.
---
---The handler will receive message at or below the given path. This can be used t to establish a
---default message handling policy for a whole "subdirectory".
---
---@param path string a '/' delimited string of path elements.
---@param handler ldbus.ObjectPathMessageFn
---@return boolean ok `true` if the object_path was successfully registered.
function DBusConnection:register_fallback(path, handler) end

---Unregisters the handler registered with exactly the given path.
---
---@param path string a '/' delimited string of path elements
---@return boolean ok
function DBusConnection:unregister_object_path(path) end

---Specifies the maximum size message this connection is allowed to receive.
---
---Larger messages will result in disconnecting the connection.
---
---@param size integer Maximum message size, in bytes.
function DBusConnection:set_max_message_size(size) end

---Gets the value set by `ldbus.DBusConnection:set_max_message_size()`.
---
---@return integer size Max size of a single message.
function DBusConnection:get_max_message_size() end

---Sets the maximum total number of bytes that can be used for all messages received on this
---connection.
---
---This function sets a soft limit on the maximum number of bytes in the receive queue. This is
---because it's not possible to know the size of a message until after it's read, so the size can
---be exceeded by the maximum size of a single message.
---
---The size may also be by several message (up to the length of the read buffer) if more than one
---messages are read at once.
---
---If the maximum received size has been exceeded, the connection will not read any more data until
---some messages are finalized and removed from the queue.
---
---@param size integer the maximum size in bytes of all outstanding messages.
function DBusConnection:set_max_received_size(size) end

---Gets the value set by `ldbus.DBusConnection:get_max_received_size()`
---
---@return integer size
function DBusConnection:get_max_received_size() end

---Gets the approximate size in bytes of all messages in the outgoing message queue.
---
---@return integer # the number of bytes queues but not sent
function DBusConnection:get_outgoing_size() end

---Checks whether there are messages in the outgoing message queue.
---
---@return boolean # true if the outgoing queue is non-empty.
function DBusConnection:has_messages_to_send() end

----------------------------------------------
--                                          --
-- MESSAGE DOCUMENTATION                    --
--                                          --
----------------------------------------------

---@class ldbus.message
ldbus.message = {}

---@alias ldbus.DBusValueType
---| ldbus.DBusBasicValueType # basic value
---| ldbus.DBusCompoundType # compound values

---@alias ldbus.DBusBasicValueType
---| "y" # byte
---| "b" # boolean
---| "n" # 16-bit integer
---| "q" # 16-bit unsigned
---| "i" # 32-bit integer
---| "u" # 32-bit unsigned
---| "x" # 64-bit integer
---| "t" # 64-bit unsigned
---| "d" # double
---| "s" # string
---| "o" # object path
---| "g" # signature
---| "h" # unix file descriptor

---@alias ldbus.DBusCompoundType
---| "a" # array
---| "v" # variant
---| "r" # record (struct)
---| "e" # dictionary entry.

---@alias ldbus.DBusMessageType
---| "method_call"
---| "method_return"
---| "signal"
---| "error"

---Constructs a new message of the given message type.
---
---@param type ldbus.DBusMessageType
---
---@return ldbus.DBusMessage
function ldbus.message.new(type) end

---Constructs a new message to invoke a method on a remote object.
---
---@param destination string? name that the message should be sent to or `nil`.
---@param path string object path the message should be sent to.
---@param interface string? interface to invoke method on, or `nil`.
---@param method string method to invoke.
---
---@return ldbus.DBusMessage
function ldbus.message.new_method_call(destination, path, interface, method) end

---Constructs a new message representing a signal emission.
---
---@param path string path to the object emitting the signal.
---@param interface string interface the signal is emitted from.
---@param name string name of the signal.
---
---@return ldbus.DBusMessage
function ldbus.message.new_signal(path, interface, name) end

---@class ldbus.DBusMessage
local DBusMessage = {}

---Returns the serial of a message or 0 if none has been specified.
---
---The message's serial number is provided by the application sending the message and is used to
---identify replies to this message.
---
---@return integer
function DBusMessage:get_serial() end

---Sets the reply serial of a message (the serial of the message this is a reply to).
---
---@param reply_serial integer the serial we're replying to.
function DBusMessage:set_reply_serial(reply_serial) end

---Returns the serial that the message is a reply to or 0 if none.
--- @return integer the reply serial
function DBusMessage:get_reply_serial() end

---Constructs a message that is a reply to a method call.
---
---@param method_call ldbus.DBusMessage
---
---@return ldbus.DBusMessage method_return
function DBusMessage:new_method_return(method_call) end

---Creates a new message that is an error reply to another message.
---
---@param reply_to ldbus.DBusMessage the message we're replying to
---@param name string the error name
---@param message string? The error message
---
---@return ldbus.DBusMessage message
function DBusMessage:new_error(reply_to, name, message) end

---Creates a new message that is an exact replica of the message specified, except that its
---refcount is set to 1, its message serial is reset to 0, and it's not locked.
---
---@param message ldbus.DBusMessage the message to copy
---@return ldbus.DBusMessage copy.
function DBusMessage:copy(message) end

---Gets the type of a message.
---
---@return ldbus.DBusMessageType
function DBusMessage:get_type() end

---Initializes a `ldbus.DBusMessageIter` for reading the arguments of the message passed in.
---
---@param iter ldbus.DBusMessageIter? If `nil`, a new ldbus.DBusMessageIter will be returned.
---
---@return ldbus.DBusMessageIter? # Return `nil` if the message has no arguments.
function DBusMessage:iter_init(iter) end

---Initializes a `ldbus.DBusMessageIter` for appending arguments to the end of a message.
---
---@param iter ldbus.DBusMessageIter? If `nil`, a new ldbus.DBusMessageIter will be returned.
---
---@return ldbus.DBusMessageIter
function DBusMessage:iter_init_append(iter) end

---Sets a flag indicating that the message does not want a reply.
---
---If this flag is set, the other end of the connection may (but is not required to) optimize by
---not sending method return or error replies.
---
---@param no_reply boolean
function DBusMessage:set_no_reply(no_reply) end

---Check whether the message expect a reply.
---
---@return boolean no_reply Returns `true` if the message does not expect a reply.
function DBusMessage:get_no_reply() end

---Sets a flag indicating that an owner for the destination name will be automatically started
---before the message is delivered.
---
---Default auto_start is `true`.
---
---@param auto_start boolean `true` if auto_starting is desired.
function DBusMessage:set_auto_start(auto_start) end

---Check whether the message will cause an owner for its destination to be auto-started
---
---@return boolean auto_start Returns `true` if the message will cause an auto-start.
function DBusMessage:get_auto_start() end

---Sets the object path this message is being sent to (method_call) or emitted from (signal).
---
---@param path string? the path, on `nil` to unset.
function DBusMessage:set_path(path) end

---Gets the object path this message is being sent to (method_call) or emitted from (signal).
---
---@return string? path The path, or `nil` if none.
function DBusMessage:get_path() end

---Gets the object path this message is being sent to (method_call) or emitted from (signal), as an
---array.
---
---@return (string[]|boolean) path The decomposed path, or `nil` if none, or `false` if there's not
---enough memory for the array.
function DBusMessage:get_path_decomposed() end

---Sets the interface this message is being sent to (method_call) or emitted from (signal).
---
---@param interface string? the interface, or `nil` to unset.
function DBusMessage:set_interface(interface) end

---Gets the interface this message is being sent to (method_call) or emitted from (signal).
---
---@return string? interface the interface, or `nil` if none
function DBusMessage:get_interface() end

---Sets the member being invoked (method_call) or sent (signal)
---
---@param member string? member name, or `nil` to unset.
function DBusMessage:set_member(member) end

---Gets the member being invoked (method_call) or sent (signal)
---
---@return string? member  member name, or `nil` if none
function DBusMessage:get_member() end

---Sets the name or the error.
---
---@param error_name string? error name, or `nil` to unset
function DBusMessage:set_error_name(error_name) end

---Gets the name or the error.
---
---@return string? error_name error name, or `nil` if none
function DBusMessage:get_error_name() end

---Sets the message's destination
---
---@param destination string? the destination, or `nil` to unset.
function DBusMessage:set_destination(destination) end

---Gets the message's destination
---
---@return string? destination the destination, or `nil` if none.
function DBusMessage:get_destination() end

---Sets the message sender.
---
---@param sender string? message sender, or `nil` to unset.
function DBusMessage:set_sender(sender) end

---Gets the message sender.
---
---@return string? sender message sender, or `nil` if none.
function DBusMessage:get_sender() end

---Gets the type signature of the message (i.e. the arguments in the payload)/
---
---@return string? signature message signature
function DBusMessage:get_signature() end

----------------------------------------------
--                                          --
-- MESSAGE ITER DOCUMENTATION               --
--                                          --
----------------------------------------------

---@class ldbus.message.iter
ldbus.message.iter = {}

---Create a new `ldbus.DBusMessageIter` that doesn't refer to any message.
---
---@return ldbus.DBusMessageIter
function ldbus.message.iter.new() end

---@class ldbus.DBusMessageIter
local DBusMessageIter = {}

---Create a new `ldbus.DBusMessageIter` that refer to the same dbus iterator.
---
---This function duplicate the iterator, and increase the reference counter on its internal state.
---
---@return ldbus.DBusMessageIter
function DBusMessageIter:clone() end

---Checks if the iterator has any more fields.
---
---@return boolean
function DBusMessageIter:has_next() end

---Moves the iterator to the next field, if any.
---
---@return boolean # `true` if the iterator moves forward, `false` otherwise.
function DBusMessageIter:next() end

---Returns the argument type of the argument the iterator points to.
---
---@return ldbus.DBusValueType? type a single char string representing the argument type, or `nil`
---if none or invalid.
function DBusMessageIter:get_arg_type() end

---Returns the number of elements in the array-typed value pointed to by the iterator.
---
---@return integer # the number of elements in the array
function DBusMessageIter:get_element_count() end

---Returns the element type of the array that the message iterator points to.
---
---You must check that the argument is an array before calling this method.
---
---@return ldbus.DBusValueType? type a single char string representing the argument type, or `nil`
---if none or invalid.
function DBusMessageIter:get_element_type() end

---Recurses into a container value when reading values from a message, initializing a sub-iterator
---traversing the child values of the container.
---
---@param sub_iter ldbus.DBusMessageIter? iterator to use for the recursion. If `nil`, a new
---iterator will be returned
---
---@return ldbus.DBusMessageIter
function DBusMessageIter:recurse(sub_iter) end

---Returns the current signature of a message iterator.
---
---@return string signature the current signature of the iterator.
function DBusMessageIter:get_signature() end

---@alias ldbus.DBusBasicValue integer|number|boolean|string

---Reads a basic-typed value from the message iterator.
---
---Warning, due to lua type-system, integer are returned as number.
---
---@return ldbus.DBusBasicValue? # The value retrieved, or `nil` if not a basic type.
---@return string? # on error, the string "Encountered non-basic type".
function DBusMessageIter:get_basic() end

---Appends a basic-typed value to the message.
---
---if the `type` parameter is nil or absent, the following type inference is performed:
--- - if `object` is an integer, append a DBUS_TYPE_INT64 ('x')
--- - if `object` is a number, append a DBUS_TYPE_DOUBLE ('d')
--- - if `object` is a string, append a DBUS_TYPE_STRING ('s')
--- - if `object` is a boolean, append a DBUS_TYPE_BOOLEAN ('b')
---
---@param object ldbus.DBusBasicValue value to append.
---@param type ldbus.DBusBasicValueType? the type of the value.
function DBusMessageIter:append_basic(object, type) end

---Appends a container-typed value to the message.
---
---On success, you are required to append the contents of the container using the returned
---sub-iterator, and then call dbus_message_iter_close_container().
---
---Valid values for `contained_sign` depends on the container `type`:
--- - for variant (v), it must be set to the type of the contained value.
--- - for array (a), it must be set to the type of the array element.
--- - for struct (r) and dict-entries (e), it must be nil and will be filled with the values
---   written to the container
---
---@param type ldbus.DBusCompoundType the container type.
---@param contained_sign string? the contained type signature, or `nil`.
---@param sub_iter? ldbus.DBusMessageIter the iterator to use, or `nil` to create a new one.
---
---@return ldbus.DBusMessageIter sub_iter iterator to append value to the container.
function DBusMessageIter:open_container(type, contained_sign, sub_iter) end

---Closes a container-typed value appended to the message.
---
---@param sub_iter ldbus.DBusMessageIter iterator to close.
---
---@return boolean `false` if not enough memory.
function DBusMessageIter:close_container(sub_iter) end

----------------------------------------------
--                                          --
-- PENDING CALL DOCUMENTATION               --
--                                          --
----------------------------------------------

---@class ldbus.DBusPendingCall
local DBusPendingCall = {}

---@alias ldbus.DBusPendingCallNotifyFn fun()

---Sets a notification function to be called when the reply is received or the pending call times out.
---
---@param notify ldbus.DBusPendingCallNotifyFn
function DBusPendingCall:set_notify(notify) end

---Cancels the pending call, such that any reply or error received will just be ignored.
function DBusPendingCall:cancel() end

---Checks whether the pending call has received a reply yet, or not.
---
---@return boolean `true` if the call is complete.
function DBusPendingCall:get_completed() end

---Gets the reply.
---
---@return ldbus.DBusMessage? reply If a reply has been received, returns the message. Return `nil`
---otherwise.
function DBusPendingCall:steal_reply() end

---Block the current thread until a reply is received.
function DBusPendingCall:block() end

----------------------------------------------
--                                          --
-- TIMEOUT DOCUMENTATION                    --
--                                          --
----------------------------------------------

---@class ldbus.DBusTimeout
local DBusTimeout = {}

---Gets the timeout interval.
---
---`DBusTimeout:handle()` should be called each time this interval elapses, starting after it
---elapses once.
---
---The interval may change during the life of the timeout; if so, the timeout will be disabled and
---re-enabled (calling the "timeout toggled function") to notify you of the change.
---
---@return integer # The timeout in milliseconds.
function DBusTimeout:get_interval() end

---Calls the timeout handler for this timeout.
---
---@return boolean false if ther wasn't enough memory to handle the timeout.
function DBusTimeout:handle() end

---Returns whether a timeout is enabled or not.
---
---@return boolean
function DBusTimeout:get_enabled() end

----------------------------------------------
--                                          --
-- WATCH DOCUMENTATION                      --
--                                          --
----------------------------------------------

---@class ldbus.DBusWatch
local DBusWatch = {}

---@enum ldbus.watch
---| "READABLE" # As in POLLIN
---| "WRITABLE" # As in POLLOUT
---| "ERROR" # As in POLLERR
---| "HANGUP" # As in POLLUP
ldbus.watch = {
    READABLE = 1 << 0,
    WRITABLE = 1 << 1,
    ERROR = 1 << 2,
    HANGUP = 1 << 3,
}

---Returns a UNIX file descriptor to be watched, which may be a pipe, socket, or other type of descriptor.
---
---@return integer? # Return `nil` when no fd is available.
function DBusWatch:get_unix_fd() end

---Returns a socket to be watched.
---
---On UNIX this will return `nil` if our transport is not socket-based so `DBusWatch:get_unix_fd()`
---is preferred.
---
---@return integer? # Return `nil` when no fd is available.
function DBusWatch:get_socket() end

---Gets flags from indicating what conditions should be monitored on the file descriptor.
---
---@return ldbus.watch
function DBusWatch:get_flags() end

---Called to notify the D-Bus library when a previously-added watch is ready for reading or
---writing, or has an exception such as a hangup.
---@param flags ldbus.watch
---@return boolean # Return `false` if there wasn't enough memory.
function DBusWatch:handle(flags) end

---Returns whether a watch is enabled or not.
---
---If not enabled, it should not be polled by the main loop.
---@return boolean
function DBusWatch:get_enabled() end
