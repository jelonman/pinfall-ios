extends SceneTree
## Proves the pull animation runs once a pin's Area3D receives a tap event:
## call _on_input directly with a synthetic touch, then watch the pin's position
## travel over frames. The viewport-delivery half is proven separately by the
## Xvfb click test (buggy build: 0 events, fixed build: events arrive).

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var level: Node3D = load("res://scripts/level.gd").new()
	root.add_child(level)
	await process_frame
	await process_frame
	await process_frame

	# Find pin 3 (lowest gate, the one the click test used)
	var pin: Node3D = null
	for child in level.get_children():
		var sc = child.get_script()
		if sc != null and sc.resource_path.ends_with("pin.gd"):
			if child.position.distance_to(Vector3(-0.10, 0.70, 0.55)) < 0.05:
				pin = child
				break
	if pin == null:
		print("RESULT: PIN NOT FOUND — FAIL")
		quit(1)
		return

	var rest: Vector3 = pin.position
	var ev := InputEventScreenTouch.new()
	ev.position = Vector2(520, 980)
	ev.pressed = true
	ev.index = 0
	pin._on_input(null, ev, Vector3.ZERO, Vector3.ZERO, 0)
	await process_frame

	var travelled := 0.0
	var frames := 0
	while frames < 30:
		await process_frame
		travelled = pin.position.distance_to(rest)
		frames += 1

	print("pin pulled after event: ", travelled > 0.05,
		" | travelled over ", frames, " frames: ", "%.3f" % travelled, " m")
	print("RESULT: ", "PASS — pin pulls when tapped" if travelled > 0.05
		else "FAIL — pin did not move")
	quit(0 if travelled > 0.05 else 1)
