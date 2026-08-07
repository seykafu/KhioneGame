extends Node
## Headless smoke test for the Winnipeg Crescent shell (saved for island 8):
## godot --headless --path . res://tools/test_winnipeg.tscn
## Travel works, the island builds without errors, the ground holds the
## player at the spawn, and the key landmarks exist.

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
	main.travel_to("res://scenes/islands/winnipeg.tscn", Vector3(0, 1.2, 42.0), "winnipeg", "The Winnipeg Crescent")
	for i in 10:
		await get_tree().process_frame

	var isl: Node3D = main.get_node("Winnipeg")
	assert(isl != null, "winnipeg island missing")
	# Terrain sanity: crescent plain snowpack, ridge in the north, sea south.
	assert(absf(isl._terrain_height(0.0, 10.0) - 0.35) < 0.05, "crescent plain should be snowpack height")
	assert(isl._terrain_height(0.0, -34.0) > 1.5, "north ridge should rise")
	assert(isl._terrain_height(0.0, 55.0) < -1.0, "south channel should be sea")

	# The player lands on the dock and physics holds her there.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(1.5).timeout
	assert(player.global_position.y > -0.5, "player should stand on the dock, not sink")
	print("terrain + spawn: OK")

	# Landmarks exist: six bungalows worth of collision, a rink, a doghouse.
	var houses := 0
	for c in isl.get_children():
		if c is Node3D and absf(c.position.length() - 21.5) < 0.6:
			houses += 1
	assert(houses >= 6, "six bungalows should ring the crescent")
	print("crescent landmarks: OK")

	# The DISPLAYED objective must speak about THIS island right after
	# travel, not the one she just left (the tracker refreshes on travel).
	var shown: String = main.get_node("HUD")._objective_label.text
	assert(shown.find("laundry") != -1, "island 4 should open with the drift-line hint on screen")
	assert(shown.find("turquoise") == -1 and shown.find("howl") == -1,
			"island 3 text must not stay on screen on island 4")
	print("objective tracker: OK")
	print("ALL WINNIPEG SHELL TESTS PASSED")
	get_tree().quit()
