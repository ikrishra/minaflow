#!/usr/bin/env python3
import os
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, radius):
    # Supersampled mask for super-smooth anti-aliasing
    scale = 4
    w, h = size[0] * scale, size[1] * scale
    r = radius * scale
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (w, h)], radius=r, fill=255)
    return mask.resize(size, Image.Resampling.LANCZOS)

def generate_macos_icon():
    source_path = "Resources/AppLogo.png"
    if not os.path.exists(source_path):
        source_path = "website/public/logo.png"
    
    logo = Image.open(source_path).convert("RGBA")
    
    # 1024x1024 canvas
    canvas_size = (1024, 1024)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    
    # Standard macOS Big Sur+ Icon Grid:
    # 824x824 body centered horizontally at x=100, y=94, with room for drop shadow at bottom
    body_w, body_h = 824, 824
    body_x, body_y = 100, 94
    corner_radius = 185
    
    # Resize logo to cover 824x824 body
    logo_resized = logo.resize((body_w, body_h), Image.Resampling.LANCZOS)
    
    # Create squircle mask
    mask = create_squircle_mask((body_w, body_h), corner_radius)
    
    # Apply mask to logo
    logo_squircle = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))
    logo_squircle.paste(logo_resized, (0, 0), mask)
    
    # Create soft drop shadow
    shadow_layer = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    shadow_mask = create_squircle_mask((body_w, body_h), corner_radius)
    # Shadow color: subtle dark shadow typical of macOS icons
    shadow_solid = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 90))
    shadow_shape = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))
    shadow_shape.paste(shadow_solid, (0, 0), shadow_mask)
    
    # Paste shadow with slight downward offset
    shadow_offset_y = body_y + 14
    shadow_layer.paste(shadow_shape, (body_x, shadow_offset_y), shadow_shape)
    # Blur shadow
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=20))
    
    # Composite: Canvas -> Shadow -> Logo Squircle
    canvas.paste(shadow_layer, (0, 0), shadow_layer)
    canvas.paste(logo_squircle, (body_x, body_y), logo_squircle)
    
    # Ensure iconset directory
    iconset_dir = "/tmp/MinaFlow_AppIcon.iconset"
    if os.path.exists(iconset_dir):
        shutil.rmtree(iconset_dir)
    os.makedirs(iconset_dir)
    
    # Icon sizes required by macOS iconutil
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
        (1024, "icon_512x512@2x.png"),
    ]
    
    for dim, filename in sizes:
        resized = canvas.resize((dim, dim), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename), "PNG")
        
    # Run iconutil to compile into AppIcon.icns
    target_icns = "Resources/AppIcon.icns"
    cmd = ["iconutil", "-c", "icns", iconset_dir, "-o", target_icns]
    print("Running:", " ".join(cmd))
    res = subprocess.run(cmd, check=True)
    
    print("Successfully generated macOS squircle icon at:", target_icns)

if __name__ == "__main__":
    generate_macos_icon()
