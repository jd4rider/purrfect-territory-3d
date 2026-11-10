class_name Novelty
extends RefCounted
## Anti-predictability checks.
##
## Boards are compared under all eight symmetries of the square, because a
## rotated or mirrored copy is the same puzzle to a player. Two things are
## measured: whether two boards share the same cat arrangement (canonical
## solution key), and how alike their territory partitions are (size histogram
## plus border count). Colour order is never part of a signature, so repainting
## a board cannot smuggle a repeat through.

## (r, c) -> cell index for the eight symmetries of an N x N square.
static func transform_map(n: int, t: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(n * n)
	for r in range(n):
		for c in range(n):
			var nr := r
			var nc := c
			match t:
				1:
					nr = c
					nc = n - 1 - r
				2:
					nr = n - 1 - r
					nc = n - 1 - c
				3:
					nr = n - 1 - c
					nc = r
				4:
					nc = n - 1 - c
				5:
					nr = n - 1 - r
				6:
					nr = c
					nc = r
				7:
					nr = n - 1 - c
					nc = n - 1 - r
			out[r * n + c] = nr * n + nc
	return out


static func solution_key(solution: Array) -> String:
	var n := solution.size()
	var best := ""
	for t in range(8):
		var map := transform_map(n, t)
		var placed: Array = []
		placed.resize(n)
		placed.fill(-1)
		for r in range(n):
			var c := int(solution[r])
			var idx := map[r * n + c]
			placed[idx / n] = idx % n
		var text := ""
		for value in placed:
			text += String.chr(65 + int(value))
		if best.is_empty() or text < best:
			best = text
	return best


static func region_key(regions: PackedInt32Array, n: int) -> String:
	var best := ""
	for t in range(8):
		var map := transform_map(n, t)
		var relabel := {}
		var next := 0
		var text := ""
		for i in range(n * n):
			var mapped := map[i]
			var reg := regions[mapped]
			if not relabel.has(reg):
				relabel[reg] = next
				next += 1
			text += String.chr(65 + int(relabel[reg]))
		if best.is_empty() or text < best:
			best = text
	return best


## Smallest number of rows whose cat sits in a different column, over all
## symmetries. Zero means the two levels are the same puzzle in disguise.
static func distance(a: Array, b: Array) -> int:
	var n := a.size()
	if b.size() != n or n == 0:
		return 99
	var best := 99
	for t in range(8):
		var map := transform_map(n, t)
		var shifted: Array = []
		shifted.resize(n)
		shifted.fill(-1)
		for r in range(n):
			var c := int(b[r])
			var idx := map[r * n + c]
			shifted[idx / n] = idx % n
		var diff := 0
		for r in range(n):
			if int(a[r]) != int(shifted[r]):
				diff += 1
		best = mini(best, diff)
	return best


static func signature(regions: PackedInt32Array, n: int) -> Dictionary:
	return {
		"sizes": RegionGen.sizes(regions, n),
		"boundary": RegionGen.boundary_edges(regions, n),
	}


## Cheap structural similarity used to keep neighbouring levels from looking
## like recolours of one another.
static func similar(first: Dictionary, second: Dictionary) -> bool:
	# Level metrics call this list "regions"; signature() calls it "sizes".
	var a: Array = first.get("sizes", first.get("regions", []))
	var b: Array = second.get("sizes", second.get("regions", []))
	if a.size() != b.size():
		return false
	var same_sizes := true
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			same_sizes = false
			break
	var border_gap := absi(int(first["boundary"]) - int(second["boundary"]))
	if same_sizes and border_gap <= 2:
		return true
	if border_gap <= 1:
		return true
	return false


## A crude predictability probe for the test suite: the fraction of accepted
## levels whose solution is a one-step shift, flip or parity rule away from the
## previous level. A generator that fools human players has this near 1.
static func predictable_ratio(levels: Array) -> float:
	if levels.size() < 2:
		return 0.0
	var hits := 0
	for i in range(1, levels.size()):
		var previous: Array = levels[i - 1]["solution"]
		var current: Array = levels[i]["solution"]
		if previous.size() != current.size():
			continue
		var shifted := true
		for r in range(current.size()):
			if int(current[r]) != (int(previous[r]) + 1) % current.size():
				shifted = false
				break
		if shifted:
			hits += 1
			continue
		var mirrored := true
		for r in range(current.size()):
			if int(current[r]) != current.size() - 1 - int(previous[r]):
				mirrored = false
				break
		if mirrored:
			hits += 1
	return float(hits) / float(levels.size() - 1)
