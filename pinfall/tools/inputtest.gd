extends SceneTree
## End-to-end input picking test for the pane fix.
##
## This drives the REAL picking path: a Viewport push_input() with an
## InputEventScreenTouch aimed at a pin's projected screen position. The viewport
## casts its own picking ray (which honors input_ray_pickable), so with the pane
## fix the Area3D receives the event and the pin starts pulling; without it the
## pane swallows the tap and the pin never moves. No physics-API shortcut.

var cam: Camera3D

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var w: Window = root
	w.size = Vector2i(1080, 2400)
	# Picking must be on for the viewport to raycast taps onto physics objects.
	root.physics_object_picking = true
	var level: Node3D = load("res://scripts/level.gd").new()
	root.add_child(level)
	await process_frame
	await process_frame
	await process_frame

	for child in level.get_children():
		if child is Camera3D:
			cam = child
			break
	if cam == null:
		print("RESULT: NO CAMERA — FAIL")
		quit(1)
		return

	# Level 1 pins: (hole_x, gate_y, 0.55)
	var pins := [Vector3(-0.85, 3.60, 0.55), Vector3(0.95, 2.10, 0.55), Vector3(-0.10, 0.70, 0.55)]
	var failed := false
	for p in pins:
		var sp: Vector2 = cam.unproject_position(p)
		var ev := InputEventScreenTouch.new()
		ev.position = sp
		ev.pressed = true
		ev.index = 0
		root.push_input(ev)
		await process_frame
		await process_frame
		await process_frame
		await process_frame
		# Find the pin node nearest this position and check its travel
		var pin: Node3D = _pin_at(level, p)
		var travelled: float = -1.0
		if pin != null:
			travelled = pin.position.distance_to(Vector3(p.x, p.y, 0.55))
		var ok: bool = travelled > 0.1
		if not ok:
			failed = true
		print("PIN ", p, " screen=", sp, " travelled=", "%.3f" % travelled,
			" -> ", "PULLED" if ok else "NO RESPONSE")
		# reset by reloading the level for the next pin
		if pins.find(p) < pins.size() - 1:
			level.queue_free()
			await process_frame
			level = load("res://scripts/level.gd").new()
			root.add_child(level)
			await process_frame
			await process_frame
			for child in level.get_children():
				if child is Camera3D:
					cam = child
					break

	print("RESULT: ", "PASS — all pins respond to taps" if not failed
		else "FAIL — at least one pin did not respond")
	quit(0 if not failed else 1)

func _pin_at(level: Node3D, world: Vector3) -> Node3D:
	# pin.gd nodes are direct children of level, positioned at their rest pos
	for child in level.get_children():
		var sc = child.get_script()
		if sc != null and sc.resource_path.ends_with("pin.gd"):
			if child.position.distance_to(world) < 0.05:
				return child
	return null
