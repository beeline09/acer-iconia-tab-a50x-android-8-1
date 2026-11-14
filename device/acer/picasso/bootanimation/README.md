# Boot visuals (picasso)

- `splash.raw` - static logo, shown by `picasso-splash.sh` a few seconds into
  boot (before SurfaceFlinger), raw 1280x800 R8G8B8A8.
- `bootanimation.zip` - looping ring, 560x560 JPEG frames, centred by
  bootanimation.

Regenerate both with `make-bootanim.py` from `source/`.

Licensing note: `source/ring.gif` and `source/logo.png` were supplied by the
device owner for personal use (Android N styled artwork). Replace them with
own/neutral artwork before distributing a build.
