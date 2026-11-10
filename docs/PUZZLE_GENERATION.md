# Puzzle generation

## The rules

An N×N tray is partitioned into N orthogonally connected territories. Place N
cats so that:

1. every row holds exactly one cat,
2. every column holds exactly one cat,
3. every territory holds exactly one cat,
4. no two cats touch, not even diagonally.

A `cats` array stores one column per row (`-1` for empty), so rule 1 is
structural and cannot be violated by the model.

## Representation

- `regions`: N×N ints, each cell's territory id. Territory id `r` contains the
  intended cat for row `r`, which makes "one per territory" trivial to verify.
- `solution`: N ints, the intended column per row.
- The four rules are checked in `PuzzleModel.validate`, which is the only thing
  the win screen trusts. The stored solution is never used as the win condition.

## Generation pipeline

```
seed
  -> random_solution(n, rng)          # sample from up to 64 valid permutations
  -> RegionGen.build(...)             # five growth strategies
  -> connectivity + one-cat-per-territory checks
  -> ExactSolver.solve(limit 2)       # independent proof of uniqueness
       if 2 solutions: RegionGen.break_alternative + recheck (up to 10 passes)
  -> HumanSolver.solve(...)           # proof that a person can get there
  -> difficulty = HumanSolver.rate(...)
  -> novelty gate (catalog stage)
```

### Why growth starts at the cats

Each territory is seeded with exactly one cell of a chosen solution and only
grows into unassigned neighbouring cells. Two properties are therefore true by
construction: every territory is connected, and no territory can contain a
second intended cat. Uniqueness is *not* guaranteed — that is exactly why the
exact solver is independent rather than reusing the generator's own bookkeeping.

Strategies (`RegionGen.STYLES`):

- **organic** — uniform random frontier growth.
- **balanced** — always grow the smallest frontier territory.
- **drift** — weight cells by distance from the territory's own cat with noise.
- **voronoi** — nearest weighted seed, then a connectivity repair pass.
- **ribbon** — bias towards the seed's column, producing stripe-like territories.

### Repairing a non-unique board

`RegionGen.break_alternative` finds a second solution, picks one of its cat
cells that is **not** part of the intended solution, and moves that cell into an
adjacent territory. The alternative now has two cats in one territory, so it
dies; the intended solution still holds because its cells are never moved. One
move per pass, then re-count. This bounded loop is what makes large boards
practical: it replaces blind perturbation with a directed edit.

### The exact solver

`ExactSolver` is an independent row-by-row DFS over columns with four prunes:
used columns, used territories, adjacency to the previous row, and feasibility
of each remaining territory (it must still have a cell in an unused column).
Counting stops at two solutions. It shares no code with the human solver.

Agreement with exhaustive enumeration is asserted for 4×4 and 5×5 in
`Tests/HeadlessTests.gd`: every generated board at those sizes is compared with
a brute-force sweep of all `n^n` arrangements.

## Human-style difficulty

`HumanSolver` maintains a candidate bitmask per row and applies, repeatedly:

| Technique | What it removes |
|---|---|
| placement exclusion | same column, and the three squares beside it in adjacent rows |
| territory exclusion | every other cell of a territory that already has a cat |
| row single | a row whose candidate set is one square |
| territory single | a territory whose candidate set is one square |
| column single | a column with one candidate |
| territory-in-row / territory-in-column | a territory confined to one row/column |
| row-in-territory / column-in-territory | a row/column confined to one territory |

Only when none of these fire does it branch on the row with the fewest
candidates. Branch depth and the techniques used set the tier:

- no branch, no line interaction, n ≤ 4 → **Tutorial**
- no branch, no line interaction → **Easy**
- no branch, line interaction → **Medium**
- branch depth 1 → **Hard**
- depth 2 → **Expert**
- depth ≥ 3 → **Master**

This is why a 5×5 can be Medium while an 8×8 can be Easy: the rating comes from
the deduction trace, not from the number of squares.

## Anti-predictability

`Novelty` canonicalises both the cat arrangement and the territory partition
under the eight symmetries of the square and compares them:

- `solution_key` — the lexicographically smallest transformed arrangement.
- `region_key` — smallest transformed partition after relabelling territories
  by first appearance.
- `distance` — minimum number of rows with a different column, over all
  symmetries. Zero means "the same puzzle in disguise".
- `signature` — sorted territory sizes plus border-edge count, used to reject
  near-identical shapes.
- `predictable_ratio` — fraction of consecutive levels whose arrangement is a
  one-step shift or a mirror; the test suite requires it under 5%.

Colour order is generated from the level id with a salt that never includes the
solution, so the palette cannot leak the answer. Region numbers in the
accessibility option are territory ids, again unrelated to cat positions.

### Reuse windows

Small boards are mathematically limited: 4×4 has two legal arrangements, 5×5
fourteen, 6×6 ninety (before symmetry). Demanding global uniqueness would make a
1,000-level campaign impossible, so the generator enforces a distance window
that scales with size: 6 for 5×5, 14 for 6×6, 45 for 7×7, 110 for 8×8, 160 for
9×9 and 10×10. Territory partitions have a wider window (400). The campaign also
ramps board size quickly — after five levels it is 6×6 and above — and uses 4×4
exactly once.

## Campaign shape

Ten chapters × 100 levels. Sizes per chapter are listed in
`Scripts/Core/Chapters.gd`; each chapter has its own palette and territory names.
Difficulty targets step from Tutorial/Easy/Medium in Sunbeam Steps to
Expert/Master in Nine Lives Summit, and the catalog generator tries the target
tier first, then the chapter's tier band, then any tier.

## Reproducing the catalog

```bash
godot --headless --path . -s Tools/GenerateCatalog.gd
```

It prints accepted levels, difficulty and size distributions, rejection reasons
and the predictability ratio, and writes `Data/levels.json`. Generation is a
one-time offline step; CI validates the committed file.
