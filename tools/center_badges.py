"""
Re-centers all badge PNGs in assets/badges/ by:
  1. Finding the bounding box of non-transparent pixels
  2. Cropping to that box
  3. Padding symmetrically so the content is centered in a square
  4. Resizing to 512x512 and saving back in-place

Run once to fix all existing badges:
    python tools/center_badges.py

Optional: target a single mission ID:
    python tools/center_badges.py fg_count
"""

import sys
import os
from PIL import Image

BADGES_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'badges')
OUTPUT_SIZE = 512


def center_badge(path: str) -> bool:
    img = Image.open(path).convert('RGBA')
    bbox = img.getbbox()  # (left, top, right, bottom) of non-transparent pixels
    if bbox is None:
        print(f'  SKIP (fully transparent): {os.path.basename(path)}')
        return False

    # Crop to content
    content = img.crop(bbox)
    cw, ch = content.size

    # Make square by padding the shorter axis symmetrically
    side = max(cw, ch)
    pad_x = (side - cw) // 2
    pad_y = (side - ch) // 2

    square = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    square.paste(content, (pad_x, pad_y))

    # Resize to target output size
    final = square.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.LANCZOS)
    final.save(path)
    return True


def main():
    filter_id = sys.argv[1] if len(sys.argv) > 1 else None

    files = sorted(f for f in os.listdir(BADGES_DIR) if f.endswith('.png'))
    if filter_id:
        files = [f for f in files if f.startswith(filter_id + '_')]

    if not files:
        print(f'No matching PNGs found in {BADGES_DIR}')
        return

    print(f'Processing {len(files)} badge(s)...')
    ok = 0
    for fname in files:
        path = os.path.join(BADGES_DIR, fname)
        if center_badge(path):
            print(f'  OK {fname}')
            ok += 1

    print(f'\nDone. {ok}/{len(files)} re-centered.')


if __name__ == '__main__':
    main()
