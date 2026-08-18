extends Node
## Headless shell test for Island 5 · Montréal:
## godot --headless --path . res://tools/test_montreal.tscn
## Terrace contract, spawn, landmarks, objective tracker, prop solidity,
## staircase geometry (aligned flights climb; wrong ones point away),
## and the funicular's corridor.

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
	main.travel_to("res://scenes/islands/montreal.tscn", Vector3(0, 1.2, 42.0), "montreal", "Montréal")
	for i in 10:
		await get_tree().process_frame

	var isl: Node3D = main.get_node("Montreal")
	assert(isl != null, "montreal island missing")
	# The terrace contract, exactly as the header promises.
	assert(absf(isl._terrain_height(0.0, 10.0) - 0.35) < 0.15, "plain height")
	assert(absf(isl.mountain_height(0.0, -12.0) - 4.0) < 0.05, "T1 = 4")
	assert(absf(isl.mountain_height(0.0, -21.0) - 8.0) < 0.05, "T2 = 8")
	assert(absf(isl.mountain_height(0.0, -29.5) - 12.0) < 0.05, "T3 = 12")
	assert(absf(isl.mountain_height(0.0, -38.0) - 15.0) < 0.05, "summit = 15")
	# Risers are steep (unwalkable): 4 m over 3 m.
	var rise: float = isl.mountain_height(0.0, -6.5) - isl.mountain_height(0.0, -4.5)
	assert(rise > 2.5, "riser must be steep, got %.2f over 2 m" % rise)
	# Flanks fall away, so the mountain cannot be walked around and up.
	assert(isl.mountain_height(20.0, -21.0) < 0.5, "flank falls to the plain")
	assert(isl._terrain_height(0.0, 60.0) < -1.0, "the river south")

	var player: Node3D = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(1.5).timeout
	assert(player.global_position.y > -0.5, "player should stand on the dock, not sink")
	print("terrain + spawn: OK")

	assert(isl.cross != null and isl.chalet != null and isl.arena != null, "landmarks missing")
	assert(isl.funicular_car != null, "funicular car missing")
	var lanterns := 0
	for c in (isl.cross as Node3D).get_children():
		if String(c.name).begins_with("Lantern"):
			lanterns += 1
	assert(lanterns == 12, "twelve lantern bases (à la douzaine), found %d" % lanterns)
	assert(isl.get_node_or_null("StaircaseShuffle/Flight1") != null, "flights missing")
	assert(isl.get_node_or_null("CalecheHorse/Horse") != null, "horse missing")
	print("landmarks: OK")

	var shown: String = main.get_node("HUD")._objective_label.text
	assert(shown.find("horse") != -1, "island 5 should open with the horse hint")
	assert(shown.find("laundry") == -1 and shown.find("turquoise") == -1,
			"older islands' text must not leak onto island 5")
	print("objective tracker: OK")

	# Prop solidity: the big set-pieces are solid volume.
	var space := player.get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.15
	probe.shape = sph
	var arena: Node3D = isl.arena
	for spot: Vector3 in [
		arena.to_global(Vector3(-7.0, 3.0, 0.0)),            # west arena wall
		(isl.chalet as Node3D).to_global(Vector3(0, 1.8, -2.5)),  # chalet mass
		(isl.cross as Node3D).to_global(Vector3(0, 5.0, 0)),      # the post
		Vector3(-14.0, 0.35 + 1.5, 4.0 - 2.6),               # bagel shop
		isl.HORSE_POS + Vector3(0, 1.1, 0.0),                # the horse's hull
		Vector3(-17.5, 1.5, -3.0),                           # the mountain-foot wall
	]:
		probe.transform = Transform3D(Basis(), spot)
		assert(space.intersect_shape(probe).size() > 0, "prop must be solid at %s" % spot)
	# The arena is a walk-in: its centre is open air.
	probe.transform = Transform3D(Basis(), arena.to_global(Vector3(2.0, 1.2, 2.0)))
	assert(space.intersect_shape(probe).is_empty(), "arena interior must be enterable")
	print("prop solidity: OK")

	# Staircase geometry: aligned flight 1 has solid tread climbing north;
	# wrong flight 2 points away from its terrace.
	var stairs: Node = isl.get_node("StaircaseShuffle")
	assert(stairs.flight_aligned(0) and not stairs.flight_aligned(1), "flights 2 and 4 start wrong")
	var f1: Array = isl.FLIGHTS[0]
	var mid := Vector3((f1[0] as Vector2).x, ((f1[2] as float) + (f1[3] as float)) / 2.0 + 0.4,
			((f1[0] as Vector2).y + (f1[1] as Vector2).y) / 2.0)
	var down := PhysicsRayQueryParameters3D.create(mid + Vector3(0, 1.0, 0), mid + Vector3(0, -1.5, 0))
	var hit := space.intersect_ray(down)
	assert(not hit.is_empty() and (hit.position as Vector3).y > (f1[2] as float) + 0.5,
			"flight 1 tread must hold weight mid-way up")
	stairs.force_fix()
	await get_tree().process_frame
	assert(stairs.flight_aligned(1) and stairs.flight_aligned(3), "force_fix aligns all")
	print("staircases: OK")

	# The funicular corridor: the car carries riders down the west flank
	# through nothing but air (terrain and the car itself exempt).
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
	var on_car := func(collider: Object) -> bool:
		var n: Node = collider as Node
		while n != null:
			if n == isl.funicular_car:
				return true
			n = n.get_parent()
		return false
	var route: Array = isl.FUNICULAR_ROUTE
	for i in route.size() - 1:
		for k in 8:
			var t := k / 8.0
			var pos := (route[i] as Vector3).lerp(route[i + 1], t)
			for dy: float in [0.6, 1.4]:
				corr.transform = Transform3D(Basis(), pos + Vector3(0, dy, 0))
				for h2 in space.intersect_shape(corr):
					var col: Object = h2.collider
					if not is_terrain.call(col) and not on_car.call(col):
						offenders.append("%s at %s" % [(col as Node).name, corr.transform.origin])
	for o in offenders:
		print("CORRIDOR OFFENDER — ", o)
	assert(offenders.is_empty(), "funicular corridor must be free of props")
	# And the rail must clear the ground everywhere it runs.
	for i in route.size() - 1:
		for k in 8:
			var pos := (route[i] as Vector3).lerp(route[i + 1], k / 8.0)
			var g: float = isl._terrain_height(pos.x, pos.z)
			assert(pos.y >= g - 0.05, "funicular rail dips under the ground at %s (ground %.2f)" % [pos, g])
	print("cinematic corridors: OK")
	print("ALL MONTREAL SHELL TESTS PASSED")
	get_tree().quit()
