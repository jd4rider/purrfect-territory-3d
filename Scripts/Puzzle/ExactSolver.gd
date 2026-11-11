class_name ExactSolver
extends RefCounted
## Independent exact solution counter.
##
## It knows nothing about how a board was generated: it takes the region grid
## and enumerates every legal cat arrangement, stopping after `limit`. A board is
## only allowed to ship when this returns exactly 1. This is deliberately a
## separate implementation from HumanSolver so a bug in one cannot mask a bug in
## the other.

static func count(regions: PackedInt32Array, n: int, limit := 2) -> int:
	return solve(regions, n, limit).size()


static func solve(regions: PackedInt32Array, n: int, limit := 2) -> Array:
	var solutions: Array = []
	var row_masks := PackedInt32Array()
	row_masks.resize(n)
	row_masks.fill(0)
	var region_masks := PackedInt32Array()
	region_masks.resize(n)
	region_masks.fill(0)
	for r in range(n):
		for c in range(n):
			row_masks[r] |= 1 << c
			region_masks[regions[r * n + c]] |= 1 << c

	var region_rows: Array = []
	for reg in range(n):
		var rows := 0
		for r in range(n):
			for c in range(n):
				if regions[r * n + c] == reg:
					rows |= 1 << r
		region_rows.append(rows)

	_dfs(0, -2, 0, 0, n, regions, row_masks, region_masks, region_rows, limit, [], solutions)
	return solutions


static func _dfs(r: int, prev_col: int, used_cols: int, used_regions: int, n: int,
		regions: PackedInt32Array, row_masks: PackedInt32Array, region_masks: PackedInt32Array,
		region_rows: Array, limit: int, acc: Array, solutions: Array) -> void:
	if solutions.size() >= limit:
		return
	if r == n:
		var found: Array = []
		for value in acc:
			found.append(value)
		solutions.append(found)
		return
	# Every remaining region needs at least one square in an unused column.
	var remaining := (1 << n) - 1
	remaining &= ~used_cols
	for reg in range(n):
		if (used_regions >> reg) & 1:
			continue
		if region_masks[reg] & remaining == 0:
			return
	# Every remaining row needs at least one free column.
	if n - r > _popcount(remaining):
		return
	for c in range(n):
		if (((row_masks[r] >> c) & 1) == 0):
			continue
		if (used_cols >> c) & 1:
			continue
		if absi(c - prev_col) <= 1:
			continue
		var reg := regions[r * n + c]
		if (used_regions >> reg) & 1:
			continue
		acc.append(c)
		_dfs(r + 1, c, used_cols | (1 << c), used_regions | (1 << reg), n,
			regions, row_masks, region_masks, region_rows, limit, acc, solutions)
		acc.pop_back()
		if solutions.size() >= limit:
			return


## True when the cats already on the tray can still grow into a full board.
##
## Every shipped board has exactly one arrangement, so a cat that is legal
## square by square but wrong still counts as "no completion left": the puzzle
## could never be finished and the player needs to be told which cat it was.
static func has_completion(regions: PackedInt32Array, n: int, cats: Array) -> bool:
	if regions.size() < n * n:
		return false
	var fixed := PackedInt32Array()
	fixed.resize(n)
	fixed.fill(-1)
	# The prefix is only checked for self-consistency here; the search below
	# re-walks every row from scratch, so it must not start out pre-used.
	var taken_cols := 0
	var taken_regions := 0
	for r in range(n):
		var c := int(cats[r]) if r < cats.size() else -1
		if c < -1 or c >= n:
			return false
		fixed[r] = c
		if c < 0:
			continue
		if (taken_cols >> c) & 1:
			return false
		var reg := regions[r * n + c]
		if (taken_regions >> reg) & 1:
			return false
		taken_cols |= 1 << c
		taken_regions |= 1 << reg
	# Where each territory sits, so a dead branch is cut before it is walked.
	var region_cols := PackedInt32Array()
	var region_rows := PackedInt32Array()
	region_cols.resize(n)
	region_rows.resize(n)
	region_cols.fill(0)
	region_rows.fill(0)
	for r in range(n):
		for c in range(n):
			var reg := regions[r * n + c]
			region_cols[reg] |= 1 << c
			region_rows[reg] |= 1 << r
	for r in range(1, n):
		var a := int(fixed[r - 1])
		var b := int(fixed[r])
		if a >= 0 and b >= 0 and absi(a - b) <= 1:
			return false
	return _complete(0, -2, 0, 0, n, regions, fixed, region_cols, region_rows)


static func _complete(r: int, prev_col: int, used_cols: int, used_regions: int, n: int,
		regions: PackedInt32Array, fixed: PackedInt32Array, region_cols: PackedInt32Array,
		region_rows: PackedInt32Array) -> bool:
	if r == n:
		return true
	var rows_left := 0
	for rr in range(r, n):
		rows_left |= 1 << rr
	var free_cols := ((1 << n) - 1) & ~used_cols
	for reg in range(n):
		if (used_regions >> reg) & 1:
			continue
		if region_rows[reg] & rows_left == 0:
			return false
		if region_cols[reg] & free_cols == 0:
			return false
	if n - r > _popcount(free_cols):
		return false
	var only := int(fixed[r])
	if only >= 0:
		if (used_cols >> only) & 1 or absi(only - prev_col) <= 1:
			return false
		var reg := regions[r * n + only]
		if (used_regions >> reg) & 1:
			return false
		return _complete(r + 1, only, used_cols | (1 << only), used_regions | (1 << reg),
			n, regions, fixed, region_cols, region_rows)
	for c in range(n):
		if (free_cols >> c) & 1 == 0:
			continue
		if absi(c - prev_col) <= 1:
			continue
		var reg := regions[r * n + c]
		if (used_regions >> reg) & 1:
			continue
		if _complete(r + 1, c, used_cols | (1 << c), used_regions | (1 << reg),
				n, regions, fixed, region_cols, region_rows):
			return true
	return false


static func _popcount(value: int) -> int:
	var total := 0
	var v := value
	while v != 0:
		v &= v - 1
		total += 1
	return total
