extends Control
## Four short pages, one rule each. Skippable, and it remembers being seen.

const PAGES: Array = [
	{
		"title": "One cat in every row",
		"body": "Every row of the tray gets exactly one cat. Tap a square to cross it out, and double-tap it to place your cat.",
	},
	{
		"title": "One cat in every column",
		"body": "Columns work the same way: exactly one cat each. Tap a square, then look down its whole column before you commit.",
	},
	{
		"title": "One cat in every territory",
		"body": "The colours are territories. Each territory holds one cat, and every square of a territory is connected to the rest of it.",
	},
	{
		"title": "No two cats touch",
		"body": "Not even corner to corner. This is the rule that catches most guesses, so check the diagonals whenever you place a new cat.",
	},
]

var _page := 0
var _title: Label
var _body: Label
var _diagram: TutorialDiagram
var _dots: Label
var _next: Button


func configure(_payload: Dictionary) -> void:
	pass


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.backdrop(Color("#1d1327"), Color("#0b0710")))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var column := Ui.column(14)
	margin.add_child(column)

	var header := Ui.row(8)
	column.add_child(header)
	var badge := Ui.label("HOW TO PLAY", 11, Ui.MUTED)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(badge)
	header.add_child(Ui.ghost("Skip", func() -> void: _finish(), 38, 12, 10))

	var top := Control.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(top)
	_title = Ui.label("", 29, Ui.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	column.add_child(_title)
	_diagram = TutorialDiagram.new()
	_diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_diagram)
	_body = Ui.label("", 17, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	_body.custom_minimum_size.y = 96
	column.add_child(_body)
	_dots = Ui.label("", 12, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_dots)

	var nav := Ui.row(10)
	column.add_child(nav)
	var back := Ui.ghost("Back", func() -> void: _step(-1), 58, 17)
	nav.add_child(back)
	_next = Ui.button("Next", 19, 58, Ui.GOLD, func() -> void: _step(1))
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_next)

	_render()


func _step(delta: int) -> void:
	_page = clampi(_page + delta, 0, PAGES.size() - 1)
	Audio.ui_click()
	_render()


func _render() -> void:
	var page: Dictionary = PAGES[_page]
	_title.text = String(page["title"])
	_body.text = String(page["body"])
	_diagram.step = _page
	_diagram.queue_redraw()
	var dots := ""
	for i in range(PAGES.size()):
		dots += "●" if i == _page else "○"
	_dots.text = dots
	_next.text = "Start puzzling" if _page == PAGES.size() - 1 else "Next"


func _finish() -> void:
	Save.set_setting("tutorial_done", true)
	var level := Levels.get_level(Save.next_level())
	if level.is_empty():
		Router.go("title")
	else:
		Router.go("game", {"level": level, "mode": "campaign"})
