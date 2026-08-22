extends SceneTree
## Every level must be solvable and must start tangled. Both are asserted, for all 60, before
## anything ships — a puzzle game whose level 43 has no solution is worse than one with 42 levels.
func _init() -> void:
	var Levels := load("res://data/levels.gd")
	var fails := 0
	var starts := 0
	for n in Levels.COUNT:
		var lv: Dictionary = Levels.build(n)
		var solved_cross: int = Levels.crossings(lv["solved"], lv["edges"])
		var start_cross: int = Levels.crossings(lv["start"], lv["edges"])
		if solved_cross != 0:
			print("LEVEL %d UNSOLVABLE: solved layout still has %d crossings" % [n, solved_cross])
			fails += 1
		if start_cross == 0:
			print("LEVEL %d STARTS SOLVED: nothing to do" % n)
			starts += 1
		print("level %2d pegs=%2d edges=%2d start_crossings=%3d solved_crossings=%d" % [
			n, lv["pegs"], lv["edges"].size(), start_cross, solved_cross])
	print("RESULT: %s (%d unsolvable, %d start solved, of %d)" % [
		"PASS" if fails == 0 and starts == 0 else "FAIL", fails, starts, Levels.COUNT])
	quit(0 if fails == 0 and starts == 0 else 1)
