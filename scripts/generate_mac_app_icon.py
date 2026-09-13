#!/usr/bin/env python3
import os
import shutil
import numpy as np
from PIL import Image

def generate():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.dirname(script_dir)
    logo_path = os.path.join(root_dir, "Resources", "AppLogo.png")
    out_icns = os.path.join(root_dir, "Resources", "AppIcon.icns")
    iconset_dir = "/tmp/MinaFlow.iconset"

    if os.path.exists(iconset_dir):
        shutil.rmtree(iconset_dir)
    os.makedirs(iconset_dir, exist_ok=True)

    logo = Image.open(logo_path).convert("RGBA")
    
    # Fill the 4 transparent corners with the logo's orange gradient so the image is 100% opaque.
    # Apple's HIG rule: When an icon has transparent corners, macOS renders a dark squircle backing tile underneath it.
    # By making the icon a full-bleed opaque square, macOS clips the corners to its own squircle mask without any dark container backing!
    top_color = np.array([250, 135, 30], dtype=float)
    bot_color = np.array([253, 60, 0], dtype=float)
    grad = np.zeros((1024, 1024, 3), dtype=np.uint8)
    for y in range(1024):
        ratio = y / 1023.0
        color = (1.0 - ratio) * top_color + ratio * bot_color
        grad[y, :] = color.astype(np.uint8)

    grad_img = Image.fromarray(grad, "RGB").convert("RGBA")
    solid_logo = Image.alpha_composite(grad_img, logo)

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png")
    ]

    for s, name in sizes:
        scaled = solid_logo.resize((s, s), Image.Resampling.LANCZOS)
        scaled.save(os.path.join(iconset_dir, name), "PNG")

    res = os.system(f"iconutil -c icns '{iconset_dir}' -o '{out_icns}'")
    if res == 0:
        print(f"Successfully generated macOS AppIcon.icns without transparent corners at {out_icns}")
    else:
        print(f"Failed to generate icns, exit code {res}")

if __name__ == "__main__":
    generate()
