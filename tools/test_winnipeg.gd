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

	# The buried car by the swing lawn must be SOLID: a ray at tire height
	# from the swing's landing spot has to stop at the hull, never pass
	# between or through the wheels.
	var space := player.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(
			Vector3(16.0, 0.65, 9.0), Vector3(18.5, 0.65, 8.0))
	var hit := space.intersect_ray(ray)
	assert(not hit.is_empty(), "tire-height ray must hit the buried car hull")
	assert((hit.position as Vector3).distance_to(Vector3(18.5, 0.65, 8.0)) > 0.6,
			"ray must stop at the car's flank, not reach its center")
	# Hood is a solid ledge you can hop onto.
	var down := PhysicsRayQueryParameters3D.create(
			Vector3(18.5, 3.0, 8.0), Vector3(18.5, 0.0, 8.0))
	var top := space.intersect_ray(down)
	assert(not top.is_empty() and (top.position as Vector3).y > 0.9,
			"car roof/hood should hold weight")
	# The car's interior must be solid VOLUME, not a hollow trimesh shell:
	# a shape probe inside the body has to overlap the hull. (Hollow
	# colliders were how Khione got trapped "inside a tire".)
	var probe := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.15
	probe.shape = sph
	for spot: Vector3 in [
		Vector3(18.5, 0.9, 8.0),                       # dead center of the body
		Vector3(18.5, 0.65, 8.0) + Vector3(0.75, 0, 1.1).rotated(Vector3.UP, 0.9),  # a wheel
		Vector3(10.8, 0.77, 7.6),                      # merry-go-round disc core
		Vector3(3.0, 0.85, 14.0),                      # fire barrel core
		Vector3(17.0, 1.15, 9.5),                      # postal truck body core
		Vector3(17.0, 0.32, 9.5) + Vector3(0.8, 0, 1.2).rotated(Vector3.UP, 0.5),  # truck wheel
	]:
		probe.transform = Transform3D(Basis(), spot)
		assert(space.intersect_shape(probe).size() > 0,
				"prop must be solid at %s" % spot)
	print("prop solidity: OK")

	# The swing's one-pump landing spot must be open snow: nothing for the
	# cat to fall into, stand-up room guaranteed. (She used to land on the
	# postal truck's bumper and drop through a wheel.)
	var lawn: Vector3 = load("res://scripts/puzzles/swing_launch.gd").TIER_TARGETS[0]
	var clear := SphereShape3D.new()
	clear.radius = 0.5
	probe.shape = clear
	probe.transform = Transform3D(Basis(), lawn + Vector3(0, 0.6, 0))
	assert(space.intersect_shape(probe).is_empty(),
			"swing lawn landing must be clear of props (at %s)" % lawn)
	var lawn_ground := PhysicsRayQueryParameters3D.create(
			lawn + Vector3(0, 1.0, 0), lawn + Vector3(0, -1.0, 0))
	assert(not space.intersect_ray(lawn_ground).is_empty(),
			"swing lawn landing must have ground under it")
	print("swing landing clearance: OK")
	print("ALL WINNIPEG SHELL TESTS PASSED")
	get_tree().quit()
