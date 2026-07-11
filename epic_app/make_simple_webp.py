import os
from PIL import Image

src_dir = r'C:\Users\ASUS\project-epic-app\aset_karakter_1'
dst_dir = r'C:\Users\ASUS\project-epic-app\epic_app\assets\images\character\default'

frames = []
# There are 300 frames
for i in range(1, 301):
    path = os.path.join(src_dir, f'{i:04d}.png')
    if os.path.exists(path):
        img = Image.open(path).convert("RGBA")
        frames.append(img)

if frames:
    print(f"Total sequence length: {len(frames)} frames")
    out_path = os.path.join(dst_dir, 'character_animated.webp')
    
    # Remove the old file if it exists
    if os.path.exists(out_path):
        os.remove(out_path)
        
    print("Saving Animated WebP. This might take a minute...")
    frames[0].save(
        out_path,
        format='WEBP',
        save_all=True,
        append_images=frames[1:],
        duration=20, # 50 fps
        loop=0,
        lossless=False,
        quality=80,
        method=4
    )
    print(f"Successfully saved to {out_path}!")
else:
    print("Error: No frames were loaded. Check the source directory.")
