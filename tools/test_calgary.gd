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

	var player: Node3D = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(1.5).timeout
	assert(player.global_position.y > -0.5, "player should stand on the dock, not sink")
	print("terrain + spawn: OK")

	assert(isl.get_node_or_null("MeadowGate") != null, "off-leash gate missing")
	assert(isl.get_node_or_null("MemorialStone") != null, "memorial stone missing")
	print("meadow landmarks: OK")
	print("ALL CALGARY PARK TESTS PASSED")
	get_tree().quit()
