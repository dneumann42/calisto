-- Direct Sway IPC client using Unix sockets
-- Based on the Sway IPC protocol: https://man.archlinux.org/man/sway-ipc.7.en

local lgi = require("lgi")
local Gio = lgi.require("Gio", "2.0")
local GLib = lgi.require("GLib", "2.0")
local Json = require("json")

local SwayIPC = {}

-- IPC Message types
local IPC_COMMAND = 0
local IPC_GET_WORKSPACES = 1
local IPC_SUBSCRIBE = 2
local IPC_GET_OUTPUTS = 3
local IPC_GET_TREE = 4
local IPC_GET_MARKS = 5
local IPC_GET_BAR_CONFIG = 6
local IPC_GET_VERSION = 7

-- IPC Event types (high bit set)
local IPC_EVENT_WORKSPACE = 0x80000000
local IPC_EVENT_OUTPUT = 0x80000001
local IPC_EVENT_MODE = 0x80000002
local IPC_EVENT_WINDOW = 0x80000003
local IPC_EVENT_BARCONFIG_UPDATE = 0x80000004
local IPC_EVENT_BINDING = 0x80000005
local IPC_EVENT_SHUTDOWN = 0x80000006

-- Magic string for IPC protocol (i3-ipc compatibility)
local IPC_MAGIC = "i3-ipc"
local IPC_HEADER_SIZE = 14 -- 6 bytes magic + 4 bytes length + 4 bytes type

-- Pack 32-bit little-endian integer
local function pack_u32_le(value)
    return string.char(
        value % 256,
        math.floor(value / 256) % 256,
        math.floor(value / 65536) % 256,
        math.floor(value / 16777216) % 256
    )
end

-- Unpack 32-bit little-endian integer
local function unpack_u32_le(bytes, offset)
    offset = offset or 1
    local b1, b2, b3, b4 = string.byte(bytes, offset, offset + 3)
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

-- Build IPC message
local function build_message(msg_type, payload)
    payload = payload or ""
    local length = #payload
    return IPC_MAGIC .. pack_u32_le(length) .. pack_u32_le(msg_type) .. payload
end

-- Create new IPC client
function SwayIPC:new()
    local client = {
        socket_path = os.getenv("SWAYSOCK") or os.getenv("I3SOCK"),
        connection = nil,
        input_stream = nil,
        output_stream = nil,
        cancellable = nil,
        event_callbacks = {},
        command_callbacks = {},
        is_connected = false,
    }

    setmetatable(client, self)
    self.__index = self
    return client
end

-- Connect to Sway IPC socket
function SwayIPC:connect()
    if not self.socket_path then
        return false, "SWAYSOCK environment variable not set"
    end

    local socket_address = Gio.UnixSocketAddress.new(self.socket_path)
    local socket_client = Gio.SocketClient.new()

    local ok, conn_or_err = pcall(function()
        return socket_client:connect(socket_address, nil)
    end)

    if not ok or not conn_or_err then
        return false, "Failed to connect to Sway IPC socket: " .. tostring(conn_or_err)
    end

    self.connection = conn_or_err
    self.input_stream = Gio.DataInputStream.new(self.connection:get_input_stream())
    self.output_stream = self.connection:get_output_stream()
    self.cancellable = Gio.Cancellable.new()
    self.is_connected = true

    return true
end

-- Send IPC message
function SwayIPC:send(msg_type, payload)
    if not self.is_connected then
        return false, "Not connected"
    end

    local message = build_message(msg_type, payload)
    local bytes = GLib.Bytes.new(message)

    local ok, err = pcall(function()
        self.output_stream:write_bytes(bytes, self.cancellable)
    end)

    if not ok then
        return false, "Failed to send message: " .. tostring(err)
    end

    return true
end

-- Read IPC header
function SwayIPC:read_header(callback)
    self.input_stream:read_bytes_async(IPC_HEADER_SIZE, GLib.PRIORITY_DEFAULT, self.cancellable, function(source, result)
        local ok, bytes = pcall(function()
            return source:read_bytes_finish(result)
        end)

        if not ok or not bytes then
            callback(nil, "Failed to read header: " .. tostring(bytes))
            return
        end

        local header_data = bytes:get_data()
        if #header_data < IPC_HEADER_SIZE then
            callback(nil, "Incomplete header")
            return
        end

        -- Verify magic string
        local magic = string.sub(header_data, 1, 6)
        if magic ~= IPC_MAGIC then
            callback(nil, "Invalid magic string: " .. magic)
            return
        end

        -- Extract length and type
        local payload_length = unpack_u32_le(header_data, 7)
        local msg_type = unpack_u32_le(header_data, 11)

        callback({ length = payload_length, type = msg_type })
    end)
end

-- Read IPC payload
function SwayIPC:read_payload(length, callback)
    if length == 0 then
        callback("")
        return
    end

    self.input_stream:read_bytes_async(length, GLib.PRIORITY_DEFAULT, self.cancellable, function(source, result)
        local ok, bytes = pcall(function()
            return source:read_bytes_finish(result)
        end)

        if not ok or not bytes then
            callback(nil, "Failed to read payload: " .. tostring(bytes))
            return
        end

        local payload = bytes:get_data()
        if #payload < length then
            callback(nil, "Incomplete payload")
            return
        end

        callback(payload)
    end)
end

-- Read complete IPC message
function SwayIPC:read_message(callback)
    self:read_header(function(header, err)
        if err then
            callback(nil, err)
            return
        end

        self:read_payload(header.length, function(payload, payload_err)
            if payload_err then
                callback(nil, payload_err)
                return
            end

            callback({ type = header.type, payload = payload })
        end)
    end)
end

-- Subscribe to events
function SwayIPC:subscribe(events, callback)
    local events_json = Json.encode(events)
    local ok, err = self:send(IPC_SUBSCRIBE, events_json)

    if not ok then
        return false, err
    end

    -- Store callback for this subscription
    for _, event in ipairs(events) do
        self.event_callbacks[event] = callback
    end

    return true
end

-- Start event loop
function SwayIPC:start_event_loop()
    local function read_next_message()
        if not self.is_connected then
            return
        end

        self:read_message(function(message, err)
            if err then
                print("ERROR: Failed to read IPC message:", err)
                -- Continue reading despite errors
                GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
                    read_next_message()
                    return false
                end)
                return
            end

            -- Check if it's an event (high bit set)
            if message.type >= 0x80000000 then
                -- Parse JSON payload
                local ok, event_data = pcall(Json.decode, message.payload)
                if ok then
                    -- Determine event type
                    local event_name = nil
                    if message.type == IPC_EVENT_WORKSPACE then
                        event_name = "workspace"
                    elseif message.type == IPC_EVENT_WINDOW then
                        event_name = "window"
                    elseif message.type == IPC_EVENT_OUTPUT then
                        event_name = "output"
                    end

                    -- Call registered callback
                    if event_name and self.event_callbacks[event_name] then
                        self.event_callbacks[event_name](event_data)
                    end
                else
                    print("ERROR: Failed to parse event JSON:", event_data)
                end
            else
                -- It's a command response
                if self.command_callbacks[message.type] then
                    local ok, response_data = pcall(Json.decode, message.payload)
                    if ok then
                        self.command_callbacks[message.type](response_data)
                    end
                end
            end

            -- Continue reading
            read_next_message()
        end)
    end

    read_next_message()
end

-- Send command and get response
function SwayIPC:command(cmd, callback)
    local ok, err = self:send(IPC_COMMAND, cmd)
    if not ok then
        callback(nil, err)
        return
    end

    -- Store callback for response
    self.command_callbacks[IPC_COMMAND] = callback
end

-- Get workspaces
function SwayIPC:get_workspaces(callback)
    local ok, err = self:send(IPC_GET_WORKSPACES, "")
    if not ok then
        callback(nil, err)
        return
    end

    self.command_callbacks[IPC_GET_WORKSPACES] = callback
end

-- Get tree
function SwayIPC:get_tree(callback)
    local ok, err = self:send(IPC_GET_TREE, "")
    if not ok then
        callback(nil, err)
        return
    end

    self.command_callbacks[IPC_GET_TREE] = callback
end

-- Disconnect
function SwayIPC:disconnect()
    if not self.is_connected then
        return
    end

    self.is_connected = false

    if self.cancellable then
        pcall(function() self.cancellable:cancel() end)
    end

    if self.connection then
        pcall(function() self.connection:close() end)
    end
end

return SwayIPC
