extends SceneTree

func _init():
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var g = scene.instantiate()
	root.add_child(g)
	# ⛔ the engine fires _ready() on the NEXT frame, so anything set before that gets overwritten
	# by the save load. Wait for it, then set up the shot.
	await process_frame
	await process_frame
	g.level = 12
	g.upgrade_level = 2
	g.start_level()
	g.state = g.State.RUN
	for i in range(64):
		_steer(g)
		g._process(1.0 / 60.0)
		if g.state != g.State.RUN:
			break
	g.queue_redraw()
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/claude-1000/-home-jelonman/066ed85d-ef51-4b89-911b-ec921d5ebd57/scratchpad/gr_frame.png")
	print("frame: level=%d crowd=%d enemy=%d drawn=%d rows_passed=%d state=%d"
			% [g.level, g.crowd, g.enemy, g.units.size(), g.rows_passed, g.state])
	quit()

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
	var ry: float = g.row_y(g.rows_passed)
	var half: float = g.lane_half(ry)
	var wide: float = 2.0 * half / float(row.size())
	g.cannon_x = lerp(g.cannon_x, 540.0 - half + wide * (float(bi) + 0.5), 0.3)
