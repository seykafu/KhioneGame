extends Node
## Headless test for Make the Flock Fly (Island 2 finale):
## godot --headless --path . res://tools/test_finale.tscn
## Verifies every gate in order: crank opens the skylight, clock-at-6 with
## open sky triggers sunset + shadow flock, fused elevator rides to the
## roof, and the banner glide completes the island with fragment 2.

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
	GameState.set_flag("island1_complete")  # as real travel would have set
	main.travel_to("res://scenes/islands/eaton.tscn", Vector3(0, 1.2, 40.0), "eaton", "The Eaton Centre")
	for i in 10:
		await get_tree().process_frame

	var clock: Node = main.get_node("Eaton/MallClock")
	var finale: Node = main.get_node("Eaton/FlockFinale")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	assert(finale != null, "finale missing")
	var space := player.get_world_3d().direct_space_state
	var elev_pos: Vector3 = finale.ELEVATOR_POS
	var cab_top: float = finale.CAB_TOP_Y
	var banner_pos: Vector3 = finale.BANNER_POS
	for i in 3:
		await get_tree().physics_frame

	# --- prop solidity: big set-pieces are solid VOLUME, not hollow shells ---
	# A shape probe INSIDE each body must overlap its collider. (Hollow
	# trimesh shells were how Khione got trapped inside props on island 4.)
	var probe := PhysicsShapeQueryParameters3D.new()
	var psph := SphereShape3D.new()
	psph.radius = 0.15
	probe.shape = psph
	if player is CollisionObject3D:
		probe.exclude = [player.get_rid()]
	for spot: Vector3 in [
		Vector3(0, 0.72, 0),                  # fountain basin core
		Vector3(13.0, 0.86, -13.6),           # food-court counter
		Vector3(-6.5, 0.83, 2.5),             # flower kiosk cart
		Vector3(-9.0, 0.73, -7.0),            # atrium planter
		Vector3(3.2, 1.68, 11.0),             # directory stand
		Vector3(-6.0, 1.5, 8.0),              # wayfinding totem
		Vector3(-22.5, 2.15, 0.0),            # pet shop body
		Vector3(17.25, 2.39, 2.25),           # east escalator, mid-run
		Vector3(18.0, 0.63, 6.5),             # mannequin pedestal
		Vector3(5.2, 2.0, 0.0),               # mall clock pole
		Vector3(6.0, 4.64, -13.5),            # drummer's dais on the balcony
		elev_pos + Vector3(0, 10.56, -1.95),  # roof catwalk
	]:
		probe.transform = Transform3D(Basis(), spot)
		assert(space.intersect_shape(probe).size() > 0,
				"prop must be solid at %s" % spot)
	print("prop solidity: OK")

	# --- cinematic corridors are prop-free ---
	# The elevator ride and the banner glide move the player by tween (or
	# carry her with physics constrained to the cab), so any solid body in
	# those corridors would be visibly clipped through. Terrain (concave
	# collider) is exempt, and so are the cab and its doors: the cab is
	# SUPPOSED to contain the player.
	var offenders: Array[String] = []
	var corr := PhysicsShapeQueryParameters3D.new()
	var csph := SphereShape3D.new()
	csph.radius = 0.3
	corr.shape = csph
	var exempt: Array[RID] = []
	if player is CollisionObject3D:
		exempt.append(player.get_rid())
	exempt.append((finale._cab as CollisionObject3D).get_rid())
	for door: PhysicsBody3D in finale._doors:
		exempt.append(door.get_rid())
	corr.exclude = exempt
	var is_terrain := func(collider: Object) -> bool:
		for c in (collider as Node).get_children():
			if c is CollisionShape3D and c.shape is ConcavePolygonShape3D:
				return true
		return false
	var sweep := func(pos: Vector3, label: String) -> void:
		corr.transform = Transform3D(Basis(), pos)
		for shp: Dictionary in space.intersect_shape(corr):
			var col: Object = shp.collider
			if col is CharacterBody3D:
				continue  # Khione or a companion wandering by
			if not is_terrain.call(col):
				offenders.append("%s: %s at %s" % [label, (col as Node).name, pos])
	# The elevator ride: a vertical column sampled at rider height over the
	# cab's whole travel (the cab is parked at the ground, so the upper
	# column is bare and any stray solid shows up).
	for k in 41:
		var t := k / 40.0
		sweep.call(elev_pos + Vector3(0, cab_top * t + 1.2, 0), "elevator ride")
	# The banner glide, sampled clear of the mount hop (like the swing
	# mounts on island 4): roof edge, out over the plaza, down to the dock.
	var p1: Vector3 = banner_pos + Vector3(0, 0.6, 0.8)
	var p2 := Vector3(0.0, 6.5, 30.0)
	var p3 := Vector3(0.0, 1.05, 38.5)
	for k in 25:
		sweep.call(p1.lerp(p2, k / 24.0), "glide (roof to plaza)")
	for k in range(1, 25):
		sweep.call(p2.lerp(p3, k / 24.0), "glide (plaza to dock)")
	for o in offenders:
		print("CORRIDOR OFFENDER — ", o)
	assert(offenders.is_empty(), "cinematic corridors must be free of props")
	print("cinematic corridors: OK")

	# Crank gate.
	finale.use_crank()
	assert(not GameState.get_flag("skylight_open"), "no crank, no sky")
	Inventory.add_item("skylight_crank")
	finale.use_crank()
	assert(GameState.get_flag("skylight_open"), "crank should open the shutters")
	assert(not Inventory.has_item("skylight_crank"), "crank installed")
	print("skylight opens: OK")

	# Sunset gate: turn the clock to 6.
	while clock.clock_hour != 6:
		clock.advance_clock()
	for i in 5:
		await get_tree().process_frame
	assert(GameState.get_flag("mall_sunset"), "6 o'clock under open sky should lean the light")
	print("sunset + shadow flock: OK")

	# Elevator gate. First: with the doors shut, the doorway must be a wall.
	var ray := PhysicsRayQueryParameters3D.create(
			finale.ELEVATOR_POS + Vector3(0.3, 1.2, -3.4),
			finale.ELEVATOR_POS + Vector3(0.3, 1.2, 0))
	var hit := space.intersect_ray(ray)
	assert(not hit.is_empty() and hit.position.z < finale.ELEVATOR_POS.z - 0.9,
			"closed doors should block the doorway")
	finale.elevator_interact()
	assert(not GameState.get_flag("elevator_powered"), "no fuse, no ride")
	Inventory.add_item("elevator_fuse")
	finale.elevator_interact()
	assert(GameState.get_flag("elevator_powered"), "fuse should wake the elevator")
	# The doors open; the walkway into the cab must be physically clear —
	# the player walks in on her own paws (the old sealed shaft bug).
	await get_tree().create_timer(2.0).timeout
	hit = space.intersect_ray(ray)
	assert(hit.is_empty() or hit.position.z > finale.ELEVATOR_POS.z - 1.05,
			"open doorway should be walk-through")
	print("doorway clearance: OK")
	player.global_position = finale.ELEVATOR_POS + Vector3(0, 1.2, 0)
	await get_tree().create_timer(10.5).timeout
	assert(player.global_position.y > 9.0, "the ride should end on the roof")
	print("elevator ride: OK")

	# The glide.
	finale.start_glide()
	await get_tree().create_timer(20.0).timeout
	assert(GameState.get_flag("letter_fragment_2"), "fragment 2 should be found")
	assert(GameState.get_flag("island2_complete"), "island 2 should complete")
	assert(Inventory.max_slots == 7, "satchel should grow to 7 pockets")
	print("banner glide + completion: OK")

	# The elevator stays in service: call it from the ground, step in, and
	# ride again.
	finale.elevator_interact()
	await get_tree().create_timer(6.0).timeout
	player.global_position = finale.ELEVATOR_POS + Vector3(0, 1.2, 0)
	await get_tree().create_timer(10.5).timeout
	assert(player.global_position.y > 9.0, "elevator should be reusable after the finale")
	print("elevator reusable: OK")
	print("ALL FINALE TESTS PASSED")
	get_tree().quit()
