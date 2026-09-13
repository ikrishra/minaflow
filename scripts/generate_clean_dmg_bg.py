from PIL import Image, ImageDraw, ImageFont
import os

width = 660
height = 400

# Create clean, modern Apple-style light background (#F8FAFC)
img = Image.new('RGB', (width, height), color=(248, 250, 252))
draw = ImageDraw.Draw(img)

# Try to load high-quality system fonts
font_title = None
font_sub = None

for font_path in [
    "/System/Library/Fonts/SFPro-Semibold.otf",
    "/System/Library/Fonts/SFPro-Medium.otf",
    "/System/Library/Fonts/SFNSText.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/Library/Fonts/Arial.ttf"
]:
    if os.path.exists(font_path):
        try:
            font_title = ImageFont.truetype(font_path, 17)
            font_sub = ImageFont.truetype(font_path, 11)
            break
        except Exception:
            continue

if font_title is None:
    font_title = ImageFont.load_default()
    font_sub = ImageFont.load_default()

# 1. Top Title (High contrast deep slate #0F172A)
title = "Drag MinaFlow to Applications to install"
bbox = draw.textbbox((0, 0), title, font=font_title)
tw = bbox[2] - bbox[0]
draw.text(((width - tw) // 2, 45), title, fill=(15, 23, 42), font=font_title)

# 2. Sleek MinaFlow Orange Arrow between icons
# MinaFlow icon is at (180, 190), Applications link is at (480, 190)
arrow_y = 190
x_start = 280
x_end = 380
brand_orange = (255, 85, 0) # #FF5500

# Arrow shaft
draw.line([(x_start, arrow_y), (x_end, arrow_y)], fill=brand_orange, width=4)

# Arrow head
draw.polygon([
    (x_end + 2, arrow_y),
    (x_end - 14, arrow_y - 9),
    (x_end - 9, arrow_y),
    (x_end - 14, arrow_y + 9)
], fill=brand_orange)

out_path = "/Users/krishna/Desktop/Bunty/minatype/Resources/dmg-background.png"
img.save(out_path, dpi=(72, 72))
print("Saved light-mode 660x400 DMG background to", out_path)
