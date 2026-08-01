extends Node3D
## Island 1 — Ahalo. Procedural low-poly blockout: sandy island, grass plateau,
## a tiered hill to climb, palm trees, rocks, water, and a few test pickups.
## Layout is deterministic (fixed seed) so everyone sees the same island.

const SAND := Color(0.93, 0.85, 0.63)
const GRASS := Color(0.42, 0.7, 0.34)
const ROCK := Color(0.55, 0.55, 0.58)
const GOLD := Color(0.95, 0.78, 0.25)
const COCONUT := Color(0.4, 0.28, 0.16)

const WATER_SURFACE_Y := -0.4

const PALM_PATHS := [
	"res://assets/nature/tree_palm.glb",
	"res://assets/nature/tree_palmBend.glb",
	"res://assets/nature/tree_palmDetailedShort.glb",
	"res://assets/nature/tree_palmDetailedTall.glb",
	"res://assets/nature/tree_palmShort.glb",
	"res://assets/nature/tree_palmTall.glb",
]
const BIG_ROCK_PATHS := [
	"res://assets/nature/rock_largeA.glb",
	"res://assets/nature/rock_largeB.glb",
	"res://assets/nature/rock_largeC.glb",
	"res://assets/nature/rock_tallA.glb",
	"res://assets/nature/rock_tallB.glb",
]
const SMALL_ROCK_PATHS := [
	"res://assets/nature/rock_smallA.glb",
	"res://assets/nature/rock_smallB.glb",
	"res://assets/nature/rock_smallC.glb",
]
const FLORA_PATHS := [
	"res://assets/nature/grass.glb",
	"res://assets/nature/grass_large.glb",
	"res://assets/nature/flower_redA.glb",
	"res://assets/nature/flower_yellowA.glb",
	"res://assets/nature/flower_purpleA.glb",
]

var _materials := {}
var _visited_locations := {}
var _sand_mat: ShaderMaterial
var _grass_mat: ShaderMaterial

func _ready() -> void:
	_build_island()
	_build_water()
	_scatter_trees()
	_scatter_rocks()
	_scatter_flora()
	_place_pickups()
	_add_location_trigger(Vector3(0, 0, 33), 8.0, "South Beach")
	_add_location_trigger(Vector3(33, 0, -4), 9.0, "Echo Cove")
	_add_location_trigger(Vector3(-14.5, 0, 4.4), 8.0, "The Hillside Den")
	_add_location_trigger(Vector3(0, 3.3, 0), 7.0, "The Old Summit")

func _build_island() -> void:
	_sand_mat = _island_material(SAND, Color(0.85, 0.75, 0.52), 11, true)
	_grass_mat = _island_material(GRASS, Color(0.33, 0.6, 0.27), 22, false)
	# Sandy base: flat top at y=0, gentle beach slope down into the water.
	_add_mesh(_cylinder(40.0, 55.0, 6.0), Vector3(0, -3.0, 0), SAND, true, _sand_mat)
	# Grass plateau with a tapered edge so Khione can walk up without jumping.
	_add_mesh(_cylinder(30.0, 33.0, 0.3), Vector3(0, 0.15, 0), GRASS, true, _grass_mat)
	# Tiered hill in the middle — each 1m step is a deliberate jump challenge.
	_add_mesh(_cylinder(12.0, 13.5, 1.0), Vector3(0, 0.8, 0), GRASS, true, _grass_mat)
	_add_mesh(_cylinder(8.5, 9.8, 1.0), Vector3(0, 1.8, 0), GRASS, true, _grass_mat)
	_add_mesh(_cylinder(5.5, 6.5, 1.0), Vector3(0, 2.8, 0), ROCK)
	_scatter_dunes()

func _island_material(base: Color, alt: Color, seed_v: int, wet: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/island.gdshader")
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("alt_color", alt)
	m.set_shader_parameter("noise_tex", _noise_tex(seed_v, 0.06))
	m.set_shader_parameter("detail_normal", _noise_tex(seed_v + 100, 0.15, true))
	m.set_shader_parameter("wet_enabled", 1.0 if wet else 0.0)
	return m

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

func _scatter_dunes() -> void:
	# Gentle walkable mounds so the ground has a silhouette.
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	for i in 7:
		var r := rng.randf_range(31.0, 38.0)
		var a := rng.randf_range(0.0, TAU)
		var dune := SphereMesh.new()
		var dr := rng.randf_range(4.5, 8.0)
		dune.radius = dr
		dune.height = dr * 0.22
		_add_mesh(dune, Vector3(cos(a) * r, 0.0, sin(a) * r), SAND, true, _sand_mat)
	for i in 4:
		var r := rng.randf_range(16.0, 26.0)
		var a := rng.randf_range(0.0, TAU)
		var mound := SphereMesh.new()
		var mr := rng.randf_range(3.5, 6.0)
		mound.radius = mr
		mound.height = mr * 0.2
		_add_mesh(mound, Vector3(cos(a) * r, 0.28, sin(a) * r), GRASS, true, _grass_mat)

func _build_water() -> void:
	# Subdivided plane + shader: gentle waves, fresnel colour shift.
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	sm.set_shader_parameter("wave_normal1", _noise_tex(51, 0.08, true))
	sm.set_shader_parameter("wave_normal2", _noise_tex(52, 0.13, true))
	mi.material_override = sm
	mi.position = Vector3(0, WATER_SURFACE_Y, 0)
	add_child(mi)

	# Invisible volume that tells the player she is in water.
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 30, 600)
	cs.shape = box
	area.add_child(cs)
	area.position = Vector3(0, WATER_SURFACE_Y - 15.0, 0)
	area.body_entered.connect(_on_water_body_entered)
	area.body_exited.connect(_on_water_body_exited)
	add_child(area)

func _scatter_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260728
	var palms: Array = []
	for p: String in PALM_PATHS:
		palms.append(load(p))
	# Palms grow in groves, with a natural lean — not an even ring.
	for g in 6:
		var gr := rng.randf_range(16.0, 26.0)
		var ga := rng.randf_range(0.0, TAU)
		var center := Vector3(cos(ga) * gr, 0.3, sin(ga) * gr)
		for i in rng.randi_range(3, 6):
			var pos := center + Vector3(rng.randf_range(-3.5, 3.5), 0, rng.randf_range(-3.5, 3.5))
			var flat_r := Vector2(pos.x, pos.z).length()
			if flat_r > 28.0 or flat_r < 14.5:
				continue
			var s := rng.randf_range(2.6, 3.4)
			var t := _add_scene(palms[rng.randi_range(0, palms.size() - 1)], pos,
					rng.randf_range(0.0, TAU), s)
			t.rotation.x = rng.randf_range(-0.06, 0.06)
			t.rotation.z = rng.randf_range(-0.06, 0.06)
			# Trunk collider sized to the palm; climbable canopies return with real level design.
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.12 * s
			cyl.height = 1.1 * s
			cs.shape = cyl
			cs.position = Vector3(0, 0.55 * s, 0)
			sb.add_child(cs)
			sb.position = pos
			add_child(sb)

func _scatter_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var big: Array = []
	for p: String in BIG_ROCK_PATHS:
		big.append(load(p))
	var small: Array = []
	for p: String in SMALL_ROCK_PATHS:
		small.append(load(p))
	# Beach rocks.
	for i in 14:
		var r := rng.randf_range(31.0, 39.0)
		var a := rng.randf_range(0.0, TAU)
		var pool: Array = big if rng.randf() < 0.35 else small
		_add_scene(pool[rng.randi_range(0, pool.size() - 1)],
				Vector3(cos(a) * r, 0.0, sin(a) * r),
				rng.randf_range(0.0, TAU), rng.randf_range(1.5, 2.5), true)
	# Sea rocks poking above the surface — swim out and climb on.
	for i in 5:
		var r := rng.randf_range(43.0, 50.0)
		var a := rng.randf_range(0.0, TAU)
		_add_scene(big[rng.randi_range(0, big.size() - 1)],
				Vector3(cos(a) * r, -0.8, sin(a) * r),
				rng.randf_range(0.0, TAU), rng.randf_range(3.0, 4.0), true)

func _scatter_flora() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var flora: Array = []
	for p: String in FLORA_PATHS:
		flora.append(load(p))
	for i in 140:
		var r := rng.randf_range(13.5, 28.5)
		var a := rng.randf_range(0.0, TAU)
		_add_scene(flora[rng.randi_range(0, flora.size() - 1)],
				Vector3(cos(a) * r, 0.3, sin(a) * r),
				rng.randf_range(0.0, TAU), rng.randf_range(2.0, 3.0))

func _add_scene(scene: PackedScene, pos: Vector3, yrot: float, s: float, collide := false) -> Node3D:
	var n: Node3D = scene.instantiate()
	n.position = pos
	n.rotation.y = yrot
	n.scale = Vector3(s, s, s)
	add_child(n)
	if collide:
		var mi := _first_mesh_instance(n)
		if mi:
			mi.create_trimesh_collision()
	return n

func _first_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _first_mesh_instance(c)
		if r:
			return r
	return null

func _place_pickups() -> void:
	# A reward atop the hill and coconuts under the palms, to exercise the inventory.
	_add_pickup(Vector3(0, 3.35, 0), "sun_shell", "Sun Shell", GOLD)
	_add_pickup(Vector3(10, 0.4, 20), "coconut", "Coconut", COCONUT)
	_add_pickup(Vector3(-18, 0.4, -8), "coconut", "Coconut", COCONUT)
	_add_pickup(Vector3(-14, 0.4, 15), "coconut", "Coconut", COCONUT)
	_add_pickup(Vector3(21, 0.4, -7), "coconut", "Coconut", COCONUT)

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
	if not body.is_in_group("player") or not GameState.get_flag("intro_done"):
		return
	var title: String = area.get_meta("title")
	if _visited_locations.has(title):
		return
	_visited_locations[title] = true
	get_node("../HUD").show_location(title)

func _on_water_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.enter_water(WATER_SURFACE_Y)

func _on_water_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.exit_water()

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[color] = m
	return _materials[color]

func _cylinder(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color, with_collision := true,
		override_mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = override_mat if override_mat else _mat(color)
	mi.position = pos
	add_child(mi)
	if with_collision:
		mi.create_trimesh_collision()
	return mi

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
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = Vector3(0, 0.25, 0)
	a.add_child(mi)
	add_child(a)
