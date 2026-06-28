import math
from PIL import Image, ImageDraw, ImageFilter

S = 4               # supersample factor
W = 256 * S
def px(v): return int(round(v * S))

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# ---- background: vertical green gradient ----
top = (18, 74, 40)      # deep green
bot = (39, 140, 63)     # brighter green
for y in range(W):
    t = y / (W - 1)
    r = int(top[0] + (bot[0]-top[0])*t)
    g = int(top[1] + (bot[1]-top[1])*t)
    b = int(top[2] + (bot[2]-top[2])*t)
    d.line([(0, y), (W, y)], fill=(r, g, b, 255))

# subtle vignette
vig = Image.new("L", (W, W), 0)
vd = ImageDraw.Draw(vig)
vd.ellipse([px(-40), px(-40), px(296), px(296)], fill=40)
vig = vig.filter(ImageFilter.GaussianBlur(px(40)))
img = Image.composite(Image.new("RGBA", (W, W), (0, 0, 0, 255)), img, vig)
d = ImageDraw.Draw(img)

# ---- price-list card (white rounded rectangle) with soft shadow ----
card = [px(46), px(54), px(210), px(214)]
shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle([card[0]+px(6), card[1]+px(10), card[2]+px(6), card[3]+px(10)],
                     radius=px(18), fill=(0, 0, 0, 110))
shadow = shadow.filter(ImageFilter.GaussianBlur(px(8)))
img = Image.alpha_composite(img, shadow)
d = ImageDraw.Draw(img)
d.rounded_rectangle(card, radius=px(18), fill=(247, 249, 250, 255))

# ---- rows: name bar (grey) + price bar (green) ----
rows_y = [px(80), px(112), px(144), px(176)]
name_x = (px(70), px(150))
price_x = (px(162), px(196))
bar_h = px(15)
for i, y in enumerate(rows_y):
    # top row is the "favorited" one: gold name bar to echo the star
    name_fill = (255, 196, 0, 255) if i == 0 else (206, 213, 219, 255)
    d.rounded_rectangle([name_x[0], y, name_x[1], y + bar_h], radius=px(7),
                        fill=name_fill)
    d.rounded_rectangle([price_x[0], y, price_x[1], y + bar_h], radius=px(7),
                        fill=(46, 125, 50, 255))

# ---- gold star badge overlapping the top-left of the card ----
def star_pts(cx, cy, R, r, n=5, rot=-90):
    pts = []
    for k in range(2 * n):
        ang = math.radians(rot + k * 180.0 / n)
        rad = R if k % 2 == 0 else r
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    return pts

scx, scy = px(64), px(64)
R, r = px(46), px(19)

# shadow for star
star_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ss = ImageDraw.Draw(star_shadow)
ss.polygon(star_pts(scx + px(3), scy + px(5), R, r), fill=(0, 0, 0, 130))
star_shadow = star_shadow.filter(ImageFilter.GaussianBlur(px(5)))
img = Image.alpha_composite(img, star_shadow)
d = ImageDraw.Draw(img)

# white outline + gold star
d.polygon(star_pts(scx, scy, R + px(5), r + px(3)), fill=(255, 255, 255, 255))
d.polygon(star_pts(scx, scy, R, r), fill=(255, 196, 0, 255))
# small inner highlight
d.polygon(star_pts(scx - px(4), scy - px(5), px(22), px(9)), fill=(255, 224, 130, 255))

# ---- downscale for antialiasing ----
out = img.resize((256, 256), Image.LANCZOS).convert("RGBA")

import os
HERE = os.path.dirname(os.path.abspath(__file__))   # tools/
ROOT = os.path.dirname(HERE)                          # repo root (mod root)
os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)

dds_path = os.path.join(ROOT, "modIcon.dds")          # the shipped mod icon
preview_path = os.path.join(ROOT, "docs", "icon.png")  # preview for README/docs

out.save(dds_path, "DDS", pixel_format="DXT5")
out.save(preview_path)
print("wrote", dds_path)
print("wrote", preview_path)
