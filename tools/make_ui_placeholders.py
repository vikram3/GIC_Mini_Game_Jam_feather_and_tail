#!/usr/bin/env python3
"""Generates PLACEHOLDER UI art into res://Art/...  (needs Pillow:  pip install pillow)

It NEVER overwrites a file that already exists, so it is safe to run again after you have
dropped in your own art - it only fills in whatever is still missing.
    python tools/make_ui_placeholders.py            # fill in missing files
    python tools/make_ui_placeholders.py --force    # regenerate everything (overwrites!)

Every file name here is a "slot": the scenes / theme point at these exact paths, so replacing
the PNG (same name) re-skins the game.  See Art/README.txt for what each slot is.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Art")
FORCE = "--force" in sys.argv
SS = 4  # supersampling for smooth edges

CREAM = (255, 245, 214)
GOLD = (255, 217, 89)
LEAF = (46, 102, 71)
DARK = (13, 38, 28)
EDGE = (115, 191, 128)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def out(path):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    return full


def save(img, path):
    full = out(path)
    if os.path.exists(full) and not FORCE:
        return
    img.save(full)
    print("wrote", path)


def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def finish(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


def rrect(d, box, r, fill=None, outline=None, width=0):
    x0, y0, x1, y1 = [v * SS for v in box]
    d.rounded_rectangle([x0, y0, x1, y1], radius=r * SS, fill=fill, outline=outline, width=width * SS)


def panel(path, w, h, radius, fill, edge, edge_w=2, bottom_extra=0):
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    rrect(d, (0, 0, w - 1, h - 1), radius, fill=edge)
    rrect(d, (edge_w, edge_w, w - 1 - edge_w, h - 1 - edge_w - bottom_extra), max(radius - edge_w, 1), fill=fill)
    save(finish(im, w, h), path)


def ring(path, w, h, radius, edge, edge_w):
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    rrect(d, (edge_w / 2, edge_w / 2, w - 1 - edge_w / 2, h - 1 - edge_w / 2), radius, outline=edge, width=edge_w)
    save(finish(im, w, h), path)


def disc(d, c, r, fill=None, outline=None, width=0):
    x, y = c
    d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=fill, outline=outline, width=width * SS)


def poly(d, pts, fill):
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill)


def glyph(path, size, text, col, bg=None, fsize=None):
    im = canvas(size, size)
    d = ImageDraw.Draw(im)
    if bg:
        disc(d, (size / 2, size / 2), size / 2 - 2, fill=bg)
    f = font((fsize or int(size * 0.7)) * SS)
    d.text((size * SS / 2, size * SS / 2), text, font=f, fill=col, anchor="mm")
    save(finish(im, size, size), path)


# ------------------------------------------------------------------ Common
def common():
    panel("Common/panel_card.png", 96, 96, 22, (15, 38, 28, 252), EDGE + (255,), 3)
    panel("Common/panel_hud.png", 64, 64, 14, (13, 33, 26, 224), EDGE + (190,), 2)
    panel("Common/panel_toast.png", 64, 64, 14, (13, 33, 26, 230), EDGE + (200,), 2)
    panel("Common/panel_keycap.png", 32, 32, 6, (242, 230, 191, 255), (140, 115, 77, 255), 1, bottom_extra=2)
    panel("Common/button_normal.png", 64, 64, 14, (43, 102, 64, 255), EDGE + (255,), 2)
    panel("Common/button_hover.png", 64, 64, 14, (61, 133, 82, 255), GOLD + (255,), 2)
    panel("Common/button_pressed.png", 64, 64, 14, (31, 77, 48, 255), GOLD + (255,), 2)
    panel("Common/button_disabled.png", 64, 64, 14, (38, 51, 43, 255), (77, 77, 77, 255), 2)
    ring("Common/button_focus.png", 64, 64, 14, GOLD + (255,), 3)
    panel("Common/slider_track.png", 32, 12, 5, (10, 26, 18, 255), EDGE + (150,), 1)
    panel("Common/slider_fill.png", 32, 12, 5, (89, 179, 107, 255), (89, 179, 107, 255), 0)
    im = canvas(28, 28)
    d = ImageDraw.Draw(im)
    disc(d, (14, 14), 12.5, fill=CREAM + (255,), outline=GOLD + (255,), width=2)
    save(finish(im, 28, 28), "Common/slider_grabber.png")
    im = canvas(28, 28)
    d = ImageDraw.Draw(im)
    disc(d, (14, 14), 12.5, fill=(255, 255, 255, 255), outline=GOLD + (255,), width=2)
    save(finish(im, 28, 28), "Common/slider_grabber_hover.png")


# --------------------------------------------------------------------- HUD
def portrait(path, kind):
    s = 96
    im = canvas(s, s)
    d = ImageDraw.Draw(im)
    disc(d, (48, 48), 46, fill=(31, 77, 51, 255))
    if kind == "mnki":
        disc(d, (48, 78), 26, fill=(217, 38, 38, 255))
        disc(d, (48, 44), 28, fill=(56, 36, 23, 255))
        disc(d, (48, 50), 21, fill=(179, 128, 82, 255))
        disc(d, (38, 46), 4, fill=(26, 15, 10, 255))
        disc(d, (58, 46), 4, fill=(26, 15, 10, 255))
        rrect(d, (26, 28, 70, 35), 3, fill=GOLD + (255,))
    else:
        disc(d, (48, 54), 30, fill=(255, 255, 255, 255))
        poly(d, [(40, 54), (56, 54), (48, 72)], (255, 153, 38, 255))
        disc(d, (39, 46), 4, fill=(26, 20, 15, 255))
        disc(d, (57, 46), 4, fill=(26, 20, 15, 255))
        poly(d, [(38, 28), (44, 18), (48, 26), (52, 18), (58, 28)], GOLD + (255,))
    save(finish(im, s, s), path)


def hud():
    portrait("HUD/portrait_mnki.png", "mnki")
    portrait("HUD/portrait_swan.png", "swan")
    for name, col, w in (("leader", GOLD + (255,), 6), ("follower", (255, 255, 255, 110), 4)):
        im = canvas(96, 96)
        d = ImageDraw.Draw(im)
        disc(d, (48, 48), 46, outline=col, width=w)
        save(finish(im, 96, 96), "HUD/portrait_ring_%s.png" % name)
    im = canvas(34, 34)
    d = ImageDraw.Draw(im)
    disc(d, (17, 17), 15, fill=(0, 0, 0, 90), outline=(255, 255, 255, 70), width=2)
    save(finish(im, 34, 34), "HUD/fruit_slot.png")
    ring("HUD/frame_leader.png", 48, 48, 12, (255, 230, 51, 242), 4)
    ring("HUD/frame_idle.png", 48, 48, 12, (255, 255, 255, 64), 3)
    save(Image.new("RGBA", (6, 64), (5, 8, 8, 255)), "HUD/divider_v.png")
    save(Image.new("RGBA", (64, 6), (5, 8, 8, 255)), "HUD/divider_h.png")
    save(Image.new("RGBA", (2, 32), (255, 255, 255, 38)), "HUD/leader_separator.png")
    panel("HUD/minimap_frame.png", 64, 64, 14, (13, 33, 26, 224), EDGE + (190,), 2)
    for name, col, shape in (("mnki", (255, 64, 64), "disc"), ("swan", (255, 255, 255), "disc"),
                             ("guard", (217, 153, 77), "disc"), ("trap", (242, 51, 38), "sq"),
                             ("apple", (242, 51, 51), "disc"), ("pear", (250, 217, 51), "disc")):
        im = canvas(16, 16)
        d = ImageDraw.Draw(im)
        if shape == "disc":
            disc(d, (8, 8), 7, fill=col + (255,), outline=(0, 0, 0, 140), width=1)
        else:
            rrect(d, (2, 2, 13, 13), 2, fill=col + (255,), outline=(0, 0, 0, 140), width=1)
        save(finish(im, 16, 16), "HUD/minimap_%s.png" % name)


# ------------------------------------------------------------------- Icons
def icons():
    # icon_apple / icon_pear / icon_heart are YOUR art (already in Art/Icons) - only extras are made here.
    im = canvas(128, 128)
    d = ImageDraw.Draw(im)
    for cx, cy, r in ((44, 40, 26), (84, 40, 26)):
        disc(d, (cx, cy), r, fill=(120, 30, 40, 255))
    poly(d, [(20, 52), (108, 52), (64, 112)], (120, 30, 40, 255))
    save(finish(im, 128, 128), "Icons/icon_heart_hurt.png")
    glyph("Icons/icon_clock.png", 128, "T", CREAM + (255,), (60, 110, 80, 255))
    glyph("Icons/icon_trap.png", 128, "X", (255, 255, 255, 255), (200, 50, 40, 255))
    glyph("Icons/icon_walkback.png", 128, "<", CREAM + (255,), (160, 110, 50, 255))
    glyph("Icons/icon_bonk.png", 128, "*", (60, 40, 10, 255), GOLD + (255,), 90)
    glyph("Icons/icon_fruit.png", 128, "F", CREAM + (255,), (60, 110, 80, 255))
    # in-world alert bubbles shown over the teddies
    glyph("Icons/alert_notice.png", 64, "?", GOLD + (255,), (0, 0, 0, 120))
    glyph("Icons/alert_chase.png", 64, "!", (255, 90, 70, 255), (0, 0, 0, 120))
    glyph("Icons/alert_recover.png", 64, "~", (150, 230, 160, 255), (0, 0, 0, 120))
    glyph("Icons/alert_hurt.png", 64, "x", (255, 255, 255, 255), (150, 30, 30, 200))


# ------------------------------------------------------------------- Touch
def touch():
    im = canvas(160, 160)
    d = ImageDraw.Draw(im)
    disc(d, (80, 80), 77, fill=(13, 33, 26, 90), outline=(191, 235, 199, 170), width=4)
    save(finish(im, 160, 160), "Touch/joy_base.png")
    im = canvas(80, 80)
    d = ImageDraw.Draw(im)
    disc(d, (40, 40), 37, fill=(247, 235, 184, 150), outline=(255, 217, 89, 220), width=3)
    save(finish(im, 80, 80), "Touch/joy_knob.png")
    for name, fill, edge in (("btn_round", (43, 102, 64, 158), (140, 217, 153, 217)),
                             ("btn_round_down", (242, 204, 77, 204), (255, 242, 153, 255))):
        im = canvas(128, 128)
        d = ImageDraw.Draw(im)
        disc(d, (64, 64), 61, fill=fill, outline=edge, width=4)
        save(finish(im, 128, 128), "Touch/%s.png" % name)
    im = canvas(64, 64)
    d = ImageDraw.Draw(im)
    rrect(d, (18, 14, 28, 50), 2, fill=CREAM + (255,))
    rrect(d, (36, 14, 46, 50), 2, fill=CREAM + (255,))
    save(finish(im, 64, 64), "Touch/icon_pause.png")


# ----------------------------------------------------------------- Bubbles
BUBBLES = {
    "mnki": ((255, 242, 224), (217, 51, 51)),
    "swan": ((245, 250, 255), (115, 166, 242)),
    "guard": ((250, 235, 199), (153, 97, 46)),
    "tower": ((250, 230, 204), (184, 71, 51)),
}


def bubbles():
    for kind, (fill, edge) in BUBBLES.items():
        panel("Bubbles/bubble_%s.png" % kind, 48, 48, 12, fill + (245,), edge + (255,), 2)
        im = canvas(16, 10)
        d = ImageDraw.Draw(im)
        poly(d, [(0, 0), (16, 0), (8, 10)], edge + (255,))
        poly(d, [(3, 0), (13, 0), (8, 6)], fill + (255,))
        save(finish(im, 16, 10), "Bubbles/bubble_tail_%s.png" % kind)


# ----------------------------------------------------------------- Screens
def ribbon(path, text, col):
    w, h = 420, 110
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    rrect(d, (4, 20, w - 5, h - 20), 18, fill=col + (255,), outline=GOLD + (255,), width=3)
    f = font(46 * SS)
    d.text((w * SS / 2, h * SS / 2), text, font=f, fill=CREAM + (255,), anchor="mm")
    save(finish(im, w, h), path)


def screens():
    ribbon("Screens/banner_pause.png", "PAUSED", (43, 102, 64))
    ribbon("Screens/banner_win.png", "YOU DID IT!", (60, 130, 70))
    ribbon("Screens/banner_lose.png", "OH NO...", (140, 60, 50))
    im = canvas(160, 48)
    d = ImageDraw.Draw(im)
    rrect(d, (2, 2, 157, 45), 20, fill=GOLD + (255,), outline=(255, 255, 255, 255), width=2)
    d.text((80 * SS, 24 * SS), "NEW BEST!", font=font(24 * SS), fill=(80, 50, 5, 255), anchor="mm")
    save(finish(im, 160, 48), "Screens/badge_new_best.png")
    im = canvas(256, 256)
    d = ImageDraw.Draw(im)
    rrect(d, (84, 40, 172, 216), 14, fill=(26, 38, 31, 255), outline=CREAM + (255,), width=5)
    rrect(d, (94, 56, 162, 190), 4, fill=(60, 110, 80, 255))
    disc(d, (128, 203), 6, fill=CREAM + (255,))
    save(finish(im, 256, 256), "Screens/rotate_phone.png")


if __name__ == "__main__":
    common()
    hud()
    icons()
    touch()
    bubbles()
    screens()
    print("done")
