extends Control
## One chapter's hundred puzzles as a tap grid.

var chapter := 0


func configure(payload: Dictionary) -> void:
	chapter = int(payload.get("chapter", 0))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.backdrop(Color("#1b1126"), Color("#0b0710")))
	var meta := Chapters.get_chapter(chapter)
	var tint := Color(String(Chapters.PALETTE[chapter % Chapters.PALETTE.size()]))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var column := Ui.column(10)
	margin.add_child(column)

	var header := Ui.row(8)
	column.add_child(header)
	var back := Ui.ghost("<", func() -> void:
		Audio.ui_back()
		Router.go("chapters"), 52, 22, 12)
	back.custom_minimum_size.x = 60
	header.add_child(back)
	var title := Ui.label(String(meta["name"]), 20, Ui.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	header.add_child(title)
	header.add_child(Ui.pill("%d / 300" % Save.chapter_stars(chapter), 12, tint))

	column.add_child(Ui.label(String(meta["blurb"]), 12, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var scroll := Ui.scroll()
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var first := chapter * Chapters.LEVELS_PER_CHAPTER + 1
	for offset in range(Chapters.LEVELS_PER_CHAPTER):
		var id := first + offset
		grid.add_child(_level_button(id, tint))


func _level_button(id: int, tint: Color) -> Button:
	var unlocked := Save.is_unlocked(id)
	var stars := Save.stars_for(id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 70)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	var text := "%d" % ((id - 1) % Chapters.LEVELS_PER_CHAPTER + 1)
	if stars > 0:
		text += "\n" + Ui.stars_text(stars)
	button.text = text
	button.disabled = not unlocked
	button.add_theme_color_override("font_color", Ui.INK)
	button.add_theme_color_override("font_disabled_color", Ui.DIM)
	var fill := Color("#2c1f39") if stars == 0 else Color(tint, 0.22)
	var border := Color("#4a3560") if unlocked else Color("#241c2e")
	button.add_theme_stylebox_override("normal", Ui.box(fill, 16, border, 6))
	button.add_theme_stylebox_override("hover", Ui.box(Color("#3a2a4a"), 16, tint, 6))
	button.add_theme_stylebox_override("pressed", Ui.box(Color("#23182e"), 16, tint, 6))
	button.add_theme_stylebox_override("disabled", Ui.box(Color("#181121"), 16, Color("#241c2e"), 6))
	button.pressed.connect(func() -> void:
		Audio.ui_click()
		var level := Levels.get_level(id)
		if level.is_empty():
			Router.toast("That puzzle is still being written.")
			return
		Router.go("game", {"level": level, "mode": "campaign"}))
	return button
