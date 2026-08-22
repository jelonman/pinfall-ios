extends SceneTree

## Proves the clash actually resolves: both sides lose bodies, the larger side survives, and the
## state lands on WON/LOST rather than hanging in CLASH.
func _init():
	var fails := 0
	for pair in [[40, 30, "WON"], [30, 40, "LOST"], [4000, 3000, "WON"], [9, 9, "LOST"]]:
		var g = load("res://scenes/Main3D.tscn").instantiate()
		root.add_child(g)
		await process_frame
		await process_frame
		g.level = 12
		g.start_level()
		g.crowd = pair[0]
		g.enemy = pair[1]
		g.units.clear()
		g._resize_crowd(g.END_Z + 3.0)
		g.state = g.State.CLASH
		g.clash_t = 0.0
		g.clash_start_crowd = pair[0]
		g.clash_start_enemy = pair[1]
		var ticks := 0
		while g.state == g.State.CLASH and ticks < 400:
			g._process(1.0 / 60.0)
			ticks += 1
		var got := "WON" if g.state == g.State.WON else ("LOST" if g.state == g.State.LOST else "STUCK")
		var ok: bool = got == pair[2] and g.crowd < pair[0] and g.enemy < pair[1]
		if not ok:
			fails += 1
		print("%d vs %d -> %s in %d ticks (crowd %d->%d, enemy %d->%d) %s"
				% [pair[0], pair[1], got, ticks, pair[0], g.crowd, pair[1], g.enemy,
				"OK" if ok else "FAIL"])
		g.free()
	print("FIGHT TEST " + ("PASS" if fails == 0 else "FAIL x%d" % fails))
	quit(fails)
