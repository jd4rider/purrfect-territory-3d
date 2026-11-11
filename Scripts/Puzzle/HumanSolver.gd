class_name HumanSolver
extends RefCounted
## A deterministic human-style deduction solver.
##
## The exact solver answers "is this board unique?". This one answers "how would
## a person get there?", which is what difficulty actually means. It applies only
## techniques a player can learn — row/column/territory exclusions, singles, and
## the four territory-line interactions — and only branches when none of those
## are available. Branch depth and the techniques used become the difficulty
## rating, so a big board is not automatically a hard one.
##
## Board state uses plain Arrays on purpose: packed arrays are value types, so a
## deduction applied through a dictionary lookup would silently edit a copy.

const KIND_TEXT := {
	"single_row": "This row has only one open square for its cat.",
	"single_region": "This territory has only one open square, so its cat must go there.",
	"single_column": "This column has only one open square.",
	"region_in_row": "Every open square in this territory sits in this row, so the row's cat belongs to it.",
	"row_in_region": "This row can only place its cat inside this territory, so the territory's cat is in this row.",
	"region_in_column": "Every open square in this territory sits in this column.",
	"column_in_region": "This column can only place its cat inside this territory.",
	"lookahead": "No single rule reaches this square yet. Looking a few moves ahead, it has to be a cat.",
}


static func solve(regions: PackedInt32Array, n: int) -> Dictionary:
	var metrics := {
		"branches": 0,
		"max_depth": 0,
		"forced": 0,
		"kinds": {},
		"max_candidates": n,
		"trace": [],
	}
	var result := _search(_initial_state(n), regions, n, 0, metrics)
	return {
		"solved": bool(result["ok"]),
		"solution": result.get("solution", []),
		"metrics": metrics,
		"difficulty": rate(n, metrics),
		"trace": metrics["trace"],
	}


static func rate(n: int, metrics: Dictionary) -> String:
	var kinds: Dictionary = metrics.get("kinds", {})
	var branches := int(metrics.get("branches", 0))
	var depth := int(metrics.get("max_depth", 0))
	var advanced := kinds.has("region_in_row") or kinds.has("row_in_region") \
		or kinds.has("region_in_column") or kinds.has("column_in_region")
	if branches == 0:
		if advanced:
			return "Medium"
		if n <= 4:
			return "Tutorial"
		return "Easy"
	if depth <= 1:
		return "Hard"
	if depth == 2:
		return "Expert"
	return "Master"


static func tier(difficulty: String) -> int:
	match difficulty:
		"Tutorial":
			return 0
		"Easy":
			return 1
		"Medium":
			return 2
		"Hard":
			return 3
		"Expert":
			return 4
		"Master":
			return 5
	return 2


# --------------------------------------------------------------------------
# search
# --------------------------------------------------------------------------

static func _initial_state(n: int) -> Dictionary:
	var masks: Array = []
	var cats: Array = []
	for r in range(n):
		masks.append((1 << n) - 1)
		cats.append(-1)
	return {"masks": masks, "cats": cats}


static func _copy_state(state: Dictionary) -> Dictionary:
	return {"masks": (state["masks"] as Array).duplicate(), "cats": (state["cats"] as Array).duplicate()}


static func _search(state: Dictionary, regions: PackedInt32Array, n: int, depth: int, metrics: Dictionary) -> Dictionary:
	if _deduce(state, regions, n, metrics):
		return {"ok": false, "solution": []}
	if _complete(state, n):
		var solution: Array = []
		for value in state["cats"]:
			solution.append(int(value))
		return {"ok": true, "solution": solution}

	var best_row := -1
	var best_count := 1 << 30
	var masks: Array = state["masks"]
	var cats: Array = state["cats"]
	for r in range(n):
		if int(cats[r]) >= 0:
			continue
		var count := _popcount(int(masks[r]))
		if count < best_count:
			best_count = count
			best_row = r
	if best_row < 0 or best_count == 0:
		return {"ok": false, "solution": []}
	metrics["branches"] = int(metrics["branches"]) + 1
	metrics["max_candidates"] = maxi(int(metrics["max_candidates"]), best_count)
	metrics["max_depth"] = maxi(int(metrics["max_depth"]), depth + 1)
	for c in _bits(int(masks[best_row])):
		var copy := _copy_state(state)
		if not _place(copy, best_row, int(c), n, metrics, "lookahead"):
			continue
		var result := _search(copy, regions, n, depth + 1, metrics)
		if bool(result["ok"]):
			return result
	return {"ok": false, "solution": []}


static func _complete(state: Dictionary, n: int) -> bool:
	var cats: Array = state["cats"]
	for r in range(n):
		if int(cats[r]) < 0:
			return false
	return true


# --------------------------------------------------------------------------
# deductions
# --------------------------------------------------------------------------

static func _deduce(state: Dictionary, regions: PackedInt32Array, n: int, metrics: Dictionary) -> bool:
	var cells := PuzzleModel.region_cells(regions, n)
	var masks: Array = state["masks"]
	var cats: Array = state["cats"]
	var guard := 0
	while true:
		guard += 1
		if guard > 500:
			return true
		var changed := false
		if _contradiction(state, regions, n):
			return true

		# Exclusions implied by every cat already on the board.
		for r in range(n):
			if int(cats[r]) < 0:
				continue
			var c := int(cats[r])
			for other in range(n):
				if other == r or int(cats[other]) >= 0:
					continue
				var before := int(masks[other])
				if absi(other - r) <= 1:
					masks[other] = before & ~_window(c, n)
				else:
					masks[other] = before & ~(1 << c)
				if int(masks[other]) != before:
					changed = true

		# A territory with a cat cannot take another one.
		for reg in range(n):
			var placed := _region_placed(state, regions, n, reg)
			if placed.x < 0:
				continue
			for at in cells[reg]:
				if int(at.x) == placed.x:
					continue
				var before := int(masks[at.x])
				masks[at.x] = before & ~(1 << int(at.y))
				if int(masks[at.x]) != before:
					changed = true

		# Naked singles: one open square in a row.
		for r in range(n):
			if int(cats[r]) >= 0:
				continue
			var mask := int(masks[r])
			if _popcount(mask) == 1:
				if not _place(state, r, _first_bit(mask), n, metrics, "single_row"):
					return true
				changed = true

		# A territory with one candidate square.
		for reg in range(n):
			if _region_placed(state, regions, n, reg).x >= 0:
				continue
			var candidates := _region_candidates(state, cells[reg])
			if candidates.is_empty():
				return true
			if candidates.size() == 1:
				var at: Vector2i = candidates[0]
				if not _place(state, int(at.x), int(at.y), n, metrics, "single_region"):
					return true
				changed = true

		# A column with one candidate square.
		for c in range(n):
			if _column_placed(state, c).x >= 0:
				continue
			var found := -1
			var count := 0
			for r in range(n):
				if int(cats[r]) >= 0:
					continue
				if ((int(masks[r]) >> c) & 1) == 1:
					count += 1
					found = r
			if count == 0:
				return true
			if count == 1:
				if not _place(state, found, c, n, metrics, "single_column"):
					return true
				changed = true

		# Territory-line interactions.
		for reg in range(n):
			if _region_placed(state, regions, n, reg).x >= 0:
				continue
			var candidates := _region_candidates(state, cells[reg])
			if candidates.is_empty():
				return true
			var rows := {}
			var cols := {}
			for at in candidates:
				rows[int(at.x)] = true
				cols[int(at.y)] = true
			if rows.size() == 1:
				var row: int = int(rows.keys()[0])
				var keep := 0
				for at in candidates:
					keep |= 1 << int(at.y)
				if int(masks[row]) != keep:
					masks[row] = keep
					_note(metrics, "region_in_row")
					changed = true
			if cols.size() == 1:
				var col: int = int(cols.keys()[0])
				for r in range(n):
					if r == (candidates[0] as Vector2i).x and false:
						continue
					if int(cats[r]) >= 0:
						continue
					if ((int(masks[r]) >> col) & 1) == 0:
						continue
					var owner := regions[r * n + col]
					if owner == reg:
						continue
					masks[r] = int(masks[r]) & ~(1 << col)
					_note(metrics, "region_in_column")
					changed = true

		# A row confined to one territory.
		for r in range(n):
			if int(cats[r]) >= 0:
				continue
			var mask := int(masks[r])
			if mask == 0:
				return true
			var owner := -1
			var mixed := false
			for c in _bits(mask):
				var reg := regions[r * n + int(c)]
				if owner < 0:
					owner = reg
				elif owner != reg:
					mixed = true
					break
			if owner >= 0 and not mixed:
				for at in cells[owner]:
					if int(at.x) == r:
						continue
					var before := int(masks[at.x])
					masks[at.x] = before & ~(1 << int(at.y))
					if int(masks[at.x]) != before:
						_note(metrics, "row_in_region")
						changed = true

		# A column confined to one territory.
		for c in range(n):
			if _column_placed(state, c).x >= 0:
				continue
			var owner := -1
			var mixed := false
			var rows_with := 0
			for r in range(n):
				if int(cats[r]) >= 0:
					continue
				if ((int(masks[r]) >> c) & 1) == 0:
					continue
				rows_with += 1
				var reg := regions[r * n + c]
				if owner < 0:
					owner = reg
				elif owner != reg:
					mixed = true
			if rows_with == 0:
				return true
			if owner >= 0 and not mixed:
				for at in cells[owner]:
					if int(at.y) == c:
						continue
					var before := int(masks[at.x])
					masks[at.x] = before & ~(1 << int(at.y))
					if int(masks[at.x]) != before:
						_note(metrics, "column_in_region")
						changed = true

		if not changed:
			return _contradiction(state, regions, n)
	return false


static func _contradiction(state: Dictionary, regions: PackedInt32Array, n: int) -> bool:
	var cats: Array = state["cats"]
	var masks: Array = state["masks"]
	var seen_cols := {}
	var seen_regions := {}
	for r in range(n):
		if int(cats[r]) < 0:
			if int(masks[r]) == 0:
				return true
			continue
		var c := int(cats[r])
		if ((int(masks[r]) >> c) & 1) == 0:
			return true
		if seen_cols.has(c):
			return true
		seen_cols[c] = true
		var reg := regions[r * n + c]
		if seen_regions.has(reg):
			return true
		seen_regions[reg] = true
	for r in range(n):
		if int(cats[r]) < 0:
			continue
		for other in range(r + 1, n):
			if int(cats[other]) < 0:
				continue
			if absi(r - other) <= 1 and absi(int(cats[r]) - int(cats[other])) <= 1:
				return true
	return false


static func _place(state: Dictionary, r: int, c: int, n: int, metrics: Dictionary, kind: String) -> bool:
	var masks: Array = state["masks"]
	var cats: Array = state["cats"]
	if ((int(masks[r]) >> c) & 1) == 0:
		return false
	if int(cats[r]) >= 0 and int(cats[r]) != c:
		return false
	cats[r] = c
	masks[r] = 1 << c
	metrics["forced"] = int(metrics["forced"]) + 1
	_note(metrics, kind)
	var trace: Array = metrics["trace"]
	if trace.size() < 80:
		trace.append({"kind": kind, "row": r, "col": c})
	return true


static func _note(metrics: Dictionary, kind: String) -> void:
	var kinds: Dictionary = metrics["kinds"]
	kinds[kind] = int(kinds.get(kind, 0)) + 1


static func _region_placed(state: Dictionary, regions: PackedInt32Array, n: int, reg: int) -> Vector2i:
	var cats: Array = state["cats"]
	for r in range(n):
		var c := int(cats[r])
		if c >= 0 and regions[r * n + c] == reg:
			return Vector2i(r, c)
	return Vector2i(-1, -1)


static func _column_placed(state: Dictionary, c: int) -> Vector2i:
	var cats: Array = state["cats"]
	for r in range(cats.size()):
		if int(cats[r]) == c:
			return Vector2i(r, c)
	return Vector2i(-1, -1)


static func _region_candidates(state: Dictionary, cells: Array) -> Array:
	var out: Array = []
	var cats: Array = state["cats"]
	var masks: Array = state["masks"]
	for at in cells:
		if int(cats[at.x]) >= 0:
			continue
		if ((int(masks[at.x]) >> int(at.y)) & 1) == 0:
			continue
		out.append(at)
	return out


static func _window(c: int, n: int) -> int:
	var mask := 0
	for value in [c - 1, c, c + 1]:
		if value >= 0 and value < n:
			mask |= 1 << value
	return mask


static func _popcount(value: int) -> int:
	var total := 0
	var v := value
	while v != 0:
		v &= v - 1
		total += 1
	return total


static func _first_bit(value: int) -> int:
	for i in range(32):
		if ((value >> i) & 1) == 1:
			return i
	return -1


static func _bits(value: int) -> Array:
	var out: Array = []
	for i in range(32):
		if ((value >> i) & 1) == 1:
			out.append(i)
	return out


# --------------------------------------------------------------------------
# hints
# --------------------------------------------------------------------------

## Turns the visible board (cats + crossed-out marks) into solver masks.
static func _state_from(regions: PackedInt32Array, n: int, cats: Array, marks: Array) -> Dictionary:
	var masks: Array = []
	var state_cats: Array = []
	for r in range(n):
		var mask := (1 << n) - 1
		for c in range(n):
			if r < marks.size() and c < (marks[r] as Array).size() and bool(marks[r][c]):
				mask &= ~(1 << c)
		masks.append(mask)
		state_cats.append(-1)
	for r in range(n):
		var c := int(cats[r]) if r < cats.size() else -1
		if c < 0:
			continue
		state_cats[r] = c
		masks[r] = 1 << c
		for other in range(n):
			if other == r or int(state_cats[other]) >= 0:
				continue
			if absi(other - r) <= 1:
				masks[other] = int(masks[other]) & ~_window(c, n)
			else:
				masks[other] = int(masks[other]) & ~(1 << c)
	for r in range(n):
		if int(state_cats[r]) >= 0:
			masks[r] = 1 << int(state_cats[r])
	return {"masks": masks, "cats": state_cats}


## Every square the human techniques prove cannot hold a cat. The mouse
## power-up uses this so its X follows a rule the player could have spotted.
static func excluded_cells(regions: PackedInt32Array, n: int, cats: Array, marks: Array) -> Array:
	var state := _state_from(regions, n, cats, marks)
	var metrics := {"branches": 0, "max_depth": 0, "forced": 0, "kinds": {},
		"max_candidates": n, "trace": []}
	_deduce(state, regions, n, metrics)
	var out: Array = []
	var masks: Array = state["masks"]
	var solved_rows: Array = state["cats"]
	for r in range(n):
		if int(solved_rows[r]) >= 0:
			continue
		for c in range(n):
			if ((int(masks[r]) >> c) & 1) == 1:
				continue
			if r < marks.size() and c < (marks[r] as Array).size() and bool(marks[r][c]):
				continue
			out.append(Vector2i(r, c))
	return out


## Explains the next forced cat from the player's current board. `marks` is an
## N x N array of booleans. Returns {ok, row, col, kind, text, solved}.
static func hint(regions: PackedInt32Array, n: int, cats: Array, marks: Array,
		region_names := []) -> Dictionary:
	var state := _state_from(regions, n, cats, marks)
	var state_cats: Array = state["cats"]
	if _contradiction(state, regions, n):
		return {
			"ok": false,
			"reason": "contradiction",
			"text": "Something already on the board breaks a rule. Undo the last cat and look again.",
		}
	if PuzzleModel.count_cats(cats) >= n:
		return {
			"ok": false,
			"reason": "full",
			"text": "Every row has a cat. Check which rule the board is not satisfying.",
		}
	var metrics := {"branches": 0, "max_depth": 0, "forced": 0, "kinds": {}, "max_candidates": n, "trace": []}
	_deduce(state, regions, n, metrics)
	var trace: Array = metrics["trace"]
	var skip := {}
	for r in range(n):
		if int(cats[r]) >= 0 if r < cats.size() else false:
			skip["%d:%d" % [r, int(cats[r])]] = true
	for entry in trace:
		var row := int(entry["row"])
		var col := int(entry["col"])
		if skip.has("%d:%d" % [row, col]):
			continue
		var kind := String(entry["kind"])
		var text := String(KIND_TEXT.get(kind, "One cat is forced here."))
		var reg := regions[row * n + col]
		if region_names.size() > reg:
			text = text.replace("this territory", "the %s" % String(region_names[reg]))
		return {"ok": true, "row": row, "col": col, "kind": kind, "text": text, "solved": false}
	# No forced move: the board needs a short look ahead. Use the unique solution.
	var solution := ExactSolver.solve(regions, n, 1)
	if solution.is_empty():
		return {"ok": false, "reason": "nosolution", "text": "This board has no solution."}
	for r in range(n):
		if int(state_cats[r]) >= 0:
			continue
		return {
			"ok": true,
			"row": r,
			"col": int(solution[0][r]),
			"kind": "lookahead",
			"text": String(KIND_TEXT["lookahead"]),
			"solved": false,
		}
	return {"ok": false, "reason": "full", "text": "The board is full."}


## Replays the unique solution against the player's cats and explains the first
## disagreement, so a wrong guess can be answered without spoiling the rest.
static func explain_conflict(solution: Array, cats: Array) -> String:
	for r in range(mini(solution.size(), cats.size())):
		if int(cats[r]) >= 0 and int(cats[r]) != int(solution[r]):
			return "Row %d's cat cannot sit there: in the finished board its cat belongs in column %d." % [r + 1, int(solution[r]) + 1]
	return ""
