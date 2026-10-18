-- hyprland.lua
-- Migrated from hyprland.conf (hyprlang) → Lua (Hyprland ≥ 0.55)
-- Reference: https://wiki.hypr.land/Configuring/
--
-- MIGRATION NOTES:
--   [MANUAL] debug.disable_logs has no direct Lua hl.config() equivalent;
--            use `hyprctl setprop debug:disable_logs false` or omit (logs
--            are enabled by default). Kept as a comment below for reference.
--   [MANUAL] `gesture = 3, horizontal, workspace` → hl.gesture() (see input section)
--   [INFO]   `$mainMod ALT` modifier combo: in Lua, use "SUPER + ALT"
--   [INFO]   bindel → hl.bind(..., { locked=true, repeating=true })
--   [INFO]   bindl  → hl.bind(..., { locked=true })
--   [INFO]   bindm  → hl.bind(..., { mouse=true })
--   [INFO]   exec-once → hl.on("hyprland.start", ...) with hl.exec_cmd()
--   [INFO]   $var references resolved inline as Lua locals

-- catppuccin (still needs references)
local colors = require("themes.catppuccin-macchiato")
-- local another = require("themes.")
local base = colors.base

--------------------
---- MONITORS ----
--------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "1",
})

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "alacritty"
local fileManager = "yazi"
local menu = "fuzzel"
local browser = "librewolf"
local lock = "hyprlock"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
	hl.exec_cmd("waybar & hyprpaper & hypridle")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("wl-paste --watch cliphist store")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- hl.config({ ecosystem = { enforce_permissions = true } })
-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- [MIGRATION NOTE] debug { disable_logs = false } has no Lua equivalent in
-- hl.config(). Logs are on by default. Remove this comment once confirmed.

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 20,
		float_gaps = 3,
		border_size = 3,

		col = {
			-- Gradient border: two colours at 45°
			active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
			inactive_border = "rgba(595959aa)",
		},

		resize_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		rounding_power = 8,

		active_opacity = 0.9,
		inactive_opacity = 0.9,

		dim_inactive = true,
		dim_strength = 0.13,

		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = "rgba(1a1a1aee)",
		},

		blur = {
			enabled = true,
			size = 3,
			passes = 3,
			xray = true,
			popups = true,
			vibrancy = 0.1696,
		},

		-- glow = { enabled = true },
	},

	animations = {
		enabled = true,
	},
})

-- Bezier curves
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/#curves
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- Animations
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only" — uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0, rounding = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0, rounding = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
-- hl.config({
--     dwindle = {
--         pseudotile     = true,  -- master switch for pseudotiling (bound to mainMod + P below)
--         preserve_split = true,
--     },
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
	master = {
		new_status = "master",
	},
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#misc
hl.config({
	misc = {
		force_default_wallpaper = -1, -- set to 0 or 1 to disable anime mascot wallpapers
		disable_hyprland_logo = false,
	},
})

---------------
---- INPUT ----
---------------

-- https://wiki.hypr.land/Configuring/Basics/Variables/#input
hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		follow_mouse = 1,
		sensitivity = 0, -- -1.0 – 1.0, 0 means no modification

		touchpad = {
			natural_scroll = false,
		},

		repeat_delay = 200,
		repeat_rate = 50,
	},
})

-- See https://wiki.hypr.land/Configuring/Basics/Gestures/
hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- "Windows" key as main modifier

-- See https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + BACKSPACE", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(
	mainMod .. " + Delete",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(lock))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + P", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(menu))
-- bind = $mainMod, P, pseudo  -- dwindle (commented in original)
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist-fuzzel-img"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + ALT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
-- hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys — volume and LCD brightness
-- (locked = active even on lockscreen; repeating = held key repeats)
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- ── 1. SUPER + G  →  toggle fullscreen for active window ─────────────────
hl.bind(mainMod .. " + G", hl.dsp.window.fullscreen())

-- ── 2. SUPER + SHIFT + N / P  →  swap window with next/prev in split ─────
-- swapnext cycles forward; "prev" goes backward.
-- Ergonomically paired: same chord family as your focus arrows.
-- hl.bind(mainMod .. " + SHIFT + N", hl.dsp.window.swap_next())
-- hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.swap_next("prev"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.layout("swapsplit"))

-- ── 3. SUPER + ALT + [1-0]  →  swap current workspace with workspace N ───
--
-- No native dispatcher exists for same-monitor workspace swapping.
-- Strategy:
--   a) Collect windows on current WS and target WS.
--   b) Move all current-WS windows to target WS (silently).
--   c) Move all target-WS windows (now identified beforehand) to current WS.
--   d) Navigate to the target WS (so you follow your windows there).
--
-- CAVEAT: hl.dsp.window.move() takes a workspace selector. We pass the
-- numeric ID. The function captures current/target IDs before moving anything.
--
local function swap_workspace(target_id)
	local current_ws = hl.get_active_workspace()
	if current_ws == nil then
		return
	end

	local current_id = current_ws.id

	-- Bail if target is same as current or target is a special workspace (< 1)
	if current_id == target_id or target_id < 1 then
		return
	end

	local all_windows = hl.get_windows()

	-- Snapshot: which windows belong to each workspace BEFORE any moves
	local on_current = {}
	local on_target = {}
	for _, w in ipairs(all_windows) do
		if w.workspace.id == current_id then
			table.insert(on_current, w)
		elseif w.workspace.id == target_id then
			table.insert(on_target, w)
		end
	end

	-- Move current-WS windows → target WS (silent: don't follow)
	for _, w in ipairs(on_current) do
		hl.dispatch(hl.dsp.window.move({ workspace = target_id, window = w, follow = false }))
	end

	-- Move target-WS windows → current WS (silent)
	for _, w in ipairs(on_target) do
		hl.dispatch(hl.dsp.window.move({ workspace = current_id, window = w, follow = false }))
	end

	-- Follow your windows to the target workspace
	hl.dispatch(hl.dsp.focus({ workspace = target_id }))
end

for i = 1, 10 do
	local key = i % 10 -- 10 → key 0, matching your existing loop convention
	local target = i
	hl.bind(mainMod .. " + ALT + " .. key, function()
		swap_workspace(target)
	end)
end

-- ── 4. SUPER + ALT + DELETE  →  close current workspace if empty ──────────
--
-- Hyprland auto-destroys non-persistent workspaces when their last window
-- closes. This bind handles the case where you navigate to a workspace
-- manually and want to "discard" it if it has nothing in it.
-- If non-empty: shows a notification and does nothing.
-- If empty: moves to the previous workspace (e-1), letting Hyprland clean up.
--
hl.bind(mainMod .. " + ALT + Delete", function()
	local ws = hl.get_active_workspace()
	if ws == nil then
		return
	end

	-- Count windows on this workspace
	local count = 0
	for _, w in ipairs(hl.get_windows()) do
		if w.workspace.id == ws.id then
			count = count + 1
		end
	end

	if count > 0 then
		hl.notification.create({
			text = "Workspace "
				.. ws.id
				.. " is not empty ("
				.. count
				.. " window"
				.. (count == 1 and "" or "s")
				.. ")",
			timeout = 2000,
			icon = "warning",
		})
		return
	end

	-- Navigate away; Hyprland will auto-destroy the now-empty, non-persistent WS
	hl.dispatch(hl.dsp.focus({ workspace = "e-1" }))
end)

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.window_rule({
	-- Ignore maximize requests from all apps.
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})
