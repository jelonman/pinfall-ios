extends SceneTree
## How fast does the pour actually drain, and where does it end up?
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	Engine.set_meta("pinfall_level", int(a[0]) if a.size() > 0 else 0)
	var level: Node3D = load("res://scripts/level.gd").new()
	root.add_child(level)
	for i in 4: await physics_frame
	var pins: Array = []
	var goal: Node = null
	var drain: Node = null
	for c in level.get_children():
		var sc = c.get_script()
		if sc == null: continue
		if sc.resource_path.ends_with("pin.gd"): pins.append(c)
		elif sc.resource_path.ends_with("goal.gd"):
			if c.get("is_goal"): goal = c
			else: drain = c
	pins.sort_custom(func(a, b): return a.position.y > b.position.y)
	for p in pins:
		p.pulled = true
		for i in 70: await physics_frame
	for step in 12:
		for i in 300: await physics_frame
		var below := 0; var lo := 999.0
		for c in level.get_children():
			if c is RigidBody3D:
				lo = minf(lo, c.position.y)
				if c.position.y < -1.2: below += 1
		print("t=%.1fs below=%d lowest=%.2f goal_count=%d drain_count=%d" % [
			(step + 1) * 300.0 / 120.0, below, lo, int(goal.get("_count")), int(drain.get("_count"))])
	# where did the mass end up, in x bands
	var bands := {"far_left":0, "goal_x":0, "centre":0, "drain_x":0, "far_right":0}
	for c in level.get_children():
		if c is RigidBody3D:
			var x = c.position.x
			if x < -2.5: bands.far_left += 1
			elif x < -0.8: bands.goal_x += 1
			elif x < 0.8: bands.centre += 1
			elif x < 2.5: bands.drain_x += 1
			else: bands.far_right += 1
	print("BANDS ", bands)
	quit()
