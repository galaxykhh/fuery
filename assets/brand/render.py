"""Renders the brand PNGs from the SVGs in this folder.

Needs Google Chrome and a network connection (text is set in Inter from
Google Fonts). Run from anywhere: python3 assets/brand/render.py
"""

import os
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = os.environ.get(
    'CHROME', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')

# (source, output, width, height, device scale factor)
TARGETS = [
    ('social-preview.svg', 'social-preview.png', 1280, 640, 1),
    ('banner.svg', 'banner.png', 1280, 400, 2),
    ('icon.svg', 'icon.png', 512, 512, 1),
    ('mark.svg', 'mark.png', 512, 512, 1),
]

PAGE = '''<!doctype html>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700&display=block">
<style>html, body {{ margin: 0; background: transparent; }} svg {{ display: block; }}</style>
{svg}
'''

for source, output, width, height, scale in TARGETS:
    with open(os.path.join(HERE, source)) as f:
        svg = f.read()
    with tempfile.NamedTemporaryFile('w', suffix='.html', delete=False) as page:
        page.write(PAGE.format(svg=svg))
    subprocess.run([
        CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
        '--default-background-color=00000000', '--virtual-time-budget=10000',
        f'--force-device-scale-factor={scale}', f'--window-size={width},{height}',
        f'--screenshot={os.path.join(HERE, output)}', f'file://{page.name}',
    ], check=True, capture_output=True)
    os.unlink(page.name)
    print(output)
