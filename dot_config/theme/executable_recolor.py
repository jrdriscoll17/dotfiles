#!/usr/bin/env python3
"""Build a Material-Black + Suru-GLOW pair in an arbitrary accent colour.

    theme recolor <base-variant> <#hex> <name>
    theme recolor Pistachio '#7fd8e8' IceBlue

Produces ~/.themes/Material-Black-<name> and
~/.local/share/icons/MB-<name>-Suru-GLOW, leaving the upstream variants alone.

Both halves are coloured mechanically rather than drawn:

  * the GTK theme states its accent as a single hex (81 times in gtk.css, plus a
    handful of SVG assets and 35 GTK2 PNGs — checkboxes, radios, switches),
  * every icon is tinted by one two-stop linear gradient, light to dark. That
    pair is what differs between Blueberry, Lime, Pistachio and the rest, so
    swapping it recolours all ~25k icons at once.

The PNGs are recoloured by mapping each accent-ish pixel through the same
lightness ramp, which keeps the anti-aliased edges intact.
"""

from __future__ import annotations

import colorsys
import re
import shutil
import sys
from pathlib import Path

HOME = Path.home()
THEMES = HOME / ".themes"
ICONS = HOME / ".local/share/icons"

# Nothing is hardcoded about the upstream variants: a base's accent and gradient
# stops are read back off the installed theme, so a recoloured build can itself
# be the base for the next one and the originals don't have to stay on disk.
def read_base(base: str) -> dict[str, str]:
    gtk = THEMES / f"Material-Black-{base}" / "gtk-3.0" / "gtk.css"
    icon = ICONS / f"MB-{base}-Suru-GLOW" / "places" / "scalable" / "folder.svg"
    if not gtk.exists() or not icon.exists():
        raise SystemExit(f"recolor: {base} is not installed (need both the GTK theme and the icon set)")

    # The accent is simply the most-repeated colour in the sheet — 81 uses,
    # against ~50 for the next one.
    counts: dict[str, int] = {}
    for hex_ in re.findall(r"#[0-9a-fA-F]{6}", gtk.read_text(errors="ignore")):
        counts[hex_.lower()] = counts.get(hex_.lower(), 0) + 1
    accent = max(counts, key=counts.get)

    # Every icon carries two dozen gradients, all identical across variants
    # except the one the artwork actually fills with. These sets were generated
    # with oomox, which names that one — so read its two stops rather than
    # guessing by position.
    svg = icon.read_text(errors="ignore")
    fill = re.search(r'fill="url\(#([^)]+)\)"', svg)
    gradient_id = fill.group(1) if fill else "oomox"
    block = re.search(
        rf'<linearGradient[^>]*id="{re.escape(gradient_id)}"[^>]*>(.*?)</linearGradient>',
        svg, re.S)
    stops = re.findall(r"stop-color:\s*(#[0-9a-fA-F]{6})", block.group(1)) if block else []
    if len(stops) < 2:
        raise SystemExit(f"recolor: could not read the '{gradient_id}' gradient out of {icon}")

    return {"accent": accent, "light": stops[0].lower(), "dark": stops[1].lower()}


def parse_hex(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    if len(value) != 6:
        raise SystemExit(f"recolor: not a colour: #{value}")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def to_hex(rgb: tuple[float, float, float]) -> str:
    return "#{:02x}{:02x}{:02x}".format(*(max(0, min(255, round(c))) for c in rgb))


def scaled(rgb: tuple[int, int, int], factor: float) -> str:
    """A darker (or lighter) shade of the same hue, matching how upstream picks
    its second gradient stop — roughly half the lightness of the first."""
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
    r, g, b = colorsys.hls_to_rgb(h, max(0.0, min(1.0, l * factor)), s)
    return to_hex((r * 255, g * 255, b * 255))


def recolour_text(text: str, mapping: dict[str, str]) -> tuple[str, bool]:
    """Case-insensitive hex substitution; upstream mixes #00E5CE and #00e5ce."""
    changed = False
    for old, new in mapping.items():
        pattern = re.compile(re.escape(old), re.IGNORECASE)
        text, n = pattern.subn(new, text)
        changed = changed or bool(n)
    return text, changed


def recolour_png(path: Path, source: tuple[int, int, int], target: tuple[int, int, int]) -> None:
    """Re-tint accent-coloured pixels, keeping their relative lightness so
    anti-aliased edges and the pressed/hover shades survive."""
    try:
        from PIL import Image
    except ImportError:
        return

    src_h, src_l, src_s = colorsys.rgb_to_hls(*(c / 255 for c in source))
    tgt_h, tgt_l, tgt_s = colorsys.rgb_to_hls(*(c / 255 for c in target))

    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    touched = False

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if s < 0.15:
                continue  # greys are chrome, not accent
            # Same hue family as the source accent (hue wraps at 1.0).
            delta = min(abs(h - src_h), 1 - abs(h - src_h))
            if delta > 0.08:
                continue
            nr, ng, nb = colorsys.hls_to_rgb(tgt_h, l * (tgt_l / src_l if src_l else 1), tgt_s)
            pixels[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
            touched = True

    if touched:
        image.save(path)


def build_gtk(base: str, name: str, accent: tuple[int, int, int]) -> Path:
    src = THEMES / f"Material-Black-{base}"
    if not src.is_dir():
        raise SystemExit(f"recolor: {src} is not installed")

    dest = THEMES / f"Material-Black-{name}"
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(src, dest, symlinks=True)

    old_accent = read_base(base)["accent"]
    mapping = {
        old_accent: to_hex(accent),
        # Hover/pressed states are drawn a step darker.
        scaled(parse_hex(old_accent), 0.8): scaled(accent, 0.8),
    }

    for path in dest.rglob("*"):
        if path.suffix.lower() in (".css", ".svg", ".rc", ".xml", ".themerc", ".theme"):
            text = path.read_text(errors="ignore")
            text, changed = recolour_text(text, mapping)
            if changed:
                path.write_text(text)

    for path in dest.rglob("*.png"):
        recolour_png(path, parse_hex(old_accent), accent)

    # index.theme names the theme to GTK; it has to match the directory.
    index = dest / "index.theme"
    if index.exists():
        text = index.read_text(errors="ignore")
        text = text.replace(f"Material-Black-{base}", f"Material-Black-{name}")
        index.write_text(text)

    return dest


def build_icons(base: str, name: str, accent: tuple[int, int, int]) -> tuple[Path, int]:
    src = ICONS / f"MB-{base}-Suru-GLOW"
    if not src.is_dir():
        raise SystemExit(f"recolor: {src} is not installed")

    dest = ICONS / f"MB-{name}-Suru-GLOW"
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(src, dest, symlinks=True)

    stops = read_base(base)
    mapping = {
        stops["light"]: to_hex(accent),
        stops["dark"]: scaled(accent, 0.5),
    }

    count = 0
    for path in dest.rglob("*.svg"):
        if path.is_symlink():
            continue
        text = path.read_text(errors="ignore")
        text, changed = recolour_text(text, mapping)
        if changed:
            path.write_text(text)
            count += 1

    index = dest / "index.theme"
    if index.exists():
        text = index.read_text(errors="ignore")
        text = re.sub(r"^Name=.*$", f"Name=MB-{name}-Suru-GLOW", text, count=1, flags=re.MULTILINE)
        if not re.search(r"^Inherits=", text, re.MULTILINE):
            text = re.sub(r"^(Comment=.*)$", r"\1\nInherits=Papirus-Dark,Papirus,hicolor",
                          text, count=1, flags=re.MULTILINE)
        index.write_text(text)

    return dest, count


def main(argv: list[str]) -> None:
    if len(argv) != 3:
        raise SystemExit(__doc__)

    base, colour, name = argv
    # Any installed Material-Black + Suru-GLOW pair can serve as the base.

    accent = parse_hex(colour)
    print(f"recolour {base} -> {to_hex(accent)} as {name}")

    gtk = build_gtk(base, name, accent)
    print(f"  {gtk}")
    icons, count = build_icons(base, name, accent)
    print(f"  {icons} ({count} icons)")
    print(f'\nPoint a theme at it:\n  "theme": "Material-Black-{name}",\n  "icons": "MB-{name}-Suru-GLOW"')


if __name__ == "__main__":
    main(sys.argv[1:])
