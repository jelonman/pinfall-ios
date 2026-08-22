extends SceneTree

## Guards against the failure dupe_test exposed: a text-replacement edit that applies cleanly and
## changes nothing. Every property this project has reported as done is asserted against the live
## scene, not against the source text, so a silent no-op cannot be reported as a fix again.
func _init():
	var g = load("res://scenes/Main3D.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await process_frame
	g.rng.seed = 20260820
	g.level = 12
	g.start_level()
	for _i in range(40):
		g._process(1.0 / 60.0)
	await process_frame

	var fails := 0
	fails += _want("drawn crowd is capped", g.MAX_RENDER == 110)
	fails += _want("units are reference-scaled", absf(g.UNIT_SCALE - 1.05) < 0.001)
	fails += _want("lane runs to -60", absf(g.END_Z + 60.0) < 0.001)
	fails += _want("camera is low", g.cam.position.y < 4.5)
	fails += _want("camera is shallow", absf(g.cam.rotation_degrees.x) < 20.0)
	print("    cannon.z=%.2f  cam.z=%.2f" % [g.cannon.position.z, g.cam.position.z])
	fails += _want("the launcher is behind the camera", g.cannon.position.z > g.cam.position.z - 1.0)

	var lit := 0
	var texd := 0
	for c in g.get_children():
		if c is MultiMeshInstance3D or c is MeshInstance3D:
			var m = (c as GeometryInstance3D).material_override
			if m is StandardMaterial3D:
				if (m as StandardMaterial3D).emission_enabled:
					lit += 1
				if (m as StandardMaterial3D).albedo_texture != null:
					texd += 1
	fails += _want("surfaces carry real textures", texd >= 3)
	fails += _want("emission floors are set", lit >= 2)

	print("CLAIMS TEST " + ("PASS" if fails == 0 else "FAIL x%d" % fails))
	quit(fails)

func _want(name: String, ok: bool) -> int:
	print("  %s  %s" % ["ok  " if ok else "MISS", name])
	return 0 if ok else 1
