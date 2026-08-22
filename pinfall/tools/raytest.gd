extends SceneTree
## Headless raycast test: does the invisible front pane shadow the pin grab areas?
## Camera at (0, 1.55, 11.2) -> pins at z=0.55, pane at z=1.35 (in front).

const CAM_POS := Vector3(0, 1.55, 11.2)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var level: Node3D = load("res://scripts/level.gd").new()
	root.add_child(level)
	await process_frame
	await process_frame

	var space := level.get_world_3d().direct_space_state
	# Locate the invisible front pane
	var pane: Node3D = null
	for child in level.get_children():
		if child is StaticBody3D and child.position.is_equal_approx(Vector3(0, 1.9, 1.35)):
			pane = child
	print("FRONT PANE found: ", pane != null,
		" | input_ray_pickable=", pane.input_ray_pickable if pane else "n/a")

	# Level 1 pins (same data as level.gd LEVELS[0])
	var pins := [Vector3(-0.85, 3.60, 0.55), Vector3(0.95, 2.10, 0.55), Vector3(-0.10, 0.70, 0.55)]
	for p in pins:
		var dir: Vector3 = (p - CAM_POS).normalized()
		var q := PhysicsRayQueryParameters3D.new()
		q.from = CAM_POS
		q.to = CAM_POS + dir * 12.0
		q.collide_with_areas = true
		# Note: Godot 4.6 dropped the old pick_ray query flag; the viewport's real tap
		# picking honors input_ray_pickable on colliders, which is exactly what the pane
		# fix toggles. A ray that reaches the pin's Area3D here means a tap can too.
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			print("PIN ", p, " -> ray hit NOTHING")
			continue
		var coll: Object = hit.get("collider")
		var hit_pos: Vector3 = hit.get("position")
		print("PIN ", p, " -> ray first hits: ", coll.get_class(),
			" pos=", hit_pos, " name=", coll.name)
		var is_pin: bool = coll is Area3D
		var is_pane: bool = coll is StaticBody3D
		print("   => pin area reached: ", is_pin, " | pane intercepted: ", is_pane)
	quit(0)
