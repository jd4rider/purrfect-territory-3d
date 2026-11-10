class_name CatView
extends Node3D
## One resident of the board: a Blender cat with a gentle idle bob, a pop-in
## when placed, a hop on victory and a shake when a rule is broken.
##
## If the GLB has not been imported yet (a fresh checkout before the asset
## step), a primitives cat of the same proportions is assembled instead, so the
## board never shows an invisible or blobby piece. Either way the model is
## measured and scaled to fit one tile.

const MODEL := "res://Assets/Models/cat.glb"
const CAT_HEIGHT := 0.62

var reduced_motion := false
var _model: Node3D
var _time := 0.0
var _phase := 0.0
var _base_y := 0.0
var _bob := true


func setup(seed_value: int = 0) -> void:
	_phase = float(seed_value) * 1.7
	if ResourceLoader.exists(MODEL):
		var scene: PackedScene = load(MODEL)
		_model = scene.instantiate() as Node3D
		if _model != null:
			add_child(_model)
	if _model == null:
		_fallback()
	_fit_to_tile()


## Scale whichever model we ended up with so it stands CAT_HEIGHT tall on the
## tile, with its feet at y = 0 and its footprint centred on the tile.
func _fit_to_tile() -> void:
	if _model == null:
		return
	var box := _model_aabb()
	if box.size.y < 0.001:
		return
	var factor := CAT_HEIGHT / box.size.y
	_model.scale *= factor
	var centre := box.get_center()
	_model.position = Vector3(-centre.x * factor, -box.position.y * factor, -centre.z * factor)


func _model_aabb() -> AABB:
	var first := true
	var merged := AABB()
	var inverse := _model.global_transform.affine_inverse()
	_merge_aabb(_model, inverse, merged, first)
	return merged


func _merge_aabb(node: Node, inverse: Transform3D, merged: AABB, first: bool) -> AABB:
	var result := merged
	var any := not first
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_node := child as MeshInstance3D
			if mesh_node.mesh != null:
				var local := inverse * mesh_node.global_transform
				var box: AABB = local * mesh_node.mesh.get_aabb()
				if any:
					result = result.merge(box)
				else:
					result = box
					any = true
		if child.get_child_count() > 0:
			result = _merge_aabb(child, inverse, result, not any)
			any = true
	return result


func set_base_y(value: float) -> void:
	_base_y = value
	position.y = value


func pop() -> void:
	scale = Vector3(0.05, 0.05, 0.05)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hop(delay: float = 0.0) -> void:
	if reduced_motion:
		return
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "position:y", _base_y + 0.2, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", _base_y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation:y", 0.22, 0.18)
	tween.tween_property(self, "rotation:y", 0.0, 0.2)


func shake() -> void:
	if reduced_motion:
		return
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", 0.16, 0.06)
	tween.tween_property(self, "rotation:z", -0.16, 0.1)
	tween.tween_property(self, "rotation:z", 0.09, 0.08)
	tween.tween_property(self, "rotation:z", 0.0, 0.08)


func _process(delta: float) -> void:
	if reduced_motion or not _bob:
		return
	_time += delta
	position.y = _base_y + sin(_time * 1.6 + _phase) * 0.012
	rotation.y = sin(_time * 1.1 + _phase) * 0.035


func _material(hex: String, roughness := 0.65) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = roughness
	return mat


func _sphere(parent: Node3D, at: Vector3, scale_value: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.scale = scale_value
	parent.add_child(node)
	return node


func _fallback() -> void:
	var root := Node3D.new()
	add_child(root)
	var fur := _material("#ffe8c9")
	var light := _material("#fff6e8")
	var pink := _material("#f0a6bd", 0.5)
	var dark := _material("#2a1d33", 0.35)
	var bell := _material("#f2cf6b", 0.3)
	bell.metallic = 0.4

	# shadow
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.01
	shadow.mesh = disc
	var shadow_mat := _material("#120c18")
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.07, 0.05, 0.09, 0.35)
	shadow.material_override = shadow_mat
	shadow.position = Vector3(0, 0.008, 0.02)
	shadow.scale = Vector3(1.0, 1.0, 0.9)
	root.add_child(shadow)

	_sphere(root, Vector3(0, 0.42, 0.0), Vector3(0.34, 0.38, 0.30), fur)
	_sphere(root, Vector3(0, 0.44, 0.24), Vector3(0.20, 0.22, 0.12), light)
	# head, facing +Z (toward the camera)
	_sphere(root, Vector3(0, 0.82, 0.06), Vector3(0.30, 0.27, 0.27), fur)
	_sphere(root, Vector3(0, 0.74, 0.28), Vector3(0.14, 0.10, 0.10), light)
	_sphere(root, Vector3(0, 0.76, 0.37), Vector3(0.035, 0.03, 0.03), pink)
	_sphere(root, Vector3(-0.13, 0.86, 0.28), Vector3(0.045, 0.055, 0.04), dark)
	_sphere(root, Vector3(0.13, 0.86, 0.28), Vector3(0.045, 0.055, 0.04), dark)
	_sphere(root, Vector3(-0.22, 0.70, 0.24), Vector3(0.055, 0.03, 0.04), pink)
	_sphere(root, Vector3(0.22, 0.70, 0.24), Vector3(0.055, 0.03, 0.04), pink)
	# ears
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.12
		cone.height = 0.26
		ear.mesh = cone
		ear.material_override = fur
		ear.position = Vector3(side * 0.17, 1.02, 0.04)
		ear.rotation_degrees = Vector3(0, 0, side * -14)
		root.add_child(ear)
		var inner := MeshInstance3D.new()
		var inner_cone := CylinderMesh.new()
		inner_cone.top_radius = 0.0
		inner_cone.bottom_radius = 0.07
		inner_cone.height = 0.18
		inner.mesh = inner_cone
		inner.material_override = pink
		inner.position = Vector3(side * 0.17, 1.0, 0.09)
		inner.rotation_degrees = Vector3(0, 0, side * -14)
		root.add_child(inner)
	# front paws
	for side in [-1, 1]:
		_sphere(root, Vector3(side * 0.17, 0.10, 0.20), Vector3(0.10, 0.075, 0.13), light)
	# collar and bell
	var collar := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.24
	ring.outer_radius = 0.29
	collar.mesh = ring
	collar.material_override = _material("#7fc8a9", 0.4)
	collar.position = Vector3(0, 0.60, 0.03)
	collar.rotation_degrees = Vector3(80, 0, 0)
	root.add_child(collar)
	_sphere(root, Vector3(0, 0.53, 0.28), Vector3(0.045, 0.045, 0.045), bell)
	# tail curling up behind
	var tail := Node3D.new()
	root.add_child(tail)
	for index in range(4):
		var segment := _sphere(tail, Vector3(0.24 + index * 0.03, 0.18 + index * 0.16, -0.16 + index * 0.02),
			Vector3(0.075, 0.13, 0.075), fur)
		segment.rotation_degrees = Vector3(0, 0, -18 - index * 4)
	_model = root
