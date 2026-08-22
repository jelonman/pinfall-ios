extends SceneTree

const Levels := preload("res://data/levels.gd")

func _init():
	var scene: PackedScene = load("res://scenes/Main3D.tscn")
	var wins := 0
	var checked := 0
	for lvl in [1, 2, 5, 10, 20, 35, 50, 75, 100]:
		var g = scene.instantiate()
		root.add_child(g)
		g._ready()
		g.level = lvl
		g.upgrade_level = int(lvl / 5)
		g.start_level()
		g.state = g.State.RUN
		for i in range(3000):
			_steer(g)
			g._process(1.0 / 60.0)
			if g.state in [g.State.WON, g.State.LOST]:
				break
		checked += 1
		if g.state == g.State.WON:
			wins += 1
		print("L%-4d rows=%d start=%-3d final=%-9d enemy=%-9d %s  drawn=%d" % [
			lvl, g.level_data["rows"].size(), Levels.start_units(lvl, int(lvl/5)),
			g.crowd, g.enemy,
			["AIM","RUN","CLASH","WON","LOST"][g.state], g.units.size()])
		g.queue_free()
	print("--- perfect play wins %d of %d sampled levels" % [wins, checked])
	quit(0 if wins == checked else 1)

func _steer(g) -> void:
	var rows: Array = g.level_data["rows"]
	if g.rows_passed >= rows.size():
		return
	var row: Array = rows[g.rows_passed]
	var bi := 0
	var bv := -999999
	for i in range(row.size()):
		var gt: Dictionary = row[i]
		var a: int = g.crowd
		match gt["kind"]:
			"mul": a = g.crowd * int(gt["value"])
			"add": a = g.crowd + int(gt["value"])
			"cut": a = max(1, int(g.crowd * (1.0 - float(gt["value"]) / 100.0)))
		if a > bv:
			bv = a; bi = i
	## 3D lane geometry: a flat lane of LANE_HALF either side of centre, not the 2D trapezoid
	## with its 540 px screen centre and per-row half-width.
	var wide: float = (g.LANE_HALF * 2.0) / float(row.size())
	g.cannon_x = -g.LANE_HALF + wide * (float(bi) + 0.5)
