class_name Board3D
extends Node3D
## The tactile part of the game: a wooden tray of bevelled tiles, one colour per
## territory, with Blender cats and paw-print notes.
##
## The camera fits the tray to the live viewport every time the window changes,
## which is what makes the board fill a phone screen instead of sitting in bars.
## Picking is a single ray against the board plane, so taps stay accurate at any
## resolution.

signal cell_tapped(row: int, col: int)
signal cell_double_tapped(row: int, col: int)

const TILE_MODEL := "res://Assets/Models/tile.glb"
const CAT_MODEL := "res://Assets/Models/cat.glb"
const TRAY_MODEL := "res://Assets/Models/tray.glb"
const YARN_MODEL := "res://Assets/Models/yarn.glb"

const TILE_TOP := 0.12
const GRID_STEP := 1.0

var n := 0
var regions := PackedInt32Array()
var colors: Array = []
var patterns := false
var high_contrast := false
var reduced_motion := false

var camera: Camera3D
var board_root: Node3D
var tile_root: Node3D
var border_root: Node3D
var cat_root: Node3D
var mark_root: Node3D
var decor_root: Node3D

var _tiles: Array = []
var _labels: Array = []
var _cats: Dictionary = {}
var _marks: Dictionary = {}
var _materials: Dictionary = {}
var _highlight: MeshInstance3D
var _hot := Vector2i(-1, -1)
var _showcase := false
var _zoom := 1.0
var _time := 0.0
var _fit_pending := true
var _last_engine_pointer_ms := -10000
var _last_tap_ms := -10000
var _last_tap_cell := Vector2i(-1, -1)
var _web_touch_cb: JavaScriptObject

const DOUBLE_TAP_MS := 450


func _ready() -> void:
	_build_tree()
	if not get_viewport().size_changed.is_connected(_on_resize):
		get_viewport().size_changed.connect(_on_resize)
	set_process(true)
	if OS.has_feature("web"):
		_install_web_touch()


## Some mobile browsers hand the canvas touch events without the pointer
## events Godot's web input expects. The shell forwards those taps here so a
## finger always reaches the board; taps the engine already handled are
## ignored by the timestamp guard below.
func _install_web_touch() -> void:
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return
	_web_touch_cb = JavaScriptBridge.create_callback(_on_web_touch)
	window.set("__purrfectTouch", _web_touch_cb)


func _on_web_touch(args: Array) -> void:
	if _showcase or n <= 0 or args.size() < 6:
		return
	if Time.get_ticks_msec() - _last_engine_pointer_ms < 250:
		return
	var client := Vector2(float(args[0]), float(args[1]))
	var rect := Rect2(float(args[2]), float(args[3]), float(args[4]), float(args[5]))
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var view := get_viewport().get_visible_rect().size
	var position := (client - rect.position) / rect.size * view
	var cell := cell_at(position)
	if cell.x < 0:
		return
	_handle_tap(cell)


func _build_tree() -> void:
	if board_root != null:
		return
	board_root = Node3D.new()
	board_root.name = "Tray"
	add_child(board_root)
	tile_root = Node3D.new()
	tile_root.name = "Tiles"
	board_root.add_child(tile_root)
	border_root = Node3D.new()
	border_root.name = "Grout"
	board_root.add_child(border_root)
	cat_root = Node3D.new()
	cat_root.name = "Cats"
	board_root.add_child(cat_root)
	mark_root = Node3D.new()
	mark_root.name = "Marks"
	board_root.add_child(mark_root)
	decor_root = Node3D.new()
	decor_root.name = "Decor"
	add_child(decor_root)
	camera = Camera3D.new()
	camera.fov = 34.0
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	camera.current = true


func _on_resize() -> void:
	_fit_pending = true


func _process(delta: float) -> void:
	_time += delta
	if _fit_pending:
		_fit_pending = false
		fit_camera()
	if _showcase and board_root != null and not reduced_motion:
		board_root.rotation.y = sin(_time * 0.22) * 0.12


# --------------------------------------------------------------------------
# building
# --------------------------------------------------------------------------

func build(level: Dictionary, options := {}) -> void:
	clear()
	_build_tree()
	n = int(level.get("n", 5))
	regions = LevelFactory.from_array(level.get("regions", []))
	colors = level.get("colors", Chapters.colors_for(int(level.get("id", 1)), n))
	patterns = bool(options.get("patterns", false))
	high_contrast = bool(options.get("high_contrast", false))
	reduced_motion = bool(options.get("reduced_motion", false))
	_showcase = bool(options.get("showcase", false))

	_build_tray()
	_build_tiles()
	_build_grout()
	_build_decor()
	_build_highlight()
	_fit_pending = true
	camera.current = true


func build_showcase() -> void:
	# A small, always-solvable board so the title screen has something alive.
	var n2 := 4
	var solution := [1, 3, 0, 2]
	var regions := PackedInt32Array([1, 0, 0, 2, 1, 1, 2, 2, 1, 1, 2, 2, 1, 1, 3, 2])
	var level := {
		"id": 9001,
		"n": n2,
		"regions": _to_array(regions),
		"solution": solution,
		"colors": Chapters.colors_for(9001, n2),
	}
	build(level, {"showcase": true})
	sync(solution, _blank_marks(n2))


func _to_array(values: PackedInt32Array) -> Array:
	var out: Array = []
	for value in values:
		out.append(int(value))
	return out


func _blank_marks(size: int) -> Array:
	var out: Array = []
	for r in range(size):
		var row: Array = []
		for c in range(size):
			row.append(false)
		out.append(row)
	return out


func clear() -> void:
	for container in [tile_root, border_root, cat_root, mark_root, decor_root]:
		if container == null:
			continue
		for child in container.get_children():
			child.queue_free()
	_tiles.clear()
	_labels.clear()
	_cats.clear()
	_marks.clear()
	_materials.clear()
	_highlight = null
	_hot = Vector2i(-1, -1)
	n = 0
	if board_root != null:
		for child in board_root.get_children():
			if child.name.begins_with("TrayModel"):
				child.queue_free()
		board_root.rotation = Vector3.ZERO


func _region_color(reg: int) -> Color:
	var hex := "#f2cf6b"
	if colors.size() > 0:
		hex = String(colors[reg % colors.size()])
	var color := Color(hex)
	# Nudge saturation up: the tray is lit warmly and the tonemapper washes
	# pastels out at phone brightness.
	color.s = minf(1.0, color.s * 1.08)
	color.v = minf(1.0, color.v * 1.02)
	if high_contrast:
		color = color.lightened(0.22)
	return color


func _material_for(reg: int) -> StandardMaterial3D:
	if _materials.has(reg):
		return _materials[reg]
	var mat := StandardMaterial3D.new()
	var color := _region_color(reg)
	mat.albedo_color = color
	mat.roughness = 0.62
	mat.metallic_specular = 0.16
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.05
	mat.rim_enabled = true
	mat.rim = 0.3
	mat.rim_tint = 0.7
	_materials[reg] = mat
	return mat


func _instance_model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	var instance := scene.instantiate()
	if instance is Node3D:
		return instance as Node3D
	instance.queue_free()
	return null


func _build_tray() -> void:
	var tray := _instance_model(TRAY_MODEL)
	if tray == null:
		_build_fallback_tray()
		return
	tray.name = "TrayModel"
	var width := float(n) + 1.3
	tray.scale = Vector3.ONE * (width / 11.4)
	# The Blender tray ships with a light clay material; tint it to the warm
	# walnut of the table so the bright tiles carry the colour.
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#3d2733")
	wood.roughness = 0.72
	wood.metallic_specular = 0.2
	for mesh in _all_meshes(tray):
		mesh.material_override = wood
	board_root.add_child(tray)
	board_root.move_child(tray, 0)


func _all_meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_all_meshes(child))
	return out


func _build_fallback_tray() -> void:
	var width := float(n) + 1.2
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#3a2530")
	wood.roughness = 0.55
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color("#241830")
	felt.roughness = 0.9
	var base := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(width, 0.3, width)
	base.mesh = slab
	base.material_override = wood
	base.position.y = -0.14
	board_root.add_child(base)
	var top := MeshInstance3D.new()
	var lining := BoxMesh.new()
	lining.size = Vector3(width - 0.35, 0.06, width - 0.35)
	top.mesh = lining
	top.material_override = felt
	top.position.y = 0.0
	board_root.add_child(top)
	for side in [-1, 1]:
		for axis in [0, 1]:
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(width, 0.1, 0.16) if axis == 0 else Vector3(0.16, 0.1, width)
			rail.mesh = rail_mesh
			rail.material_override = wood
			if axis == 0:
				rail.position = Vector3(0, 0.05, side * (width * 0.5 - 0.08))
			else:
				rail.position = Vector3(side * (width * 0.5 - 0.08), 0.05, 0)
			board_root.add_child(rail)


func _build_tiles() -> void:
	var tile_scene: PackedScene = null
	if ResourceLoader.exists(TILE_MODEL):
		tile_scene = load(TILE_MODEL)
	var half := (float(n) - 1.0) * 0.5
	for r in range(n):
		for c in range(n):
			var cell := r * n + c
			var holder := Node3D.new()
			# The tile mesh is 0.12 tall centred on its origin, so lift it half a
			# tile: its top face then lands exactly on TILE_TOP for picking.
			holder.position = Vector3(float(c) - half, 0.06, float(r) - half)
			tile_root.add_child(holder)
			var mesh_node: MeshInstance3D = null
			if tile_scene != null:
				var instance := tile_scene.instantiate()
				mesh_node = _find_mesh(instance)
				if mesh_node != null:
					instance.remove_child(mesh_node)
					mesh_node.position = Vector3.ZERO
				instance.queue_free()
			if mesh_node == null:
				mesh_node = MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.94, 0.12, 0.94)
				mesh_node.mesh = box
				mesh_node.position.y = 0.06
			mesh_node.material_override = _material_for(regions[cell])
			holder.add_child(mesh_node)
			_tiles.append(mesh_node)
			if patterns:
				var label := Label3D.new()
				label.text = str(regions[cell] + 1)
				label.font_size = 48
				label.pixel_size = 0.004
				label.modulate = Color(0.12, 0.08, 0.15, 0.55)
				label.position = holder.position + Vector3(-0.34, TILE_TOP + 0.02, 0.34)
				label.rotation_degrees = Vector3(-90, 0, 0)
				label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				label.no_depth_test = false
				border_root.add_child(label)
				_labels.append(label)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null


func _build_grout() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3a2b44") if not high_contrast else Color("#120c18")
	mat.roughness = 0.8
	var half := (float(n) - 1.0) * 0.5
	for r in range(n):
		for c in range(n):
			var cell := r * n + c
			var here := regions[cell]
			var x := float(c) - half
			var z := float(r) - half
			if c + 1 < n and regions[cell + 1] != here:
				_grout_strip(Vector3(x + 0.5, TILE_TOP + 0.02, z), Vector3(0.05, 0.03, 1.0), mat)
			if r + 1 < n and regions[cell + n] != here:
				_grout_strip(Vector3(x, TILE_TOP + 0.02, z + 0.5), Vector3(1.0, 0.03, 0.05), mat)


func _grout_strip(position: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = position
	border_root.add_child(mesh)


func _build_decor() -> void:
	var yarn := _instance_model(YARN_MODEL)
	if yarn != null:
		# Rest it on the table beside the tray rather than floating at tile height.
		yarn.scale = Vector3.ONE * 1.6
		yarn.position = Vector3(float(n) * 0.5 + 0.55, -0.3, -float(n) * 0.5 + 0.25)
		decor_root.add_child(yarn)


func _build_highlight() -> void:
	_highlight = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.02, 0.02, 1.02)
	_highlight.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#fff3d0")
	mat.emission_enabled = true
	mat.emission = Color("#ffe6a8")
	mat.emission_energy_multiplier = 0.9
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.35
	_highlight.material_override = mat
	_highlight.visible = false
	board_root.add_child(_highlight)


# --------------------------------------------------------------------------
# camera
# --------------------------------------------------------------------------

func fit_camera() -> void:
	if camera == null or n <= 0:
		return
	var size := get_viewport().get_visible_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var aspect := size.x / size.y
	var span := float(n) + 1.55
	var vfov := deg_to_rad(camera.fov)
	var hfov := 2.0 * atan(tan(vfov * 0.5) * aspect)
	var tilt := deg_to_rad(63.0)
	var by_width := (span * 0.52) / tan(hfov * 0.5)
	var projected_depth := span * sin(tilt) * 0.55 + span * 0.16
	var by_height := projected_depth / tan(vfov * 0.5)
	var distance := maxf(by_width, by_height) * 1.02 * _zoom
	var target := Vector3(0, 0.05, 0)
	camera.position = target + Vector3(0, sin(tilt), cos(tilt)) * distance
	camera.look_at(target, Vector3.UP)


# --------------------------------------------------------------------------
# board state
# --------------------------------------------------------------------------

func sync(cats: Array, marks: Array) -> void:
	if n <= 0:
		return
	var half := (float(n) - 1.0) * 0.5
	for r in range(n):
		var c := int(cats[r]) if r < cats.size() else -1
		var has := _cats.has(r)
		if c >= 0 and not has:
			var view := CatView.new()
			view.reduced_motion = reduced_motion
			view.position = Vector3(float(c) - half, TILE_TOP + 0.01, float(r) - half)
			cat_root.add_child(view)
			view.setup(r * 7 + c)
			view.set_base_y(TILE_TOP + 0.01)
			view.pop()
			_cats[r] = view
		elif c >= 0 and has:
			var view: CatView = _cats[r]
			if view != null and is_instance_valid(view):
				view.position.x = float(c) - half
				view.position.z = float(r) - half
		elif c < 0 and has:
			var view: CatView = _cats[r]
			if view != null and is_instance_valid(view):
				view.queue_free()
			_cats.erase(r)
	for r in range(n):
		for c in range(n):
			var key := r * n + c
			var marked := false
			if r < marks.size() and c < (marks[r] as Array).size():
				marked = bool(marks[r][c])
			if marked and not _marks.has(key):
				var cross := _make_cross()
				cross.position = Vector3(float(c) - half, TILE_TOP + 0.02, float(r) - half)
				mark_root.add_child(cross)
				_marks[key] = cross
			elif not marked and _marks.has(key):
				(_marks[key] as Node3D).queue_free()
				_marks.erase(key)


## A crisp X on the tile: minesweeper's cheap, reversible "not here" mark.
func _make_cross() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3b2545")
	mat.roughness = 0.86
	mat.emission_enabled = true
	mat.emission = Color("#2a1d33")
	mat.emission_energy_multiplier = 0.12
	for angle in [45.0, -45.0]:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.58, 0.045, 0.12)
		bar.mesh = box
		bar.material_override = mat
		bar.rotation_degrees.y = angle
		root.add_child(bar)
	return root


func flash_wrong(row: int, col: int) -> void:
	if n <= 0:
		return
	var index := row * n + col
	if index < 0 or index >= _tiles.size():
		return
	var tile: MeshInstance3D = _tiles[index]
	var original: Material = tile.material_override
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#b8434f")
	red.emission_enabled = true
	red.emission = Color("#ff6b6b")
	red.emission_energy_multiplier = 0.6
	tile.material_override = red
	var tween := create_tween()
	tween.tween_interval(0.18)
	tween.tween_callback(func() -> void:
		if is_instance_valid(tile):
			tile.material_override = original)


func highlight(row: int, col: int, duration := 1.6) -> void:
	if _highlight == null or n <= 0:
		return
	var half := (float(n) - 1.0) * 0.5
	_highlight.position = Vector3(float(col) - half, TILE_TOP + 0.03, float(row) - half)
	_highlight.visible = true
	_highlight.scale = Vector3(1, 1, 1)
	var tween := create_tween()
	tween.tween_property(_highlight, "scale", Vector3(1.08, 1.0, 1.08), 0.35)
	tween.tween_property(_highlight, "scale", Vector3(1.0, 1.0, 1.0), 0.35)
	tween.tween_interval(maxf(0.4, duration - 0.7))
	tween.tween_callback(func() -> void:
		if is_instance_valid(_highlight):
			_highlight.visible = false)


func celebrate() -> void:
	var index := 0
	for key in _cats.keys():
		var view: CatView = _cats[key]
		if view != null and is_instance_valid(view):
			view.hop(0.06 * index)
		index += 1


func shake_cat(row: int) -> void:
	if _cats.has(row):
		var view: CatView = _cats[row]
		if view != null and is_instance_valid(view):
			view.shake()


# --------------------------------------------------------------------------
# input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _showcase or n <= 0:
		return
	var position := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		_last_engine_pointer_ms = Time.get_ticks_msec()
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		position = touch.position
		pressed = true
	elif event is InputEventMouseButton:
		_last_engine_pointer_ms = Time.get_ticks_msec()
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
			return
		position = click.position
		pressed = true
	if not pressed:
		return
	var cell := cell_at(position)
	if cell.x < 0:
		return
	get_viewport().set_input_as_handled()
	_handle_tap(cell)


## One tap crosses a square out; a quick second tap on the same square places
## a cat. The cheap, reversible action is the easy gesture, and committing a
## cat takes a deliberate double tap — minesweeper muscle memory.
func _handle_tap(cell: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	if cell == _last_tap_cell and now - _last_tap_ms <= DOUBLE_TAP_MS:
		_last_tap_ms = -10000
		_last_tap_cell = Vector2i(-1, -1)
		cell_double_tapped.emit(cell.x, cell.y)
		return
	_last_tap_ms = now
	_last_tap_cell = cell
	cell_tapped.emit(cell.x, cell.y)


## Maps a screen point to a board cell, or (-1, -1) when the ray misses.
func cell_at(position: Vector2) -> Vector2i:
	if camera == null or n <= 0:
		return Vector2i(-1, -1)
	var origin := camera.project_ray_origin(position)
	var direction := camera.project_ray_normal(position)
	if absf(direction.y) < 0.0001:
		return Vector2i(-1, -1)
	var distance := (TILE_TOP - origin.y) / direction.y
	if distance < 0.0:
		return Vector2i(-1, -1)
	var hit := origin + direction * distance
	var half := (float(n) - 1.0) * 0.5
	var col := int(round(hit.x + half))
	var row := int(round(hit.z + half))
	if row < 0 or col < 0 or row >= n or col >= n:
		return Vector2i(-1, -1)
	return Vector2i(row, col)


func set_zoom(value: float) -> void:
	_zoom = clampf(value, 0.5, 2.5)
	_fit_pending = true


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for key in _cats.keys():
		var view: CatView = _cats[key]
		if view != null and is_instance_valid(view):
			view.reduced_motion = value
