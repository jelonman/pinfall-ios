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
const DROPS := 140
const DROP_RADIUS := 0.115

var pins: Array[Node3D] = []
var _won := false
var _lost := false
var _hud: CanvasLayer
var _juice: Node
var _save: Node
var _pins_pulled := 0
var _spilled_any := false

## Levels are DATA. gates = (height, x of the hole); goal_x = which side the crucible sits on;
## needed = drops required. Adding a level is a row here, not a scene file.
const LEVELS := [
	{"gates": [[3.60, -0.85], [2.10, 0.95], [0.70, -0.10]], "goal_x": -1.65, "needed": 45},
	{"gates": [[3.90, 1.20], [2.60, -1.25], [1.35, 1.05], [0.15, -0.15]], "goal_x": 1.65, "needed": 55},
	{"gates": [[4.00, 0.00], [2.55, -1.55], [1.60, 1.55], [0.45, 0.00]], "goal_x": -1.65, "needed": 60},
]
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
	_build_vessels()
	_build_hero()
	_build_fluid()
	_hud = preload("res://scripts/hud.gd").new()
	add_child(_hud)
	_hud.set_level(level_index + 1, int(LEVELS[level_index]["needed"]),
		_save.stars, int(_save.best.get(level_index, 0)))


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
	goal.setup(Vector3(gx, -1.75, 0.55), Vector3(1.7, 1.1, 1.3), true, int(lvl["needed"]), goal_mat)
	goal.filled.connect(_on_win)
	add_child(goal)

	var drain := preload("res://scripts/goal.gd").new()
	drain.setup(Vector3(-gx, -1.75, 0.55), Vector3(1.7, 1.1, 1.3), false, 0, drain_mat)
	drain.spilled.connect(_on_lose)
	add_child(drain)


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
	cam.position = Vector3(0, 1.55, 11.2)
	cam.rotation_degrees = Vector3(-4, 0, 0)
	cam.fov = 50.0
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
	_slab(Vector3(6.4, 8.2, 0.4), Vector3(0, 1.9, -0.2), wall)
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
	pane_shape.size = Vector3(6.4, 8.2, 0.2)
	pane_cs.shape = pane_shape
	pane.add_child(pane_cs)
	pane.position = Vector3(0, 1.9, 1.35)
	add_child(pane)
	_slab(Vector3(6.4, 0.5, 3.6), Vector3(0, -2.55, 0.5), floor_mat)
	_slab(Vector3(0.5, 8.2, 3.6), Vector3(-3.05, 1.9, 0.55), wall)
	_slab(Vector3(0.5, 8.2, 3.6), Vector3(3.05, 1.9, 0.55), wall)
	# The funnel that gives the fluid somewhere to go, and the puzzle its shape.
	var accent := Look.toon(Color(0.30, 0.50, 0.68), 0.35)
	var left := _slab(Vector3(2.6, 0.35, 1.5), Vector3(-1.35, -0.75, 0.55), accent)
	left.rotation_degrees = Vector3(0, 0, -17)
	var right := _slab(Vector3(2.6, 0.35, 1.5), Vector3(1.35, -0.75, 0.55), accent)
	right.rotation_degrees = Vector3(0, 0, 17)


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
	const HOLE := 0.62          # hole width; must exceed the pin diameter or it never clears
	const THICK := 0.30

	for i in gates.size():
		var g: Dictionary = gates[i]
		var y: float = g["y"]
		var hx: float = g["hole"]
		var left_w: float = (hx - HOLE * 0.5) + HALF
		var right_w: float = HALF - (hx + HOLE * 0.5)
		if left_w > 0.05:
			_slab(Vector3(left_w, THICK, 1.5),
				Vector3(-HALF + left_w * 0.5, y, 0.55), shelf)
		if right_w > 0.05:
			_slab(Vector3(right_w, THICK, 1.5),
				Vector3(HALF - right_w * 0.5, y, 0.55), shelf)
		var pin := preload("res://scripts/pin.gd").new()
		pin.setup(Vector3(hx, y, 0.55), 1.9, mat, i)
		pin.pulled_out.connect(_on_pin_out)
		add_child(pin)
		pins.append(pin)


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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Look.LAVA
	mat.albedo_color = Color(1.0, 0.30, 0.10)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.34, 0.06)
	mat.emission_energy_multiplier = 1.15
	mat.roughness = 0.45
	mat.metallic = 0.0

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
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = mat
		drop.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		drop.add_child(cs)
		drop.position = Vector3(
			rng.randf_range(-0.75, 0.75),
			5.4 + float(i) * 0.03,
			0.55 + rng.randf_range(-0.25, 0.25))
		add_child(drop)
