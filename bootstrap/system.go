package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const wallpapersRepo = "git@github.com:jrdriscoll17/wallpapers.git"

func home() string {
	h, err := os.UserHomeDir()
	if err != nil {
		return os.Getenv("HOME")
	}
	return h
}

func inHome(rel string) string { return filepath.Join(home(), rel) }

func exists(path string) bool {
	_, err := os.Lstat(path)
	return err == nil
}

// run executes a command with the user's terminal attached, so sudo can prompt
// and pacman can draw its progress bars.
func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd.Run()
}

// capture runs a command silently and returns its stdout.
func capture(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	return strings.TrimSpace(string(out)), err
}

func have(bin string) bool {
	_, err := exec.LookPath(bin)
	return err == nil
}

// -- host detection ----------------------------------------------------------

// isLaptop reports whether this machine has a battery. This is the same signal
// the configs should use at runtime rather than hardcoding a hostname.
func isLaptop() bool {
	entries, err := os.ReadDir("/sys/class/power_supply")
	if err != nil {
		return false
	}
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), "BAT") {
			return true
		}
	}
	return false
}

func hostname() string {
	h, _ := os.Hostname()
	return h
}

// -- packages ----------------------------------------------------------------

func pkgInstalled(name string) bool {
	return exec.Command("pacman", "-Qq", name).Run() == nil
}

func missing(pkgs []string) []string {
	var out []string
	for _, p := range pkgs {
		if !pkgInstalled(p) {
			out = append(out, p)
		}
	}
	return out
}

// aurHelper returns paru or yay, whichever is present.
func aurHelper() string {
	for _, h := range []string{"paru", "yay"} {
		if have(h) {
			return h
		}
	}
	return ""
}

func installPackages(pkgs []string) error {
	if len(pkgs) == 0 {
		return nil
	}
	args := append([]string{"pacman", "-S", "--needed"}, pkgs...)
	return run("sudo", args...)
}

func installAUR(pkgs []string) error {
	if len(pkgs) == 0 {
		return nil
	}
	helper := aurHelper()
	if helper == "" {
		return fmt.Errorf("no AUR helper (paru/yay) found; install one to get: %s",
			strings.Join(pkgs, " "))
	}
	return run(helper, append([]string{"-S", "--needed"}, pkgs...)...)
}

// -- chezmoi -----------------------------------------------------------------

func chezmoiReady() bool { return have("chezmoi") }

func installChezmoi() error {
	script := `sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"`
	return run("sh", "-c", script)
}

// FileState is what chezmoi would do to one target path.
type FileState int

const (
	StateClean    FileState = iota // target already matches the source
	StateNew                       // target does not exist; safe to create
	StateConflict                  // target exists and differs — needs a decision
)

// scan asks chezmoi what it would change, restricted to the given paths.
// chezmoi status prints two status columns then the path; an "M" in either
// means the target exists and differs, "A" means it would be created.
func scan(paths []string) (map[string]FileState, error) {
	out, err := capture("chezmoi", "status")
	if err != nil {
		return nil, err
	}
	states := map[string]FileState{}
	for _, line := range strings.Split(out, "\n") {
		if len(line) < 4 {
			continue
		}
		code, path := strings.TrimSpace(line[:2]), strings.TrimSpace(line[3:])
		if !ownedBy(path, paths) {
			continue
		}
		switch {
		case strings.Contains(code, "M"):
			states[path] = StateConflict
		case strings.Contains(code, "A"):
			states[path] = StateNew
		}
	}
	return states, nil
}

// ownedBy reports whether a target path falls under any of the given roots.
func ownedBy(path string, roots []string) bool {
	for _, r := range roots {
		if path == r || strings.HasPrefix(path, r+"/") {
			return true
		}
	}
	return false
}

func applyPaths(paths []string) error {
	if len(paths) == 0 {
		return nil
	}
	args := append([]string{"apply"}, paths...)
	return run("chezmoi", args...)
}

func showDiff(path string) error { return run("chezmoi", "diff", path) }

func backup(path string) error {
	full := inHome(path)
	if !exists(full) {
		return nil
	}
	dst := full + ".before-setup"
	return run("cp", "-a", full, dst)
}

// -- post-install steps ------------------------------------------------------

func tpmInstalled() bool { return exists(inHome(".tmux/plugins/tpm")) }

func installTPM() error {
	return run("git", "clone", "--depth", "1",
		"https://github.com/tmux-plugins/tpm", inHome(".tmux/plugins/tpm"))
}

func fisherInstalled() bool {
	out, err := capture("fish", "-c", "fisher list")
	return err == nil && out != ""
}

func installFisher() error {
	// fisher.fish ships in the repo, so the function exists once configs are
	// applied; `fisher update` then installs everything in fish_plugins.
	return run("fish", "-c", "fisher update")
}

func lazySynced() bool { return exists(inHome(".local/share/nvim/lazy/lazy.nvim")) }

func syncLazy() error {
	return run("nvim", "--headless", "+Lazy! sync", "+qa")
}

func doomInstalled() bool { return exists(inHome(".config/emacs/bin/doom")) }

func installDoom() error {
	if !exists(inHome(".config/emacs")) {
		err := run("git", "clone", "--depth", "1",
			"https://github.com/doomemacs/doomemacs", inHome(".config/emacs"))
		if err != nil {
			return err
		}
	}
	return run(inHome(".config/emacs/bin/doom"), "install", "--no-config", "--force")
}

// themeRendered checks for kitty's generated include, which is the file whose
// absence makes kitty error on startup.
func themeRendered() bool { return exists(inHome(".config/kitty/theme.conf")) }

func applyTheme() error {
	return run("python3", inHome(".config/theme/theme.py"), "apply", "--quiet")
}

func wallpapersLinked() bool {
	entries, err := os.ReadDir(inHome(".config/hypr/wallpapers"))
	return err == nil && len(entries) > 0
}

func linkWallpapers() error {
	dst := inHome("wallpapers")
	if !exists(dst) {
		if err := run("git", "clone", wallpapersRepo, dst); err != nil {
			return err
		}
	}
	link := inHome(".config/hypr/wallpapers")
	if exists(link) {
		os.Remove(link)
	}
	if err := os.MkdirAll(filepath.Dir(link), 0o755); err != nil {
		return err
	}
	return os.Symlink(dst, link)
}

// -- system checks -----------------------------------------------------------

// Check is a non-fatal system-level condition worth reporting rather than
// silently failing on later.
type Check struct {
	Name string
	OK   bool
	Fix  string
}

// palette is the part of a theme JSON that names external assets.
type palette struct {
	Name   string `json:"name"`
	Colors struct {
		Accent string `json:"accent"`
	} `json:"colors"`
	GTK struct {
		Theme string `json:"theme"`
		Icons string `json:"icons"`
		GTK4  string `json:"gtk4"`
	} `json:"gtk"`
}

// variant is the suffix recolor.py builds against: the palette's GTK theme
// "Material-Black-Evergreen" and icon set "MB-Evergreen-Suru-GLOW" share the
// stem "Evergreen".
func (p palette) variant() string {
	return strings.TrimPrefix(p.GTK.Theme, "Material-Black-")
}

func (p palette) built() bool {
	return exists(inHome(".themes/"+p.GTK.Theme)) &&
		exists(inHome(".local/share/icons/"+p.GTK.Icons))
}

const (
	// The Material-Black GTK themes and their matching Suru-GLOW icon sets
	// both live on this one branch, so a single sparse clone gets a complete
	// base pair. Blueberry is an arbitrary pick — recolor.py reads the accent
	// back off whatever base it is given.
	mbRepo   = "https://github.com/rtlewis88/rtl88-Themes"
	mbBranch = "material-black-COLORS"
	mbTheme  = "Material-Black-Blueberry-3.36"
	mbIcons  = "MB-Blueberry-Suru-GLOW"

	colloidRepo = "https://github.com/vinceliuice/Colloid-gtk-theme"
)

// palettes reads every theme definition, ignoring any that will not parse.
func palettes() []palette {
	dir := inHome(".config/theme/themes")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var out []palette
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			continue
		}
		var p palette
		if json.Unmarshal(raw, &p) == nil {
			out = append(out, p)
		}
	}
	return out
}

// themeBaseInstalled reports whether any Material-Black + Suru-GLOW pair is
// present. recolor.py can derive from any of them, including one of its own
// earlier outputs, so the upstream base does not have to be the one on disk.
func themeBaseInstalled() bool { return installedBase() != "" }

// installThemeBase sparse-clones just the one colour pair (~150M) rather than
// the whole ~850M repo, and drops the version suffix upstream uses so the
// directory name is the "Material-Black-<base>" that recolor.py looks for.
func installThemeBase() error {
	tmp, err := os.MkdirTemp("", "mbtheme")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)

	if err := run("git", "clone", "--depth", "1", "--single-branch",
		"--branch", mbBranch, "--filter=blob:none", "--sparse", mbRepo, tmp); err != nil {
		return err
	}
	if err := run("git", "-C", tmp, "sparse-checkout", "set", mbTheme, mbIcons); err != nil {
		return err
	}

	for _, d := range []string{inHome(".themes"), inHome(".local/share/icons")} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return err
		}
	}
	base := strings.TrimSuffix(mbTheme, "-3.36")
	if err := run("cp", "-a", filepath.Join(tmp, mbTheme), inHome(".themes/"+base)); err != nil {
		return err
	}
	return run("cp", "-a", filepath.Join(tmp, mbIcons), inHome(".local/share/icons/"))
}

// colloidVariants returns the gtk4 theme names the palettes ask for that are
// not installed yet.
func colloidVariants() []string {
	seen := map[string]bool{}
	var want []string
	for _, p := range palettes() {
		n := p.GTK.GTK4
		if n == "" || seen[n] || exists(inHome(".themes/"+n)) {
			continue
		}
		seen[n] = true
		want = append(want, n)
	}
	return want
}

func colloidInstalled() bool { return len(colloidVariants()) == 0 }

// installColloid maps a theme directory name back to install.sh flags:
// Colloid-Green-Dark-Everforest -> -t green -c dark --tweaks everforest.
func installColloid() error {
	variants := colloidVariants()
	if len(variants) == 0 {
		return nil
	}

	tmp, err := os.MkdirTemp("", "colloid")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)

	if err := run("git", "clone", "--depth", "1", colloidRepo, tmp); err != nil {
		return err
	}
	if err := os.MkdirAll(inHome(".themes"), 0o755); err != nil {
		return err
	}

	for _, v := range variants {
		parts := strings.Split(v, "-")
		if len(parts) < 3 || parts[0] != "Colloid" {
			fmt.Printf("    skipping %s: cannot derive install flags from the name\n", v)
			continue
		}
		args := []string{
			filepath.Join(tmp, "install.sh"),
			"-d", inHome(".themes"),
			"-t", strings.ToLower(parts[1]),
			"-c", strings.ToLower(parts[2]),
		}
		if len(parts) > 3 {
			args = append(args, "--tweaks", strings.ToLower(parts[3]))
		}
		if err := run("bash", args...); err != nil {
			return fmt.Errorf("installing %s: %w", v, err)
		}
	}
	return nil
}

func paletteThemesBuilt() bool {
	for _, p := range palettes() {
		if p.GTK.Theme != "" && !p.built() {
			return false
		}
	}
	return true
}

// buildPaletteThemes derives each palette's GTK theme and icon set from an
// installed base, in the palette's own accent colour. This is what turns the
// one upstream pair into the per-theme assets the switcher expects.
func buildPaletteThemes() error {
	base := installedBase()
	if base == "" {
		return errors.New("no Material-Black + Suru-GLOW pair to derive from")
	}
	for _, p := range palettes() {
		if p.GTK.Theme == "" || p.built() {
			continue
		}
		if p.Colors.Accent == "" {
			fmt.Printf("    skipping %s: no accent colour in the palette\n", p.Name)
			continue
		}
		fmt.Printf("    %s (%s from %s)\n", p.variant(), p.Colors.Accent, base)
		if err := run("python3", inHome(".config/theme/recolor.py"),
			base, p.Colors.Accent, p.variant()); err != nil {
			return fmt.Errorf("recolouring %s: %w", p.variant(), err)
		}
	}
	return nil
}

// installedBase returns the stem of any Material-Black + Suru-GLOW pair on
// disk, which recolor.py can use as a source.
func installedBase() string {
	entries, err := os.ReadDir(inHome(".themes"))
	if err != nil {
		return ""
	}
	for _, e := range entries {
		name := strings.TrimPrefix(e.Name(), "Material-Black-")
		if name == e.Name() {
			continue
		}
		if exists(inHome(".themes/"+e.Name()+"/gtk-3.0/gtk.css")) &&
			exists(inHome(".local/share/icons/MB-"+name+"-Suru-GLOW/places/scalable/folder.svg")) {
			return name
		}
	}
	return ""
}

// themeAssetChecks verifies the GTK and icon themes the palettes point at.
// These are the one part of the setup nothing reproduces: recolor.py derives
// Material-Black-<name> and MB-<name>-Suru-GLOW from an existing pair, the
// Colloid gtk4 themes are installed by hand, and none of it is packaged or in
// the repo. Missing assets do not error — you just get an unstyled desktop —
// so they are worth reporting explicitly.
func themeAssetChecks() []Check {
	dir := inHome(".config/theme/themes")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}

	var checks []Check
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			continue
		}
		var p palette
		if json.Unmarshal(raw, &p) != nil {
			continue
		}

		var gone []string
		for _, a := range []struct{ path, name string }{
			{inHome(".themes/" + p.GTK.Theme), p.GTK.Theme},
			{inHome(".themes/" + p.GTK.GTK4), p.GTK.GTK4},
			{inHome(".local/share/icons/" + p.GTK.Icons), p.GTK.Icons},
		} {
			if a.name != "" && !exists(a.path) {
				gone = append(gone, a.name)
			}
		}

		name := strings.TrimSuffix(e.Name(), ".json")
		checks = append(checks, Check{
			Name: "theme assets for " + name,
			OK:   len(gone) == 0,
			Fix: fmt.Sprintf("missing: %s — re-run setup with the Theme switcher "+
				"component selected; it clones the upstream base and rebuilds these",
				strings.Join(gone, ", ")),
		})
	}
	return checks
}

func systemChecks(selected map[string]bool) []Check {
	var checks []Check

	if selected["theme"] {
		checks = append(checks, themeAssetChecks()...)
	}

	if selected["ddc"] {
		loaded := exec.Command("sh", "-c", "lsmod | grep -q '^i2c_dev'").Run() == nil
		checks = append(checks, Check{
			Name: "i2c-dev module loaded (ddcutil)",
			OK:   loaded,
			Fix:  "echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf && sudo modprobe i2c-dev",
		})
		groups, _ := capture("id", "-nG")
		checks = append(checks, Check{
			Name: "user in i2c group (ddcutil without sudo)",
			OK:   strings.Contains(" "+groups+" ", " i2c "),
			Fix:  "sudo usermod -aG i2c $USER   # then log out and back in",
		})
	}

	if selected["core"] {
		shell := os.Getenv("SHELL")
		checks = append(checks, Check{
			Name: "login shell is fish",
			OK:   strings.HasSuffix(shell, "/fish"),
			Fix:  "chsh -s /usr/bin/fish",
		})
	}

	checks = append(checks, Check{
		Name: "~/.local/bin on PATH",
		OK:   strings.Contains(os.Getenv("PATH"), inHome(".local/bin")),
		Fix:  "add ~/.local/bin to fish_user_paths",
	})

	return checks
}
