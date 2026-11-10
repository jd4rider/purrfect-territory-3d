extends Control
## Every trophy, earned ones lit.

func configure(_payload: Dictionary) -> void:
	pass


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.backdrop(Color("#1b1226"), Color("#0b0710")))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var column := Ui.column(10)
	margin.add_child(column)

	var header := Ui.row(8)
	column.add_child(header)
	var back := Ui.ghost("<", func() -> void:
		Audio.ui_back()
		Router.go("settings"), 44, 18, 12)
	back.custom_minimum_size.x = 52
	header.add_child(back)
	var title := Ui.label("Trophies", 22, Ui.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(Ui.pill("%d / %d" % [Save.achievement_count(), Save.ACHIEVEMENTS.size()], 12, Ui.GOLD))

	var scroll := Ui.scroll()
	column.add_child(scroll)
	var list := Ui.column(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for entry in Save.ACHIEVEMENTS:
		var id := String(entry["id"])
		var earned := Save.has_achievement(id)
		var card := Ui.panel(Color("#241a30") if earned else Color("#1a1422"), 14,
			Color("#6b4c88") if earned else Color("#2a2033"), 10)
		var row := Ui.row(10)
		card.add_child(row)
		var mark := Ui.label("*" if earned else "·", 22, Ui.GOLD if earned else Ui.DIM,
			HORIZONTAL_ALIGNMENT_CENTER)
		mark.custom_minimum_size.x = 26
		row.add_child(mark)
		var texts := Ui.column(2)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(texts)
		texts.add_child(Ui.label(String(entry["name"]), 15, Ui.INK if earned else Ui.MUTED))
		texts.add_child(Ui.label(String(entry["hint"]), 11, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		if earned:
			row.add_child(Ui.pill("earned", 10, Ui.MINT))
		list.add_child(card)
