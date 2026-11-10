extends Control
## Settings: sound, comfort options, account and the one destructive button.

var _reset_armed := false
var _reset_button: Button


func configure(_payload: Dictionary) -> void:
	pass


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.backdrop(Color("#1c1226"), Color("#0b0710")))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var column := Ui.column(12)
	margin.add_child(column)

	var header := Ui.row(8)
	column.add_child(header)
	var back := Ui.ghost("<", func() -> void:
		Audio.ui_back()
		Router.go("title"), 44, 18, 12)
	back.custom_minimum_size.x = 52
	header.add_child(back)
	var title := Ui.label("Settings", 22, Ui.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var scroll := Ui.scroll()
	column.add_child(scroll)
	var list := Ui.column(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	list.add_child(_section("Sound"))
	list.add_child(_slider("Music", "music", 0.45))
	list.add_child(_slider("Sounds", "sfx", 0.8))

	list.add_child(_section("Comfort"))
	list.add_child(_toggle("Reduce motion", "reduced_motion",
		"Stops the idle bounce and the victory hops."))
	list.add_child(_toggle("High contrast territories", "high_contrast",
		"Lifts the tile colours and darkens the borders."))
	list.add_child(_toggle("Territory numbers", "patterns",
		"Prints each territory's number on its tiles, for colour-blind play."))
	list.add_child(_toggle("Mistakes scatter the cats", "hearts",
		"After three wrong guesses the board resets. Off is relaxed play."))

	list.add_child(_section("Learn"))
	list.add_child(Ui.ghost("How to play", func() -> void: Router.go("tutorial"), 50, 16))
	list.add_child(Ui.ghost("Trophies · %d of %d" % [Save.achievement_count(), Save.ACHIEVEMENTS.size()],
		func() -> void: Router.go("trophies"), 50, 16))

	list.add_child(_section("Little Joy Arcade"))
	var account := Ui.ghost(Arcade.status_text(), func() -> void:
		if Arcade.available and not Arcade.signed_in:
			Arcade.sign_in()
		else:
			Arcade.open_arcade(), 50, 15)
	list.add_child(account)
	list.add_child(Ui.ghost("Open Little Joy Arcade", func() -> void: Arcade.open_arcade(), 46, 14))

	list.add_child(_section("Progress"))
	list.add_child(Ui.label("%d stars · %d puzzles solved · %d trophies" % [
		Save.total_stars(), Save.cleared_count(), Save.achievement_count()], 13, Ui.MUTED))

	_reset_button = Ui.ghost("Reset all progress", func() -> void: _arm_reset(), 48, 15)
	_reset_button.add_theme_color_override("font_color", Ui.DANGER)
	list.add_child(_reset_button)
	list.add_child(Ui.label("Made by FreeBuff for Little Joy Arcade · v1.0.0", 11, Ui.DIM,
		HORIZONTAL_ALIGNMENT_CENTER))


func _section(text: String) -> Control:
	var label := Ui.label(text.to_upper(), 11, Ui.GOLD)
	var holder := Ui.column(4)
	holder.add_child(Ui.spacer(6))
	holder.add_child(label)
	return holder


func _slider(text: String, key: String, fallback: float) -> Control:
	var row := Ui.row(12)
	var label := Ui.label(text, 16, Ui.INK)
	label.custom_minimum_size.x = 88
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Save.get_setting(key, fallback))
	slider.custom_minimum_size.y = 34
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		Save.set_setting(key, value)
		Audio.apply_settings(Save.data["settings"]))
	row.add_child(slider)
	var value_label := Ui.label("%d%%" % int(slider.value * 100), 13, Ui.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size.x = 44
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(value * 100))
	row.add_child(value_label)
	return row


func _toggle(text: String, key: String, hint: String) -> Control:
	var card := Ui.panel(Color("#221730"), 16, Color("#3a2a4a"), 12)
	var row := Ui.row(8)
	card.add_child(row)
	var texts := Ui.column(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	texts.add_child(Ui.label(text, 15, Ui.INK))
	texts.add_child(Ui.label(hint, 11, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var check := CheckButton.new()
	check.button_pressed = bool(Save.get_setting(key, false))
	check.add_theme_color_override("font_color", Ui.MINT)
	check.toggled.connect(func(value: bool) -> void:
		Save.set_setting(key, value)
		if key == "reduced_motion" or key == "high_contrast" or key == "patterns":
			Router.toast("Applies the next time you open a puzzle."))
	row.add_child(check)
	return card


func _arm_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Tap again to erase everything"
		_reset_button.add_theme_color_override("font_color", Ui.DANGER)
		Router.toast("This clears stars, trophies and settings. Tap once more to confirm.")
		return
	Save.reset_progress()
	Audio.ui_back()
	Router.toast("Progress reset. A fresh tray of puzzles.")
	_reset_armed = false
	_reset_button.text = "Reset all progress"
