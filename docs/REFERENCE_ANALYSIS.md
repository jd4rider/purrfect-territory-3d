# Reference analysis and design decisions

## What the reference was, and what it was not

The brief supplied a read-only forensic report on an installed commercial cat
logic puzzle (Meowdoku 1.18.0, a Godot 4.6.1 build). That report was used as
**technical context only**: it confirms Godot can ship a polished casual puzzle
on mobile, and it describes a `Control`-based board. It is not a source of
assets, layouts, level data, scripts or branding, and none were copied.

The game was also played briefly for high-level feel (pacing, feedback, clarity),
which is exactly what the brief allowed. No levels were harvested, no binary was
modified, nothing was extracted from the PCK.

## Deliberate differences

| Area | Reference | This game |
|---|---|---|
| Board | 2D `Control` view | True `Node3D` tray: Blender tiles, grout, cats, raycast picking |
| Art | flat illustrated board | tactile toy diorama: walnut tray, bevelled tiles, lamplit table, 3D cat with idle animation |
| Level source | shipped level banks | generated once by our own pipeline, proved unique, committed as JSON |
| Difficulty | not public | explicit human-deduction solver and six tiers derived from its trace |
| Anti-repeat | not public | canonical symmetry keys, arrangement distance, territory-shape similarity, predictability test |
| Hints | not public | replay the deduction solver from the player's board and name the rule used |
| Progression | not copied | ten original chapters with original names, palettes and territory names |
| Audio | not copied | every sound synthesised by `Tools/audio.py` |
| Structural model | `Control` board | `Node3D` board + `Control` HUD, as the brief requires |

## Why a permutation model

A cat per row is structural when the board state is one column per row. That
removes an entire class of invalid states and makes the exact solver a
column-choice DFS rather than a general CSP. Regions are stored as ids whose
index matches the row of the intended cat, which makes "exactly one per
territory" cheap to check and impossible to get wrong during growth.

## Why an independent solver

The generator knows which cat arrangement it started from, so it can never be the
thing that certifies uniqueness. `ExactSolver` receives only the region grid. The
test suite additionally compares it with brute-force enumeration at 4×4 and 5×5,
which is the only way to catch a pruning bug that silently hides solutions.

## Why difficulty comes from a second solver

Machine effort (nodes searched) is not human difficulty. `HumanSolver` applies
only teachable techniques, then branches. The depth of that branch is what "Hard",
"Expert" and "Master" mean here. This is also what makes hints honest: the same
solver explains the next forced move, so a hint can never be a bare reveal unless
no rule reaches the square.

## Why novelty is measured, not assumed

Uniqueness alone does not make a puzzle feel new. Two boards can be unique and be
the same puzzle rotated. Canonicalisation under the square's eight symmetries,
plus arrangement distance and territory-shape descriptors, is enforced at
catalog time, and the test suite measures how often a naive shift/mirror rule
would predict the next level. That number must stay under 5%.

## Honest limits

Small boards are mathematically limited (4×4: two arrangements; 5×5: fourteen),
so those sizes appear once and only briefly; the campaign moves to 7×7–10×10
quickly, and its reuse windows scale with board size. This is documented rather
than hidden behind "1,000 unique puzzles".
