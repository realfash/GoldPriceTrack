import os

ICON_SIZES = [72, 96, 128, 144, 152, 192, 384, 512]

def create_simple_icon(size):
    svg_template = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#667eea"/>
      <stop offset="100%" style="stop-color:#764ba2"/>
    </linearGradient>
  </defs>
  <rect width="{size}" height="{size}" rx="{size // 5}" fill="url(#bg)"/>
  <circle cx="{size // 2}" cy="{size // 2 - size // 10}" r="{size // 3}" fill="#FFD700" stroke="#DAA520" stroke-width="{size // 40}"/>
  <text x="{size // 2}" y="{size // 2 + size // 20}" font-size="{size // 4}" text-anchor="middle" fill="#8B4513" font-weight="bold">Au</text>
</svg>'''
    return svg_template

def main():
    icons_dir = os.path.join(os.path.dirname(__file__), 'public', 'icons')
    os.makedirs(icons_dir, exist_ok=True)
    
    for size in ICON_SIZES:
        svg_content = create_simple_icon(size)
        svg_path = os.path.join(icons_dir, f'icon-{size}.svg')
        with open(svg_path, 'w') as f:
            f.write(svg_content)
        print(f'Created {svg_path}')
    
    print('\nNote: For production, convert these SVG files to PNG using:')
    print('  - Online tools like https://cloudconvert.com/svg-to-png')
    print('  - Or install imagemagick: convert icon-192.svg icon-192.png')

if __name__ == '__main__':
    main()
