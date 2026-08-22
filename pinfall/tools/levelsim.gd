extends SceneTree
## Measures what each level can actually deliver, so `needed` is a fact rather than a guess.
##
## Plays every level with a perfect solve — pull the top pin, let the pour settle, pull the next —
## and reads the crucible's own counter at the end. A level whose perfect solve catches 61 drops
## cannot ask for 80, and a level that catches 130 should not ask for 40. Both were possible with
## the hand-typed numbers, and neither was ever checked.
##
##     godot --headless --path . --script tools/levelsim.gd            # all 60
##     godot --headless --path . --script tools/levelsim.gd -- 0 5     # a slice, while iterating

const SETTLE_AFTER_PULL := 70    ## physics frames between pulls (120 Hz => ~0.6 s)
const SETTLE_AT_END := 1800       ## ~15 s: the pour is 90% done by then (flowprobe)

var results: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 0
	var last := int(args[1]) if args.size() > 1 else 60
	for n in range(first, last):
		var caught := await _play(n)
		results.append([n, caught])
		print("LEVEL %d caught=%d" % [n, caught])
	print("TABLE ", JSON.stringify(results))
	quit()


func _play(n: int) -> int:
	Engine.set_meta("pinfall_level", n)
	var level: Node3D = load("res://scripts/level.gd").new()
	root.add_child(level)
	for i in 4:
		await physics_frame

	var pins: Array = []
	var goal: Node = null
	for child in level.get_children():
		var sc = child.get_script()
		if sc == null:
			continue
		if sc.resource_path.ends_with("pin.gd"):
			pins.append(child)
		elif sc.resource_path.ends_with("goal.gd") and child.get("is_goal") == true:
			goal = child
	# Pins are built top shelf first, which is also the only order a human can pull them in:
	# a lower pin still plugged holds the pour above it.
	pins.sort_custom(func(a, b): return a.position.y > b.position.y)
	var drops := 0
	for child in level.get_children():
		if child is RigidBody3D:
			drops += 1
	print("  diag level %d: pins=%d goal=%s drops=%d" % [n, pins.size(), str(goal != null), drops])

	for p in pins:
		p.pulled = true
		for i in SETTLE_AFTER_PULL:
			await physics_frame
	for i in SETTLE_AT_END:
		await physics_frame

	var below := 0
	for child in level.get_children():
		if child is RigidBody3D and child.position.y < -1.2:
			below += 1
	var caught: int = int(goal.get("_count")) if goal != null else -1
	var gx: float = goal.position.x
	var inbox := 0
	for child in level.get_children():
		if child is RigidBody3D:
			var d = child.position
			if absf(d.x - gx) < 0.85 and d.y > -2.30 and d.y < -1.20:
				inbox += 1
	var lo := 999.0
	var hi := -999.0
	for child in level.get_children():
		if child is RigidBody3D:
			lo = minf(lo, child.position.y); hi = maxf(hi, child.position.y)
	print("  diag end: IN GOAL BOX by position=%d | drops y range %.2f..%.2f | below-1.2=%d | pin0 %s (rest x was %.2f) | pulled=%s _t=%.2f" % [inbox, lo, hi, below, str(pins[0].position), pins[0]._rest.x, str(pins[0].pulled), pins[0]._t])
	level.queue_free()
	await process_frame
	return caught
