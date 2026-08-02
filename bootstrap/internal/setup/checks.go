package setup

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/jrdriscoll17/dotfiles/bootstrap/internal/sys"
)

// Non-fatal system conditions worth reporting rather than silently failing on
// later.

// Check is a non-fatal system-level condition worth reporting rather than
// silently failing on later.
type Check struct {
	Name string
	OK   bool
	Fix  string
}

// themeAssetChecks verifies the GTK and icon themes the palettes point at.
// These are the one part of the setup nothing reproduces: the recolour derives
// Material-Black-<name> and MB-<name>-Suru-GLOW from an existing pair, the
// Colloid gtk4 themes are installed by hand, and none of it is packaged or in
// the repo. Missing assets do not error — you just get an unstyled desktop —
// so they are worth reporting explicitly.
func themeAssetChecks() []Check {
	var checks []Check
	for _, p := range palettes() {
		var gone []string
		for _, a := range []struct{ path, name string }{
			{sys.InHome(".themes/" + p.GTK.Theme), p.GTK.Theme},
			{sys.InHome(".themes/" + p.GTK.GTK4), p.GTK.GTK4},
			{sys.InHome(".local/share/icons/" + p.GTK.Icons), p.GTK.Icons},
		} {
			if a.name != "" && !sys.Exists(a.path) {
				gone = append(gone, a.name)
			}
		}

		checks = append(checks, Check{
			Name: "theme assets for " + p.Name,
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
		groups, _ := sys.Capture("id", "-nG")
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
		OK:   strings.Contains(os.Getenv("PATH"), sys.InHome(".local/bin")),
		Fix:  "add ~/.local/bin to fish_user_paths",
	})

	return checks
}
