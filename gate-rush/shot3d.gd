extends SceneTree

## Two frames, because the ad sells two different moments: the run through the gates, and the
## smash at the end. Judging only the first is how the clash stayed empty for three rounds.
const SP := "/tmp/claude-1000/-home-jelonman/066ed85d-ef51-4b89-911b-ec921d5ebd57/scratchpad/"

func _init():
	var g = load("res://scenes/Main3D.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await process_frame
	## a fixed seed, so the gauntlet compares rounds instead of comparing noise
	g.rng.seed = 20260820
	g.level = 12
	g.upgrade_level = 2
	g.start_level()
	g.state = g.State.RUN
	for i in range(900):
		_steer(g)
		g._process(1.0 / 60.0)
		if g.state != g.State.RUN:
			break
		if g.rows_passed >= 2 and g.to_spawn == 0 and g.crowd >= 80:
			var rows: Array = g.level_data["rows"]
			if g.rows_passed < rows.size():
				var gap: float = g._lead_z() - g.row_z(g.rows_passed)
				if gap > 0.0 and gap < 5.0 and g.broken.is_empty():
					break
	g.set_process(false)
	await _grab(SP + "gr3d.png")
	g.set_process(true)
	print("run frame: level=%d crowd=%d enemy=%d instances=%d rows_passed=%d"
			% [g.level, g.crowd, g.enemy, g.ally_mm.multimesh.visible_instance_count, g.rows_passed])
	var guard := 0
	while g.state == g.State.RUN and guard < 900:
		_steer(g)
		g._process(1.0 / 60.0)
		guard += 1
	## ⛔ Capturing after 14 ticks landed on a frame where the enemy was already 0 — a picture of
	## the aftermath, not of the clash. Stop at 45% of the way through the trade instead.
	var t := 0
	while g.state == g.State.CLASH and g.clash_t < 0.18 and t < 200:
		g._process(1.0 / 60.0)
		t += 1
	g.set_process(false)
	await _grab(SP + "gr3d_clash.png")
	g.set_process(true)
	print("clash frame: state=%s crowd=%d enemy=%d sparks=%d"
			% [g.state, g.crowd, g.enemy, g.sparks.size()])
	quit()

func _grab(path: String) -> void:
	for i in range(6):
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)

func _steer(g) -> void:
	var rows: Array = g.level_data["rows"]
	if g.rows_passed >= rows.size():
		return
	var row: Array = rows[g.rows_passed]
	var bi := 0
	var bv := -999999
	for i in range(row.size()):
		var gt: Dictionary = row[i]
		var a: int = g.crowd
		match gt["kind"]:
			"mul": a = g.crowd * int(gt["value"])
			"add": a = g.crowd + int(gt["value"])
			"cut": a = max(1, int(g.crowd * (1.0 - float(gt["value"]) / 100.0)))
		if a > bv:
			bv = a; bi = i
	var wide: float = (g.LANE_HALF * 2.0) / float(row.size())
	g.cannon_x = -g.LANE_HALF + wide * (float(bi) + 0.5)
