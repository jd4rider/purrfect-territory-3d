class_name RegionGen
extends RefCounted
## Territory partitioning.
##
## Every strategy starts from the N cells of a chosen solution and grows each
## territory outward from its own cat, which guarantees two things: every
## territory is connected, and every territory contains exactly one solution
## cell. Uniqueness is *not* guaranteed by construction — ExactSolver checks it
## independently, and the factory perturbs boundaries until it holds.

const STYLES := ["organic", "balanced", "drift", "voronoi", "ribbon"]

const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func build(n: int, solution: Array, rng: RandomNumberGenerator, style: String) -> PackedInt32Array:
	var assign := PackedInt32Array()
	assign.resize(n * n)
	assign.fill(-1)
	for r in range(n):
		assign[r * n + int(solution[r])] = r
	if style == "voronoi":
		_voronoi(assign, n, solution, rng)
	elif style == "ribbon":
		_grow(assign, n, rng, "ribbon")
	else:
		_grow(assign, n, rng, style)
	ensure_connected(assign, n, solution)
	return assign


static func _seed_cells(assign: PackedInt32Array, n: int) -> Array:
	var seeds: Array = []
	seeds.resize(n)
	for i in range(assign.size()):
		if assign[i] >= 0:
			seeds[assign[i]] = Vector2i(i / n, i % n)
	return seeds


## Multi-source frontier growth. A cell is only ever claimed from the frontier of
## the territory that claimed its neighbour, so connectivity is structural.
static func _grow(assign: PackedInt32Array, n: int, rng: RandomNumberGenerator, style: String) -> void:
	var seeds := _seed_cells(assign, n)
	var counts := PackedInt32Array()
	counts.resize(n)
	counts.fill(1)
	var cells: Array = []
	var owners: Array = []
	for reg in range(n):
		for step: Vector2i in NEIGHBOURS:
			var nr: int = seeds[reg].x + step.x
			var nc: int = seeds[reg].y + step.y
			if nr < 0 or nc < 0 or nr >= n or nc >= n:
				continue
			if assign[nr * n + nc] != -1:
				continue
			cells.append(nr * n + nc)
			owners.append(reg)
	while not cells.is_empty():
		var pick := -1
		match style:
			"balanced":
				# grow whichever frontier territory is smallest, so the board
				# does not end up with one giant blob and three single tiles
				var best := 1 << 30
				for i in range(cells.size()):
					var owner: int = owners[i]
					if counts[owner] < best:
						best = counts[owner]
				var options: Array = []
				for i in range(cells.size()):
					if counts[owners[i]] == best:
						options.append(i)
				pick = options[rng.randi_range(0, options.size() - 1)]
			"drift":
				# prefer squares nearer the territory's own cat, with noise so
				# the shapes are not perfect diamonds
				var weights: Array = []
				var total := 0.0
				for i in range(cells.size()):
					var owner: int = owners[i]
					var cell_pos := Vector2i(cells[i] / n, cells[i] % n)
					var dist := absi(cell_pos.x - seeds[owner].x) + absi(cell_pos.y - seeds[owner].y)
					var weight := 1.0 / (1.0 + float(dist)) + 0.35 * rng.randf()
					weights.append(weight)
					total += weight
				var roll := rng.randf() * total
				for i in range(cells.size()):
					roll -= weights[i]
					if roll <= 0.0:
						pick = i
						break
				if pick < 0:
					pick = cells.size() - 1
			"ribbon":
				var column_options: Array = []
				for i in range(cells.size()):
					var owner: int = owners[i]
					if cells[i] % n == seeds[owner].y:
						column_options.append(i)
				if not column_options.is_empty() and rng.randf() < 0.7:
					pick = column_options[rng.randi_range(0, column_options.size() - 1)]
				else:
					pick = rng.randi_range(0, cells.size() - 1)
			_:
				pick = rng.randi_range(0, cells.size() - 1)
		var cell_index: int = cells[pick]
		var owner: int = owners[pick]
		cells[pick] = cells[cells.size() - 1]
		owners[pick] = owners[owners.size() - 1]
		cells.pop_back()
		owners.pop_back()
		if assign[cell_index] != -1:
			continue
		assign[cell_index] = owner
		counts[owner] += 1
		var r := cell_index / n
		var c := cell_index % n
		for step: Vector2i in NEIGHBOURS:
			var nr: int = r + step.x
			var nc: int = c + step.y
			if nr < 0 or nc < 0 or nr >= n or nc >= n:
				continue
			if assign[nr * n + nc] != -1:
				continue
			cells.append(nr * n + nc)
			owners.append(owner)


## Nearest-seed assignment with random per-seed weights, then a connectivity
## repair pass. Produces the angular, border-heavy shapes the other styles miss.
static func _voronoi(assign: PackedInt32Array, n: int, solution: Array, rng: RandomNumberGenerator) -> void:
	var seeds := _seed_cells(assign, n)
	var bias: Array = []
	for reg in range(n):
		bias.append(rng.randf_range(0.75, 1.5))
	for r in range(n):
		for c in range(n):
			var best := 0
			var best_score := 1e9
			for reg in range(n):
				var dx := float(r - seeds[reg].x)
				var dy := float(c - seeds[reg].y)
				var score := (dx * dx + dy * dy) * float(bias[reg])
				if score < best_score:
					best_score = score
					best = reg
			assign[r * n + c] = best
	# seeds always keep their own territory
	for r in range(n):
		assign[r * n + int(solution[r])] = r
	ensure_connected(assign, n, solution)


## Repairs any territory that a strategy split in two: unreached cells are
## cleared, then regrown from cells that are already connected to a seed.
static func ensure_connected(assign: PackedInt32Array, n: int, solution: Array) -> void:
	var reached := PackedByteArray()
	reached.resize(n * n)
	reached.fill(0)
	for reg in range(n):
		# region id == the row its cat sits in, so the cell is (row, column)
		var start := reg * n + int(solution[reg])
		var queue: Array = [start]
		reached[start] = 1
		var head := 0
		while head < queue.size():
			var at: int = queue[head]
			head += 1
			var r := at / n
			var c := at % n
			for step: Vector2i in NEIGHBOURS:
				var nr: int = r + step.x
				var nc: int = c + step.y
				if nr < 0 or nc < 0 or nr >= n or nc >= n:
					continue
				var idx := nr * n + nc
				if reached[idx] == 1 or assign[idx] != reg:
					continue
				reached[idx] = 1
				queue.append(idx)
	var cells: Array = []
	var owners: Array = []
	for i in range(n * n):
		if reached[i] == 1:
			continue
		if assign[i] != -1:
			assign[i] = -1
	for i in range(n * n):
		if assign[i] < 0:
			continue
		var r := i / n
		var c := i % n
		for step: Vector2i in NEIGHBOURS:
			var nr: int = r + step.x
			var nc: int = c + step.y
			if nr < 0 or nc < 0 or nr >= n or nc >= n:
				continue
			var idx := nr * n + nc
			if assign[idx] != -1:
				continue
			cells.append(idx)
			owners.append(assign[i])
	var cursor := 0
	while cursor < cells.size():
		var idx: int = cells[cursor]
		var owner: int = owners[cursor]
		cursor += 1
		if assign[idx] != -1:
			continue
		assign[idx] = owner
		var r := idx / n
		var c := idx % n
		for step: Vector2i in NEIGHBOURS:
			var nr: int = r + step.x
			var nc: int = c + step.y
			if nr < 0 or nc < 0 or nr >= n or nc >= n:
				continue
			var next := nr * n + nc
			if assign[next] != -1:
				continue
			cells.append(next)
			owners.append(owner)


## One random legal boundary move: a cell changes to a neighbouring territory.
## The donor territory must stay connected without it, so shapes stay valid.
static func perturb(assign: PackedInt32Array, n: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var copy: PackedInt32Array = assign.duplicate()
	for attempt in range(120):
		var idx := rng.randi_range(0, n * n - 1)
		var r := idx / n
		var c := idx % n
		var from := copy[idx]
		var options: Array = []
		for step: Vector2i in NEIGHBOURS:
			var nr: int = r + step.x
			var nc: int = c + step.y
			if nr < 0 or nc < 0 or nr >= n or nc >= n:
				continue
			var other := copy[nr * n + nc]
			if other != from:
				options.append(other)
		if options.is_empty():
			continue
		var to: int = options[rng.randi_range(0, options.size() - 1)]
		copy[idx] = to
		if _region_connected(copy, n, from):
			return copy
		copy[idx] = from
	return copy


## Targeted uniqueness repair. Finds an alternative solution, picks a cat cell
## that is not part of the intended solution, and moves it into a neighbouring
## territory. That alternative then breaks — it has two cats in one territory —
## while the intended arrangement still holds, because intended solution cells
## are never moved. One move per call, so the caller can re-check cheaply.
static func break_alternative(regions: PackedInt32Array, n: int, solution: Array,
		rng: RandomNumberGenerator) -> PackedInt32Array:
	var sols := ExactSolver.solve(regions, n, 2)
	if sols.size() <= 1:
		return regions
	var alt: Array = sols[0]
	if _same_solution(alt, solution):
		alt = sols[1]
	var keep := {}
	for r in range(n):
		keep[r * n + int(solution[r])] = true
	var options: Array = []
	for r in range(n):
		if not keep.has(r * n + int(alt[r])):
			options.append(Vector2i(r, int(alt[r])))
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = options[i]
		options[i] = options[j]
		options[j] = swap
	for at in options:
		var index := int(at.x) * n + int(at.y)
		var from := regions[index]
		var targets: Array = []
		for step: Vector2i in NEIGHBOURS:
			var nr: int = int(at.x) + step.x
			var nc: int = int(at.y) + step.y
			if nr < 0 or nc < 0 or nr >= n or nc >= n:
				continue
			var other := regions[nr * n + nc]
			if other != from and not targets.has(other):
				targets.append(other)
		for i in range(targets.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap = targets[i]
			targets[i] = targets[j]
			targets[j] = swap
		for to in targets:
			var copy: PackedInt32Array = regions.duplicate()
			copy[index] = int(to)
			if _region_connected(copy, n, from):
				return copy
	return regions


static func _same_solution(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return false
	return true


static func _region_connected(regions: PackedInt32Array, n: int, reg: int) -> bool:
	var start := -1
	var total := 0
	for i in range(n * n):
		if regions[i] == reg:
			total += 1
			if start < 0:
				start = i
	if total == 0:
		return false
	var seen := {}
	var queue: Array = [start]
	seen[start] = true
	var head := 0
	while head < queue.size():
		var at: int = queue[head]
		head += 1
		var r := at / n
		var c := at % n
		for step: Vector2i in NEIGHBOURS:
			var nr: int = r + step.x
			var nc: int = c + step.y
			if nr < 0 or nc < 0 or nr >= n or nc >= n:
				continue
			var idx := nr * n + nc
			if regions[idx] != reg or seen.has(idx):
				continue
			seen[idx] = true
			queue.append(idx)
	return seen.size() == total


static func sizes(regions: PackedInt32Array, n: int) -> Array:
	var counts := PackedInt32Array()
	counts.resize(n)
	counts.fill(0)
	for i in range(n * n):
		counts[regions[i]] += 1
	var out: Array = []
	for value in counts:
		out.append(value)
	out.sort()
	return out


static func boundary_edges(regions: PackedInt32Array, n: int) -> int:
	var total := 0
	for r in range(n):
		for c in range(n):
			if r + 1 < n and regions[r * n + c] != regions[(r + 1) * n + c]:
				total += 1
			if c + 1 < n and regions[r * n + c] != regions[r * n + c + 1]:
				total += 1
	return total
