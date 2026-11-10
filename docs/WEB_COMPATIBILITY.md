# Web compatibility

## Build

- Godot **4.7.2 stable** (the installed version).
- **Compatibility** renderer (`gl_compatibility`) for WebGL 2; no Vulkan-only
  features, no compute shaders.
- **Single-threaded** export (`variant/thread_support=false`), so no
  cross-origin isolation headers are required. This matters because the arcade
  may add ad or analytics scripts that would break COOP/COEP.
- GDScript only, no C#.
- Textures are conservative (Blender GLBs total ≈ 560 KB); audio is mono
  22 kHz WAV. The exported package is a few megabytes, dominated by the engine
  wasm.

## Phone framing

`project.godot` uses `window/stretch/aspect="expand"` with a 720×1280 design
size, and `web/play/frame.css` gives the canvas `width:100%; height:100%` with no
max-width guard. Together they mean a 390×844 phone gets a 390×844 canvas — no
pillarbox, no letterbox. The board's camera solves its own fit from the live
viewport aspect (`Board3D.fit_camera`), so tall, short and desktop-portrait
windows all frame the tray without cropping.

Landscape windows show a rotate gate (`#lja-rotate` in `arcade-bridge.js`) and
the canvas still fills the window behind it.

Safe areas are respected in standalone display mode through
`env(safe-area-inset-*)`; in a browser tab the viewport is clean.

## Input

- Touch: `InputEventScreenTouch` on the canvas, picked through the 3D camera.
- Mouse: left click also picks; `emulate_touch_from_mouse` is enabled.
- Keyboard: the UI is ordinary Godot `Control` focus/activation, so Enter and
  Space work on focused buttons.
- `touch-action: none` and `user-select: none` stop browser scroll/zoom gestures
  stealing taps.

## Audio

Browsers suspend WebAudio until a gesture. `Audio.kick()` is called from the
first touch or click in `Main._unhandled_input`, and music only starts after
that, so no console warning or silent game.

## Saving

Godot writes to `user://`, which the web export backs with IndexedDB. The arcade
bridge snapshots that JSON (`LJA_SNAPSHOT` / `LJA_APPLY_SNAPSHOT`) so the portal
can sync it without reading Godot's storage directly. Browser storage can be
cleared by the user; the game treats that as a fresh save and never errors.

## Hosting

Static hosting only. On GitHub Pages the game is published from the `gh-pages`
branch (built by the workflow), which serves `.wasm` as `application/wasm` and
`.pck` as a binary download. `.nojekyll` is written by `Tools/patch_web.py` so
underscore-prefixed files are served. No server code, no API keys in the client
(the arcade client ships with its public anon key, as on every other game in the
portal).

If a host does not send the right MIME type for `.wasm`, Godot's shell reports a
missing-feature notice instead of a blank canvas; the error text is shown in the
`#status-notice` panel.

## Tested here

- Chromium (Playwright) at 390×844, 360×740, 430×764 and 1280×720.
- Desktop Chromium at 1280×720: rotate gate visible, canvas full-window.

Not run on physical devices in this session: iOS Safari, Android Chrome,
Firefox and desktop Safari. The build avoids the usual causes of Safari failure
(no threads, no COOP/COEP dependency, WebGL 2 via the Compatibility renderer,
audio unlocked by gesture), but that is an expectation, not a measurement.
