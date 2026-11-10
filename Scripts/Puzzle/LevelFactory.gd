class_name LevelFactory
extends RefCounted
## Builds one board and proves it before handing it out.
##
## Order matters: pick a cat arrangement from a broad random sample, grow
## territories from it, then let ExactSolver count solutions. Boards with more
## than one answer are repaired by boundary moves, and boards that survive are
## still run through HumanSolver so every shipped level has a recorded logical
## solution path.

const MAX_ATTEMPTS := 45


static func random_solution(n: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	_collect(n, 0, -2, 0, [], pool, rng, 64)
	if pool.is_empty():
		return []
	return (pool[rng.randi_range(0, pool.size() - 1)] as Array).duplicate()


static func _collect(n: int, r: int, prev: int, used: int, acc: Array, pool: Array,
		rng: RandomNumberGenerator, cap: int) -> void:
	if pool.size() >= cap:
		return
	if r == n:
		pool.append(acc.duplicate())
		return
	var columns: Array = []
	for c in range(n):
		columns.append(c)
	for i in range(columns.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = columns[i]
		columns[i] = columns[j]
		columns[j] = swap
	for c in columns:
		if (used >> int(c)) & 1:
			continue
		if absi(int(c) - prev) <= 1:
			continue
		acc.append(c)
		_collect(n, r + 1, int(c), used | (1 << int(c)), acc, pool, rng, cap)
		acc.pop_back()
		if pool.size() >= cap:
			return


## Produces {ok, level, attempts, ms}. `require` is an optional array of
## difficulty names the caller will accept; an empty array accepts any tier.
static func produce(n: int, seed: int, require := [], style := "", budget_ms := 2500) -> Dictionary:
	var started := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	for attempt in range(MAX_ATTEMPTS):
		if Time.get_ticks_msec() - started > budget_ms:
			break
		rng.seed = int(seed) * 2654435761 + attempt * 40503
		var solution := random_solution(n, rng)
		if solution.is_empty():
			continue
		var chosen_style := style
		if chosen_style.is_empty():
			chosen_style = RegionGen.STYLES[attempt % RegionGen.STYLES.size()]
		var regions := RegionGen.build(n, solution, rng, chosen_style)
		if not PuzzleModel.regions_connected(regions, n):
			continue
		if not _one_per_region(regions, n, solution):
			continue
		# Kill alternative solutions one at a time, then require a single answer.
		var tries := 0
		while tries < 10:
			var sols := ExactSolver.solve(regions, n, 2)
			if sols.size() == 1:
				break
			if sols.is_empty():
				break
			var next := RegionGen.break_alternative(regions, n, solution, rng)
			if next == regions:
				regions = RegionGen.perturb(regions, n, rng)
			else:
				regions = next
			tries += 1
		if ExactSolver.count(regions, n, 2) != 1:
			continue
		var human := HumanSolver.solve(regions, n)
		if not bool(human["solved"]):
			continue
		if not _same(human["solution"], solution):
			continue
		var difficulty := String(human["difficulty"])
		if not require.is_empty() and not require.has(difficulty):
			continue
		var level := {
			"id": 0,
			"n": n,
			"seed": int(seed),
			"style": chosen_style,
			"difficulty": difficulty,
			"solution": solution,
			"regions": _to_array(regions),
			"metrics": {
				"branches": int((human["metrics"] as Dictionary)["branches"]),
				"depth": int((human["metrics"] as Dictionary)["max_depth"]),
				"forced": int((human["metrics"] as Dictionary)["forced"]),
				"kinds": (human["metrics"] as Dictionary)["kinds"],
				"regions": RegionGen.sizes(regions, n),
				"boundary": RegionGen.boundary_edges(regions, n),
			},
		}
		return {"ok": true, "level": level, "attempts": attempt + 1, "ms": Time.get_ticks_msec() - started}
	return {"ok": false, "level": {}, "attempts": MAX_ATTEMPTS, "ms": Time.get_ticks_msec() - started}


static func _one_per_region(regions: PackedInt32Array, n: int, solution: Array) -> bool:
	var used := {}
	for r in range(n):
		var reg := regions[r * n + int(solution[r])]
		if used.has(reg):
			return false
		used[reg] = true
	return used.size() == n


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return false
	return true


static func _to_array(regions: PackedInt32Array) -> Array:
	var out: Array = []
	for value in regions:
		out.append(int(value))
	return out


static func from_array(values: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for value in values:
		out.append(int(value))
	return out
