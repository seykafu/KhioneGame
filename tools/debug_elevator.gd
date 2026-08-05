extends Node
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
	main.travel_to("res://scenes/islands/eaton.tscn", Vector3(0, 1.2, 40.0), "eaton", "The Eaton Centre")
	for i in 10:
		await get_tree().process_frame
	var finale: Node = main.get_node("Eaton/FlockFinale")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	GameState.set_flag("skylight_open")
	GameState.set_flag("mall_sunset")
	Inventory.add_item("elevator_fuse")
	finale.elevator_interact()
	await get_tree().create_timer(2.0).timeout
	print("doors_open=", finale._doors_open, " cab_y=", finale._cab.position.y)
	player.global_position = finale.ELEVATOR_POS + Vector3(0, 1.2, 0)
	for i in 12:
		await get_tree().create_timer(1.0).timeout
		print("t=", i + 3, " cab_y=%.2f" % finale._cab.position.y,
				" player_y=%.2f" % player.global_position.y,
				" inside=", finale._player_inside, " riding=", finale._riding)
	get_tree().quit()
