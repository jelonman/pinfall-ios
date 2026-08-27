extends SceneTree
## WHERE does a drop cross the silo floor plane? x and z at the crossing, nothing else.
func _init() -> void: call_deferred("_run")
func _run() -> void:
	Engine.set_meta("pinfall_level", 0)
	var level: Node3D = load("res://scripts/level.gd").new()
	root.add_child(level)
	for i in 4: await physics_frame
	var silos: Array = level.silo_pins
	for p in level.pins:
		if not silos.has(p): p.pulled = true
	var iron := []
	for c in level.get_children():
		if c is RigidBody3D and int(c.get_meta("metal", 0)) == 1:
			iron.append({"d": c, "was": c.position.y, "hit": false})
	var floor_y: float = level.SILO_FLOOR_Y
	var xs := []
	var zs := []
	for step in 1200:
		await physics_frame
		for e in iron:
			if e["hit"]: continue
			var d = e["d"]
			if not is_instance_valid(d): continue
			var y: float = d.position.y
			if e["was"] > floor_y and y <= floor_y:
				e["hit"] = true
				xs.append(d.position.x)
				zs.append(d.position.z)
			e["was"] = y
	xs.sort(); zs.sort()
	print("crossed floor: %d of %d" % [xs.size(), iron.size()])
	if xs.size() > 0:
		print("x at crossing: min %.2f  p25 %.2f  med %.2f  p75 %.2f  max %.2f" % [
			xs[0], xs[xs.size()/4], xs[xs.size()/2], xs[xs.size()*3/4], xs[xs.size()-1]])
		print("z at crossing: min %.2f  med %.2f  max %.2f" % [zs[0], zs[zs.size()/2], zs[zs.size()-1]])
	print("silo1 hole spans x 0.40..1.45, pin covers z 0.23..0.87, lips cover the rest")
	quit()
