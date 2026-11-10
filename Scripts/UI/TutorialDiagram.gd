class_name TutorialDiagram
extends Control
## A 4x4 board drawn with primitives, one rule per step. No image assets, so it
## stays crisp at every pixel density and explains the rule it is showing.

var step := 0
var tint := Color("#f2cf6b")

const REGIONS := [1, 0, 0, 2, 1, 1, 2, 2, 1, 1, 2, 2, 1, 1, 3, 2]
const CATS := [1, 3, 0, 2]
const COLORS := ["#f2cf6b", "#8fd9c3", "#c79be8", "#f0a6bd"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(260, 260)


func _draw() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return
	var span := minf(size.x, size.y) - 8.0
	var side := span / 4.0
	var origin := Vector2((size.x - span) * 0.5, (size.y - span) * 0.5)
	var radius := side * 0.44

	# tray
	draw_rect(Rect2(origin - Vector2(6, 6), Vector2(span + 12, span + 12)), Color("#3a2a44"))

	for r in range(4):
		for c in range(4):
			var rect := Rect2(origin + Vector2(c * side + 2, r * side + 2), Vector2(side - 4, side - 4))
			var region := int(REGIONS[r * 4 + c])
			var color := Color(String(COLORS[region]))
			if step < 2:
				color = Color("#4b3a58")
			elif step == 2:
				color = color.darkened(0.15)
			draw_rect(rect, color)

	# rule 1: one cat per row
	if step <= 1:
		for r in range(4):
			var y := origin.y + r * side + side * 0.5
			draw_line(Vector2(origin.x - 4, y), Vector2(origin.x + span + 4, y), Color(tint, 0.55), 3.0)

	# rule 2: one cat per column
	if step == 1:
		for c in range(4):
			var x := origin.x + c * side + side * 0.5
			draw_line(Vector2(x, origin.y - 4), Vector2(x, origin.y + span + 4), Color(tint, 0.55), 3.0)

	if step < 3:
		for r in range(4):
			var c := int(CATS[r])
			var center := origin + Vector2(c * side + side * 0.5, r * side + side * 0.5)
			_draw_cat(center, radius, Color("#ffe8c9"))
	else:
		# rule 4: no touching, even diagonally
		var a := origin + Vector2(side * 0.5, side * 0.5)
		var b := origin + Vector2(side * 1.5, side * 1.5)
		_draw_cat(a, radius, Color("#ffe8c9"))
		_draw_cat(b, radius, Color("#ffe8c9"))
		draw_line(a + Vector2(-radius, radius), b + Vector2(radius, -radius), Color("#ef7d7d"), 6.0)
		draw_line(a + Vector2(-radius, -radius), b + Vector2(radius, radius), Color("#ef7d7d"), 6.0)
		var warn := Ui.label("not allowed", 12, Color("#ef7d7d"), HORIZONTAL_ALIGNMENT_CENTER)
		warn.position = Vector2(origin.x, origin.y + span + 2)
		warn.size = Vector2(span, 18)


func _draw_cat(center: Vector2, radius: float, fur: Color) -> void:
	# ears
	var ear := radius * 0.42
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-radius * 0.62, -radius * 0.52),
		center + Vector2(-radius * 0.88, -radius * 1.12),
		center + Vector2(-radius * 0.18, -radius * 0.86),
	]), fur)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(radius * 0.62, -radius * 0.52),
		center + Vector2(radius * 0.88, -radius * 1.12),
		center + Vector2(radius * 0.18, -radius * 0.86),
	]), fur)
	draw_circle(center, radius, fur)
	draw_circle(center + Vector2(-radius * 0.32, -radius * 0.12), radius * 0.1, Color("#2a1d33"))
	draw_circle(center + Vector2(radius * 0.32, -radius * 0.12), radius * 0.1, Color("#2a1d33"))
	draw_circle(center + Vector2(0, radius * 0.16), radius * 0.09, Color("#f0a6bd"))
