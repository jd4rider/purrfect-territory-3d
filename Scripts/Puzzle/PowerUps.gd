class_name PowerUps
extends RefCounted
## The three assists a player earns over time.
##
## Cat  — unearths one cat still hidden on the tray.
## Clue — explains the next forced square (HumanSolver) and lets you apply it.
## Mouse — crosses out a square that provably cannot hold a cat.
##
## Everything here is derived from the player's current board, never from a
## stored arrangement, so an assist can never contradict the rules on screen.

## Picks a row that has no cat yet and returns the solution's cat for it, but
## only when that cat fits beside the cats already on the tray. Revealing a true
## cat next to a player's mistaken one would put an illegal board on screen.
static func hidden_cat(regions: PackedInt32Array, n: int, cats: Array, solution: Array,
		rng: RandomNumberGenerator) -> Vector2i:
	var rows: Array = []
	for r in range(mini(cats.size(), solution.size())):
		if int(cats[r]) >= 0:
			continue
		if conflicts(regions, n, cats, r, int(solution[r])):
			continue
		rows.append(r)
	if rows.is_empty():
		return Vector2i(-1, -1)
	var row := int(rows[rng.randi_range(0, rows.size() - 1)])
	return Vector2i(row, int(solution[row]))


## True when a cat at (row, col) would share a column or a territory with a cat
## already placed, or touch one, even corner to corner.
static func conflicts(regions: PackedInt32Array, n: int, cats: Array, row: int, col: int) -> bool:
	for r in range(n):
		if r == row or r >= cats.size():
			continue
		var other := int(cats[r])
		if other < 0:
			continue
		if other == col:
			return true
		if absi(r - row) == 1 and absi(other - col) <= 1:
			return true
		if regions.size() >= n * n and regions[r * n + other] == regions[row * n + col]:
			return true
	return false


## A square that cannot hold a cat. Human-style exclusions come first so the X
## teaches a rule; the solution is only a safety net and a tie-breaker.
static func safe_mark(regions: PackedInt32Array, n: int, cats: Array, marks: Array,
		solution: Array, rng: RandomNumberGenerator) -> Vector2i:
	var safe: Array = []
	for at: Vector2i in HumanSolver.excluded_cells(regions, n, cats, marks):
		if at.x < solution.size() and int(solution[at.x]) == at.y:
			continue
		safe.append(at)
	if safe.is_empty():
		safe = _open_cells(n, cats, marks, solution)
	if safe.is_empty():
		return Vector2i(-1, -1)
	return safe[rng.randi_range(0, safe.size() - 1)]


## Every square that is not a placed cat, not marked yet and not a cat in the
## finished board.
static func _open_cells(n: int, cats: Array, marks: Array, solution: Array) -> Array:
	var out: Array = []
	for r in range(n):
		var placed := int(cats[r]) if r < cats.size() else -1
		for c in range(n):
			if c == placed:
				continue
			if r < solution.size() and int(solution[r]) == c:
				continue
			if r < marks.size() and c < (marks[r] as Array).size() and bool(marks[r][c]):
				continue
			out.append(Vector2i(r, c))
	return out
