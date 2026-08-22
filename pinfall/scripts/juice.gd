extends Node
## Impact feedback. The difference between a physics toy and a game people replay.
##
## Everything here is reactive: a pin coming out kicks the camera, molten landing in the crucible
## throws sparks, and a win pushes the light up. None of it changes what happens — it changes
## whether pulling a pin feels like anything. A pull with no kick reads as a UI event, and the
## whole genre is built on that pull feeling physical.

var _cam: Camera3D
var _base := Vector3.ZERO
var _shake := 0.0
var _decay := 6.0


func bind(cam: Camera3D) -> void:
	_cam = cam
	_base = cam.position


func kick(amount: float = 0.22) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if _cam == null:
		return
	if _shake <= 0.0005:
		_cam.position = _base
		return
	# Positional, not rotational. Rotating the camera on a fixed 2.5D layout swings the whole
	# playfield and makes it hard to track a falling drop; translating keeps the level readable.
	_cam.position = _base + Vector3(
		randf_range(-_shake, _shake),
		randf_range(-_shake, _shake) * 0.6,
		0.0)
	_shake = maxf(0.0, _shake - _decay * _shake * delta)


static func sparks(parent: Node3D, at: Vector3, colour: Color, amount := 18) -> void:
	## One-shot GPUParticles3D that frees itself. Attaching these to the crucible and forgetting
	## them is how a level ends up with 400 emitters after a minute of play.
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 42.0
	mat.initial_velocity_min = 2.2
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -9.0, 0)
	mat.scale_min = 0.25
	mat.scale_max = 0.7
	mat.damping_min = 0.5
	mat.damping_max = 1.5
	p.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 6
	mesh.rings = 3
	var dm := StandardMaterial3D.new()
	dm.albedo_color = colour
	dm.emission_enabled = true
	dm.emission = colour
	dm.emission_energy_multiplier = 3.5
	mesh.material = dm
	p.draw_pass_1 = mesh

	p.amount = amount
	p.lifetime = 0.75
	p.one_shot = true
	p.explosiveness = 0.95
	p.position = at
	parent.add_child(p)
	p.emitting = true
	# Free after the last particle dies, not on a guessed timer.
	parent.get_tree().create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)
