import os
from PIL import Image
import numpy as np

src_dir = r'C:\Users\ASUS\project-epic-app\aset-epic-karakter1'
frames = []

for i in range(1, 251):
    path = os.path.join(src_dir, f'{i:04d}.png')
    if os.path.exists(path):
        img = Image.open(path).convert('L') # Convert to grayscale
        img = img.resize((100, 100)) # Downscale for faster processing
        frames.append(np.array(img))

diffs = []
for i in range(1, len(frames)):
    diff = np.mean(np.abs(frames[i].astype(float) - frames[i-1].astype(float)))
    diffs.append(diff)

# Print out regions of high movement
print("Motion Analysis:")
state = "idle"
threshold = 1.5 # Adjust based on results
start_idx = 1

for i, d in enumerate(diffs):
    frame_num = i + 2
    is_moving = d > threshold
    
    if is_moving and state == "idle":
        print(f"Frames {start_idx}-{frame_num-1}: Idle (diff ~ {np.mean(diffs[start_idx-1:i]):.2f})")
        state = "action"
        start_idx = frame_num
    elif not is_moving and state == "action":
        print(f"Frames {start_idx}-{frame_num-1}: Action (diff ~ {np.mean(diffs[start_idx-1:i]):.2f})")
        state = "idle"
        start_idx = frame_num

print(f"Frames {start_idx}-250: {state.capitalize()}")
