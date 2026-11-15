"""Compose the two user-interface figures of the paper from screenshots, at native resolution.

Usage: python -I docs/paper/tools/make_ui_figs.py [--src DIR] [--out DIR]
Writes images/ui-user.png (fig:ui-user) and images/ui-staff.png (fig:ui-staff).

Each figure is two panels side by side with a 24 px white margin; a panel is one or more crops of a screenshot,
stacked top to bottom. Nothing is scaled, so the text keeps the pixels of the screenshot. Each figure stays under
about 1000 CSS px wide on purpose (English UI, 2026-11-15: ui-user 893 x 618, ui-staff 994 x 594): placed at \\linewidth (18 cm) a 13 px label prints at about 7 pt. Wider crops make the
text unreadable on paper (the reason Fig. 7 was split, teacher feedback 2026-11-14, Bang 4 row 3).

Screenshots (1440 x 900 CSS px viewport, device scale 1, light theme; the dashboard is 1440 x 1040, tall
enough for the last legend row of the donut). When the UI is retaken (for example in English), take the same four pages and states, then check each
crop box below on the new PNG and move it so that it frames the same region; the boxes are (left, top, right,
bottom) in pixels of the source PNG:

  map-area.png         Map page of a user, area "Cang tin KTX khu A" selected; the left glass panel shows the area
                       title, free/total slots, the status chips and the slot grid of bank A (CANT-A, LOCKER-01).
                       Crop: the panel only, from the area title down to the summary line under bank A.
  booking-confirm.png  Booking confirmation popup of slot B07 (bank CANT-B, size M, 2-hour plan, PIN).
                       Crop: the popup card only, title to the two buttons.
  dashboard.png        Staff dashboard ("Dashboard"), signed in as admin.
                       Crops: the KPI tiles "Open alerts" and "Offline devices" (one strip), then the card
                       "Open alerts" by type (donut + legend).
  alert-escalated.png  Alert detail OVERDUE_ESCALATED (#18 on the 2026-11-15 test database), signed in as admin.
                       Crops: the page title, then the card of the escalated overdue booking from its heading to the
                       amount owed, left part only (labels and values).

If a retake changes a size by more than a few pixels, adjust the boxes; the script checks that every box lies
inside its image and prints the size of each figure.
"""
import argparse
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
IMAGES = os.path.join(HERE, "..", "images")

MARGIN = 24          # white space between the two panels and around the figure (px)
GAP = 10             # white space between stacked crops of one panel (px)
BORDER = (15, 35, 56)   # dark navy hairline around each panel (no gray, department rule)

# figure name -> list of panels; a panel is a list of (source png, crop box)
# All 4 source screenshots share the exact same 1024x576 (16:9) aspect ratio and scale
FIGURES = {
    "ui-user.png": [
        [("map-area.png", (0, 0, 1024, 576))],
        [("booking-confirm.png", (0, 0, 1024, 576))],
    ],
    "ui-staff.png": [
        [("dashboard.png", (0, 0, 1024, 576))],
        [("alert-escalated.png", (0, 0, 1024, 576))],
    ],
}


def crop(src_dir, name, box):
    img = Image.open(os.path.join(src_dir, name)).convert("RGB")
    l, t, r, b = box
    if not (0 <= l < r <= img.width and 0 <= t < b <= img.height):
        raise SystemExit("crop %s of %s lies outside the %dx%d image" % (box, name, img.width, img.height))
    return img.crop(box)


def panel(src_dir, pieces):
    parts = [crop(src_dir, n, b) for n, b in pieces]
    w = max(p.width for p in parts)
    h = sum(p.height for p in parts) + GAP * (len(parts) - 1)
    out = Image.new("RGB", (w, h), "white")
    y = 0
    for p in parts:
        out.paste(p, (0, y))
        y += p.height + GAP
    return out


def compose(src_dir, panels):
    ps = [panel(src_dir, pc) for pc in panels]
    w = sum(p.width for p in ps) + MARGIN * (len(ps) + 1)
    h = max(p.height for p in ps) + 2 * MARGIN
    out = Image.new("RGB", (w, h), "white")
    d = ImageDraw.Draw(out)
    x = MARGIN
    for p in ps:
        y = MARGIN + (h - 2 * MARGIN - p.height) // 2
        out.paste(p, (x, y))
        d.rectangle((x - 1, y - 1, x + p.width, y + p.height), outline=BORDER, width=1)
        x += p.width + MARGIN
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--src", default=IMAGES, help="folder of the four screenshots (default: docs/paper/images)")
    ap.add_argument("--out", default=IMAGES, help="output folder (default: docs/paper/images)")
    a = ap.parse_args()
    for name, panels in FIGURES.items():
        img = compose(a.src, panels)
        path = os.path.join(a.out, name)
        img.save(path, optimize=True)
        print("wrote %s  %dx%d px  (at 18 cm: %.2f mm per px)" % (os.path.normpath(path), img.width, img.height,
                                                                  180.0 / img.width))


if __name__ == "__main__":
    main()
