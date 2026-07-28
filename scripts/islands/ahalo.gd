extends Node3D
## Island 1 — Ahalo. Procedural low-poly blockout: sandy island, grass plateau,
## a tiered hill to climb, palm trees, rocks, water, and a few test pickups.
## Layout is deterministic (fixed seed) so everyone sees the same island.

const SAND := Color(0.93, 0.85, 0.63)
const GRASS := Color(0.42, 0.7, 0.34)
const TRUNK := Color(0.45, 0.32, 0.2)
const LEAF := Color(0.24, 0.55, 0.28)
const ROCK := Color(0.55, 0.55, 0.58)
const WATER := Color(0.12, 0.42, 0.65, 0.75)
const GOLD := Color(0.95, 0.78, 0.25)
const COCONUT := Color(0.4, 0.28, 0.16)

const WATER_SURFACE_Y := -0.4

var _materials := {}

func _ready() -> void:
	_build_island()
	_build_water()
	_scatter_trees()
	_scatter_rocks()
	_place_pickups()

func _build_island() -> void:
	# Sandy base: flat top at y=0, gentle beach slope down into the water.
	_add_mesh(_cylinder(40.0, 55.0, 6.0), Vector3(0, -3.0, 0), SAND)
	# Grass plateau with a tapered edge so Khione can walk up without jumping.
	_add_mesh(_cylinder(30.0, 33.0, 0.3), Vector3(0, 0.15, 0), GRASS)
	# Tiered hill in the middle — each 1m step is a deliberate jump challenge.
	_add_mesh(_cylinder(12.0, 13.5, 1.0), Vector3(0, 0.8, 0), GRASS)
	_add_mesh(_cylinder(8.5, 9.8, 1.0), Vector3(0, 1.8, 0), GRASS)
	_add_mesh(_cylinder(5.5, 6.5, 1.0), Vector3(0, 2.8, 0), ROCK)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	_add_mesh(plane, Vector3(0, WATER_SURFACE_Y, 0), WATER, false)

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
	for i in 26:
		var r := rng.randf_range(15.0, 27.0)
		var a := rng.randf_range(0.0, TAU)
		var x := cos(a) * r
		var z := sin(a) * r
		var h := rng.randf_range(2.2, 3.4)
		_add_mesh(_cylinder(0.16, 0.22, h), Vector3(x, 0.3 + h * 0.5, z), TRUNK)
		# Canopies are solid so Khione can hop from tree to tree.
		var canopy := SphereMesh.new()
		var cr := rng.randf_range(1.0, 1.5)
		canopy.radius = cr
		canopy.height = cr * 1.6
		_add_mesh(canopy, Vector3(x, 0.3 + h + cr * 0.4, z), LEAF)

func _scatter_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Beach rocks.
	for i in 12:
		var r := rng.randf_range(31.0, 39.0)
		var a := rng.randf_range(0.0, TAU)
		var rr := rng.randf_range(0.4, 1.0)
		var rock := SphereMesh.new()
		rock.radius = rr
		rock.height = rr * 1.2
		_add_mesh(rock, Vector3(cos(a) * r, 0.15, sin(a) * r), ROCK)
	# Sea rocks poking above the surface — swim out and climb on.
	for i in 5:
		var r := rng.randf_range(43.0, 50.0)
		var a := rng.randf_range(0.0, TAU)
		var rock := SphereMesh.new()
		rock.radius = 1.3
		rock.height = 2.2
		_add_mesh(rock, Vector3(cos(a) * r, -0.5, sin(a) * r), ROCK)

func _place_pickups() -> void:
	# A reward atop the hill and coconuts under the palms, to exercise the inventory.
	_add_pickup(Vector3(0, 3.35, 0), "sun_shell", "Sun Shell", GOLD)
	_add_pickup(Vector3(10, 0.4, 20), "coconut", "Coconut", COCONUT)
	_add_pickup(Vector3(-18, 0.4, -8), "coconut", "Coconut", COCONUT)

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

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
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
