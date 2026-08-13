extends Node3D
## Island 4 · The Winnipeg Crescent — first snow, and the dig duet.
## A snowed-in crescent of bungalows under a prairie sky: a frozen
## playground, a backyard rink, woodsmoke, magpies, and silver squalls
## rolling through on a clock. Riddles (The Drift Line, Backyard Rink,
## Mailbox Morse, Swing Set Launch, main: The Longest Slide) land in
## later passes; this is the living shell.

const WATER_SURFACE_Y := -0.4
const COAST_BASE := 46.0
const ROAD_R := 16.0
const HOUSE_R := 21.5

## The toboggan run's spine, ridge to shore. The slide puzzle builds its
## gates on this; tree scatter keeps the corridor clear.
const RUN_PATH: Array[Vector2] = [
	Vector2(-12, -35), Vector2(-12, -32.5), Vector2(-14, -27), Vector2(-15, -21),
	Vector2(-14, -14), Vector2(-13, -6), Vector2(-11.5, 3), Vector2(-9, 12),
	Vector2(-6, 20), Vector2(-3, 28), Vector2(-1.5, 34), Vector2(-1, 37),
]

const SNOW := Color(0.93, 0.95, 0.99)
const WOOD := Color(0.52, 0.4, 0.3)
const TRIM := Color(0.9, 0.88, 0.84)
const STEEL := Color(0.45, 0.47, 0.52)
const WARM_WINDOW := Color(1.0, 0.85, 0.55)

## House palette around the crescent; index 3 is Number Eight, Oreo's.
const HOUSE_COLORS := [
	Color(0.62, 0.5, 0.42), Color(0.5, 0.56, 0.62), Color(0.66, 0.6, 0.48),
	Color(0.58, 0.44, 0.38), Color(0.52, 0.6, 0.52), Color(0.6, 0.52, 0.6),
]
const HOUSE_ANGLES := [2.62, 3.32, 4.01, 4.71, 5.41, 6.11]

var _materials := {}
var _visited_locations := {}
var _sun_tween: Tween
var _squall_on := false

func _ready() -> void:
	_build_island()
	_build_water()
	_build_crescent()
	_build_playground()
	_build_rink()
	_build_dock()
	_build_yard_eight()
	_scatter_winterings()
	_build_snowfall()
	_spawn_magpies()
	_build_prairie_wind()
	_add_ambient_loop("res://assets/audio/winter_wind.wav", Vector3(0, 4.0, -10), -8.0, 60.0)
	_add_location_trigger(Vector3(0, 0, 10), 9.0, "The Crescent")
	_add_location_trigger(Vector3(10, 0, 4), 6.0, "The Frozen Playground")
	_add_location_trigger(Vector3(-10, 0, 2), 6.0, "The Backyard Rink")
	_add_location_trigger(Vector3(0, 0, -25), 7.0, "Number Eight")
	_add_location_trigger(Vector3(-13, 1.0, -27), 7.0, "The Top of the Run")
	_add_location_trigger(Vector3(38, 0, -28), 9.0, "The Fishing Shacks")
	_blue_hour()
	_build_aurora()
	_build_skyline()
	_build_frozen_bay()
	_build_string_lights()
	_build_buried_cars()
	_build_rink_gear()
	_spawn_jackrabbit()
	_train_horn_loop()
	for def: Array in [
		["DriftLine", "res://scripts/puzzles/drift_line.gd"],
		["RinkMaze", "res://scripts/puzzles/rink_maze.gd"],
		["MailboxMorse", "res://scripts/puzzles/mailbox_morse.gd"],
		["SwingLaunch", "res://scripts/puzzles/swing_launch.gd"],
		["LongestSlide", "res://scripts/puzzles/longest_slide.gd"],
	]:
		var puzzle := Node3D.new()
		puzzle.name = def[0]
		puzzle.set_script(load(def[1]))
		add_child(puzzle)

## Winnipeg lives at blue hour: low cold sun, deep twilight sky, and every
## warm window and string light earning its keep. travel_to resets both
## sun and sky between islands, so the grade stays local.
func _blue_hour() -> void:
	var mgr := get_tree().get_first_node_in_group("island_manager")
	if mgr == null:
		return
	var sun: DirectionalLight3D = mgr.get_node_or_null("Sun")
	if sun:
		sun.light_color = Color(0.8, 0.86, 1.05)
		sun.light_energy = 0.95
		sun.rotation_degrees = Vector3(-22.0, 55.0, 0.0)
	var env_node: Node = mgr.get_node_or_null("WorldEnvironment")
	if env_node:
		var sky_mat := (env_node.environment as Environment).sky.sky_material as ProceduralSkyMaterial
		if sky_mat:
			sky_mat.sky_top_color = Color(0.12, 0.16, 0.32)
			sky_mat.sky_horizon_color = Color(0.58, 0.46, 0.55)
			sky_mat.ground_horizon_color = Color(0.44, 0.4, 0.5)
			sky_mat.ground_bottom_color = Color(0.16, 0.17, 0.26)
			sky_mat.sky_cover_modulate = Color(0.55, 0.55, 0.7, 0.35)

func _build_aurora() -> void:
	# Three overlapping curtains over the northern sky, drifting slowly.
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 512
	tex.height = 128
	for def: Array in [
		[Vector3(-40, 52, -200), 250.0, 55.0, 0.15, 0.022, 0.65],
		[Vector3(50, 60, -215), 210.0, 48.0, -0.2, 0.016, 0.5],
		[Vector3(-100, 46, -175), 160.0, 40.0, 0.45, 0.028, 0.4],
	]:
		var curtain := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(def[1], def[2])
		curtain.mesh = quad
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/aurora.gdshader")
		m.set_shader_parameter("band_noise", tex)
		m.set_shader_parameter("speed", def[4])
		m.set_shader_parameter("strength", def[5])
		curtain.material_override = m
		curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		curtain.position = def[0]
		var to_center: Vector3 = -(def[0] as Vector3)
		curtain.rotation.y = atan2(to_center.x, to_center.z) + (def[3] as float) * 0.3
		add_child(curtain)

func _build_skyline() -> void:
	# Downtown across the frozen river: modest towers, the Museum for Human
	# Rights with its lit spire, and the Legislature's dome with a small
	# golden someone on top.
	var base := Vector3(150.0, 0.0, 130.0)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.35, 0.42, 0.55)
	glass.emission_enabled = true
	glass.emission = Color(0.95, 0.85, 0.6)
	glass.emission_energy_multiplier = 0.35
	for def: Array in [
		[Vector3(-20, 0, 6), Vector3(7, 24, 7)], [Vector3(-8, 0, -4), Vector3(8, 30, 8)],
		[Vector3(6, 0, 4), Vector3(6, 20, 6)], [Vector3(18, 0, -6), Vector3(7, 26, 7)],
		[Vector3(32, 0, 4), Vector3(6, 16, 6)], [Vector3(-34, 0, 2), Vector3(5, 14, 5)],
	]:
		var t := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = def[1]
		t.mesh = box
		t.material_override = glass
		t.position = base + (def[0] as Vector3) + Vector3(0, (def[1] as Vector3).y / 2.0 - 1.0, 0)
		add_child(t)
	# The museum: a mound of tilted glass planes and the Tower of Hope.
	var cmhr_base := base + Vector3(46, 0, 14)
	for k in 4:
		var pane := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(10.0 - k * 1.6, 7.0 + k * 2.4, 6.0 - k * 0.8)
		pane.mesh = pb
		pane.material_override = glass
		pane.position = cmhr_base + Vector3(k * 1.1, pb.size.y / 2.0 - 1.0, -k * 0.6)
		pane.rotation.y = 0.3 + k * 0.22
		add_child(pane)
	var spire := MeshInstance3D.new()
	spire.mesh = _cyl(0.35, 0.8, 14.0)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.85, 0.9, 0.95)
	sm.emission_enabled = true
	sm.emission = Color(0.9, 0.95, 1.0)
	sm.emission_energy_multiplier = 0.9
	spire.material_override = sm
	spire.position = cmhr_base + Vector3(3.5, 20.0, -1.5)
	add_child(spire)
	# The Legislature: colonnade block, dome, Golden Boy.
	var leg_base := base + Vector3(-52, 0, 12)
	_add_box(Vector3(12, 7, 8), leg_base + Vector3(0, 2.5, 0), Color(0.55, 0.52, 0.48), false)
	_add_mesh(_cyl(2.6, 3.2, 4.0), leg_base + Vector3(0, 8.0, 0), Color(0.45, 0.5, 0.45), false)
	var dome := MeshInstance3D.new()
	var ds := SphereMesh.new()
	ds.radius = 2.6
	ds.height = 3.4
	dome.mesh = ds
	dome.material_override = _mat(Color(0.35, 0.5, 0.45))
	dome.position = leg_base + Vector3(0, 10.8, 0)
	add_child(dome)
	var boy := MeshInstance3D.new()
	var bs := CapsuleMesh.new()
	bs.radius = 0.35
	bs.height = 1.6
	boy.mesh = bs
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.85, 0.35)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.8, 0.3)
	gold.emission_energy_multiplier = 1.2
	boy.material_override = gold
	boy.position = leg_base + Vector3(0, 13.3, 0)
	add_child(boy)

func _build_frozen_bay() -> void:
	# The north-east bay froze solid: walkable ice sheets off the shore,
	# ice-fishing shacks, augered holes, and tip-up flags.
	var rng := RandomNumberGenerator.new()
	rng.seed = 204
	for def: Array in [
		[Vector3(36, 0, -30), 10.0], [Vector3(44, 0, -18), 9.0], [Vector3(30, 0, -38), 7.5],
	]:
		var sheet := MeshInstance3D.new()
		sheet.mesh = _cyl(def[1], def[1], 0.25)
		var im := StandardMaterial3D.new()
		im.albedo_color = Color(0.82, 0.89, 0.95)
		im.roughness = 0.12
		im.metallic = 0.05
		sheet.material_override = im
		sheet.position = (def[0] as Vector3) + Vector3(0, -0.28, 0)
		add_child(sheet)
		sheet.create_trimesh_collision()
	for def: Array in [
		[Vector3(36, -0.16, -30), Color(0.75, 0.35, 0.3), 0.4],
		[Vector3(43, -0.16, -20), Color(0.35, 0.55, 0.65), -0.3],
		[Vector3(31, -0.16, -36), Color(0.7, 0.6, 0.3), 1.1],
	]:
		var shack := Node3D.new()
		shack.position = def[0]
		shack.rotation.y = def[2]
		add_child(shack)
		var body := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(1.6, 1.7, 1.9)
		body.mesh = bb
		body.material_override = _mat(def[1])
		body.position = Vector3(0, 0.85, 0)
		shack.add_child(body)
		body.create_trimesh_collision()
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(1.8, 0.6, 2.1)
		roof.mesh = prism
		roof.material_override = _mat((def[1] as Color).darkened(0.35))
		roof.position = Vector3(0, 2.0, 0)
		shack.add_child(roof)
		var cap := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(1.85, 0.1, 1.1)
		cap.mesh = cb
		cap.material_override = _mat(SNOW)
		cap.position = Vector3(0, 2.28, 0.5)
		cap.rotation.x = -0.5
		shack.add_child(cap)
		var pipe := MeshInstance3D.new()
		pipe.mesh = _cyl(0.07, 0.07, 0.7)
		pipe.material_override = _mat(Color(0.25, 0.25, 0.28))
		pipe.position = Vector3(0.5, 2.4, -0.4)
		shack.add_child(pipe)
		var window := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(0.5, 0.4, 0.06)
		window.mesh = wb
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(1.0, 0.85, 0.55)
		wm.emission_enabled = true
		wm.emission = Color(1.0, 0.8, 0.5)
		wm.emission_energy_multiplier = 1.0
		window.material_override = wm
		window.position = Vector3(0, 1.1, 0.98)
		shack.add_child(window)
	# Augered holes and tip-up flags on the open ice.
	for i in 5:
		var p := Vector3(rng.randf_range(28.0, 46.0), -0.14, rng.randf_range(-38.0, -18.0))
		var hole := _add_mesh(_cyl(0.22, 0.22, 0.04), p, Color(0.1, 0.16, 0.24), false)
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i % 2 == 0:
			_add_mesh(_cyl(0.02, 0.02, 0.8), p + Vector3(0.3, 0.4, 0), Color(0.7, 0.65, 0.55), false)
			_add_box(Vector3(0.03, 0.12, 0.2), p + Vector3(0.3, 0.85, 0.1), Color(0.9, 0.3, 0.25), false)

func _build_string_lights() -> void:
	# Holiday strings sag between the crescent houses and ring the rink.
	var bulb_colors := [Color(1.0, 0.4, 0.35), Color(0.4, 0.85, 0.5), Color(1.0, 0.8, 0.4),
			Color(0.45, 0.6, 1.0), Color(0.9, 0.5, 0.9)]
	for i in HOUSE_ANGLES.size() - 1:
		var a1: float = HOUSE_ANGLES[i]
		var a2: float = HOUSE_ANGLES[i + 1]
		var p1 := Vector3(cos(a1) * HOUSE_R, 0, sin(a1) * HOUSE_R)
		var p2 := Vector3(cos(a2) * HOUSE_R, 0, sin(a2) * HOUSE_R)
		p1.y = _terrain_height(p1.x, p1.z) + 3.1
		p2.y = _terrain_height(p2.x, p2.z) + 3.1
		_light_string(p1, p2, bulb_colors)
	# Around the rink: two poles and a double run.
	var pole_a := Vector3(-13.8, 0.35, -0.9)
	var pole_b := Vector3(-6.2, 0.35, 4.9)
	for pole: Vector3 in [pole_a, pole_b]:
		_add_mesh(_cyl(0.05, 0.07, 2.6), pole + Vector3(0, 1.3, 0), Color(0.35, 0.3, 0.26))
	_light_string(pole_a + Vector3(0, 2.5, 0), pole_b + Vector3(0, 2.5, 0), bulb_colors)

func _light_string(from: Vector3, to: Vector3, bulb_colors: Array) -> void:
	var segments := 10
	var prev := from
	for k in range(1, segments + 1):
		var t := k / float(segments)
		var p := from.lerp(to, t)
		p.y -= sin(t * PI) * 0.55  # the sag
		var cable := MeshInstance3D.new()
		cable.mesh = _cyl(0.012, 0.012, prev.distance_to(p))
		cable.material_override = _mat(Color(0.2, 0.2, 0.22))
		cable.position = (prev + p) / 2.0
		var dir := (p - prev).normalized()
		var axis := Vector3.UP.cross(dir)
		if axis.length() > 0.001:
			cable.rotate(axis.normalized(), Vector3.UP.angle_to(dir))
		add_child(cable)
		if k < segments:
			var bulb := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.05
			bs.height = 0.1
			bulb.mesh = bs
			var color: Color = bulb_colors[k % bulb_colors.size()]
			var bm := StandardMaterial3D.new()
			bm.albedo_color = color
			bm.emission_enabled = true
			bm.emission = color
			bm.emission_energy_multiplier = 1.6
			bulb.material_override = bm
			bulb.position = p + Vector3(0, -0.06, 0)
			add_child(bulb)
		prev = p

func _build_buried_cars() -> void:
	# Cars that have not moved since November, wearing thick snow duvets.
	for def: Array in [
		[Vector3(18.5, 0.35, 8.0), 0.9, Color(0.45, 0.3, 0.3)],
		[Vector3(-19.0, 0.35, 9.5), -0.7, Color(0.3, 0.4, 0.5)],
	]:
		var car := Node3D.new()
		car.position = def[0]
		car.rotation.y = def[1]
		add_child(car)
		var body := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(1.7, 0.55, 3.4)
		body.mesh = bb
		body.material_override = _mat(def[2])
		body.position = Vector3(0, 0.55, 0)
		car.add_child(body)
		# Solid convex colliders (never hollow trimesh): one block from the
		# ground to the snow duvet covering body AND wheels, one for the
		# cabin. Nothing walks through a tire, nothing gets trapped inside,
		# and the hood stays a hoppable ledge.
		var hull := StaticBody3D.new()
		car.add_child(hull)
		for shape_def: Array in [
			[Vector3(1.75, 1.06, 3.45), Vector3(0, 0.53, 0)],
			[Vector3(1.55, 0.42, 1.75), Vector3(0, 1.27, -0.2)],
		]:
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = shape_def[0]
			cs.shape = box
			cs.position = shape_def[1]
			hull.add_child(cs)
		var cabin := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(1.5, 0.5, 1.7)
		cabin.mesh = cb
		cabin.material_override = _mat((def[2] as Color).darkened(0.25))
		cabin.position = Vector3(0, 1.05, -0.2)
		car.add_child(cabin)
		var duvet := MeshInstance3D.new()
		var dsz := BoxMesh.new()
		dsz.size = Vector3(1.75, 0.22, 3.45)
		duvet.mesh = dsz
		duvet.material_override = _mat(SNOW)
		duvet.position = Vector3(0, 0.95, 0)
		car.add_child(duvet)
		var cabin_snow := MeshInstance3D.new()
		var csz := BoxMesh.new()
		csz.size = Vector3(1.55, 0.18, 1.75)
		cabin_snow.mesh = csz
		cabin_snow.material_override = _mat(SNOW)
		cabin_snow.position = Vector3(0, 1.38, -0.2)
		car.add_child(cabin_snow)
		for s: Array in [[-0.75, 1.1], [0.75, 1.1], [-0.75, -1.1], [0.75, -1.1]]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = _cyl(0.3, 0.3, 0.2)
			wheel.material_override = _mat(Color(0.15, 0.15, 0.17))
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(s[0], 0.3, s[1])
			car.add_child(wheel)

func _build_rink_gear() -> void:
	# Hockey nets at both ends, sticks against the boards.
	for def: Array in [[Vector3(-13.0, 0.4, 2.0), PI / 2.0], [Vector3(-7.0, 0.4, 2.0), -PI / 2.0]]:
		var net := Node3D.new()
		net.position = def[0]
		net.rotation.y = def[1]
		add_child(net)
		var frame_col := Color(0.8, 0.25, 0.2)
		for part: Array in [
			[Vector3(0.06, 0.75, 0.06), Vector3(-0.6, 0.37, 0)],
			[Vector3(0.06, 0.75, 0.06), Vector3(0.6, 0.37, 0)],
			[Vector3(1.26, 0.06, 0.06), Vector3(0, 0.75, 0)],
		]:
			var bar := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = part[0]
			bar.mesh = bb
			bar.material_override = _mat(frame_col)
			bar.position = part[1]
			net.add_child(bar)
		var mesh_panel := MeshInstance3D.new()
		var mb := BoxMesh.new()
		mb.size = Vector3(1.2, 0.7, 0.5)
		mesh_panel.mesh = mb
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.9, 0.9, 0.9, 0.25)
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_panel.material_override = mm
		mesh_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_panel.position = Vector3(0, 0.37, -0.25)
		net.add_child(mesh_panel)
	for i in 2:
		var stick := _add_box(Vector3(0.05, 1.3, 0.05), Vector3(-6.4, 0.9, 4.0 + i * 0.3), Color(0.6, 0.48, 0.32), false)
		stick.rotation.z = 0.4
		var blade := _add_box(Vector3(0.05, 0.3, 0.12), Vector3(-6.15, 0.35, 4.0 + i * 0.3), Color(0.6, 0.48, 0.32), false)
		blade.rotation.z = 1.2

func _spawn_jackrabbit() -> void:
	# A white prairie hare: nibbles, notices, and is somewhere else.
	var rabbit := Node3D.new()
	var body := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.16
	bs.height = 0.28
	body.mesh = bs
	body.scale = Vector3(1.0, 1.0, 1.5)
	body.material_override = _mat(Color(0.96, 0.96, 0.98))
	body.position.y = 0.16
	rabbit.add_child(body)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.09
	hs.height = 0.16
	head.mesh = hs
	head.material_override = _mat(Color(0.96, 0.96, 0.98))
	head.position = Vector3(0, 0.3, 0.2)
	rabbit.add_child(head)
	for s in [-0.04, 0.04]:
		var ear := MeshInstance3D.new()
		var es := CapsuleMesh.new()
		es.radius = 0.025
		es.height = 0.2
		ear.mesh = es
		ear.material_override = _mat(Color(0.9, 0.88, 0.9))
		ear.position = Vector3(s, 0.46, 0.17)
		ear.rotation.x = -0.15
		rabbit.add_child(ear)
	rabbit.position = Vector3(24.0, 0.35, 18.0)
	add_child(rabbit)
	_rabbit_brain(rabbit)

func _rabbit_brain(rabbit: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var loop := func() -> void:
		while is_inside_tree():
			await get_tree().create_timer(0.35).timeout
			if not is_inside_tree() or not is_instance_valid(rabbit):
				return
			var player: Node3D = get_tree().get_first_node_in_group("player")
			if player and player.global_position.distance_to(rabbit.global_position) < 5.0:
				# Three bounds to somewhere safer, then back to nibbling.
				var away := (rabbit.global_position - player.global_position).normalized()
				away.y = 0
				var t := rabbit.create_tween()
				for hop in 3:
					var to := rabbit.position + away.rotated(Vector3.UP, rng.randf_range(-0.5, 0.5)) \
							* rng.randf_range(2.2, 3.2)
					to.x = clampf(to.x, -34.0, 34.0)
					to.z = clampf(to.z, -34.0, 34.0)
					to.y = _terrain_height(to.x, to.z)
					var mid := (rabbit.position + to) / 2.0 + Vector3(0, 0.8, 0)
					t.tween_property(rabbit, "position", mid, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					t.tween_property(rabbit, "position", to, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				await t.finished
				await get_tree().create_timer(1.5).timeout
	loop.call()

func _train_horn_loop() -> void:
	# Somewhere south, a freight crosses the night. Winnipeg keeps time by it.
	var horn := AudioStreamPlayer3D.new()
	horn.stream = load("res://assets/audio/train_horn.wav")
	horn.position = Vector3(30, 3.0, 90)
	horn.volume_db = -8.0
	horn.max_distance = 220.0
	horn.bus = "SFX"
	add_child(horn)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var loop := func() -> void:
		while is_inside_tree():
			await get_tree().create_timer(rng.randf_range(95.0, 170.0)).timeout
			if not is_inside_tree():
				return
			horn.pitch_scale = rng.randf_range(0.94, 1.02)
			horn.play()
	loop.call()

func _near_run(p: Vector2) -> bool:
	for i in RUN_PATH.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, RUN_PATH[i], RUN_PATH[i + 1])
		if p.distance_to(q) < 2.4:
			return true
	return false

func is_squalling() -> bool:
	return _squall_on

## Test hook: pin the weather.
func force_squall(on: bool) -> void:
	_squall_on = on
	GameState.set_flag("prairie_gust", on)

func _add_pickup(pos: Vector3, id: String, disp: String, color: Color) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/interaction/item_pickup.gd"))
	a.set("item_id", id)
	a.set("display_name", disp)
	a.position = pos
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.2
	cs.shape = sph
	a.add_child(cs)
	a.add_to_group("pickup_" + id)
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = Vector3(0, 0.25, 0)
	a.add_child(mi)
	add_child(a)

# --- terrain & water ---

func _coast_radius(theta: float) -> float:
	# Same harmonic family as the water shader's coast_offset, on a wider base.
	var wob := 2.6 * sin(3.0 * theta + 1.7) + 1.7 * sin(5.0 * theta + 4.2) \
			+ 1.1 * sin(8.0 * theta + 0.9)
	var d := absf(wrapf(theta - PI / 2.0, -PI, PI))
	wob *= smoothstep(0.55, 1.1, d)
	return COAST_BASE + wob

func _terrain_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var theta := atan2(z, x)
	var coast := _coast_radius(theta)
	if d >= coast:
		return -6.0 * clampf((d - coast) / 12.0, 0.0, 1.0)
	# A flat snowpack plain, with a foothill ridge rising along the north rim.
	var h := 0.35 * (1.0 - smoothstep(coast - 4.0, coast - 1.5, d))
	var rim := smoothstep(coast * 0.52, coast * 0.82, d)
	var northness := smoothstep(-14.0, -30.0, z)
	h += 2.6 * rim * northness
	return h

func _build_island() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 150
	var span := 124.0
	var step := span / (n - 1)
	var heights := []
	for iz in n:
		var row := PackedFloat32Array()
		for ix in n:
			row.append(_terrain_height(-span / 2.0 + ix * step, -span / 2.0 + iz * step))
		heights.append(row)
	for iz in n - 1:
		for ix in n - 1:
			var x0 := -span / 2.0 + ix * step
			var z0 := -span / 2.0 + iz * step
			var p00 := Vector3(x0, heights[iz][ix], z0)
			var p10 := Vector3(x0 + step, heights[iz][ix + 1], z0)
			var p01 := Vector3(x0, heights[iz + 1][ix], z0 + step)
			var p11 := Vector3(x0 + step, heights[iz + 1][ix + 1], z0 + step)
			for p: Vector3 in [p00, p10, p11, p00, p11, p01]:
				st.set_uv(Vector2(p.x, p.z) * 0.05)
				st.add_vertex(p)
	st.generate_normals()
	st.generate_tangents()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/snow_island.gdshader")
	sm.set_shader_parameter("noise_tex", _noise_tex(21, 0.06))
	sm.set_shader_parameter("detail_normal", _noise_tex(211, 0.15, true))
	sm.set_shader_parameter("base_radius", COAST_BASE)
	sm.set_shader_parameter("road_radius", ROAD_R)
	terrain.material_override = sm
	add_child(terrain)
	terrain.create_trimesh_collision()

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	sm.set_shader_parameter("wave_normal1", _noise_tex(71, 0.08, true))
	sm.set_shader_parameter("wave_normal2", _noise_tex(72, 0.13, true))
	sm.set_shader_parameter("shore_radius", COAST_BASE)
	sm.set_shader_parameter("coast_wobble", 1.0)
	sm.set_shader_parameter("shallow_color", Color(0.52, 0.72, 0.78))
	sm.set_shader_parameter("deep_color", Color(0.06, 0.18, 0.32))
	sm.set_shader_parameter("wave_height", 0.06)
	mi.material_override = sm
	mi.position = Vector3(0, WATER_SURFACE_Y, 0)
	add_child(mi)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 30, 600)
	cs.shape = box
	area.add_child(cs)
	area.position = Vector3(0, WATER_SURFACE_Y - 15.0, 0)
	area.body_entered.connect(_on_water_entered)
	area.body_exited.connect(_on_water_exited)
	add_child(area)
	# Ice floes drifting off the cold shores (never in the south channel).
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	for i in 8:
		var a := rng.randf_range(PI * 0.75, PI * 2.25)
		var r := _coast_radius(a) + rng.randf_range(4.0, 14.0)
		var floe := MeshInstance3D.new()
		floe.mesh = _cyl(rng.randf_range(1.2, 2.6), rng.randf_range(1.4, 2.8), 0.22)
		floe.material_override = _mat(Color(0.92, 0.95, 0.98))
		floe.position = Vector3(cos(a) * r, WATER_SURFACE_Y + 0.06, sin(a) * r)
		add_child(floe)
		var bob := floe.create_tween().set_loops()
		bob.tween_property(floe, "position:y", WATER_SURFACE_Y + 0.12, rng.randf_range(2.6, 4.0)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(floe, "position:y", WATER_SURFACE_Y + 0.02, rng.randf_range(2.6, 4.0)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_water_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.enter_water(WATER_SURFACE_Y)

func _on_water_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.exit_water()

# --- the crescent ---

func _build_crescent() -> void:
	for i in HOUSE_ANGLES.size():
		var a: float = HOUSE_ANGLES[i]
		var pos := Vector3(cos(a) * HOUSE_R, 0.35, sin(a) * HOUSE_R)
		var facing := atan2(-pos.x, -pos.z)  # face the crescent's heart
		_bungalow(pos, facing, HOUSE_COLORS[i], i == 3, i % 2 == 0)
	# Picket fence runs between the houses along the road's outer edge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for k in 40:
		var a := lerpf(2.35, 6.45, k / 39.0)
		var gap := false
		for ha: float in HOUSE_ANGLES:
			if absf(angle_difference(a, ha)) < 0.17:
				gap = true
		if gap:
			continue
		var p := Vector3(cos(a) * 18.9, 0.35, sin(a) * 18.9)
		var post := _add_box(Vector3(0.09, 0.75, 0.09), p + Vector3(0, 0.37, 0), TRIM, false)
		post.rotation.y = -a
		var rail := _add_box(Vector3(0.06, 0.1, 1.9), p + Vector3(0, 0.55, 0), TRIM, false)
		rail.rotation.y = -a + PI / 2.0
	# Street lamps along the road, warm halos in the snow-light.
	for a: float in [2.8, 3.7, 4.7, 5.7]:
		var p := Vector3(cos(a) * 14.2, 0.35, sin(a) * 14.2)
		_add_mesh(_cyl(0.06, 0.09, 3.0), p + Vector3(0, 1.5, 0), Color(0.2, 0.24, 0.2))
		var head := MeshInstance3D.new()
		head.mesh = _cyl(0.22, 0.3, 0.24)
		var hm := StandardMaterial3D.new()
		hm.albedo_color = WARM_WINDOW
		hm.emission_enabled = true
		hm.emission = Color(1.0, 0.88, 0.6)
		hm.emission_energy_multiplier = 1.6
		head.material_override = hm
		head.position = p + Vector3(0, 3.05, 0)
		add_child(head)

func _bungalow(pos: Vector3, facing: float, color: Color, is_eight: bool, smokes: bool) -> void:
	var house := Node3D.new()
	house.position = pos
	house.rotation.y = facing
	add_child(house)
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(5.6, 2.5, 4.2)
	body.mesh = bb
	body.material_override = _mat(color)
	body.position = Vector3(0, 1.25, 0)
	house.add_child(body)
	body.create_trimesh_collision()
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(6.2, 1.5, 4.8)
	roof.mesh = prism
	roof.material_override = _mat(color.darkened(0.35))
	roof.position = Vector3(0, 3.25, 0)
	house.add_child(roof)
	roof.create_trimesh_collision()
	# Snow load on both roof slopes.
	for s in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(6.3, 0.14, 2.6)
		cap.mesh = cb
		cap.material_override = _mat(SNOW)
		cap.position = Vector3(0, 3.62, s * 1.18)
		cap.rotation.x = -s * 0.55
		house.add_child(cap)
	var door := _door_color(color)
	var door_mesh := MeshInstance3D.new()
	var db := BoxMesh.new()
	db.size = Vector3(0.9, 1.7, 0.12)
	door_mesh.mesh = db
	door_mesh.material_override = _mat(door)
	door_mesh.position = Vector3(-1.4, 0.85, 2.14)
	house.add_child(door_mesh)
	for wx in [0.6, 1.9]:
		var win := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(0.9, 0.75, 0.1)
		win.mesh = wb
		var wm := StandardMaterial3D.new()
		wm.albedo_color = WARM_WINDOW
		wm.emission_enabled = true
		wm.emission = Color(1.0, 0.82, 0.5)
		wm.emission_energy_multiplier = 1.1
		win.material_override = wm
		win.position = Vector3(wx, 1.35, 2.14)
		house.add_child(win)
	var chimney := MeshInstance3D.new()
	var cb2 := BoxMesh.new()
	cb2.size = Vector3(0.55, 1.6, 0.55)
	chimney.mesh = cb2
	chimney.material_override = _mat(Color(0.48, 0.36, 0.32))
	chimney.position = Vector3(1.8, 3.6, -0.8)
	house.add_child(chimney)
	if smokes:
		var smoke := CPUParticles3D.new()
		smoke.amount = 22
		smoke.lifetime = 5.0
		smoke.preprocess = 5.0
		smoke.direction = Vector3(0, 1, 0)
		smoke.spread = 8.0
		smoke.gravity = Vector3(0.25, 0.5, 0)
		smoke.initial_velocity_min = 0.5
		smoke.initial_velocity_max = 0.9
		smoke.scale_amount_min = 0.7
		smoke.scale_amount_max = 1.6
		var puff := SphereMesh.new()
		puff.radius = 0.16
		puff.height = 0.32
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.85, 0.85, 0.88, 0.4)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material = pm
		smoke.mesh = puff
		smoke.position = Vector3(1.8, 4.5, -0.8)
		house.add_child(smoke)
	# Curb plaque; Number Eight's is unmistakably loved.
	var plaque := _add_box(Vector3(0.5, 0.35, 0.08),
			pos + Vector3(cos(facing + PI) * -2.6, 0.55, sin(facing + PI) * -2.6).rotated(Vector3.UP, 0.0),
			Color(0.9, 0.88, 0.8) if not is_eight else Color(0.85, 0.3, 0.3), false)
	plaque.rotation.y = facing
	plaque.position = pos + Vector3(0, 0.55, 0) + Vector3(sin(facing), 0, cos(facing)) * 3.4

func _door_color(base: Color) -> Color:
	return Color(base.g, base.b, base.r).lightened(0.1)

# --- the frozen playground ---

func _build_playground() -> void:
	var origin := Vector3(10, 0.35, 4)
	# Slide: ladder, platform, and the long tongue.
	_add_box(Vector3(0.12, 2.0, 0.12), origin + Vector3(-1.2, 1.0, -1.0), STEEL)
	_add_box(Vector3(0.12, 2.0, 0.12), origin + Vector3(-0.6, 1.0, -1.0), STEEL)
	for r in 5:
		_add_box(Vector3(0.7, 0.06, 0.12), origin + Vector3(-0.9, 0.35 + r * 0.38, -1.0), STEEL, false)
	_add_box(Vector3(1.0, 0.12, 1.0), origin + Vector3(-0.9, 2.0, -0.4), STEEL)
	var tongue := _add_box(Vector3(0.9, 0.1, 3.2), origin + Vector3(-0.9, 1.25, 1.15), Color(0.75, 0.3, 0.28))
	tongue.rotation.x = -0.45
	# Swing set: two A-frames, crossbar, two seats.
	for sx in [-1.6, 1.6]:
		for lean in [-0.35, 0.35]:
			var leg := _add_box(Vector3(0.1, 2.6, 0.1), origin + Vector3(3.0 + sx, 1.2, lean * 1.6), STEEL)
			leg.rotation.x = lean
	_add_box(Vector3(3.6, 0.1, 0.1), origin + Vector3(3.0, 2.45, 0), STEEL)
	for sx in [-0.8, 0.8]:
		for cz in [-0.18, 0.18]:
			_add_box(Vector3(0.03, 1.6, 0.03), origin + Vector3(3.0 + sx, 1.6, cz), Color(0.35, 0.35, 0.38), false)
		_add_box(Vector3(0.5, 0.06, 0.24), origin + Vector3(3.0 + sx, 0.8, 0), Color(0.2, 0.2, 0.24))
	# Merry-go-round: disc, hub, four handles, a dusting of snow.
	var disc := _add_mesh(_cyl(1.5, 1.5, 0.14), origin + Vector3(0.8, 0.42, 3.6), Color(0.3, 0.5, 0.62))
	_add_mesh(_cyl(0.08, 0.1, 0.9), origin + Vector3(0.8, 0.9, 3.6), STEEL)
	for k in 4:
		var ha := TAU * k / 4.0
		_add_box(Vector3(0.06, 0.5, 0.06),
				origin + Vector3(0.8 + cos(ha) * 1.2, 0.75, 3.6 + sin(ha) * 1.2), STEEL, false)
	_add_mesh(_cyl(1.1, 1.3, 0.05), origin + Vector3(0.8, 0.52, 3.6), SNOW, false)
	var _keep := disc  # future riddle: the merry-go-round rotates

# --- the backyard rink ---

func _build_rink() -> void:
	var origin := Vector3(-10, 0.35, 2)
	var ice := MeshInstance3D.new()
	var ib := BoxMesh.new()
	ib.size = Vector3(7.0, 0.08, 5.0)
	ice.mesh = ib
	var im := StandardMaterial3D.new()
	im.albedo_color = Color(0.75, 0.86, 0.94)
	im.roughness = 0.06
	im.metallic = 0.1
	ice.material_override = im
	ice.position = origin + Vector3(0, 0.05, 0)
	add_child(ice)
	ice.create_trimesh_collision()
	for def: Array in [
		[Vector3(7.4, 0.5, 0.15), Vector3(0, 0.3, 2.55)], [Vector3(7.4, 0.5, 0.15), Vector3(0, 0.3, -2.55)],
		[Vector3(0.15, 0.5, 5.2), Vector3(3.65, 0.3, 0)], [Vector3(0.15, 0.5, 5.2), Vector3(-3.65, 0.3, 0)],
	]:
		_add_box(def[0], origin + (def[1] as Vector3), TRIM)
	# A shovel leaning on the boards, and last week's snowman keeping score.
	var handle := _add_box(Vector3(0.06, 1.4, 0.06), origin + Vector3(3.8, 0.9, 1.4), WOOD, false)
	handle.rotation.z = 0.4
	_add_box(Vector3(0.34, 0.3, 0.04), origin + Vector3(4.08, 0.28, 1.4), STEEL, false)
	_snowman(origin + Vector3(-4.6, 0, -1.6))

# --- dock, yard eight, winter dressing ---

func _build_dock() -> void:
	for i in 6:
		_add_box(Vector3(2.4, 0.15, 1.7), Vector3(0, 0.28 - i * 0.012, 40.0 + i * 1.8), Color(0.5, 0.42, 0.34))
	for side in [-1.0, 1.0]:
		for i in 3:
			_add_mesh(_cyl(0.12, 0.14, 1.6), Vector3(side * 1.1, -0.15, 41.0 + i * 4.0), Color(0.4, 0.33, 0.27))
	# The canoe that brought them, hauled up on the snow.
	var canoe := MeshInstance3D.new()
	var cb := CapsuleMesh.new()
	cb.radius = 0.55
	cb.height = 3.6
	canoe.mesh = cb
	canoe.material_override = _mat(Color(0.65, 0.3, 0.25))
	canoe.position = Vector3(3.2, 0.35, 38.5)
	canoe.rotation.z = PI / 2.0
	canoe.rotation.y = 0.4
	canoe.scale = Vector3(1.0, 1.0, 0.55)
	add_child(canoe)
	# Fire barrel by the path head: the island's warm heart.
	var barrel := _add_mesh(_cyl(0.42, 0.4, 1.0), Vector3(3.0, 0.85, 14.0), Color(0.25, 0.22, 0.24))
	var ember := MeshInstance3D.new()
	ember.mesh = _cyl(0.34, 0.34, 0.1)
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(1.0, 0.55, 0.2)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.45, 0.12)
	em.emission_energy_multiplier = 2.2
	ember.material_override = em
	ember.position = Vector3(3.0, 1.32, 14.0)
	add_child(ember)
	var fire := CPUParticles3D.new()
	fire.amount = 26
	fire.lifetime = 1.1
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 12.0
	fire.gravity = Vector3(0, 1.6, 0)
	fire.initial_velocity_min = 0.5
	fire.initial_velocity_max = 1.1
	fire.scale_amount_min = 0.4
	fire.scale_amount_max = 1.0
	var flame := SphereMesh.new()
	flame.radius = 0.09
	flame.height = 0.18
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.6, 0.2, 0.8)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material = fm
	fire.mesh = flame
	fire.position = Vector3(3.0, 1.45, 14.0)
	add_child(fire)
	var _keep := barrel

func _build_yard_eight() -> void:
	# Oreo's backyard, behind the north bungalow: fenced, gated, snowed-in.
	var fence_col := Color(0.62, 0.55, 0.46)
	for def: Array in [
		[Vector3(12.0, 0.9, 0.12), Vector3(0, 0.8, -32.0)],
		[Vector3(0.12, 0.9, 8.0), Vector3(-6.0, 0.8, -28.0)],
		[Vector3(0.12, 0.9, 8.0), Vector3(6.0, 0.8, -28.0)],
		[Vector3(4.6, 0.9, 0.12), Vector3(-3.6, 0.8, -24.0)],
		[Vector3(4.6, 0.9, 0.12), Vector3(3.6, 0.8, -24.0)],
	]:
		_add_box(def[0], def[1] as Vector3, fence_col)
	# The frozen gate (the Chimney Choir will one day shake it loose).
	var gate := _add_box(Vector3(2.5, 0.85, 0.1), Vector3(0, 0.78, -24.0), fence_col.darkened(0.15))
	var icicles := MeshInstance3D.new()
	icicles.mesh = _cyl(0.03, 0.09, 0.4)
	icicles.material_override = _mat(Color(0.8, 0.9, 0.98))
	icicles.position = Vector3(0.5, 0.35, -24.0)
	add_child(icicles)
	var _keep := gate
	# The yard's only tree: big, bare, patient.
	_bare_tree(Vector3(0, 0.7, -28.5), 3.4)
	# The doghouse, kid-built and kid-painted, half under a snowdrift.
	var dh := Node3D.new()
	dh.position = Vector3(2.4, 0.7, -29.5)
	dh.rotation.y = 0.5
	add_child(dh)
	var dbody := MeshInstance3D.new()
	var dbb := BoxMesh.new()
	dbb.size = Vector3(1.5, 1.0, 1.7)
	dbody.mesh = dbb
	dbody.material_override = _mat(Color(0.58, 0.46, 0.36))
	dbody.position = Vector3(0, 0.5, 0)
	dh.add_child(dbody)
	dbody.create_trimesh_collision()
	var droof := MeshInstance3D.new()
	var dprism := PrismMesh.new()
	dprism.size = Vector3(1.7, 0.6, 1.9)
	droof.mesh = dprism
	droof.material_override = _mat(Color(0.4, 0.3, 0.26))
	droof.position = Vector3(0, 1.3, 0)
	dh.add_child(droof)
	# The kid-painted mountain skyline band.
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.52, 0.28, 0.03)
	band.mesh = bb
	band.material_override = _mat(Color(0.45, 0.6, 0.75))
	band.position = Vector3(0, 0.72, 0.86)
	dh.add_child(band)
	var doorway := MeshInstance3D.new()
	doorway.mesh = _cyl(0.32, 0.32, 0.06)
	doorway.material_override = _mat(Color(0.12, 0.1, 0.1))
	doorway.rotation.x = PI / 2.0
	doorway.position = Vector3(0, 0.45, 0.86)
	dh.add_child(doorway)
	# Snowdrift over its back half.
	var drift := MeshInstance3D.new()
	var ds := SphereMesh.new()
	ds.radius = 1.3
	ds.height = 1.2
	drift.mesh = ds
	drift.material_override = _mat(SNOW)
	drift.position = Vector3(2.4, 0.55, -30.3)
	drift.scale = Vector3(1.2, 0.6, 1.0)
	add_child(drift)

func _scatter_winterings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	# Conifers with snow shoulders, thicker toward the north ridge.
	for i in 34:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(24.0, 40.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if p.z > 12.0 and absf(p.x) < 8.0:
			continue  # keep the dock path open
		if p.z < -20.0 and absf(p.x) < 8.0 and p.z > -33.0:
			continue  # keep yard eight clear
		if _near_run(Vector2(p.x, p.z)):
			continue  # the toboggan corridor stays clear
		var h := _terrain_height(p.x, p.z)
		if h < 0.25:
			continue
		_conifer(Vector3(p.x, h, p.z), rng.randf_range(0.8, 1.7))
	for i in 8:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(20.0, 30.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := _terrain_height(p.x, p.z)
		if h < 0.25:
			continue
		_bare_tree(Vector3(p.x, h, p.z), rng.randf_range(1.6, 2.6))
	# Snowbanks where the plow pushed, and a couple of neighbourly snowmen.
	for i in 14:
		var a := rng.randf_range(2.35, 6.45)
		var r := ROAD_R + (2.2 if i % 2 == 0 else -2.2)
		var bank := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = rng.randf_range(0.8, 1.5)
		bs.height = rng.randf_range(0.7, 1.0)
		bank.mesh = bs
		bank.material_override = _mat(SNOW)
		bank.position = Vector3(cos(a) * r, 0.32, sin(a) * r)
		bank.scale = Vector3(rng.randf_range(1.0, 1.9), 0.55, 1.0)
		bank.rotation.y = -a
		add_child(bank)
	_snowman(Vector3(5.5, 0.35, 9.0))
	_snowman(Vector3(-14.5, 0.35, 8.5))

func _conifer(pos: Vector3, s: float) -> void:
	var trunk := _add_mesh(_cyl(0.1 * s, 0.14 * s, 0.8 * s), pos + Vector3(0, 0.4 * s, 0), Color(0.35, 0.26, 0.2))
	for tier in 3:
		var cone := MeshInstance3D.new()
		cone.mesh = _cyl(0.02, (1.15 - tier * 0.28) * s, 1.0 * s)
		cone.material_override = _mat(Color(0.2, 0.36, 0.28))
		cone.position = pos + Vector3(0, (0.9 + tier * 0.62) * s, 0)
		add_child(cone)
	var cap := MeshInstance3D.new()
	cap.mesh = _cyl(0.02, 0.5 * s, 0.5 * s)
	cap.material_override = _mat(SNOW)
	cap.position = pos + Vector3(0, 2.45 * s, 0)
	add_child(cap)
	var _keep := trunk

func _bare_tree(pos: Vector3, s: float) -> void:
	_add_mesh(_cyl(0.09 * s, 0.16 * s, 1.6 * s), pos + Vector3(0, 0.8 * s, 0), Color(0.42, 0.36, 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 17.0 + pos.z * 31.0)
	for i in 5:
		var branch := MeshInstance3D.new()
		branch.mesh = _cyl(0.02 * s, 0.05 * s, 1.1 * s)
		branch.material_override = _mat(Color(0.42, 0.36, 0.3))
		branch.position = pos + Vector3(0, (1.35 + 0.22 * i) * s, 0)
		branch.rotation.z = rng.randf_range(0.5, 1.1) * (1 if i % 2 == 0 else -1)
		branch.rotation.y = rng.randf_range(0.0, TAU)
		add_child(branch)

func _snowman(pos: Vector3) -> void:
	for def: Array in [[0.55, 0.35], [1.12, 0.26], [1.52, 0.17]]:
		var ball := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = def[1]
		bs.height = def[1] * 2.0
		ball.mesh = bs
		ball.material_override = _mat(SNOW)
		ball.position = pos + Vector3(0, def[0], 0)
		add_child(ball)
	var nose := MeshInstance3D.new()
	nose.mesh = _cyl(0.01, 0.05, 0.22)
	nose.material_override = _mat(Color(0.9, 0.5, 0.15))
	nose.position = pos + Vector3(0, 1.52, 0.2)
	nose.rotation.x = PI / 2.0
	add_child(nose)
	for s in [-0.06, 0.06]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.025
		es.height = 0.05
		eye.mesh = es
		eye.material_override = _mat(Color(0.1, 0.1, 0.1))
		eye.position = pos + Vector3(s, 1.6, 0.15)
		add_child(eye)

# --- sky: snowfall, magpies, the prairie wind ---

func _build_snowfall() -> void:
	var snow := CPUParticles3D.new()
	snow.amount = 650
	snow.lifetime = 9.0
	snow.preprocess = 9.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(52.0, 1.0, 52.0)
	snow.position = Vector3(0, 11.0, 0)
	snow.direction = Vector3(0, -1, 0)
	snow.spread = 6.0
	snow.gravity = Vector3(0.3, -1.1, 0.1)
	snow.initial_velocity_min = 0.4
	snow.initial_velocity_max = 0.9
	var flake := QuadMesh.new()
	flake.size = Vector2(0.06, 0.06)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.97, 0.98, 1.0, 0.85)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake.material = fm
	snow.mesh = flake
	add_child(snow)

func _spawn_magpies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in 4:
		var bird := Node3D.new()
		var body := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.09
		bs.height = 0.14
		body.mesh = bs
		body.scale = Vector3(1.0, 1.0, 2.2)
		body.material_override = _mat(Color(0.08, 0.08, 0.1))
		bird.add_child(body)
		for s in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			var wb := QuadMesh.new()
			wb.size = Vector2(0.22, 0.12)
			wing.mesh = wb
			wing.material_override = _mat(Color(0.92, 0.93, 0.95))
			wing.position = Vector3(0.13 * s, 0.02, 0)
			wing.rotation.x = -PI / 2.0
			bird.add_child(wing)
		var tail := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.05, 0.02, 0.28)
		tail.mesh = tb
		tail.material_override = _mat(Color(0.15, 0.25, 0.3))
		tail.position = Vector3(0, 0, -0.25)
		bird.add_child(tail)
		var r := rng.randf_range(12.0, 22.0)
		var a := rng.randf_range(0.0, TAU)
		var home := Vector3(cos(a) * r, rng.randf_range(1.2, 2.4), sin(a) * r)
		bird.position = home
		add_child(bird)
		var path := bird.create_tween().set_loops()
		for k in 4:
			var wp := home + Vector3(rng.randf_range(-5.0, 5.0),
					rng.randf_range(-0.6, 1.0), rng.randf_range(-5.0, 5.0))
			path.tween_property(bird, "position", wp, rng.randf_range(2.5, 4.0)) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		path.tween_property(bird, "position", home, 3.0).set_trans(Tween.TRANS_SINE)

func _build_prairie_wind() -> void:
	# A storm shelf hangs over the western ridge; every minute or so a hard
	# prairie squall rolls through and the light goes cold silver.
	for i in 9:
		var a := PI * 0.72 + i * 0.09
		var shelf := _add_box(Vector3(34.0, 5.0, 10.0),
				Vector3(cos(a) * 230.0, 30.0 + sin(i * 1.7) * 2.0, sin(a) * 230.0),
				Color(0.82, 0.8, 0.84), false)
		shelf.rotation.y = -a
	var timer := Timer.new()
	timer.wait_time = 75.0
	timer.autostart = true
	timer.timeout.connect(_prairie_squall)
	add_child(timer)

func _prairie_squall() -> void:
	# Eight silver seconds: the light goes cold, the wind leans hard.
	if _squall_on or not is_inside_tree():
		return
	_squall_on = true
	GameState.set_flag("prairie_gust")
	var mgr := get_tree().get_first_node_in_group("island_manager")
	var sun: DirectionalLight3D = mgr.get_node_or_null("Sun") if mgr else null
	if sun:
		if _sun_tween and _sun_tween.is_valid():
			_sun_tween.kill()
		_sun_tween = create_tween()
		_sun_tween.tween_property(sun, "light_color", Color(0.82, 0.9, 1.1), 2.5)
		_sun_tween.tween_interval(6.0)
		# Back to the island's blue-hour grade, not daylight.
		_sun_tween.tween_property(sun, "light_color", Color(0.72, 0.8, 1.0), 3.0)
	var hud := get_node_or_null("../HUD")
	if hud and not _visited_locations.has("_squall_seen"):
		_visited_locations["_squall_seen"] = true
		hud.flash_message("The prairie wind leans hard off the ridge, and every icicle keens.", 4.5)
	var reset := create_tween()
	reset.tween_interval(12.0)
	reset.tween_callback(func() -> void:
		_squall_on = false
		GameState.set_flag("prairie_gust", false))

# --- shared helpers ---

func _add_ambient_loop(path: String, pos: Vector3, volume_db: float, max_dist: float) -> void:
	var stream: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.position = pos
	player.volume_db = volume_db
	player.max_distance = max_dist
	player.bus = "SFX"
	player.autoplay = true
	add_child(player)

func _add_location_trigger(pos: Vector3, radius: float, title: String) -> void:
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	cs.shape = sph
	area.add_child(cs)
	area.position = pos
	area.set_meta("title", title)
	area.body_entered.connect(_on_location_entered.bind(area))
	add_child(area)

func _on_location_entered(body: Node3D, area: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	var title: String = area.get_meta("title")
	if _visited_locations.has(title):
		return
	_visited_locations[title] = true
	var hud := get_node_or_null("../HUD")
	if hud:
		hud.show_location(title)

func _noise_tex(seed_v: int, freq: float, as_normal := false) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = freq
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.as_normal_map = as_normal
	tex.width = 256
	tex.height = 256
	return tex

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[color] = m
	return _materials[color]

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	if with_collision:
		mi.create_trimesh_collision()
	return mi

func _add_box(size: Vector3, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _add_mesh(box, pos, color, with_collision)
