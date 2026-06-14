"""Generate the Daily Loop app icon (1024x1024, no alpha).

Concept: a glowing cyclic loop-arrow (violet->gold) with a gap + arrowhead to
imply continuous motion, and four colored nodes around it for the four
reflection stages (Win, Mistake, Lesson, Adjustment). Dark premium background.
"""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 2048  # supersample, downscale to 1024 at the end
cx = cy = S / 2


def vgrad(size, top, bot):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        d.line(
            [(0, y), (size, y)],
            fill=(
                int(top[0] + (bot[0] - top[0]) * t),
                int(top[1] + (bot[1] - top[1]) * t),
                int(top[2] + (bot[2] - top[2]) * t),
            ),
        )
    return img


# Background: deep violet-black gradient
img = vgrad(S, (22, 15, 44), (6, 6, 9))
d = ImageDraw.Draw(img)

R = S * 0.29
w = int(S * 0.078)
bbox = [cx - R, cy - R, cx + R, cy + R]
sa, ea = -60, 240  # 300-degree arc, gap centered at the top (270 deg)

# Soft violet glow behind the ring
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).arc(bbox, sa, ea, fill=(126, 91, 239, 255), width=w + 30)
glow = glow.filter(ImageFilter.GaussianBlur(55))
img.paste(Image.new("RGB", (S, S), (126, 91, 239)),
          (0, 0), glow.split()[3].point(lambda a: int(a * 0.45)))

# Gradient ring (violet -> gold) through an arc mask
grad = vgrad(S, (150, 116, 255), (255, 200, 61))
mask = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(mask)
md.arc(bbox, sa, ea, fill=255, width=w)
# Rounded cap on the tail end only (the head gets an arrowhead).
ptx = cx + R * math.cos(math.radians(sa))
pty = cy + R * math.sin(math.radians(sa))
md.ellipse([ptx - w / 2, pty - w / 2, ptx + w / 2, pty + w / 2], fill=255)
img.paste(grad, (0, 0), mask)

# Arrowhead at the leading (clockwise) end, pointing toward the gap
a = ea
px = cx + R * math.cos(math.radians(a))
py = cy + R * math.sin(math.radians(a))
tx, ty = -math.sin(math.radians(a)), math.cos(math.radians(a))  # clockwise tangent
nx, ny = math.cos(math.radians(a)), math.sin(math.radians(a))   # outward normal
L = w * 1.15
base = px + tx * (w * 0.15), py + ty * (w * 0.15)
d.polygon(
    [(px + tx * L, py + ty * L),
     (base[0] + nx * w * 0.95, base[1] + ny * w * 0.95),
     (base[0] - nx * w * 0.95, base[1] - ny * w * 0.95)],
    fill=(255, 200, 61),
)

# Four stage nodes around the loop (Win/Mistake/Lesson/Adjustment accents)
nodes = [
    (-30, (52, 199, 89)),    # green
    (60, (255, 159, 10)),    # orange
    (150, (90, 200, 250)),   # blue
    (210, (175, 140, 255)),  # violet
]
for a, col in nodes:
    px = cx + R * math.cos(math.radians(a))
    py = cy + R * math.sin(math.radians(a))
    rr = w * 0.52
    d.ellipse([px - rr, py - rr, px + rr, py + rr],
              fill=col, outline=(10, 9, 14), width=int(S * 0.007))

out = img.resize((1024, 1024), Image.LANCZOS).convert("RGB")  # RGB = no alpha
out.save(
    __import__("os").path.join(__import__("os").path.dirname(__file__),
                               "..", "Resources", "Assets.xcassets",
                               "AppIcon.appiconset", "icon-1024.png"),
    "PNG",
)
print("icon written")
