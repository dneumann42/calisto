local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib", "2.0")
local Gio = lgi.require("Gio", "2.0") -- Need Gio for async subprocesses
local Widgets = {}
local Json = require("json")
local UI = require("ui")
local pp = require("pprint")
local SwayIPC = import("sway_ipc")

-- Asynchronous command runner using Gio.Subprocess
local function run_shell_command_async(command_args, callback)
    local process = Gio.Subprocess.new(command_args, Gio.SubprocessFlags.STDOUT_PIPE + Gio.SubprocessFlags.STDERR_PIPE)

    process:communicate_utf8_async(nil, nil, function(source, result)
        local ok, stdout, stderr = pcall(function()
            return source:communicate_utf8_finish(result)
        end)

        if not ok then
            print("ERROR: Command failed:", table.concat(command_args, " "), "-", stdout)
            callback(nil, "Failed to run command: " .. tostring(stdout))
            return
        end

        if process:get_successful() then
            callback(stdout, nil)
        else
            print("ERROR: Command failed:", table.concat(command_args, " "), "stderr:", stderr)
            callback(nil, "Command failed: " .. tostring(stderr))
        end
    end)
end

local function parse_sway_json(json_str)
    local decoded = Json.decode(json_str)
    local workspaces = {}

    for i = 1, #decoded do
        local ws = decoded[i]
        table.insert(workspaces, {
            name = ws.name,
            focused = ws.focused,
            urgent = ws.urgent,
            visible = ws.visible,
            num = tonumber(ws.num),
        })
    end
    table.sort(workspaces, function(a, b)
        return a.num < b.num
    end)
    return workspaces
end

local function apply_css(widget, css)
    if not css then
        return
    end
    local provider = Gtk.CssProvider.new()
    provider:load_from_string(css)
    widget:get_style_context():add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
end

local MONTHS = {
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
}

local function format_date(fmt)
    if fmt then
        return os.date(fmt)
    end
    local t = os.date("*t")
    local suf = (t.day >= 11 and t.day <= 13) and "th" or ({ [1] = "st", [2] = "nd", [3] = "rd" })[t.day % 10] or "th"
    local h12 = t.hour % 12
    if h12 == 0 then
        h12 = 12
    end
    return string.format(
        "%s %d%s, %d | %d:%02d%s",
        MONTHS[t.month],
        t.day,
        suf,
        t.year,
        h12,
        t.min,
        t.hour < 12 and "AM" or "PM"
    )
end

Widgets.bar = {}
function Widgets.bar:new(cfg)
    local gap = cfg.gap or 0
    local bar = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, gap)
    bar:set_valign(Gtk.Align.CENTER)

    -- Parse padding: {top, bottom, left, right} or individual values
    local padding = cfg.padding or { 0, 0, 0, 0 }
    local padding_top = padding[1] or 0
    local padding_bottom = padding[2] or 0
    local padding_left = padding[3] or 0
    local padding_right = padding[4] or 0

    -- Apply margin to bar for padding effect
    bar:set_margin_top(padding_top)
    bar:set_margin_bottom(padding_bottom)
    bar:set_margin_start(padding_left)
    bar:set_margin_end(padding_right)

    -- Always apply theme to ensure colors are updated
    UI:apply_theme(cfg.opacity, cfg.font, cfg.font_size, cfg.widget_height)

    local widgets = cfg.widgets or {}
    for i = 1, #widgets do
        bar:append(widgets[i])
    end

    return bar
end

Widgets.button = {}
function Widgets.button:new(cfg)
    local label = cfg.label or "Button"
    local btn = Gtk.Button.new_with_label(label)
    if not cfg.css then
        btn:set_margin_start(2)
    end
    btn.on_clicked = cfg.on_clicked or function()
        print("Button clicked")
    end
    apply_css(btn, cfg.css)
    return btn
end

Widgets.image_button = {}
function Widgets.image_button:new(cfg)
    local image_path = cfg.image or ""
    local icon_name = cfg.icon

    -- Resolve @res/ prefix to ~/.alatar/res/
    if image_path ~= "" and image_path:match("^@res/") then
        local home = os.getenv("HOME") or ""
        image_path = home .. "/.alatar/res/" .. image_path:sub(6)
    end

    -- Create a box instead of button for full control over padding
    local box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)

    -- Only fill height if no custom size specified
    if not cfg.size then
        box:set_vexpand(true)
        box:set_valign(Gtk.Align.FILL)
    else
        -- Let the box size naturally to the image
        box:set_valign(Gtk.Align.CENTER)
    end

    -- Create and set the image with scaling
    local size = cfg.size or (UI.widget_height or 28)
    print(
        string.format(
            "[image_button] Image: %s, Size: %d, Pixelated: %s",
            image_path,
            size,
            tostring(cfg.pixelated or cfg.nearest_neighbor)
        )
    )

    local img

    if icon_name then
        -- Use GTK icon name
        img = Gtk.Image.new_from_icon_name(icon_name)
        if cfg.size then
            img:set_pixel_size(cfg.size)
        end
    elseif cfg.pixelated or cfg.nearest_neighbor then
        -- Load with GdkPixbuf for nearest neighbor scaling
        local GdkPixbuf = lgi.require("GdkPixbuf", "2.0")
        local Gdk = lgi.require("Gdk", "4.0")
        local pixbuf = GdkPixbuf.Pixbuf.new_from_file(image_path)

        -- Get original dimensions
        local orig_width = pixbuf:get_width()
        local orig_height = pixbuf:get_height()

        -- Scale maintaining aspect ratio
        local scale_factor = size / math.max(orig_width, orig_height)
        local new_width = math.floor(orig_width * scale_factor)
        local new_height = math.floor(orig_height * scale_factor)

        print(
            string.format(
                "[image_button] Original: %dx%d, Scaled: %dx%d",
                orig_width,
                orig_height,
                new_width,
                new_height
            )
        )

        -- Scale with nearest neighbor (INTERP_NEAREST = 0)
        local scaled = pixbuf:scale_simple(new_width, new_height, 0)

        -- Use Gtk.Picture for proper sizing in GTK4
        local texture = Gdk.Texture.new_for_pixbuf(scaled)
        img = Gtk.Picture.new_for_paintable(texture)
        img:set_can_shrink(false)
        img:set_content_fit(Gtk.ContentFit.FILL)

        -- Set explicit size
        img:set_size_request(new_width, new_height)
        img:set_halign(Gtk.Align.CENTER)
        img:set_valign(Gtk.Align.CENTER)

        -- Set explicit size on box to match image
        box:set_size_request(new_width, new_height)
    else
        -- Use default smooth scaling
        img = Gtk.Image.new_from_file(image_path)
        img:set_pixel_size(size)
    end

    box:append(img)

    -- Add click gesture to make it act like a button
    local Gtk4 = lgi.require("Gtk", "4.0")
    local click = Gtk4.GestureClick.new()
    click.on_released = function(gesture, n_press, x, y)
        if cfg.on_clicked then
            cfg.on_clicked()
        else
            print("Image button clicked")
        end
    end
    box:add_controller(click)

    -- Apply CSS with zero padding and optional nearest neighbor interpolation
    local interpolation = ""
    if cfg.pixelated or cfg.nearest_neighbor then
        interpolation = [[
            -gtk-icon-filter: none;
            image-rendering: pixelated;
            image-rendering: crisp-edges;
        ]]
    end

    local box_css = string.format(
        [[
        box {
            padding: 0;
            margin: 0;
            background: none;
        }
        box image {
            padding: 0;
            margin: 0;
            %s
        }
    ]],
        interpolation
    )
    apply_css(box, box_css)

    -- Apply user CSS on top if provided
    if cfg.css then
        apply_css(box, cfg.css)
    end

    return box
end

Widgets.clock = {}
function Widgets.clock:new(cfg)
    local clock = Gtk.Label.new(format_date(cfg.format))
    if not cfg.css then
        clock:set_margin_end(12)
    end

    -- Fill height like buttons do
    clock:set_vexpand(true)
    clock:set_valign(Gtk.Align.FILL)

    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, function()
        clock:set_text(format_date(cfg.format))
        if cfg.tick and not cfg.tick() then
            return false
        end
        return true
    end)
    apply_css(clock, cfg.css)
    return clock
end

Widgets.hspacer = {}
function Widgets.hspacer:new(cfg)
    cfg = cfg or {}
    local spacer = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)

    if cfg.width then
        -- Fixed width spacer
        spacer:set_size_request(cfg.width, -1)
        spacer:set_hexpand(false)
    else
        -- Expandable spacer (default)
        spacer:set_hexpand(true)
    end

    apply_css(spacer, cfg.css or "")
    return spacer
end

Widgets.media = {}
function Widgets.media:new(cfg)
    cfg = cfg or {}
    local media_script = os.getenv("HOME") .. "/.alatar/scripts/media.sh"
    local media_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
    media_box:set_vexpand(true)
    media_box:set_valign(Gtk.Align.FILL)
    media_box:set_spacing(0)

    -- Set fixed width if specified
    if cfg.width then
        media_box:set_size_request(cfg.width, -1)
        media_box:set_hexpand(false)
    end

    -- UTF-8 aware string functions
    local function utf8_chars(str)
        local chars = {}
        local i = 1
        while i <= #str do
            local byte = string.byte(str, i)
            local char_len = 1
            if byte >= 0xF0 then
                char_len = 4
            elseif byte >= 0xE0 then
                char_len = 3
            elseif byte >= 0xC0 then
                char_len = 2
            end
            table.insert(chars, string.sub(str, i, i + char_len - 1))
            i = i + char_len
        end
        return chars
    end

    local function utf8_sub(str, start_char, end_char)
        local chars = utf8_chars(str)
        local result = {}
        for i = start_char, math.min(end_char, #chars) do
            table.insert(result, chars[i])
        end
        return table.concat(result)
    end

    local function utf8_len(str)
        return #utf8_chars(str)
    end

    -- Create album art image - use bar height if available
    local GdkPixbuf = lgi.require("GdkPixbuf", "2.0")
    local Gdk = lgi.require("Gdk", "4.0")
    local art_size = cfg.art_size or UI.widget_height or 32
    local album_art = Gtk.Picture.new()
    album_art:set_can_shrink(false)
    album_art:set_content_fit(Gtk.ContentFit.FILL)
    album_art:set_size_request(art_size, art_size)
    album_art:set_halign(Gtk.Align.CENTER)
    album_art:set_valign(Gtk.Align.CENTER)

    -- Create buttons with GTK icons
    local prev_btn = Gtk.Button.new()
    local prev_icon = Gtk.Image.new_from_icon_name("media-skip-backward-symbolic")
    prev_btn:set_child(prev_icon)

    local toggle_btn = Gtk.Button.new()
    local toggle_icon = Gtk.Image.new_from_icon_name("media-playback-start-symbolic")
    toggle_btn:set_child(toggle_icon)

    local next_btn = Gtk.Button.new()
    local next_icon = Gtk.Image.new_from_icon_name("media-skip-forward-symbolic")
    next_btn:set_child(next_icon)

    -- Calculate fixed width for label to prevent unicode symbol width changes
    local widget_width = cfg.width or 400
    local buttons_width = 120 -- approximate width of 3 buttons
    local art_width = (cfg.show_art ~= false) and art_size or 0
    local label_width = widget_width - buttons_width - art_width - 20 -- 20px margin

    -- Create scrollable label container with fixed width
    local info_label = Gtk.Label.new("No track")
    info_label:set_ellipsize(0) -- PANGO_ELLIPSIZE_NONE - don't ellipsize, we handle scrolling
    info_label:set_xalign(0) -- Left align

    -- Wrap label in a box with fixed width to prevent resizing
    local label_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
    label_box:append(info_label)
    label_box:set_size_request(label_width, -1)
    label_box:set_hexpand(false)

    -- Apply CSS classes
    media_box:add_css_class("media-widget")
    prev_btn:add_css_class("media-pill-left")
    toggle_btn:add_css_class("media-pill-middle")
    next_btn:add_css_class("media-pill-middle")
    label_box:add_css_class("media-pill-right")

    -- Apply themed CSS if provided in config
    if cfg and cfg.css then
        apply_css(media_box, cfg.css)
    end

    -- Button actions
    prev_btn.on_clicked = function()
        run_shell_command_async({ media_script, "prev" }, function() end)
    end

    toggle_btn.on_clicked = function()
        run_shell_command_async({ media_script, "toggle" }, function() end)
    end

    next_btn.on_clicked = function()
        run_shell_command_async({ media_script, "next" }, function() end)
    end

    -- Marquee scrolling state
    local full_text = "No track"
    local previous_text = "No track"
    local scroll_offset = 0
    local scroll_timer = nil
    local current_art_url = nil

    -- Download and cache album art
    local function download_album_art(url, callback)
        if not url or url == "" then
            callback(nil)
            return
        end

        local cache_dir = os.getenv("HOME") .. "/.cache/calisto"
        os.execute("mkdir -p " .. cache_dir)

        -- Handle file:// URLs
        if url:match("^file://") then
            local local_path = url:sub(8) -- Remove "file://"
            callback(local_path)
            return
        end

        -- Handle HTTP(S) URLs with caching
        local image_id = url:match("/([a-f0-9]+)$")
        local cache_file
        if image_id then
            cache_file = cache_dir .. "/" .. image_id .. ".jpg"
        else
            -- Create a simple hash from URL
            local hash = 0
            for i = 1, #url do
                hash = ((hash * 31) + url:byte(i)) % 0x7FFFFFFF
            end
            cache_file = cache_dir .. "/art_" .. hash .. ".jpg"
        end

        -- Return cached file if it exists
        local f = io.open(cache_file, "r")
        if f then
            f:close()
            callback(cache_file)
            return
        end

        -- Download the image asynchronously
        run_shell_command_async({
            "curl", "-sL", "-f", "--max-time", "5", "-o", cache_file, url
        }, function(output, err)
            if not err then
                -- Verify file was downloaded
                local verify = io.open(cache_file, "r")
                if verify then
                    verify:close()
                    callback(cache_file)
                else
                    callback(nil)
                end
            else
                callback(nil)
            end
        end)
    end

    -- Update function
    local function update_media()
        -- Get full status including class
        run_shell_command_async({ media_script, "status" }, function(output, err)
            if not err and output then
                local ok, data = pcall(Json.decode, output)
                if ok then
                    -- Update icon based on playback state from class
                    if data.class then
                        local state = nil
                        for _, cls in ipairs(data.class) do
                            if cls == "playing" then
                                state = "playing"
                                break
                            elseif cls == "paused" then
                                state = "paused"
                                break
                            end
                        end

                        if state == "playing" then
                            toggle_icon:set_from_icon_name("media-playback-pause-symbolic")
                        else
                            toggle_icon:set_from_icon_name("media-playback-start-symbolic")
                        end
                    end
                end
            end
        end)

        -- Get track info
        run_shell_command_async({ media_script, "track" }, function(output, err)
            if not err and output then
                local ok, data = pcall(Json.decode, output)
                if ok and data.text then
                    -- Clean text: remove leading/trailing whitespace and non-printable chars
                    -- Remove common icon byte sequences (UTF-8 for Private Use Area)
                    local new_text = data
                        .text
                        :gsub("[\239][\140-\191][\128-\191]", "") -- Remove U+E000-U+EFFF range
                        :gsub("[\239][\184-\191][\128-\191]", "") -- Remove U+F800-U+FFFF range
                        :gsub("^%s+", "")
                        :gsub("%s+$", "") -- Trim whitespace
                    if new_text == "" then
                        new_text = "No track"
                    end

                    -- Only reset scroll if track changed
                    if new_text ~= previous_text then
                        full_text = new_text
                        previous_text = new_text
                        scroll_offset = 0

                        -- Calculate visible characters based on fixed label width
                        -- Estimate ~8 pixels per character for monospace font
                        local max_visible_chars = math.max(30, math.floor(label_width / 8))

                        -- If text is too long, start scrolling
                        local full_text_len = utf8_len(full_text)
                        if full_text_len > max_visible_chars then
                            if scroll_timer then
                                GLib.source_remove(scroll_timer)
                            end
                            scroll_timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, function()
                                scroll_offset = scroll_offset + 1
                                if scroll_offset > full_text_len then
                                    scroll_offset = 0
                                end
                                local doubled_text = full_text .. "   " .. full_text
                                local visible_text = utf8_sub(doubled_text, scroll_offset + 1, scroll_offset + max_visible_chars)
                                info_label:set_text(visible_text)
                                return true
                            end)
                        else
                            if scroll_timer then
                                GLib.source_remove(scroll_timer)
                                scroll_timer = nil
                            end
                            info_label:set_text(full_text)
                        end
                    end
                end
            end
        end)

        -- Get album art URL
        run_shell_command_async({
            "playerctl", "-p", "spotube,spotify", "metadata", "--format", "{{mpris:artUrl}}"
        }, function(output, err)
            if not err and output then
                local art_url = output:gsub("^%s+", ""):gsub("%s+$", "")
                if art_url ~= "" and art_url ~= current_art_url then
                    current_art_url = art_url
                    download_album_art(art_url, function(art_file)
                        if art_file then
                            -- Load and display the album art
                            local ok, pixbuf_err = pcall(function()
                                local pixbuf = GdkPixbuf.Pixbuf.new_from_file(art_file)
                                -- Scale to art_size maintaining aspect ratio
                                local orig_width = pixbuf:get_width()
                                local orig_height = pixbuf:get_height()
                                local scale_factor = art_size / math.max(orig_width, orig_height)
                                local new_width = math.floor(orig_width * scale_factor)
                                local new_height = math.floor(orig_height * scale_factor)
                                local scaled = pixbuf:scale_simple(new_width, new_height, 2) -- INTERP_BILINEAR = 2
                                local texture = Gdk.Texture.new_for_pixbuf(scaled)
                                album_art:set_paintable(texture)
                                album_art:set_size_request(new_width, new_height)
                            end)
                            if not ok then
                                print("ERROR: Failed to load album art:", pixbuf_err)
                            end
                        else
                            -- Clear album art if download failed
                            album_art:set_paintable(nil)
                        end
                    end)
                end
            end
        end)

        return true -- Continue timer
    end

    -- Initial update and setup timer
    update_media()
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, update_media)

    -- Add widgets to box
    media_box:append(prev_btn)
    media_box:append(toggle_btn)
    media_box:append(next_btn)
    media_box:append(label_box)
    if cfg.show_art ~= false then
        media_box:append(album_art)
    end

    return media_box
end

Widgets.window = {}
function Widgets.window:new(cfg)
    local window_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
    window_box:set_vexpand(true)
    window_box:set_valign(Gtk.Align.FILL)
    window_box:add_css_class("window-widget")

    -- Create scrollable label
    local window_label = Gtk.Label.new("Desktop")
    window_label:set_ellipsize(3) -- PANGO_ELLIPSIZE_END
    window_label:set_max_width_chars(60)
    window_label:set_xalign(0) -- Left align

    window_box:append(window_label)

    -- UTF-8 aware string functions
    local function utf8_chars(str)
        local chars = {}
        local i = 1
        while i <= #str do
            local byte = string.byte(str, i)
            local char_len = 1
            if byte >= 0xF0 then
                char_len = 4
            elseif byte >= 0xE0 then
                char_len = 3
            elseif byte >= 0xC0 then
                char_len = 2
            end
            table.insert(chars, string.sub(str, i, i + char_len - 1))
            i = i + char_len
        end
        return chars
    end

    local function utf8_sub(str, start_char, end_char)
        local chars = utf8_chars(str)
        local result = {}
        for i = start_char, math.min(end_char, #chars) do
            table.insert(result, chars[i])
        end
        return table.concat(result)
    end

    local function utf8_len(str)
        return #utf8_chars(str)
    end

    -- Marquee scrolling state
    local full_text = "Desktop"
    local scroll_offset = 0
    local scroll_timer = nil
    local update_pending = false

    -- Set up direct Sway IPC connection
    local ipc = SwayIPC:new()
    local ok, err = ipc:connect()

    if not ok then
        print("ERROR: Failed to connect to Sway IPC for window:", err)
        return window_box
    end

    local function update_window()
        ipc:get_tree(function(data, get_err)
            if get_err then
                print("ERROR: Failed to get window tree:", get_err)
                return
            end

            if not data then
                print("ERROR: Empty data from IPC get_tree")
                return
            end

            -- Find focused window recursively
            local function find_focused(node)
                if node.focused and node.name then
                    return node.name
                end
                if node.nodes then
                    for _, child in ipairs(node.nodes) do
                        local result = find_focused(child)
                        if result then
                            return result
                        end
                    end
                end
                if node.floating_nodes then
                    for _, child in ipairs(node.floating_nodes) do
                        local result = find_focused(child)
                        if result then
                            return result
                        end
                    end
                end
                return nil
            end

            local title = find_focused(data) or "Desktop"
            full_text = title
            scroll_offset = 0

            -- If text is too long, start scrolling
            local max_visible_chars = 60
            local full_text_len = utf8_len(full_text)
            if full_text_len > max_visible_chars then
                if scroll_timer then
                    GLib.source_remove(scroll_timer)
                end
                scroll_timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, function()
                    scroll_offset = scroll_offset + 1
                    if scroll_offset > full_text_len then
                        scroll_offset = 0
                    end
                    local doubled_text = full_text .. "   " .. full_text
                    local visible_text = utf8_sub(doubled_text, scroll_offset + 1, scroll_offset + max_visible_chars)
                    window_label:set_text(visible_text)
                    return true
                end)
            else
                if scroll_timer then
                    GLib.source_remove(scroll_timer)
                    scroll_timer = nil
                end
                window_label:set_text(full_text)
            end
        end)
    end

    -- Schedule window update with idle priority for coalescing
    local function schedule_window_update()
        if update_pending then
            return -- Already scheduled
        end
        update_pending = true

        GLib.idle_add(GLib.PRIORITY_HIGH_IDLE, function()
            update_pending = false
            update_window()
            return false
        end)
    end

    -- Initial update
    update_window()

    -- Subscribe to window events
    local subscribe_ok, subscribe_err = ipc:subscribe({"window"}, function(event)
        if event.change == "focus" or event.change == "title" or event.change == "close" then
            schedule_window_update()
        end
    end)

    if not subscribe_ok then
        print("ERROR: Failed to subscribe to window events:", subscribe_err)
        ipc:disconnect()
        return window_box
    end

    -- Start event loop
    ipc:start_event_loop()

    -- Apply CSS if provided
    if cfg and cfg.css then
        apply_css(window_box, cfg.css)
    end

    return window_box
end

Widgets.audio = {}
function Widgets.audio:new(cfg)
    local audio_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 4)
    audio_box:set_vexpand(true)
    audio_box:set_valign(Gtk.Align.FILL)
    audio_box:add_css_class("audio-widget")

    local volume_label = Gtk.Label.new("--% ")
    audio_box:append(volume_label)

    local function update_audio()
        run_shell_command_async({ "pactl", "get-sink-volume", "@DEFAULT_SINK@" }, function(output, err)
            if not err and output then
                -- Parse volume from pactl output: "Volume: front-left: 65536 /  100% / 0.00 dB"
                local volume = output:match("(%d+)%%")
                if volume then
                    -- Get mute status
                    run_shell_command_async(
                        { "pactl", "get-sink-mute", "@DEFAULT_SINK@" },
                        function(mute_output, mute_err)
                            if not mute_err and mute_output then
                                local is_muted = mute_output:match("yes")
                                if is_muted then
                                    volume_label:set_text("mute ")
                                else
                                    local icon = ""
                                    local vol_num = tonumber(volume)
                                    if vol_num <= 33 then
                                        icon = ""
                                    elseif vol_num <= 66 then
                                        icon = ""
                                    else
                                        icon = ""
                                    end
                                    volume_label:set_text(string.format("%3s%% %s", volume, icon))
                                end
                            end
                        end
                    )
                end
            end
        end)
        return true
    end

    -- Update every 2 seconds
    update_audio()
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, update_audio)

    -- Apply CSS if provided
    if cfg and cfg.css then
        apply_css(audio_box, cfg.css)
    end

    return audio_box
end

Widgets.network = {}
function Widgets.network:new(cfg)
    local network_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 4)
    network_box:set_vexpand(true)
    network_box:set_valign(Gtk.Align.FILL)
    network_box:add_css_class("network-widget")

    local network_label = Gtk.Label.new("offline")
    network_box:append(network_label)

    local function update_network()
        run_shell_command_async(
            { "nmcli", "-t", "-f", "TYPE,STATE,NAME", "connection", "show", "--active" },
            function(output, err)
                if not err and output then
                    local lines = {}
                    for line in output:gmatch("[^\r\n]+") do
                        table.insert(lines, line)
                    end

                    if #lines > 0 then
                        -- Parse first active connection: TYPE:STATE:NAME
                        local parts = {}
                        for part in lines[1]:gmatch("[^:]+") do
                            table.insert(parts, part)
                        end

                        if #parts >= 3 then
                            local conn_type = parts[1]
                            local conn_name = parts[3]

                            if conn_type == "802-11-wireless" or conn_type == "wifi" then
                                -- Get signal strength for wifi - get the first line which is the active connection
                                run_shell_command_async({
                                    "sh",
                                    "-c",
                                    "nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no | grep '^\\*' | cut -d: -f2",
                                }, function(signal_output, signal_err)
                                    if not signal_err and signal_output then
                                        local signal = signal_output:match("(%d+)")
                                        if signal then
                                            network_label:set_text(string.format("%s (%s%%) ", conn_name, signal))
                                        else
                                            network_label:set_text(conn_name .. " ")
                                        end
                                    else
                                        network_label:set_text(conn_name .. " ")
                                    end
                                end)
                            else
                                -- Ethernet or other
                                network_label:set_text(conn_name .. " ")
                            end
                        else
                            network_label:set_text("online")
                        end
                    else
                        network_label:set_text("offline")
                    end
                else
                    network_label:set_text("offline")
                end
            end
        )
        return true
    end

    -- Update every 3 seconds
    update_network()
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 3000, update_network)

    -- Apply CSS if provided
    if cfg and cfg.css then
        apply_css(network_box, cfg.css)
    end

    return network_box
end

Widgets.systray = {}
function Widgets.systray:new(cfg)
    cfg = cfg or {}
    local tray_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 4)
    tray_box:set_vexpand(true)
    tray_box:set_valign(Gtk.Align.FILL)
    tray_box:add_css_class("systray-widget")

    local tray_items = {} -- Map of service -> widget

    -- Extract icon name from SNI item
    local function get_icon_for_item(service, callback)
        -- Try to get IconName property
        local bus = "session"
        local service_name = service:match("^([^/]+)")
        local object_path = service:match("^[^/]+(/.+)$") or "/StatusNotifierItem"

        if not service_name then
            callback(nil)
            return
        end

        -- Query the IconName property
        run_shell_command_async({
            "busctl",
            "--user",
            "get-property",
            service_name,
            object_path,
            "org.kde.StatusNotifierItem",
            "IconName",
        }, function(output, err)
            if not err and output then
                -- Parse output: s "icon-name"
                local icon = output:match('"([^"]+)"')
                callback(icon)
            else
                -- Fallback: try to extract from service name
                local fallback_icon = service_name:match("%.([^%.]+)$") or service_name
                callback(fallback_icon:lower())
            end
        end)
    end

    local function add_tray_item(service)
        if tray_items[service] then
            return -- Already exists
        end

        get_icon_for_item(service, function(icon_name)
            local btn = Gtk.Button.new()
            btn:add_css_class("tray-item")

            if icon_name then
                local icon = Gtk.Image.new_from_icon_name(icon_name)
                icon:set_pixel_size(16)
                btn:set_child(icon)
                print("[systray] Added item:", service, "with icon:", icon_name)
            else
                -- Fallback to dot if no icon
                btn:set_label("•")
                print("[systray] Added item:", service, "with no icon")
            end

            btn.on_clicked = function()
                -- Activate the tray item
                local service_name = service:match("^([^/]+)")
                local object_path = service:match("^[^/]+(/.+)$") or "/StatusNotifierItem"
                run_shell_command_async({
                    "busctl",
                    "--user",
                    "call",
                    service_name,
                    object_path,
                    "org.kde.StatusNotifierItem",
                    "Activate",
                    "ii",
                    "0",
                    "0",
                }, function(output, err)
                    if err then
                        print("[systray] Failed to activate:", service, err)
                    end
                end)
            end

            tray_box:append(btn)
            tray_items[service] = btn
        end)
    end

    local function remove_tray_item(service)
        local btn = tray_items[service]
        if btn then
            tray_box:remove(btn)
            tray_items[service] = nil
            print("[systray] Removed item:", service)
        end
    end

    local function update_tray_items()
        -- Query registered items
        run_shell_command_async({
            "sh",
            "-c",
            "busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null",
        }, function(output, err)
            if not err and output then
                local current_services = {}
                for service in output:gmatch('"([^"]+)"') do
                    current_services[service] = true
                    add_tray_item(service)
                end

                -- Remove items that no longer exist
                for service in pairs(tray_items) do
                    if not current_services[service] then
                        remove_tray_item(service)
                    end
                end
            end
        end)
    end

    -- Initial update
    update_tray_items()

    -- Poll for changes every 2 seconds
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, function()
        update_tray_items()
        return true
    end)

    -- Apply CSS if provided
    if cfg.css then
        apply_css(tray_box, cfg.css)
    end

    return tray_box
end

Widgets.workspaces = {}
function Widgets.workspaces:new(cfg)
    local gap = (cfg and cfg.gap) or 2
    local workspace_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
    workspace_box:set_vexpand(true)
    workspace_box:set_valign(Gtk.Align.FILL)
    workspace_box:set_spacing(gap) -- Configurable spacing between workspace buttons

    -- Set up direct Sway IPC connection
    local ipc = SwayIPC:new()
    local ipc_ok, ipc_err = ipc:connect()

    if not ipc_ok then
        print("ERROR: Failed to connect to Sway IPC for workspaces:", ipc_err)
        return workspace_box
    end

    -- get_sway_workspaces using direct IPC
    local get_sway_workspaces = function(callback)
        ipc:get_workspaces(function(data, err)
            if err then
                print("ERROR: Failed to get sway workspaces:", err)
                callback({}, err)
                return
            end
            local parsed_workspaces = parse_sway_json(Json.encode(data))
            callback(parsed_workspaces, nil)
        end)
    end

    local current_buttons = {} -- Map from workspace number to Gtk.Button
    local last_states = {} -- Map from workspace number to its last known state {focused, urgent, urgent, visible}

    local function process_workspaces(workspaces)
        local new_button_order = {} -- To store buttons in the order they should appear
        local new_num_to_ws = {} -- Map new workspace numbers to their data for easy lookup

        for _, ws in ipairs(workspaces) do
            new_num_to_ws[ws.num] = ws
        end

        -- Process existing and new workspaces
        for _, ws in ipairs(workspaces) do
            local btn = current_buttons[ws.num]
            local is_new_button = false

            if not btn then
                -- Create new button if it doesn't exist
                btn = Gtk.Button.new_with_label(ws.name)
                btn:add_css_class("workspace") -- Add base class
                btn.on_clicked = function()
                    run_shell_command_async({ "swaymsg", "workspace", ws.name }, function(output, err)
                        if err then
                            print("ERROR: Failed to switch workspace:", err)
                        end
                    end)
                end
                workspace_box:append(btn)
                current_buttons[ws.num] = btn
                is_new_button = true
            else
                -- Update label if name changed
                if btn:get_label() ~= ws.name then
                    btn:set_label(ws.name)
                end
            end
            table.insert(new_button_order, btn)

            -- Update CSS classes if state changed or it's a new button
            local last_state = last_states[ws.num]
            local state_changed = not last_state
                or last_state.focused ~= ws.focused
                or last_state.urgent ~= ws.urgent
                or last_state.visible ~= ws.visible

            if is_new_button or state_changed then
                -- Remove all state-related classes first
                btn:remove_css_class("focused")
                btn:remove_css_class("urgent")
                btn:remove_css_class("occupied")

                -- Add new state-related classes
                if ws.focused then
                    btn:add_css_class("focused")
                elseif ws.urgent then
                    btn:add_css_class("urgent")
                elseif ws.visible then
                    btn:add_css_class("occupied")
                end
            end
            last_states[ws.num] = { focused = ws.focused, urgent = ws.urgent, visible = ws.visible }
        end

        -- Remove buttons for workspaces that no longer exist
        for num, btn in pairs(current_buttons) do
            if not new_num_to_ws[num] then
                workspace_box:remove(btn)
                current_buttons[num] = nil
                last_states[num] = nil
            end
        end

        for i, btn in ipairs(new_button_order) do
            if i == 1 then
                workspace_box:reorder_child_after(btn, nil) -- Place first button at the beginning
            else
                workspace_box:reorder_child_after(btn, new_button_order[i - 1])
            end
        end
    end

    -- Immediate update with minimal debouncing for better responsiveness
    local update_pending = false
    local function update_workspaces_ui_from_sway()
        get_sway_workspaces(function(workspaces, err)
            if err then
                print("ERROR: Failed to get workspaces:", err)
                -- Keep existing UI on error instead of clearing
                return
            end

            if not workspaces or #workspaces == 0 then
                print("WARNING: Empty workspace array from swaymsg")
                return
            end

            process_workspaces(workspaces)
        end)
        return true -- Continue GLib.timeout_add
    end

    local function schedule_update()
        if update_pending then
            return -- Already scheduled
        end
        update_pending = true

        GLib.idle_add(GLib.PRIORITY_HIGH_IDLE, function()
            update_pending = false
            update_workspaces_ui_from_sway()
            return false
        end)
    end

    -- Initial update
    update_workspaces_ui_from_sway()

    -- Subscribe to workspace events
    local subscribe_ok, subscribe_err = ipc:subscribe({"workspace"}, function(event)
        if event.change then
            schedule_update()
        end
    end)

    if not subscribe_ok then
        print("ERROR: Failed to subscribe to workspace events:", subscribe_err)
        ipc:disconnect()
        return workspace_box
    end

    -- Start event loop
    ipc:start_event_loop()

    -- Apply CSS if provided
    if cfg and cfg.css then
        apply_css(workspace_box, cfg.css)
    end

    print("Workspaces widget created, returning workspace_box")
    return workspace_box
end

return Widgets
