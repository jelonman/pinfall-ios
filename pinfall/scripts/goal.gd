extends Area3D
## The vessel the molten has to reach, and the drain it must not.
##
## Both are the same object with opposite meanings, because the failure mode of this genre is a
## player who cannot tell which container is which. So the difference is carried by MATERIAL and
## LIGHT, not by a label: the goal glows warm and is lit from inside, the drain is cold, matte
## and unlit. You can tell them apart in a screenshot with the sound off, which is exactly the
## test an ad has to pass.

signal filled
signal spilled
signal metal_in(metal: int, total: int)

@export var is_goal := true
var _count := 0
## Per-metal tallies. The foundry order is a RECIPE, so the vessel has to know what is in it, not
## just how full it is — 40 drops of the wrong alloy is a ruined heat, not a win.
var counts := {}
var _needed := 0
var _fired := false


func setup(pos: Vector3, size: Vector3, goal: bool, needed: int, mat: StandardMaterial3D) -> void:
	is_goal = goal
	_needed = needed
	position = pos

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
	monitoring = true

	# Built as a floor and two walls, not a solid block. The first version drew a filled box, so
	# the crucible read as a slab the molten was landing ON rather than a vessel it was going IN
	# to — which inverts the instruction the whole level is giving.
	var wall_t := 0.16
	for part in [
		{"s": Vector3(size.x, wall_t, size.z), "p": Vector3(0, -size.y * 0.5, 0)},
		{"s": Vector3(wall_t, size.y, size.z), "p": Vector3(-size.x * 0.5, 0, 0)},
		{"s": Vector3(wall_t, size.y, size.z), "p": Vector3(size.x * 0.5, 0, 0)},
	]:
		var body := StaticBody3D.new()
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part["s"]
		mi.mesh = mesh
		mi.material_override = mat
		body.add_child(mi)
		var bcs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = part["s"]
		bcs.shape = bs
		body.add_child(bcs)
		body.position = part["p"]
		add_child(body)

	if is_goal:
		# Light INSIDE the vessel. A rim light on the outside reads as decoration; a light in the
		# mouth of the container reads as "put the molten here", which is the whole instruction.
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.72, 0.35)
		lamp.light_energy = 2.4
		lamp.omni_range = 3.2
		lamp.position = Vector3(0, size.y * 0.4, 0)
		add_child(lamp)

	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if _fired or not (body is RigidBody3D):
		return
	_count += 1
	var m: int = int(body.get_meta("metal", 0))
	counts[m] = int(counts.get(m, 0)) + 1
	metal_in.emit(m, int(counts[m]))
	if is_goal and _count >= _needed:
		_fired = true
		filled.emit()
	elif not is_goal and _count >= 6:
		# Six drops, not one. A single stray splash off a shelf is not a loss, and losing to one
		# is the kind of unfairness that makes people uninstall on level three.
		_fired = true
		spilled.emit()
