class_name PuzzleModel
extends RefCounted
## Board geometry and the four territory rules.
##
## A board is an N x N grid of cells, each cell tagged with a region id 0..N-1.
## A solution is `cats`, an array with one column per row (-1 for "no cat"), so
## the row rule is structural: there is exactly one entry per row.

static func cell(n: int, r: int, c: int) -> int:
	return r * n + c


static func region_cells(regions: PackedInt32Array, n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append([])
	for r in range(n):
		for c in range(n):
			(out[regions[r * n + c]] as Array).append(Vector2i(r, c))
	return out


static func count_cats(cats: Array) -> int:
	var total := 0
	for r in range(cats.size()):
		if int(cats[r]) >= 0:
			total += 1
	return total


## Full rule check used by the win condition and the tests. The board is only
## solved when all four rules hold, never because a stored arrangement matched.
static func validate(regions: PackedInt32Array, n: int, cats: Array) -> Dictionary:
	var result := {
		"ok": false,
		"reason": "",
		"rows": true,
		"columns": true,
		"regions": true,
		"touching": true,
	}
	if cats.size() != n:
		result["reason"] = "wrong number of rows"
		return result
	var columns := {}
	var region_used := {}
	var by_column := {}
	var by_region := {}
	var positions: Array = []
	for r in range(n):
		var c := int(cats[r])
		if c < 0:
			result["rows"] = false
			result["reason"] = "row %d has no cat" % (r + 1)
			continue
		if c >= n:
			result["rows"] = false
			result["reason"] = "row %d is off the board" % (r + 1)
			continue
		positions.append(Vector2i(r, c))
		var col_key := str(c)
		if by_column.has(col_key):
			result["columns"] = false
			result["reason"] = "column %d has two cats" % (c + 1)
		by_column[col_key] = true
		var reg := regions[r * n + c]
		if by_region.has(reg):
			result["regions"] = false
			result["reason"] = "territory %d has two cats" % (reg + 1)
		by_region[reg] = true
		region_used[reg] = true
		columns[c] = true
	# every territory needs a cat; with N cats and N territories that is implied,
	# but check it explicitly so a partial board can never report a win.
	for reg in range(n):
		if not region_used.has(reg):
			result["regions"] = false
			result["reason"] = "territory %d has no cat" % (reg + 1)
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var a: Vector2i = positions[i]
			var b: Vector2i = positions[j]
			if absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1:
				result["touching"] = false
				result["reason"] = "two cats touch"
				result["ok"] = false
				return result
	if not (result["rows"] and result["columns"] and result["regions"] and result["touching"]):
		if String(result["reason"]).is_empty():
			result["reason"] = "rules not satisfied"
		return result
	result["ok"] = true
	result["reason"] = "solved"
	return result


## Regions must be orthogonally connected, or the board is not a real Star
## Battle-style puzzle and the colour blobs look broken.
static func regions_connected(regions: PackedInt32Array, n: int) -> bool:
	var cells := region_cells(regions, n)
	for reg in range(n):
		var list: Array = cells[reg]
		if list.is_empty():
			return false
		var seen := {}
		var queue: Array = [list[0]]
		seen[cell(n, list[0].x, list[0].y)] = true
		var head := 0
		while head < queue.size():
			var at: Vector2i = queue[head]
			head += 1
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nr: int = at.x + step.x
				var nc: int = at.y + step.y
				if nr < 0 or nc < 0 or nr >= n or nc >= n:
					continue
				if regions[nr * n + nc] != reg:
					continue
				var key: int = nr * n + nc
				if seen.has(key):
					continue
				seen[key] = true
				queue.append(Vector2i(nr, nc))
		if seen.size() != list.size():
			return false
	return true
