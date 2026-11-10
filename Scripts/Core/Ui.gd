class_name Ui
extends RefCounted
## Shared cosy UI kit: colours, panels, buttons, labels.

const INK := Color("#fbf3e6")
const MUTED := Color("#c3b3c9")
const DIM := Color("#7d6b86")
const CREAM := Color("#ffe8bd")
const GOLD := Color("#f2cf6b")
const MINT := Color("#8fd9c3")
const ROSE := Color("#f0a6bd")
const PLUM := Color("#2a1d33")
const PLUM_HI := Color("#382843")
const NIGHT := Color("#150f1c")
const DANGER := Color("#ef7d7d")


static func label(text: String, size: int, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT,
		wrap := false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = align
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return node


static func box(color: Color, radius := 22, border := Color.TRANSPARENT, pad := 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	if border.a > 0.0:
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = border
	return style


static func button(text: String, size: int, height: int, color: Color, on_press: Callable,
		text_color := Color("#2a1d33"), pad := 16) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = height
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", text_color)
	node.add_theme_color_override("font_hover_color", text_color)
	node.add_theme_color_override("font_pressed_color", text_color)
	node.add_theme_color_override("font_disabled_color", DIM)
	node.add_theme_stylebox_override("normal", box(color, 20, Color.TRANSPARENT, pad))
	node.add_theme_stylebox_override("hover", box(color.lightened(0.08), 20, Color.TRANSPARENT, pad))
	node.add_theme_stylebox_override("pressed", box(color.darkened(0.10), 20, Color.TRANSPARENT, pad))
	node.add_theme_stylebox_override("disabled", box(Color("#241a2d"), 20, Color.TRANSPARENT, pad))
	node.pressed.connect(func() -> void:
		Audio.ui_click()
		on_press.call())
	return node


static func ghost(text: String, on_press: Callable, height := 62, size := 20, pad := 14) -> Button:
	var node := button(text, size, height, Color("#332341"), on_press, INK, pad)
	node.add_theme_stylebox_override("normal", box(Color("#2c1f39"), 20, Color("#4a3560"), pad))
	node.add_theme_stylebox_override("hover", box(Color("#3a2a4a"), 20, Color("#6b4c88"), pad))
	node.add_theme_stylebox_override("pressed", box(Color("#23182e"), 20, Color("#6b4c88"), pad))
	node.add_theme_stylebox_override("disabled", box(Color("#1d1526"), 20, Color("#33253f"), pad))
	return node


static func panel(color := PLUM, radius := 24, border := Color.TRANSPARENT, pad := 16) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(color, radius, border, pad))
	return node


static func pill(text: String, size := 14, color := GOLD) -> Label:
	var node := label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	node.add_theme_stylebox_override("normal", box(Color(color, 0.16), 14, Color(color, 0.5), 10))
	return node


static func spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = height
	return node


static func row(gap := 10) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func column(gap := 10) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func scroll() -> ScrollContainer:
	var node := ScrollContainer.new()
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func format_time(seconds: int) -> String:
	var minutes := seconds / 60
	var rest := seconds % 60
	return "%d:%02d" % [minutes, rest]


static func stars_text(stars: int, total := 3) -> String:
	var out := ""
	for i in range(total):
		out += "*" if i < stars else "-"
	return out


## Soft vertical wash used behind every menu.
static func backdrop(from: Color, to: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, from)
	gradient.set_color(1, to)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.2, 0.0)
	texture.fill_to = Vector2(0.8, 1.0)
	texture.width = 8
	texture.height = 256
	var node := TextureRect.new()
	node.texture = texture
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	return node


static func clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


## A small five-petal paw glyph drawn with primitives, used as a bullet and a
## mark on the board. The bundled font has no emoji, so shapes it is.
static func paw(size: int, color := ROSE) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(size, size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.draw.connect(func() -> void:
		var center := Vector2(size * 0.5, size * 0.62)
		node.draw_circle(center, size * 0.22, color)
		node.draw_circle(center + Vector2(-size * 0.22, -size * 0.16), size * 0.10, color)
		node.draw_circle(center + Vector2(0.0, -size * 0.26), size * 0.10, color)
		node.draw_circle(center + Vector2(size * 0.22, -size * 0.16), size * 0.10, color))
	return node
