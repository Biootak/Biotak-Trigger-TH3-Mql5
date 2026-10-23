#!/usr/bin/env python3
"""make-disc-skins.py - rebuild the circular skins so a disc reads as a DISC.

WHY (P-UI-221, 2026-10-23)
--------------------------
BiotakMenu.mqh documents the law this art has to obey:

    CIRC_BG_SIZE 52   // circular glass skin: 44px diameter + 4px glow margin

The shipped art broke that law's SPIRIT: the 44px disc is right, but the glow
baked into its 4px margin was a BOX blur - it filled the canvas corners, so the
silhouette of the halo was the bitmap RECTANGLE, not the disc. On a chart that
reads as a light square plate behind every seat, which is exactly the «دایره
نیست» report: the seat is a circle, the thing behind it is a square.

This tool keeps the disc pixel-for-pixel - the face, the rim highlight, the
border, the on/off colours are NOT resampled - and redraws only the margin as a
true RADIAL glow that reaches alpha 0 before the bitmap ends. Same canvas, same
diameter, so no layout number, hit rect or icon offset moves.

cell_*.bmp is the grid tile: a rounded square by design, which next to a rail of
discs is a second visual language (and the user's «مربع نباشه»). It is rebuilt
from the circular face at the same canvas, so the panel cells are discs too.

    python tools/icons/make-disc-skins.py                     # rewrite Files/Icons
    python tools/icons/make-disc-skins.py --dry               # report only
    python tools/icons/make-disc-skins.py --install <dir>     # + refresh the terminal

The terminal embeds these at COMPILE time (#resource), so a build is required
after a run.
"""

import argparse
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ICONS = os.path.join(ROOT, "Files", "Icons")

# name -> (margin, face source). The cell skins keep their canvas (46) so the
# grid's pitch, hit rect and icon offset are untouched, but their FACE is the
# circular glass: one visual language for every seat.
SKINS = {
    "circ_off": (4, None), "circ_on": (4, None),
    "circ_off_43": (4, None), "circ_on_43": (4, None),
    "circ_off_39": (4, None), "circ_on_39": (4, None),
    "circ_off_35": (4, None), "circ_on_35": (4, None),
    "circ_off_32": (4, None), "circ_on_32": (4, None),
    "circ_off_30": (4, None), "circ_on_30": (4, None),
    "cell_off": (3, "circ_off"), "cell_on": (3, "circ_on"),
}

GLOW_POW = 1.9       # how fast the halo falls to nothing


# ---------------------------------------------------------------- bmp io ---
def read_bmp32(path):
    """-> (w, h, [[(r,g,b,a) ...] ...]) top-down rows, alpha honoured.

    The skins are 32bpp BI_RGB: the 4th byte is NOT padding, MT reads it as
    alpha. Pillow reports mode RGB here and silently drops it, which is why
    this reads the file itself.
    """
    d = open(path, "rb").read()
    if d[:2] != b"BM":
        raise ValueError("%s: not a BMP" % path)
    off = struct.unpack("<I", d[10:14])[0]
    w, h = struct.unpack("<ii", d[18:26])
    bpp = struct.unpack("<H", d[28:30])[0]
    if bpp != 32:
        raise ValueError("%s: %d bpp, expected 32" % (path, bpp))
    flip = h > 0
    h = abs(h)
    stride = ((w * 32 + 31) // 32) * 4
    rows = []
    for y in range(h):
        src = (h - 1 - y) if flip else y
        base = off + src * stride
        row = []
        for x in range(w):
            p = base + x * 4
            row.append((d[p + 2], d[p + 1], d[p], d[p + 3]))
        rows.append(row)
    return w, h, rows


def write_bmp32(path, w, h, rows):
    stride = ((w * 32 + 31) // 32) * 4
    body = bytearray()
    for y in range(h - 1, -1, -1):          # bottom-up
        for (r, g, b, a) in rows[y]:
            body += bytes((b, g, r, a))
        body += b"\x00" * (stride - w * 4)
    info = struct.pack("<IiiHHIIiiII", 40, w, h, 1, 32, 0, len(body), 2835, 2835, 0, 0)
    head = struct.pack("<2sIHHI", b"BM", 14 + 40 + len(body), 0, 0, 54)
    open(path, "wb").write(head + info + bytes(body))


# ------------------------------------------------------------- geometry ---
def solid_radius(w, h, rows, thr=200):
    """Radius of the SOLID disc (alpha > thr) around the canvas centre, and the
    mean alpha of the ring just outside it - the glow has to start where the
    art's own glow starts, or a seam appears."""
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    r = 0.0
    for y in range(h):
        for x in range(w):
            if rows[y][x][3] > thr:
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d > r:
                    r = d
    ring, n = 0, 0
    for y in range(h):
        for x in range(w):
            a = rows[y][x][3]
            if a <= thr:
                continue
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d > r - 1.5:
                ring += a
                n += 1
    return r, (ring / n if n else 160.0)


def rim_colour(w, h, rows, r):
    """The disc's own outer colour, averaged over the rim band."""
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    acc, n = [0, 0, 0], 0
    for y in range(h):
        for x in range(w):
            rr, gg, bb, a = rows[y][x]
            if a < 200:
                continue
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d > r - 2.0:
                acc[0] += rr
                acc[1] += gg
                acc[2] += bb
                n += 1
    return tuple(v // n for v in acc) if n else (110, 118, 133)


def resample(w, h, rows, tw, th):
    """Bilinear canvas resize (used only when a skin borrows another's face)."""
    out = []
    for y in range(th):
        fy = y * (h - 1) / float(max(1, th - 1))
        row = []
        for x in range(tw):
            fx = x * (w - 1) / float(max(1, tw - 1))
            x0, y0 = int(fx), int(fy)
            x1, y1 = min(w - 1, x0 + 1), min(h - 1, y0 + 1)
            tx, ty = fx - x0, fy - y0
            px = []
            for k in range(4):
                a = rows[y0][x0][k] * (1 - tx) + rows[y0][x1][k] * tx
                b = rows[y1][x0][k] * (1 - tx) + rows[y1][x1][k] * tx
                px.append(a * (1 - ty) + b * ty)
            row.append(tuple(int(round(v)) for v in px))
        out.append(row)
    return out


def rebuild(name, margin, dry, face_from=None):
    path = os.path.join(ICONS, name + ".bmp")
    w, h, rows = read_bmp32(path)
    fpath = os.path.join(ICONS, (face_from or name) + ".bmp")
    fw, fh, frows = read_bmp32(fpath)
    if face_from:                                   # borrow the circular face
        rows = resample(fw, fh, frows, w, h)
    r_solid, a0 = solid_radius(w, h, rows)
    rim = rim_colour(w, h, rows, r_solid)
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    # the glow must be DEAD one pixel before the canvas ends, or the last row
    # keeps a few alpha levels and the silhouette is the rectangle again.
    half = min(w, h) / 2.0 - 1.0
    out = []
    for y in range(h):
        row = []
        for x in range(w):
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if dist <= r_solid:
                row.append(rows[y][x])              # the disc, untouched
            else:
                t = (dist - r_solid) / max(0.001, half - r_solid)
                if t >= 1.0:
                    row.append((0, 0, 0, 0))        # dead before the edge
                else:
                    a = a0 * ((1.0 - t) ** GLOW_POW)
                    row.append((rim[0], rim[1], rim[2], int(round(a))))
        out.append(row)
    changed = any(out[y][x] != rows[y][x] for y in range(h) for x in range(w))
    print("  %-13s canvas=%dx%d  disc r=%.1f  glow0=%3d  rim=%s  face=%-8s %s"
          % (name, w, h, r_solid, int(a0), rim, face_from or "self",
             "rewritten" if changed else "unchanged"))
    if not dry and changed:
        write_bmp32(path, w, h, out)
    return changed


def install(target):
    import shutil
    n = 0
    for name in SKINS:
        src = os.path.join(ICONS, name + ".bmp")
        dst = os.path.join(target, name + ".bmp")
        if os.path.exists(src):
            shutil.copy2(src, dst)
            n += 1
    print("installed %d skins -> %s" % (n, target))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--install", default=None,
                    help="terminal MQL5\\Files\\Icons folder to refresh")
    a = ap.parse_args()
    print("rebuilding disc skins in %s" % ICONS)
    n = 0
    for name, (margin, face_from) in SKINS.items():
        if not os.path.exists(os.path.join(ICONS, name + ".bmp")):
            print("  %-13s MISSING" % name)
            continue
        if rebuild(name, margin, a.dry, face_from):
            n += 1
    print("%d skin(s) %s" % (n, "would change" if a.dry else "changed"))
    if a.install and not a.dry:
        install(a.install)
    return 0


if __name__ == "__main__":
    sys.exit(main())
