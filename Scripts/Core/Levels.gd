extends Node
## Campaign catalog plus the two runtime-generated modes.
##
## The 1,000 campaign boards are generated once by Tools/GenerateCatalog.gd and
## committed, so loading is instant and CI can validate exactly what ships.
## Daily and practice boards are built on the device from a seed; both use the
## same factory, so they are uniqueness-checked like everything else.

const CATALOG_PATH := "res://Data/levels.json"

var levels: Array = []
var chapters: Array = []
var _by_id: Dictionary = {}
var _daily: Dictionary = {}
var _daily_key := ""
var _practice_count := 0


func _ready() -> void:
	load_catalog()


func load_catalog() -> void:
	levels.clear()
	_by_id.clear()
	chapters.clear()
	if FileAccess.file_exists(CATALOG_PATH):
		var text := FileAccess.get_file_as_string(CATALOG_PATH)
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			var payload: Dictionary = parsed
			chapters = payload.get("chapters", [])
			var raw: Array = payload.get("levels", [])
			for entry in raw:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var level := _normalise(entry)
				levels.append(level)
				_by_id[int(level["id"])] = level
	if levels.is_empty():
		_build_fallback()
	if chapters.is_empty():
		for i in range(Chapters.count()):
			var chapter := Chapters.get_chapter(i)
			chapters.append({"name": chapter["name"], "blurb": chapter["blurb"]})


## JSON numbers arrive as floats; the board code wants ints everywhere.
func _normalise(entry: Dictionary) -> Dictionary:
	var level := entry.duplicate(true)
	level["id"] = int(level.get("id", 0))
	level["n"] = int(level.get("n", 5))
	level["chapter"] = int(level.get("chapter", 0))
	var solution: Array = []
	for value in level.get("solution", []):
		solution.append(int(value))
	level["solution"] = solution
	var regions: Array = []
	for value in level.get("regions", []):
		regions.append(int(value))
	level["regions"] = regions
	if not level.has("colors") or (level["colors"] as Array).is_empty():
		level["colors"] = Chapters.colors_for(int(level["id"]), int(level["n"]))
	if not level.has("title") or String(level["title"]).is_empty():
		level["title"] = Chapters.title_for(int(level["id"]))
	return level


func _build_fallback() -> void:
	# Dev-only safety net: if the catalog has not been generated yet, build one
	# board so the game still boots and can be tested.
	var result := LevelFactory.produce(5, 4242, [])
	if not bool(result["ok"]):
		return
	var level: Dictionary = result["level"]
	level["id"] = 1
	level["chapter"] = 0
	level["title"] = Chapters.title_for(1)
	level["colors"] = Chapters.colors_for(1, int(level["n"]))
	levels.append(level)
	_by_id[1] = level
	if chapters.is_empty():
		for i in range(Chapters.count()):
			var chapter := Chapters.get_chapter(i)
			chapters.append({"name": chapter["name"], "blurb": chapter["blurb"]})


func has_catalog() -> bool:
	return levels.size() >= Chapters.LEVELS_PER_CHAPTER


func get_level(id: int) -> Dictionary:
	if _by_id.has(id):
		return _by_id[id]
	if not levels.is_empty():
		return levels[clampi(id - 1, 0, levels.size() - 1)]
	return {}


func region_names(level: Dictionary) -> Array:
	return Chapters.region_names(int(level.get("chapter", 0)))


func daily_key() -> String:
	var now := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [now.year, now.month, now.day]


## One board a day, same for everyone, built from a date seed. Sizes step
## through 6..8 so the daily is not always the same shape of puzzle.
func daily() -> Dictionary:
	var key := daily_key()
	if _daily_key == key and not _daily.is_empty():
		return _daily
	var stamp := int(Time.get_unix_time_from_system())
	var day := int(stamp / 86400)
	var n := 6 + day % 3
	var seed_value := day * 7919 + 104729
	var tiers := ["Hard", "Expert"] if day % 2 == 0 else ["Medium", "Hard"]
	for attempt in range(6):
		var result := LevelFactory.produce(n, seed_value + attempt * 65537, tiers)
		if bool(result["ok"]):
			_daily = result["level"]
			_daily["id"] = 0
			_daily["mode"] = "daily"
			_daily["title"] = "Daily Purr"
			_daily["chapter"] = 0
			_daily["colors"] = Chapters.colors_for(day, n)
			_daily_key = key
			return _daily
	var fallback := get_level(Save.next_level())
	_daily = fallback.duplicate(true)
	_daily["mode"] = "daily"
	_daily["title"] = "Daily Purr"
	_daily_key = key
	return _daily


func practice() -> Dictionary:
	_practice_count += 1
	var stamp := int(Time.get_unix_time_from_system())
	var n := 6 + (_practice_count + stamp) % 3
	var seed_value := stamp * 31 + _practice_count * 7919
	for attempt in range(5):
		var result := LevelFactory.produce(n, seed_value + attempt * 65537, [])
		if bool(result["ok"]):
			var level: Dictionary = result["level"]
			level["id"] = 0
			level["mode"] = "practice"
			level["title"] = "Practice Patch"
			level["chapter"] = 0
			level["colors"] = Chapters.colors_for(_practice_count + stamp, n)
			return level
	var fallback := get_level(Save.next_level())
	var level := fallback.duplicate(true)
	level["mode"] = "practice"
	level["title"] = "Practice Patch"
	return level
