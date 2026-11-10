extends Control
## The journey: ten chapters as cards, with progress and locks.

func configure(_payload: Dictionary) -> void:
	pass


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.backdrop(Color("#1d1228"), Color("#0c0711")))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 12)
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
	var title := Ui.label("Chapters", 24, Ui.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(Ui.pill("%d stars" % Save.total_stars(), 13, Ui.GOLD))

	var scroll := Ui.scroll()
	column.add_child(scroll)
	var list := Ui.column(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for index in range(Chapters.count()):
		list.add_child(_chapter_card(index))


func _chapter_card(index: int) -> Control:
	var chapter := Chapters.get_chapter(index)
	var unlocked := Save.chapter_unlocked(index)
	var card := Ui.panel(Color("#241830") if unlocked else Color("#1a1422"), 20,
		Color("#4a3560") if unlocked else Color("#2a2033"), 14)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var inhale := Ui.row(12)
	card.add_child(inhale)

	var tint := Color(String(Chapters.PALETTE[index % Chapters.PALETTE.size()]))
	var badge := Ui.label(str(index + 1), 24, tint, HORIZONTAL_ALIGNMENT_CENTER)
	badge.custom_minimum_size = Vector2(48, 48)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", Ui.box(Color(tint, 0.14), 16, Color(tint, 0.45), 8))
	inhale.add_child(badge)

	var texts := Ui.column(4)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhale.add_child(texts)
	var name := Ui.label(String(chapter["name"]), 18, Ui.INK if unlocked else Ui.DIM)
	texts.add_child(name)
	texts.add_child(Ui.label(String(chapter["blurb"]), 12, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var cleared := Save.chapter_cleared(index)
	var stars := Save.chapter_stars(index)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = cleared
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("background", Ui.box(Color("#120c19"), 6))
	bar.add_theme_stylebox_override("fill", Ui.box(tint, 6))
	texts.add_child(bar)
	texts.add_child(Ui.label("%d / 100 cleared  ·  %d / 300 stars" % [cleared, stars], 11, Ui.DIM))

	var status := Ui.column(2)
	status.custom_minimum_size.x = 54
	inhale.add_child(status)
	var stars_label := Ui.label(Ui.stars_text(mini(3, int(ceil(float(stars) / 100.0)))), 12, Ui.GOLD,
		HORIZONTAL_ALIGNMENT_RIGHT)
	status.add_child(stars_label)
	status.add_child(Ui.label("open" if unlocked else "locked", 11,
		Ui.MINT if unlocked else Ui.DIM, HORIZONTAL_ALIGNMENT_RIGHT))

	if unlocked:
		# Containers stop mouse events by default; hand every descendant back to
		# the card so the whole row is a tap target.
		_ignore_mouse(inhale)
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				Audio.ui_click()
				Router.go("levels", {"chapter": index}))
	else:
		card.modulate = Color(1, 1, 1, 0.62)
	return card


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if child is MultiMeshInstance3D or child is Node:
			_ignore_mouse(child)
