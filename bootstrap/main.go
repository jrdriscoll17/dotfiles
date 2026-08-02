// Command setup installs and maintains this machine: it picks the components
// you want, installs their packages, hands the config files to chezmoi, and
// runs the bootstrap that nothing else tracks (tpm, fisher, lazy, Doom, the
// theme assets).
//
// It is a multi-call binary. Installed as ~/.local/bin/setup with a `theme`
// symlink beside it, the same executable is also the theme switcher, so the
// installer, the switcher and the theme-asset builder ship as one artefact.
//
//	setup                 interactive installer
//	setup -plan           report what would happen, change nothing
//	setup recolor …       build a Material-Black + Suru-GLOW pair
//	theme … (or setup theme …)   the theme switcher
//
// It is deliberately re-runnable: everything is checked first, so a second run
// installs only what is missing and asks only about files that actually differ.
package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/charmbracelet/huh"

	"github.com/jrdriscoll17/dotfiles/bootstrap/internal/recolor"
	"github.com/jrdriscoll17/dotfiles/bootstrap/internal/setup"
	"github.com/jrdriscoll17/dotfiles/bootstrap/internal/theme"
)

func main() {
	// Dispatch on argv[0] first: invoked through the `theme` symlink this is
	// the switcher, not the installer.
	if filepath.Base(os.Args[0]) == "theme" {
		exit("theme", theme.Main(os.Args[1:]))
	}

	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "theme":
			exit("theme", theme.Main(os.Args[2:]))
		case "recolor":
			if len(os.Args) != 5 {
				fmt.Fprintln(os.Stderr, "usage: setup recolor <base-variant> <#hex> <name>")
				os.Exit(2)
			}
			exit("recolor", recolor.Run(os.Args[2], os.Args[3], os.Args[4]))
		}
	}

	if err := setup.Run(); err != nil {
		// A cancelled prompt is a normal way to leave the TUI, not a failure.
		if errors.Is(err, huh.ErrUserAborted) {
			fmt.Println("\naborted — nothing was changed")
			os.Exit(0)
		}
		fmt.Fprintln(os.Stderr, "setup: "+err.Error())
		os.Exit(1)
	}
}

// exit ends the process after a subcommand, reporting failures the way that
// command's users expect.
func exit(name string, err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: %v\n", name, err)
		os.Exit(1)
	}
	os.Exit(0)
}
