"""Generates the desktop app icons from assets/icon/app_icon.png.

    python tool/gen_desktop_icons.py   (from mobile/, needs Pillow)

Writes windows/runner/resources/app_icon.ico (16-256 px, rounded corners),
the macOS AppIcon.appiconset PNGs (Big Sur style: rounded square inset on a
transparent canvas) and linux/runner/app_icon.png.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "icon" / "app_icon.png"


def rounded(img: Image.Image, radius_fraction: float) -> Image.Image:
    """[img] with transparent rounded corners."""
    size = img.size[0]
    scale = 4  # supersampled mask for smooth edges
    mask = Image.new("L", (size * scale, size * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * scale - 1, size * scale - 1), radius=int(size * scale * radius_fraction), fill=255
    )
    out = img.convert("RGBA")
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def main() -> None:
    src = Image.open(SOURCE).convert("RGBA")

    # Windows: one .ico holding every size the shell asks for.
    win = rounded(src, 0.18)
    ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    win.save(ico, sizes=[(s, s) for s in (16, 20, 24, 32, 40, 48, 64, 128, 256)])

    # macOS: 824/1024 rounded square centred on a transparent canvas.
    body = rounded(src.resize((824, 824), Image.LANCZOS), 0.225)
    mac = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    mac.paste(body, (100, 100), body)
    iconset = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for s in (16, 32, 64, 128, 256, 512, 1024):
        mac.resize((s, s), Image.LANCZOS).save(iconset / f"app_icon_{s}.png")

    # Linux: the window icon set by the GTK runner.
    rounded(src.resize((256, 256), Image.LANCZOS), 0.18).save(ROOT / "linux" / "runner" / "app_icon.png")


if __name__ == "__main__":
    main()
