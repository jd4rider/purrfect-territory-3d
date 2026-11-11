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
	_test_audio()
	_test_powerups()
	_test_doomed_cats()
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


func _test_powerups() -> void:
	var backup: Dictionary = Save.data.duplicate(true)
	var now := int(Time.get_unix_time_from_system())
	Save.data["powerups"] = {
		"cat": {"count": 1, "at": now},
		"clue": {"count": Save.POWERUP_MAX, "at": now},
		"mouse": {"count": 0, "at": now - Save.POWERUP_INTERVAL * 2},
	}
	Save._settle_powerups()
	ok(Save.powerup_count("mouse") == 2, "power-ups refill one charge every interval")
	ok(Save.powerup_count("clue") == Save.POWERUP_MAX, "power-ups never exceed the cap")
	ok(Save.consume_powerup("cat"), "a charge can be spent")
	ok(Save.powerup_count("cat") == 0, "spending a charge decrements the stock")
	ok(not Save.consume_powerup("cat"), "an empty power-up cannot be spent")
	ok(Save.powerup_seconds_left("cat") > 0, "an empty power-up counts down to a refill")
	ok(Save.powerup_seconds_left("clue") == 0, "a full power-up has no countdown")
	Save.grant_powerup("cat", 9)
	ok(Save.powerup_count("cat") == Save.POWERUP_MAX, "grants stop at the cap")
	Save.data = backup

	var level := Levels.get_level(1)
	var n := int(level["n"])
	var regions := LevelFactory.from_array(level["regions"])
	var solution: Array = level["solution"]
	var cats: Array = []
	var marks: Array = []
	for r in range(n):
		cats.append(-1)
		var row: Array = []
		for c in range(n):
			row.append(false)
		marks.append(row)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var cat_pick := PowerUps.hidden_cat(regions, n, cats, solution, rng)
	ok(cat_pick.x >= 0 and cat_pick.y == int(solution[cat_pick.x]),
		"the cat power-up unearths a real cat")
	# A true cat revealed next to the player's own cat would put a board on
	# screen that breaks the no-touching rule, so those rows must be skipped.
	var wrong := cats.duplicate()
	wrong[1] = int(solution[1]) + 1 if int(solution[1]) + 1 < n else int(solution[1]) - 1
	var revealed_conflict := false
	for seed_value in range(40):
		var probe := RandomNumberGenerator.new()
		probe.seed = 1000 + seed_value
		var candidate := PowerUps.hidden_cat(regions, n, wrong, solution, probe)
		if candidate.x == 0:
			revealed_conflict = true
			break
		if candidate.x > 0 and PowerUps.conflicts(regions, n, wrong, candidate.x, candidate.y):
			revealed_conflict = true
			break
	ok(not revealed_conflict, "the cat power-up never reveals a cat that would break a rule")
	var bad := 0
	for at: Vector2i in HumanSolver.excluded_cells(regions, n, cats, marks):
		if int(solution[at.x]) == at.y:
			bad += 1
	ok(bad == 0, "human exclusions never rule out a cat")
	var mouse_ok := true
	for i in range(5):
		var pick := PowerUps.safe_mark(regions, n, cats, marks, solution, rng)
		if pick.x < 0 or int(solution[pick.x]) == pick.y:
			mouse_ok = false
			break
		marks[pick.x][pick.y] = true
	ok(mouse_ok, "the mouse only crosses out squares with no cat")


## The completion check is what lets the game spot a cat that obeys every rule
## but still makes the puzzle impossible.
func _test_doomed_cats() -> void:
	var level := Levels.get_level(7)
	var n := int(level["n"])
	var regions := LevelFactory.from_array(level["regions"])
	var solution: Array = level["solution"]
	var cats: Array = []
	for r in range(n):
		cats.append(-1)
	ok(ExactSolver.has_completion(regions, n, cats), "an empty tray still has a completion")
	ok(ExactSolver.has_completion(regions, n, solution), "the stored solution counts as complete")
	# The first square that obeys the rules but is not the answer.
	var wrong_row := -1
	var wrong_col := -1
	for r in range(n):
		for c in range(n):
			if c == int(solution[r]):
				continue
			if PowerUps.conflicts(regions, n, cats, r, c):
				continue
			wrong_row = r
			wrong_col = c
			break
		if wrong_row >= 0:
			break
	ok(wrong_row >= 0, "level 7 offers a legal square that is not the answer")
	if wrong_row >= 0:
		cats[wrong_row] = wrong_col
		ok(not ExactSolver.has_completion(regions, n, cats),
			"a legal cat that is not the answer is flagged as unfinishable")
		cats[wrong_row] = -1
		cats[0] = int(solution[0])
		ok(ExactSolver.has_completion(regions, n, cats), "a true cat keeps the board finishable")
	# On a board with a single answer, a prefix can be completed exactly when it
	# is part of that answer. Check every single cat at n = 4 and 5.
	for size in [4, 5]:
		var built := LevelFactory.produce(size, 777 + size, [])
		if not bool(built["ok"]):
			ok(false, "producer failed while checking completions at n=%d" % size)
			continue
		var probe_level: Dictionary = built["level"]
		var probe_regions := LevelFactory.from_array(probe_level["regions"])
		var probe_solution: Array = probe_level["solution"]
		var probe: Array = []
		for r in range(size):
			probe.append(-1)
		var disagree := 0
		for r in range(size):
			for c in range(size):
				probe[r] = c
				var truth := c == int(probe_solution[r])
				if ExactSolver.has_completion(probe_regions, size, probe) != truth:
					disagree += 1
			probe[r] = -1
		ok(disagree == 0, "completion check matches the true answer at n=%d (%d wrong)" % [size, disagree])
	# Only the real answer survives a full tray.
	var full := solution.duplicate()
	full[int(n / 2)] = int(solution[int(n / 2)]) + 1 if int(solution[int(n / 2)]) + 1 < n else 0
	ok(not ExactSolver.has_completion(regions, n, full),
		"a complete tray with one cat moved has no completion")


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
	ok(Chapters.count() == 10, "there are ten chapters")
	ok(Chapters.size_for(1) == 4, "level one is a 4x4 tutorial")
	ok(Chapters.chapter_of(1000) == 9, "level 1000 is in the last chapter")


func _test_audio() -> void:
	var bed := Audio._looped(Audio.MUSIC_DIR + "focus.wav")
	ok(bed != null, "the focus bed loads")
	ok(is_same(Audio._looped(Audio.MUSIC_DIR + "focus.wav"), bed), "the looped bed is cached, not rebuilt")
	Audio.play_music("focus")
	var stream := Audio._music.stream
	Audio.play_music("focus")
	ok(is_same(Audio._music.stream, stream), "re-requesting the running bed keeps the same stream")
	Audio.kick()
	ok(is_same(Audio._music.stream, stream), "a tap does not restart the running bed")
	Audio.play_music("cozy")
	ok(not is_same(Audio._music.stream, stream), "changing mood swaps the bed")
	Audio.stop_music()
	ok(not Audio._music.playing, "stopping music halts the bed")
