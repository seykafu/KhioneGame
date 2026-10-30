extends Node
## Headless smoke test for Prince's Island (summer Calgary) shell:
## godot --headless --path . res://tools/test_calgary.tscn
## Travel works, the park builds without errors, the lagoon dips below the
## waterline, the plain holds the player, and the meadow keeps its gate,
## great cottonwood, and memorial stone.

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
	GameState.set_flag("island1_complete")
	GameState.set_flag("island2_complete")
	main.travel_to("res://scenes/islands/calgary.tscn", Vector3(0, 1.2, 42.0), "calgary", "Prince's Island")
	for i in 10:
		await get_tree().process_frame

	var isl: Node3D = main.get_node("Calgary")
	assert(isl != null, "calgary island missing")
	assert(absf(isl._terrain_height(0.0, 10.0) - 0.35) < 0.05, "park lawn should sit at plain height")
	var lagoon_bed: float = isl._terrain_height(-11.0, -1.0)
	assert(lagoon_bed < -0.1, "lagoon hollow should dip below the waterline")
	assert(lagoon_bed > -0.4, "lagoon must stay wading depth: never deep enough to trigger swim mode")
	assert(isl._terrain_height(0.0, 55.0) < -1.0, "south channel should be river")
	assert(isl._terrain_height(27.0, 6.0) > 0.9, "the picnic knoll should rise")
	assert(absf(isl._terrain_height(0.0, -27.0) - 0.35) < 0.05, "the meadow must stay level")
	assert(absf(isl._terrain_height(13.0, 6.5) - 0.35) < 0.05, "the picnic-table lawn must stay level")

	var player: Node3D = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(1.5).timeout
	assert(player.global_position.y > -0.5, "player should stand on the dock, not sink")
	print("terrain + spawn: OK")

	assert(isl.get_node_or_null("MeadowGate") != null, "off-leash gate missing")
	assert(isl.get_node_or_null("MemorialStone") != null, "memorial stone missing")
	print("meadow landmarks: OK")

	# The south fence line must be solid wall-to-gate: no cat-sized gaps
	# beside the gate, and the gate itself blocks until the key opens it.
	var space := player.get_world_3d().direct_space_state
	for x in [1.3, -1.3, 0.0]:
		for y in [0.6, 1.7]:  # walk height AND above her best jump apex (1.41m)
			var ray := PhysicsRayQueryParameters3D.create(
					Vector3(x, y, -21.5), Vector3(x, y, -24.5))
			var hit := space.intersect_ray(ray)
			assert(not hit.is_empty(), "the fence at x=%s y=%s should be solid" % [x, y])
	print("fence seals (low and high): OK")

	# --- prop solidity ---
	# Big set-pieces must be solid VOLUME, not hollow trimesh shells: a
	# sphere probe at each core has to overlap a collider. (Hollow shells
	# were how Khione got trapped inside island 4's props.)
	var probe := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.15
	probe.shape = sph
	for spot: Vector3 in [
		Vector3(3.0, 1.15, 14.0),    # ice cream cart body core
		Vector3(3.7, 0.63, 14.42),   # cart wheel, right
		Vector3(2.3, 0.63, 14.42),   # cart wheel, left
		Vector3(8.0, 0.52, 5.0),     # bandstand platform core
		Vector3(8.0 + 2.3, 1.5, 5.0),  # a bandstand post
		Vector3(1.8, 0.6, -27.6),    # memorial stone core
		Vector3(3.2, 0.6, 38.5),     # the beached canoe's hull (above the beach)
		Vector3(-3.6, 1.7, 17.0),    # entrance sign board
		Vector3(13.0, 1.13, 6.5),    # picnic table top
	]:
		probe.transform = Transform3D(Basis(), spot)
		assert(space.intersect_shape(probe).size() > 0,
				"prop must be solid at %s" % spot)
	# The cart's wheels stop a walk-through at shin height (island 4's
	# postal truck let the cat stroll through a tire).
	var tire := PhysicsRayQueryParameters3D.create(
			Vector3(3.7, 0.55, 15.3), Vector3(3.7, 0.55, 13.6))
	assert(not space.intersect_ray(tire).is_empty(),
			"shin-height ray must stop at the cart wheel")
	print("prop solidity: OK")

	# --- the Peace Bridge tube ---
	# The deck stays a solid walkway (boxes, not paper trimesh)…
	var deck := PhysicsRayQueryParameters3D.create(
			Vector3(-11.0, 3.0, -1.0), Vector3(-11.0, 0.0, -1.0))
	var deck_hit := space.intersect_ray(deck)
	assert(not deck_hit.is_empty() and (deck_hit.position as Vector3).y > 1.0,
			"the bridge deck should hold weight at the arch apex")
	# …and the tube's interior stays PASSABLE: no hoop or rail collider
	# may bulge into the walkway a cat and a dog walk through.
	probe.transform = Transform3D(Basis(), Vector3(-11.0, 1.85, -1.0))
	assert(space.intersect_shape(probe).is_empty(),
			"the bridge tube interior must stay walkable")
	print("peace bridge deck + tube: OK")

	# Jumping ahead must silence earlier islands' objective chains.
	var objective: String = main.get_node("HUD")._current_objective_text()
	assert(objective.find("glass mall") == -1, "the mall hint must not leak onto island 3")
	assert(objective.find("becalmed") != -1, "island 3 should open with the regatta hint")
	print("objective tracker: OK")
	print("ALL CALGARY PARK TESTS PASSED")
	get_tree().quit()
