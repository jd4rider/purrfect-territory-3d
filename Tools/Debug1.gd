extends SceneTree

func _init() -> void:
	var n := 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	print("A random solution")
	var solution := LevelFactory.random_solution(n, rng)
	print("  ", solution)
	print("B build regions")
	var regions := RegionGen.build(n, solution, rng, "organic")
	print("  ", regions)
	print("C connected ", PuzzleModel.regions_connected(regions, n))
	print("D unique count ", ExactSolver.count(regions, n, 2))
	print("E human solve")
	var human := HumanSolver.solve(regions, n)
	print("  solved=", human["solved"], " difficulty=", human["difficulty"], " solution=", human["solution"])
	print("F produce")
	var result := LevelFactory.produce(n, 999)
	print("  ok=", result["ok"], " attempts=", result["attempts"], " ms=", result["ms"])
	quit()
