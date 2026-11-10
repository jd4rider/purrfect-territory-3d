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


static func _popcount(value: int) -> int:
	var total := 0
	var v := value
	while v != 0:
		v &= v - 1
		total += 1
	return total
