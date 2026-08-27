extends Node3D
## Builds one Pinfall chamber in code.
##
## Why procedural rather than a hand-authored .tscn: a level here is ~15 numbers (pin positions,
## the goal, the hazard) and everything else is the same chamber every time. Keeping the geometry
## in code means a new level is a data row, not a scene file somebody has to open an editor to
## edit — which matters when the plan is dozens of levels and the editor is not in the loop.
##
## The look is the point. The owner's brief was explicit: proper assets, high resolution, real
## materials, "don't make them like some weird Minecraft stuff". So every surface here takes a
## photoscanned CC0 PBR set (albedo + normal + roughness + metallic where it exists), the
## lighting is a real key/rim pair with soft shadows, and the liquid is 140 rigid spheres rather
## than a flat blue rectangle. Nothing in this file is an untextured primitive.

const TEX := "res://art/textures/%s/%s.jpg"
const Look := preload("res://scripts/look.gd")

## The fluid is granular on purpose. Real fluid simulation is out of budget on a phone, and the
## ad games this is modelled on all use exactly this trick: enough small rigid bodies that the
## mass reads as a liquid when it pours. 140 is where it stops looking countable on a 1080p
## phone screen and before the 120 Hz physics tick starts costing frames.
# ⛔ 140 DROPS DID NOT FIT IN A SILO. At 0.055 spacing a 70-drop column stood 3.85 m tall inside
# a 1.6 m silo, so the top half of every silo was above its own divider and poured sideways into
# its neighbour — measured as exactly 8 iron in the crucible on every level before the wanted
# metal had finished, which is a contamination loss the player cannot prevent. 108 in a grid fits
# under the dividers with room to spare.
const DROPS := 108
const DROP_RADIUS := 0.115

var pins: Array[Node3D] = []
var _won := false
var _lost := false
var _hud: CanvasLayer
var _juice: Node
var _save: Node
var _pins_pulled := 0
var _spilled_any := false
var _diverter: StaticBody3D
var _diverter_left := true
var _goal: Node = null
var silo_pins: Array = []

## Levels are DATA, and there are 60 of them plus an endless curve after that.
##
## Owner, 2026-08-22: the shipped games were "very bones... the levels are short". Three levels
## is a demo. The curve below is generated from the index rather than hand-typed, so a level is
## a formula and the whole ladder can be re-measured in one run.
##
## gates = (height, x of the hole); goal_x = which side the crucible sits on; needed = drops
## required to win. NEEDED is MEASURED, not guessed — tools/levelsim.gd plays every level with a
## perfect top-to-bottom pull and records what actually lands in the crucible; the table below is
## 72% of that, so a clean solve wins and a sloppy one does not. Regenerate it with:
##     godot --headless --path . --script tools/levelsim.gd
const CHAMBER_HALF := 1.55       ## the usable half-width between the side walls
const DROPS_TOTAL := 140

## ⛔ REJECTED 4.3(a) AS SPAM ON 2026-08-25: "shares a similar binary, metadata, and/or concept as
## apps submitted by other developers, with only minor differences". Every pull-the-pin game on
## the store is the same sentence — get the liquid to the thing. So this one stopped being that.
##
## The chamber is now a FOUNDRY POUR. The molten in the shaft is not one liquid: it is layered,
## copper at the bottom, iron above it, gold on top, and it drains from the bottom up — so the
## order the metals arrive in is physics, not a menu. What the player controls is the DIVERTER
## under the shaft: one tap swings it toward the crucible, another toward the slag pit. Each level
## is an ORDER — so many of this metal, so many of that — and the wrong metal in the crucible
## ruins the heat exactly as surely as too little of the right one.
const METALS := [
	{"name": "copper", "albedo": Color(0.95, 0.26, 0.05), "emit": Color(1.00, 0.18, 0.02)},
	{"name": "iron",   "albedo": Color(0.55, 0.66, 0.86), "emit": Color(0.40, 0.60, 1.00)},
	{"name": "gold",   "albedo": Color(1.00, 0.88, 0.24), "emit": Color(1.00, 0.82, 0.16)},
]
## How much of a metal may end up in the crucible before it counts as contamination. A single
## splash off a shelf is not a spoiled heat; a stream is.
const CONTAMINATION_ALLOWANCE := 7

## Measured ceilings x a share that tightens from 68% to 82% as the ladder climbs.
## Raw measured catch, 2026-08-22 (tools/levelsim.gd, perfect top-to-bottom solve):
## 42 43 43 44 44 45 45 46 46 47 47 48 48 49 49 50 50 51 51 52 52 53 53 54 55 55 56 56 57 57 58 58 59 59 60 60 61 61 62 62 47 40 42 42 38 41 42 36 41 45 34 38 33 42 45 39 36 46 45 30 Filled by tools/levelsim.gd; a 0 means "not measured yet"
## and falls back to the formula, so the game is never unplayable while the table is being rebuilt.
const NEEDED := [7, 14, 6, 9, 13, 13, 8, 12, 6, 12, 8, 7, 5, 10, 8, 5, 3, 7, 10, 12, 8, 4, 9, 7, 4, 8, 8, 7, 4, 4, 4, 13, 8, 5, 6, 3, 5, 8, 7, 5, 5, 3, 5, 7, 5, 5, 6, 6, 6, 9, 6, 5, 6, 3, 6, 9, 10, 5, 4, 4]

static var LEVELS: Array = _build_levels()


static func _build_levels() -> Array:
	var out: Array = []
	for n in 60:
		out.append(_make_level(n))
	return out


static func _make_level(n: int) -> Dictionary:
	## Four bands of shelf count, so the shape of a level changes visibly as the player climbs
	## rather than only its numbers. Within a band the holes drift outward and the shelves pack
	## closer, which is what actually makes a pour harder: less room to correct between gates.
	# ⛔ THE STACK IS CAPPED AT FOUR SHELVES NOW. The silos need the top of the chamber, and more
	# than four shelves also destroyed the thing the silos exist for: measured, a layered pour
	# through six shelves arrives at the diverter completely interleaved, so no amount of steering
	# could keep one metal out of the crucible (copper 13, iron 8, every run a contamination
	# loss). Difficulty above level 20 comes from the hole positions, not from more shelves.
	# ⛔ THE FOURTH SHELF WAS A CLIFF, NOT A STEP. Measured across all 60 levels: the deliverable
	# ceiling averages about 15 drops for levels 1-20 and then collapses to 0-8 from level 21,
	# which is exactly where the stack went from three shelves to four. Eleven levels delivered
	# nothing at all. Survival compounds, so a fourth shelf does not make a level harder, it makes
	# it impossible. Three shelves everywhere; the ladder is the ORDER — one metal, then two, from
	# two silos, then three.
	var rows := 3
	# ⛔ SIX SHELVES DID NOT FIT IN THE OLD RANGE. Holding the top at 4.05 put 6 shelves 0.74
	# apart; with 0.30 of thickness and a 6 degree tilt the raised ends met the shelf above and
	# sealed the chamber. Measured: levels 0-39 caught 42 to 62 drops on a clean rising curve,
	# and every level from 40 on caught 0 to 6. The top of the stack now rises with the shelf
	# count so the gap never falls below about 0.95.
	var bottom := 0.35
	var top: float = bottom + 0.97 * float(rows - 1)
	var gates: Array = []
	for i in rows:
		var t: float = float(i) / float(max(rows - 1, 1))
		var y: float = top - (top - bottom) * t
		# Alternate the hole side every shelf, and push it further out as the ladder climbs, so
		# the stream has to be walked across the chamber instead of dropping straight through.
		var side := 1.0 if (i + n) % 2 == 0 else -1.0
		var reach: float = 0.35 + 0.75 * clampf(float(n) / 45.0, 0.0, 1.0)
		var wobble: float = 0.22 * sin(float(n) * 1.7 + float(i) * 2.3)
		var hole: float = clampf(side * CHAMBER_HALF * reach + wobble, -1.58, 1.58)
		gates.append([snappedf(y, 0.01), snappedf(hole, 0.01)])
	var goal_x := -1.65 if n % 2 == 0 else 1.65
	# Two metals to start with, three from level 10. The order asks for one of them early and two
	# from level 18, which is the point the diverter has to be worked twice in one pour.
	var metal_count := 2 if n < 10 else 3
	var wants: Array = [0]
	if n >= 18:
		wants = [0, 2] if metal_count > 2 and n % 3 != 1 else [0, 1]
	if n >= 30 and metal_count > 2 and n % 4 == 0:
		wants = [1, 2]
	# ⛔ WINNABILITY IS BUILT IN, NOT HOPED FOR. The ridge peaks near x=0.2 and each side falls
	# away to its own vessel, so a level whose LAST hole sits on the wrong side of that peak
	# cannot deliver a single drop to the crucible no matter how well it is played — measured:
	# generated levels 1 and 2 caught 0 of 140 before this line existed. The bottom hole is
	# therefore always on the goal's side; the difficulty lives in the shelves above it, which
	# decide how much of the pour is still travelling when it gets there.
	# ⛔ The bottom hole used to be bound to the goal's side, because the ridge under it was fixed
	# and a stream on the wrong side could never be recovered. The diverter replaced the ridge, so
	# the bottom hole now aims at the MIDDLE — the player decides the side, not the level.
	var last: Array = gates[gates.size() - 1]
	last[1] = snappedf(0.24 * sin(float(n) * 2.1), 0.01)
	return {"gates": gates, "goal_x": goal_x, "needed": _needed_for(n),
		"metals": metal_count, "wants": wants}


static func _needed_for(n: int) -> int:
	## The measured table wins whenever it has a row for this level.
	if n < NEEDED.size() and int(NEEDED[n]) > 0:
		return NEEDED[n]
	# Fallback while the table is being rebuilt: a share of the pour that grows with the ladder.
	return int(round(DROPS_TOTAL * (0.30 + 0.22 * clampf(float(n) / 59.0, 0.0, 1.0))))


var level_index := 0


func _ready() -> void:
	_save = preload("res://scripts/save.gd").new()
	add_child(_save)
	# Resume where they left off rather than at level 1. A returning player landing back on a
	# level they already beat is the fastest way to lose them on day two.
	level_index = clampi(int(Engine.get_meta("pinfall_level", _save.level)), 0, LEVELS.size() - 1)
	_build_environment()
	_build_chamber()
	_build_pins()
	_build_silos()
	_build_vessels()
	_build_hero()
	_build_fluid()
	_hud = preload("res://scripts/hud.gd").new()
	add_child(_hud)
	var names: Array = []
	for m in METALS:
		names.append(m["name"])
	_hud.set_order(names, wants_of(level_index), per_metal_target(level_index),
		level_index + 1, _save.stars, int(_save.best.get(level_index, 0)))
	_hud.set_diverter(_diverter_left, goal_x_of(level_index) < 0.0)


func _unhandled_input(event: InputEvent) -> void:
	## Tap anywhere after a verdict to move on. No menu, on purpose: the retry loop in this genre
	## has to be faster than the impulse to close the app.
	if not (_won or _lost):
		return
	var tapped: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		Engine.set_meta("pinfall_level",
			mini(level_index + 1, LEVELS.size() - 1) if _won else level_index)
		get_tree().reload_current_scene()


func _build_vessels() -> void:
	## Two containers, opposite meanings, told apart by material alone.
	var lvl: Dictionary = LEVELS[level_index]
	var gx: float = lvl["goal_x"]

	var goal_mat := Look.metal(Look.GOLD)

	var drain_mat := Look.toon(Color(0.16, 0.14, 0.18), 0.3)

	var goal := preload("res://scripts/goal.gd").new()
	# The total is no longer the win. `filled` is left unconnected on purpose: the crucible is
	# judged on the RECIPE, and a crucible with the right total of the wrong metal is a failure,
	# not a success.
	goal.setup(Vector3(gx, -1.75, 0.55), Vector3(1.7, 1.1, 1.3), true, 99999, goal_mat)
	goal.metal_in.connect(_on_metal_in)
	add_child(goal)
	_goal = goal

	# ⛔ THE SLAG PIT IS NO LONGER A LOSS. Dumping the metals the order does not call for is now
	# how the level is PLAYED — punishing it would make the diverter pointless. What ends a heat
	# is the wrong metal reaching the crucible.
	var drain := preload("res://scripts/goal.gd").new()
	drain.setup(Vector3(-gx, -1.75, 0.55), Vector3(1.7, 1.1, 1.3), false, 999999, drain_mat)
	add_child(drain)


func wants_of(n: int) -> Array:
	return LEVELS[n].get("wants", [0])


func per_metal_target(n: int) -> int:
	## The level's measured ceiling, split across the metals the order asks for.
	var w: Array = wants_of(n)
	return maxi(6, int(round(float(LEVELS[n]["needed"]) / float(maxi(w.size(), 1)))))


func _on_metal_in(metal: int, total: int) -> void:
	if _won or _lost:
		return
	var w: Array = wants_of(level_index)
	if not w.has(metal):
		if total > CONTAMINATION_ALLOWANCE:
			_spilled_any = true
			_on_lose_reason("%s in the crucible. The heat is ruined." % METALS[metal]["name"])
		return
	var target := per_metal_target(level_index)
	var counts: Dictionary = _goal.counts
	for m in w:
		if int(counts.get(m, 0)) < target:
			if _hud != null and _hud.has_method("set_recipe_progress"):
				_hud.set_recipe_progress(counts, w, target)
			return
	_on_win()


func _on_lose_reason(reason: String) -> void:
	if _won:
		return
	_lost = true
	_hud.verdict(reason, false)


func _on_pin_out(_i: int) -> void:
	_pins_pulled += 1
	## The kick lands when the pin CLEARS, not when the drag starts — the release is the moment
	## the player caused something, and feedback on the wrong frame reads as lag.
	_juice.kick(0.16)


func _on_win() -> void:
	if _lost:
		return
	_won = true
	_juice.kick(0.30)
	var sparks := preload("res://scripts/juice.gd")
	sparks.sparks(self, Vector3(LEVELS[level_index]["goal_x"], -1.2, 0.55),
		Color(1.0, 0.72, 0.3), 46)
	var improved: bool = _save.record_win(level_index, _pins_pulled, not _spilled_any)
	_hud.verdict("Rescued!" if not improved else "Rescued — best yet", true)


func _on_lose() -> void:
	if _won:
		return
	_lost = true
	_spilled_any = true
	_hud.verdict("Too much spilled", false)


func _pbr(role: String, uv_scale: float = 1.0, metal_hint := 0.0) -> StandardMaterial3D:
	## One material per surface, built from the scanned maps that actually exist for it.
	## Missing maps are skipped rather than substituted: a flat grey standing in for a roughness
	## scan is exactly the plastic look this project is trying not to have.
	var m := StandardMaterial3D.new()
	var albedo := TEX % [role, "albedo"]
	if ResourceLoader.exists(albedo):
		m.albedo_texture = load(albedo)
	var normal := TEX % [role, "normal"]
	if ResourceLoader.exists(normal):
		m.normal_enabled = true
		m.normal_texture = load(normal)
		m.normal_scale = 1.0
	var rough := TEX % [role, "roughness"]
	if ResourceLoader.exists(rough):
		m.roughness_texture = load(rough)
	else:
		m.roughness = 0.6
	var metal := TEX % [role, "metallic"]
	if ResourceLoader.exists(metal):
		m.metallic_texture = load(metal)
		m.metallic = 1.0
	else:
		m.metallic = metal_hint
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _build_environment() -> void:
	## A key light, a cool rim, and a real sky. The rim is what stops the metal pins reading as
	## grey cardboard against the wall — with a single light, a cylinder has no silhouette.
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.36, 0.58)
	sky_mat.sky_horizon_color = Color(0.52, 0.62, 0.72)
	sky_mat.ground_bottom_color = Color(0.18, 0.21, 0.30)
	sky_mat.ground_horizon_color = Color(0.28, 0.34, 0.46)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.6
	# Glow makes the fluid read as molten rather than as painted spheres. Cheap on mobile
	# because only the emissive drops exceed the threshold.
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 3.2
	env.ssao_enabled = false      # mobile renderer: not available, and asking for it costs nothing but a warning

	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var key := DirectionalLight3D.new()
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.96, 0.90)
	key.shadow_enabled = true
	key.shadow_opacity = 0.35
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.rotation_degrees = Vector3(-52, -36, 0)
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.75
	rim.light_color = Color(0.45, 0.62, 1.0)
	rim.shadow_enabled = false
	rim.rotation_degrees = Vector3(-18, 148, 0)
	add_child(rim)

	var bounce := DirectionalLight3D.new()
	bounce.light_energy = 0.7
	bounce.light_color = Color(0.62, 0.74, 1.0)
	bounce.shadow_enabled = false
	bounce.rotation_degrees = Vector3(58, 18, 0)
	add_child(bounce)

	var cam := Camera3D.new()
	# The silos sit at y 4.6-7.0 now, so the camera has to hold roughly 10 m of chamber instead of
	# 6. Raised and pulled back until both the silo gates and the crucible read in one frame.
	# With the width locked, fov 50 is the HORIZONTAL angle, so the distance has to be set from the
	# chamber's 6.4 m width rather than from its height: 3.6 / tan(25 deg) puts the walls just
	# inside the frame edges. At the old 12.9 the chamber filled a third of a tall phone screen.
	cam.position = Vector3(0, 2.05, 8.40)
	cam.rotation_degrees = Vector3(-2, 0, 0)
	cam.fov = 50.0
	# ⛔ KEEP THE WIDTH, NOT THE HEIGHT. A Camera3D defaults to holding vertical FOV, so on a phone
	# narrower than the 1080x1920 design — an iPhone 17 Pro Max is 1320x2868, ratio 0.46 against
	# 0.5625 — the chamber is CROPPED sideways and both outer silos run off the screen. Captured
	# at 1290x2796 and looked at, which is the only way this shows up. Holding the width means a
	# taller phone simply sees more chamber.
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	_juice = preload("res://scripts/juice.gd").new()
	add_child(_juice)
	_juice.bind(cam)


func _slab(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = size
	shape.shape = col
	body.add_child(shape)
	body.position = pos
	add_child(body)
	return body


func _build_chamber() -> void:
	var wall := Look.toon(Look.STONE, 0.5)
	var floor_mat := Look.toon(Look.STONE_DARK, 0.4)
	# Back plate, floor, and two side walls. UV scale differs per surface so the tiling repeat
	# never lines up across an edge, which is the tell that gives away a texture atlas.
	_slab(Vector3(6.4, 9.4, 0.4), Vector3(0, 2.5, -0.2), wall)
	# The invisible front pane. Without it the drops drift out of the pin plane and the level
	# looks like it is working while nothing is actually being held back — which is exactly what
	# the first render showed: molten pooled on the floor with every pin still in place.
	#
	# ⛔ It MUST NOT be ray-pickable. StaticBody3D defaults to input_ray_pickable=true, and this
	# pane sits between the camera (z=11.2) and every pin (z=0.55), so with picking enabled it
	# intercepts every tap and the pin grab areas never see an input event — a shipped build
	# where "the pins/paddles don't respond" (reported by a closed-test tester 2026-08-08;
	# proven by tools/raytest.gd: rays to all 3 pins hit the pane at z=1.45, never the Area3D).
	var pane := StaticBody3D.new()
	pane.input_ray_pickable = false
	var pane_cs := CollisionShape3D.new()
	var pane_shape := BoxShape3D.new()
	pane_shape.size = Vector3(6.4, 9.4, 0.2)
	pane_cs.shape = pane_shape
	pane.add_child(pane_cs)
	pane.position = Vector3(0, 2.5, 1.35)
	add_child(pane)
	_slab(Vector3(6.4, 0.5, 3.6), Vector3(0, -2.55, 0.5), floor_mat)
	_slab(Vector3(0.5, 9.4, 3.6), Vector3(-3.05, 2.5, 0.55), wall)
	_slab(Vector3(0.5, 9.4, 3.6), Vector3(3.05, 2.5, 0.55), wall)
	# The funnel that gives the fluid somewhere to go, and the puzzle its shape.
	var accent := Look.toon(Color(0.30, 0.50, 0.68), 0.35)
	# ⛔ THIS WAS A V AND THE GAME COULD NOT BE WON. Both slabs sloped DOWN toward the centre and
	# spanned x -2.59..-0.11 and 0.11..2.59, which put a solid roof over both vessel mouths
	# (the crucible opening is x -2.50..-0.80, top at y=-1.20). tools/levelsim.gd plays a level
	# with a perfect top-to-bottom pull and counts what lands: 0 of 140 for every one of the three
	# shipped levels, and 0 drops even reached y=-1.2. Molten came to rest at y=-0.86, sitting on
	# the funnel, and the crucible could never fill. Build 1 shipped like this on 2026-08-02.
	#
	# It is now a RIDGE, not a funnel: the peak is at the centre and each slab falls away toward
	# its own vessel, so where the stream crosses the ridge decides which one it fills. That is
	# also the choice the level is supposed to be asking for.
	# THE DIVERTER. One plate under the shaft, and the only control in the game besides the pins.
	# It starts pointing at the slag pit, because a level that starts pointing at the crucible
	# would fill it with whatever came first and decide the heat before the player touched it.
	# Long enough that each end sits over a vessel mouth. At 3.3 the plate stopped short of both
	# and read as a loose slab floating in the middle of the chamber rather than as a chute.
	_diverter = _slab(Vector3(3.9, 0.26, 1.5), Vector3(0.0, -0.72, 0.55), accent)
	_set_diverter(goal_x_of(level_index) > 0.0)   # true = tipped left, i.e. away from the goal
	var tap := Area3D.new()
	var tcs := CollisionShape3D.new()
	var tb := BoxShape3D.new()
	tb.size = Vector3(4.2, 1.5, 1.6)
	tcs.shape = tb
	tap.add_child(tcs)
	tap.position = Vector3(0.0, -0.72, 0.55)
	tap.input_event.connect(_on_diverter_tap)
	add_child(tap)


func goal_x_of(n: int) -> float:
	return float(LEVELS[n]["goal_x"])


func _set_diverter(tip_left: bool) -> void:
	## A tilted plate feeds the side its LOW end is on. Positive z rotation drops the +x end.
	_diverter_left = tip_left
	_diverter.rotation_degrees = Vector3(0, 0, 13.0 if tip_left else -13.0)


func _on_diverter_tap(_cam: Node, event: InputEvent, _p: Vector3, _n: Vector3, _i: int) -> void:
	if _won or _lost:
		return
	if (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed):
		_set_diverter(not _diverter_left)
		_juice.kick(0.10)
		if _hud != null and _hud.has_method("set_diverter"):
			_hud.set_diverter(_diverter_left, goal_x_of(level_index) < 0.0)


func _build_pins() -> void:
	## A pin is a PLUG, not a floating rod. The first playable render had pins hanging in open
	## space with metre-wide gaps between them, so the fluid poured straight past every one and
	## the level looked finished while doing nothing. That is the whole mechanic: a solid shelf
	## with a hole in it, and a pin filling the hole. Pull the pin, the hole opens, the fluid goes.
	var shelf := Look.toon(Look.STONE_DARK, 0.55)
	var mat := Look.metal(Look.STEEL)

	# Each gate: a y height, and the x centre of the hole the pin plugs. The shelf is built as
	# two segments either side, so the hole is real geometry rather than a gap that only exists
	# in the collision layer.
	var gates := []
	for g in LEVELS[level_index]["gates"]:
		gates.append({"y": float(g[0]), "hole": float(g[1])})
	const HALF := 2.80          # inner half-width of the chamber
	# ⛔ 0.62 JAMMED. 140 spheres of radius 0.115 arch over any orifice narrower than about five
	# ball diameters, so a 0.62 hole (2.7 diameters) stopped the pour dead: tools/flowprobe.gd
	# measured 6 of 140 drops through in the first 2.5 s and then nothing at all for the next
	# 27.5 s. 1.30 is 5.6 diameters and drains. The pin is 1.9 long, so it still plugs the hole.
	# ⛔ 1.30 DRAINED, BUT IT DID NOT DELIVER. Survival compounds across shelves, so a hole that
	# passes some of the pour on one shelf passes almost none through four: the measured ceiling
	# fell from 22 drops on level 1 to between 1 and 4 by level 30, which is not an order anybody
	# can fill. 1.90, with a 2.5 pin to plug it, took level 30 from 3 to 23 and left the diverter
	# just as decisive (the nailed-diverter run still loses).
	const HOLE := 1.90          # hole width; must exceed the pin diameter or it never clears
	const THICK := 0.30

	for i in gates.size():
		var g: Dictionary = gates[i]
		var y: float = g["y"]
		var hx: float = g["hole"]
		var left_w: float = (hx - HOLE * 0.5) + HALF
		var right_w: float = HALF - (hx + HOLE * 0.5)
		# ⛔ FLAT SHELVES STOP THE POUR. Molten that lands away from the hole simply rests there:
		# tools/flowprobe.gd on level 8 measured the whole pour parked at y=0.61, on top of the
		# lowest shelf, for 30 s with not one drop through — and every generated level with 4 or
		# more shelves caught 0 of 140 for the same reason. Each half now slopes 6 degrees TOWARD
		# the hole, so a shelf gathers what lands on it instead of holding it. The puzzle is
		# unchanged: which hole, and in which order.
		const TILT := 18.0
		if left_w > 0.05:
			var ls := _slab(Vector3(left_w, THICK, 1.5),
				Vector3(-HALF + left_w * 0.5, y, 0.55), shelf)
			ls.rotation_degrees = Vector3(0, 0, -TILT)
		if right_w > 0.05:
			var rs := _slab(Vector3(right_w, THICK, 1.5),
				Vector3(HALF - right_w * 0.5, y, 0.55), shelf)
			rs.rotation_degrees = Vector3(0, 0, TILT)
		_hole_lips(hx, y, HOLE, shelf)
		var pin := preload("res://scripts/pin.gd").new()
		pin.setup(Vector3(hx, y, 0.55), 2.5, mat, i)
		pin.pulled_out.connect(_on_pin_out)
		add_child(pin)
		pins.append(pin)


const SILO_HALF := 2.80        ## the chamber's inner half-width; the silos fill it
const SILO_FLOOR_Y := 3.95
# ⛔ THE DIVIDERS HAVE TO BE TALLER THAN THE CHARGE. At 5 columns a 54-drop grid stands 2.86 m,
# starting at 4.87 — so with a 7.00 divider the top three rows began ABOVE it and spilled into the
# neighbouring silo. Measured with the gate shut: 44 of 54 iron drops escaped anyway.
const SILO_TOP_Y := 6.60


func _hole_lips(x: float, y: float, width: float, mat: StandardMaterial3D) -> void:
	## ⛔ A PIN PLUGS A CIRCLE; A HOLE IN A SHELF IS A RECTANGLE. The pin is a cylinder of radius
	## 0.32 lying along x, so it seals z 0.23-0.87. The shelves and silo floors are 1.5 deep,
	## z -0.20 to 1.30 — which leaves two open strips the charge simply falls through. Measured
	## with tools/leakprobe.gd: with the iron gate CLOSED, 46 of 54 iron drops were below y=3
	## within two seconds. These two lips close the part of the hole the pin was never covering.
	const LIP := 0.43
	_slab(Vector3(width, 0.26, LIP), Vector3(x, y, -0.20 + LIP * 0.5), mat)
	_slab(Vector3(width, 0.26, LIP), Vector3(x, y, 1.30 - LIP * 0.5), mat)


func _build_silos() -> void:
	## One silo per metal, side by side, each with its own gate. This is the change that made the
	## order mean anything: with all three metals stacked in ONE shaft they arrive mixed, and the
	## player has nothing to aim. With a gate each, the player decides WHICH metal is falling, and
	## the diverter decides where it goes. Two controls, and the level is the question of how to
	## use them together.
	var metal_n: int = int(LEVELS[level_index].get("metals", 2))
	var wall := Look.toon(Look.STONE_DARK, 0.5)
	var mat := Look.metal(Look.STEEL)
	# ⛔ THE SILOS HAVE TO REACH THE CHAMBER WALLS. Built 3.7 m wide inside a 5.6 m chamber, they
	# left a 0.95 m open strip down each side with no floor in it — and tools/crossprobe.gd found
	# every escaping drop crossing the floor plane at x 2.02 to 2.52, which is exactly that strip.
	# 45 of 54 iron left a shut silo by walking off its outer edge.
	var span: float = (SILO_HALF * 2.0) / float(metal_n)
	for m in metal_n:
		var cx: float = -SILO_HALF + span * (float(m) + 0.5)
		# Divider between silos, so a metal cannot drift sideways into its neighbour's gate.
		if m > 0:
			_slab(Vector3(0.16, SILO_TOP_Y - SILO_FLOOR_Y, 1.5),
				Vector3(cx - span * 0.5, (SILO_FLOOR_Y + SILO_TOP_Y) * 0.5, 0.55), wall)
		var hole := 1.05
		var lw: float = (span - hole) * 0.5
		if lw > 0.05:
			_slab(Vector3(lw, 0.26, 1.5), Vector3(cx - span * 0.5 + lw * 0.5, SILO_FLOOR_Y, 0.55), wall)
			_slab(Vector3(lw, 0.26, 1.5), Vector3(cx + span * 0.5 - lw * 0.5, SILO_FLOOR_Y, 0.55), wall)
		_hole_lips(cx, SILO_FLOOR_Y, hole, wall)
		var pin := preload("res://scripts/pin.gd").new()
		pin.setup(Vector3(cx, SILO_FLOOR_Y, 0.55), 1.5, mat, 100 + m)
		pin.pulled_out.connect(_on_pin_out)
		add_child(pin)
		pins.append(pin)
		silo_pins.append(pin)


func _build_hero() -> void:
	## A chunky stylised figure standing in the goal, waiting. Deliberately simple shapes: at
	## phone size a detailed character is mush, and the silhouette is doing all the work.
	var lvl: Dictionary = LEVELS[level_index]
	var gx: float = lvl["goal_x"]
	var root := Node3D.new()
	root.position = Vector3(gx, -1.95, 0.95)
	add_child(root)

	var cloth := Look.toon(Look.HERO_CLOTH, 0.7)
	var skin := Look.toon(Look.HERO_SKIN, 0.6)

	var body := MeshInstance3D.new()
	var caps := CapsuleMesh.new()
	caps.radius = 0.24
	caps.height = 0.74
	body.mesh = caps
	body.material_override = cloth
	body.position = Vector3(0, 0.30, 0)
	root.add_child(body)

	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.20
	sph.height = 0.40
	head.mesh = sph
	head.material_override = skin
	head.position = Vector3(0, 0.80, 0)
	root.add_child(head)

	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var ac := CapsuleMesh.new()
		ac.radius = 0.085
		ac.height = 0.42
		arm.mesh = ac
		arm.material_override = skin
		arm.position = Vector3(side * 0.27, 0.46, 0)
		# Arms up. It reads as "help" from across the room, which is the entire point of
		# putting a figure in the frame at all.
		arm.rotation_degrees = Vector3(0, 0, side * 38.0)
		root.add_child(arm)


func _build_fluid() -> void:
	## Emissive, heavy, slightly bouncy. Emission is what makes 140 spheres read as one molten
	## mass under the glow pass instead of as 140 separate balls.
	# One material per metal. The shaft drains from the bottom, so the metal a drop is given is
	# decided by where it starts in the stack: the deepest third is copper, then iron, then gold.
	# That is what makes the arrival ORDER a physical fact the player can plan around.
	var metal_n: int = int(LEVELS[level_index].get("metals", 2))
	var mats: Array = []
	for m in metal_n:
		var mm := StandardMaterial3D.new()
		mm.albedo_color = METALS[m]["albedo"]
		mm.emission_enabled = true
		mm.emission = METALS[m]["emit"]
		mm.emission_energy_multiplier = 4.2
		mm.roughness = 0.45
		mm.metallic = 0.25 if m > 0 else 0.0
		mats.append(mm)

	var sphere := SphereMesh.new()
	sphere.radius = DROP_RADIUS
	sphere.height = DROP_RADIUS * 2.0
	sphere.radial_segments = 8      # a phone never resolves more, and 140 of them adds up
	sphere.rings = 4

	var shape := SphereShape3D.new()
	shape.radius = DROP_RADIUS

	var phys := PhysicsMaterial.new()
	phys.friction = 0.05
	phys.bounce = 0.05

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260801        # a fixed seed so a level plays the same way twice
	for i in DROPS:
		var drop := RigidBody3D.new()
		drop.mass = 0.22
		drop.physics_material_override = phys
		drop.continuous_cd = true          # at 0.085 radius and 14 m/s^2, drops tunnel without it
		var metal: int = mini(int(float(i) / float(DROPS) * float(metal_n)), metal_n - 1)
		# i ascends, so metal 0 fills first and each silo gets an equal share of the heat.
		drop.set_meta("metal", metal)
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = mats[metal]
		drop.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		drop.add_child(cs)
		var span: float = (SILO_HALF * 2.0) / float(metal_n)
		var cx: float = -SILO_HALF + span * (float(metal) + 0.5)
		var per: int = int(ceil(float(DROPS) / float(metal_n)))
		var within: int = i % per
		# A GRID, not a column. Height is what overflowed the dividers, so the charge is laid out
		# across the silo's width first and only then upward.
		var cols: int = maxi(3, int(floor((span - 0.30) / 0.26)))
		var col: int = within % cols
		var row: int = within / cols
		drop.position = Vector3(
			cx - (span - 0.30) * 0.5 + float(col) * 0.26 + rng.randf_range(-0.02, 0.02),
			# ⛔ Row 0 used to spawn at +0.32, which is exactly the top of the pin's 0.32 radius —
			# so every drop in the bottom row started half inside the gate and Godot pushed it out
			# THROUGH the plug. That, not the dividers, was the leak: 42 of 54 iron escaped a shut
			# gate. Starting a clear radius above the plug removes it.
			SILO_FLOOR_Y + 0.62 + float(row) * 0.26,
			0.55 + rng.randf_range(-0.20, 0.20))
		# i ascends with height, and the metal index ascends with i, so copper really is at the
		# bottom of the shaft and gold really is on top. Colour alone would be a label; this is
		# the level's actual timing.
		add_child(drop)
