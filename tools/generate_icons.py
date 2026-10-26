"""Render Wallfree's original SVG mark into desktop icon formats.

Requires Pillow. Run from the repository root with `python3 tools/generate_icons.py`.
The paths below mirror assets/brand/wallfree-icon.svg.
"""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SCALE = 3
SIZE = 1024
S = SIZE * SCALE


def pt(x: float, y: float) -> tuple[float, float]:
    return x * SCALE, y * SCALE


def cubic(p0, p1, p2, p3, steps=40):
    points = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        points.append(pt(x, y))
    return points


def gradient(top, bottom):
    image = Image.new("RGBA", (S, S))
    draw = ImageDraw.Draw(image)
    for y in range(S):
        t = y / (S - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,)
        draw.line((0, y, S, y), fill=color)
    return image


def curve_shape(draw, start, segments, color, tail):
    coords = [pt(*start)]
    current = start
    for c1, c2, end in segments:
        coords.extend(cubic(current, c1, c2, end))
        current = end
    coords.extend(pt(x, y) for x, y in tail)
    draw.polygon(coords, fill=color)


def render():
    image = gradient((43, 48, 50), (21, 25, 28))
    shell_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shell_mask).rounded_rectangle((0, 0, S - 1, S - 1), radius=220 * SCALE, fill=255)
    image.putalpha(shell_mask)
    draw = ImageDraw.Draw(image)

    draw.rounded_rectangle(
        (150 * SCALE, 150 * SCALE, 874 * SCALE, 874 * SCALE),
        radius=176 * SCALE,
        fill="#e4edd8",
    )
    sky_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(sky_mask).rounded_rectangle(
        (210 * SCALE, 210 * SCALE, 814 * SCALE, 814 * SCALE),
        radius=126 * SCALE,
        fill=255,
    )
    sky = gradient((41, 67, 63), (28, 48, 47))
    image.paste(sky, (0, 0), sky_mask)
    draw = ImageDraw.Draw(image)

    draw.ellipse((590 * SCALE, 318 * SCALE, 742 * SCALE, 470 * SCALE), fill="#d6f078")

    curve_shape(
        draw,
        (210, 650),
        [((315, 562), (441, 528), (560, 640)), ((650, 544), (733, 526), (814, 585))],
        "#41685a",
        [(814, 814), (210, 814)],
    )
    draw.polygon(
        [pt(210, 636), *cubic((210, 636), (304, 613), (380, 659), (451, 814)), pt(210, 814)],
        fill="#c1e987",
    )
    draw.polygon(
        [pt(407, 814), *cubic((407, 814), (510, 686), (647, 636), (814, 681)), pt(814, 814)],
        fill="#83b96a",
    )

    image = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    brand = ROOT / "assets" / "brand"
    brand.mkdir(parents=True, exist_ok=True)
    image.save(brand / "wallfree-icon.png", optimize=True)

    app_icon_dir = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for pixels in (16, 32, 64, 128, 256, 512, 1024):
        image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(
            app_icon_dir / f"app_icon_{pixels}.png", optimize=True
        )

    image.save(
        ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


if __name__ == "__main__":
    render()
