extends Node3D
## Ahalo's small life: crabs scuttling on the beaches, snails crossing the
## meadow with shimmer trails, fish shadows in the shallows that flee the
## swimmer, palms dropping the odd coconut, and the tide's slow breathing.
## Purely ambient — nothing here gates a riddle.

@onready var _island: Node3D = get_parent()

var _time := 0.0
var _fish: Array[Dictionary] = []

func _ready() -> void:
	_spawn_crabs()
	_spawn_snails()
	_spawn_fish()
	_start_coconut_drops()

func _process(delta: float) -> void:
	_time += delta
	# The tide breathes: the whole sea plane rises and falls a few cm.
	var water: MeshInstance3D = _island.get("_water_mesh")
	if water:
		water.position.y = _island.WATER_SURFACE_Y + sin(_time * 0.21) * 0.07
	_steer_fish(delta)

func _ground(x: float, z: float) -> float:
	return _island._terrain_height(x, z)

# --- Crabs ---------------------------------------------------------------

func _spawn_crabs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	for a: float in [0.35, 2.5, -2.1]:
		var r: float = _island._coast_radius(a) - 5.5
		var home := Vector3(cos(a) * r, 0.0, sin(a) * r)
		home.y = _ground(home.x, home.z) + 0.09
		var crab := Node3D.new()
		var body := MeshInstance3D.new()
		var bmesh := SphereMesh.new()
		bmesh.radius = 0.16
		bmesh.height = 0.18
		body.mesh = bmesh
		body.scale = Vector3(1.25, 0.55, 1.0)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.86, 0.4, 0.3)
		body.material_override = bm
		crab.add_child(body)
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.1, 0.1, 0.1)
		for side: float in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var emesh := SphereMesh.new()
			emesh.radius = 0.025
			emesh.height = 0.05
			eye.mesh = emesh
			eye.material_override = em
			eye.position = Vector3(0.06 * side, 0.13, 0.13)
			crab.add_child(eye)
		crab.position = home
		add_child(crab)
		_crab_wander(crab, home, rng.randi())

func _crab_wander(crab: Node3D, home: Vector3, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var loop := func() -> void:
		while is_instance_valid(crab):
			await get_tree().create_timer(rng.randf_range(0.8, 2.6)).timeout
			if not is_instance_valid(crab):
				return
			var target := home + Vector3(rng.randf_range(-2.6, 2.6), 0, rng.randf_range(-2.6, 2.6))
			target.y = _ground(target.x, target.z) + 0.09
			if target.y < 0.05:
				continue  # not into the surf
			var dir := target - crab.position
			if dir.length() < 0.3:
				continue
			# Crabs face across their line of travel and skitter sideways.
			crab.rotation.y = atan2(dir.x, dir.z) + PI / 2.0
			var tw := crab.create_tween()
			var dur := dir.length() / rng.randf_range(1.4, 2.0)
			tw.tween_property(crab, "position", target, dur) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tw.finished
	loop.call()

# --- Snails --------------------------------------------------------------

func _spawn_snails() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7272
	for home_xz: Vector2 in [Vector2(-5, 18), Vector2(20, 6), Vector2(6, -20)]:
		var snail := Node3D.new()
		var body := MeshInstance3D.new()
		var bmesh := CapsuleMesh.new()
		bmesh.radius = 0.05
		bmesh.height = 0.3
		body.mesh = bmesh
		body.rotation.x = PI / 2.0
		body.position.y = 0.05
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.82, 0.72, 0.55)
		body.material_override = bm
		snail.add_child(body)
		var shell := MeshInstance3D.new()
		var smesh := SphereMesh.new()
		smesh.radius = 0.09
		smesh.height = 0.18
		shell.mesh = smesh
		shell.position = Vector3(0, 0.12, -0.02)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.5, 0.34, 0.22)
		shell.material_override = sm
		snail.add_child(shell)
		snail.position = Vector3(home_xz.x, _ground(home_xz.x, home_xz.y), home_xz.y)
		add_child(snail)
		_snail_wander(snail, home_xz, rng.randi())

func _snail_wander(snail: Node3D, home_xz: Vector2, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var loop := func() -> void:
		while is_instance_valid(snail):
			var target_xz := home_xz + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
			if _island.near_river(target_xz, 2.0):
				continue
			var target := Vector3(target_xz.x, _ground(target_xz.x, target_xz.y), target_xz.y)
			var dist := (target - snail.position).length()
			if dist < 0.5:
				continue
			snail.look_at(target, Vector3.UP)
			var dur := dist / 0.22  # snail's pace
			var trail_timer := 0.0
			var from := snail.position
			var t := 0.0
			while t < dur and is_instance_valid(snail):
				var delta: float = get_process_delta_time()
				t += delta
				trail_timer += delta
				snail.position = from.lerp(target, t / dur)
				if trail_timer > 2.2:
					trail_timer = 0.0
					_drop_trail_dab(snail.position)
				await get_tree().process_frame
			await get_tree().create_timer(rng.randf_range(2.0, 5.0)).timeout
	loop.call()

func _drop_trail_dab(pos: Vector3) -> void:
	var dab := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.13, 0.2)
	dab.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.95, 0.95, 0.32)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.7, 0.9, 0.9)
	m.emission_energy_multiplier = 0.25
	dab.material_override = m
	dab.position = pos + Vector3(0, 0.02, 0)
	add_child(dab)
	var tw := dab.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 14.0)
	tw.tween_callback(dab.queue_free)

# --- Fish shadows --------------------------------------------------------

func _spawn_fish() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8383
	for i in 6:
		var a := rng.randf_range(0.0, TAU)
		var coast: float = _island._coast_radius(a)
		var anchor := Vector2(cos(a), sin(a)) * (coast + 4.0)
		var fish := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.3
		mesh.height = 0.12
		fish.mesh = mesh
		fish.scale = Vector3(1.5, 1.0, 0.55)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.08, 0.2, 0.28, 0.5)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fish.material_override = m
		fish.position = Vector3(anchor.x, _island.WATER_SURFACE_Y - 0.12, anchor.y)
		add_child(fish)
		_fish.append({
			"node": fish, "anchor": anchor,
			"heading": rng.randf_range(0.0, TAU), "speed": rng.randf_range(0.5, 0.9),
			"turn_seed": rng.randf_range(0.0, 10.0),
		})

func _steer_fish(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	for f: Dictionary in _fish:
		var fish: MeshInstance3D = f.node
		var pos2 := Vector2(fish.position.x, fish.position.z)
		var speed: float = f.speed
		if player:
			var p2 := Vector2(player.global_position.x, player.global_position.z)
			if pos2.distance_to(p2) < 3.5 and player.global_position.y < 0.6:
				f.heading = (pos2 - p2).angle()  # dart away from the swimmer
				speed = 4.0
		# Meander, and keep loosely to the home shallows.
		f.heading += sin(_time * 0.7 + (f.turn_seed as float)) * 0.6 * delta
		var anchor: Vector2 = f.anchor
		if pos2.distance_to(anchor) > 6.0:
			var back := (anchor - pos2).angle()
			f.heading = lerp_angle(f.heading, back, 1.5 * delta)
		var vel := Vector2.from_angle(f.heading) * speed
		fish.position += Vector3(vel.x, 0, vel.y) * delta
		fish.position.y = _island.WATER_SURFACE_Y - 0.12
		fish.rotation.y = -(f.heading as float)

# --- Coconut drops -------------------------------------------------------

func _start_coconut_drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9494
	var loop := func() -> void:
		while is_inside_tree():
			await get_tree().create_timer(rng.randf_range(40.0, 75.0)).timeout
			if not is_inside_tree():
				return
			var spots: Array[Vector3] = _island.get("_palm_spots")
			var loose: int = get_tree().get_nodes_in_group("pickup_coconut").size()
			if loose >= 4 or spots.is_empty():
				continue
			var spot := spots[rng.randi_range(0, spots.size() - 1)]
			var land := spot + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
			land.y = _ground(land.x, land.z) + 0.12
			var nut := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.25
			mesh.height = 0.5
			nut.mesh = mesh
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.4, 0.28, 0.16)
			nut.material_override = m
			nut.position = land + Vector3(0, 3.1, 0)
			add_child(nut)
			var tw := nut.create_tween()
			tw.tween_property(nut, "position", land, 0.55).set_trans(Tween.TRANS_QUAD) \
					.set_ease(Tween.EASE_IN)
			tw.tween_property(nut, "position:y", land.y + 0.35, 0.18) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(nut, "position:y", land.y, 0.16) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await tw.finished
			if is_instance_valid(nut):
				nut.queue_free()
			_island._add_pickup(land - Vector3(0, 0.12, 0), "coconut", "Coconut",
					Color(0.4, 0.28, 0.16))
	loop.call()
