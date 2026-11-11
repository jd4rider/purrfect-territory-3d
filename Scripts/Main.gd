extends Node
## Application shell: the lit 3D table, the screen router and a thin web debug
## bridge used by the automated browser smoke test.

const SCREEN_PATHS := {
	"title": "res://Scripts/Screens/TitleScreen.gd",
	"chapters": "res://Scripts/Screens/ChapterScreen.gd",
	"levels": "res://Scripts/Screens/LevelScreen.gd",
	"game": "res://Scripts/Screens/GameScreen.gd",
	"settings": "res://Scripts/Screens/SettingsScreen.gd",
	"tutorial": "res://Scripts/Screens/TutorialScreen.gd",
	"trophies": "res://Scripts/Screens/TrophyScreen.gd",
}

var world: Node3D
var screen_root: Control
var board: Board3D
var current_screen: Control
var current_name := ""
var history: Array = []
var toast_label: Label
var toast_timer: Timer
var _debug_clock := 0.0
var _debug_available := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Router.main = self
	_build_world()
	_build_ui()
	_debug_available = OS.has_feature("web")
	var resumed := _resume_payload()
	if resumed.is_empty():
		show_screen("title")
		Audio.play_music("cozy")
	else:
		show_screen("game", resumed)


func _notification(what: int) -> void:
	# A phone can suspend or reload the page at any moment, so write the pending
	# tray to disk before that happens.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_inside_tree():
			Save.flush()


## A puzzle that was left mid-solve (or interrupted by a page reload) comes back
## exactly as it was instead of dropping the player on the title screen.
func _resume_payload() -> Dictionary:
	var saved: Dictionary = Save.session()
	if saved.is_empty():
		return {}
	var raw: Variant = saved.get("level", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var level: Dictionary = raw
	if level.is_empty() or not level.has("regions") or not level.has("n"):
		return {}
	return {"level": level, "mode": String(saved.get("mode", "campaign")), "resume": saved}


func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#150f1c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a793b6")
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_enabled = true
	environment.glow_intensity = 0.3
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	world.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe6c4")
	key.light_energy = 0.82
	key.rotation_degrees = Vector3(-54, -38, 0)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 46.0
	world.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#9fc2e8")
	fill.light_energy = 0.24
	fill.rotation_degrees = Vector3(-18, 140, 0)
	world.add_child(fill)

	# the table the tray sits on, and a warm pool of light above it
	var table := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 30.0
	disc.bottom_radius = 30.0
	disc.height = 0.6
	disc.radial_segments = 64
	table.mesh = disc
	table.position = Vector3(0, -0.62, 0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#2b1b26")
	wood.roughness = 0.82
	table.material_override = wood
	world.add_child(table)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 9.0, 3.0)
	lamp.light_color = Color("#ffd9a0")
	lamp.light_energy = 0.78
	lamp.omni_range = 26.0
	lamp.shadow_enabled = false
	world.add_child(lamp)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(screen_root)

	toast_label = Ui.label("", 15, Ui.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_left = 30
	toast_label.offset_right = -30
	toast_label.offset_top = -150
	toast_label.offset_bottom = -100
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.visible = false
	layer.add_child(toast_label)
	var panel := Ui.panel(Color("#241830"), 18, Color("#5b3f74"), 12)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 30
	panel.offset_right = -30
	panel.offset_top = -150
	panel.offset_bottom = -100
	panel.visible = false
	panel.name = "ToastPanel"
	layer.add_child(panel)
	layer.move_child(panel, toast_label.get_index())
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 3.0
	toast_timer.timeout.connect(func() -> void:
		toast_label.visible = false
		(panel as Control).visible = false)
	layer.add_child(toast_timer)


func show_toast(text: String) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.visible = true
	var panel: Control = get_node_or_null("UI/ToastPanel")
	if panel != null:
		panel.visible = true
	toast_timer.start()


func show_screen(name: String, payload := {}) -> void:
	var path: String = SCREEN_PATHS.get(name, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("unknown screen %s" % name)
		return
	clear_board()
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null
	var script: GDScript = load(path)
	var screen := script.new() as Control
	if screen == null:
		return
	if screen.has_method("configure"):
		screen.call("configure", payload)
	screen_root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_screen = screen
	current_name = name
	Audio.play_music("focus" if name == "game" else "cozy")


func navigate(name: String, payload := {}) -> void:
	history.append({"screen": current_name, "payload": {}})
	if history.size() > 24:
		history.pop_front()
	show_screen(name, payload)


func go_back() -> void:
	if history.is_empty():
		show_screen("title")
		return
	var entry: Dictionary = history.pop_back()
	show_screen(String(entry["screen"]), entry.get("payload", {}))


func spawn_board(level: Dictionary, options := {}) -> Board3D:
	clear_board()
	board = Board3D.new()
	board.name = "Board"
	world.add_child(board)
	board.build(level, options)
	board.set_process(true)
	return board


func clear_board() -> void:
	if board != null and is_instance_valid(board):
		board.queue_free()
	board = null


func _unhandled_input(event: InputEvent) -> void:
	# The first real gesture is what lets browsers start audio.
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		Audio.kick()


# --------------------------------------------------------------------------
# web debug bridge
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _debug_available:
		return
	_debug_clock += delta
	if _debug_clock < 0.2:
		return
	_debug_clock = 0.0
	_publish_state()
	_poll_command()


func _publish_state() -> void:
	var state := {
		"screen": current_name,
		"board": board != null,
		"level": 0,
	}
	if current_screen != null and current_screen.has_method("debug_state"):
		state.merge(current_screen.call("debug_state"), true)
	if board != null and board.n > 0:
		var probe_row := 1 if board.n > 1 else 0
		var probe_col := 1 if board.n > 1 else 0
		var half := (float(board.n) - 1.0) * 0.5
		var point := Vector3(float(probe_col) - half, Board3D.TILE_TOP, float(probe_row) - half)
		var screen_point := board.camera.unproject_position(point)
		state["probe"] = {
			"row": probe_row,
			"col": probe_col,
			"x": screen_point.x,
			"y": screen_point.y,
		}
		state["board_n"] = board.n
		var region_list: Array = []
		for value in board.regions:
			region_list.append(int(value))
		state["regions"] = region_list
		state["colors"] = board.colors
	state["canvas"] = {
		"w": int(get_viewport().get_visible_rect().size.x),
		"h": int(get_viewport().get_visible_rect().size.y),
	}
	var text := JSON.stringify(state)
	JavaScriptBridge.eval(
		"window.__purrfectState = JSON.parse(atob('%s'))" % Marshalls.utf8_to_base64(text), true)


func _poll_command() -> void:
	var raw: Variant = JavaScriptBridge.eval("window.__purrfectCommand || ''", true)
	if raw == null:
		return
	var command := String(raw)
	if command.is_empty():
		return
	JavaScriptBridge.eval("window.__purrfectCommand = ''", true)
	_run_command(command)


func _run_command(command: String) -> void:
	var parts := command.split(":")
	match parts[0]:
		"screen":
			if parts.size() > 1:
				show_screen(parts[1])
		"start":
			if parts.size() > 2 and parts[1] == "campaign":
				var level := Levels.get_level(int(parts[2]))
				show_screen("game", {"level": level, "mode": "campaign"})
		"daily":
			show_screen("game", {"level": Levels.daily(), "mode": "daily"})
		"practice":
			show_screen("game", {"level": Levels.practice(), "mode": "practice"})
		"tap":
			if parts.size() > 2 and current_screen != null and current_screen.has_method("debug_tap"):
				current_screen.call("debug_tap", int(parts[1]), int(parts[2]))
		"hint":
			if current_screen != null and current_screen.has_method("_hint"):
				current_screen.call("_hint")
		"undo":
			if current_screen != null and current_screen.has_method("_undo"):
				current_screen.call("_undo")
		"reset":
			if current_screen != null and current_screen.has_method("_reset"):
				current_screen.call("_reset")
		"solve":
			if current_screen != null and current_screen.has_method("debug_solve"):
				current_screen.call("debug_solve")
		"next":
			if current_screen != null and current_screen.has_method("_next_puzzle"):
				current_screen.call("_next_puzzle")
		"back":
			go_back()
