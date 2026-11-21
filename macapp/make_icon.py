"""Generate AppIcon.icns for the native macOS app (requires Pillow)."""
import os
import subprocess
from PIL import Image, ImageDraw

# IMGTOPDF_BUILD lets build_macos.sh redirect artefacts when the repository is
# built from a different working root (for example a fresh GitHub checkout).
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUILD = os.environ.get("IMGTOPDF_BUILD") or os.path.join(ROOT, ".build")
SET = os.path.join(BUILD, "AppIcon.iconset")
OUT = os.path.join(BUILD, "AppIcon.icns")
os.makedirs(SET, exist_ok=True)

S = 1024
canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bd = ImageDraw.Draw(bg)
for y in range(S):
    t = y / S
    bd.line([(0, y), (S, y)], fill=(int(40 + 22 * t), int(104 + 46 * t), int(224 - 26 * t), 255))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((56, 56, S - 56, S - 56), radius=214, fill=255)
canvas.paste(bg, (0, 0), mask)

d = ImageDraw.Draw(canvas)
d.rounded_rectangle((248, 176, 744, 842), radius=54, fill=(0, 0, 0, 55))
d.rounded_rectangle((238, 158, 734, 824), radius=54, fill=(255, 255, 255, 255))
d.polygon([(600, 158), (734, 158), (734, 292)], fill=(214, 226, 248, 255))
d.polygon([(600, 158), (600, 226), (668, 292), (734, 292), (600, 158)], fill=(238, 243, 253, 255))
d.rounded_rectangle((292, 300, 680, 600), radius=24, fill=(226, 238, 252, 255))
d.ellipse((588, 336, 646, 394), fill=(255, 196, 74, 255))
d.polygon([(292, 560), (424, 412), (520, 516), (578, 452), (680, 560), (680, 600), (292, 600)],
          fill=(86, 158, 232, 255))
d.polygon([(292, 586), (392, 476), (486, 574), (540, 520), (680, 586), (680, 600), (292, 600)],
          fill=(52, 122, 206, 255))
d.rounded_rectangle((292, 646, 596, 670), radius=10, fill=(198, 211, 232, 255))
d.rounded_rectangle((292, 692, 528, 716), radius=10, fill=(214, 224, 240, 255))
d.rounded_rectangle((596, 620, 826, 826), radius=38, fill=(255, 183, 52, 255))
d.arc((642, 556, 780, 700), 180, 360, fill=(255, 255, 255, 255), width=30)
d.ellipse((684, 690, 738, 744), fill=(255, 255, 255, 255))
d.rounded_rectangle((702, 722, 720, 782), radius=9, fill=(255, 255, 255, 255))

for size, scale, suffix in [
    (16, 1, ""), (16, 2, "@2x"), (32, 1, ""), (32, 2, "@2x"),
    (128, 1, ""), (128, 2, "@2x"), (256, 1, ""), (256, 2, "@2x"),
    (512, 1, ""), (512, 2, "@2x"),
]:
    px = size * scale
    canvas.resize((px, px), Image.LANCZOS).save(os.path.join(SET, f"icon_{size}x{size}{suffix}.png"))

subprocess.run(["iconutil", "-c", "icns", SET, "-o", OUT], check=True)
print("wrote", OUT, os.path.getsize(OUT), "bytes")
