# Hyprland Lua Migration + In-Config Game Mode — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hyprlang `~/.config/hypr/hyprland.conf` with a single `~/.config/hypr/hyprland.lua` (Hyprland 0.55 Lua config), and move the Game Mode toggle from an external bash script into an in-config Lua function that also fixes SDR-in-HDR washout via `sdr_max_luminance`.

**Architecture:** One `hyprland.lua` mirroring the current config's section order. Static settings use `hl.config{}`, `hl.monitor{}`, `hl.env()`, `hl.curve{}`, `hl.animation{}`, `hl.on("hyprland.start", ...)`. Binds use `hl.bind(keys, hl.dsp.*)`. Game Mode is a Lua function (`toggle_game_mode`) bound to `SUPER+G`, self-healing via `io.popen("hyprctl monitors")`. Each section is added incrementally and validated with `hyprctl reload` so any error is isolated.

**Tech Stack:** Hyprland 0.55.3, Lua config (`hl.*` API), `hyprctl` for live reload/verification.

**Environment note:** `/home/jake` is not a git repo, so this plan uses **file-copy snapshots** instead of git commits.

> **⚠️ REVISION 2026-06-09 (post-Task-1 finding):** Hyprland selects the config *format* (`hyprland.lua` vs legacy `hyprland.conf`) **once at startup** and keeps it across `hyprctl reload`. Proven empirically: a probe `hyprland.lua` setting `gaps_out=37` did NOT take effect on reload (stayed `10` from `.conf`); log showed `Lua config not found, using legacy config`. **Consequences:** (1) the original section-by-section reload iteration is NOT possible from the current `.conf` session; (2) switching to Lua requires a **full Hyprland restart** (closes windows) — a human-gated step. Revised approach: write the COMPLETE `hyprland.lua` at once, validate syntax **offline** (`luac -p`/`luajit`, non-disruptive since the file isn't loaded until restart), keep `hyprland.conf` as automatic fallback, then human restarts and verifies. Once Lua is the active format, `hyprctl reload` DOES reload it, so later tuning (T-tune) can iterate normally. Tasks below are restructured accordingly: T2–T5's code is unchanged but is written together (T2-combined) rather than reload-verified individually.

**Reference (verified against wiki + binary):**
- Config path: `~/.config/hypr/hyprland.lua` (`.conf` deprecated since 0.55).
- `hl.monitor{}` accepts `sdr_max_luminance`/`sdr_min_luminance` (the legacy `monitor=` string does NOT).
- `hl.bind(keys, function() ... end)` allows a Lua-function dispatcher.
- `hl.notification.create({ text, duration, icon?, color?, font_size? })`.
- Dispatchers: `hl.dsp.window.close/float/fullscreen/move/drag/resize`, `hl.dsp.focus({direction|workspace, on_current_monitor})`, `hl.dsp.workspace.toggle_special`, `hl.dsp.exec_cmd`, `hl.dsp.exit`.

---

### Task 1: Safety snapshot + confirm Lua/conf precedence

**Files:**
- Create: `~/.config/hypr/_backup-2026-06-09/` (snapshot dir)
- Temp: `~/.config/hypr/hyprland.lua` (throwaway probe, then removed)

- [ ] **Step 1: Snapshot the current config**

```bash
mkdir -p ~/.config/hypr/_backup-2026-06-09
cp ~/.config/hypr/hyprland.conf ~/.config/hypr/_backup-2026-06-09/hyprland.conf
cp ~/.config/hypr/scripts/game-mode.sh ~/.config/hypr/_backup-2026-06-09/game-mode.sh
```

- [ ] **Step 2: Record current live state for later comparison**

```bash
hyprctl monitors -j > /tmp/monitors-before.json
hyprctl binds | wc -l
```
Expected: 4 monitors in JSON; note the bind count.

- [ ] **Step 3: Write a minimal probe hyprland.lua to confirm precedence**

```lua
-- /home/jake/.config/hypr/hyprland.lua  (probe)
hl.notification.create({ text = "LUA CONFIG LOADED", duration = 3000 })
```

- [ ] **Step 4: Reload and confirm Lua is picked up over the existing .conf**

Run: `hyprctl reload`
Expected: an on-screen notification "LUA CONFIG LOADED" appears. This proves `hyprland.lua` takes precedence while `hyprland.conf` still exists.

> If NO notification appears, STOP — precedence assumption is wrong; do not proceed. Investigate `hyprctl reload` output / `/tmp/hypr/hyprland.log`.

- [ ] **Step 5: Remove the probe (full file written in Task 2)**

```bash
rm ~/.config/hypr/hyprland.lua
hyprctl reload   # falls back to hyprland.conf; session restored to known-good
```
Expected: session back to normal 3-monitor layout.

---

### Task 2: Write static config sections (everything except binds, rules, Game Mode)

**Files:**
- Create: `~/.config/hypr/hyprland.lua`

- [ ] **Step 1: Write monitors, workspaces, programs, autostart, env, look & feel, animations, misc/input/xwayland**

```lua
-- ~/.config/hypr/hyprland.lua
-- Migrated from hyprland.conf (hyprlang) on 2026-06-09.
-- Hyprland 0.55 Lua config. See docs/plans/2026-06-09-hyprland-lua-migration.md

------------------
---- MONITORS ----
------------------
hl.monitor({ output = "DP-2",     mode = "3840x2160@120", position = "0x0",     scale = 2 })
hl.monitor({ output = "DP-1",     mode = "3840x2160@120", position = "1920x0",  scale = 2 })
hl.monitor({ output = "DP-3",     mode = "3840x2160@120", position = "3840x0",  scale = 2 })
hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@120", position = "-1920x0", scale = 2 })

hl.workspace_rule({ workspace = "2",  monitor = "DP-2" })
hl.workspace_rule({ workspace = "1",  monitor = "DP-1" })
hl.workspace_rule({ workspace = "3",  monitor = "DP-3" })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1" })

---------------------
---- MY PROGRAMS ----
---------------------
local terminal    = "alacritty"
local fileManager = "pcmanfm"
local menu        = "wofi --show drun"
local browser     = "brave --enable-features=UseOzonePlatform --ozone-platform=wayland --password-store=kwallet"
local discord     = "vesktop"

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("mako")
    hl.exec_cmd("waybar")
    hl.exec_cmd("udiskie")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("plex-mpv-shim")
    -- Slow app launch fix: import env into systemd/dbus user session
    hl.exec_cmd("systemctl --user import-environment")
    hl.exec_cmd("dbus-update-activation-environment --systemd")
    -- NOTE: the old `hash dbus-update-activation-environment 2>/dev/null` exec-once
    -- was a shell builtin and a no-op under exec; intentionally dropped.
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GDK_SCALE", "2")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        col = {
            active_border   = "rgba(61afefee)",
            inactive_border = "rgba(282c34aa)",
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "master",
    },
    decoration = {
        rounding         = 10,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },
        blur = {
            enabled  = true,
            size     = 4,
            passes   = 2,
            vibrancy = 0.1696,
        },
    },
    animations = { enabled = true },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
    input = {
        kb_layout    = "us",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad     = { natural_scroll = false },
    },
    xwayland = {
        use_nearest_neighbor = false,
        force_zero_scaling   = true,
    },
})

----------------------
---- ANIMATIONS  -----
----------------------
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}   } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}   } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}      } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1.0} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}    } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
```

- [ ] **Step 2: Reload and verify static config applies**

Run: `hyprctl reload`
Expected: no error popup. 4 monitors present and correctly placed:
```bash
hyprctl monitors -j | grep -E '"name"|"x":|"refreshRate"'
```
Expected: DP-2 at x=0, DP-1 at x=1920, DP-3 at x=3840, HDMI-A-1 at x=-1920, all ~120Hz. Borders/gaps/blur visually match the old config.

- [ ] **Step 3: Snapshot progress**

```bash
cp ~/.config/hypr/hyprland.lua ~/.config/hypr/_backup-2026-06-09/hyprland.lua.t2
```

---

### Task 3: Add Game Mode function (before binds, so the closure resolves it)

**Files:**
- Modify: `~/.config/hypr/hyprland.lua` (append after ANIMATIONS section)

- [ ] **Step 1: Append the Game Mode section**

```lua
-------------------
---- GAME MODE ----
-------------------
-- Toggle: middle monitor (DP-1) only @ 240Hz + HDR, side monitors off.
-- Self-healing: reads current state live from `hyprctl monitors`.

local function game_mode_is_on()
    local handle = io.popen("hyprctl monitors")
    if not handle then return false end
    local out = handle:read("*a")
    handle:close()
    -- DP-2 is active only in normal mode; absent => we are in game mode.
    return out:find("Monitor DP%-2 ") == nil
end

function toggle_game_mode()
    if game_mode_is_on() then
        -- Restore normal 3-monitor SDR layout. Explicitly clear HDR on DP-1.
        hl.monitor({ output = "DP-2", mode = "3840x2160@120", position = "0x0",    scale = 2 })
        hl.monitor({ output = "DP-1", mode = "3840x2160@120", position = "1920x0", scale = 2,
                     bitdepth = 8, cm = "auto" })
        hl.monitor({ output = "DP-3", mode = "3840x2160@120", position = "3840x0", scale = 2 })
        hl.notification.create({ text = "Game Mode OFF — 3 monitors · 120Hz", duration = 4000 })
    else
        -- Game Mode ON: DP-1 only @ 240Hz + HDR (correct SDR luminance range), sides off.
        hl.monitor({
            output = "DP-1", mode = "3840x2160@239.99", position = "1920x0", scale = 2,
            bitdepth = 10, cm = "hdr",
            sdr_max_luminance = 203, sdr_min_luminance = 0,
            sdrbrightness = 1.0, sdrsaturation = 1.0,
        })
        hl.monitor({ output = "DP-2", disabled = true })
        hl.monitor({ output = "DP-3", disabled = true })
        hl.notification.create({ text = "🎮 Game Mode ON — DP-1 @ 240Hz · HDR · sides off", duration = 4000 })
    end
end
```

- [ ] **Step 2: Reload to verify the function parses (not yet bound)**

Run: `hyprctl reload`
Expected: no error popup. Nothing visually changes (function defined, not called).

---

### Task 4: Add keybinds

**Files:**
- Modify: `~/.config/hypr/hyprland.lua` (append after GAME MODE section)

- [ ] **Step 1: Append all keybinds**

```lua
---------------------
---- KEYBINDINGS ----
---------------------
local mainMod = "SUPER"

hl.bind(mainMod .. " + RETURN",    hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd(discord))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd(menu))

hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
hl.bind(mainMod .. " + T",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())

-- F = maximize (keeps bar/gaps), SHIFT+F = true fullscreen
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Toggle Game Mode
hl.bind(mainMod .. " + G",         function() toggle_game_mode() end)

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces: switch (on current monitor) + move-silent
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i, on_current_monitor = true }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Scratchpad
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys (locked = work on lockscreen, repeating = key-repeat)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Media control (playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
```

- [ ] **Step 2: Reload and verify binds register**

Run: `hyprctl reload && hyprctl binds | grep -ciE "modmask|key"`
Expected: no error popup; bind count comparable to before. Spot-check: `SUPER+RETURN` opens alacritty, `SUPER+1/2/3` switch workspaces on the focused monitor, `SUPER+F` maximizes.

- [ ] **Step 3: Snapshot progress**

```bash
cp ~/.config/hypr/hyprland.lua ~/.config/hypr/_backup-2026-06-09/hyprland.lua.t4
```

---

### Task 5: Add window rules

**Files:**
- Modify: `~/.config/hypr/hyprland.lua` (append at end)

- [ ] **Step 1: Append window rules**

```lua
--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
```

- [ ] **Step 2: Reload and verify no errors**

Run: `hyprctl reload`
Expected: no error popup. Apps still behave (no spurious maximize). 

---

### Task 6: Verify Game Mode toggle both directions

**Files:** none (runtime verification)

- [ ] **Step 1: From normal mode, toggle Game Mode ON**

Press `SUPER+G` (or `hyprctl dispatch` is not applicable — it's a Lua-fn bind, so press the key). 
Expected: notification "🎮 Game Mode ON"; DP-2/DP-3 go dark; DP-1 stays.

- [ ] **Step 2: Verify HDR + luminance applied**

```bash
hyprctl monitors -j | grep -iE '"name"|currentFormat|colorManagementPreset|sdrMaxLuminance|sdrMinLuminance'
```
Expected for DP-1: `currentFormat XR30`/`XRGB2101010`, `colorManagementPreset "hdr"`, `sdrMaxLuminance 203`, `sdrMinLuminance 0`. DP-2/DP-3 absent (disabled).

- [ ] **Step 3: Toggle Game Mode OFF**

Press `SUPER+G`.
Expected: notification "Game Mode OFF"; all three monitors return @120Hz; DP-1 `colorManagementPreset` no longer "hdr" (back to auto/srgb), `currentFormat` back to 8-bit.

- [ ] **Step 4: Verify self-heal heuristic**

```bash
hyprctl monitors | grep -c "Monitor DP-2 "
```
Expected: `1` when normal (DP-2 active). Toggle ON, re-run → `0`. Confirms `game_mode_is_on()` tracks reality.

---

### Task 7: HDR washout tuning + cleanup

**Files:**
- Modify: `~/.config/hypr/hyprland.lua` (only if tuning needed)
- Delete: `~/.config/hypr/scripts/game-mode.sh` (after confirmation)

- [ ] **Step 1: Eyeball SDR content in Game Mode**

Toggle ON, open an SDR app (terminal/browser). Confirm it is NOT washed out and blacks are deep. If too dim/bright, adjust `sdr_max_luminance` (try 250 brighter / 160 dimmer) in the GAME MODE section, `hyprctl reload`, re-toggle. Iterate until it looks right.

- [ ] **Step 2: Remove the old keybind path + script (the bind already points at the Lua fn)**

```bash
rm ~/.config/hypr/scripts/game-mode.sh
```
(The old `bind = SUPER,G,exec,...sh` lived only in `hyprland.conf`, which is no longer loaded. No edit needed beyond deleting the script. Keep `hyprland.conf` itself as rollback.)

- [ ] **Step 3: Final full-session verification**

Run: `hyprctl reload`
Expected: clean reload, no error popup. Walk through: monitors, a few binds, Game Mode both ways. Compare against `/tmp/monitors-before.json` for the normal layout.

- [ ] **Step 4: Confirm it survives a fresh start (highest-risk check)**

Log out and back in (or reboot when convenient). Expected: Hyprland starts from `hyprland.lua` cleanly with the full layout, autostart apps, and Game Mode bind working.

> Rollback if anything fails on fresh start: `mv ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.broken` — Hyprland falls back to the still-present `hyprland.conf`.

- [ ] **Step 5: Final snapshot**

```bash
cp ~/.config/hypr/hyprland.lua ~/.config/hypr/_backup-2026-06-09/hyprland.lua.final
```

---

## Self-review notes

- **Spec coverage:** monitors+workspaces (T2), programs/autostart/env (T2), look&feel/animations/misc/input/xwayland (T2), Game Mode fn w/ self-heal + luminance (T3,T6), binds incl. SUPER+G→fn (T4), window rules (T5), HDR washout fix `sdr_max_luminance=203` (T3), safety/rollback (T1,T7). All spec items mapped.
- **No placeholders:** every code step is complete literal Lua; every verify step has an exact command + expected result.
- **Name consistency:** `toggle_game_mode` (global) defined in T3, referenced in T4 bind; `game_mode_is_on` local helper used only within T3.
- **Known risk to watch:** `cm = "auto"` + `bitdepth = 8` in the OFF branch is the explicit HDR-clear; if a future Hyprland leaves HDR latched, set `cm = "srgb"` instead.

---

## Post-implementation note (2026-06-09)

Shipped and verified. Two deviations from the task code above (see the design
doc's "Implementation Findings" for detail):

- **Toggle state detection:** `io.popen("hyprctl monitors")` (T3 code) was
  replaced by the in-process getter `hl.get_monitor("DP-2") == nil`. The
  io.popen approach deadlocks the compositor from inside a bind callback.
- **Final HDR tuning:** washout was a saturation issue, not luminance. Final
  values: `sdr_max_luminance=203, sdr_min_luminance=0, sdrbrightness=1.3,
  sdrsaturation=1.3` (tuned by eyeball on the AW3225QF).

Old `scripts/game-mode.sh` removed (backed up in `_backup-2026-06-09/`).
`hyprland.conf` retained as rollback artifact.
