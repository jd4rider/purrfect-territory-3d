extends SceneTree

func _init() -> void:
	for n in [4, 5, 6]:
		for i in range(6):
			var r := LevelFactory.produce(n, 500 + i * 37 + n * 11, [])
			print("n=%d i=%d ok=%s attempts=%s ms=%s diff=%s" % [n, i, r["ok"], r["attempts"], r["ms"], (r["level"] as Dictionary).get("difficulty", "-")])
	quit()
