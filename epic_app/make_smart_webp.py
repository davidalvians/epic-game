import os
from PIL import Image

src_dir = r'C:\Users\ASUS\project-epic-app\aset-epic-karakter1'
dst_dir = r'C:\Users\ASUS\project-epic-app\epic_app\assets\images\character\default'

def load_frames(start, end):
    frames = []
    for i in range(start, end + 1):
        path = os.path.join(src_dir, f'{i:04d}.png')
        if os.path.exists(path):
            img = Image.open(path).convert("RGBA")
            frames.append(img)
    return frames

print("Loading frames...")
action1 = load_frames(1, 58)
idle = load_frames(59, 67)
action2 = load_frames(128, 206)
action3 = load_frames(207, 250)

# Build the sequence
sequence = []
durations = []

def add_to_sequence(frames, is_idle=False):
    # If it's an idle sequence, we want it to last about 4 seconds (120 frames at 30fps)
    # The idle sequence is only 9 frames long, so we loop it 13 times
    if is_idle:
        loop_count = 13
        for _ in range(loop_count):
            for f in frames:
                img_copy = f.copy()
                sequence.append(img_copy)
                durations.append(33) # 30 fps
    else:
        for f in frames:
            img_copy = f.copy()
            sequence.append(img_copy)
            durations.append(33) # 30 fps

print("Building sequence...")
add_to_sequence(action1, is_idle=False)
add_to_sequence(idle, is_idle=True)
add_to_sequence(action2, is_idle=False)
add_to_sequence(idle, is_idle=True)
add_to_sequence(action3, is_idle=False)
add_to_sequence(idle, is_idle=True)

if sequence:
    print(f"Total sequence length: {len(sequence)} frames")
    out_path = os.path.join(dst_dir, 'character_animated.webp')
    
    # Remove the old file if it exists
    if os.path.exists(out_path):
        os.remove(out_path)
        
    print("Saving Animated WebP. This might take a minute...")
    sequence[0].save(
        out_path,
        format='WEBP',
        save_all=True,
        append_images=sequence[1:],
        duration=durations,
        loop=0,
        lossless=False,
        quality=80,
        method=4
    )
    print(f"Successfully saved to {out_path}!")
else:
    print("Error: No frames were loaded.")
