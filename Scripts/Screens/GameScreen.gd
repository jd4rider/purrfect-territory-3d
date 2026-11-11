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
var legend_row: HBoxContainer
var win_layer: Control
var win_card: VBoxContainer
var _win_star_row: StarRow
var _win_stats: Label
var _win_power: Label

var _drag_painting := false
var _drag_value := true
var _power_buttons: Dictionary = {}
var _power_tick := 0.0
var _restore: Dictionary = {}
var _clue_layer: Control
var _clue_text: Label
var _clue_row := -1
var _clue_col := -1


func configure(payload: Dictionary) -> void:
	level = payload.get("level", {})
	mode = String(payload.get("mode", "campaign"))
	var saved: Variant = payload.get("resume", {})
	_restore = saved if typeof(saved) == TYPE_DICTIONARY else {}


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
	_restore_state()
	_build_hud()
	_build_clue()
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
	board.cell_double_tapped.connect(_on_double_cell)
	board.drag_started.connect(_on_drag_started)
	board.drag_moved.connect(_on_drag_moved)
	board.drag_ended.connect(_on_drag_ended)
	board.set_safe_area(168.0, 184.0)
	board.fit_camera()
	_sync_board()
	if _restore.is_empty():
		_show_toast("Tap to cross out · hold and drag for a row · double-tap for a cat")
	else:
		_show_toast("Welcome back — the tray is as you left it.")


func _process(delta: float) -> void:
	if running and not solved:
		elapsed += delta
		if timer_label != null:
			timer_label.text = Ui.format_time(int(elapsed))
		_power_tick += delta
		if _power_tick >= 1.0:
			_power_tick = 0.0
			_refresh_powerups()


# --------------------------------------------------------------------------
# HUD
# --------------------------------------------------------------------------

func _build_hud() -> void:
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	top.add_theme_constant_override("margin_top", 32)
	add_child(top)
	var top_column := Ui.column(8)
	top.add_child(top_column)

	var header := Ui.row(8)
	top_column.add_child(header)
	var back := Ui.ghost("<", func() -> void:
		_leave(), 52, 22, 12)
	back.custom_minimum_size.x = 60
	header.add_child(back)
	title_label = Ui.label(String(level.get("title", "Puzzle")), 22, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	header.add_child(title_label)
	timer_label = Ui.label("0:00", 18, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.custom_minimum_size.x = 66
	header.add_child(timer_label)

	var meta := Ui.row(8)
	top_column.add_child(meta)
	var chapter_data: Dictionary = Chapters.get_chapter(int(level.get("chapter", 0)))
	var chapter_label := Ui.label(String(chapter_data["name"]), 14, Ui.MUTED)
	chapter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(chapter_label)
	meta.add_child(Ui.pill(difficulty, 13, Ui.MINT))
	progress_label = Ui.label("0 / %d cats" % n, 14, Ui.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	meta.add_child(progress_label)

	# The colours still missing a cat, in the same order as the territories.
	# A chip fades once its territory's cat is on the tray.
	legend_row = Ui.row(6)
	legend_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_column.add_child(legend_row)

	# toast sits just above the controls, where the eye already is
	toast_label = Ui.label("", 17, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_left = 24
	toast_label.offset_right = -24
	toast_label.offset_top = -258
	toast_label.offset_bottom = -196
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
	bottom.add_theme_constant_override("margin_left", 12)
	bottom.add_theme_constant_override("margin_right", 12)
	bottom.add_theme_constant_override("margin_bottom", 24)
	add_child(bottom)
	var controls := Ui.column(10)
	bottom.add_child(controls)

	# The three earned assists. A spent one shows its refill countdown.
	var powers := Ui.row(8)
	controls.add_child(powers)
	for kind in Save.POWERUP_KINDS:
		powers.add_child(_power_button(String(kind)))

	var actions := Ui.row(8)
	controls.add_child(actions)
	actions.add_child(_action("Undo", func() -> void: _undo()))
	actions.add_child(_action("Redo", func() -> void: _redo()))
	actions.add_child(_action("Reset", func() -> void: _reset()))
	_refresh_powerups()


func _action(text: String, on_press: Callable) -> Button:
	var node := Ui.ghost(text, on_press, 62, 17, 8)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


func _power_button(kind: String) -> Button:
	var node := Ui.ghost("", func() -> void: _use_powerup(kind), 64, 15, 6)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_color_override("font_disabled_color", Ui.DIM)
	_power_buttons[kind] = node
	return node


func _show_toast(text: String) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start()


# --------------------------------------------------------------------------
# play
# --------------------------------------------------------------------------

## A single tap is the reversible action: cross the square out (or clear it).
func _on_cell(row: int, col: int) -> void:
	if solved or row < 0 or col < 0 or row >= n or col >= n:
		return
	if int(cats[row]) == col:
		return
	_push_undo()
	marks[row][col] = not bool(marks[row][col])
	Audio.mark()
	_sync_board()


## A quick second tap on the same square commits the cat, minesweeper style.
func _on_double_cell(row: int, col: int) -> void:
	if solved or not _in_bounds(row, col):
		return
	if int(cats[row]) == col:
		_push_undo()
		cats[row] = -1
		Audio.unplace()
		_sync_board()
		return
	_commit_cat(row, col)


## Places a cat if the rules allow it. Returns false (and explains why) when the
## square would break a rule, so the tap, the clue and the cat power-up all go
## through the same check.
func _commit_cat(row: int, col: int) -> bool:
	var old := int(cats[row])
	_push_undo()
	cats[row] = col
	var problem := _conflict(row, col)
	if not problem.is_empty():
		cats[row] = old
		_undo_stack_pop_quiet()
		_reject(row, col, problem)
		return false
	marks[row][col] = false
	Audio.place()
	_sync_board()
	_check_win()
	return true


func _in_bounds(row: int, col: int) -> bool:
	return row >= 0 and col >= 0 and row < n and col < n


# --------------------------------------------------------------------------
# drag painting
# --------------------------------------------------------------------------

## A held finger paints one value across every square it crosses: marking if the
## first square was clear, clearing if it was already crossed out. The whole
## sweep is a single undo step.
func _on_drag_started(row: int, col: int) -> void:
	if solved or not _in_bounds(row, col):
		return
	if int(cats[row]) == col:
		_drag_painting = false
		return
	_push_undo()
	_drag_painting = true
	_drag_value = not bool(marks[row][col])
	_paint_cell(row, col)


func _on_drag_moved(row: int, col: int) -> void:
	if _drag_painting:
		_paint_cell(row, col)


func _on_drag_ended() -> void:
	if not _drag_painting:
		return
	_drag_painting = false
	Audio.mark()
	_sync_board()


func _paint_cell(row: int, col: int) -> void:
	if not _in_bounds(row, col) or int(cats[row]) == col:
		return
	if bool(marks[row][col]) == _drag_value:
		return
	marks[row][col] = _drag_value
	_sync_board(true)


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
	_refresh_powerups()
	_sync_board()


func _hint() -> void:
	if solved:
		return
	var normal := HumanSolver.hint(regions, n, cats, marks, Chapters.region_names(int(level.get("chapter", 0))))
	if not bool(normal.get("ok", false)):
		_show_toast(String(normal.get("text", "No hint available.")))
		return
	hints_used += 1
	Audio.hint()
	if board != null:
		board.highlight(int(normal["row"]), int(normal["col"]), 4.0)
	_show_toast(String(normal["text"]))


# --------------------------------------------------------------------------
# power-ups
# --------------------------------------------------------------------------

func _powerup_name(kind: String) -> String:
	match kind:
		"cat":
			return "Cat"
		"clue":
			return "Clue"
		_:
			return "Mouse"


## Shows the stock on each button, and the refill countdown when it is empty.
func _refresh_powerups() -> void:
	for kind in _power_buttons.keys():
		var button: Button = _power_buttons[kind]
		if button == null or not is_instance_valid(button):
			continue
		var count := Save.powerup_count(String(kind))
		button.disabled = solved or count <= 0
		if count > 0:
			button.text = "%s %d" % [_powerup_name(String(kind)), count]
		else:
			button.text = "%s\n%s" % [_powerup_name(String(kind)),
				Ui.format_time(Save.powerup_seconds_left(String(kind)))]


func _use_powerup(kind: String) -> void:
	if solved:
		return
	if Save.powerup_count(kind) <= 0:
		_show_toast("%s is recharging — %s to go." % [_powerup_name(kind),
			Ui.format_time(Save.powerup_seconds_left(kind))])
		return
	match kind:
		"cat":
			_use_cat()
		"clue":
			_open_clue()
		"mouse":
			_use_mouse()


## Cat: one cat that is still hidden on the tray, placed on its real square.
func _use_cat() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick := PowerUps.hidden_cat(cats, solution, rng)
	if pick.x < 0:
		_show_toast("Every row already has its cat.")
		return
	if not Save.consume_powerup("cat"):
		return
	_push_undo()
	cats[pick.x] = pick.y
	marks[pick.x][pick.y] = false
	Audio.place()
	_sync_board()
	_refresh_powerups()
	if board != null:
		board.highlight(pick.x, pick.y, 1.6)
	_show_toast("A cat padded out of hiding.")
	_check_win()


## Mouse: crosses out a square that cannot hold a cat, following a rule a player
## could have worked out themselves where one applies.
func _use_mouse() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick := PowerUps.safe_mark(regions, n, cats, marks, solution, rng)
	if pick.x < 0:
		_show_toast("There is nothing left that is safely empty.")
		return
	if not Save.consume_powerup("mouse"):
		return
	_push_undo()
	marks[pick.x][pick.y] = true
	Audio.mark()
	_sync_board()
	_refresh_powerups()
	if board != null:
		board.highlight(pick.x, pick.y, 1.6)
	_show_toast("The mouse scratched an X where no cat can be.")


# --------------------------------------------------------------------------
# clue card
# --------------------------------------------------------------------------

func _build_clue() -> void:
	_clue_layer = Control.new()
	_clue_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clue_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_clue_layer.visible = false
	add_child(_clue_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.08, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clue_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clue_layer.add_child(center)
	var card := Ui.panel(Color("#241830"), 26, Color("#5b3f74"), 20)
	card.custom_minimum_size = Vector2(344, 0)
	center.add_child(card)
	var column := Ui.column(12)
	card.add_child(column)
	column.add_child(Ui.label("A clue", 23, Ui.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	_clue_text = Ui.label("", 17, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	_clue_text.custom_minimum_size.y = 96
	column.add_child(_clue_text)
	column.add_child(Ui.button("Place that cat", 18, 56, Ui.GOLD, func() -> void:
		_apply_clue()))
	column.add_child(Ui.ghost("Keep thinking", func() -> void:
		_clue_layer.visible = false, 52, 16))


## The charge buys the explanation; applying it afterwards is free, because the
## cat is already on screen and highlighted.
func _open_clue() -> void:
	var normal := HumanSolver.hint(regions, n, cats, marks,
		Chapters.region_names(int(level.get("chapter", 0))))
	if not bool(normal.get("ok", false)):
		_show_toast(String(normal.get("text", "No clue is available right now.")))
		return
	if not Save.consume_powerup("clue"):
		return
	hints_used += 1
	Audio.hint()
	_clue_row = int(normal["row"])
	_clue_col = int(normal["col"])
	_clue_text.text = String(normal["text"])
	_clue_layer.visible = true
	if board != null:
		board.highlight(_clue_row, _clue_col, 8.0)
	_refresh_powerups()
	_persist_session()


func _apply_clue() -> void:
	if _clue_layer != null:
		_clue_layer.visible = false
	if _clue_row < 0:
		return
	if _commit_cat(_clue_row, _clue_col):
		_show_toast("The clue's cat is on the tray.")
	_clue_row = -1
	_clue_col = -1


# --------------------------------------------------------------------------
# resume
# --------------------------------------------------------------------------

func _restore_state() -> void:
	if _restore.is_empty():
		return
	var stored_cats: Array = _restore.get("cats", [])
	if stored_cats.size() == n:
		for r in range(n):
			cats[r] = clampi(int(stored_cats[r]), -1, n - 1)
	var stored_marks: Array = _restore.get("marks", [])
	if stored_marks.size() == n:
		for r in range(n):
			var row: Array = stored_marks[r]
			if row.size() != n:
				continue
			for c in range(n):
				marks[r][c] = bool(row[c])
	elapsed = float(_restore.get("elapsed", 0.0))
	hints_used = int(_restore.get("hints", 0))
	mistakes = int(_restore.get("mistakes", 0))


## Written after every committed change, so a browser reload or a trip out of
## the tab puts the same tray back on the screen.
func _persist_session() -> void:
	if solved or n <= 0:
		return
	Save.save_session({
		"level": level,
		"mode": mode,
		"cats": cats,
		"marks": marks,
		"elapsed": elapsed,
		"hints": hints_used,
		"mistakes": mistakes,
	})
	# A phone can kill the tab without warning, so the tray goes to disk now
	# rather than on the save timer.
	Save.flush()


## `light` is for the middle of a drag: the 3D marks still update, but the
## legend chips (which rebuild nodes) wait until the finger lifts.
func _sync_board(light := false) -> void:
	if board != null:
		board.sync(cats, marks)
	var placed := PuzzleModel.count_cats(cats)
	progress_label.text = "%d / %d cats" % [placed, n]
	if not light:
		_refresh_legend()
		_persist_session()


func _level_colors() -> Array:
	var stored: Array = level.get("colors", [])
	if stored.is_empty():
		return Chapters.colors_for(int(level.get("id", 1)), n)
	return stored


## Rebuilds the "cats still to find" strip. Each territory contributes one
## chip in its own colour; a placed cat empties its chip to a faint ring.
func _refresh_legend() -> void:
	if legend_row == null:
		return
	for child in legend_row.get_children():
		child.queue_free()
	var palette := _level_colors()
	for reg in range(n):
		var revealed := false
		for r in range(n):
			var c := int(cats[r])
			if c >= 0 and regions[r * n + c] == reg:
				revealed = true
				break
		var hex := String(palette[reg % palette.size()])
		legend_row.add_child(_legend_chip(Color(hex), revealed))


func _legend_chip(color: Color, revealed: bool) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(28, 28)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.draw.connect(func() -> void:
		var center := Vector2(14, 14)
		if revealed:
			node.draw_arc(center, 9.5, 0.0, TAU, 28, Color(color, 0.42), 2.0)
			return
		node.draw_circle(center, 11.0, color)
		node.draw_arc(center, 11.0, 0.0, TAU, 28, Color(1, 1, 1, 0.4), 1.5)
		var ink := Color(0.10, 0.06, 0.13, 0.75)
		node.draw_circle(center + Vector2(0, 1.6), 4.2, ink)
		node.draw_circle(center + Vector2(-4.4, -3.0), 1.9, ink)
		node.draw_circle(center + Vector2(0, -4.4), 1.9, ink)
		node.draw_circle(center + Vector2(4.4, -3.0), 1.9, ink))
	return node


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
	Save.clear_session()
	var stars := 3
	if hints_used > 0:
		stars -= 1
	if mistakes > 0:
		stars -= 1
	stars = maxi(1, stars)
	var level_id := int(level.get("id", 0))
	var unlocked: Array = []
	var earned := ""
	if level_id > 0:
		var result := Save.record_solve(level_id, stars, elapsed, hints_used, mistakes,
			"campaign", difficulty, n)
		unlocked = result.get("unlocked", [])
		earned = String(result.get("powerup", ""))
	elif mode == "daily":
		var result := Save.record_solve(0, stars, elapsed, hints_used, mistakes, "daily", difficulty, n)
		unlocked = result.get("unlocked", [])
		earned = String(result.get("powerup", ""))
	else:
		var result := Save.record_solve(0, stars, elapsed, hints_used, mistakes, "practice", difficulty, n)
		unlocked = result.get("unlocked", [])
		earned = String(result.get("powerup", ""))
	if board != null:
		board.celebrate()
	Audio.win()
	_refresh_powerups()
	_show_win(stars, unlocked, earned)


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
	_win_power = Ui.label("", 14, Ui.MINT, HORIZONTAL_ALIGNMENT_CENTER, true)
	win_card.add_child(_win_power)
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


func _show_win(stars: int, unlocked: Array, earned := "") -> void:
	if _win_power != null:
		_win_power.text = ("Power-up earned: %s" % _powerup_name(earned)) if not earned.is_empty() else ""
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
	Save.clear_session()
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


func debug_double_tap(row: int, col: int) -> void:
	_on_double_cell(row, col)


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
		"dragging": _drag_painting,
		"powerups": {
			"cat": Save.powerup_count("cat"),
			"clue": Save.powerup_count("clue"),
			"mouse": Save.powerup_count("mouse"),
		},
	}
