extends SceneTree

## Does it actually PLAY? Drives the real scene, not a mock: instantiate Main, send a release to
## start the run, then step _process at 60fps and watch the numbers move.
## The old build shipped with nobody ever asking whether a gate changes anything.

func _init():
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var g = scene.instantiate()
	root.add_child(g)
	g._ready()

	var start_crowd: int = g.crowd
	var enemy: int = g.enemy
	print("level %d: start crowd=%d enemy=%d rows=%d"
			% [g.level, start_crowd, enemy, g.level_data["rows"].size()])

	# Play it like a player: before each row, steer the cannon at the best lane.
	# A test that never steers is not testing the game, it is testing gravity.
	g.state = g.State.RUN
	var peak_units := 0
	var gate_hits := 0
	var prev_rows := 0
	for i in range(1200):                       # 20 simulated seconds
		_steer(g)
		g._process(1.0 / 60.0)
		peak_units = max(peak_units, g.units.size())
		if g.rows_passed > prev_rows:
			gate_hits += 1
			prev_rows = g.rows_passed
			print("  gate %d -> crowd=%d, drawn units=%d" % [gate_hits, g.crowd, g.units.size()])
		if g.state in [g.State.WON, g.State.LOST]:
			break

	print("final state=%s crowd=%d enemy=%d gates_passed=%d peak_drawn=%d"
			% [["AIM","RUN","CLASH","WON","LOST"][g.state], g.crowd, enemy, gate_hits, peak_units])

	var ok := true
	if gate_hits == 0:
		print("FAIL: the run never crossed a gate"); ok = false
	if g.crowd <= start_crowd:
		print("FAIL: crowd never grew (%d -> %d)" % [start_crowd, g.crowd]); ok = false
	if peak_units < 8:
		print("FAIL: only %d units ever drawn — this is the one-dot bug again" % peak_units); ok = false
	if not (g.state in [g.State.WON, g.State.LOST]):
		print("FAIL: the run never resolved, state=%d" % g.state); ok = false
	print("PLAYTEST " + ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _steer(g) -> void:
	var rows: Array = g.level_data["rows"]
	if g.rows_passed >= rows.size():
		return
	var row: Array = rows[g.rows_passed]
	var best_i := 0
	var best_v := -999999
	for i in range(row.size()):
		var gt: Dictionary = row[i]
		var after: int = g.crowd
		match gt["kind"]:
			"mul": after = g.crowd * int(gt["value"])
			"add": after = g.crowd + int(gt["value"])
			"sub": after = max(1, g.crowd - int(gt["value"]))
		if after > best_v:
			best_v = after
			best_i = i
	var ry: float = g.row_y(g.rows_passed)
	var half: float = g.lane_half(ry)
	var wide: float = 2.0 * half / float(row.size())
	var target: float = 540.0 - half + wide * (float(best_i) + 0.5)
	g.cannon_x = lerp(g.cannon_x, target, 0.25)
