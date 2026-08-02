#!/usr/bin/env bash
# Deploy config packages with GNU stow.
#
#   ./install.sh core      -> portable packages only (any host)
#   ./install.sh desktop   -> everything, for the Hyprland box
#   ./install.sh nvim tmux -> named packages
#
# --no-folding is required: see README ("Why --no-folding").

set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

CORE=(fish tmux nvim doom git)
DESKTOP=("${CORE[@]}" hypr quickshell theme kitty alacritty btop gtk qt xdg)

case "${1:-}" in
    core)    packages=("${CORE[@]}") ;;
    desktop) packages=("${DESKTOP[@]}") ;;
    "")      echo "usage: $0 {core|desktop|<package>...}" >&2; exit 1 ;;
    *)       packages=("$@") ;;
esac

command -v stow >/dev/null || { echo "stow is not installed" >&2; exit 1; }

for pkg in "${packages[@]}"; do
    [ -d "$pkg" ] || { echo "skip: $pkg (no such package)" >&2; continue; }
    if stow --no-folding -t "$HOME" "$pkg"; then
        echo "stowed: $pkg"
    else
        echo "FAILED: $pkg" >&2
    fi
done
