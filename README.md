# dotfiles

System configs for `hypr-cachy` (CachyOS/Hyprland desktop) and `linux-work`,
deployed with GNU stow. Each top-level directory is a stow package whose
contents mirror paths relative to `$HOME`.

## Layout

| Package | Deploys | Hosts |
|---|---|---|
| `fish` | `~/.config/fish` | all |
| `tmux` | `~/.tmux.conf` | all |
| `nvim` | `~/.config/nvim` | all |
| `doom` | `~/.config/doom` | all |
| `git` | `~/.gitconfig`, `~/.config/git` | all |
| `hypr` | `~/.config/hypr` (hyprland.lua, hypridle, hyprlock, hyprpaper, scripts) | desktop |
| `quickshell` | `~/.config/quickshell` | desktop |
| `theme` | `~/.config/theme` (theme switcher) | desktop |
| `kitty` | `~/.config/kitty` | desktop |
| `alacritty` | `~/.config/alacritty` | desktop |
| `btop` | `~/.config/btop` | desktop |
| `gtk` | `~/.config/gtk-3.0`, `~/.config/gtk-4.0`, `~/.gtkrc-2.0` | desktop |
| `qt` | `~/.config/qt5ct`, `~/.config/qt6ct`, `~/.config/Kvantum` | desktop |
| `xdg` | `~/.config/mimeapps.list` | desktop |

## Install

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./install.sh core       # portable set — safe on any host
./install.sh desktop    # everything, for the Hyprland box
```

`install.sh` is a thin wrapper around `stow --no-folding -t ~ <pkg>`.

### Why `--no-folding`

Without it, stow replaces a whole directory with a single symlink into the
repo ("tree folding"). That breaks the dirs that must stay machine-local:
`~/.config/quickshell/generated`, `~/.config/hypr/wallpapers`, and
`~/.config/fish/fish_variables` all need to be real paths inside an otherwise
symlinked tree. `--no-folding` creates real directories and symlinks only
leaf files, so those can coexist. **Re-run `install.sh` after adding new files**
to the repo — with no-folding, new files are not picked up automatically.

## Wallpapers

Kept in a separate repo to keep this one small (they were ~41M). `theme.py`
looks for them at `~/.config/hypr/wallpapers`, which is a symlink:

```sh
git clone <wallpapers-repo> ~/wallpapers
ln -sfn ~/wallpapers ~/.config/hypr/wallpapers
```

## Generated files

The theme switcher (`theme/.config/theme/theme.py`) rewrites files across
several packages on every `theme apply`. The small ones are tracked, so a
fresh checkout is immediately usable — `kitty.conf` has `include theme.conf`
and errors if it is missing. The tradeoff is that switching themes produces
diffs in `kitty/theme.conf`, `hypr/colors.conf`, `alacritty/colors.toml`,
`nvim/lua/theme.lua`, `doom/theme.el`, `btop/`, `gtk/`, and `qt/`. That is
expected; commit or discard them as you like.

Larger or host-specific generated output is gitignored — see `.gitignore`.

## Known issue: kitty font-face leak

Every config reload makes kitty 0.48.1 re-`mmap` all four font faces without
freeing the old ones (~0.7 MB PSS each; RSS overstates it wildly because the
same font pages get counted per mapping). `theme.py` reloads kitty twice per
apply: once because kitty's own config watcher sees the new `theme.conf`, and
again from the explicit `pkill -USR1 -x kitty` at `theme.py:677`. The `pkill`
is redundant on this kitty version — dropping it would halve the leak.
Left as-is deliberately.
