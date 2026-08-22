extends Node2D

## Gate Rush — the real game, not the ad.
##
## The webview version drew ONE 8px dot and called it a mob. The whole mechanic is watching a
## crowd grow, so this renders every unit as its own body with its own arrival delay and its own
## jitter. A gate that turns 12 units into 36 has to LOOK like 12 becoming 36.
##
## 2.5D on purpose: a Node2D lane with perspective scaling reads like the reference on a phone
## and costs a fraction of a 3D scene. Depth comes from lane taper + per-unit scale by y.

const Levels := preload("res://data/levels.gd")
const Save := preload("res://scripts/save.gd")

const LANE_TOP := 300.0
const LANE_BOTTOM := 1720.0
const LANE_HALF_TOP := 300.0
const LANE_HALF_BOTTOM := 528.0
const CANNON_Y := 1660.0
const FIRE_INTERVAL := 0.045          ## a stream, not a trickle
const UNIT_SPEED := 620.0
const MAX_DRAWN := 700                ## past this we draw a mass, not individuals

enum State { AIM, RUN, CLASH, WON, LOST }

var state: int = State.AIM
var level: int = 1
var upgrade_level: int = 0
var level_data: Dictionary = {}
var cannon_x: float = 540.0
var dragging: bool = false

## Each unit: {x, y, vx, alive}
var units: Array = []
var to_spawn: int = 0
var spawn_timer: float = 0.0
var crowd: int = 0                    ## logical count, what the gates operate on
var enemy: int = 0
var rows_passed: int = 0
var clash_t: float = 0.0
var banner: String = ""
var banner_t: float = 0.0
var shake: float = 0.0

@onready var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	var s := Save.load_state()
	level = int(s.get("level", 1))
	upgrade_level = int(s.get("upgrade", 0))
	start_level()


func start_level() -> void:
	level_data = Levels.build(level, upgrade_level)
	crowd = int(level_data["start_units"])
	enemy = Levels.enemy_count(level, upgrade_level)
	units.clear()
	to_spawn = crowd
	spawn_timer = 0.0
	rows_passed = 0
	clash_t = 0.0
	state = State.AIM
	cannon_x = 540.0
	queue_redraw()


func lane_half(y: float) -> float:
	var t: float = clampf((y - LANE_TOP) / (LANE_BOTTOM - LANE_TOP), 0.0, 1.0)
	return lerpf(LANE_HALF_TOP, LANE_HALF_BOTTOM, t)


func depth_scale(y: float) -> float:
	var t: float = clampf((y - LANE_TOP) / (LANE_BOTTOM - LANE_TOP), 0.0, 1.0)
	return lerpf(0.62, 1.15, t)


func row_y(i: int) -> float:
	var n: int = level_data["rows"].size()
	return lerpf(LANE_BOTTOM - 200.0, LANE_TOP + 190.0, float(i) / float(max(n - 1, 1)))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			dragging = true
			if state in [State.WON, State.LOST]:
				_advance()
		else:
			dragging = false
			if state == State.AIM:
				state = State.RUN
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and dragging:
		var half := lane_half(CANNON_Y) - 40.0
		cannon_x = clampf(event.position.x, 540.0 - half, 540.0 + half)
		queue_redraw()


func _advance() -> void:
	if state == State.WON:
		level += 1
		if level % 5 == 0:
			upgrade_level += 1        ## slow meta-progression, the reason to keep playing
		Save.save_state({"level": level, "upgrade": upgrade_level})
	start_level()


func _process(delta: float) -> void:
	if banner_t > 0.0:
		banner_t -= delta
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 3.0)

	if state == State.RUN:
		_spawn(delta)
		_move(delta)
		_check_rows()
		_check_reach()
	elif state == State.CLASH:
		clash_t += delta
		if clash_t > 0.9:
			state = State.WON if crowd > enemy else State.LOST
			banner = "LEVEL %d CLEARED" % level if state == State.WON else "OVERRUN"
			banner_t = 3.0
	queue_redraw()


func _spawn(delta: float) -> void:
	if to_spawn <= 0:
		return
	spawn_timer -= delta
	while spawn_timer <= 0.0 and to_spawn > 0:
		spawn_timer += FIRE_INTERVAL
		to_spawn -= 1
		units.append({
			"x": cannon_x + rng.randf_range(-26.0, 26.0),
			"y": CANNON_Y - rng.randf_range(0.0, 18.0),
			"vx": rng.randf_range(-24.0, 24.0),
		})


func _move(delta: float) -> void:
	var half_pull := 0.0
	for u in units:
		u["y"] -= UNIT_SPEED * delta
		u["x"] += u["vx"] * delta
		var half := lane_half(u["y"]) - 18.0
		if absf(u["x"] - 540.0) > half:
			u["x"] = 540.0 + signf(u["x"] - 540.0) * half
			u["vx"] *= -0.6
		half_pull += u["x"]
	# gentle cohesion so the crowd reads as one body rather than confetti
	if units.size() > 0:
		var mean: float = half_pull / float(units.size())
		for u in units:
			u["vx"] = lerpf(u["vx"], (mean - u["x"]) * 0.9, delta * 1.4)


func _lead_y() -> float:
	var best := LANE_BOTTOM
	for u in units:
		best = minf(best, u["y"])
	return best


func _check_rows() -> void:
	## ⛔ The first model decided the whole row by the crowd's MEAN x. Perfect play still lost
	## levels 35-100, because by then the crowd is wider than a lane and its centre sits in a
	## gate nobody aimed at. The reference game does not work that way and neither does this now:
	## every unit passes through the gate it is physically in, and the crowd is the sum of what
	## comes out. Splitting the crowd is the actual decision the player is making.
	var rows: Array = level_data["rows"]
	if rows_passed >= rows.size():
		return
	var ry := row_y(rows_passed)
	if _lead_y() > ry:
		return
	var row: Array = rows[rows_passed]
	var lanes: int = row.size()
	var half := lane_half(ry)
	var wide := 2.0 * half / float(lanes)

	# how the crowd is distributed across the lanes right now
	var share := []
	share.resize(lanes)
	for i in range(lanes):
		share[i] = 0
	for u in units:
		var idx: int = clampi(int(floor((u["x"] - (540.0 - half)) / wide)), 0, lanes - 1)
		share[idx] += 1
	var drawn: int = maxi(units.size(), 1)

	var total := 0
	var applied := {}
	for i in range(lanes):
		var portion: int = int(round(float(crowd) * float(share[i]) / float(drawn)))
		if portion <= 0:
			continue
		var g: Dictionary = row[i]
		match g["kind"]:
			"mul": portion = portion * int(g["value"])
			"add": portion = portion + int(g["value"])
			"cut": portion = maxi(1, int(float(portion) * (1.0 - float(g["value"]) / 100.0)))
		applied[i] = g
		total += portion
	var before := crowd
	crowd = maxi(1, total)
	_resize_crowd(before, ry)

	# show the gate the bulk of the crowd actually took
	var lead := 0
	for i in range(lanes):
		if share[i] > share[lead]:
			lead = i
	var lg: Dictionary = row[lead]
	banner = ("x%d" % int(lg["value"])) if lg["kind"] == "mul" else \
			(("+%d" % int(lg["value"])) if lg["kind"] == "add" else ("-%d%%" % int(lg["value"])))
	banner_t = 0.7
	shake = 0.35 if lg["kind"] == "cut" else 0.15
	rows_passed += 1


func _resize_crowd(before: int, at_y: float) -> void:
	## The visual crowd follows the logical count, capped so a phone stays at 60fps.
	var want: int = mini(crowd, MAX_DRAWN)
	while units.size() > want and units.size() > 0:
		units.remove_at(units.size() - 1)
	while units.size() < want:
		var src: Dictionary = units[rng.randi_range(0, units.size() - 1)] if units.size() > 0 \
				else {"x": 540.0, "y": at_y, "vx": 0.0}
		units.append({
			"x": src["x"] + rng.randf_range(-70.0, 70.0),
			"y": src["y"] + rng.randf_range(-40.0, 40.0),
			"vx": rng.randf_range(-40.0, 40.0),
		})


func _check_reach() -> void:
	if to_spawn > 0:
		return
	if _lead_y() <= LANE_TOP + 150.0:
		state = State.CLASH
		clash_t = 0.0
		shake = 1.0


# ── drawing ────────────────────────────────────────────────────────────────────
# The old build was a flat navy rectangle with one dot. Everything below exists so the frame
# reads the way the advertised game does: a receding lane, gates you can price at a glance, and
# a crowd whose size is the whole point.

const C_SKY := Color(0.36, 0.68, 0.92)
const C_GROUND_FAR := Color(0.55, 0.60, 0.66)
const C_GROUND_NEAR := Color(0.34, 0.60, 0.34)
const C_ALLY := Color(0.13, 0.48, 0.98)
const C_ALLY_HI := Color(0.55, 0.80, 1.00)
const C_ENEMY := Color(0.92, 0.13, 0.16)
const C_GOOD := Color(0.66, 0.18, 0.85)
const C_BAD := Color(0.14, 0.20, 0.30)
const C_INK := Color(0.09, 0.10, 0.14)


func _draw() -> void:
	var off := Vector2(0, 0)
	if shake > 0.0:
		off = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake * 9.0
	draw_set_transform(off, 0.0, Vector2.ONE)

	draw_rect(Rect2(0, 0, 1080, LANE_TOP), C_SKY)
	_draw_hills()
	draw_rect(Rect2(0, LANE_TOP, 1080, 1920 - LANE_TOP), C_GROUND_NEAR)
	_draw_lane()
	_draw_enemy()
	_draw_gates()
	_draw_units()
	_draw_cannon()
	_draw_hud()


func _draw_hills() -> void:
	for i in range(5):
		var cx := 90.0 + i * 240.0
		var h := 120.0 + ((i * 37) % 70)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 190, LANE_TOP), Vector2(cx, LANE_TOP - h),
			Vector2(cx + 190, LANE_TOP)]), C_GROUND_FAR.darkened(0.08))


func _draw_lane() -> void:
	# light road, hard edges, kerbs — the reference road is the brightest thing in frame
	var road := Color(0.80, 0.80, 0.82)
	draw_colored_polygon(PackedVector2Array([
		Vector2(540 - LANE_HALF_TOP, LANE_TOP), Vector2(540 + LANE_HALF_TOP, LANE_TOP),
		Vector2(540 + LANE_HALF_BOTTOM, LANE_BOTTOM), Vector2(540 - LANE_HALF_BOTTOM, LANE_BOTTOM)
	]), road)
	for sgn in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(540 + sgn * LANE_HALF_TOP, LANE_TOP),
			Vector2(540 + sgn * (LANE_HALF_TOP + 16), LANE_TOP),
			Vector2(540 + sgn * (LANE_HALF_BOTTOM + 30), LANE_BOTTOM),
			Vector2(540 + sgn * LANE_HALF_BOTTOM, LANE_BOTTOM)]), Color(0.62, 0.62, 0.66))
	for i in range(11):
		var y0 := lerpf(LANE_TOP, LANE_BOTTOM, float(i) / 11.0)
		var y1 := lerpf(LANE_TOP, LANE_BOTTOM, (float(i) + 0.5) / 11.0)
		var w0 := 9.0 * depth_scale(y0)
		var w1 := 9.0 * depth_scale(y1)
		draw_colored_polygon(PackedVector2Array([
			Vector2(540 - w0, y0), Vector2(540 + w0, y0),
			Vector2(540 + w1, y1), Vector2(540 - w1, y1)]), Color(1, 1, 1, 0.85))


func _draw_gates() -> void:
	# ⛔ These were invisible in the first rendered frame — a grey label and no arch at all.
	# A gate has to be a solid slab across its lane with a bevel and a number you can read at a
	# glance, because pricing the two lanes IS the game.
	var rows: Array = level_data.get("rows", [])
	var fnt := ThemeDB.fallback_font
	for i in range(rows.size()):
		if i < rows_passed:
			continue
		var ry := row_y(i)
		var half := lane_half(ry)
		var row: Array = rows[i]
		var lanes: int = row.size()
		var wide := 2.0 * half / float(lanes)
		var d := depth_scale(ry)
		var hgt := 150.0 * d
		for j in range(lanes):
			var g: Dictionary = row[j]
			var x0 := 540.0 - half + wide * float(j)
			var col := C_GOOD if g["kind"] != "cut" else C_BAD
			# slab + top bevel + dark base line
			draw_rect(Rect2(x0 + 4, ry - hgt, wide - 8, hgt), col)
			draw_rect(Rect2(x0 + 4, ry - hgt, wide - 8, hgt * 0.22), col.lightened(0.30))
			draw_rect(Rect2(x0 + 4, ry - 6, wide - 8, 6), col.darkened(0.45))
			var label := ("x%d" % int(g["value"])) if g["kind"] == "mul" else \
					(("+%d" % int(g["value"])) if g["kind"] == "add" else ("-%d%%" % int(g["value"])))
			var fs := int(86.0 * d)
			var tw := fnt.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tp := Vector2(x0 + wide * 0.5 - tw * 0.5, ry - hgt * 0.30)
			draw_string(fnt, tp + Vector2(3, 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
					Color(0, 0, 0, 0.45))
			draw_string(fnt, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_enemy() -> void:
	# was a single dotted line at the top edge; the reference is a WALL of bodies
	if state == State.WON:
		return
	var shown: int = mini(enemy, 520)
	var per_row := 20
	var rows_n: int = int(ceil(float(shown) / float(per_row)))
	for r in range(rows_n):
		var y := LANE_TOP + 18.0 + float(r) * 26.0
		var half := lane_half(y) * 0.96
		for c in range(per_row):
			if r * per_row + c >= shown:
				break
			var x := 540.0 - half + (2.0 * half) * (float(c) + 0.5) / float(per_row)
			var s := depth_scale(y) * 15.0
			draw_circle(Vector2(x + 2, y + 3), s, Color(0, 0, 0, 0.22))
			draw_circle(Vector2(x, y), s, C_ENEMY)
			draw_circle(Vector2(x - s * 0.28, y - s * 0.32), s * 0.36, C_ENEMY.lightened(0.45))
	var fnt := ThemeDB.fallback_font
	var t := str(enemy)
	var w := fnt.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	draw_string(fnt, Vector2(540 - w * 0.5 + 3, LANE_TOP - 26), t, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 84, Color(0, 0, 0, 0.4))
	draw_string(fnt, Vector2(540 - w * 0.5, LANE_TOP - 30), t, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 84, C_ENEMY.lightened(0.2))


func _draw_units() -> void:
	for u in units:
		var s2: float = depth_scale(u["y"]) * 19.0
		draw_circle(Vector2(u["x"] + 2, u["y"] + 4), s2 * 0.95, Color(0, 0, 0, 0.20))
		draw_circle(Vector2(u["x"], u["y"]), s2, C_ALLY)
		draw_circle(Vector2(u["x"] - s2 * 0.28, u["y"] - s2 * 0.34), s2 * 0.36, C_ALLY_HI)


func _draw_cannon() -> void:
	var y := CANNON_Y + 40.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(cannon_x - 54, y + 30), Vector2(cannon_x + 54, y + 30),
		Vector2(cannon_x + 34, y - 34), Vector2(cannon_x - 34, y - 34)]), C_INK)
	draw_rect(Rect2(cannon_x - 15, y - 66, 30, 40), C_ALLY)


func _draw_hud() -> void:
	var fnt := ThemeDB.fallback_font
	draw_string(fnt, Vector2(40, 74), "LEVEL %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 52,
			Color(1, 1, 1, 0.95))
	var c := str(crowd)
	draw_string(fnt, Vector2(1040 - fnt.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x, 78),
			c, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, C_ALLY_HI)
	if state == State.AIM:
		draw_string(fnt, Vector2(230, 1830), "drag to aim, release to send",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.8))
	if banner_t > 0.0 and banner != "":
		var a: float = clampf(banner_t, 0.0, 1.0)
		var big := 96 if state in [State.WON, State.LOST] else 74
		var w := fnt.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		draw_string(fnt, Vector2(540 - w * 0.5, 980), banner, HORIZONTAL_ALIGNMENT_LEFT, -1,
				big, Color(1, 1, 1, a))
	if state in [State.WON, State.LOST]:
		draw_string(fnt, Vector2(360, 1080), "tap to continue", HORIZONTAL_ALIGNMENT_LEFT, -1,
				42, Color(1, 1, 1, 0.85))
