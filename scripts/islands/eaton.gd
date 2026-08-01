extends Node3D
## Island 2 — The Eaton Centre. A silent glass shopping mall grown out of a
## sandy island: two-storey atrium, escalators, fountain, storefronts, a
## frozen flock of geese under the skylight, a dark glass elevator, and one
## very territorial cleaning robot (the hiss teacher). Riddles land next.

const SAND := Color(0.9, 0.86, 0.72)
const CONCRETE := Color(0.78, 0.77, 0.74)
const FRAME := Color(0.35, 0.37, 0.4)
const GLASS := Color(0.7, 0.85, 0.92, 0.22)
const GOOSE_WHITE := Color(0.95, 0.95, 0.92)
const WATER_SURFACE_Y := -0.4

const MALL_W := 26.0   # x span
const MALL_D := 18.0   # z span
const BALCONY_Y := 4.0
const ROOF_Y := 9.0

var _materials := {}
var _visited_locations := {}
var _robot: Node3D
var _robot_tween: Tween
var _confronted := false
var _robot_home := Vector3(-11.0, 0.5, -6.5)
const PATROL := [Vector3(6, 0.5, -4), Vector3(-6, 0.5, -4), Vector3(-6, 0.5, 4), Vector3(6, 0.5, 4)]

func _ready() -> void:
	_build_island()
	_build_water()
	_build_mall()
	_build_fountain()
	_build_shops()
	_build_geese()
	_build_elevator()
	_build_dock()
	_build_robot()
	_add_location_trigger(Vector3(0, 0, 0), 8.0, "The Atrium")
	_add_location_trigger(Vector3(-11.5, 0, 2.5), 5.0, "The Pet Shop")
	GameState.vocal_used.connect(_on_vocal)

# --- terrain & water ---

func _build_island() -> void:
	_add_mesh(_cylinder(32.0, 44.0, 6.0), Vector3(0, -3.0, 0), SAND)
	_add_mesh(_cylinder(22.0, 24.0, 0.3), Vector3(0, 0.15, 0), CONCRETE)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	sm.set_shader_parameter("wave_normal1", _noise_tex(61, 0.08, true))
	sm.set_shader_parameter("wave_normal2", _noise_tex(62, 0.13, true))
	sm.set_shader_parameter("shore_radius", 33.0)
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

func _on_water_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.enter_water(WATER_SURFACE_Y)

func _on_water_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.exit_water()

# --- the mall shell ---

func _build_mall() -> void:
	var hw := MALL_W / 2.0
	var hd := MALL_D / 2.0
	# Corner and midpoint pillars.
	for x in [-hw, 0.0, hw]:
		for z in [-hd, hd]:
			if x == 0.0 and z == hd:
				continue  # entrance side keeps its middle open
			_add_box(Vector3(0.6, ROOF_Y, 0.6), Vector3(x, ROOF_Y / 2.0 + 0.3, z), FRAME)
	for z in [-hd / 2.0, hd / 2.0]:
		for x in [-hw, hw]:
			_add_box(Vector3(0.6, ROOF_Y, 0.6), Vector3(x, ROOF_Y / 2.0 + 0.3, z), FRAME)
	# Glass walls (entrance gap on the south face).
	_glass_wall(Vector3(0, 0, -hd), Vector3(MALL_W, ROOF_Y, 0.15))
	_glass_wall(Vector3(-hw, 0, 0), Vector3(0.15, ROOF_Y, MALL_D))
	_glass_wall(Vector3(hw, 0, 0), Vector3(0.15, ROOF_Y, MALL_D))
	_glass_wall(Vector3(-hw / 2.0 - 1.5, 0, hd), Vector3(hw - 3.0, ROOF_Y, 0.15))
	_glass_wall(Vector3(hw / 2.0 + 1.5, 0, hd), Vector3(hw - 3.0, ROOF_Y, 0.15))
	# Entrance lintel glass above the gap.
	_glass_wall(Vector3(0, 4.0, hd), Vector3(6.0, ROOF_Y - 4.0, 0.15))

	# Balcony ring at the second floor, atrium open in the centre.
	_add_box(Vector3(MALL_W, 0.3, 4.0), Vector3(0, BALCONY_Y, -hd + 2.0), CONCRETE)
	_add_box(Vector3(MALL_W, 0.3, 4.0), Vector3(0, BALCONY_Y, hd - 2.0), CONCRETE)
	_add_box(Vector3(4.0, 0.3, MALL_D - 8.0), Vector3(-hw + 2.0, BALCONY_Y, 0), CONCRETE)
	_add_box(Vector3(4.0, 0.3, MALL_D - 8.0), Vector3(hw - 2.0, BALCONY_Y, 0), CONCRETE)
	# Balcony railings.
	for def: Array in [
		[Vector3(MALL_W - 8.0, 0.8, 0.1), Vector3(0, BALCONY_Y + 0.55, -hd + 4.0)],
		[Vector3(MALL_W - 8.0, 0.8, 0.1), Vector3(0, BALCONY_Y + 0.55, hd - 4.0)],
		[Vector3(0.1, 0.8, MALL_D - 8.0), Vector3(-hw + 4.0, BALCONY_Y + 0.55, 0)],
		[Vector3(0.1, 0.8, MALL_D - 8.0), Vector3(hw - 4.0, BALCONY_Y + 0.55, 0)],
	]:
		_add_box(def[0], def[1], FRAME)

	# Roof with a central skylight opening.
	_add_box(Vector3(MALL_W + 1.0, 0.4, 4.5), Vector3(0, ROOF_Y, -hd + 2.25), CONCRETE)
	_add_box(Vector3(MALL_W + 1.0, 0.4, 4.5), Vector3(0, ROOF_Y, hd - 2.25), CONCRETE)
	_add_box(Vector3(8.5, 0.4, MALL_D - 9.0), Vector3(-hw + 4.25, ROOF_Y, 0), CONCRETE)
	_add_box(Vector3(8.5, 0.4, MALL_D - 9.0), Vector3(hw - 4.25, ROOF_Y, 0), CONCRETE)
	# The skylight itself: glass over the atrium.
	var sky := _add_box(Vector3(9.0, 0.1, MALL_D - 9.0), Vector3(0, ROOF_Y + 0.15, 0), GLASS, false)
	sky.material_override = _glass_mat()

	# Escalator ramps between floors (walkable).
	_ramp(Vector3(9.0, 0.3, 2.0), Vector3(5.0, BALCONY_Y, -1.0), 2.2)
	_ramp(Vector3(-9.0, 0.3, -2.0), Vector3(-5.0, BALCONY_Y, 1.0), 2.2)

func _glass_wall(pos: Vector3, size: Vector3) -> void:
	var mi := _add_box(size, pos + Vector3(0, size.y / 2.0 + 0.3, 0), GLASS)
	mi.material_override = _glass_mat()

func _ramp(from: Vector3, to: Vector3, width: float) -> void:
	var span := to - from
	var length := span.length()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.25, length)
	mi.mesh = box
	mi.material_override = _mat(FRAME.lightened(0.2))
	mi.position = (from + to) / 2.0
	var flat := Vector2(span.x, span.z).length()
	mi.rotation.y = atan2(span.x, span.z)
	mi.rotation.x = -atan(span.y / flat)
	add_child(mi)
	mi.create_trimesh_collision()

# --- fixtures ---

func _build_fountain() -> void:
	_add_mesh(_cylinder(2.6, 2.8, 0.6), Vector3(0, 0.6, 0), CONCRETE.darkened(0.1))
	var water := _add_mesh(_cylinder(2.3, 2.3, 0.1), Vector3(0, 0.85, 0), Color(0.2, 0.5, 0.65, 0.7), false)
	var m: StandardMaterial3D = water.material_override
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	for i in 9:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(0.3, 1.9)
		_add_mesh(_cylinder(0.09, 0.09, 0.03),
				Vector3(cos(a) * r, 0.82, sin(a) * r), Color(0.95, 0.8, 0.3), false)

func _build_shops() -> void:
	var shop_colors := [Color(0.75, 0.4, 0.35), Color(0.4, 0.55, 0.7), Color(0.65, 0.55, 0.3)]
	for i in 3:
		var z := -5.0 + i * 5.0
		_add_box(Vector3(3.0, 3.0, 4.0), Vector3(11.0, 1.8, z), CONCRETE.lightened(0.1))
		_add_box(Vector3(0.4, 0.8, 4.2), Vector3(9.4, 3.0, z), shop_colors[i])
	# The pet shop, west wall: big window, a collar on a stand, a door that will not open.
	_add_box(Vector3(3.0, 3.0, 5.0), Vector3(-11.0, 1.8, 2.5), CONCRETE.lightened(0.05))
	var win := _add_box(Vector3(0.1, 2.0, 3.6), Vector3(-9.45, 1.6, 2.5), GLASS, false)
	win.material_override = _glass_mat()
	_add_box(Vector3(0.4, 0.8, 5.2), Vector3(-9.4, 3.2, 2.5), Color(0.45, 0.6, 0.45))
	_add_mesh(_cylinder(0.08, 0.12, 0.9), Vector3(-10.4, 0.75, 2.5), FRAME, false)
	var collar := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.2
	collar.mesh = torus
	collar.material_override = _mat(Color(0.5, 0.3, 0.2))
	collar.position = Vector3(-10.4, 1.28, 2.5)
	collar.rotation.x = 0.4
	add_child(collar)
	var plate := PetWindow.new()
	plate.position = Vector3(-9.2, 1.0, 2.5)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.0
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

class PetWindow:
	extends Interactable

	func _init() -> void:
		prompt = "Peer through the glass"

	func interact(_player: Node) -> void:
		GameState.set_flag("pet_window_seen")
		var hud := get_tree().get_first_node_in_group("island_manager")
		if hud:
			hud = hud.get_node_or_null("HUD")
		if hud:
			hud.flash_message("One collar on a stand. The tag is blank, but the charm is a tiny paw. The door will not open.", 5.0)

func _build_geese() -> void:
	var flock := Node3D.new()
	flock.name = "Geese"
	flock.position = Vector3(0, 6.0, 0)
	add_child(flock)
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	var spots: Array[Vector3] = [Vector3(0, 1.4, -5.0)]
	for i in range(1, 8):
		spots.append(Vector3(-0.85 * i, rng.randf_range(0.4, 1.4), -5.0 + i * 1.05))
		spots.append(Vector3(0.85 * i, rng.randf_range(0.4, 1.4), -5.0 + i * 1.05))
	for s in spots:
		if abs(s.x) > 6.5:
			continue
		var goose := Node3D.new()
		var body := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.22
		bs.height = 0.34
		body.mesh = bs
		body.scale = Vector3(1.0, 1.0, 1.7)
		body.material_override = _mat(GOOSE_WHITE)
		goose.add_child(body)
		var neck := MeshInstance3D.new()
		var nc := CylinderMesh.new()
		nc.top_radius = 0.045
		nc.bottom_radius = 0.06
		nc.height = 0.34
		neck.mesh = nc
		neck.material_override = _mat(Color(0.2, 0.2, 0.22))
		neck.position = Vector3(0, 0.2, 0.3)
		neck.rotation.x = 0.5
		goose.add_child(neck)
		for side in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			var wb := BoxMesh.new()
			wb.size = Vector3(0.5, 0.03, 0.22)
			wing.mesh = wb
			wing.material_override = _mat(GOOSE_WHITE)
			wing.position = Vector3(0.3 * side, 0.08, 0)
			wing.rotation.z = 0.5 * side
			goose.add_child(wing)
		goose.position = s
		goose.rotation.y = PI  # flying toward the entrance, and the sea
		flock.add_child(goose)

func _build_elevator() -> void:
	var shaft := _add_box(Vector3(2.2, ROOF_Y, 2.2), Vector3(10.5, ROOF_Y / 2.0 + 0.3, -6.5), GLASS)
	shaft.material_override = _glass_mat()
	var plate := ElevatorDoor.new()
	plate.position = Vector3(9.2, 1.0, -6.5)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.8
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

class ElevatorDoor:
	extends Interactable

	func _init() -> void:
		prompt = "A dark glass elevator"

	func interact(_player: Node) -> void:
		var mgr := get_tree().get_first_node_in_group("island_manager")
		var hud: Node = mgr.get_node_or_null("HUD") if mgr else null
		if hud:
			hud.flash_message("Dark, silent, waiting. Its call button wants something the mall hasn't given yet.", 4.5)

func _build_dock() -> void:
	for i in 6:
		_add_box(Vector3(2.4, 0.15, 1.6), Vector3(0, 0.1 - i * 0.02, 25.0 + i * 1.7), Color(0.6, 0.5, 0.4))
	for side in [-1.0, 1.0]:
		for i in 2:
			_add_mesh(_cylinder(0.12, 0.14, 1.4), Vector3(side * 1.1, -0.2, 27.0 + i * 6.0), Color(0.45, 0.38, 0.3))

# --- the robot, and the hiss ---

func _build_robot() -> void:
	_robot = Node3D.new()
	_robot.name = "RobotVac"
	var body := MeshInstance3D.new()
	body.mesh = _cylinder(0.5, 0.55, 0.28)
	body.material_override = _mat(Color(0.2, 0.21, 0.24))
	body.position = Vector3(0, 0.14, 0)
	_robot.add_child(body)
	var eye := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 0.06
	es.height = 0.12
	eye.mesh = es
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(1, 0.3, 0.2)
	em.emission_enabled = true
	em.emission = Color(1, 0.25, 0.15)
	em.emission_energy_multiplier = 1.6
	eye.material_override = em
	eye.position = Vector3(0, 0.24, 0.45)
	_robot.add_child(eye)
	_robot.position = PATROL[0]
	add_child(_robot)
	_start_patrol()

	# Confrontation trigger just inside the entrance.
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7.0, 3.0, 3.0)
	cs.shape = box
	area.add_child(cs)
	area.position = Vector3(0, 1.4, MALL_D / 2.0 - 1.0)
	area.body_entered.connect(_on_mall_entered)
	add_child(area)

func _start_patrol() -> void:
	if _robot_tween and _robot_tween.is_valid():
		_robot_tween.kill()
	_robot_tween = create_tween().set_loops()
	for p in PATROL:
		_robot_tween.tween_property(_robot, "position", p, 3.0)

func _on_mall_entered(body: Node3D) -> void:
	if _confronted or not body.is_in_group("player"):
		return
	_confronted = true
	_confront(body)

func _confront(player: Node3D) -> void:
	if _robot_tween and _robot_tween.is_valid():
		_robot_tween.kill()
	Sfx.play("robot_whir", 1.0, 0.0, -4.0)
	var dest := Vector3(player.global_position.x + 1.1, 0.5, player.global_position.z + 1.1)
	var t := create_tween()
	t.tween_property(_robot, "position", dest, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash("A cleaning robot rounds on Khione, brushes whirring…", 3.0)
	await get_tree().create_timer(2.2).timeout
	if GameState.knows_vocal("hiss"):
		return
	GameState.learn_vocal("hiss")
	_flash("Khione's fur rises. Something new rattles in her throat.  (H to hiss!)", 6.0)

func _on_vocal(kind: String) -> void:
	if kind != "hiss" or _robot == null:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null or player.global_position.distance_to(_robot.global_position) > 7.0:
		return
	if _robot_tween and _robot_tween.is_valid():
		_robot_tween.kill()
	Sfx.play("robot_flee", 1.0, 0.05, -6.0)
	var t := create_tween()
	t.tween_property(_robot, "position", _robot_home, 1.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_robot, "rotation:y", _robot.rotation.y + TAU * 2.0, 1.4)
	t.tween_interval(25.0)
	t.tween_callback(_start_patrol)
	if not GameState.get_flag("robot_repelled"):
		GameState.set_flag("robot_repelled")
		_flash("The robot flees at top speed. Hissing: extremely effective.", 4.0)

# --- shared helpers ---

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../HUD")
	if hud:
		hud.flash_message(text, dur)

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

func _glass_mat() -> StandardMaterial3D:
	if not _materials.has("glass"):
		var m := StandardMaterial3D.new()
		m.albedo_color = GLASS
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["glass"] = m
	return _materials["glass"]

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[color] = m
	return _materials[color]

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

func _cylinder(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
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
