extends Node2D
## Untangle — drag the pegs until no rope crosses another.
##
## Owner, 2026-08-22, about the shipped HTML version of this game: "very bones... no animations,
## no graphics, no scoring". So this build is judged on what is on the screen while a finger is
## moving: a rope that bends and settles rather than snapping between two straight positions, a
## peg that lifts when it is picked up, crossings called out in red the moment they happen, a
## counter that goes DOWN as the board clears, and a solve that is worth watching.

const Levels := preload("res://data/levels.gd")

const PEG_R := 34.0          ## drawn radius
const TOUCH_R := 78.0        ## finger radius — a 34 px target is missed constantly on glass
const ROPE_W := 9.0
const CLEAR := Color(0.36, 0.85, 0.78)
const HOT := Color(1.0, 0.36, 0.42)
const PEG_FILL := Color(0.93, 0.96, 1.0)
const PEG_RIM := Color(0.42, 0.62, 1.0)
const BG_TOP := Color(0.07, 0.09, 0.16)
const BG_BOT := Color(0.03, 0.04, 0.08)

var level := 0
var edges: Array = []
var pos: Array[Vector2] = []        ## live positions, screen space
var vel: Array[Vector2] = []        ## rope settle, so a released peg does not stop dead
var solved_norm: Array[Vector2] = []
var hot: Dictionary = {}
var dragging := -1
var moves := 0
var best := {}
var won := false
var win_t := 0.0
var sparks: Array = []
var field := Rect2()
var stars := 0

@onready var hud_font: Font = ThemeDB.fallback_font


func _ready() -> void:
	_load_save()
	_build(level)
	set_process(true)
	set_process_input(true)


func _norm_to_screen(p: Vector2) -> Vector2:
	return field.position + (p * 0.5 + Vector2(0.5, 0.5)) * field.size


func _layout() -> void:
	var vp := get_viewport_rect().size
	# The board is inset well clear of the notch and the thumb: a peg under either is a peg the
	# player cannot reach, and this genre is all reach.
	var m := vp.x * 0.13
	var top := vp.y * 0.17
	var bottom := vp.y * 0.12
	field = Rect2(Vector2(m, top), Vector2(vp.x - m * 2.0, vp.y - top - bottom))


func _build(n: int) -> void:
	level = n
	_layout()
	var lv: Dictionary = Levels.build(n)
	edges = lv["edges"]
	solved_norm = lv["solved"]
	pos = []
	vel = []
	for p in lv["start"]:
		pos.append(_norm_to_screen(p))
		vel.append(Vector2.ZERO)
	# ⛔ Progress was saved only on the WIN, with the level just finished. Tapping continue moved
	# the player on but wrote nothing, so closing the app there dropped them back onto a level
	# they had already solved. The board that is on screen is the board that is saved.
	_save()
	moves = 0
	won = false
	win_t = 0.0
	sparks = []
	dragging = -1
	_recount()
	if OS.has_environment("UNTANGLE_SOLUTION"):
		# Playtest hook: prints where each peg has to end up, so an automated run can drive the
		# real game with real drags instead of poking at internals. Read-only, gated on an env
		# var, and it changes no rule.
		for i in solved_norm.size():
			print("SOLUTION %d %.1f %.1f" % [i, _norm_to_screen(solved_norm[i]).x,
				_norm_to_screen(solved_norm[i]).y])
		for i in pos.size():
			print("START %d %.1f %.1f" % [i, pos[i].x, pos[i].y])
	queue_redraw()


func _recount() -> void:
	hot = Levels.crossing_edges(pos, edges)


func _input(event: InputEvent) -> void:
	if won:
		if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed):
			if win_t > 0.7:
				_build(mini(level + 1, Levels.COUNT - 1))
		return
	var p := Vector2.ZERO
	var down := false
	var up := false
	if event is InputEventScreenTouch:
		p = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseButton:
		p = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if dragging >= 0:
			pos[dragging] = _clamp_to_field(event.position)
			_recount()
			queue_redraw()
		return

	if down:
		var bestd := TOUCH_R
		var pick := -1
		for i in pos.size():
			var d := pos[i].distance_to(p)
			if d < bestd:
				bestd = d
				pick = i
		dragging = pick
	elif up and dragging >= 0:
		moves += 1
		vel[dragging] = Vector2.ZERO
		dragging = -1
		_recount()
		if hot.is_empty():
			_win()
		queue_redraw()


func _clamp_to_field(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, field.position.x, field.end.x),
				   clampf(p.y, field.position.y, field.end.y))


func _win() -> void:
	won = true
	win_t = 0.0
	# Three stars for a solve at or under the peg count in moves, two for double that, else one.
	var pegs := pos.size()
	stars = 3 if moves <= pegs else (2 if moves <= pegs * 2 else 1)
	var prev: int = int(best.get(level, 999))
	if moves < prev:
		best[level] = moves
	_save()
	for i in 90:
		var a := randf() * TAU
		var s := randf_range(150.0, 620.0)
		sparks.append({"p": _centre(), "v": Vector2(cos(a), sin(a)) * s,
			"t": 0.0, "life": randf_range(0.5, 1.15),
			"c": CLEAR.lerp(Color(1.0, 0.86, 0.45), randf())})


func _centre() -> Vector2:
	var c := Vector2.ZERO
	for p in pos:
		c += p
	return c / maxf(float(pos.size()), 1.0)


func _process(delta: float) -> void:
	var moving := false
	# Ropes settle instead of teleporting: every peg that is not held eases toward rest, so a
	# release reads as weight rather than as a value being assigned.
	for i in pos.size():
		if i == dragging:
			continue
		if vel[i].length() > 1.0:
			pos[i] += vel[i] * delta
			vel[i] = vel[i].lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
			moving = true
	if won:
		win_t += delta
		for s in sparks:
			s["t"] += delta
			s["p"] += s["v"] * delta
			s["v"] += Vector2(0, 900.0) * delta
			s["v"] = s["v"].lerp(Vector2.ZERO, clampf(delta * 1.2, 0.0, 1.0))
		sparks = sparks.filter(func(s): return s["t"] < s["life"])
		moving = true
	if moving or dragging >= 0:
		queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), BG_BOT)
	# A soft vertical wash. Cheap, and it stops the board reading as a flat black rectangle.
	for i in 26:
		var t := float(i) / 25.0
		draw_rect(Rect2(Vector2(0, vp.y * t * 0.5), Vector2(vp.x, vp.y * 0.5 / 25.0 + 1.0)),
			BG_TOP.lerp(BG_BOT, t))

	# Ropes. Drawn three times — a wide dim pass for the glow, the body, then a thin bright core.
	for i in edges.size():
		var e: Array = edges[i]
		var a: Vector2 = pos[e[0]]
		var b: Vector2 = pos[e[1]]
		var col: Color = HOT if hot.has(i) else CLEAR
		draw_line(a, b, Color(col.r, col.g, col.b, 0.16), ROPE_W * 3.0, true)
		draw_line(a, b, Color(col.r, col.g, col.b, 0.85), ROPE_W, true)
		draw_line(a, b, Color(1, 1, 1, 0.30), ROPE_W * 0.32, true)

	for i in pos.size():
		var r := PEG_R * (1.28 if i == dragging else 1.0)
		draw_circle(pos[i], r * 1.9, Color(PEG_RIM.r, PEG_RIM.g, PEG_RIM.b, 0.13))
		draw_circle(pos[i], r, PEG_RIM)
		draw_circle(pos[i], r * 0.74, PEG_FILL)
		draw_circle(pos[i] - Vector2(r * 0.22, r * 0.24), r * 0.24, Color(1, 1, 1, 0.9))

	for s in sparks:
		var k: float = 1.0 - s["t"] / s["life"]
		draw_circle(s["p"], 7.0 * k, Color(s["c"].r, s["c"].g, s["c"].b, k))

	_draw_hud(vp)


func _draw_hud(vp: Vector2) -> void:
	var pad := vp.x * 0.07
	draw_string(hud_font, Vector2(pad, vp.y * 0.075), "Level %d" % (level + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 58, Color(1, 1, 1, 0.95))
	var left: int = _crossing_pairs()
	var msg := "untangled" if left == 0 else ("%d crossing%s left" % [left, "" if left == 1 else "s"])
	draw_string(hud_font, Vector2(pad, vp.y * 0.115), msg,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 38, HOT if left > 0 else CLEAR)
	var b: String = ("best %d" % int(best[level])) if best.has(level) else ""
	# ⛔ Right alignment needs a WIDTH. With width -1 the alignment argument is ignored and the
	# string is drawn from the given x, which ran the move counter off the right edge.
	draw_string(hud_font, Vector2(0, vp.y * 0.075), "%d moves   %s" % [moves, b],
		HORIZONTAL_ALIGNMENT_RIGHT, vp.x - pad, 38, Color(1, 1, 1, 0.6))
	if won:
		# ⛔ The banner sat across the middle of the board and covered a peg, so the thing the
		# player just solved was hidden by the message saying they had solved it. It is a card
		# at the bottom now, and the stars are drawn rather than typed as asterisks.
		var h := vp.y * 0.19
		var card := Rect2(Vector2(vp.x * 0.06, vp.y - h - vp.y * 0.04),
			Vector2(vp.x * 0.88, h))
		draw_rect(card.grow(6.0), Color(CLEAR.r, CLEAR.g, CLEAR.b, 0.10))
		draw_rect(card, Color(0.05, 0.08, 0.13, 0.94))
		draw_string(hud_font, Vector2(card.position.x, card.position.y + h * 0.36),
			"Untangled!", HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 66, CLEAR)
		var sx: float = card.position.x + card.size.x * 0.5 - 54.0
		for i in 3:
			_star(Vector2(sx + float(i) * 54.0, card.position.y + h * 0.60), 21.0,
				Color(1.0, 0.82, 0.35) if i < stars else Color(1, 1, 1, 0.16))
		draw_string(hud_font, Vector2(card.position.x, card.position.y + h * 0.88),
			"tap to continue", HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 32,
			Color(1, 1, 1, 0.55))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad: float = r if i % 2 == 0 else r * 0.44
		var a: float = -PI * 0.5 + PI * float(i) / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, col)


func _crossing_pairs() -> int:
	return Levels.crossings(pos, edges)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "level", level)
	cfg.set_value("p", "best", best)
	cfg.save("user://untangle.cfg")


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://untangle.cfg") == OK:
		level = clampi(int(cfg.get_value("p", "level", 0)), 0, Levels.COUNT - 1)
		best = cfg.get_value("p", "best", {})
