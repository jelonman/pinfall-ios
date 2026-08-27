extends SceneTree
## Measures the foundry order every level can actually deliver, and proves the diverter matters.
##
## Plays each level as a perfect operator: pull the pins top-down, and every physics step aim the
## diverter at the crucible when the metal currently passing over it is one the order asks for,
## and at the slag pit when it is not. Records what ends up in the crucible, per metal.
##
## It also plays each level a second time with the diverter NAILED to the crucible — the way the
## old fixed ridge behaved. If that run delivers the same result, the diverter is decoration and
## the level is not a puzzle.
##
##     godot --headless --path . --script tools/levelsim.gd -- 0 60

const SETTLE_AFTER_PULL := 70
const SETTLE_AT_END := 1000   ## the pour is done well before this; measured, not assumed

var results: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 0
	var last := int(args[1]) if args.size() > 1 else 60
	for n in range(first, last):
		# ⛔ MEASURE ONE THING PER RUN. The three-run version took a quarter of an hour for 60
		# levels and looked like a hang from outside. The diverter-nailed comparison is a separate
		# switch now: it is a one-off proof that the control matters, not something every bake
		# needs to re-run.
		if OS.has_environment("PINFALL_PLAY"):
			# The acceptance test: an operator who works the gates and the diverter correctly must
			# actually WIN against the baked target. A measured ceiling proves the metal can get
			# there; only this proves the level can be finished.
			var run: Dictionary = await _play(n, "play")
			print("LEVEL %d play=%s %s target=%d" % [
				n, JSON.stringify(run["counts"]), run["state"], _target(n)])
			continue
		var solo: Dictionary = await _play(n, "solo")
		results.append([n, solo["counts"]])
		print("LEVEL %d ceiling=%s" % [n, JSON.stringify(solo["counts"])])
		if OS.has_environment("PINFALL_PROVE_DIVERTER"):
			var naive: Dictionary = await _play(n, "nailed")
			print("   diverter-nailed=%s %s" % [JSON.stringify(naive["counts"]), naive["state"]])
	print("TABLE ", JSON.stringify(results))
	quit()


var _lvl_cache: Node = null


func _target(n: int) -> int:
	var g: Node3D = load("res://scripts/level.gd").new()
	root.add_child(g)
	var t: int = g.per_metal_target(n)
	g.queue_free()
	return t


func _play(n: int, mode: String) -> Dictionary:
	Engine.set_meta("pinfall_level", n)
	var level: Node3D = load("res://scripts/level.gd").new()
	root.add_child(level)
	for i in 4:
		await physics_frame

	var wants: Array = level.wants_of(n)
	var goal_left: bool = level.goal_x_of(n) < 0.0
	var pins: Array = []
	var drops: Array = []
	for child in level.get_children():
		var sc = child.get_script()
		if sc != null and sc.resource_path.ends_with("pin.gd"):
			pins.append(child)
		if child is RigidBody3D:
			drops.append(child)
	pins.sort_custom(func(a, b): return a.position.y > b.position.y)

	var silos: Array = level.silo_pins
	var shelf: Array = []
	for p in pins:
		if not silos.has(p):
			shelf.append(p)

	if mode == "nailed":
		# The old fixed-ridge behaviour: everything open at once, aimed at the crucible.
		level._set_diverter(goal_left)
		for p in pins:
			p.pulled = true
			for i in SETTLE_AFTER_PULL:
				await physics_frame
		for i in SETTLE_AT_END:
			await physics_frame
			if level._won or level._lost:
				break
	elif mode == "solo":
		# The CEILING: open the path, aim at the crucible, and run only the silos the order asks
		# for. Nothing else is released, so whatever lands is the most this level can ever give.
		level._set_diverter(goal_left)
		for p in shelf:
			p.pulled = true
			for i in SETTLE_AFTER_PULL:
				await physics_frame
		for m in wants:
			if m < silos.size():
				silos[m].pulled = true
		for i in SETTLE_AT_END:
			await physics_frame
	else:
		# A competent operator: open the path first, then run ONE silo at a time — the wanted
		# metals into the crucible, everything else into the slag pit. Opening every silo at once
		# is what the first version of this simulator did, and it contaminated every heat.
		for p in shelf:
			p.pulled = true
			for i in SETTLE_AFTER_PULL:
				await physics_frame
		var target: int = level.per_metal_target(n)
		for m in wants:
			level._set_diverter(goal_left)
			if m < silos.size():
				silos[m].pulled = true
			for i in 1400:
				await physics_frame
				if level._won or level._lost:
					break
				if int(level._goal.counts.get(m, 0)) >= target:
					break
			if level._won or level._lost:
				break
		if not (level._won or level._lost):
			level._set_diverter(not goal_left)
			for m in silos.size():
				if not wants.has(m):
					silos[m].pulled = true
			for i in SETTLE_AT_END:
				await physics_frame
				if level._won or level._lost:
					break

	var counts: Dictionary = {}
	if level._goal != null:
		counts = level._goal.counts.duplicate()
	var state := "won" if level._won else ("lost" if level._lost else "open")
	level.queue_free()
	await process_frame
	return {"counts": counts, "state": state}


func _steer(level: Node3D, drops: Array, wants: Array, goal_left: bool) -> void:
	## Aim at the crucible only while the metal actually approaching the diverter is wanted.
	## Sampling a BAND above the plate, not the whole shaft: what matters is the next second of
	## pour, and the metal sitting four shelves up says nothing about it.
	var tally := {}
	for d in drops:
		if not is_instance_valid(d):
			continue
		var y: float = d.position.y
		if y > -0.55 and y < 1.10 and absf(d.position.x) < 2.4:
			var m: int = int(d.get_meta("metal", 0))
			tally[m] = int(tally.get(m, 0)) + 1
	if tally.is_empty():
		return
	var top := -1
	var best := 0
	for m in tally:
		if int(tally[m]) > best:
			best = int(tally[m])
			top = int(m)
	var want_goal: bool = wants.has(top)
	level._set_diverter(goal_left if want_goal else not goal_left)
