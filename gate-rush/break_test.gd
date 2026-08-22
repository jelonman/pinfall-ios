extends SceneTree
## Proves a passed gate row actually leaves the lane, and that no panel is queued twice.
func _init():
	var g = load("res://scenes/Main3D.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await process_frame
	g.level = 12
	g.start_level()
	for i in range(3):
		await process_frame
	var before: int = g.gate_root.get_child_count()
	g.state = g.State.RUN
	var guard := 0
	while g.rows_passed < 1 and guard < 900:
		g._process(1.0/60.0); guard += 1
	var queued: int = g.broken.size()
	var uniq: int = g.breaking.size()
	for i in range(140):
		g._process(1.0/60.0)
	for i in range(4):
		await process_frame
	var tagged := 0
	for c in g.gate_root.get_children():
		if c is Node3D and int((c as Node3D).get_meta("row", -1)) == 0:
			tagged += 1
	var after: int = g.gate_root.get_child_count()
	print("gate children %d -> %d after one row passed; queued=%d unique=%d tagged-left=%d"
			% [before, after, queued, uniq, tagged])
	var ok: bool = queued > 0 and queued == uniq and tagged == 0 and after < before
	print("BREAK TEST " + ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
