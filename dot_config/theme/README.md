# Theme switcher

Three desktop themes, each defined once in `themes/<name>.json` and rendered out
to every config on the box.

```
theme list            # what exists, and which one is live
theme set ice-blue    # switch (also: `theme ice-blue`)
theme next            # cycle
theme apply           # re-render the current theme
theme icons           # rebuild the icon index (after installing apps)
theme data            # JSON for the Quickshell picker
```

`Super+Shift+T` opens the picker in the bar (`qs ipc call theme toggle`).

## The themes

| | wallpaper | editors | GTK / icons | accent |
|---|---|---|---|---|
| **onedark** | `wallpaper.jpg` | doom-one / onedark.nvim | Material-Black-OneDark + MB-OneDark-Suru-GLOW | `#61afef` |
| **ice-blue** | `new_rock.jpg` | doom-iceblue / nightfox | Material-Black-IceBlue + MB-IceBlue-Suru-GLOW | `#7fd8e8` |
| **evergreen** | `forest_mist.jpg` | doom-evergreen / everforest | Material-Black-Evergreen + MB-Evergreen-Suru-GLOW | `#a7c080` |

Other wallpapers that suit each: `ice_landscape.jpg` (ice-blue),
`forest_cabin.jpg` and `forest_shrine.jpg` (evergreen).

## What a switch touches

Generated files — never edit these, they are overwritten:

| target | file | picked up |
|---|---|---|
| Quickshell | `quickshell/generated/Colors.qml` | hot reload |
| kitty | `kitty/theme.conf` | SIGUSR1, live |
| alacritty | `alacritty/colors.toml` | live |
| nvim | `nvim/lua/theme.lua` | next start |
| Doom | `doom/theme.el` | next start (`SPC h r r`) |
| hyprpaper | `hypr/hyprpaper.conf` | live (set + verified over IPC) |
| hyprlock | `hypr/colors.conf` | next lock |
| icon index | `quickshell/generated/icons.json` | hot reload |
| btop | `btop/themes/<name>.theme` | next start |
| Kvantum | `Kvantum/<Name>/` | next app start |

Notifications are drawn by the shell itself (`quickshell/notifications/`), not
by a daemon, so they follow the palette with everything else — there is nothing
to regenerate and mako is gone. `Super+Shift+N` dismisses everything on screen;
`qs ipc call notifications dnd` toggles do-not-disturb (notifications still
arrive and stay in the shell's history, they just don't pop).

Settings rewritten in place: `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`
(+ the `gtk.css` symlink for libadwaita), `~/.gtkrc-2.0` for GTK2,
`btop/btop.conf`, `Kvantum/kvantum.kvconfig`, `qt5ct/qt5ct.conf`,
`qt6ct/qt6ct.conf`. GTK also goes through `gsettings` for apps that use the
settings portal. Keys are created if absent — a config missing the key would
otherwise sit silently on the previous theme.

**GTK and Qt apps only re-read this at startup.** A theme switch recolours the
shell, terminals, wallpaper and borders live, but a file manager or editor that
was already open keeps the theme it launched with until you restart it.

Renderer order matters: `render_quickshell` runs **last**, because writing
`generated/Colors.qml` makes Quickshell hot-reload, and that reload kills the
`theme set` process the picker spawned. The picker also launches it with
`setsid -f` so it survives regardless.

Window borders are the one thing with nowhere to persist: they are pushed with
`hyprctl`, and `hyprland.lua` runs `theme apply --quiet` at startup to restore
them.

## Adding or editing a theme

Drop a new `themes/<name>.json` next to the others (copy one — every key is
required) and run `theme apply`. It shows up in `theme list` and in the picker
automatically. Two things aren't generated and need a matching entry:

- **Doom**: `editors.doom` must name a loadable theme. `doom-iceblue` and
  `doom-evergreen` are hand-written in `~/.config/doom/themes/`; keep their
  palettes in sync with the JSON by hand.
- **nvim**: `editors.nvim` must name a colorscheme installed by
  `~/.config/nvim/lua/plugins/colorscheme.lua`.

Comment colours are chosen against a measured contrast ratio (4.5–6:1 on the
editor background) rather than by eye — that was the point of the rebuild, so
keep `colors.comment` well clear of `colors.fgFaint` in new themes.

## GTK, Qt, and icons

The GTK themes and icons are recoloured builds of rtl88's, made by
`theme recolor <base-variant> <#hex> <name>` so each theme's app
chrome matches its palette accent exactly rather than approximating it with a
stock variant:

```
theme recolor Pistachio '#7fd8e8' IceBlue    # any hex, ~2s
```

It works because the colour isn't artwork: the GTK theme states its accent as a
single hex (81 times in gtk.css, plus 35 GTK2 PNGs that get re-tinted by hue),
and every one of the ~25k icons is painted by one two-stop gradient. The
upstream variants stay installed as bases — Blueberry, Pistachio and Lime. The GTK themes are GTK2/3 only, so
each theme's `gtk.gtk4` key names a Colloid variant in the same palette to borrow
a GTK4 sheet from — the few GTK4 apps stay in-palette even though they can't have
the Material-Black look.

The Suru-GLOW icon themes ship no `Inherits=`, so anything they lack would fall
back to hicolor and render blank; the install adds
`Inherits=Papirus-Dark,Papirus,hicolor`. That's the only reason Papirus is still
installed, and it's the largest thing here at ~420MB — droppable if you'd rather
have the space than the fallback.

`~/.local/src/theme-gtk-build.sh` rebuilds all of it from nothing on a fresh
machine: it clones each source into a staging dir, installs, recolours, and
deletes the checkouts again (they are far larger than what they produce — the
rtl88 branch alone is 2.7 GB). It also builds a dart-sass shim for Colloid,
which wants `sassc`. Nothing here needs root.

Only the recoloured themes are kept on disk. `theme recolor` reads a base's
accent and gradient off the installed files, so a recoloured theme can be the
base for the next one and the upstream variants don't need to stay.

Switching costs about 100ms. Two things used to make it slower, and both are
worth preserving if this code is touched:

- The icon index is cached per icon theme under `~/.cache/theme/`. Each theme
  has its own icon set, so rebuilding on every switch cost ~1.6s of disk
  walking; the cache turns that into a file copy. `theme icons` clears it.
- `services/Icons.qml` loads that index lazily, on the first name Qt can't
  resolve. The shell restarts on every switch, and parsing 2.5MB of JSON each
  time bought nothing while qt6ct is installed.

Wallpapers are kept at 3840x2160, the native resolution here — the originals
are in `wallpapers/original/`. A 6000x4000 source decodes to ~92MB per monitor
and made hyprpaper spin the fans on every switch.

Qt resolves themed icon names only when a platform theme plugin is installed.
Before `qt6ct` went in, `Quickshell.iconPath()` and `image://icon/...` handled
absolute paths only, which is why the launcher showed letter placeholders and
notifications showed broken-image tiles. `services/Icons.qml` now asks Qt first
and falls back to `quickshell/generated/icons.json`, an index `theme apply`
writes for the active icon theme and everything it inherits. Keep the fallback:
it covers names Qt misses and survives the plugin going away. Run `theme icons`
after installing apps if a new icon doesn't show up.
