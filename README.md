# dotfiles

System configs for `hypr-cachy` (CachyOS/Hyprland desktop) and other machines,
managed with [chezmoi](https://chezmoi.io).

Source lives in `~/dotfiles` rather than chezmoi's default
`~/.local/share/chezmoi`, so `sourceDir` is set explicitly in the generated
`~/.config/chezmoi/chezmoi.toml`.

## Install on a new machine

```sh
sudo pacman -S --needed go git
git clone git@github.com:jrdriscoll17/dotfiles.git ~/dotfiles
cd ~/dotfiles/bootstrap && make install
setup
```

`setup` is the interactive installer (`bootstrap/`). It detects the host, lets
you pick components, installs their packages, hands the configs to chezmoi, and
runs the bootstrap that nothing else tracks — tpm, fisher, lazy.nvim, Doom, the
wallpapers clone, the first theme render. It installs chezmoi itself if absent.

It is re-runnable: everything is checked first, so a second run installs only
what is missing and asks only about files that actually differ.

```sh
setup          # interactive
setup -plan    # report what would happen, change nothing
```

**Components are opt-out.** Doom Emacs and Media are off by default; anything
in the list can be deselected. Laptop-only and desktop-only components are
filtered by whether a battery exists.

**Conflicts are yours to resolve.** When a config already exists and differs
from the repo, `setup` stops and offers, per file: show the diff, keep yours,
back yours up then take the repo's, or overwrite. Answer once and it offers to
apply the same choice to the rest. Backups land beside the original as
`<name>.before-setup`.

### Doing it by hand

`setup` only orchestrates; nothing stops you driving the pieces directly:

```sh
chezmoi init --source ~/dotfiles && chezmoi apply
git clone git@github.com:jrdriscoll17/wallpapers.git ~/wallpapers
ln -sfn ~/wallpapers ~/.config/hypr/wallpapers
```

`init` asks once whether the machine is a laptop and writes the answer to
`~/.config/chezmoi/chezmoi.toml`; templates branch on it.

## Workflow

chezmoi **copies** source → target; the files in `~/.config` are not symlinks.
Editing them directly does not reach the repo:

```sh
chezmoi edit ~/.config/hypr/hyprland.lua   # edit the source
chezmoi diff                               # preview
chezmoi apply                              # deploy
chezmoi re-add                             # pull target-side edits back in
chezmoi cd                                 # shell in the source repo, then git
```

If you do edit a target by hand, `chezmoi re-add` captures it — but note it
skips anything in `.chezmoiignore`.

## Per-host differences

Templates branch on `.laptop` (and `.hostname` if something needs to be more
specific). The worked example is the monitor block in
`dot_config/hypr/hyprland.lua.tmpl`: the desktop's three hardcoded 4K
DisplayPort outputs and workspace pinning, versus `preferred`/`auto` on a
laptop panel.

Prefer runtime detection over templating where it works. Brightness keybinds,
for instance, need no template at all — `XF86MonBrightness` simply never fires
on a desktop keyboard, so the bind is dead weight rather than a bug. Reach for
a template only when the config is *data* that genuinely differs, like the
monitor layout.

To templatize a file: `chezmoi chattr +template <target>`, then edit the
`.tmpl` in the source.

## Generated files

The theme switcher (`~/.config/theme`) rewrites files across many packages on
every `theme apply`. All of that output is in `.chezmoiignore`, so it never
enters git and switching themes produces no diffs.

`run_onchange_after_apply-theme.sh.tmpl` rebuilds it after `chezmoi apply`,
which is what keeps a fresh machine complete — `kitty.conf` has
`include theme.conf` and errors outright if it is missing. The script re-runs
whenever the switcher or a palette changes, tracked by content hashes embedded
in its comments.

A few files are *mutated* in place by `theme.py` rather than generated whole
(`gtk-3.0/settings.ini`, `qt5ct/qt6ct.conf`, `btop.conf`), so they hold real
config and stay tracked. `chezmoi apply` may reset a theme-owned line in them;
the post-apply script immediately puts it back.

Machine-local state is ignored too — `fish_variables`, `theme/current`, the
GTK4 css symlinks into the generated `~/.themes/` tree, and the wallpapers
symlink. See `.chezmoiignore`, which explains each entry.

## Not reproducible: GTK and icon theme assets

`~/.themes/Material-Black-*`, `~/.themes/Colloid-*` and
`~/.local/share/icons/MB-*-Suru-GLOW` are referenced by every palette but are
in no repo and no package. `recolor.py` derives the Material-Black/Suru-GLOW
pair from an *existing* pair, and there is no upstream base left on this
machine to derive from; the Colloid gtk4 themes were installed by hand.

Nothing errors without them — you just get an unstyled desktop — so `setup`
reports them explicitly under system checks. On a new machine, copy
`~/.themes` and `~/.local/share/icons` across, or reinstall an upstream
Material-Black + Suru-GLOW pair and rebuild with
`theme recolor <base> <#hex> <name>`.

## Known issue: kitty font-face leak

Every config reload makes kitty 0.48.1 re-`mmap` all four font faces without
freeing the old ones (~0.7 MB PSS each; RSS overstates it wildly because the
same font pages are counted once per mapping). `theme.py` reloads kitty twice
per apply: once because kitty's own config watcher sees the new `theme.conf`,
and again from the explicit `pkill -USR1 -x kitty` at `theme.py:677`. The
`pkill` is redundant on this kitty version — dropping it would halve the leak.
Left as-is deliberately.
