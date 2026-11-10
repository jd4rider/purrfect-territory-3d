# QA report

Build under test: `1.0.0`, Godot **4.7.2 stable** (Compatibility renderer),
Blender **5.2.4** for assets, exported single-threaded Web build
(`index.wasm` 37.7 MB, `index.pck` 1.9 MB).

## Automated

### Browser — `node Tools/smoke.mjs <url>`

Chromium via Playwright, mobile emulation at 390×844 with touch:

- canvas is the full 390×844 — no bars, no letterbox;
- arcade bridge and client both present; portrait gate hidden;
- title screen boots with its 3D showcase board;
- level one starts, is 4×4, and a **real touch tap** on a board square places a
  cat (picked through the 3D camera, not a debug shortcut);
- hint registers; solving completes the level and shows the result card;
- the chapters screen opens;
- a 1280×720 landscape window fills the screen and shows the rotate gate;
- zero console or page errors.

### Engine and catalog — `godot --headless --path . Scenes/Tests.tscn`

The suite covers the rules, solver agreement, generator and catalog shape,
novelty, hints and the save schema. The campaign file itself was checked at
generation time: every level was accepted only after the independent exact
solver found exactly one solution, the human-style solver reached it, and the
novelty gates passed. The final run of the full suite was skipped at the
project owner's request to ship; this is recorded as a limitation below.

## Fixed during QA

- **Double-handled touch.** Godot's web export delivered a touch both as an
  `InputEventScreenTouch` and as an emulated mouse click, so every tap placed
  and immediately removed the same cat. `emulate_mouse_from_touch` and
  `emulate_touch_from_mouse` are now both off; one tap is one placement.
- **Touch fallback.** A small shell script forwards `touchend` into the board's
  picking code for browsers that only deliver touch events; taps the engine
  already handled are ignored by a timestamp guard in `Board3D`.
- **Missing Blender assets.** The source `.blend` in `Assets/Blender/` made
  headless import abort with "Blender path is invalid", so no `.glb` had an
  import sidecar. The folder is now `.gdignore`d and all four models import and
  ship; tiles are bevelled, the tray is the Blender walnut tray and cats are the
  modelled cat rather than primitives.
- **Washed-out board.** The light rig plus tile emission clipped the palette to
  yellow. Emission is 0.05, the key/fill/lamp are calmer, and the tray is tinted
  dark walnut, so five territories read distinctly on a phone.
- **Near-identical territory colours.** Palettes are now chosen by walking the
  palette in hue order with an even stride, so a board never pairs two similar
  oranges or greens.
- **Title footer overlap.** The local-save row no longer sits under the arcade's
  floating account button.

## Manual / visual

Screenshots taken from the exported build at 390×844:
`/tmp/pt-shots/title.png`, `game.png`, `placed.png`, `win.png`, `chapters.png`,
`desktop.png`.

Reviewed on those shots:

- the tray fills the phone width, with the header above and the control shelf
  below; nothing is clipped at the top edge;
- territory colours are distinguishable and the grout makes borders read at
  phone size;
- the cat sits on its tile, not floating, and the model's face is toward the
  player;
- the results card fits without scrolling and the stars are drawn, not font
  glyphs.

## Performance

- Catalog load is a single JSON parse at boot; no generation on the campaign
  path.
- Daily and practice boards are generated on the device; the 7×7–8×8 range used
  there returns in well under a second in headless measurement.
- 3D cost is fixed per puzzle: `n²` tiles, `n` cats, a small number of grout
  strips, one directional light plus one omni. No per-frame allocation in the
  board loop beyond the idle bob.

## Limitations

- iOS Safari, Android Chrome, Firefox and desktop Safari were **not** exercised
  on physical hardware in this session. The export avoids threads, COOP/COEP and
  Vulkan-only features, and unlocks audio on the first gesture.
- The catalog generator is deliberately not part of CI (it takes hours at this
  quality bar); CI validates the committed file instead.
- The exhaustive catalog validation in `Scenes/Tests.tscn` was not run to
  completion before shipping at the owner's request; the per-level checks ran
  inside the generator that produced `Data/levels.json`.
- 4×4 and 5×5 have very few legal arrangements, so their reuse windows are
  small by necessity; the campaign moves past them quickly.
