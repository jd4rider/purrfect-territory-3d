# Purrfect Territory 3D

A cosy, portrait-first **3D cat territory logic puzzle** for Little Joy Arcade.
One cat per row, one per column, one per territory — and no two cats may touch,
not even corner to corner.

Play: <https://jd4rider.github.io/purrfect-territory-3d/>

Built with Godot 4.7.2 (Compatibility renderer, single-threaded Web export) and
Blender 5.2 for the cat, tiles, tray and yarn. No third-party art or audio.

---

## What is here

| Path | What it is |
|---|---|
| `Scripts/Puzzle/` | Rules, exact solution counter, territory generator, human-style deduction solver, novelty checks, level factory |
| `Scripts/Board/` | The 3D tray: tiles, grout, cats, paw notes, camera fitting, picking |
| `Scripts/Screens/` | Title, chapters, level grid, game, settings, tutorial, trophies |
| `Scripts/Core/` | Save schema, audio, Little Joy Arcade bridge, catalog loader, router, UI kit |
| `Data/levels.json` | The 1,000 committed campaign puzzles |
| `Tools/GenerateCatalog.gd` | One-time catalog builder (validated, novelty-checked) |
| `Tools/Probe.gd` | Generator yield/difficulty probe |
| `Tools/audio.py` | Synthesises every sound effect and both music loops |
| `Blender/build_assets.py` | Authors and exports `cat.glb`, `tile.glb`, `tray.glb`, `yarn.glb` |
| `Tests/HeadlessTests.gd` | Rules, solver agreement, catalog validation, novelty, hints, save |
| `docs/` | Puzzle generation, web compatibility, QA report, reference analysis |

## Run it

```bash
godot --path .                     # editor or game
godot --headless --path . Scenes/Tests.tscn    # tests
```

## Build and deploy

```bash
godot --headless --path . --import
godot --headless --path . Scenes/Tests.tscn
godot --headless --path . --export-release "Web" web/play/index.html
python3 Tools/patch_web.py
```

`Tools/patch_web.py` adds the arcade bridge, the full-bleed phone framing, the
manifest and the drop-in arcade client. The GitHub workflow runs exactly these
steps and publishes `web/play` to the `gh-pages` branch; Pages serves that branch
at the URL above. The branch publish is deliberate: artifact deployments on this
account stall in `syncing_files`.

Local browser check:

```bash
python3 -m http.server 4189 --directory web/play
node Tools/smoke.mjs http://127.0.0.1:4189/
```

## How the puzzles are made

1. Pick a cat arrangement from a broad random sample of valid permutations.
2. Grow N connected territories outward from those N cats using one of five
   strategies (organic, balanced, drift, Voronoi, ribbon).
3. Count solutions with an **independent exact solver**; if there is more than
   one, move a border cell belonging to an alternative solution into a
   neighbouring territory and re-check. This kills alternatives without touching
   the intended arrangement.
4. Run the **human-style deduction solver** to record how a person can solve it.
   Its maximum look-ahead depth and the techniques it needed decide the
   difficulty tier.
5. Reject near-repeats: canonical forms under all eight symmetries, arrangement
   distance from recent levels, and territory-shape similarity.

The 1,000 shipped boards were generated once and are committed; CI validates the
file rather than regenerating it. Details in [`docs/PUZZLE_GENERATION.md`](docs/PUZZLE_GENERATION.md).

## Difficulty is not board size

`HumanSolver` only uses techniques a player can learn: row/column exclusions,
territory exclusions, singles, the four territory-line interactions, then
look-ahead. Its tier:

| Tier | Meaning |
|---|---|
| Tutorial | 4×4, singles only |
| Easy | solved with no look-ahead on a board 5+ |
| Medium | needs a territory-line interaction, still no look-ahead |
| Hard | one level of look-ahead |
| Expert | two levels |
| Master | three or more |

A hint replays the same solver from the player's current board and names the
rule, so hints teach rather than reveal.

## Accessibility and comfort

- Reduced motion (stops idle bounce and victory hops)
- High-contrast territories
- Territory numbers printed on tiles for colour-blind play
- Optional "mistakes scatter the cats" mode; off by default
- Large touch targets and a portrait-locked layout

## Saves

Local first, in `user://purrfect_territory_save.json`, schema-versioned and
merged with defaults on load; a corrupt file is backed up, not deleted. When the
page is inside Little Joy Arcade and the player is signed in, the same payload
syncs through `window.PurrfectTerritory` (see `web/play/arcade-bridge.js`), with
achievements unioned and the newest progress winning.

## Known limitations

- 4×4 has exactly two legal arrangements and 5×5 only fourteen; those sizes are
  used for the tutorial and the first few levels only, and their anti-repeat
  window is necessarily small.
- Audio is synthesised; there is no voice work.
- The board is rendered at 60 fps with a fixed light rig; there is no quality
  slider yet, only reduced motion.
- Tested in Chromium via Playwright at phone and desktop sizes; Safari iOS and
  Android Chrome are covered by the same Compatibility-renderer build and WebGL 2
  path but were not run on physical devices in this session.

A Little Joy Arcade original. Made by FreeBuff.
