extends SceneTree
## Where does the iron get out before its gate is pulled?
func _init() -> void: call_deferred("_run")
func _run() -> void:
	Engine.set_meta("pinfall_level", 0)
	var level: Node3D = load("res://scripts/level.gd").new()
	root.add_child(level)
	for i in 4: await physics_frame
	var silos: Array = level.silo_pins
	var drops: Array = []
	for c in level.get_children():
		if c is RigidBody3D: drops.append(c)
	var iron := []
	for d in drops:
		if int(d.get_meta("metal", 0)) == 1: iron.append(d)
	print("silo pins: ", silos.size(), " iron drops: ", iron.size())
	for s in silos:
		print("  silo pin at ", s.position, " pulled=", s.pulled)
	var lo := 999.0; var hi := -999.0; var xlo := 999.0; var xhi := -999.0
	for d in iron:
		lo = minf(lo, d.position.y); hi = maxf(hi, d.position.y)
		xlo = minf(xlo, d.position.x); xhi = maxf(xhi, d.position.x)
	print("iron at t0: y %.2f..%.2f  x %.2f..%.2f" % [lo, hi, xlo, xhi])
	# open only the shelf pins
	for p in level.pins:
		if not silos.has(p): p.pulled = true
	for step in 8:
		for i in 240: await physics_frame
		var below := 0; var minx := 999.0; var miny := 999.0
		for d in iron:
			if is_instance_valid(d):
				miny = minf(miny, d.position.y)
				if d.position.y < 3.0: below += 1
		print("t=%.1fs iron below y=3: %d  lowest %.2f  goal counts %s  silo1 pulled=%s" % [
			(step+1)*2.0, below, miny, JSON.stringify(level._goal.counts), str(silos[1].pulled)])
	quit()
