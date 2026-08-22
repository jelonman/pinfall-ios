extends SceneTree
## Print the screen-space position of each level-1 pin as the game camera sees it,
## so a test tap on the emulator can be aimed precisely.
## Camera: (0, 1.55, 11.2), rotation (-4, 0, 0), fov 50. Portrait 1080x2400.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# Make a window sized like the phone so unproject_position matches.
	var w: Window = root
	w.size = Vector2i(1080, 1920)
	var level: Node3D = load("res://scripts/level.gd").new()
	root.add_child(level)
	await process_frame
	await process_frame

	# Find the camera (added inside _build_environment)
	var cam: Camera3D = null
	for child in level.get_children():
		if child is Camera3D:
			cam = child
			break
	if cam == null:
		print("NO CAMERA")
		quit(1)
		return

	# Level 1 pins: same data as LEVELS[0] gates, x = hole, y = gate height, z = 0.55
	var pins := [Vector3(-0.85, 3.60, 0.55), Vector3(0.95, 2.10, 0.55), Vector3(-0.10, 0.70, 0.55)]
	for p in pins:
		var sp: Vector2 = cam.unproject_position(p)
		print("PIN ", p, " -> screen (", int(sp.x), ", ", int(sp.y), ")")
	# Also the goal vessel position for orientation
	var goal := Vector3(-1.65, -1.75, 0.55)
	var sg: Vector2 = cam.unproject_position(goal)
	print("GOAL -> screen (", int(sg.x), ", ", int(sg.y), ")")
	quit(0)
