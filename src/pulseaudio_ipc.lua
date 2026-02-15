-- PulseAudio IPC client using pactl subscribe
-- Listens to PulseAudio events in real-time for instant volume widget updates

local lgi = require("lgi")
local Gio = lgi.require("Gio", "2.0")
local GLib = lgi.require("GLib", "2.0")

local PulseAudioIPC = {}

-- Create new PulseAudio IPC client
function PulseAudioIPC:new()
    local client = {
        subprocess = nil,
        input_stream = nil,
        cancellable = nil,
        event_callback = nil,
        is_running = false,
    }

    setmetatable(client, self)
    self.__index = self
    return client
end

-- Subscribe to PulseAudio events
function PulseAudioIPC:subscribe(_event_types, callback)
    if self.is_running then
        return false, "Already subscribed"
    end

    -- Store callback
    self.event_callback = callback

    -- Spawn pactl subscribe as a long-running subprocess
    local ok, result = pcall(function()
        return Gio.Subprocess.new(
            {"pactl", "subscribe"},
            Gio.SubprocessFlags.STDOUT_PIPE
        )
    end)

    if not ok or not result then
        return false, "Failed to start pactl subscribe: " .. tostring(result)
    end

    self.subprocess = result
    self.cancellable = Gio.Cancellable.new()

    -- Get stdout stream and wrap it in a DataInputStream for line-by-line reading
    local stdout = self.subprocess:get_stdout_pipe()
    self.input_stream = Gio.DataInputStream.new(stdout)

    self.is_running = true

    -- Start reading events
    self:start_event_loop()

    return true
end

-- Start event loop to read events line-by-line
function PulseAudioIPC:start_event_loop()
    local function read_next_line()
        if not self.is_running then
            return
        end

        -- Read one line asynchronously
        self.input_stream:read_line_async(GLib.PRIORITY_DEFAULT, self.cancellable, function(source, result)
            local ok, line, _length = pcall(function()
                return source:read_line_finish_utf8(result)
            end)

            if not ok or not line then
                -- EOF or error - subprocess likely terminated
                if self.is_running then
                    print("WARNING: PulseAudio IPC event stream ended:", tostring(line))
                    self.is_running = false
                end
                return
            end

            -- Parse event line
            -- Example: "Event 'change' on sink #0"
            -- Example: "Event 'new' on sink #1"
            -- Example: "Event 'change' on source #0"
            local event_type, object_type, object_id = line:match("Event '(%w+)' on (%w+) #(%d+)")

            if event_type and object_type then
                -- Filter for sink events (volume/mute changes affect sinks)
                if object_type == "sink" then
                    if self.event_callback then
                        self.event_callback({
                            type = event_type,
                            object = object_type,
                            id = tonumber(object_id)
                        })
                    end
                end
            end

            -- Continue reading next line
            read_next_line()
        end)
    end

    -- Start the loop
    read_next_line()
end

-- Get current audio state (volume and mute status)
function PulseAudioIPC:get_audio_state(callback)
    -- First get volume
    local volume_proc = Gio.Subprocess.new(
        {"pactl", "get-sink-volume", "@DEFAULT_SINK@"},
        Gio.SubprocessFlags.STDOUT_PIPE + Gio.SubprocessFlags.STDERR_PIPE
    )

    volume_proc:communicate_utf8_async(nil, nil, function(vol_source, vol_result)
        local vol_ok, stdout, stderr = pcall(function()
            return vol_source:communicate_utf8_finish(vol_result)
        end)

        if not vol_ok or not volume_proc:get_successful() then
            callback(nil, "Failed to get volume: " .. tostring(stderr))
            return
        end

        -- Parse volume from pactl output: "Volume: front-left: 65536 /  100% / 0.00 dB"
        local volume = stdout:match("(%d+)%%")
        if not volume then
            callback(nil, "Failed to parse volume from output")
            return
        end

        -- Now get mute status
        local mute_proc = Gio.Subprocess.new(
            {"pactl", "get-sink-mute", "@DEFAULT_SINK@"},
            Gio.SubprocessFlags.STDOUT_PIPE + Gio.SubprocessFlags.STDERR_PIPE
        )

        mute_proc:communicate_utf8_async(nil, nil, function(mute_source, mute_result)
            local mute_ok, mute_stdout, mute_stderr = pcall(function()
                return mute_source:communicate_utf8_finish(mute_result)
            end)

            if not mute_ok or not mute_proc:get_successful() then
                callback(nil, "Failed to get mute status: " .. tostring(mute_stderr))
                return
            end

            -- Parse mute status: "Mute: yes" or "Mute: no"
            local is_muted = mute_stdout:match("yes") ~= nil

            -- Return combined state
            callback({
                volume = tonumber(volume),
                muted = is_muted
            }, nil)
        end)
    end)
end

-- Disconnect and cleanup
function PulseAudioIPC:disconnect()
    if not self.is_running then
        return
    end

    self.is_running = false

    if self.cancellable then
        pcall(function() self.cancellable:cancel() end)
    end

    if self.subprocess then
        pcall(function() self.subprocess:force_exit() end)
    end
end

return PulseAudioIPC
