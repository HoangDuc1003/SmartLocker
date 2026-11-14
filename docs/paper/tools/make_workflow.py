"""Draw the workflow figure of the paper (Fig. workflow) as a vector PDF and a 300 dpi PNG.

Usage: python -I docs/paper/tools/make_workflow.py
Writes docs/paper/images/workflow.pdf and docs/paper/images/workflow.png.

The page is 504 pt wide (7 in, the text width of the one-column IEEE layout), so the figure is placed at
\\linewidth without scaling and its labels stay at 8-9 pt as IEEE asks. The hardware parts are drawn front-on
after the parts of the prototype box (ESP32 DevKit on a terminal expansion board, red PN532 NFC module and a white
card, AS608, 4x4 membrane keypad, LCD 1602, ultrasonic ranger, SG90), redrawn after product photos.
"""
import math
import os

import pymupdf as fitz

W, H = 504, 250
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "images")


def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


INK = hexc("#262626")
BLUE = hexc("#2F6DB5")
LIGHT = hexc("#DCE8F6")
YELLOW = hexc("#E8B931")
RED = hexc("#C9302C")
GREEN = hexc("#3C9A4B")
GRAY = hexc("#BDBDBD")
DARK = hexc("#454545")
GOLD = hexc("#D4A93A")
SILVER = hexc("#CDD1D6")
WHITE = (1, 1, 1)

doc = fitz.open()
page = doc.new_page(width=W, height=H)
sh = page.new_shape()
texts = []
MORPH = None  # set while an icon is drawn larger than its 24 pt design box


def text_at(x, y, s, size, font="helv", color=(0, 0, 0)):
    texts.append((x, y, s, font, size, color, fitz.get_text_length(s, fontname=font, fontsize=size)))


def text_c(cx, y, s, bold=False, size=8.0, color=(0, 0, 0), font=None):
    font = font or ("hebo" if bold else "helv")
    w = fitz.get_text_length(s, fontname=font, fontsize=size)
    texts.append((cx - w / 2, y, s, font, size, color, w))


def fin(**kw):
    if MORPH:
        kw["morph"] = MORPH
    sh.finish(**kw)


def rrect(x0, y0, x1, y1, r, fill=None, stroke=INK, w=0.6, opacity=1):
    r = min(0.5, r / min(x1 - x0, y1 - y0)) if r else None
    sh.draw_rect(fitz.Rect(x0, y0, x1, y1), radius=r)
    fin(color=stroke, fill=fill, width=w, fill_opacity=opacity)


def circle(cx, cy, r, fill=None, stroke=INK, w=0.6):
    sh.draw_circle((cx, cy), r)
    fin(color=stroke, fill=fill, width=w)


def poly(pts, fill=None, stroke=INK, w=0.6, close=True):
    sh.draw_polyline(pts)
    fin(color=stroke, fill=fill, width=w, closePath=close, lineJoin=1, lineCap=1)


def arc_path(cx, cy, r, a0, a1):
    """Append a circular arc (degrees, counter-clockwise on screen) as Bezier pieces."""
    n = max(1, math.ceil(abs(a1 - a0) / 90))
    step = (a1 - a0) / n
    for i in range(n):
        b0 = math.radians(a0 + i * step)
        b1 = math.radians(a0 + (i + 1) * step)
        k = 4 / 3 * math.tan((b1 - b0) / 4)
        p0 = (cx + r * math.cos(b0), cy - r * math.sin(b0))
        p3 = (cx + r * math.cos(b1), cy - r * math.sin(b1))
        c1 = (p0[0] - k * r * math.sin(b0), p0[1] - k * r * math.cos(b0))
        c2 = (p3[0] + k * r * math.sin(b1), p3[1] + k * r * math.cos(b1))
        sh.draw_bezier(p0, c1, c2, p3)


def arc(cx, cy, r, a0, a1, stroke=INK, w=0.6):
    arc_path(cx, cy, r, a0, a1)
    fin(color=stroke, width=w, closePath=False, lineCap=1)


def line(p, q, stroke=INK, w=0.6):
    sh.draw_line(p, q)
    fin(color=stroke, width=w, closePath=False, lineCap=1)


def curve(p0, c1, c2, p3, stroke=INK, w=0.6):
    sh.draw_bezier(p0, c1, c2, p3)
    fin(color=stroke, width=w, closePath=False, lineCap=1)


# ---- hardware parts, drawn front-on inside a 60 x 34 pt box centred on (cx, cy) ----
# Redrawn after product photos of the parts used in the box (no photo is copied).

def p_esp32(cx, cy):
    """ESP32 DevKit, 38 pins, black PCB, USB-C on the left, WROOM-32 module with its antenna on the right."""
    rrect(cx - 28, cy - 12.5, cx + 28, cy + 12.5, 1.6, fill=hexc("#161616"), stroke=hexc("#000000"), w=0.4)
    for row in (-10.6, 10.6):
        for k in range(19):
            x = cx - 24.6 + k * 2.75
            circle(x, cy + row, 0.85, fill=GOLD, stroke=None)
            circle(x, cy + row, 0.38, fill=hexc("#111111"), stroke=None)
    rrect(cx + 3, cy - 8.2, cx + 29, cy + 8.2, 0.6, fill=hexc("#1E1E1E"), stroke=hexc("#3A3A3A"), w=0.3)
    rrect(cx + 4, cy - 7.2, cx + 21, cy + 7.2, 0.8, fill=SILVER, stroke=hexc("#8A8F96"), w=0.4)
    arc(cx + 8.5, cy - 3.0, 1.8, 30, 330, stroke=hexc("#8A8F96"), w=0.5)
    poly([(cx + 23, cy + 6), (cx + 23, cy - 6), (cx + 24.6, cy - 6), (cx + 24.6, cy + 5), (cx + 26.2, cy + 5),
          (cx + 26.2, cy - 6), (cx + 27.8, cy - 6), (cx + 27.8, cy + 6)], stroke=GOLD, w=0.5, close=False)
    rrect(cx - 30.5, cy - 3.4, cx - 24, cy + 3.4, 1.6, fill=SILVER, stroke=hexc("#6E737A"), w=0.4)  # USB-C
    rrect(cx - 29.5, cy - 1.6, cx - 25, cy + 1.6, 0.8, fill=hexc("#3A3A3A"), stroke=None)
    for by in (-6.4, 6.4):  # EN, BOOT
        rrect(cx - 21.5, cy + by - 1.6, cx - 18.3, cy + by + 1.6, 0.4, fill=hexc("#E8E8E8"), stroke=None)
        circle(cx - 19.9, cy + by, 0.9, fill=hexc("#555555"), stroke=None)
    rrect(cx - 15, cy - 3.2, cx - 8.6, cy + 3.2, 0.3, fill=hexc("#2B2B2B"), stroke=hexc("#555555"), w=0.3)
    rrect(cx - 5.5, cy - 7.2, cx - 1.5, cy - 4.2, 0.2, fill=hexc("#2B2B2B"), stroke=None)
    rrect(cx - 5, cy - 1.6, cx - 1.6, cy + 1.6, 0.2, fill=hexc("#E2A33B"), stroke=None)
    for k in range(3):
        rrect(cx - 6 + k * 2.2, cy + 4.6, cx - 4.8 + k * 2.2, cy + 6.4, 0, fill=hexc("#C8B89A"), stroke=None)
    circle(cx - 16.5, cy + 6.4, 0.6, fill=hexc("#E53935"), stroke=None)
    text_c(cx + 13.5, cy + 3.2, "ESP32", size=3.6, color=hexc("#6B7078"), font="hebo")


def p_keypad(cx, cy):
    """4x4 membrane keypad (blue digits, red letters, * and #) with its ribbon cable and connector."""
    rrect(cx - 3.6, cy + 4, cx + 3.6, cy + 13.5, 0, fill=hexc("#E4E6E8"), stroke=hexc("#A9AEB3"), w=0.3)
    for k in range(8):
        line((cx - 3.0 + k * 0.85, cy + 4.5), (cx - 3.0 + k * 0.85, cy + 13.3), stroke=hexc("#A9AEB3"), w=0.2)
    rrect(cx - 4.2, cy + 13.3, cx + 4.2, cy + 17, 0.4, fill=hexc("#151515"), stroke=None)
    rrect(cx - 12, cy - 17, cx + 12, cy + 6, 1.8, fill=hexc("#1C1C1C"), stroke=hexc("#000000"), w=0.4)
    rrect(cx - 10.8, cy - 15.8, cx + 10.8, cy + 4.8, 1.4, fill=None, stroke=hexc("#7F858B"), w=0.35)
    labels = ["123A", "456B", "789C", "*0#D"]
    for j, row in enumerate(labels):
        for i, ch in enumerate(row):
            red = i == 3 or (j == 3 and i in (0, 2))
            x, y = cx - 6.9 + i * 4.6, cy - 12.0 + j * 4.6
            rrect(x - 1.85, y - 1.85, x + 1.85, y + 1.85, 0.5, fill=hexc("#E2384F") if red else hexc("#3DA5DB"),
                  stroke=None)
            text_c(x, y + 0.95, ch, size=2.7, color=WHITE, font="hebo")


def p_pn532(cx, cy):
    """PN532 NFC module V3: square red board, antenna band, two plated holes, chip, DIP switch, pads."""
    rrect(cx + 5, cy - 9, cx + 30, cy + 11, 1.8, fill=WHITE, stroke=hexc("#9A9A9A"), w=0.5)  # white card
    bx = cx - 7
    rrect(bx - 17, cy - 17, bx + 17, cy + 17, 2.4, fill=hexc("#E3262F"), stroke=hexc("#A3121A"), w=0.4)
    rrect(bx - 15.2, cy - 15.2, bx + 15.2, cy + 15.2, 2, fill=None, stroke=hexc("#F6C4C4"), w=1.5)
    rrect(bx - 12.6, cy - 12.6, bx + 12.6, cy + 12.6, 1.6, fill=None, stroke=hexc("#F1A3A3"), w=0.4)
    for hx, hy in ((-12.2, -12.2), (12.2, 12.2)):
        circle(bx + hx, cy + hy, 2.5, fill=SILVER, stroke=hexc("#8A8F96"), w=0.3)
        circle(bx + hx, cy + hy, 1.2, fill=WHITE, stroke=None)
    for k in range(8):  # top pads
        rrect(bx - 7 + k * 1.6, cy - 11.2, bx - 6.1 + k * 1.6, cy - 10.0, 0, fill=WHITE, stroke=None)
    rrect(bx + 5, cy - 12.2, bx + 10.5, cy - 8.2, 0.3, fill=hexc("#C9952C"), stroke=None)  # DIP switch
    for k in range(2):
        rrect(bx + 6 + k * 2.4, cy - 11.4, bx + 7.4 + k * 2.4, cy - 9.8, 0, fill=hexc("#1A1A1A"), stroke=None)
    rrect(bx - 3.6, cy - 3.6, bx + 3.6, cy + 3.6, 0.3, fill=hexc("#1E1E1E"), stroke=hexc("#555555"), w=0.3)
    for px, py in ((-8.5, -4), (-8.5, -1.5), (-8.5, 1), (5.5, -5.5), (6.5, 4.5), (-2, 7)):
        rrect(bx + px, cy + py, bx + px + 2, cy + py + 1.1, 0, fill=hexc("#D9C9A8"), stroke=None)
    for k in range(8):  # bottom header pads
        circle(bx - 9.8 + k * 2.6, cy + 12.4, 0.9, fill=WHITE, stroke=None)
    for k in range(4):  # I2C pads on the right
        circle(bx + 13.2, cy - 3.6 + k * 2.6, 0.9, fill=WHITE, stroke=None)


def p_as608(cx, cy):
    """AS608 optical fingerprint sensor: black housing, recessed glass window, gold PCB edge."""
    poly([(cx + 8, cy - 15), (cx + 12, cy - 17), (cx + 12, cy + 13), (cx + 8, cy + 15)], fill=hexc("#C9A23A"),
         stroke=hexc("#8E7020"), w=0.4)
    rrect(cx - 11, cy - 15, cx + 8.5, cy + 16, 1.8, fill=hexc("#191919"), stroke=hexc("#000000"), w=0.4)
    line((cx - 11, cy - 4), (cx + 8.5, cy - 4), stroke=hexc("#3A3A3A"), w=0.5)
    circle(cx - 1.2, cy - 9.5, 0.9, fill=hexc("#050505"), stroke=hexc("#444444"), w=0.3)
    rrect(cx - 8.8, cy - 1.5, cx + 6.3, cy + 13.8, 1.2, fill=hexc("#2C2C2C"), stroke=hexc("#4A4A4A"), w=0.4)
    rrect(cx - 6.8, cy + 0.5, cx + 4.3, cy + 11.8, 0.6, fill=hexc("#11181D"), stroke=None)
    poly([(cx - 6.8, cy + 9), (cx - 0.5, cy + 0.5), (cx + 2.2, cy + 0.5), (cx - 4.2, cy + 11.8), (cx - 6.8, cy + 11.8)],
         fill=hexc("#2E3C46"), stroke=None)


def p_lcd(cx, cy):
    """LCD 1602 module: green PCB, black bezel, yellow-green screen, 16-pin header top left."""
    rrect(cx - 30, cy - 15, cx + 30, cy + 15, 1, fill=hexc("#2D8A3C"), stroke=hexc("#1E6129"), w=0.5)
    for sx in (-27.4, 27.4):
        for sy in (-12.4, 12.4):
            circle(cx + sx, cy + sy, 1.6, fill=hexc("#E9D8A6"), stroke=GOLD, w=0.5)
            circle(cx + sx, cy + sy, 0.7, fill=WHITE, stroke=None)
    for k in range(16):
        circle(cx - 23 + k * 1.8, cy - 13.2, 0.6, fill=GOLD, stroke=None)
    rrect(cx - 26, cy - 10.5, cx + 26, cy + 11, 0.8, fill=hexc("#121212"), stroke=None)
    rrect(cx - 22.5, cy - 6.5, cx + 22.5, cy + 7.5, 0.4, fill=hexc("#B4C63A"), stroke=None)
    rrect(cx - 22.5, cy - 6.5, cx + 22.5, cy - 4.5, 0, fill=hexc("#A3B52F"), stroke=None)


def p_ultrasonic(cx, cy):
    """Ultrasonic ranger on a blue board: two meshed transducers and a white 4-pin connector."""
    rrect(cx - 28, cy - 13, cx + 28, cy + 13, 3, fill=hexc("#2D7DB8"), stroke=hexc("#1D5C8A"), w=0.4)
    for hx, hy in ((-25, -10), (25, 10)):
        circle(cx + hx, cy + hy, 1.5, fill=WHITE, stroke=hexc("#9DB9CF"), w=0.4)
    for sx in (-13, 5):
        circle(cx + sx, cy, 9.5, fill=SILVER, stroke=hexc("#7E848B"), w=0.5)
        circle(cx + sx, cy, 7.4, fill=hexc("#45494E"), stroke=hexc("#9AA0A6"), w=0.3)
        for d in (-5, -3, -1, 1, 3, 5):
            h = math.sqrt(max(0, 7.0 ** 2 - d ** 2))
            line((cx + sx + d, cy - h), (cx + sx + d, cy + h), stroke=hexc("#6A6F75"), w=0.3)
            line((cx + sx - h, cy + d), (cx + sx + h, cy + d), stroke=hexc("#6A6F75"), w=0.3)
    rrect(cx + 16.5, cy - 6, cx + 24.5, cy + 6, 0.6, fill=hexc("#F4F4F4"), stroke=hexc("#A0A0A0"), w=0.4)
    for k in range(4):
        rrect(cx + 18.5, cy - 4.4 + k * 2.6, cx + 22.5, cy - 3.2 + k * 2.6, 0, fill=hexc("#C9C9C9"), stroke=None)


def p_sg90(cx, cy):
    """SG90 micro servo (translucent blue), white horn, brown-red-orange lead looping to its plug."""
    for k, c in enumerate(("#6D3B1F", "#D32F2F", "#F28C1E")):
        o = k * 1.0
        curve((cx + 10, cy + 6 + o), (cx + 30, cy + 6 + o), (cx + 28, cy - 16 + o), (cx + 16, cy - 12 + o),
              stroke=hexc(c), w=0.8)
    rrect(cx + 12.5, cy - 14.5, cx + 17.5, cy - 9.5, 0.5, fill=hexc("#1A1A1A"), stroke=None)
    blue, edge = hexc("#2F5FD9"), hexc("#1D3F9E")
    rrect(cx - 16, cy - 1.5, cx + 12, cy + 2.5, 0.8, fill=blue, stroke=edge, w=0.5, opacity=0.9)
    rrect(cx - 11, cy - 8, cx + 8, cy + 12, 1.2, fill=blue, stroke=edge, w=0.5, opacity=0.9)
    rrect(cx - 11, cy - 12, cx - 1, cy - 8, 1, fill=hexc("#4C78EA"), stroke=edge, w=0.5)
    rrect(cx - 17, cy - 15.5, cx + 3, cy - 12.5, 1.5, fill=WHITE, stroke=hexc("#9A9A9A"), w=0.5)
    for k in range(4):
        circle(cx - 14 + k * 4.3, cy - 14, 0.5, fill=hexc("#888888"), stroke=None)
    circle(cx - 6, cy - 14, 1.3, fill=hexc("#F2F2F2"), stroke=hexc("#9A9A9A"), w=0.4)
    rrect(cx - 7.5, cy - 3.5, cx + 5.5, cy + 7, 0.6, fill=hexc("#151515"), stroke=None)
    text_c(cx - 1, cy + 3.4, "SG90", size=3.6, color=hexc("#F2C94C"), font="hebo")


def p_phone(cx, cy):
    """Phone showing the unlock page."""
    rrect(cx - 9, cy - 17, cx + 9, cy + 17, 2.6, fill=hexc("#222222"), stroke=INK, w=0.4)
    rrect(cx - 7.6, cy - 14, cx + 7.6, cy + 13, 0.8, fill=WHITE, stroke=None)
    rrect(cx - 7.6, cy - 14, cx + 7.6, cy - 10, 0, fill=BLUE, stroke=None)
    rrect(cx - 5.5, cy - 6.5, cx + 5.5, cy - 2.5, 0.8, fill=None, stroke=hexc("#8A8A8A"), w=0.4)
    for k in range(6):
        circle(cx - 4.2 + k * 1.7, cy - 4.5, 0.45, fill=INK, stroke=None)
    rrect(cx - 5.5, cy + 1, cx + 5.5, cy + 5, 0.8, fill=GREEN, stroke=None)
    rrect(cx - 2, cy + 14.6, cx + 2, cy + 15.4, 0.4, fill=hexc("#777777"), stroke=None)


def p_door_weight(cx, cy):
    rrect(cx - 15, cy - 16, cx + 1, cy + 16, 0.6, fill=hexc("#F2F2F2"), stroke=hexc("#7A7A7A"))
    rrect(cx - 3.5, cy - 1, cx - 1.5, cy + 4, 0.8, fill=hexc("#BBBBBB"), stroke=None)
    poly([(cx + 4, cy + 16), (cx + 7, cy + 3), (cx + 16, cy + 3), (cx + 19, cy + 16)], fill=DARK)
    circle(cx + 11.5, cy, 2.8, w=1.0)


# ---- generic icons, drawn in a 24 x 24 pt box and enlarged ----

def i_server(cx, cy):
    for k in range(3):
        y = cy - 11 + k * 7.6
        rrect(cx - 10, y, cx + 10, y + 6.2, 1, fill=DARK)
        circle(cx + 6.5, y + 3.1, 1.1, fill=hexc("#7CD67C"), stroke=None)
        line((cx - 7, y + 3.1), (cx + 1, y + 3.1), stroke=GRAY, w=1.0)


def i_pulse(cx, cy):
    poly([(cx - 12, cy), (cx - 6, cy), (cx - 3.5, cy - 8), (cx + 0.5, cy + 9), (cx + 3.5, cy - 3),
          (cx + 5.5, cy), (cx + 12, cy)], stroke=RED, w=1.5, close=False)


def i_database(cx, cy):
    f = LIGHT
    sh.draw_oval(fitz.Rect(cx - 9, cy + 5, cx + 9, cy + 11))
    fin(color=BLUE, fill=f, width=0.8)
    sh.draw_rect(fitz.Rect(cx - 9, cy - 8, cx + 9, cy + 8))
    fin(color=None, fill=f, width=0)
    line((cx - 9, cy - 8), (cx - 9, cy + 8), stroke=BLUE, w=0.8)
    line((cx + 9, cy - 8), (cx + 9, cy + 8), stroke=BLUE, w=0.8)
    sh.draw_oval(fitz.Rect(cx - 9, cy - 11, cx + 9, cy - 5))
    fin(color=BLUE, fill=f, width=0.8)


def i_magnifier(cx, cy):
    line((cx + 2.5, cy + 2.5), (cx + 10, cy + 10), stroke=DARK, w=3.0)
    circle(cx - 2.5, cy - 2.5, 7.5, fill=WHITE, stroke=DARK, w=1.6)


def i_flow(cx, cy):
    line((cx - 6, cy - 5), (cx - 7.5, cy - 5))
    line((cx - 7.5, cy - 5), (cx - 7.5, cy + 5))
    line((cx + 6, cy - 5), (cx + 7.5, cy - 5))
    line((cx + 7.5, cy - 5), (cx + 7.5, cy + 5))
    poly([(cx, cy - 11), (cx + 6, cy - 5), (cx, cy + 1), (cx - 6, cy - 5)], fill=YELLOW)
    rrect(cx - 12, cy + 5, cx - 3, cy + 11, 0.5, fill=LIGHT)
    rrect(cx + 3, cy + 5, cx + 12, cy + 11, 0.5, fill=LIGHT)


def i_network(cx, cy):
    layers = [[(cx - 9, cy - 6), (cx - 9, cy + 6)],
              [(cx, cy - 9), (cx, cy), (cx, cy + 9)],
              [(cx + 9, cy)]]
    for a, b in zip(layers, layers[1:]):
        for p in a:
            for q in b:
                line(p, q, stroke=GRAY, w=0.6)
    for li, layer in enumerate(layers):
        for p in layer:
            circle(p[0], p[1], 2.5, fill=(BLUE, YELLOW, RED)[li], w=0.5)


def i_warning(cx, cy):
    poly([(cx, cy - 11), (cx + 12, cy + 10), (cx - 12, cy + 10)], fill=RED, stroke=hexc("#8E1F1C"))
    rrect(cx - 1.2, cy - 4, cx + 1.2, cy + 3, 0, fill=WHITE, stroke=None)
    circle(cx, cy + 6, 1.3, fill=WHITE, stroke=None)


def i_ticket(cx, cy):
    rrect(cx - 8, cy - 9, cx + 8, cy + 11, 1, fill=WHITE)
    rrect(cx - 4, cy - 11, cx + 4, cy - 7, 0.8, fill=GRAY)
    for y in (cy - 3, cy + 1.5, cy + 6):
        line((cx - 5, y), (cx + 5, y), stroke=DARK, w=0.8)


def i_chain(cx, cy):
    line((cx - 6, cy), (cx - 3, cy), stroke=BLUE, w=1.2)
    line((cx + 3, cy), (cx + 6, cy), stroke=BLUE, w=1.2)
    for x in (cx - 12, cx - 3, cx + 6):
        rrect(x, cy - 3.5, x + 6, cy + 3.5, 0.6, fill=LIGHT, stroke=BLUE, w=0.8)
    rrect(cx - 2.5, cy - 11, cx + 2.5, cy - 7, 0.5, fill=YELLOW, w=0.5)
    arc(cx, cy - 11, 1.9, 0, 180, w=0.8)


def i_monitor(cx, cy):
    rrect(cx - 12, cy - 10, cx + 12, cy + 5, 1, fill=DARK)
    for k, (h, c) in enumerate(((5, BLUE), (9, YELLOW), (7, GREEN), (11, RED))):
        x = cx - 8 + k * 4.5
        rrect(x, cy + 2.5 - h, x + 3, cy + 2.5, 0, fill=c, stroke=None)
    rrect(cx - 2, cy + 5, cx + 2, cy + 9, 0, fill=GRAY, stroke=None)
    rrect(cx - 6, cy + 9, cx + 6, cy + 10.5, 0.4, fill=GRAY, stroke=None)


def i_pin(cx, cy):
    sh.draw_bezier((cx, cy + 11), (cx - 3, cy + 6), (cx - 8, cy + 1), (cx - 8, cy - 3))
    arc_path(cx, cy - 3, 8, 180, 0)
    sh.draw_bezier((cx + 8, cy - 3), (cx + 8, cy + 1), (cx + 3, cy + 6), (cx, cy + 11))
    fin(color=hexc("#8E1F1C"), fill=RED, width=0.6)
    circle(cx, cy - 3, 3, fill=WHITE, stroke=None)


def i_shield(cx, cy):
    poly([(cx, cy - 11), (cx + 9, cy - 7.5), (cx + 8, cy + 3), (cx, cy + 11), (cx - 8, cy + 3), (cx - 9, cy - 7.5)],
         fill=GREEN, stroke=hexc("#24622E"))
    poly([(cx - 4, cy), (cx - 1, cy + 3.5), (cx + 5, cy - 4)], stroke=WHITE, w=1.8, close=False)


ICONS = {i_server, i_pulse, i_database, i_magnifier, i_flow, i_network, i_warning, i_ticket, i_chain,
         i_monitor, i_pin, i_shield}

# ---- layout ----

PANELS = [
    (2, 142, "Input sources", hexc("#E6EFFA"), hexc("#BCD2EE")),
    (154, 370, "Processing", hexc("#FDF0E1"), hexc("#F3CFA4")),
    (382, 502, "Output", hexc("#FBE8E8"), hexc("#EFC0C0")),
]
COLUMNS = [
    (6, 72, "Credentials", [(p_keypad, "Keypad 4x4", "(PIN)"), (p_pn532, "PN532 NFC,", "RFID card"),
                            (p_as608, "AS608", "fingerprint")]),
    (76, 138, "Web, sensors", [(p_phone, "Phone", "unlock page"), (p_ultrasonic, "Ultrasonic,", "presence"),
                               (p_door_weight, "Door time,", "weight")]),
    (158, 228, "ESP32 box", [(p_esp32, "ESP32 forwards", "credential"), (p_lcd, "LCD 1602", "message"),
                             (p_sg90, "SG90 servo", "unlocks")]),
    (230, 300, "Server", [(i_server, "Authorise", "or deny"), (i_pulse, "Heartbeat,", "commands"),
                          (i_database, "Store access", "sessions")]),
    (302, 366, "Detection", [(i_magnifier, "Load context", "from DB"), (i_flow, "Rule engine", "(Tier 1)"),
                             (i_network, "Weka risk", "(Tier 2)")]),
    (386, 442, "Records", [(i_warning, "Typed alert,", "evidence"), (i_ticket, "Maintenance", "ticket"),
                           (i_chain, "Audit hash", "chain")]),
    (446, 498, "Review", [(i_monitor, "Staff", "dashboard"), (i_pin, "User map,", "e-mail"),
                          (i_shield, "Auditor", "check")]),
]
PY0, PY1 = 9, 247
CARD_Y = (44, 112, 180)
CARD_H = 63

for x0, x1, title, fill, tab in PANELS:
    rrect(x0, PY0, x1, PY1, 5, fill=fill, stroke=hexc("#8C8C8C"), w=0.6)
    tw = fitz.get_text_length(title, fontname="hebo", fontsize=9)
    cx = (x0 + x1) / 2
    rrect(cx - tw / 2 - 8, 2, cx + tw / 2 + 8, 16, 3, fill=tab, stroke=hexc("#8C8C8C"), w=0.6)
    text_c(cx, 12.3, title, bold=True, size=9)

for x0, x1, head, cards in COLUMNS:
    cx = (x0 + x1) / 2
    rrect(x0, 22, x1, 37, 2.5, fill=WHITE, stroke=hexc("#8C8C8C"), w=0.5)
    text_c(cx, 32.6, head, bold=True)
    for (art, l1, l2), y0 in zip(cards, CARD_Y):
        rrect(x0, y0, x1, y0 + CARD_H, 3, fill=WHITE, stroke=hexc("#B0B0B0"), w=0.5)
        ay = y0 + 21
        if art in ICONS:
            MORPH = (fitz.Point(cx, ay), fitz.Matrix(1.3, 1.3))
            art(cx, ay)
            MORPH = None
        else:
            art(cx, ay)
        text_c(cx, y0 + 49, l1)
        text_c(cx, y0 + 58, l2)

# arrows between the panels
for xa, xb in ((142, 154), (370, 382)):
    y = (PY0 + PY1) / 2
    line((xa, y), (xb - 4.5, y), w=1.2)
    poly([(xb, y), (xb - 5, y - 3), (xb - 5, y + 3)], fill=INK, stroke=None)

sh.commit()

# text on top of the shapes; check that every 8 pt label fits its column
cols = [(c[0], c[1]) for c in COLUMNS]
for x, y, s, font, size, color, w in texts:
    page.insert_text((x, y), s, fontname=font, fontsize=size, color=color)
    if size == 8:
        for c0, c1 in cols:
            if c0 <= x + w / 2 <= c1 and w > (c1 - c0) - 3:
                print("label too wide:", s, round(w, 1), "for column", c1 - c0)

os.makedirs(OUT, exist_ok=True)
doc.save(os.path.join(OUT, "workflow.pdf"), garbage=4, deflate=True)
page.get_pixmap(dpi=300).save(os.path.join(OUT, "workflow.png"))
print("wrote", os.path.normpath(os.path.join(OUT, "workflow.pdf")), "and workflow.png")
