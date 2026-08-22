extends SceneTree

## The critics can only judge pixels. This proves the thing a player actually does works:
## drag across the screen, the aim moves, the crowd follows it, and the aim never leaves the lane.
func _init():
	var g = load("res://scenes/Main3D.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await process_frame
	g.level = 8
	g.start_level()
	var fails := 0

	# a drag to the far right must clamp inside the lane, not run off it
	_drag(g, 1070.0)
	if absf(g.cannon_x) > g.LANE_HALF + 0.001:
		print("FAIL aim left the lane: %.2f (limit %.2f)" % [g.cannon_x, g.LANE_HALF]); fails += 1
	var right: float = g.cannon_x
	_drag(g, 10.0)
	var left: float = g.cannon_x
	if not (left < right):
		print("FAIL dragging left did not move the aim left: %.2f -> %.2f" % [right, left]); fails += 1
	if absf(left) > g.LANE_HALF + 0.001:
		print("FAIL aim left the lane on the left: %.2f" % left); fails += 1

	# the crowd has to actually follow the aim, not just the number
	g.state = g.State.RUN
	_drag(g, 1070.0)
	for i in range(90):
		g._process(1.0 / 60.0)
	var mean := 0.0
	for u in g.units:
		mean += u["x"]
	mean /= maxf(float(g.units.size()), 1.0)
	if g.units.is_empty():
		print("FAIL no units spawned at all"); fails += 1
	elif mean < 0.0:
		print("FAIL crowd did not follow the aim right: mean x %.2f, aim %.2f" % [mean, g.cannon_x]); fails += 1
	else:
		print("aim %.2f, crowd mean x %.2f, units %d" % [g.cannon_x, mean, g.units.size()])

	print("INPUT TEST " + ("PASS" if fails == 0 else "FAIL x%d" % fails))
	quit(fails)

func _drag(g, screen_x: float) -> void:
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = Vector2(screen_x, 1400.0)
	g._unhandled_input(down)
	var mv := InputEventScreenDrag.new()
	mv.position = Vector2(screen_x, 1400.0)
	g._unhandled_input(mv)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = Vector2(screen_x, 1400.0)
	g._unhandled_input(up)
