extends Node
## Headless collision-integrity test for Island 1 (Ahalo):
## godot --headless --path . res://tools/test_ahalo.tscn
## The island builds, terrain holds the player, the big set-pieces are solid
## VOLUME (convex, never hollow trimesh shells), the hillside den stays
## enterable, and the raft-departure cinematic corridor is prop-free.

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

	var isl: Node3D = main.get_node("Ahalo")
	assert(isl != null, "ahalo island missing")
	# Terrain sanity: summit tiers, flat south-beach boat channel, sea beyond.
	assert(absf(isl._terrain_height(0.0, 0.0) - 3.3) < 0.05, "summit should be 3.3")
	assert(absf(isl._terrain_height(0.0, 33.0)) < 0.05, "south beach should be flat sand")
	assert(isl._terrain_height(0.0, 55.0) < -1.0, "beyond the coast should be sea")

	# The player lands on the beach and physics holds her there.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	await get_tree().create_timer(1.5).timeout
	assert(player.global_position.y > -0.5, "player should stand on the island, not sink")
	print("terrain + spawn: OK")

	var space := player.get_world_3d().direct_space_state
	# A collider counts as terrain iff it carries a concave (trimesh) shape.
	# After the convex conversion the heightfield is the ONLY concave body.
	var is_terrain := func(collider: Object) -> bool:
		for c in (collider as Node).get_children():
			if c is CollisionShape3D and c.shape is ConcavePolygonShape3D:
				return true
		return false

	# --- prop solidity ---
	# Interior points of the island's set-pieces must overlap a NON-terrain
	# collider: hollow shells pass a surface ray but fail a volume probe.
	var probe := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.15
	probe.shape = sph
	if player is CollisionObject3D:
		probe.exclude = [player.get_rid()]
	var echo: Node3D = isl.get_node("EchoStones")
	var saw: Node3D = isl.get_node("DriftwoodSeesaw")
	var frond: Node3D = isl.get_node("FrondPalm")
	var crab: Node3D = isl.get_node("CrabVines")
	var sundial: Node = isl.get_node("SundialReef")
	var target_rock: Vector3 = sundial.TARGET_ROCK
	var solid_spots: Array = [
		["echo stone (large)", echo.to_global(Vector3(3.4, 0.7, 0.2))],
		["echo carving slab", echo.to_global(Vector3(-0.6, 0.35, -5.6))],
		["gull target rock", target_rock + Vector3(0, 1.5, 0)],
		["sundial pedestal", Vector3(1.8, 3.55, -1.5)],
		["seesaw wedge", saw.to_global(Vector3(0, 0.2, 2.8))],
		["den side rock", saw.to_global(Vector3(-1.05, 0.6, -0.4))],
		["den roof rock", saw.to_global(Vector3(0, 2.0, -0.6))],
		["den back wall", saw.to_global(Vector3(0, 0.85, -1.9))],
		["den gate (closed)", saw.to_global(Vector3(0, 0.75, 0.55))],
		["frond hop boulder", frond.to_global(Vector3(-4.2, 0.6, 1.5))],
		["crab vine rock", crab.to_global(Vector3(0, 0.8, -1.5))],
	]
	for def: Array in solid_spots:
		probe.transform = Transform3D(Basis(), def[1] as Vector3)
		var solid := false
		for hit in space.intersect_shape(probe):
			if not is_terrain.call(hit.collider):
				solid = true
		assert(solid, "%s must be solid volume at %s" % [def[0], def[1]])
	print("prop solidity: OK")

	# --- the den stays enterable ---
	# The convex den rocks must not close over the cavity: Khione has to walk
	# in under the raised gate and reach the Old Oar.
	var room := PhysicsShapeQueryParameters3D.new()
	var rs := SphereShape3D.new()
	rs.radius = 0.28
	room.shape = rs
	if player is CollisionObject3D:
		room.exclude = [player.get_rid()]
	for def: Array in [
		["den doorway", saw.to_global(Vector3(0, 0.55, 0.1))],
		["den interior", saw.to_global(Vector3(0, 0.55, -0.9))],
		["oar alcove", saw.to_global(Vector3(0, 0.55, -1.35))],
	]:
		room.transform = Transform3D(Basis(), def[1] as Vector3)
		for hit in space.intersect_shape(room):
			if not is_terrain.call(hit.collider):
				var blocker := hit.collider as Node3D
				var par := blocker.get_parent() as Node3D
				print("DEN BLOCKER — %s (parent %s, mesh %s) at %s" % [blocker.name,
						par.name if par else "?",
						(par as MeshInstance3D).mesh if par is MeshInstance3D else "?",
						par.global_position if par else blocker.global_position])
				assert(false, "%s must stay open, blocked by %s at %s" %
						[def[0], (hit.collider as Node).name, def[1]])
	print("den enterable: OK")

	# --- cinematic corridors are prop-free ---
	# The raft departure tweens Khione (physics off) from the south-beach
	# berth straight down the boat channel; any solid body inside that
	# corridor would be visibly clipped through. Terrain is exempt (the raft
	# hugs the water line on purpose), and so is the raft itself should it
	# ever carry collision.
	var offenders: Array[String] = []
	var corr := PhysicsShapeQueryParameters3D.new()
	var csph := SphereShape3D.new()
	csph.radius = 0.3
	corr.shape = csph
	if player is CollisionObject3D:
		corr.exclude = [player.get_rid()]
	var is_raft := func(collider: Object) -> bool:
		var n := collider as Node
		while n != null:
			if n.name == "RaftFrame":
				return true
			n = n.get_parent()
		return false
	var sweep := func(pos: Vector3, label: String) -> void:
		corr.transform = Transform3D(Basis(), pos)
		for hit2 in space.intersect_shape(corr):
			var col: Object = hit2.collider
			if not is_terrain.call(col) and not is_raft.call(col):
				offenders.append("%s: %s at %s" % [label, (col as Node).name, pos])
	# The berth: Khione hops onto the beached raft here, and must have
	# stand-up room when physics comes back.
	var beach: Vector3 = sundial.BEACH_POINT
	sweep.call(beach + Vector3(0, 0.75, 0), "berth")
	# The drift path, exactly as raft_departure.gd lerps it (rider at +0.4).
	var dest := Vector3(2.0, beach.y - 0.12, 80.0)
	for k in 61:
		var t: float = k / 60.0
		var rp := beach.lerp(dest, t)
		sweep.call(rp + Vector3(0, 0.4, 0), "departure drift")
	for o in offenders:
		print("CORRIDOR OFFENDER — ", o)
	assert(offenders.is_empty(), "cinematic corridors must be free of props")
	print("cinematic corridors: OK")
	print("ALL AHALO COLLISION TESTS PASSED")
	get_tree().quit()
