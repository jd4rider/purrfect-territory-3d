extends SceneTree

func brute(regions: PackedInt32Array, n: int) -> Array:
	var out: Array = []
	var total := int(pow(n, n))
	for code in range(total):
		var cats: Array = []
		var value := code
		for r in range(n):
			cats.append(value % n)
			value /= n
		var check := PuzzleModel.validate(regions, n, cats)
		if bool(check["ok"]):
			out.append(cats)
	return out

func _init() -> void:
	var n := 4
	var regions := PackedInt32Array([1, 0, 0, 2, 1, 1, 2, 2, 1, 1, 2, 2, 1, 1, 3, 2])
	print("brute force solutions: ", brute(regions, n))
	print("exact solver limit 2: ", ExactSolver.solve(regions, n, 2))
	print("exact solver limit 9: ", ExactSolver.solve(regions, n, 9))
	quit()
