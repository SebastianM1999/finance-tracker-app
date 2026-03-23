"""
Badge processor — crops a 2x2 grid image into 4 individual transparent PNGs.

Usage:
    python tools/process_badge.py <image_path> <mission_id>

Grid layout expected:
    top-left     = bronze
    top-right    = silver
    bottom-left  = gold
    bottom-right = diamond

Output:
    assets/badges/<mission_id>_bronze.png
    assets/badges/<mission_id>_silver.png
    assets/badges/<mission_id>_gold.png
    assets/badges/<mission_id>_diamond.png

Example:
    python tools/process_badge.py ~/Downloads/etf_badge.png etf_vol
"""

import sys
import io
import os
from PIL import Image
from rembg import remove

TIERS = ['bronze', 'silver', 'gold', 'diamond']
POSITIONS = [(0, 0), (1, 0), (0, 1), (1, 1)]  # (col, row)
OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'badges')


def process(image_path: str, mission_id: str):
    if not os.path.exists(image_path):
        print(f'Error: file not found: {image_path}')
        sys.exit(1)

    os.makedirs(OUT_DIR, exist_ok=True)

    img = Image.open(image_path).convert('RGB')
    w, h = img.size
    half_w, half_h = w // 2, h // 2

    print(f'Source: {image_path} ({w}x{h})')

    for (col, row), tier in zip(POSITIONS, TIERS):
        x0, y0 = col * half_w, row * half_h
        cropped = img.crop((x0, y0, x0 + half_w, y0 + half_h))

        buf = io.BytesIO()
        cropped.save(buf, format='PNG')
        result = Image.open(io.BytesIO(remove(buf.getvalue()))).convert('RGBA')

        # Auto-center: crop to non-transparent bbox, then pad symmetrically
        bbox = result.getbbox()
        if bbox:
            content = result.crop(bbox)
            cw, ch = content.size
            side = max(cw, ch)
            centered = Image.new('RGBA', (side, side), (0, 0, 0, 0))
            centered.paste(content, ((side - cw) // 2, (side - ch) // 2))
            result = centered.resize((512, 512), Image.LANCZOS)

        out_path = os.path.join(OUT_DIR, f'{mission_id}_{tier}.png')
        result.save(out_path)
        print(f'  OK {mission_id}_{tier}.png')

    print('Done.')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    process(sys.argv[1], sys.argv[2])
