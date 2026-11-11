extends Node
## Local-first save data.
##
## Written to `user://` after every meaningful event, mirrored to the Little Joy
## Arcade cloud when someone is signed in. Versioned, merged with defaults, and a
## corrupt file is backed up instead of deleted. Nothing here is scored: the
## puzzle itself decides whether a board is solved.

signal changed
signal achievement_unlocked(id: String)

const SAVE_PATH := "user://purrfect_territory_save.json"
const BACKUP_PATH := "user://purrfect_territory_save.corrupt.json"
const SCHEMA_VERSION := 1

## Earned assists refill over wall-clock time, one charge per kind per interval,
## and stop at POWERUP_MAX. Solving a puzzle also grants one.
const POWERUP_KINDS: Array = ["cat", "clue", "mouse"]
const POWERUP_MAX := 3
const POWERUP_INTERVAL := 600

## The in-progress tray also lives in localStorage on the web. Godot's user://
## filesystem is IndexedDB-backed and syncs asynchronously, so a page reload can
## beat the write; localStorage is synchronous and always there on the next boot.
const SESSION_KEY := "purrfect_territory_session_v1"

const ACHIEVEMENTS: Array = [
	{"id": "first_purr", "name": "First Purr", "hint": "Solve your first territory.", "stat": "solved", "need": 1},
	{"id": "solved_5", "name": "Settling In", "hint": "Solve five puzzles.", "stat": "solved", "need": 5},
	{"id": "solved_25", "name": "Neighbourhood Cat", "hint": "Solve 25 puzzles.", "stat": "solved", "need": 25},
	{"id": "solved_100", "name": "Territory Expert", "hint": "Solve 100 puzzles.", "stat": "solved", "need": 100},
	{"id": "solved_250", "name": "Cartographer", "hint": "Solve 250 puzzles.", "stat": "solved", "need": 250},
	{"id": "solved_500", "name": "Half the World", "hint": "Solve 500 puzzles.", "stat": "solved", "need": 500},
	{"id": "solved_1000", "name": "Nine Lives Summit", "hint": "Solve all 1,000 puzzles.", "stat": "solved", "need": 1000},
	{"id": "stars_10", "name": "Ten Stars", "hint": "Earn ten stars.", "stat": "stars", "need": 10},
	{"id": "stars_100", "name": "Star Basket", "hint": "Earn 100 stars.", "stat": "stars", "need": 100},
	{"id": "stars_500", "name": "Constellation", "hint": "Earn 500 stars.", "stat": "stars", "need": 500},
	{"id": "stars_1500", "name": "Night Sky", "hint": "Earn 1,500 stars.", "stat": "stars", "need": 1500},
	{"id": "stars_3000", "name": "Every Star", "hint": "Earn all 3,000 stars.", "stat": "stars", "need": 3000},
	{"id": "three_star_1", "name": "Nothing Wasted", "hint": "Earn three stars on a puzzle.", "stat": "three_stars", "need": 1},
	{"id": "three_star_10", "name": "Clean Paws", "hint": "Three stars on ten puzzles.", "stat": "three_stars", "need": 10},
	{"id": "three_star_50", "name": "Perfect Instinct", "hint": "Three stars on 50 puzzles.", "stat": "three_stars", "need": 50},
	{"id": "three_star_200", "name": "Unstoppable", "hint": "Three stars on 200 puzzles.", "stat": "three_stars", "need": 200},
	{"id": "no_hint_10", "name": "All By Myself", "hint": "Solve ten puzzles without a hint.", "stat": "no_hint", "need": 10},
	{"id": "no_hint_100", "name": "Own Two Paws", "hint": "Solve 100 puzzles without a hint.", "stat": "no_hint", "need": 100},
	{"id": "master_1", "name": "Master Mind", "hint": "Solve a Master puzzle.", "stat": "master", "need": 1},
	{"id": "master_10", "name": "Deep Thinker", "hint": "Solve ten Master puzzles.", "stat": "master", "need": 10},
	{"id": "master_25", "name": "Nine Lives of Logic", "hint": "Solve 25 Master puzzles.", "stat": "master", "need": 25},
	{"id": "chapter_1", "name": "Sunbeam Graduate", "hint": "Clear Sunbeam Steps.", "stat": "chapters", "need": 1},
	{"id": "chapter_3", "name": "Three Chapters In", "hint": "Clear three chapters.", "stat": "chapters", "need": 3},
	{"id": "chapter_5", "name": "Halfway Home", "hint": "Clear five chapters.", "stat": "chapters", "need": 5},
	{"id": "chapter_10", "name": "The Whole Journey", "hint": "Clear all ten chapters.", "stat": "chapters", "need": 10},
	{"id": "daily_1", "name": "Today's Cat", "hint": "Finish a daily puzzle.", "stat": "daily", "need": 1},
	{"id": "daily_7", "name": "Daily Habit", "hint": "Finish seven dailies.", "stat": "daily", "need": 7},
	{"id": "daily_30", "name": "A Month of Purrs", "hint": "Finish 30 dailies.", "stat": "daily", "need": 30},
	{"id": "streak_7", "name": "Seven in a Row", "hint": "Reach a seven-day streak.", "stat": "streak", "need": 7},
	{"id": "streak_30", "name": "Moon to Moon", "hint": "Reach a 30-day streak.", "stat": "streak", "need": 30},
	{"id": "practice_10", "name": "Practice Paws", "hint": "Solve ten practice puzzles.", "stat": "practice", "need": 10},
	{"id": "practice_50", "name": "Extra Homework", "hint": "Solve 50 practice puzzles.", "stat": "practice", "need": 50},
	{"id": "hints_25", "name": "Good Question", "hint": "Use 25 hints.", "stat": "hints", "need": 25},
	{"id": "comeback", "name": "Comeback Cat", "hint": "Finish a puzzle after a wrong guess.", "stat": "comebacks", "need": 1},
	{"id": "big_board", "name": "Ten by Ten", "hint": "Solve a 10x10 puzzle.", "stat": "big_boards", "need": 1},
	{"id": "all_chapters_three", "name": "Golden Paws", "hint": "Earn three stars in every chapter.", "stat": "golden_chapters", "need": 10},
]


static func _defaults() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"created": int(Time.get_unix_time_from_system()),
		"savedAt": 0,
		"profile": {"name": "Guest"},
		"settings": {
			"music": 0.45,
			"sfx": 0.8,
			"reduced_motion": false,
			"high_contrast": false,
			"patterns": false,
			"hearts": false,
			"tutorial_done": false,
		},
		"progress": {
			"stars": {},
			"times": {},
			"hints": {},
			"cleared": 0,
			"daily": {},
			"practice": 0,
			"last_level": 1,
		},
		"stats": {
			"solved": 0,
			"three_stars": 0,
			"no_hint": 0,
			"master": 0,
			"hints": 0,
			"mistakes": 0,
			"daily": 0,
			"practice": 0,
			"streak": 0,
			"best_streak": 0,
			"seconds": 0,
			"comebacks": 0,
			"big_boards": 0,
			"chapters": {},
			"daily_dates": {},
		},
		"powerups": {
			"cat": {"count": 1, "at": 0},
			"clue": {"count": 1, "at": 0},
			"mouse": {"count": 1, "at": 0},
		},
		# The puzzle currently on the tray, so a reload (or a jump out to the
		# browser) can put the player back exactly where they were.
		"session": {},
		"achievements": {},
	}


var data: Dictionary = {}
var _timer: Timer
var _dirty := false
var _writing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.6
	_timer.timeout.connect(flush)
	add_child(_timer)
	load_data()


func load_data() -> void:
	data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		queue_save()
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_backup(text)
		queue_save()
		return
	data = _merge(parsed, _defaults())
	data["schema"] = SCHEMA_VERSION
	_settle_powerups()
	changed.emit()


func _backup(text: String) -> void:
	push_warning("Purrfect Territory save could not be parsed; keeping a backup.")
	var file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()


func _merge(target: Dictionary, defaults: Dictionary) -> Dictionary:
	for key in defaults.keys():
		if not target.has(key):
			target[key] = defaults[key]
		elif typeof(target[key]) == TYPE_DICTIONARY and typeof(defaults[key]) == TYPE_DICTIONARY:
			_merge(target[key], defaults[key])
	return target


func queue_save() -> void:
	_dirty = true
	if _timer and _timer.is_inside_tree():
		_timer.start()


func flush() -> void:
	if _writing:
		return
	_writing = true
	data["savedAt"] = int(Time.get_unix_time_from_system() * 1000.0)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.flush()
		file.close()
		_dirty = false
		if has_node("/root/Arcade"):
			get_node("/root/Arcade").on_local_save(data)
		if has_node("/root/Audio"):
			get_node("/root/Audio").apply_settings(data["settings"])
	_writing = false


func get_setting(key: String, fallback: Variant = null) -> Variant:
	if data.has("settings") and data["settings"].has(key):
		return data["settings"][key]
	return fallback


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	queue_save()
	if has_node("/root/Audio"):
		get_node("/root/Audio").apply_settings(data["settings"])
	changed.emit()


# --------------------------------------------------------------------------
# progress
# --------------------------------------------------------------------------

func stars_for(id: int) -> int:
	return int((data["progress"]["stars"] as Dictionary).get(str(id), 0))


func is_cleared(id: int) -> bool:
	return stars_for(id) > 0


func is_unlocked(id: int) -> bool:
	if id <= 1:
		return true
	return is_cleared(id - 1)


func next_level() -> int:
	for id in range(1, Chapters.level_count() + 1):
		if not is_cleared(id):
			return id
	return Chapters.level_count()


func total_stars() -> int:
	var total := 0
	for value in (data["progress"]["stars"] as Dictionary).values():
		total += int(value)
	return total


func cleared_count() -> int:
	var total := 0
	for value in (data["progress"]["stars"] as Dictionary).values():
		if int(value) > 0:
			total += 1
	return total


func chapter_stars(chapter: int) -> int:
	var total := 0
	var first := chapter * Chapters.LEVELS_PER_CHAPTER + 1
	for id in range(first, first + Chapters.LEVELS_PER_CHAPTER):
		total += stars_for(id)
	return total


func chapter_cleared(chapter: int) -> int:
	var total := 0
	var first := chapter * Chapters.LEVELS_PER_CHAPTER + 1
	for id in range(first, first + Chapters.LEVELS_PER_CHAPTER):
		if is_cleared(id):
			total += 1
	return total


func chapter_unlocked(chapter: int) -> bool:
	if chapter <= 0:
		return true
	return chapter_cleared(chapter - 1) >= 10


func record_solve(id: int, stars: int, seconds: float, hints_used: int, mistakes: int,
		mode: String, difficulty: String, n: int) -> Dictionary:
	var key := str(id)
	if mode == "campaign":
		var previous := stars_for(id)
		if stars > previous:
			(data["progress"]["stars"] as Dictionary)[key] = stars
		(data["progress"]["times"] as Dictionary)[key] = int(seconds)
		(data["progress"]["hints"] as Dictionary)[key] = hints_used
		data["progress"]["cleared"] = cleared_count()
		(data["stats"]["chapters"] as Dictionary)[str(Chapters.chapter_of(id))] = true
		data["progress"]["last_level"] = mini(Chapters.level_count(), id + 1)
	elif mode == "daily":
		data["stats"]["daily"] = int(data["stats"]["daily"]) + 1
		var dates: Dictionary = data["stats"]["daily_dates"]
		dates[daily_key()] = true
		data["stats"]["streak"] = _streak()
		data["stats"]["best_streak"] = maxi(int(data["stats"]["best_streak"]), int(data["stats"]["streak"]))
	else:
		data["stats"]["practice"] = int(data["stats"]["practice"]) + 1

	data["stats"]["solved"] = int(data["stats"]["solved"]) + 1
	data["stats"]["seconds"] = int(data["stats"]["seconds"]) + int(seconds)
	data["stats"]["hints"] = int(data["stats"]["hints"]) + hints_used
	data["stats"]["mistakes"] = int(data["stats"]["mistakes"]) + mistakes
	if stars >= 3:
		data["stats"]["three_stars"] = int(data["stats"]["three_stars"]) + 1
	if hints_used == 0:
		data["stats"]["no_hint"] = int(data["stats"]["no_hint"]) + 1
	if mistakes > 0:
		data["stats"]["comebacks"] = int(data["stats"]["comebacks"]) + 1
	if difficulty == "Master":
		data["stats"]["master"] = int(data["stats"]["master"]) + 1
	if n >= 10:
		data["stats"]["big_boards"] = int(data["stats"]["big_boards"]) + 1
	data["stats"]["streak"] = _streak()
	var unlocked := check_achievements()
	var reward := powerup_solve_reward()
	queue_save()
	changed.emit()
	return {"unlocked": unlocked, "stars": stars_total(), "powerup": reward}


func stars_total() -> int:
	return total_stars()


func register_mistake() -> void:
	data["stats"]["mistakes"] = int(data["stats"]["mistakes"]) + 1
	queue_save()


# --------------------------------------------------------------------------
# power-ups
# --------------------------------------------------------------------------

## Awaited before every read: the clock, not an event, is what refills them.
func _settle_powerups() -> void:
	var store: Variant = data.get("powerups", {})
	if typeof(store) != TYPE_DICTIONARY:
		store = {}
		data["powerups"] = store
	var now := int(Time.get_unix_time_from_system())
	var changed_any := false
	for kind in POWERUP_KINDS:
		var raw: Variant = (store as Dictionary).get(kind, null)
		if typeof(raw) != TYPE_DICTIONARY:
			(store as Dictionary)[kind] = {"count": 1, "at": now}
			changed_any = true
			continue
		var entry: Dictionary = raw
		var count := int(entry.get("count", 0))
		var at := int(entry.get("at", 0))
		if at <= 0:
			entry["at"] = now
			at = now
			changed_any = true
		if count >= POWERUP_MAX:
			continue
		var gained := int((now - at) / POWERUP_INTERVAL)
		if gained > 0:
			entry["count"] = mini(POWERUP_MAX, count + gained)
			entry["at"] = at + gained * POWERUP_INTERVAL
			changed_any = true
	if changed_any:
		queue_save()


func powerup_count(kind: String) -> int:
	_settle_powerups()
	var store: Dictionary = data.get("powerups", {})
	var entry: Variant = store.get(kind, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return 0
	return int((entry as Dictionary).get("count", 0))


func powerup_seconds_left(kind: String) -> int:
	_settle_powerups()
	var store: Dictionary = data.get("powerups", {})
	var entry: Dictionary = store.get(kind, {})
	var count := int(entry.get("count", 0))
	if count >= POWERUP_MAX:
		return 0
	var at := int(entry.get("at", 0))
	if at <= 0:
		return POWERUP_INTERVAL
	return clampi(POWERUP_INTERVAL - (int(Time.get_unix_time_from_system()) - at), 0, POWERUP_INTERVAL)


func grant_powerup(kind: String, amount := 1) -> bool:
	_settle_powerups()
	var store: Dictionary = data.get("powerups", {})
	var entry: Dictionary = store.get(kind, {})
	var count := int(entry.get("count", 0))
	if count >= POWERUP_MAX:
		return false
	entry["count"] = mini(POWERUP_MAX, count + amount)
	if int(entry.get("at", 0)) <= 0:
		entry["at"] = int(Time.get_unix_time_from_system())
	store[kind] = entry
	queue_save()
	changed.emit()
	return true


func consume_powerup(kind: String) -> bool:
	_settle_powerups()
	var store: Dictionary = data.get("powerups", {})
	var entry: Dictionary = store.get(kind, {})
	var count := int(entry.get("count", 0))
	if count <= 0:
		return false
	# Leaving a full stock starts the refill clock now; spending a partial one
	# keeps its existing countdown, so nothing is thrown away.
	if count >= POWERUP_MAX:
		entry["at"] = int(Time.get_unix_time_from_system())
	entry["count"] = count - 1
	store[kind] = entry
	queue_save()
	changed.emit()
	return true


## One charge per solve, rotating through the three kinds.
func powerup_solve_reward() -> String:
	var solved := int(data["stats"]["solved"])
	var kind := String(POWERUP_KINDS[solved % POWERUP_KINDS.size()])
	if grant_powerup(kind):
		return kind
	return ""


# --------------------------------------------------------------------------
# in-progress puzzle (survives a reload)
# --------------------------------------------------------------------------

func session() -> Dictionary:
	var stashed := _web_session()
	if not stashed.is_empty():
		return stashed
	var current: Variant = data.get("session", {})
	return current if typeof(current) == TYPE_DICTIONARY else {}


func save_session(payload: Dictionary) -> void:
	data["session"] = payload
	_stash_web_session(payload)
	queue_save()


func clear_session() -> void:
	var current: Dictionary = session()
	if current.is_empty():
		return
	data["session"] = {}
	_clear_web_session()
	queue_save()


## Base64 keeps the JSON safe through the JavaScript bridge whatever the
## territory names contain. All three calls are no-ops off the web.
func _stash_web_session(payload: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	var encoded := Marshalls.utf8_to_base64(JSON.stringify(payload))
	JavaScriptBridge.eval(
		"try{localStorage.setItem('%s','%s')}catch(e){}" % [SESSION_KEY, encoded], true)


func _web_session() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var raw: Variant = JavaScriptBridge.eval(
		"(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % SESSION_KEY, true)
	if raw == null:
		return {}
	var encoded := String(raw)
	if encoded.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(Marshalls.base64_to_utf8(encoded))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _clear_web_session() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try{localStorage.removeItem('%s')}catch(e){}" % SESSION_KEY, true)


func daily_key() -> String:
	var now := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [now.year, now.month, now.day]


func daily_done() -> bool:
	return (data["stats"]["daily_dates"] as Dictionary).has(daily_key())


func _streak() -> int:
	var dates: Dictionary = data["stats"]["daily_dates"]
	var streak := 0
	var now := int(Time.get_unix_time_from_system())
	for i in range(200):
		var stamp := now - i * 86400
		var d := Time.get_datetime_dict_from_unix_time(stamp)
		var key := "%04d-%02d-%02d" % [d.year, d.month, d.day]
		if not dates.has(key):
			if i == 0:
				continue
			break
		streak += 1
	return streak


# --------------------------------------------------------------------------
# achievements
# --------------------------------------------------------------------------

func has_achievement(id: String) -> bool:
	return (data["achievements"] as Dictionary).has(id)


func unlock_achievement(id: String) -> bool:
	if has_achievement(id):
		return false
	(data["achievements"] as Dictionary)[id] = int(Time.get_unix_time_from_system())
	queue_save()
	achievement_unlocked.emit(id)
	if has_node("/root/Arcade"):
		get_node("/root/Arcade").achievement(id)
	return true


func _stat(key: String) -> int:
	var stats: Dictionary = data["stats"]
	match key:
		"stars":
			return total_stars()
		"chapters":
			return (stats["chapters"] as Dictionary).size()
		"golden_chapters":
			var count := 0
			for chapter in range(Chapters.count()):
				var first := chapter * Chapters.LEVELS_PER_CHAPTER + 1
				var all_three := true
				for id in range(first, first + Chapters.LEVELS_PER_CHAPTER):
					if stars_for(id) < 3:
						all_three = false
						break
				if all_three:
					count += 1
			return count
		"streak":
			return int(stats["streak"])
		_:
			return int(stats.get(key, 0))


func check_achievements() -> Array:
	var unlocked: Array = []
	for entry in ACHIEVEMENTS:
		var id := String(entry["id"])
		if has_achievement(id):
			continue
		if _stat(String(entry["stat"])) >= int(entry["need"]):
			if unlock_achievement(id):
				unlocked.append(id)
	return unlocked


func achievement_count() -> int:
	return (data["achievements"] as Dictionary).size()


func reset_progress() -> void:
	var settings: Dictionary = data["settings"]
	var profile: Dictionary = data["profile"]
	var created: Variant = data["created"]
	data = _defaults()
	data["settings"] = settings
	data["profile"] = profile
	data["created"] = created
	_clear_web_session()
	queue_save()
	changed.emit()
