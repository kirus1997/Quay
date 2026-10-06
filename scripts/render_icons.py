#!/usr/bin/env python3
"""Draw Quay's original app icon and menu-bar mark."""

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "App" / "Assets.xcassets" / "AppIcon.appiconset"
MENU_DIR = ROOT / "App" / "Assets.xcassets" / "MenuBarMark.imageset"


def write_png(path: Path, width: int, height: int, pixels):
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def cover_round_rect(px, py, x, y, w, h, r):
    dx = px - (x + w / 2)
    dy = py - (y + h / 2)
    ax = abs(dx) - (w / 2 - r)
    ay = abs(dy) - (h / 2 - r)
    outside = math.hypot(max(ax, 0), max(ay, 0)) + min(max(ax, ay), 0) - r
    return max(0.0, min(1.0, 0.5 - outside))


def app_pixel(x, y, size):
    s = size
    px = x + 0.5
    py = y + 0.5
    t = py / s
    top = (18, 78, 74, 255)
    bottom = (10, 42, 40, 255)
    base = mix(top, bottom, t)
    deck = cover_round_rect(px, py, s * 0.10, s * 0.54, s * 0.80, s * 0.13, s * 0.045)
    cabin = cover_round_rect(px, py, s * 0.20, s * 0.28, s * 0.30, s * 0.28, s * 0.05)
    piling_a = cover_round_rect(px, py, s * 0.20, s * 0.64, s * 0.09, s * 0.20, s * 0.03)
    piling_b = cover_round_rect(px, py, s * 0.68, s * 0.64, s * 0.09, s * 0.20, s * 0.03)
    cream = (244, 239, 228, 255)
    brass = (215, 164, 65, 255)
    color = base
    color = mix(color, brass, piling_a)
    color = mix(color, brass, piling_b)
    color = mix(color, cream, deck)
    color = mix(color, cream, cabin * 0.95)
    # A small window on the cabin.
    window = cover_round_rect(px, py, s * 0.275, s * 0.35, s * 0.15, s * 0.10, s * 0.025)
    color = mix(color, (22, 92, 88, 255), window)
    return color


def menu_pixel(x, y, size):
    s = size
    px = x + 0.5
    py = y + 0.5
    deck = cover_round_rect(px, py, s * 0.08, s * 0.62, s * 0.84, s * 0.14, s * 0.06)
    post = cover_round_rect(px, py, s * 0.22, s * 0.30, s * 0.14, s * 0.36, s * 0.05)
    alpha = max(deck, post)
    return (0, 0, 0, int(255 * alpha))


def render_icon(size):
    pixels = []
    for y in range(size):
        for x in range(size):
            pixels.extend(app_pixel(x, y, size))
    return pixels


def render_menu(size):
    pixels = []
    for y in range(size):
        for x in range(size):
            pixels.extend(menu_pixel(x, y, size))
    return pixels


def main():
    for size, name in (
        (16, "icon_16.png"),
        (32, "icon_32.png"),
        (64, "icon_64.png"),
        (128, "icon_128.png"),
        (256, "icon_256.png"),
        (512, "icon_512.png"),
        (1024, "icon_1024.png"),
    ):
        write_png(ICON_DIR / name, size, size, render_icon(size))
    write_png(MENU_DIR / "menubar.png", 18, 18, render_menu(18))
    write_png(MENU_DIR / "menubar@2x.png", 36, 36, render_menu(36))


if __name__ == "__main__":
    main()
