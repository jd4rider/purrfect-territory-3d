extends Node
## Headless suite: rules, solver agreement, catalog validation, novelty gates,
## hints and the save schema.
##
##   godot --headless --path . Scenes/Tests.tscn

var checks := 0
var failures: Array = []


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_test_rules()
	_test_solver_agreement()
	_test_generation()
	_test_catalog()
	_test_novelty()
	_test_hints()
	_test_save()
	print("%d checks, %d failures, %d ms" % [checks, failures.size(), Time.get_ticks_msec() - started])
	for failure in failures.slice(0, 30):
		print("FAIL: ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


# --------------------------------------------------------------------------

func _test_rules() -> void:
	var n := 4
	var regions := PackedInt32Array([1, 0, 0, 2, 1, 1, 2, 2, 1, 1, 2, 2, 1, 1, 3, 2])
	var solved := PuzzleModel.validate(regions, n, [1, 3, 0, 2])
	ok(bool(solved["ok"]), "the known 4x4 board validates")
	ok(not bool(PuzzleModel.validate(regions, n, [1, 3, 0, 1])["ok"]), "a repeated column is rejected")
	ok(not bool(PuzzleModel.validate(regions, n, [1, 0, 3, 2])["ok"]), "touching cats are rejected")
	ok(not bool(PuzzleModel.validate(regions, n, [1, 3, -1, 2])["ok"]), "an empty row is rejected")
	var two_regions := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1])
	ok(not bool(PuzzleModel.validate(two_regions, n, [1, 3, 0, 2])["ok"]), "a territory with two cats is rejected")
	ok(PuzzleModel.regions_connected(regions, n), "the known board's territories are connected")
	ok(not PuzzleModel.regions_connected(two_regions, n), "a disconnected territory is spotted")


func _brute(regions: PackedInt32Array, n: int) -> Array:
	var out: Array = []
	var total := int(pow(n, n))
	for code in range(total):
		var cats: Array = []
		var value := code
		for r in range(n):
			cats.append(value % n)
			value /= n
		if bool(PuzzleModel.validate(regions, n, cats)["ok"]):
			out.append(cats)
	return out


func _test_solver_agreement() -> void:
	# For every board the generator makes at small sizes, the exact solver must
	# agree with exhaustive enumeration. This is the test that would catch a
	# regression in the pruning logic.
	for n in [4, 5]:
		for i in range(3):
			var built := LevelFactory.produce(n, 1000 + n * 100 + i, [])
			if not bool(built["ok"]):
				ok(false, "producer failed for n=%d" % n)
				continue
			var level: Dictionary = built["level"]
			var regions := LevelFactory.from_array(level["regions"])
			var brute := _brute(regions, n)
			var exact := ExactSolver.count(regions, n, 5)
			ok(brute.size() == exact, "exact solver matches brute force at n=%d (brute %d, exact %d)" % [n, brute.size(), exact])
			ok(brute.size() == 1, "generated n=%d board is unique by brute force" % n)


func _test_generation() -> void:
	for n in [5, 6, 7, 8]:
		for i in range(2):
			var built := LevelFactory.produce(n, 4200 + n * 31 + i, [])
			ok(bool(built["ok"]), "producer builds n=%d" % n)
			if not bool(built["ok"]):
				continue
			var level: Dictionary = built["level"]
			var regions := LevelFactory.from_array(level["regions"])
			ok(PuzzleModel.regions_connected(regions, n), "generated n=%d regions are connected" % n)
			ok(ExactSolver.count(regions, n, 2) == 1, "generated n=%d board is unique" % n)
			var human := HumanSolver.solve(regions, n)
			ok(bool(human["solved"]), "human solver solves n=%d" % n)
			ok(_same(human["solution"], level["solution"]), "human solution matches the seeded solution at n=%d" % n)
			ok(int((level["metrics"] as Dictionary)["boundary"]) > 0, "generated board has territory borders")


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return false
	return true


func _test_catalog() -> void:
	ok(Levels.levels.size() == Chapters.level_count(),
		"catalog has exactly %d levels (found %d)" % [Chapters.level_count(), Levels.levels.size()])
	var difficulties := {}
	var sizes := {}
	var exact_failures := 0
	var human_failures := 0
	var connectivity_failures := 0
	var color_failures := 0
	for level in Levels.levels:
		var id := int(level["id"])
		var n := int(level["n"])
		var regions := LevelFactory.from_array(level["regions"])
		sizes[str(n)] = int(sizes.get(str(n), 0)) + 1
		difficulties[String(level["difficulty"])] = int(difficulties.get(String(level["difficulty"]), 0)) + 1
		if not PuzzleModel.regions_connected(regions, n):
			connectivity_failures += 1
		if (level["colors"] as Array).size() != n:
			color_failures += 1
		if ExactSolver.count(regions, n, 2) != 1:
			exact_failures += 1
		var human := HumanSolver.solve(regions, n)
		if not bool(human["solved"]) or not _same(human["solution"], level["solution"]):
			human_failures += 1
	ok(exact_failures == 0, "every catalog level has exactly one solution (%d bad)" % exact_failures)
	ok(human_failures == 0, "every catalog level has a human-style solution (%d bad)" % human_failures)
	ok(connectivity_failures == 0, "every catalog territory is connected (%d bad)" % connectivity_failures)
	ok(color_failures == 0, "every catalog level has a colour per territory (%d bad)" % color_failures)
	print("catalog difficulties ", difficulties)
	print("catalog sizes ", sizes)
	var ids_ok := true
	for index in range(Levels.levels.size()):
		if int(Levels.levels[index]["id"]) != index + 1:
			ids_ok = false
			break
	ok(ids_ok, "catalog ids run 1..1000 in order")
	ok(int(sizes.get("10", 0)) >= 20, "the campaign includes 10x10 boards")
	ok(int(sizes.get("4", 0)) <= 2, "tiny 4x4 boards are used sparingly")


func _test_novelty() -> void:
	var keys := {}
	var duplicates := 0
	for level in Levels.levels:
		var key := Novelty.solution_key(level["solution"])
		var n := int(level["n"])
		var window := 6 if n <= 5 else 14 if n == 6 else 45 if n == 7 else 110
		if keys.has(key) and int(level["id"]) - int(keys[key]) < window:
			duplicates += 1
		keys[key] = int(level["id"])
	ok(duplicates == 0, "no cat arrangement repeats inside its window (%d repeats)" % duplicates)
	var ratio := Novelty.predictable_ratio(Levels.levels)
	ok(ratio < 0.05, "a simple shift/mirror rule predicts under 5%% of levels (%.3f)" % ratio)
	ok(Novelty.distance([1, 3, 0, 2], [2, 0, 3, 1]) == 0, "mirrors count as the same arrangement")
	ok(Novelty.distance([1, 3, 0, 2], [1, 3, 0, 2]) == 0, "identical arrangements are distance zero")
	ok(Novelty.solution_key([1, 3, 0, 2]) == Novelty.solution_key([2, 0, 3, 1]),
		"the two 4x4 arrangements canonicalise together")


func _test_hints() -> void:
	var level := Levels.get_level(1)
	var n := int(level["n"])
	var regions := LevelFactory.from_array(level["regions"])
	var cats: Array = []
	var marks: Array = []
	for r in range(n):
		cats.append(-1)
		var row: Array = []
		for c in range(n):
			row.append(false)
		marks.append(row)
	var hint := HumanSolver.hint(regions, n, cats, marks)
	ok(bool(hint.get("ok", false)), "a hint is available on an empty board")
	if bool(hint.get("ok", false)):
		ok(not String(hint["text"]).is_empty(), "the hint explains itself")
		ok(int(hint["row"]) >= 0 and int(hint["col"]) >= 0, "the hint has a square")
	ok(HumanSolver.hint(regions, n, cats, marks, Chapters.region_names(0)).has("text"),
		"hint text survives region names")


func _test_save() -> void:
	var defaults := Save._defaults()
	ok(int(defaults["schema"]) == Save.SCHEMA_VERSION, "save schema version is set")
	ok((defaults["settings"] as Dictionary).has("reduced_motion"), "comfort settings exist")
	var merged := Save._merge({"progress": {"stars": {"4": 3}}}, defaults)
	ok(int((merged["progress"]["stars"] as Dictionary).get("4", 0)) == 3, "a save merges without losing stars")
	ok((merged["settings"] as Dictionary).has("music"), "a merge restores missing settings")
	ok(Save.ACHIEVEMENTS.size() >= 30, "there are at least 30 trophies")
	var stars_before := Save.total_stars()
	ok(stars_before >= 0, "star total is readable")
	ok(Chapters.level_count() == 1000, "the campaign is 1,000 levels")
	ok(Chapters.size() == 10, "there are ten chapters")
	ok(Chapters.size_for(1) == 4, "level one is a 4x4 tutorial")
	ok(Chapters.chapter_of(1000) == 9, "level 1000 is in the last chapter")
