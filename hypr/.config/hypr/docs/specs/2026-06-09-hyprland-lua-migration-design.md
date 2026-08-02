# Hyprland config → Lua migration + in-config Game Mode

Date: 2026-06-09
Status: approved (design)

## Background

Hyprland 0.55.3 deprecates the hyprlang `.conf` format in favor of Lua
(`~/.config/hypr/hyprland.lua`). The user's active config is a single 249-line
`~/.config/hypr/hyprland.conf`. The Game Mode toggle currently lives in an
external bash script (`scripts/game-mode.sh`) invoked via `bind = SUPER,G,exec,...`.

A secondary driver: SDR content looks washed out in HDR because Hyprland's
default `sdr_max_luminance` is 80 nits (and `sdr_min_luminance` 0.2). The classic
`monitor=` string config **cannot** set these luminance tokens (`invalid syntax`),
but the Lua `hl.monitor{}` API can. Moving Game Mode into Lua therefore both
modernizes the config and unlocks the proper washout fix.

Panel: 3× Dell AW3225QF (QD-OLED, 4K 240Hz). EDID reports ~993 nit peak,
~277 nit max-frame-average, ~0 min.

## Goals

1. Rewrite the active `hyprland.conf` as a single `hyprland.lua`, faithfully
   porting every section with no behavioral change to non-HDR features.
2. Replace the external Game Mode script with an in-config Lua function bound to
   `SUPER + G`, preserving the self-healing toggle behavior.
3. Fix SDR-in-HDR washout by setting a correct luminance range in Game Mode.

## Non-goals

- No redesign of keybinds, layout, or look & feel beyond a faithful port.
- Not folding in the orphaned `config/*.conf` files or `hyprland.conf.bak`
  (left untouched).
- No multi-file split (decided: single file).

## Decisions

- **File layout:** single `~/.config/hypr/hyprland.lua`.
- **SDR luminance target:** `sdr_max_luminance = 203` (reference SDR white),
  `sdr_min_luminance = 0`. **Final tuned multipliers (set by eyeball on the
  AW3225QF): `sdrbrightness = 1.3`, `sdrsaturation = 1.3`.** Rationale below
  (luminance range alone did NOT fix washout — it was a saturation problem).
- **Toggle state:** self-healing detection via the in-process **`hl.get_monitor("DP-2")`**
  getter (`nil` ⇒ DP-2 disabled ⇒ game mode on). NOTE: the original plan to use
  `io.popen("hyprctl monitors")` deadlocks — see Implementation Findings.

## Implementation Findings (deviations from original design)

1. **Lua config format is chosen once at Hyprland startup, not on reload.**
   Writing `hyprland.lua` while a `.conf`-started session is running has no
   effect until a full Hyprland **restart**. Verified via probe (`gaps_out`
   didn't change on reload; log: `Lua config not found, using legacy config`).
   Migration therefore required: write complete `.lua` → offline syntax check
   (`luajit -bl`) → user restart. After the switch, `hyprctl reload` reloads Lua
   normally (used for the HDR tuning loop).

2. **`io.popen("hyprctl monitors")` inside a bind callback deadlocks** the
   compositor: the callback runs on the main thread, which is also the thread
   that answers the IPC socket `hyprctl` is waiting on. Symptom: ~2s freeze +
   always-OFF (empty output → wrong branch). Fixed by using the in-process
   getter `hl.get_monitor("DP-2")` (confirmed via source: accepts a string
   selector, resolves only enabled monitors → `nil` when disabled).

3. **Washout was saturation, not luminance.** `sdr_max_luminance = 203`
   (vs default 80) alone left colors "very washed out / faded-pale" while
   brightness/contrast were fine. Fix was `sdrsaturation` (sRGB content mapped
   into the wide-gamut HDR container reads as dull). Converged to
   `sdrsaturation = 1.3`; a small `sdrbrightness = 1.3` removed a remaining dimness.

## Architecture

Single `hyprland.lua` mirroring the current section order:

| Section            | Lua API |
|--------------------|---------|
| Monitors           | `hl.monitor{}` (×4: DP-1/2/3 + HDMI-A-1) |
| Workspace→monitor  | workspace binding (exact form verified in impl step) |
| Programs           | `local terminal = ...` etc. |
| Autostart          | `hl.on("hyprland.start", function() hl.exec_cmd(...) end)` |
| Env vars           | `hl.env(k, v)` |
| Look & feel        | `hl.config{ general=, decoration=, ... }` |
| Animations         | `hl.curve{}` + `hl.animation{}` |
| Misc / Input / Xwayland | `hl.config{ misc=, input=, xwayland= }` |
| Keybinds           | `hl.bind(keys, hl.dsp.*)` / `hl.bind(keys, function() end)` |
| Window rules       | `hl.window_rule{}` |

### Game Mode function

```lua
hl.bind(mainMod .. " + G", function() toggle_game_mode() end)
```

`toggle_game_mode()`:
1. `game_mode_is_on()` = `hl.get_monitor("DP-2") == nil` (in-process; NOT io.popen).
2. Normal → ON: DP-1 @ 239.99 + HDR (Section below); DP-2/DP-3 `disabled = true`;
   `hl.notification.create{}` "Game Mode ON".
3. ON → OFF: DP-1/2/3 restored @ 120 SDR (DP-1 explicitly `bitdepth=8, cm="auto"`);
   notify "Game Mode OFF".

### HDR settings (Game Mode ON, DP-1)

```lua
hl.monitor({
  output = "DP-1", mode = "3840x2160@239.99", position = "1920x0", scale = 2,
  bitdepth = 10,
  cm = "hdr",
  sdr_max_luminance = 203,
  sdr_min_luminance = 0,
  sdrbrightness = 1.3,   -- tuned by eyeball (removed residual dimness)
  sdrsaturation = 1.3,   -- tuned by eyeball (fixed faded/pale colors)
})
```

## Safety / rollback

- `hyprland.conf` left on disk as rollback artifact. Verify empirically that
  0.55 ignores `.conf` when `.lua` is present (via `hyprctl reload`).
- Test with `hyprctl reload` before logging out. Syntax errors only block the
  reload + pop an error; they do not kill the running session.
- `scripts/game-mode.sh` retained until the in-config version is confirmed, then
  removed.

## Open items resolved during implementation

Exact Lua dispatcher names verified against the Dispatchers wiki:
`fullscreen` (1/0), `focusworkspaceoncurrentmonitor`, `movetoworkspacesilent`,
`togglespecialworkspace`, workspace→monitor binding, and the autostart/env forms.

## Verification

- `hyprctl reload` clean (no error popup).
- All keybinds function; 4 monitors in correct positions/refresh.
- `SUPER+G` toggles Game Mode both directions; `hyprctl monitors -j` shows
  DP-1 `XRGB2101010`, `colorManagementPreset hdr`, `sdrMaxLuminance 203`,
  `sdrMinLuminance 0` when ON, and SDR 120Hz ×3 when OFF.
- SDR content visually correct (not washed out) in Game Mode.
