import os
import re
from PIL import Image

src_dir = r'C:\Users\ASUS\project-epic-app\Ipeh-si-manis'
dst_dir = r'C:\Users\ASUS\project-epic-app\epic_app\assets\images\character\ipeh'

# Create destination directory if it doesn't exist
os.makedirs(dst_dir, exist_ok=True)

# Scan and sort PNG files numerically
png_files = []
for f in os.listdir(src_dir):
    if f.lower().endswith('.png'):
        match = re.search(r'(\d+)', f)
        num = int(match.group(1)) if match else 0
        png_files.append((num, f))

png_files.sort(key=lambda x: x[0])

frames = []
print(f"Found {len(png_files)} PNG files in source directory.")
for num, filename in png_files:
    path = os.path.join(src_dir, filename)
    img = Image.open(path).convert("RGBA")
    frames.append(img)

if frames:
    # Save static image (using the first frame)
    static_path = os.path.join(dst_dir, 'character_static.png')
    frames[0].save(static_path)
    print(f"Static PNG saved at {static_path}")

    # Save animated WebP
    # 50 fps -> 20 ms per frame
    out_path = os.path.join(dst_dir, 'character_animated.webp')
    
    # Remove old file if it exists
    if os.path.exists(out_path):
        os.remove(out_path)
        
    print("Saving Animated WebP. This might take a minute...")
    frames[0].save(
        out_path,
        format='WEBP',
        save_all=True,
        append_images=frames[1:],
        duration=20, # 50 fps
        loop=0, # loop forever
        lossless=False,
        quality=80,
        method=4
    )
    print(f"Animated WebP saved successfully at {out_path} with {len(frames)} frames.")
else:
    print("Error: No frames were loaded. Check the source directory.")
