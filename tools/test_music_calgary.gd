extends Node
## Verifies the calgary track resolves and actually starts playing when
## the island travel requests it.
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
	main.travel_to("res://scenes/islands/calgary.tscn", Vector3(0, 1.2, 42.0), "calgary", "Prince's Island")
	await get_tree().create_timer(3.0).timeout
	assert(Music._current_track == "calgary", "calgary should be the current track")
	var playing := false
	for deck in [Music._deck_a, Music._deck_b]:
		if deck.playing and deck.stream != null:
			playing = true
	assert(playing, "a deck should be playing the calgary stream")
	print("calgary track resolves and plays: OK")
	get_tree().quit()
