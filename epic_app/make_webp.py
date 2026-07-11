import os
from PIL import Image

src_dir = r'C:\Users\ASUS\project-epic-app\aset-epic-karakter1'
dst_dir = r'C:\Users\ASUS\project-epic-app\epic_app\assets\images\character\default'

frames = []
for i in range(1, 251):
    path = os.path.join(src_dir, f'{i:04d}.png')
    if os.path.exists(path):
        img = Image.open(path).convert("RGBA")
        frames.append(img)

if frames:
    # Save as animated WebP
    # 30 fps -> 1000/30 ms per frame = ~33 ms
    out_path = os.path.join(dst_dir, 'character_animated.webp')
    frames[0].save(
        out_path,
        format='WEBP',
        save_all=True,
        append_images=frames[1:],
        duration=33, # duration for each frame in milliseconds
        loop=0, # 0 means infinite loop
        lossless=False,
        quality=80,
        method=4
    )
    print(f"Animated WebP saved successfully at {out_path} with {len(frames)} frames.")
else:
    print("No frames found!")
