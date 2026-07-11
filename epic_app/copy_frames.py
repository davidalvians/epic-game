import os
import shutil

src_dir = r'C:\Users\ASUS\project-epic-app\aset-epic-karakter1'
dst_dir = r'C:\Users\ASUS\project-epic-app\epic_app\assets\images\character\default'

os.makedirs(dst_dir, exist_ok=True)

# Copy Idle frames
for i in range(1, 11):
    src = os.path.join(src_dir, f'{i:04d}.png')
    dst = os.path.join(dst_dir, f'Idle ({i}).png')
    shutil.copy(src, dst)

# Copy Attack frames
for i in range(1, 11):
    src = os.path.join(src_dir, f'{i+10:04d}.png')
    dst = os.path.join(dst_dir, f'Attack ({i}).png')
    shutil.copy(src, dst)

# Copy Jump frames
for i in range(1, 11):
    src = os.path.join(src_dir, f'{i+20:04d}.png')
    dst = os.path.join(dst_dir, f'Jump ({i}).png')
    shutil.copy(src, dst)

print("Frames copied successfully!")
