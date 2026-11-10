extends Control
## Title: a live little board on the table, then the way in.

var main: Node
var _showcase_shown := false


func configure(payload: Dictionary) -> void:
	main = Router.main


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(Ui.backdrop(Color(0.10, 0.06, 0.13, 0.30), Color(0.05, 0.03, 0.08, 0.94)))
	_build_showcase()
	_build_ui()


func _build_showcase() -> void:
	if main == null or _showcase_shown:
		return
	_showcase_shown = true
	var board: Board3D = main.spawn_board({
		"id": 9001,
		"n": 4,
		"regions": [1, 0, 0, 2, 1, 1, 2, 2, 1, 1, 2, 2, 1, 1, 3, 2],
		"solution": [1, 3, 0, 2],
		"colors": ["#f2cf6b", "#8fd9c3", "#c79be8", "#f0a6bd"],
	}, {"showcase": true})
	board.build_showcase()
	board.set_zoom(1.28)
	board.fit_camera()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 34)
	# Leave room for the arcade's account button, which floats over the
	# bottom-left corner of the page in the portal and in the standalone build.
	margin.add_theme_constant_override("margin_bottom", 74)
	add_child(margin)
	var column := Ui.column(10)
	margin.add_child(column)

	var badge := Ui.label("A LITTLE JOY ARCADE ORIGINAL", 11, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(badge)

	var top := Control.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(top)

	var title_card := Ui.panel(Color(0.07, 0.045, 0.10, 0.78), 26, Color(0.42, 0.30, 0.52, 0.55), 16)
	var title_column := Ui.column(2)
	title_card.add_child(title_column)
	column.add_child(title_card)
	title_column.add_child(Ui.label("Purrfect", 48, Ui.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	title_column.add_child(Ui.label("TERRITORY 3D", 22, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	title_column.add_child(Ui.label("One cat per row, column and territory.\nNo two cats may touch.",
		14, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var middle := Control.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)

	var next_id := Save.next_level()
	var label := "Continue · level %d" % next_id
	if Save.cleared_count() >= Chapters.level_count():
		label = "All territories secured"
	var continue_button := Ui.button(label, 20, 58, Ui.GOLD, func() -> void:
		var level := Levels.get_level(Save.next_level())
		if level.is_empty():
			Router.go("chapters")
		else:
			Router.go("game", {"level": level, "mode": "campaign"}))
	column.add_child(continue_button)

	var chapters := Ui.ghost("Chapters", func() -> void: Router.go("chapters"), 52, 18)
	column.add_child(chapters)

	var quick := Ui.row(10)
	column.add_child(quick)
	quick.add_child(Ui.ghost("Daily purr", func() -> void:
		Router.go("game", {"level": Levels.daily(), "mode": "daily"}), 48, 15, 8))
	quick.add_child(Ui.ghost("Practice", func() -> void:
		Router.go("game", {"level": Levels.practice(), "mode": "practice"}), 48, 15, 8))

	var footer := Ui.row(10)
	column.add_child(footer)
	footer.add_child(Ui.ghost("How to play", func() -> void: Router.go("tutorial"), 46, 14, 8))
	footer.add_child(Ui.ghost("Settings", func() -> void: Router.go("settings"), 46, 14, 8))
	footer.add_child(Ui.ghost("Trophies", func() -> void: Router.go("trophies"), 46, 14, 8))

	var arcade := Ui.ghost(Arcade.status_text(), func() -> void:
		if Arcade.available and not Arcade.signed_in:
			Arcade.sign_in()
		else:
			Router.go("settings"), 40, 12, 8)
	arcade.add_theme_color_override("font_color", Ui.MUTED)
	column.add_child(arcade)
	var progress := Ui.label("%d stars  ·  %d solved  ·  %d trophies" % [
		Save.total_stars(), Save.cleared_count(), Save.achievement_count()],
		12, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(progress)
