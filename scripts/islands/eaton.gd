extends Node3D
## Island 2 — The Eaton Centre. A silent glass shopping mall grown out of a
## sandy island: tiled two-storey atrium with warm lighting, recessed
## storefronts, escalators, a two-tier fountain ringed with benches, a food
## court, planters, hanging banners, a frozen goose flock under the trussed
## skylight, a dark glass elevator, the pet shop window, and one very
## territorial cleaning robot (the hiss teacher). Riddles land next.

const SAND := Color(0.9, 0.86, 0.72)
const CONCRETE := Color(0.78, 0.77, 0.74)
const FRAME := Color(0.35, 0.37, 0.4)
const GLASS := Color(0.7, 0.85, 0.92, 0.22)
const GOOSE_WHITE := Color(0.95, 0.95, 0.92)
const WATER_SURFACE_Y := -0.4

const MALL_W := 40.0
const MALL_D := 26.0
const BALCONY_Y := 4.4
const ROOF_Y := 10.5

const FURNITURE := "res://assets/furniture/"

var _materials := {}
var _visited_locations := {}
var _robot: Node3D
var _robot_tween: Tween
var _confronted := false
var _robot_home := Vector3(-13.0, 0.5, -9.0)
const PATROL := [Vector3(10, 0.5, -5), Vector3(-10, 0.5, -5), Vector3(-10, 0.5, 5), Vector3(10, 0.5, 5)]

func _ready() -> void:
	_build_island()
	_build_water()
	_build_mall()
	_build_lighting()
	_build_fountain()
	_build_shops()
	_build_furnishings()
	_build_geese()
	_build_elevator()
	_build_dock()
	_build_robot()
	_add_location_trigger(Vector3(0, 0, 0), 9.0, "The Atrium")
	_add_location_trigger(Vector3(-16, 0, 0), 5.0, "The Pet Shop")
	_add_location_trigger(Vector3(11, 0, -6), 5.0, "The Food Court")
	GameState.vocal_used.connect(_on_vocal)

# --- terrain & water ---

func _build_island() -> void:
	_add_mesh(_cylinder(38.0, 52.0, 6.0), Vector3(0, -3.0, 0), SAND)
	_add_mesh(_cylinder(27.0, 29.0, 0.3), Vector3(0, 0.15, 0), CONCRETE)
	# Tiled mall floor.
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(MALL_W - 0.5, 0.08, MALL_D - 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = floor_mesh
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/mall_floor.gdshader")
	mi.material_override = sm
	mi.position = Vector3(0, 0.34, 0)
	add_child(mi)
	mi.create_trimesh_collision()

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
	sm.set_shader_parameter("shore_radius", 39.0)
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
	# Pillars along all faces.
	for i in 7:
		var x := -hw + i * (MALL_W / 6.0)
		for z in [-hd, hd]:
			if absf(x) < 4.5 and z == hd:
				continue  # entrance stays open
			_add_box(Vector3(0.65, ROOF_Y, 0.65), Vector3(x, ROOF_Y / 2.0 + 0.3, z), FRAME)
	for z in [-hd / 2.0, 0.0, hd / 2.0]:
		for x in [-hw, hw]:
			_add_box(Vector3(0.65, ROOF_Y, 0.65), Vector3(x, ROOF_Y / 2.0 + 0.3, z), FRAME)
	# Glass walls; the south face keeps an 8m entrance gap with a lintel.
	_glass_wall(Vector3(0, 0, -hd), Vector3(MALL_W, ROOF_Y, 0.15))
	_glass_wall(Vector3(-hw, 0, 0), Vector3(0.15, ROOF_Y, MALL_D))
	_glass_wall(Vector3(hw, 0, 0), Vector3(0.15, ROOF_Y, MALL_D))
	var seg := (MALL_W - 8.0) / 2.0
	_glass_wall(Vector3(-(4.0 + seg / 2.0), 0, hd), Vector3(seg, ROOF_Y, 0.15))
	_glass_wall(Vector3(4.0 + seg / 2.0, 0, hd), Vector3(seg, ROOF_Y, 0.15))
	_glass_wall(Vector3(0, BALCONY_Y, hd), Vector3(8.0, ROOF_Y - BALCONY_Y, 0.15))
	# Entrance canopy, sign band, and logo mark.
	_add_box(Vector3(10.0, 0.3, 3.0), Vector3(0, 4.0, hd + 1.5), FRAME)
	_add_box(Vector3(12.0, 1.3, 0.3), Vector3(0, 8.6, hd + 0.2), Color(0.2, 0.5, 0.5), false)
	_add_box(Vector3(0.9, 0.9, 0.32), Vector3(-4.6, 8.6, hd + 0.22), Color(0.95, 0.93, 0.85), false)
	# Rooftop clutter: parapet lips and HVAC units, the honest mall silhouette.
	_add_box(Vector3(MALL_W + 1.2, 0.5, 0.3), Vector3(0, ROOF_Y + 0.45, -hd), CONCRETE.darkened(0.05), false)
	_add_box(Vector3(MALL_W + 1.2, 0.5, 0.3), Vector3(0, ROOF_Y + 0.45, hd), CONCRETE.darkened(0.05), false)
	_add_box(Vector3(0.3, 0.5, MALL_D + 1.2), Vector3(-hw, ROOF_Y + 0.45, 0), CONCRETE.darkened(0.05), false)
	_add_box(Vector3(0.3, 0.5, MALL_D + 1.2), Vector3(hw, ROOF_Y + 0.45, 0), CONCRETE.darkened(0.05), false)
	for def: Array in [
		[-13.0, Vector3(2.2, 1.2, 1.8)],
		[13.5, Vector3(1.8, 1.0, 1.6)],
		[-15.5, Vector3(1.2, 0.9, 1.2)],
	]:
		var size: Vector3 = def[1]
		_add_box(size, Vector3(def[0], ROOF_Y + 0.2 + size.y / 2.0, -hd + 3.0), FRAME.lightened(0.35))

	# Balcony ring (atrium opening 30 x 16).
	_add_box(Vector3(MALL_W, 0.3, 5.0), Vector3(0, BALCONY_Y, -hd + 2.5), CONCRETE)
	_add_box(Vector3(MALL_W, 0.3, 5.0), Vector3(0, BALCONY_Y, hd - 2.5), CONCRETE)
	_add_box(Vector3(5.0, 0.3, MALL_D - 10.0), Vector3(-hw + 2.5, BALCONY_Y, 0), CONCRETE)
	_add_box(Vector3(5.0, 0.3, MALL_D - 10.0), Vector3(hw - 2.5, BALCONY_Y, 0), CONCRETE)
	for def: Array in [
		[Vector3(30.0, 0.9, 0.12), Vector3(0, BALCONY_Y + 0.6, -hd + 5.0)],
		[Vector3(30.0, 0.9, 0.12), Vector3(0, BALCONY_Y + 0.6, hd - 5.0)],
		[Vector3(0.12, 0.9, MALL_D - 10.0), Vector3(-hw + 5.0, BALCONY_Y + 0.6, 0)],
		[Vector3(0.12, 0.9, MALL_D - 10.0), Vector3(hw - 5.0, BALCONY_Y + 0.6, 0)],
	]:
		_add_box(def[0], def[1], FRAME)

	# Roof ring with a trussed skylight over the atrium.
	_add_box(Vector3(MALL_W + 1.0, 0.4, 6.5), Vector3(0, ROOF_Y, -hd + 3.25), CONCRETE)
	_add_box(Vector3(MALL_W + 1.0, 0.4, 6.5), Vector3(0, ROOF_Y, hd - 3.25), CONCRETE)
	_add_box(Vector3(6.5, 0.4, MALL_D - 13.0), Vector3(-hw + 3.25, ROOF_Y, 0), CONCRETE)
	_add_box(Vector3(6.5, 0.4, MALL_D - 13.0), Vector3(hw - 3.25, ROOF_Y, 0), CONCRETE)
	var sky := _add_box(Vector3(MALL_W - 12.0, 0.1, MALL_D - 12.5), Vector3(0, ROOF_Y + 0.2, 0), GLASS, false)
	_glassify(sky)
	for i in 7:
		var x := -12.0 + i * 4.0
		_add_box(Vector3(0.25, 0.4, MALL_D - 13.0), Vector3(x, ROOF_Y - 0.1, 0), FRAME, false)

	# Escalators with side skirts.
	_ramp(Vector3(11.0, 0.38, 5.5), Vector3(15.5, BALCONY_Y, 1.0), 2.2, true)
	_ramp(Vector3(-11.0, 0.38, -5.5), Vector3(-15.5, BALCONY_Y, -1.0), 2.2, true)

	# Second-floor storefront facades along the north balcony.
	var upper_colors := [Color(0.7, 0.45, 0.5), Color(0.45, 0.55, 0.7), Color(0.6, 0.6, 0.4), Color(0.5, 0.65, 0.55)]
	for i in 4:
		var x := -12.0 + i * 8.0
		_add_box(Vector3(6.0, 3.2, 2.2), Vector3(x, BALCONY_Y + 1.9, -hd + 1.4), CONCRETE.lightened(0.08))
		_add_box(Vector3(6.2, 0.7, 0.3), Vector3(x, BALCONY_Y + 3.2, -hd + 2.6), upper_colors[i])

	# Banners hanging from the balcony rails.
	var banner_colors := [Color(0.75, 0.35, 0.3), Color(0.35, 0.5, 0.7), Color(0.85, 0.7, 0.3), Color(0.45, 0.65, 0.5)]
	for i in 4:
		var x := -9.0 + i * 6.0
		_add_box(Vector3(0.06, 2.4, 1.3), Vector3(x, BALCONY_Y - 1.1, -hd + 5.1), banner_colors[i], false)
		_add_box(Vector3(0.06, 2.4, 1.3), Vector3(x, BALCONY_Y - 1.1, hd - 5.1), banner_colors[(i + 2) % 4], false)

func _glass_wall(pos: Vector3, size: Vector3) -> void:
	var mi := _add_box(size, pos + Vector3(0, size.y / 2.0 + 0.3, 0), GLASS)
	_glassify(mi)

func _ramp(from: Vector3, to: Vector3, width: float, with_skirts := false) -> void:
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
	if with_skirts:
		var dirn := Vector3(span.x, 0, span.z).normalized()
		var perp := Vector3(dirn.z, 0, -dirn.x)
		for s in [-1.0, 1.0]:
			var sk := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(0.15, 1.0, length)
			sk.mesh = sb
			sk.material_override = _mat(FRAME)
			sk.position = (from + to) / 2.0 + perp * (width / 2.0 * s) + Vector3(0, 0.45, 0)
			sk.rotation.y = mi.rotation.y
			sk.rotation.x = mi.rotation.x
			add_child(sk)

func _build_lighting() -> void:
	# Warm light strips under the balcony soffits and omni fill lights.
	var strip := StandardMaterial3D.new()
	strip.albedo_color = Color(1.0, 0.95, 0.85)
	strip.emission_enabled = true
	strip.emission = Color(1.0, 0.93, 0.78)
	strip.emission_energy_multiplier = 1.8
	# NOTE: no OmniLights here on purpose. Forward+ clustered omni lights
	# tile-artifact on macOS 13 Metal (same driver family as the SDFGI and
	# depth-texture bugs), so the interior is lit by emissive strips, the
	# skylight, and sky ambient instead.
	for def: Array in [
		[Vector3(28.0, 0.08, 0.5), Vector3(0, BALCONY_Y - 0.18, -8.2)],
		[Vector3(28.0, 0.08, 0.5), Vector3(0, BALCONY_Y - 0.18, 8.2)],
		[Vector3(0.5, 0.08, 14.0), Vector3(-14.8, BALCONY_Y - 0.18, 0)],
		[Vector3(0.5, 0.08, 14.0), Vector3(14.8, BALCONY_Y - 0.18, 0)],
		[Vector3(0.5, 0.08, 22.0), Vector3(-19.6, ROOF_Y - 0.4, 0)],
		[Vector3(0.5, 0.08, 22.0), Vector3(19.6, ROOF_Y - 0.4, 0)],
	]:
		var mi := _add_box(def[0], def[1], Color.WHITE, false)
		mi.material_override = strip
	# NOTE: no ReflectionProbe either; probes are clustered elements in
	# Forward+ and tile-corrupt on this driver just like omni lights.
	# Dust motes drifting in the skylight beams.
	var motes := CPUParticles3D.new()
	motes.amount = 70
	motes.lifetime = 14.0
	motes.preprocess = 14.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(13.0, 4.0, 6.5)
	motes.position = Vector3(0, 5.5, 0)
	motes.gravity = Vector3.ZERO
	motes.direction = Vector3(0, -1, 0)
	motes.spread = 180.0
	motes.initial_velocity_min = 0.03
	motes.initial_velocity_max = 0.12
	var grain := SphereMesh.new()
	grain.radius = 0.012
	grain.height = 0.024
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.98, 0.9, 0.5)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grain.material = gm
	motes.mesh = grain
	add_child(motes)

# --- fixtures ---

func _build_fountain() -> void:
	_add_mesh(_cylinder(3.4, 3.6, 0.7), Vector3(0, 0.72, 0), CONCRETE.darkened(0.1))
	var water := _add_mesh(_cylinder(3.05, 3.05, 0.1), Vector3(0, 1.02, 0), Color(0.2, 0.5, 0.65, 0.7), false)
	(water.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add_mesh(_cylinder(0.5, 0.9, 1.2), Vector3(0, 1.45, 0), CONCRETE.darkened(0.15))
	_add_mesh(_cylinder(1.5, 1.6, 0.28), Vector3(0, 2.15, 0), CONCRETE.darkened(0.1))
	var upper := _add_mesh(_cylinder(1.3, 1.3, 0.08), Vector3(0, 2.32, 0), Color(0.25, 0.55, 0.68, 0.7), false)
	(upper.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	for i in 12:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(0.4, 2.6)
		_add_mesh(_cylinder(0.09, 0.09, 0.03),
				Vector3(cos(a) * r, 0.99, sin(a) * r), Color(0.95, 0.8, 0.3), false)

func _build_shops() -> void:
	# Ground-floor shops, east wall: recessed interiors behind glass fronts.
	var shop_colors := [Color(0.75, 0.4, 0.35), Color(0.4, 0.55, 0.7), Color(0.65, 0.55, 0.3)]
	for i in 3:
		var z := -8.0 + i * 8.0
		_add_box(Vector3(3.0, 3.6, 5.0), Vector3(18.5, 2.15, z), CONCRETE.lightened(0.1))
		var front := _add_box(Vector3(0.1, 2.6, 4.2), Vector3(15.9, 1.75, z), GLASS, true)
		_glassify(front)
		_add_box(Vector3(0.35, 0.9, 4.8), Vector3(15.8, 3.55, z), shop_colors[i])
		_add_scene(FURNITURE + ["tableCoffee.glb", "plantSmall2.glb", "lampRoundFloor.glb"][i],
				Vector3(16.8, 0.4, z), PI / 2.0, 1.6)
		# Window merchandise: little stacks of product boxes.
		var box_colors := [Color(0.85, 0.6, 0.3), Color(0.5, 0.65, 0.8), Color(0.8, 0.75, 0.6)]
		for k in 3:
			_add_box(Vector3(0.35, 0.35, 0.35),
					Vector3(16.6, 0.56 + (k / 2) * 0.36, z - 1.3 + (k % 2) * 0.45),
					box_colors[(i + k) % box_colors.size()], false)
	# West wall: two shops flanking the pet shop.
	for z in [-8.5, 8.5]:
		_add_box(Vector3(3.0, 3.6, 5.0), Vector3(-18.5, 2.15, z), CONCRETE.lightened(0.1))
		var front := _add_box(Vector3(0.1, 2.6, 4.2), Vector3(-15.9, 1.75, z), GLASS, true)
		_glassify(front)
		_add_box(Vector3(0.35, 0.9, 4.8), Vector3(-15.8, 3.55, z), Color(0.55, 0.45, 0.65))
		_add_scene(FURNITURE + "plantSmall3.glb", Vector3(-16.8, 0.4, z), -PI / 2.0, 1.6)
	# The pet shop: one collar on a stand, and a door that will not open.
	_add_box(Vector3(3.0, 3.6, 6.0), Vector3(-18.5, 2.15, 0), CONCRETE.lightened(0.05))
	var win := _add_box(Vector3(0.1, 2.4, 4.4), Vector3(-15.9, 1.7, 0), GLASS, true)
	_glassify(win)
	_add_box(Vector3(0.35, 0.9, 5.4), Vector3(-15.8, 3.55, 0), Color(0.45, 0.6, 0.45))
	_add_mesh(_cylinder(0.08, 0.12, 0.9), Vector3(-16.8, 0.85, 0), FRAME, false)
	var collar := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.2
	collar.mesh = torus
	collar.material_override = _mat(Color(0.5, 0.3, 0.2))
	collar.position = Vector3(-16.8, 1.38, 0)
	collar.rotation.x = 0.4
	add_child(collar)
	var plate := PetWindow.new()
	plate.position = Vector3(-15.2, 1.0, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.2
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

class PetWindow:
	extends Interactable

	func _init() -> void:
		prompt = "Peer through the glass"

	func interact(_player: Node) -> void:
		GameState.set_flag("pet_window_seen")
		var mgr := get_tree().get_first_node_in_group("island_manager")
		var hud: Node = mgr.get_node_or_null("HUD") if mgr else null
		if hud:
			hud.flash_message("One collar on a stand. The tag is blank, but the charm is a tiny paw. The door will not open.", 5.0)

func _build_furnishings() -> void:
	# Benches ringing the fountain, facing it.
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var pos := Vector3(cos(a) * 5.6, 0.38, sin(a) * 5.6)
		_add_scene(FURNITURE + "bench.glb", pos, atan2(-pos.x, -pos.z), 1.5, true)
	# Food court, north-east corner of the ground floor.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 3:
		var t_pos := Vector3(8.5 + (i % 2) * 4.0, 0.38, -8.0 + i * 2.6)
		_add_scene(FURNITURE + "tableRound.glb", t_pos, 0.0, 1.5, true)
		for k in 2:
			var a := rng.randf_range(0.0, TAU)
			var c_pos := t_pos + Vector3(cos(a) * 1.1, 0, sin(a) * 1.1)
			_add_scene(FURNITURE + "chairModernCushion.glb", c_pos, a + PI, 1.5, true)
	# Planters at the atrium corners and flanking the entrance.
	for pos: Vector3 in [
		Vector3(-8, 0.38, -6), Vector3(8, 0.38, 6), Vector3(-8, 0.38, 6),
		Vector3(-5, 0.38, 11.5), Vector3(5, 0.38, 11.5),
	]:
		_add_box(Vector3(1.6, 0.7, 1.6), pos + Vector3(0, 0.35, 0), CONCRETE.darkened(0.12))
		_add_scene(FURNITURE + ["pottedPlant.glb", "plantSmall1.glb", "plantSmall2.glb"][randi() % 3],
				pos + Vector3(0, 0.7, 0), randf_range(0.0, TAU), 1.7)
	# Floor lamps along the atrium.
	for pos: Vector3 in [Vector3(-13, 0.38, -6), Vector3(13, 0.38, 6), Vector3(-13, 0.38, 6), Vector3(13, 0.38, -6)]:
		_add_scene(FURNITURE + "lampRoundFloor.glb", pos, 0.0, 1.8, true)

func _build_geese() -> void:
	var flock := Node3D.new()
	flock.name = "Geese"
	flock.position = Vector3(0, 6.6, 0)
	add_child(flock)
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	var spots: Array[Vector3] = [Vector3(0, 1.6, -6.0)]
	for i in range(1, 11):
		spots.append(Vector3(-0.95 * i, rng.randf_range(0.3, 1.6), -6.0 + i * 1.05))
		spots.append(Vector3(0.95 * i, rng.randf_range(0.3, 1.6), -6.0 + i * 1.05))
	for s in spots:
		if absf(s.x) > 10.5:
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
	var shaft := _add_box(Vector3(2.4, ROOF_Y - 0.3, 2.4), Vector3(13.5, ROOF_Y / 2.0 + 0.3, -6.5), GLASS)
	_glassify(shaft)
	var plate := ElevatorDoor.new()
	plate.position = Vector3(12.0, 1.0, -6.5)
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
	for i in 7:
		_add_box(Vector3(2.4, 0.15, 1.7), Vector3(0, 0.1 - i * 0.015, 29.0 + i * 1.8), Color(0.6, 0.5, 0.4))
	for side in [-1.0, 1.0]:
		for i in 3:
			_add_mesh(_cylinder(0.12, 0.14, 1.5), Vector3(side * 1.1, -0.2, 30.0 + i * 4.5), Color(0.45, 0.38, 0.3))
	# Concrete walkway from the dock to the entrance, with bollards.
	_add_box(Vector3(4.0, 0.1, 16.0), Vector3(0, 0.31, 21.0), CONCRETE.darkened(0.04))
	for side in [-1.0, 1.0]:
		for z in [15.5, 20.5, 25.5]:
			_add_mesh(_cylinder(0.1, 0.12, 0.7), Vector3(side * 2.5, 0.65, z), FRAME.lightened(0.15))

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

	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(9.0, 3.0, 3.0)
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
		_robot_tween.tween_property(_robot, "position", p, 3.5)

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

## Glass never casts shadows: alpha-dithered shadow maps stamp checker
## noise over the whole interior otherwise.
func _glassify(mi: MeshInstance3D) -> void:
	mi.material_override = _glass_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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

func _add_scene(path: String, pos: Vector3, yrot: float, s: float, collide := false) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.rotation.y = yrot
	n.scale = Vector3.ONE * s
	add_child(n)
	if collide:
		var mi := _fmi(n)
		if mi:
			mi.create_trimesh_collision()
	return n

func _fmi(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _fmi(c)
		if r:
			return r
	return null
