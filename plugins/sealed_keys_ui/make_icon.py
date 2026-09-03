#!/usr/bin/env python3
"""Generate the Sealed icon (256x256 PNG): a redacted document under a wax seal."""
from PIL import Image, ImageDraw
import os

S = 256
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Rounded dark ground.
d.rounded_rectangle([8, 8, S - 8, S - 8], radius=40, fill=(11, 13, 18, 255))

# Cream "document" inset.
pad, top = 44, 40
d.rounded_rectangle([pad, top, S - pad, S - 36], radius=10, fill=(243, 239, 228, 255))

# Black redaction bars over the document lines.
import random
random.seed(7)
y = top + 22
x0, xw = pad + 16, (S - pad) - (pad + 16)
for _ in range(6):
    w = int(xw * (0.45 + random.random() * 0.5))
    d.rounded_rectangle([x0, y, x0 + w, y + 12], radius=3, fill=(17, 19, 24, 255))
    y += 22
    if y > S - 70:
        break

# Wax seal: red disc with a darker ring, lower-right.
cx, cy, r = S - 78, S - 78, 34
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(181, 48, 58, 255))
d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(120, 28, 36, 255), width=4)
# inner emboss ring
d.ellipse([cx - r + 10, cy - r + 10, cx + r - 10, cy + r - 10], outline=(150, 36, 44, 255), width=3)

out = os.path.join(os.path.dirname(__file__), "icons", "sealed.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
img.save(out, "PNG")
print("wrote", out, img.size)
