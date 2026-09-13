#!/usr/bin/env python3
import os
import sys
import time
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

def generate_background_images():
    os.makedirs("Resources", exist_ok=True)
    
    # 1x: 660x400
    # 2x: 1320x800
    for scale, suffix in [(1, ""), (2, "@2x")]:
        w = 660 * scale
        h = 400 * scale
        img = Image.new('RGB', (w, h), color=(248, 250, 252)) # Clean Apple Light Slate
        draw = ImageDraw.Draw(img)
        
        # Title font
        font_title = None
        for font_path in [
            "/System/Library/Fonts/SFPro-Semibold.otf",
            "/System/Library/Fonts/SFPro-Medium.otf",
            "/System/Library/Fonts/SFNSText.ttf",
            "/System/Library/Fonts/HelveticaNeue.ttc",
            "/Library/Fonts/Arial.ttf"
        ]:
            if os.path.exists(font_path):
                try:
                    font_title = ImageFont.truetype(font_path, 17 * scale)
                    break
                except Exception:
                    continue
        if font_title is None:
            font_title = ImageFont.load_default()
            
        # Top instructional text
        title = "Drag MinaFlow to Applications to install"
        bbox = draw.textbbox((0, 0), title, font=font_title)
        tw = bbox[2] - bbox[0]
        draw.text(((w - tw) // 2, 44 * scale), title, fill=(15, 23, 42), font=font_title)
        
        # Sleek orange connector arrow
        arrow_y = 190 * scale
        x_start = 280 * scale
        x_end = 380 * scale
        brand_orange = (255, 85, 0)
        
        draw.line([(x_start, arrow_y), (x_end, arrow_y)], fill=brand_orange, width=4 * scale)
        draw.polygon([
            (x_end + 2 * scale, arrow_y),
            (x_end - 14 * scale, arrow_y - 9 * scale),
            (x_end - 9 * scale, arrow_y),
            (x_end - 14 * scale, arrow_y + 9 * scale)
        ], fill=brand_orange)
        
        out_path = f"Resources/dmg-background{suffix}.png"
        img.save(out_path, dpi=(72 * scale, 72 * scale))
        print(f"Generated {out_path} ({w}x{h})")

def build_custom_dmg(app_bundle="MinaFlow.app", output_dmg="MinaFlow.dmg", identity="Developer ID Application: Krishna Rathore (HK3P3D695Z)"):
    if not os.path.exists(app_bundle):
        print(f"Error: {app_bundle} not found!")
        sys.exit(1)
        
    generate_background_images()
    
    vol_name = "MinaFlow"
    tmp_dmg = "/tmp/minaflow_rw.dmg"
    mount_point = "/Volumes/MinaFlow"
    
    # Clean up previous artifacts
    for p in [tmp_dmg, output_dmg]:
        if os.path.exists(p):
            try: os.remove(p)
            except: pass
            
    # Unmount if currently mounted
    if os.path.exists(mount_point):
        subprocess.run(["hdiutil", "detach", mount_point, "-force"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1)
        
    print("1. Creating writable temporary disk image...")
    # Calculate size of app bundle + padding
    app_size_mb = int(subprocess.check_output(["du", "-sm", app_bundle]).split()[0].decode()) + 40
    subprocess.run(["hdiutil", "create", "-size", f"{app_size_mb}m", "-fs", "HFS+", "-volname", vol_name, tmp_dmg, "-ov"], check=True)
    
    print("2. Mounting temporary disk image...")
    subprocess.run(["hdiutil", "attach", tmp_dmg, "-mountpoint", mount_point, "-nobrowse"], check=True)
    time.sleep(1)
    
    try:
        print("3. Copying MinaFlow.app and background assets...")
        dest_app = os.path.join(mount_point, os.path.basename(app_bundle))
        subprocess.run(["cp", "-R", app_bundle, dest_app], check=True)
        
        # Symlink to /Applications
        app_symlink = os.path.join(mount_point, "Applications")
        if os.path.exists(app_symlink): os.remove(app_symlink)
        os.symlink("/Applications", app_symlink)
        
        # Background folder
        bg_dir = os.path.join(mount_point, ".background")
        os.makedirs(bg_dir, exist_ok=True)
        shutil.copy("Resources/dmg-background.png", os.path.join(bg_dir, "dmg-background.png"))
        shutil.copy("Resources/dmg-background@2x.png", os.path.join(bg_dir, "dmg-background@2x.png"))
        
        # Volume Icon
        if os.path.exists("Resources/AppIcon.icns"):
            vol_icon = os.path.join(mount_point, ".VolumeIcon.icns")
            shutil.copy("Resources/AppIcon.icns", vol_icon)
            subprocess.run(["SetFile", "-c", "icnC", vol_icon], check=False)
            subprocess.run(["SetFile", "-a", "C", mount_point], check=False)
            
        print("4. Applying Finder view preferences and drag-and-drop icon positions...")
        applescript = f'''
        tell application "Finder"
            tell disk "{vol_name}"
                open
                set theView to container window
                tell theView
                    set current view to icon view
                    set toolbar visible to false
                    set statusbar visible to false
                    set the bounds to {{200, 120, 860, 520}}
                end tell
                
                set opts to icon view options of theView
                tell opts
                    set icon size to 120
                    set text size to 12
                    set arrangement to not arranged
                    try
                        set background picture to (POSIX file "{mount_point}/.background/dmg-background.png" as alias)
                    end try
                end tell
                
                try
                    set position of item "{os.path.basename(app_bundle)}" of theView to {{180, 190}}
                end try
                try
                    set position of item "Applications" of theView to {{480, 190}}
                end try
                
                close
                open
                update without registering applications
                delay 2
            end tell
        end tell
        '''
        res = subprocess.run(["osascript", "-e", applescript], check=False)
        time.sleep(2)
        
        # Hide .background folder
        subprocess.run(["SetFile", "-a", "V", bg_dir], check=False)
        
    finally:
        print("5. Unmounting temporary disk image...")
        subprocess.run(["hdiutil", "detach", mount_point, "-force"], check=True)
        time.sleep(2)
        
    print("6. Converting to compressed read-only DMG...")
    subprocess.run(["hdiutil", "convert", tmp_dmg, "-format", "UDZO", "-imagekey", "zlib-level=9", "-o", output_dmg, "-ov"], check=True)
    if os.path.exists(tmp_dmg):
        os.remove(tmp_dmg)
        
    print(f"7. Signing {output_dmg} with {identity}...")
    subprocess.run(["codesign", "--force", "--sign", identity, output_dmg], check=True)
    
    print(f"DMG generation complete: {output_dmg}")

if __name__ == "__main__":
    app = "MinaFlow.app"
    out = "MinaFlow.dmg"
    ident = os.environ.get("IDENTITY", "-")
    build_custom_dmg(app, out, ident)
