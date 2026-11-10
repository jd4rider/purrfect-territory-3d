extends Control
## One puzzle: the 3D tray, the HUD, notes, undo, hints and the result card.
##
## Every win runs the full rule check on the board that is actually on screen —
## never a remembered arrangement — so a mis-tap that happens to look tidy cannot
## count as solved.

var main: Node
var level: Dictionary = {}
var mode := "campaign"
var n := 0
var regions := PackedInt32Array()
var solution: Array = []
var difficulty := "Medium"

var cats: Array = []
var marks: Array = []
var board: Board3D

var undo_stack: Array = []
var redo_stack: Array = []
var mistakes := 0
var hints_used := 0
var elapsed := 0.0
var solved := false
var running := true
var mark_mode := false

var title_label: Label
var stats_label: Label
var timer_label: Label
var progress_label: Label
var toast_label: Label
var toast_timer: Timer
var cat_button: Button
var note_button: Button
var hint_count_label: Label
var win_layer: Control
var win_card: VBoxContainer
var _win_star_row: StarRow
var _win_stats: Label


func configure(payload: Dictionary) -> void:
	level = payload.get("level", {})
	mode = String(payload.get("mode", "campaign"))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	n = int(level.get("n", 5))
	regions = LevelFactory.from_array(level.get("regions", []))
	solution = level.get("solution", [])
	difficulty = String(level.get("difficulty", "Medium"))
	cats = []
	marks = []
	for r in range(n):
		cats.append(-1)
		var row: Array = []
		for c in range(n):
			row.append(false)
		marks.append(row)
	_build_hud()
	_build_win()
	call_deferred("_start_board")
	Audio.play_music("focus")


func _start_board() -> void:
	board = Router.main.spawn_board(level, {
		"patterns": bool(Save.get_setting("patterns", false)),
		"high_contrast": bool(Save.get_setting("high_contrast", false)),
		"reduced_motion": bool(Save.get_setting("reduced_motion", false)),
	})
	board.cell_tapped.connect(_on_cell)
	board.fit_camera()
	_sync_board()


func _process(delta: float) -> void:
	if running and not solved:
		elapsed += delta
		if timer_label != null:
			timer_label.text = Ui.format_time(int(elapsed))


# --------------------------------------------------------------------------
# HUD
# --------------------------------------------------------------------------

func _build_hud() -> void:
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	top.add_theme_constant_override("margin_top", 30)
	add_child(top)
	var top_column := Ui.column(8)
	top.add_child(top_column)

	var header := Ui.row(8)
	top_column.add_child(header)
	var back := Ui.ghost("<", func() -> void:
		_leave(), 46, 20, 12)
	back.custom_minimum_size.x = 54
	header.add_child(back)
	title_label = Ui.label(String(level.get("title", "Puzzle")), 20, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	header.add_child(title_label)
	timer_label = Ui.label("0:00", 17, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.custom_minimum_size.x = 62
	header.add_child(timer_label)

	var meta := Ui.row(8)
	top_column.add_child(meta)
	var chapter_data: Dictionary = Chapters.get_chapter(int(level.get("chapter", 0)))
	var chapter_label := Ui.label(String(chapter_data["name"]), 13, Ui.MUTED)
	chapter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(chapter_label)
	meta.add_child(Ui.pill(difficulty, 12, Ui.MINT))
	progress_label = Ui.label("0 / %d cats" % n, 13, Ui.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	meta.add_child(progress_label)

	# toast sits just above the controls, where the eye already is
	toast_label = Ui.label("", 16, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_left = 24
	toast_label.offset_right = -24
	toast_label.offset_top = -196
	toast_label.offset_bottom = -140
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.visible = false
	add_child(toast_label)
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 4.5
	toast_timer.timeout.connect(func() -> void:
		if toast_label != null:
			toast_label.visible = false)
	add_child(toast_timer)

	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.add_theme_constant_override("margin_left", 14)
	bottom.add_theme_constant_override("margin_right", 14)
	bottom.add_theme_constant_override("margin_bottom", 26)
	add_child(bottom)
	var controls := Ui.column(10)
	bottom.add_child(controls)

	var modes := Ui.row(10)
	controls.add_child(modes)
	cat_button = _mode_button("Place cat", true, func() -> void: _set_mode(false))
	note_button = _mode_button("Paw note", false, func() -> void: _set_mode(true))
	modes.add_child(cat_button)
	modes.add_child(note_button)

	var actions := Ui.row(8)
	controls.add_child(actions)
	actions.add_child(_action("Undo", func() -> void: _undo()))
	actions.add_child(_action("Redo", func() -> void: _redo()))
	var hint_button := _action("Hint", func() -> void: _hint())
	hint_count_label = Ui.label("", 12, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hint_button.add_child(hint_count_label)
	actions.add_child(hint_button)
	actions.add_child(_action("Reset", func() -> void: _reset()))


func _mode_button(text: String, active: bool, on_press: Callable) -> Button:
	var node := Ui.ghost(text, on_press, 52, 16, 10)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.toggle_mode = true
	node.button_pressed = active
	return node


func _action(text: String, on_press: Callable) -> Button:
	var node := Ui.ghost(text, on_press, 58, 16, 8)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


func _set_mode(note: bool) -> void:
	mark_mode = note
	cat_button.button_pressed = not note
	note_button.button_pressed = note
	Audio.ui_click()
	_show_toast("Tap a square to place a paw note." if note else "Tap a square to place its cat.")


func _show_toast(text: String) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start()


# --------------------------------------------------------------------------
# play
# --------------------------------------------------------------------------

func _on_cell(row: int, col: int) -> void:
	if solved or row < 0 or col < 0 or row >= n or col >= n:
		return
	if mark_mode:
		if int(cats[row]) == col:
			return
		_push_undo()
		marks[row][col] = not bool(marks[row][col])
		Audio.mark()
		_sync_board()
		return
	if int(cats[row]) == col:
		_push_undo()
		cats[row] = -1
		Audio.unplace()
		_sync_board()
		return
	var old := int(cats[row])
	_push_undo()
	cats[row] = col
	var problem := _conflict(row, col)
	if not problem.is_empty():
		cats[row] = old
		_undo_stack_pop_quiet()
		_reject(row, col, problem)
		return
	marks[row][col] = false
	Audio.place()
	_sync_board()
	if board != null:
		board.sync(cats, marks)
	_check_win()


## Returns a player-facing reason when the cat in (row, col) breaks a rule, or an
## empty string when it is legal so far.
func _conflict(row: int, col: int) -> String:
	for r in range(n):
		if r == row:
			continue
		var other := int(cats[r])
		if other < 0:
			continue
		if other == col:
			return "Column %d already has a cat." % (col + 1)
		if absi(r - row) == 1 and absi(other - col) <= 1:
			return "Cats cannot touch, even corner to corner."
	for r in range(n):
		if r == row:
			continue
		var other := int(cats[r])
		if other < 0:
			continue
		if regions[r * n + other] == regions[row * n + col]:
			return "That territory already has a cat."
	return ""


func _reject(row: int, col: int, reason: String) -> void:
	mistakes += 1
	Save.register_mistake()
	Audio.wrong()
	if board != null:
		board.flash_wrong(row, col)
		board.shake_cat(row)
	_show_toast(reason)
	if Save.get_setting("hearts", false) and mistakes % 3 == 0:
		_show_toast("The cats scattered — the board is reset.")
		_reset(false)
	_sync_board()


func _push_undo() -> void:
	undo_stack.append({"cats": cats.duplicate(), "marks": _copy_marks()})
	if undo_stack.size() > 120:
		undo_stack.pop_front()
	redo_stack.clear()


func _undo_stack_pop_quiet() -> void:
	if undo_stack.is_empty():
		return
	var state: Dictionary = undo_stack.pop_back()
	cats = (state["cats"] as Array).duplicate()
	marks = (state["marks"] as Array).duplicate()


func _copy_marks() -> Array:
	var out: Array = []
	for row in marks:
		var copy: Array = []
		for value in row:
			copy.append(bool(value))
		out.append(copy)
	return out


func _undo() -> void:
	if solved or undo_stack.is_empty():
		return
	redo_stack.append({"cats": cats.duplicate(), "marks": _copy_marks()})
	var state: Dictionary = undo_stack.pop_back()
	cats = (state["cats"] as Array).duplicate()
	marks = (state["marks"] as Array).duplicate()
	Audio.unplace()
	_sync_board()


func _redo() -> void:
	if solved or redo_stack.is_empty():
		return
	undo_stack.append({"cats": cats.duplicate(), "marks": _copy_marks()})
	var state: Dictionary = redo_stack.pop_back()
	cats = (state["cats"] as Array).duplicate()
	marks = (state["marks"] as Array).duplicate()
	Audio.place()
	_sync_board()


func _reset(ask_sound := true) -> void:
	if ask_sound:
		Audio.ui_back()
	undo_stack.clear()
	redo_stack.clear()
	for r in range(n):
		cats[r] = -1
		for c in range(n):
			marks[r][c] = false
	mistakes = 0
	hints_used = 0
	elapsed = 0.0
	_update_hint_count()
	_sync_board()


func _hint() -> void:
	if solved:
		return
	var normal := HumanSolver.hint(regions, n, cats, marks, Chapters.region_names(int(level.get("chapter", 0))))
	if not bool(normal.get("ok", false)):
		_show_toast(String(normal.get("text", "No hint available.")))
		return
	hints_used += 1
	_update_hint_count()
	Audio.hint()
	if board != null:
		board.highlight(int(normal["row"]), int(normal["col"]), 4.0)
	_show_toast(String(normal["text"]))


func _sync_board() -> void:
	if board != null:
		board.sync(cats, marks)
	var placed := PuzzleModel.count_cats(cats)
	progress_label.text = "%d / %d cats" % [placed, n]
	_update_hint_count()


func _update_hint_count() -> void:
	if hint_count_label != null:
		hint_count_label.text = "  hint %d" % hints_used if hints_used > 0 else ""


func _check_win() -> void:
	if PuzzleModel.count_cats(cats) < n:
		return
	var check := PuzzleModel.validate(regions, n, cats)
	if not bool(check["ok"]):
		return
	_finish()


# --------------------------------------------------------------------------
# result
# --------------------------------------------------------------------------

func _finish() -> void:
	solved = true
	running = false
	var stars := 3
	if hints_used > 0:
		stars -= 1
	if mistakes > 0:
		stars -= 1
	stars = maxi(1, stars)
	var level_id := int(level.get("id", 0))
	var unlocked: Array = []
	if level_id > 0:
		var result := Save.record_solve(level_id, stars, elapsed, hints_used, mistakes,
			"campaign", difficulty, n)
		unlocked = result.get("unlocked", [])
	elif mode == "daily":
		var result := Save.record_solve(0, stars, elapsed, hints_used, mistakes, "daily", difficulty, n)
		unlocked = result.get("unlocked", [])
	else:
		var result := Save.record_solve(0, stars, elapsed, hints_used, mistakes, "practice", difficulty, n)
		unlocked = result.get("unlocked", [])
	if board != null:
		board.celebrate()
	Audio.win()
	_show_win(stars, unlocked)


func _build_win() -> void:
	win_layer = Control.new()
	win_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_layer.visible = false
	win_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(win_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_layer.add_child(center)
	var card := Ui.panel(Color("#241830"), 28, Color("#5b3f74"), 22)
	card.custom_minimum_size = Vector2(330, 0)
	center.add_child(card)
	win_card = Ui.column(12)
	card.add_child(win_card)
	win_card.add_child(Ui.label("Territory secured", 26, Ui.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	_win_star_row = StarRow.new()
	_win_star_row.size_px = 40.0
	_win_star_row.gap = 12.0
	win_card.add_child(_win_star_row)
	_win_stats = Ui.label("", 14, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	win_card.add_child(_win_stats)
	var extra := Ui.label("", 13, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	extra.name = "Extra"
	win_card.add_child(extra)
	win_card.add_child(Ui.spacer(4))
	var primary := Ui.button("Next puzzle", 18, 54, Ui.GOLD, func() -> void: _next_puzzle())
	win_card.add_child(primary)
	win_card.add_child(Ui.ghost("Play again", func() -> void: _play_again(), 50, 16))
	win_card.add_child(Ui.ghost("Chapter map", func() -> void:
		Audio.ui_back()
		Router.go("levels", {"chapter": int(level.get("chapter", 0))}), 50, 16))


func _show_win(stars: int, unlocked: Array) -> void:
	_win_star_row.filled = stars
	_win_star_row.animate_in()
	_win_stats.text = "%s  ·  %d hint%s  ·  %d wrong guess%s" % [
		Ui.format_time(int(elapsed)), hints_used, "" if hints_used == 1 else "s",
		mistakes, "" if mistakes == 1 else "es",
	]
	var extra: Label = win_card.get_node_or_null("Extra")
	if extra != null:
		if not unlocked.is_empty():
			var entry := _achievement_name(String(unlocked[0]))
			extra.text = "Trophy earned: %s" % entry
		elif Save.daily_done() and mode == "daily":
			extra.text = "Daily purr complete — come back tomorrow."
		else:
			extra.text = "%d of %d stars collected" % [Save.total_stars(), Chapters.level_count() * 3]
	win_layer.visible = true
	win_layer.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(win_layer, "modulate:a", 1.0, 0.25)
	for i in range(stars):
		get_tree().create_timer(0.28 + i * 0.18).timeout.connect(func() -> void:
			Audio.star(i))


func _achievement_name(id: String) -> String:
	for entry in Save.ACHIEVEMENTS:
		if String(entry["id"]) == id:
			return String(entry["name"])
	return id


func _next_puzzle() -> void:
	if mode != "campaign":
		Router.go("title")
		return
	var next_id := mini(Chapters.level_count(), int(level.get("id", 1)) + 1)
	var next_level := Levels.get_level(next_id)
	if next_level.is_empty():
		Router.go("levels", {"chapter": int(level.get("chapter", 0))})
		return
	Router.go("game", {"level": next_level, "mode": "campaign"})


func _play_again() -> void:
	Router.go("game", {"level": level, "mode": mode})


func _leave() -> void:
	Audio.ui_back()
	if mode == "campaign":
		Router.go("levels", {"chapter": int(level.get("chapter", 0))})
	elif mode == "daily":
		Router.go("title")
	else:
		Router.go("title")


# --------------------------------------------------------------------------
# debug hooks used by Tools/smoke.mjs (web build only)
# --------------------------------------------------------------------------

func debug_tap(row: int, col: int) -> void:
	_on_cell(row, col)


func debug_solve() -> void:
	if solved:
		return
	if solution.size() != n:
		return
	for r in range(n):
		cats[r] = int(solution[r])
	_sync_board()
	_check_win()


func debug_state() -> Dictionary:
	return {
		"level": int(level.get("id", 0)),
		"n": n,
		"difficulty": difficulty,
		"cats": cats,
		"marks": marks,
		"solved": solved,
		"mistakes": mistakes,
		"hints": hints_used,
		"stars": Save.stars_for(int(level.get("id", 0))) if int(level.get("id", 0)) > 0 else 0,
		"mark_mode": mark_mode,
	}
