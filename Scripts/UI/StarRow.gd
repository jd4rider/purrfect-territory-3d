class_name StarRow
extends Control
## Three hand-drawn stars. The bundled font has no star glyph, and a drawn star
## can actually be animated, so the results card gets real gold stars.

var filled := 3
var total := 3
var size_px := 30.0
var gap := 8.0
var color := Color("#f2cf6b")
var empty_color := Color("#4b3a58")
var _pop := 0.0


static func star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(10):
		var angle := -PI / 2.0 + float(i) * PI / 5.0
		var r := radius if i % 2 == 0 else radius * 0.44
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2((size_px + gap) * total, size_px + 6.0)


func animate_in() -> void:
	_pop = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_pop", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		queue_redraw())


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var width := (size_px + gap) * total - gap
	var start := Vector2((size.x - width) * 0.5, size.y * 0.5)
	for i in range(total):
		var center := start + Vector2(size_px * 0.5 + i * (size_px + gap), 0)
		var radius := size_px * 0.52
		var on := i < filled
		if on and _pop < 1.0:
			radius *= maxf(0.25, _pop)
		draw_colored_polygon(star_points(center, radius), color if on else empty_color)
		if on:
			draw_colored_polygon(star_points(center, radius * 0.55), color.lightened(0.25))
