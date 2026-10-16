"""Builds the native splash sources in mobile/assets/splash/ from shared/brand.

Usage: python mobile/tool/gen_splash.py <repo root>
then: cd mobile && dart run flutter_native_splash:create
"""
import sys
from pathlib import Path
import pymupdf
from PIL import Image

root = Path(sys.argv[1])
brand = root / 'shared' / 'brand'
out = root / 'mobile' / 'assets' / 'splash'
out.mkdir(parents=True, exist_ok=True)
mark = Image.open(brand / 'png' / 'logo-mark-1024.png').convert('RGBA')

# Android 12+: 1152x1152 canvas, icon must fit the 768 px circle. A 560 px
# rounded square (rx 20%) reaches 0.624*560 = 349 px from centre < 384.
a12 = Image.new('RGBA', (1152, 1152), (0, 0, 0, 0))
m = mark.resize((560, 560), Image.LANCZOS)
a12.alpha_composite(m, (296, 296))
a12.save(out / 'splash_icon_android12.png', optimize=True)

# Pre-12 Android and iOS: the image is taken as 4x, so 560 px = 140 pt/dp,
# the same visible size as the Android 12 icon.
m.save(out / 'splash_icon.png', optimize=True)

svg = (brand / 'wordmark.svg').read_text(encoding='utf-8')
def wordmark(color, name, width=600):
    doc = pymupdf.open(stream=svg.replace('currentColor', color).encode(), filetype='svg')
    page = doc[0]
    scale = width * 4 / page.rect.width  # supersample, then downscale
    pix = page.get_pixmap(matrix=pymupdf.Matrix(scale, scale), alpha=True)
    img = Image.frombytes('RGBA', (pix.width, pix.height), pix.samples)
    img = img.resize((width, round(pix.height * width / pix.width)), Image.LANCZOS)
    bbox = img.getbbox(); img = img.crop(bbox)
    # Android 12 requires 800x320 branding; centre the wordmark in it.
    canvas = Image.new('RGBA', (800, 320), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((800 - img.width) // 2, (320 - img.height) // 2))
    canvas.save(out / name, optimize=True)
    print(name, img.size)

wordmark('#1F2937', 'branding.png')
wordmark('#F5F0E0', 'branding_dark.png')
