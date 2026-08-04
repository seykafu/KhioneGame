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
	for i in 30:
		await get_tree().process_frame
	print("post-intro track: ", Music._current_track)
	main.travel_to("res://scenes/islands/eaton.tscn", Vector3(0, 1.2, 40.0), "eaton", "The Eaton Centre")
	await get_tree().create_timer(4.0).timeout
	print("track: ", Music._current_track)
	print("deckA playing=", Music._deck_a.playing, " vol=", Music._deck_a.volume_db, " stream=", Music._deck_a.stream)
	print("deckB playing=", Music._deck_b.playing, " vol=", Music._deck_b.volume_db, " stream=", Music._deck_b.stream)
	print("music bus vol: ", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), " muted: ", AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	get_tree().quit()
