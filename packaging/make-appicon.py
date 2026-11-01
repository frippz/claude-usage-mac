#!/usr/bin/env python3
"""Render the macOS AppIcon set.

The mark is a meter: a frosted squircle around a dark dial, a 270-degree arc
split at the app's own thresholds (green to 60%, amber to 80%, red to the
limit) and one needle. What lies past the needle is the headroom. The colours
are Level's tints in SharedViews/Theme.swift.

The SVG is built here and rasterised with rsvg-convert (`brew install
librsvg`), which draws the gradients and shadows Pillow can't. Output is
committed, so CI needs neither. Rerun this only when the mark changes:

    python3 packaging/make-appicon.py
"""
import json
import math
import os
import subprocess

OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Sources", "MenuBarApp", "Assets.xcassets", "AppIcon.appiconset",
)

OK, WARN, CRITICAL = "#22c55e", "#f59e0b", "#ef4444"

C = 512          # canvas centre; the canvas is 1024
R = 250          # arc radius
STROKE = 64
START, SWEEP = -135, 270    # degrees clockwise from 12 o'clock
NEEDLE = 0.45               # where the needle points, as a fraction of the sweep
GAP = 9.6                   # half gap between segments, room for both round caps

# macOS icon grid: artwork fills 824 of a 1024 canvas, with a 22.5% corner
# radius. Without the margin the icon sits visibly larger than every native one
# beside it in Finder.
CONTENT, CORNER = 824, 185


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


def svg(ticks=True):
    origin = (1024 - CONTENT) / 2
    segments = [
        (OK, _arc(_at(0), _at(0.6) - GAP)),
        (WARN, _arc(_at(0.6) + GAP, _at(0.8) - GAP)),
        (CRITICAL, _arc(_at(0.8) + GAP, _at(1))),
    ]
    arcs = "\n".join(
        f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{STROKE}" stroke-linecap="round"/>'
        for c, d in segments
    )
    tick_path = (
        f'<path d="{_ticks()}" fill="none" stroke="#fff" stroke-opacity="0.28" '
        f'stroke-width="10" stroke-linecap="round"/>' if ticks else ""
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
<defs>
  <linearGradient id="base" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#f7f9fc"/><stop offset="1" stop-color="#cfd7e2"/>
  </linearGradient>
  <linearGradient id="edge" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.9"/>
    <stop offset="0.45" stop-color="#fff" stop-opacity="0"/>
    <stop offset="1" stop-color="#fff" stop-opacity="0.35"/>
  </linearGradient>
  <radialGradient id="dial" cx="0.5" cy="0.32" r="0.75">
    <stop offset="0" stop-color="#273141"/><stop offset="1" stop-color="#0b0f15"/>
  </radialGradient>
  <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.95"/>
    <stop offset="1" stop-color="#fff" stop-opacity="0.2"/>
  </linearGradient>
  <linearGradient id="spec" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.22"/>
    <stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </linearGradient>
  <radialGradient id="hub" cx="0.4" cy="0.3" r="0.8">
    <stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#b8c1cc"/>
  </radialGradient>
  <clipPath id="clip"><circle cx="{C}" cy="{C}" r="318"/></clipPath>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="150%">
    <feDropShadow dx="0" dy="16" stdDeviation="22" flood-color="#000" flood-opacity="0.28"/>
  </filter>
  <filter id="needleShadow" x="-50%" y="-50%" width="200%" height="200%">
    <feDropShadow dx="0" dy="8" stdDeviation="10" flood-color="#000" flood-opacity="0.45"/>
  </filter>
</defs>
<rect x="{origin}" y="{origin}" width="{CONTENT}" height="{CONTENT}" rx="{CORNER}" fill="url(#base)" filter="url(#shadow)"/>
<rect x="{origin + 3}" y="{origin + 3}" width="{CONTENT - 6}" height="{CONTENT - 6}" rx="{CORNER - 3}" fill="none" stroke="url(#edge)" stroke-width="6"/>
<circle cx="{C}" cy="{C}" r="318" fill="url(#dial)"/>
<circle cx="{C}" cy="{C}" r="322" fill="none" stroke="url(#rim)" stroke-width="10"/>
<path d="{_arc(_at(0), _at(1))}" fill="none" stroke="#fff" stroke-opacity="0.08" stroke-width="{STROKE}" stroke-linecap="round"/>
{tick_path}
{arcs}
<ellipse cx="{C}" cy="318" rx="300" ry="190" fill="url(#spec)" clip-path="url(#clip)"/>
<g filter="url(#needleShadow)">
  <path d="M 507 236 Q 512 226 517 236 L 532 512 L 492 512 Z" fill="#fff" transform="rotate({_at(NEEDLE):.1f} {C} {C})"/>
  <circle cx="{C}" cy="{C}" r="52" fill="url(#hub)"/>
</g>
<circle cx="{C}" cy="{C}" r="16" fill="#0f1216" fill-opacity="0.8"/>
</svg>
"""


def render(pixels, path):
    # The ticks are mush at 32 px and below; the dial reads without them.
    subprocess.run(
        ["rsvg-convert", "-w", str(pixels), "-h", str(pixels), "-o", path],
        input=svg(ticks=pixels > 32).encode(), check=True,
    )


# (logical size, scale). macOS wants every one of these.
VARIANTS = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
            (256, 1), (256, 2), (512, 1), (512, 2)]


def main():
    os.makedirs(OUT, exist_ok=True)
    images = []

    for logical, scale in VARIANTS:
        pixels = logical * scale
        name = f"icon_{logical}x{logical}{'@2x' if scale == 2 else ''}.png"
        render(pixels, os.path.join(OUT, name))
        images.append({
            "size": f"{logical}x{logical}",
            "idiom": "mac",
            "filename": name,
            "scale": f"{scale}x",
        })
        print(f"  {name}  ({pixels}px)")

    with open(os.path.join(OUT, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({"images": images, "info": {"version": 1, "author": "xcode"}},
                  f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    print("Rendering AppIcon ->", OUT)
    main()
    print("done.")
