extends Node
## Headless shell test for Island 5 · The Pirate Ship:
## godot --headless --path . res://tools/test_pirate.tscn
## Terrain contract, spawn, landmarks, prop solidity, objective tracker,
## and the departure cinematic's corridor (swept AFTER the stones sink,
## exactly as the finale orders it).

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 5:
		await get_tree().process_frame
	main.get_node("IntroSequence").debug_fast_start()
	for i in 20:
		await get_tree().process_frame
	for f: String in ["island1_complete", "island2_complete", "island3_complete",
			"island4_complete", "oreo_joined"]:
		GameState.set_flag(f)
	main.travel_to("res://scenes/islands/pirate.tscn", Vector3(0, 1.2, 42.0), "pirate", "The Pirate Ship")
	for i in 10:
		await get_tree().process_frame

	var isl: Node3D = main.get_node("Pirate")
	assert(isl != null, "pirate island missing")
	# Terrain contract: shore plain, cove and drydock below the water,
	# golf shelf terrace, sea past the coast.
	assert(absf(isl._terrain_height(0.0, 5.0) - 0.35) < 0.15, "shore plain height")
	assert(isl._terrain_height(isl.COVE_CENTER.x, isl.COVE_CENTER.y) < isl.WATER_SURFACE_Y - 0.4,
			"cove pocket must be under water")
	assert(isl._terrain_height(isl.DOCK_CENTER.x, isl.DOCK_CENTER.y) < isl.WATER_SURFACE_Y - 0.4,
			"drydock basin must be under water level")
	assert(isl._terrain_height(27.0, 16.0) > 0.55, "golf shelf terrace")
	assert(isl._terrain_height(0.0, 60.0) < -1.0, "open Atlantic south")

	var player: Node3D = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(1.5).timeout
	assert(player.global_position.y > -0.5, "player should stand on the wharf, not sink")
	print("terrain + spawn: OK")

	# Landmarks: the ship with her masts, nest, capstan, helm, cannons.
	assert(isl.ship != null and isl.crow_nest != null, "Santa Maria incomplete")
	assert(isl.capstan != null and isl.helm != null, "capstan/helm missing")
	var cannons := 0
	for c in (isl.ship as Node3D).get_children():
		if String(c.name).begins_with("Cannon"):
			cannons += 1
	assert(cannons == 9, "nine cannons expected, found %d" % cannons)
	assert(isl.get_node_or_null("Boathouse") != null, "boathouse missing")
	assert(isl.get_node_or_null("CaveGrate") != null, "sea cave grate missing")
	print("landmarks: OK")

	# The objective tracker speaks about THIS island right after travel.
	var shown: String = main.get_node("HUD")._objective_label.text
	assert(shown.find("parrot") != -1, "island 5 should open with the parrot hint")
	assert(shown.find("laundry") == -1 and shown.find("turquoise") == -1,
			"older islands' text must not leak onto island 5")
	print("objective tracker: OK")

	# Prop solidity: big set-pieces are solid volume, never hollow.
	var space := player.get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.15
	probe.shape = sph
	for spot: Vector3 in [
		(isl.ship as Node3D).to_global(Vector3(0, 0.3, 0)),    # hull heart
		(isl.ship as Node3D).to_global(Vector3(0, 2.7, -4.6)), # stern castle mass
		Vector3(-26.0, isl._terrain_height(-26.0, 4.0) + 1.2, 4.0),  # a saltbox
		Vector3(0.0, 0.42, 33.2),                              # wharf deck plank
	]:
		probe.transform = Transform3D(Basis(), spot)
		assert(space.intersect_shape(probe).size() > 0, "prop must be solid at %s" % spot)
	print("prop solidity: OK")

	# Corridor sweep: submerge the stones (as the finale does), then the
	# departure route must be clean at hull and deck heights.
	var wave_clock: Node = isl.get_node("WaveClock")
	wave_clock.submerge_stones()
	await get_tree().create_timer(1.5).timeout
	var offenders: Array[String] = []
	var corr := PhysicsShapeQueryParameters3D.new()
	var csph := SphereShape3D.new()
	csph.radius = 0.3
	corr.shape = csph
	if player is CollisionObject3D:
		corr.exclude = [player.get_rid()]
	var is_terrain := func(collider: Object) -> bool:
		for c in (collider as Node).get_children():
			if c is CollisionShape3D and c.shape is ConcavePolygonShape3D:
				return true
		return false
	var on_ship := func(collider: Object) -> bool:
		var n: Node = collider as Node
		while n != null:
			if n == isl.ship:
				return true
			n = n.get_parent()
		return false
	var route: Array = load("res://scripts/puzzles/float_santa_maria.gd").SAIL_ROUTE
	for i in route.size() - 1:
		for k in 6:
			var t := k / 6.0
			var pos := (route[i] as Vector3).lerp(route[i + 1], t)
			for dy: float in [0.6, 2.2]:   # hull flank and rider height
				corr.transform = Transform3D(Basis(), pos + Vector3(0, dy, 0))
				for hit in space.intersect_shape(corr):
					var col: Object = hit.collider
					if not is_terrain.call(col) and not on_ship.call(col):
						offenders.append("%s at %s" % [(col as Node).name, corr.transform.origin])
	for o in offenders:
		print("CORRIDOR OFFENDER — ", o)
	assert(offenders.is_empty(), "departure corridor must be free of props")
	print("cinematic corridors: OK")
	print("ALL PIRATE SHELL TESTS PASSED")
	get_tree().quit()
