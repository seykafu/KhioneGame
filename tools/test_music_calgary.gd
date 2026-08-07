extends Node
## Verifies each built island's music track resolves and actually starts
## playing when travel requests it.
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
	for def in [["res://scenes/islands/calgary.tscn", "calgary", "Prince's Island"],
			["res://scenes/islands/winnipeg.tscn", "winnipeg", "The Winnipeg Crescent"]]:
		main.travel_to(def[0], Vector3(0, 1.2, 42.0), def[1], def[2])
		await get_tree().create_timer(3.0).timeout
		assert(Music._current_track == def[1], "%s should be the current track" % def[1])
		var playing := false
		for deck in [Music._deck_a, Music._deck_b]:
			if deck.playing and deck.stream != null:
				playing = true
		assert(playing, "a deck should be playing the %s stream" % def[1])
		print("%s track resolves and plays: OK" % def[1])
	get_tree().quit()
