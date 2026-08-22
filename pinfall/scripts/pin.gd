extends Node3D
## One pullable pin: a metal rod that plugs a hole until the player drags it out.
##
## The whole game is this object. Two things make it feel right rather than merely work:
## the pin RESISTS for the first few centimetres and then releases, and it stays a solid
## collider for the fluid until it is fully clear. A pin that vanishes on tap gives the player
## nothing to feel, and a pin that stops colliding at the start of the animation lets the fluid
## leak through a hole that is visibly still plugged.

const PULL_DISTANCE := 5.2      ## metres of travel before the pin is considered out
const PULL_SPEED := 6.5

var index := 0
var pulled := false
var _t := 0.0
var _body: StaticBody3D
var _rest: Vector3
var _length := 2.6

signal pulled_out(index: int)


func setup(pos: Vector3, length: float, mat: StandardMaterial3D, idx: int) -> void:
	index = idx
	_rest = pos
	_length = length
	position = pos

	_body = StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.32
	cyl.height = length
	cyl.radial_segments = 20        # a pin is the closest object to camera; 8 sides would read
	mesh.mesh = cyl
	mesh.material_override = mat
	mesh.rotation_degrees = Vector3(0, 0, 90)
	_body.add_child(mesh)

	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.32
	shape.height = length
	cs.shape = shape
	cs.rotation_degrees = Vector3(0, 0, 90)
	_body.add_child(cs)
	add_child(_body)

	# The pin's collider exists only for the fluid. Make it input-inert so every tap aimed at
	# the pin lands on the grab Area3D below, never on this body (its surface is 1 cm nearer
	# the camera than the area's front face, and StaticBody3D is ray-pickable by default).
	_body.input_ray_pickable = false

	# A grab volume wider than the pin. Fingers are not mouse cursors; hit targets under about
	# 9 mm on a phone are missed constantly, and the pin itself is 2.6 mm wide on screen.
	var area := Area3D.new()
	var acs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 0.62, 0.62)
	acs.shape = box
	area.add_child(acs)
	area.input_event.connect(_on_input)
	add_child(area)


func _on_input(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	if pulled:
		return
	if event is InputEventMouseButton and event.pressed:
		pulled = true
	elif event is InputEventScreenTouch and event.pressed:
		pulled = true


func _process(delta: float) -> void:
	if not pulled or _t >= 1.0:
		return
	_t = min(1.0, _t + delta * PULL_SPEED / PULL_DISTANCE)
	# Ease-in: slow for the first fifth of the travel, then it lets go. That short resistance is
	# the entire tactile character of the mechanic — linear travel feels like a slide, not a pull.
	var eased := _t * _t * (3.0 - 2.0 * _t)
	position = _rest + Vector3(PULL_DISTANCE * eased * signf(_rest.x if _rest.x != 0.0 else 1.0), 0, 0)
	# Collision goes away only once the pin has cleared its hole, not when the animation starts.
	if _t > 0.72 and _body.collision_layer != 0:
		_body.collision_layer = 0
		_body.collision_mask = 0
		pulled_out.emit(index)
