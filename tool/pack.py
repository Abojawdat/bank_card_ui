#!/usr/bin/env python3
# turns build/frames/<name>/*.png into art/<name>.webp, needs pillow
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parent.parent

for folder in sorted((root / 'build/frames').iterdir()):
    frames = [Image.open(p).convert('RGB') for p in sorted(folder.glob('*.png'))]
    if not frames:
        continue
    out = root / 'art' / f'{folder.name}.webp'
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=40, loop=0, quality=80, method=6)
    print(f'{out.relative_to(root)}  {len(frames)} frames  {out.stat().st_size // 1024} KB')
