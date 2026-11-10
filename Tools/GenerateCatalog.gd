extends SceneTree
## Builds the shipped campaign: 1,000 uniquely solvable, human-solvable boards,
## each checked for novelty against everything already accepted.
##
##   godot --headless --path . -s Tools/GenerateCatalog.gd
##
## Output is Data/levels.json. CI never regenerates it; it validates the file.

const OUT_PATH := "res://Data/levels.json"


## How far apart two boards may repeat the same cat arrangement. Small boards
## have only a handful of legal arrangements at all (4x4 has two, 5x5 fourteen,
## 6x6 ninety), so demanding more than the size can offer would leave holes.
static func reuse_window(n: int) -> int:
	if n <= 5:
		return 6
	if n == 6:
		return 14
	if n == 7:
		return 45
	if n == 8:
		return 110
	return 160


func _init() -> void:
	var started := Time.get_ticks_msec()
	var levels: Array = []
	var solution_keys := {}
	var region_keys := {}
	var recent: Array = []
	var attempts_total := 0
	var tier_counts := {}
	var size_counts := {}
	var rejects := {"solution": 0, "region": 0, "distance": 0, "shape": 0, "failed": 0}

	for id in range(1, Chapters.level_count() + 1):
		var chapter := Chapters.chapter_of(id)
		var n := Chapters.size_for(id)
		var tiers: Array = Chapters.tiers_for(chapter)
		var index := (id - 1) % Chapters.LEVELS_PER_CHAPTER
		var target := String(tiers[index % tiers.size()])
		var made: Dictionary = {}
		var phases: Array = [[target], tiers, []]
		for phase in range(phases.size()):
			var require: Array = phases[phase]
			var budget := 5 if phase == 0 else 4
			for attempt in range(budget):
				attempts_total += 1
				var seed_value := id * 7919 + phase * 104729 + attempt * 65537
				var result := LevelFactory.produce(n, seed_value, require)
				if not bool(result["ok"]):
					rejects["failed"] = int(rejects["failed"]) + 1
					continue
				var candidate: Dictionary = result["level"]
				var skey := Novelty.solution_key(candidate["solution"])
				var rkey := Novelty.region_key(LevelFactory.from_array(candidate["regions"]), n)
				# Small boards have very few legal arrangements, so the anti-repeat
				# window is bounded: the same arrangement may return once it is far
				# away from the player. Region partitions have a wider window.
				if solution_keys.has(skey) and id - int(solution_keys[skey]) < reuse_window(n):
					rejects["solution"] = int(rejects["solution"]) + 1
					continue
				if region_keys.has(rkey) and id - int(region_keys[rkey]) < 400:
					rejects["region"] = int(rejects["region"]) + 1
					continue
				var too_close := false
				var too_similar := false
				for other in recent:
					if int(other["n"]) != n:
						continue
					if Novelty.distance(candidate["solution"], other["solution"]) < maxi(2, n / 3):
						too_close = true
						break
					if Novelty.similar(candidate["metrics"], other["metrics"]):
						too_similar = true
						break
				if too_close:
					rejects["distance"] = int(rejects["distance"]) + 1
					continue
				if too_similar:
					rejects["shape"] = int(rejects["shape"]) + 1
					continue
				solution_keys[skey] = id
				region_keys[rkey] = id
				candidate["id"] = id
				candidate["chapter"] = chapter
				candidate["title"] = Chapters.title_for(id)
				candidate["colors"] = Chapters.colors_for(id, n)
				made = candidate
			if not made.is_empty():
				break
		if made.is_empty():
			# A hole in a 1,000-level campaign is worse than a near-neighbour.
			# Keep the board, drop only the strict distance preference.
			for fallback in range(30):
				attempts_total += 1
				var result := LevelFactory.produce(n, id * 104729 + fallback * 7919, [])
				if not bool(result["ok"]):
					continue
				var candidate: Dictionary = result["level"]
				var skey := Novelty.solution_key(candidate["solution"])
				if solution_keys.has(skey) and id - int(solution_keys[skey]) < reuse_window(n):
					continue
				solution_keys[skey] = id
				candidate["id"] = id
				candidate["chapter"] = chapter
				candidate["title"] = Chapters.title_for(id)
				candidate["colors"] = Chapters.colors_for(id, n)
				made = candidate
				break
		if made.is_empty():
			push_error("could not build level %d" % id)
			continue
		levels.append(made)
		var difficulty := String(made["difficulty"])
		tier_counts[difficulty] = int(tier_counts.get(difficulty, 0)) + 1
		size_counts[str(n)] = int(size_counts.get(str(n), 0)) + 1
		recent.append(made)
		if recent.size() > 90:
			recent.pop_front()
		if levels.size() % 10 == 0:
			print("  %4d levels  %6.1fs  %s" % [
				levels.size(), (Time.get_ticks_msec() - started) / 1000.0, str(tier_counts)])

	var payload := {
		"version": 1,
		"generated": Time.get_datetime_string_from_system(),
		"chapters": [],
		"levels": levels,
	}
	for i in range(Chapters.count()):
		var chapter := Chapters.get_chapter(i)
		payload["chapters"].append({
			"name": chapter["name"],
			"blurb": chapter["blurb"],
		})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Data"))
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % OUT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("wrote %s" % OUT_PATH)
	print("levels %d  attempts %d  %.1fs" % [levels.size(), attempts_total, elapsed])
	print("difficulties %s" % str(tier_counts))
	print("sizes %s" % str(size_counts))
	print("rejects %s" % str(rejects))
	print("predictable ratio %.3f" % Novelty.predictable_ratio(levels))
	quit()
