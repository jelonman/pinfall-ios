extends SceneTree

## The gauntlet compares one round's frame against the next. If the frame is not reproducible,
## every score difference is partly noise — measured at 37-41% of pixels before the seed was
## pinned. This asserts the scene is deterministic under a fixed seed, so that cannot come back.
func _init():
	var a := await _run()
	var b := await _run()
	var same: bool = a == b
	print("run A: %s" % a)
	print("run B: %s" % b)
	print("SHOT REPEAT TEST " + ("PASS" if same else "FAIL — the scene is not deterministic"))
	quit(0 if same else 1)

func _run() -> String:
	var g = load("res://scenes/Main3D.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await process_frame
	g.rng.seed = 20260820
	g.level = 12
	g.upgrade_level = 2
	g.start_level()
	g.state = g.State.RUN
	for i in range(260):
		g._process(1.0 / 60.0)
	var sx := 0.0
	var sz := 0.0
	for u in g.units:
		sx += float(u["x"])
		sz += float(u["z"])
	var out := "crowd=%d rows=%d sum_x=%.3f sum_z=%.3f" % [g.crowd, g.rows_passed, sx, sz]
	g.free()
	return out
