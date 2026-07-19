#!/usr/bin/env python3
"""Compose App Store marketing screenshots: caption above, real device shot below,
on a brand gradient, exported at 6.9" (1290x2796) and 6.5" (1242x2688)."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SRC = "/private/tmp/claude-501/-Users-josiahrininger-Developer/413638bf-d8b1-4f3a-9e74-89f74f4b8580/scratchpad"
OUT = "/Users/josiahrininger/Developer/BMI/BMICalculator/Screenshots/appstore"

# (source capture, headline, subhead)
SHOTS = [
    ("cap_calc.png",        "Know your BMI in seconds",
     "Enter your height and weight for a clear, color-coded result."),
    ("cap_history.png",     "Track your trend over time",
     "Every result is saved privately so you can watch your progress."),
    ("cap_result_over.png", "Every result, explained",
     "Plain-language categories and your healthy range. Never judgmental."),
    ("cap_settings.png",    "Made to fit you",
     "Metric, imperial, or stone. Universal or Asian standards. 100% private."),
]

SIZES = {"6.9": (1290, 2796), "6.5": (1242, 2688)}

# Brand palette (app brand blue #19BEF4)
BG_TOP = (206, 238, 251)      # soft brand-blue tint
BG_BOT = (240, 249, 254)      # near white
HEAD_COLOR = (14, 42, 59)     # dark navy
SUB_COLOR = (90, 115, 130)    # muted slate
BEZEL = (13, 15, 18)          # near-black device frame

def find_font(bold):
    cands_bold = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica.ttc",
    ]
    cands_reg = [
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for p in (cands_bold if bold else cands_reg):
        if os.path.exists(p):
            return p
    return None

BOLD = find_font(True)
REG = find_font(False)

def font(bold, size):
    p = BOLD if bold else REG
    return ImageFont.truetype(p, size)

def gradient(w, h):
    base = Image.new("RGB", (w, h))
    px = base.load()
    for y in range(h):
        t = y / (h - 1)
        r = int(BG_TOP[0] + (BG_BOT[0] - BG_TOP[0]) * t)
        g = int(BG_TOP[1] + (BG_BOT[1] - BG_TOP[1]) * t)
        b = int(BG_TOP[2] + (BG_BOT[2] - BG_TOP[2]) * t)
        for x in range(w):
            px[x, y] = (r, g, b)
    return base

def wrap(draw, text, fnt, max_w):
    words = text.split()
    lines, cur = [], ""
    for wd in words:
        trial = (cur + " " + wd).strip()
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = wd
    if cur:
        lines.append(cur)
    return lines

def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m

def compose(src, headline, sub, W, H):
    canvas = gradient(W, H)
    draw = ImageDraw.Draw(canvas)

    # --- Caption ---
    head_f = font(True, int(H * 0.0285))
    sub_f = font(False, int(H * 0.0158))
    top_pad = int(H * 0.055)
    max_text_w = int(W * 0.86)

    head_lines = wrap(draw, headline, head_f, max_text_w)
    sub_lines = wrap(draw, sub, sub_f, max_text_w)

    y = top_pad
    hl_h = (head_f.getbbox("Ag")[3] - head_f.getbbox("Ag")[1])
    for ln in head_lines:
        tw = draw.textlength(ln, font=head_f)
        draw.text(((W - tw) / 2, y), ln, font=head_f, fill=HEAD_COLOR)
        y += int(hl_h * 1.18)
    y += int(H * 0.006)
    sl_h = (sub_f.getbbox("Ag")[3] - sub_f.getbbox("Ag")[1])
    for ln in sub_lines:
        tw = draw.textlength(ln, font=sub_f)
        draw.text(((W - tw) / 2, y), ln, font=sub_f, fill=SUB_COLOR)
        y += int(sl_h * 1.30)

    caption_bottom = y + int(H * 0.02)

    # --- Device ---
    shot = Image.open(os.path.join(SRC, src)).convert("RGB")
    sw, sh = shot.size  # 1320 x 2868
    bottom_margin = int(H * 0.045)
    avail_h = H - caption_bottom - bottom_margin
    phone_w = min(int(W * 0.74), int(avail_h * sw / sh))
    phone_h = int(phone_w * sh / sw)

    # rounded screenshot
    radius = int(phone_w * 0.085)
    shot_r = shot.resize((phone_w, phone_h), Image.LANCZOS)
    mask = rounded_mask((phone_w, phone_h), radius)

    bezel_t = max(6, int(W * 0.011))
    bez_w, bez_h = phone_w + bezel_t * 2, phone_h + bezel_t * 2
    bez_radius = radius + bezel_t
    bezel_img = Image.new("RGBA", (bez_w, bez_h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bezel_img)
    bd.rounded_rectangle([0, 0, bez_w - 1, bez_h - 1], radius=bez_radius, fill=BEZEL + (255,))

    px_x = (W - phone_w) // 2
    px_y = caption_bottom + (avail_h - phone_h) // 2
    bez_x, bez_y = px_x - bezel_t, px_y - bezel_t

    # shadow
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        [bez_x, bez_y + int(H * 0.006), bez_x + bez_w, bez_y + bez_h + int(H * 0.006)],
        radius=bez_radius, fill=(10, 30, 50, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(W * 0.02)))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)

    canvas.paste(bezel_img, (bez_x, bez_y), bezel_img)
    canvas.paste(shot_r, (px_x, px_y), mask)
    return canvas.convert("RGB")

def main():
    for label, (W, H) in SIZES.items():
        d = os.path.join(OUT, label)
        os.makedirs(d, exist_ok=True)
        for i, (src, head, sub) in enumerate(SHOTS, 1):
            img = compose(src, head, sub, W, H)
            out = os.path.join(d, f"{i:02d}_{src.replace('cap_','').replace('.png','')}_{label}.png")
            img.save(out, "PNG")
            print("wrote", out, img.size)

if __name__ == "__main__":
    print("bold font:", BOLD)
    print("reg font:", REG)
    main()
