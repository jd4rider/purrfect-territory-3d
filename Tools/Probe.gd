extends SceneTree
## Generation probe: measures yield, uniqueness, difficulty spread and timing
## before any content is committed. Run with:
##   godot --headless --path . -s Tools/Probe.gd

func _init() -> void:
	var sizes: Array = []
	for value in OS.get_cmdline_user_args():
		sizes.append(int(value))
	if sizes.is_empty():
		sizes = [4, 5, 6, 7, 8, 9, 10]
	print("size  built  tries   ms   difficulties                     region-shapes")
	for n in sizes:
		var started := Time.get_ticks_msec()
		var ok := 0
		var attempts := 0
		var difficulties := {}
		var size_shapes := {}
		for i in range(8):
			var result := LevelFactory.produce(n, 7000 + n * 997 + i * 13)
			attempts += int(result["attempts"])
			if not bool(result["ok"]):
				continue
			ok += 1
			var level: Dictionary = result["level"]
			var difficulty := String(level["difficulty"])
			difficulties[difficulty] = int(difficulties.get(difficulty, 0)) + 1
			var shape := str((level["metrics"] as Dictionary)["regions"])
			size_shapes[shape] = int(size_shapes.get(shape, 0)) + 1
		var elapsed := Time.get_ticks_msec() - started
		print("%3d %6d %6d %5d  %-32s %d" % [n, ok, attempts, elapsed, str(difficulties), size_shapes.size()])
	quit()
