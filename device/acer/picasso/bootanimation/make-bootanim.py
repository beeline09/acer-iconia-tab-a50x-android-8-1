#!/usr/bin/env python3
"""Regenerate bootanimation.zip and splash.raw for picasso (1280x800).

Usage: make-bootanim.py   (run from this directory; needs Pillow)

- bootanimation.zip: source/ring.gif (91 frames, 400x400) scaled to 560x560
  JPEG, desc "560 560 30", one endless part, STORED (bootanimation mmaps the
  entries and rejects compressed ones). A small frame keeps on-the-fly
  decoding cheap: the GLES2 bootanimation does not cache frame textures.
- splash.raw: source/logo.png 300x300 centred on black, raw 1280x800
  R8G8B8A8 (tegra_fb format), written to /dev/graphics/fb0 by
  picasso-splash.sh early in boot.
"""
import io, zipfile
from PIL import Image

S = 560
g = Image.open('source/ring.gif')
with zipfile.ZipFile('bootanimation.zip', 'w', zipfile.ZIP_STORED) as z:
    z.writestr('desc.txt', f'{S} {S} 30\np 0 0 part0\n')
    for i in range(g.n_frames):
        g.seek(i)
        f = g.convert('RGB').resize((S, S), Image.LANCZOS)
        b = io.BytesIO()
        f.save(b, 'JPEG', quality=92, subsampling=0, optimize=True)
        z.writestr(f'part0/{i:03d}.jpg', b.getvalue())

logo = Image.open('source/logo.png').convert('RGBA').resize((300, 300), Image.LANCZOS)
bg = Image.new('RGBA', (1280, 800), (0, 0, 0, 255))
bg.alpha_composite(logo, ((1280 - 300) // 2, (800 - 300) // 2))
open('splash.raw', 'wb').write(bg.tobytes('raw', 'RGBA'))
