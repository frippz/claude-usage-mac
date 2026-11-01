#!/usr/bin/env python3
"""Write the layer artwork of the Icon Composer app icon.

The mark is a meter: a dark dial, a 270-degree arc split at the app's default
thresholds (green to 50%, amber to 80%, red to the limit) and one needle. What
lies past the needle is the headroom. The colours are Level's tints in
SharedViews/Theme.swift.

This writes one SVG per layer into AppIcon.icon/Assets. The squircle, glass,
shadows, dark and clear appearances, and the flattened icon for macOS before
26 come from Icon Composer and Xcode, set in AppIcon.icon/icon.json, which
Icon Composer edits and this script leaves alone. Rerun this only when the
mark changes:

    python3 packaging/make-appicon.py
"""
import math
import os

OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Sources", "MenuBarApp", "AppIcon.icon", "Assets",
)

OK, WARN, CRITICAL = "#22c55e", "#f59e0b", "#ef4444"
# Level.of's defaults. The icon can't follow a user's own thresholds.
WARN_AT, CRITICAL_AT = 0.5, 0.8

C = 512          # dial centre on the 1024 drawing grid
DIAL = 318       # dial radius
R = 250          # arc radius
STROKE = 64
START, SWEEP = -135, 270    # degrees clockwise from 12 o'clock
NEEDLE = 0.45               # where the needle points, as a fraction of the sweep
GAP = 9.6                   # half gap between segments, room for both round caps

# The mark was drawn for a squircle 824 wide on a 1024 grid, the macOS icon
# margin. Icon Composer's canvas is the squircle itself, so each layer's
# viewBox crops to it and keeps the dial's proportion to the squircle.
SQUIRCLE = 824


def _at(fraction):
    return START + SWEEP * fraction


def _pt(deg, r):
    a = math.radians(deg)
    return C + r * math.sin(a), C - r * math.cos(a)


def _arc(d0, d1):
    (x0, y0), (x1, y1) = _pt(d0, R), _pt(d1, R)
    large = 1 if d1 - d0 > 180 else 0
    return f"M {x0:.1f} {y0:.1f} A {R} {R} 0 {large} 1 {x1:.1f} {y1:.1f}"


def _ticks():
    path = []
    for i in range(11):
        d = _at(i / 10)
        (ax, ay), (bx, by) = _pt(d, 196), _pt(d, 164 if i % 5 == 0 else 178)
        path.append(f"M {ax:.1f} {ay:.1f} L {bx:.1f} {by:.1f}")
    return " ".join(path)


def _stroke(d, colour, width, opacity=1):
    return (f'<path d="{d}" fill="none" stroke="{colour}" stroke-opacity="{opacity}" '
            f'stroke-width="{width}" stroke-linecap="round"/>')


def _svg(body, defs=""):
    o = (1024 - SQUIRCLE) / 2
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
            f'viewBox="{o:g} {o:g} {SQUIRCLE} {SQUIRCLE}">\n'
            f'<defs>{defs}</defs>\n{body}\n</svg>\n')


def layers():
    return {
        "dial.svg": _svg(
            f'<circle cx="{C}" cy="{C}" r="{DIAL}" fill="url(#dial)"/>',
            '<radialGradient id="dial" cx="0.5" cy="0.32" r="0.75">'
            '<stop offset="0" stop-color="#273141"/><stop offset="1" stop-color="#0b0f15"/>'
            '</radialGradient>'),
        "track.svg": _svg(
            _stroke(_arc(_at(0), _at(1)), "#fff", STROKE, 0.08)
            + _stroke(_ticks(), "#fff", 10, 0.28)),
        "ok.svg": _svg(_stroke(_arc(_at(0), _at(WARN_AT) - GAP), OK, STROKE)),
        "warn.svg": _svg(_stroke(_arc(_at(WARN_AT) + GAP, _at(CRITICAL_AT) - GAP), WARN, STROKE)),
        "critical.svg": _svg(_stroke(_arc(_at(CRITICAL_AT) + GAP, _at(1)), CRITICAL, STROKE)),
        "needle.svg": _svg(
            f'<path d="M 507 236 Q 512 226 517 236 L 532 512 L 492 512 Z" fill="#fff" '
            f'transform="rotate({_at(NEEDLE):.1f} {C} {C})"/>'),
        "hub.svg": _svg(
            f'<circle cx="{C}" cy="{C}" r="52" fill="url(#hub)"/>'
            f'<circle cx="{C}" cy="{C}" r="16" fill="#0f1216" fill-opacity="0.8"/>',
            '<radialGradient id="hub" cx="0.4" cy="0.3" r="0.8">'
            '<stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#b8c1cc"/>'
            '</radialGradient>'),
    }


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, svg in layers().items():
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            f.write(svg)
        print(f"  {name}")


if __name__ == "__main__":
    print("Writing AppIcon layers ->", OUT)
    main()
    print("done.")
