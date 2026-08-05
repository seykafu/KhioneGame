extends Node3D
## Island 3 · Prince's Island — Calgary in high summer, Oreo's hometown.
## A green park island in the milky-turquoise braid of the Bow: lawns and
## cottonwoods, a lagoon with ducklings, the red lattice tube of the Peace
## Bridge, gophers on the east lawn, a bandstand, an abandoned ice-cream
## cart, and the downtown skyline hazy across the water. The off-leash
## meadow waits at the north point. Riddles land in later passes; this is
## the living shell.

const WATER_SURFACE_Y := -0.4
const COAST_BASE := 46.0
const PATH_R := 16.0
const LAGOON_CENTER := Vector2(-11.0, -1.0)
const LAGOON_RADII := Vector2(7.5, 5.5)

const LAWN := Color(0.42, 0.68, 0.32)
const WOOD := Color(0.5, 0.38, 0.28)
const PARK_GREEN := Color(0.16, 0.42, 0.3)  # painted benches and rails
const BRIDGE_RED := Color(0.78, 0.16, 0.14)
const STONE := Color(0.6, 0.6, 0.62)

var _materials := {}
var _visited_locations := {}
var _gopher_mounds: Array[Vector3] = []

func _ready() -> void:
	_build_island()
	_build_water()
	_build_lagoon()
	_build_peace_bridge()
	_build_skyline()
	_build_dock()
	_build_dog_park()
	_build_bandstand()
	_build_ice_cream_cart()
	_build_furnishings()
	_scatter_trees()
	_scatter_grass_blades()
	_build_fluff()
	_spawn_ducks()
	_spawn_gophers()
	_spawn_butterflies()
	_add_ambient_loop("res://assets/audio/park_birds.wav", Vector3(0, 3.0, -4), -10.0, 70.0)
	_add_ambient_loop("res://assets/audio/brook.wav", Vector3(-5.5, 0.3, 3.5), -14.0, 12.0)
	var breeze := Node3D.new()
	breeze.name = "BowBreeze"
	breeze.set_script(load("res://scripts/islands/bow_breeze.gd"))
	add_child(breeze)
	for def: Array in [
		["PaperRegatta", "res://scripts/puzzles/paper_regatta.gd"],
		["IceCreamRound", "res://scripts/puzzles/ice_cream_round.gd"],
		["GopherSemaphore", "res://scripts/puzzles/gopher_semaphore.gd"],
		["BridgeKite", "res://scripts/puzzles/bridge_kite.gd"],
		["OffleashHowl", "res://scripts/puzzles/offleash_howl.gd"],
	]:
		var puzzle := Node3D.new()
		puzzle.name = def[0]
		puzzle.set_script(load(def[1]))
		add_child(puzzle)
	_add_location_trigger(Vector3(0, 0, 15), 6.0, "The Landing")
	_add_location_trigger(Vector3(-11, 0, -1), 8.0, "The Lagoon")
	_add_location_trigger(Vector3(-11, 0.8, -7), 4.0, "The Peace Bridge")
	_add_location_trigger(Vector3(14, 0, 1), 6.0, "The Gopher Lawn")
	_add_location_trigger(Vector3(8, 0, 5), 5.0, "The Bandstand")
	_add_location_trigger(Vector3(0, 0, -27), 7.0, "The Off-Leash Meadow")

# --- terrain & waters ---

func _coast_radius(theta: float) -> float:
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
	var h := 0.35 * (1.0 - smoothstep(coast - 4.0, coast - 1.5, d))
	# The lagoon hollow.
	var lag := Vector2(x, z) - LAGOON_CENTER
	var lag_d := Vector2(lag.x / LAGOON_RADII.x, lag.y / LAGOON_RADII.y).length()
	h -= 1.15 * (1.0 - smoothstep(0.55, 1.0, lag_d))
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
	sm.shader = load("res://shaders/park_island.gdshader")
	sm.set_shader_parameter("noise_tex", _noise_tex(31, 0.06))
	sm.set_shader_parameter("detail_normal", _noise_tex(311, 0.15, true))
	sm.set_shader_parameter("base_radius", COAST_BASE)
	sm.set_shader_parameter("path_radius", PATH_R)
	sm.set_shader_parameter("lagoon_center", LAGOON_CENTER)
	sm.set_shader_parameter("lagoon_radii", LAGOON_RADII)
	terrain.material_override = sm
	add_child(terrain)
	terrain.create_trimesh_collision()

func _build_water() -> void:
	# The Bow: milky glacier turquoise.
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	sm.set_shader_parameter("wave_normal1", _noise_tex(81, 0.08, true))
	sm.set_shader_parameter("wave_normal2", _noise_tex(82, 0.13, true))
	sm.set_shader_parameter("shore_radius", COAST_BASE)
	sm.set_shader_parameter("coast_wobble", 1.0)
	sm.set_shader_parameter("shallow_color", Color(0.45, 0.78, 0.74))
	sm.set_shader_parameter("deep_color", Color(0.05, 0.32, 0.34))
	sm.set_shader_parameter("wave_height", 0.07)
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

func _build_lagoon() -> void:
	# Still water in the hollow, with a slow drift.
	var pond := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.08
	pond.mesh = disc
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/river.gdshader")
	m.set_shader_parameter("flow_noise", _noise_tex(313, 0.1))
	m.set_shader_parameter("flow_speed", 0.05)
	m.set_shader_parameter("col_water", Color(0.4, 0.7, 0.68))
	pond.material_override = m
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond.position = Vector3(LAGOON_CENTER.x, -0.12, LAGOON_CENTER.y)
	pond.scale = Vector3(LAGOON_RADII.x * 0.92, 1.0, LAGOON_RADII.y * 0.92)
	add_child(pond)

# --- the Peace Bridge ---

func _build_peace_bridge() -> void:
	# The red lattice tube, arched over the lagoon's short axis. One smooth
	# ribbon deck (no segment gaps), continuous red rails, leaning lattice
	# ribs, and hoops for the tube silhouette.
	var from_z := LAGOON_CENTER.y - LAGOON_RADII.y - 1.5
	var to_z := LAGOON_CENTER.y + LAGOON_RADII.y + 1.5
	var x := LAGOON_CENTER.x
	var samples := 25
	var deck_y := func(t: float) -> float:
		return 0.3 + 0.95 * sin(t * PI)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in samples - 1:
		var t0 := i / float(samples - 1)
		var t1 := (i + 1) / float(samples - 1)
		var z0 := lerpf(from_z, to_z, t0)
		var z1 := lerpf(from_z, to_z, t1)
		var y0: float = deck_y.call(t0)
		var y1: float = deck_y.call(t1)
		var l0 := Vector3(x - 1.1, y0, z0)
		var r0 := Vector3(x + 1.1, y0, z0)
		var l1 := Vector3(x - 1.1, y1, z1)
		var r1 := Vector3(x + 1.1, y1, z1)
		for p: Vector3 in [l0, r0, r1, l0, r1, l1]:
			st.set_uv(Vector2(p.x, p.z) * 0.3)
			st.add_vertex(p)
	st.generate_normals()
	var deck := MeshInstance3D.new()
	deck.mesh = st.commit()
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.88, 0.88, 0.9)
	dm.roughness = 0.6
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	deck.material_override = dm
	add_child(deck)
	deck.create_trimesh_collision()
	# Continuous rails and lattice ribs along the curve.
	for i in samples - 1:
		var t0 := i / float(samples - 1)
		var t1 := (i + 1) / float(samples - 1)
		var z0 := lerpf(from_z, to_z, t0)
		var z1 := lerpf(from_z, to_z, t1)
		var y0: float = deck_y.call(t0)
		var y1: float = deck_y.call(t1)
		var length := Vector2(z1 - z0, y1 - y0).length() + 0.06
		for s in [-1.0, 1.0]:
			var rail := _add_box(Vector3(0.08, 0.08, length),
					Vector3(x + s * 1.08, (y0 + y1) / 2.0 + 1.02, (z0 + z1) / 2.0), BRIDGE_RED, false)
			rail.rotation.x = -atan2(y1 - y0, z1 - z0)
			if i % 3 == 0:
				var rib := _add_box(Vector3(0.055, 1.15, 0.055),
						Vector3(x + s * 1.08, (y0 + y1) / 2.0 + 0.52, (z0 + z1) / 2.0), BRIDGE_RED, false)
				rib.rotation.x = 0.45 if (i / 3) % 2 == 0 else -0.45
	# Hoops overhead: the tube silhouette.
	for k in 4:
		var t := (k + 0.5) / 4.0
		var hz := lerpf(from_z, to_z, t)
		var hy: float = deck_y.call(t)
		var hoop := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.42
		torus.outer_radius = 1.5
		hoop.mesh = torus
		hoop.material_override = _mat(BRIDGE_RED)
		hoop.rotation.x = PI / 2.0
		hoop.position = Vector3(x, hy + 1.05, hz)
		add_child(hoop)

# --- the skyline across the water ---

func _build_skyline() -> void:
	var base := Vector3(170.0, 0.0, 148.0)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.68, 0.76)
	glass.emission_enabled = true
	glass.emission = Color(0.68, 0.76, 0.84)
	glass.emission_energy_multiplier = 0.2
	for def: Array in [
		[Vector3(-24, 0, 8), Vector3(7, 26, 7)], [Vector3(-10, 0, -4), Vector3(8, 34, 8)],
		[Vector3(6, 0, 6), Vector3(6, 22, 6)], [Vector3(30, 0, -2), Vector3(9, 30, 9)],
		[Vector3(44, 0, 10), Vector3(6, 18, 6)],
	]:
		var t := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = def[1]
		t.mesh = box
		t.material_override = glass
		t.position = base + (def[0] as Vector3) + Vector3(0, (def[1] as Vector3).y / 2.0 - 1.0, 0)
		add_child(t)
	# The Calgary Tower: shaft, observation pod, spire.
	_add_mesh(_cyl(1.6, 2.4, 30.0), base + Vector3(16, 14.0, 2), Color(0.72, 0.7, 0.68), false)
	_add_mesh(_cyl(3.6, 3.0, 3.6), base + Vector3(16, 31.0, 2), Color(0.75, 0.3, 0.24), false)
	_add_mesh(_cyl(0.2, 0.5, 5.0), base + Vector3(16, 35.0, 2), Color(0.72, 0.7, 0.68), false)
	# The Saddledome: squat bowl with a saddle-dipped roof.
	var bowl := _add_mesh(_cyl(8.0, 9.5, 5.0), base + Vector3(-38, 1.5, 16), Color(0.66, 0.62, 0.58), false)
	bowl.scale = Vector3(1.3, 1.0, 1.0)
	for s in [-1.0, 1.0]:
		var roof := _add_box(Vector3(13.0, 0.5, 6.2), base + Vector3(-38, 4.6, 16 + s * 3.4),
				Color(0.85, 0.84, 0.8), false)
		roof.rotation.x = s * 0.3

# --- landing, meadow, park furniture ---

func _build_dock() -> void:
	for i in 6:
		_add_box(Vector3(2.4, 0.15, 1.7), Vector3(0, 0.28 - i * 0.012, 40.0 + i * 1.8), Color(0.55, 0.45, 0.36))
	for side in [-1.0, 1.0]:
		for i in 3:
			_add_mesh(_cyl(0.12, 0.14, 1.6), Vector3(side * 1.1, -0.15, 41.0 + i * 4.0), Color(0.42, 0.35, 0.28))
	var canoe := MeshInstance3D.new()
	canoe.name = "Canoe"
	var cb := CapsuleMesh.new()
	cb.radius = 0.55
	cb.height = 3.6
	canoe.mesh = cb
	canoe.material_override = _mat(Color(0.65, 0.3, 0.25))
	canoe.position = Vector3(3.2, 0.32, 38.5)
	canoe.rotation.z = PI / 2.0
	canoe.rotation.y = 0.4
	canoe.scale = Vector3(1.0, 1.0, 0.55)
	add_child(canoe)
	var paddle := _add_box(Vector3(0.08, 0.08, 1.5), Vector3(4.4, 0.4, 38.0), WOOD, false)
	paddle.rotation.y = 0.7

func _build_dog_park() -> void:
	# The off-leash meadow: chain-link on green posts, a gate that will not
	# open for strangers, the one great cottonwood, and the memorial stone.
	var post_col := PARK_GREEN
	for def: Array in [
		[Vector3(14.0, 0.05, 0.06), Vector3(0, 1.0, -31.0)],
		[Vector3(0.06, 0.05, 8.0), Vector3(-7.0, 1.0, -27.0)],
		[Vector3(0.06, 0.05, 8.0), Vector3(7.0, 1.0, -27.0)],
		[Vector3(5.2, 0.05, 0.06), Vector3(-4.4, 1.0, -23.0)],
		[Vector3(5.2, 0.05, 0.06), Vector3(4.4, 1.0, -23.0)],
	]:
		# Top rail plus a translucent "mesh" panel below it.
		_add_box(def[0], def[1] as Vector3, post_col)
		var panel_size: Vector3 = def[0]
		panel_size.y = 0.95
		var panel := _add_box(panel_size, (def[1] as Vector3) - Vector3(0, 0.5, 0),
				Color(0.55, 0.6, 0.58, 0.35))
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for px in [-7.0, -3.5, 0.0, 3.5, 7.0]:
		_add_box(Vector3(0.09, 1.15, 0.09), Vector3(px, 0.92, -31.0), post_col)
		_add_box(Vector3(0.09, 1.15, 0.09), Vector3(px, 0.92, -23.0), post_col)
	for pz in [-26.0, -29.0]:
		_add_box(Vector3(0.09, 1.15, 0.09), Vector3(-7.0, 0.92, pz), post_col)
		_add_box(Vector3(0.09, 1.15, 0.09), Vector3(7.0, 0.92, pz), post_col)
	# The gate, closed, with its arch and a sun-bleached notice board.
	var gate := _add_box(Vector3(1.7, 1.1, 0.08), Vector3(0, 0.9, -23.0), post_col.darkened(0.1))
	gate.name = "MeadowGate"
	for gx in [-0.95, 0.95]:
		_add_box(Vector3(0.14, 2.2, 0.14), Vector3(gx, 1.35, -23.0), post_col)
	_add_box(Vector3(2.2, 0.3, 0.16), Vector3(0, 2.55, -23.0), WOOD)
	# A sun-bleached notice board hanging from the arch.
	_add_box(Vector3(0.8, 0.55, 0.05), Vector3(0, 2.1, -23.06), Color(0.92, 0.88, 0.78), false)
	for cx in [-0.3, 0.3]:
		_add_box(Vector3(0.03, 0.2, 0.03), Vector3(cx, 2.45, -23.06), WOOD.darkened(0.2), false)
	# The great cottonwood, the memorial stone in its shade, and a water bowl.
	_cottonwood(Vector3(0, 0.35, -27.0), 2.4)
	var stone := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.8, 0.55, 0.3)
	stone.mesh = sb
	stone.material_override = _mat(STONE)
	stone.name = "MemorialStone"
	stone.position = Vector3(1.8, 0.6, -27.6)
	stone.rotation.y = -0.3
	stone.rotation.x = -0.08
	add_child(stone)
	stone.create_trimesh_collision()
	_add_mesh(_cyl(0.22, 0.26, 0.12), Vector3(-1.2, 0.42, -23.8), Color(0.3, 0.5, 0.75))
	# Two tennis balls the grass half swallowed.
	for bp: Vector3 in [Vector3(-2.6, 0.42, -26.2), Vector3(3.4, 0.42, -29.0)]:
		var ball := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.09
		bs.height = 0.18
		ball.mesh = bs
		ball.material_override = _mat(Color(0.8, 0.9, 0.3))
		ball.position = bp
		add_child(ball)

func _build_bandstand() -> void:
	var origin := Vector3(8, 0.35, 5)
	_add_mesh(_cyl(2.7, 2.9, 0.35), origin + Vector3(0, 0.17, 0), Color(0.72, 0.66, 0.58))
	for k in 6:
		var a := TAU * k / 6.0
		_add_box(Vector3(0.14, 2.3, 0.14), origin + Vector3(cos(a) * 2.3, 1.5, sin(a) * 2.3), PARK_GREEN)
	var roof := _add_mesh(_cyl(0.05, 3.2, 1.3), origin + Vector3(0, 3.3, 0), Color(0.3, 0.5, 0.5), false)
	var _keep := roof
	_add_mesh(_cyl(0.05, 0.12, 0.4), origin + Vector3(0, 4.1, 0), Color(0.85, 0.75, 0.4), false)

func _build_ice_cream_cart() -> void:
	var origin := Vector3(3, 0.35, 14)
	var cart := _add_box(Vector3(1.7, 1.1, 0.95), origin + Vector3(0, 0.8, 0), Color(0.94, 0.93, 0.9))
	var _keep := cart
	_add_box(Vector3(1.7, 0.16, 0.95), origin + Vector3(0, 1.42, 0), Color(0.85, 0.35, 0.35), false)
	for s in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		wheel.mesh = _cyl(0.28, 0.28, 0.08)
		wheel.material_override = _mat(Color(0.25, 0.25, 0.28))
		wheel.rotation.z = PI / 2.0
		wheel.position = origin + Vector3(s * 0.7, 0.28, 0.42)
		add_child(wheel)
	_add_box(Vector3(0.06, 0.06, 0.9), origin + Vector3(-1.0, 0.95, -0.2), Color(0.6, 0.58, 0.55), false)
	# The bell with no clapper, and the striped parasol.
	_add_mesh(_cyl(0.12, 0.16, 0.14), origin + Vector3(0.45, 1.6, 0.2), Color(0.8, 0.66, 0.3), false)
	_add_mesh(_cyl(0.03, 0.03, 1.9), origin + Vector3(-0.4, 2.3, -0.1), Color(0.5, 0.48, 0.46), false)
	var top := _add_mesh(_cyl(0.02, 1.15, 0.45), origin + Vector3(-0.4, 3.3, -0.1), Color(0.85, 0.4, 0.38), false)
	var _keep2 := top

func _build_furnishings() -> void:
	# Benches around the path ring, facing the lawn.
	for a: float in [2.7, 3.6, 4.4, 5.2, 6.0]:
		var p := Vector3(cos(a) * (PATH_R + 2.2), 0.35, sin(a) * (PATH_R + 2.2))
		_bench(p, atan2(-p.x, -p.z))
	# Picnic tables on the east lawn.
	for tp: Vector3 in [Vector3(13, 0.35, 6.5), Vector3(18, 0.35, 0.5), Vector3(11, 0.35, -4.5)]:
		_picnic_table(tp)
	# Flower beds flanking the dock path and the ring.
	var flower_colors := [Color(0.85, 0.3, 0.3), Color(0.9, 0.75, 0.3), Color(0.6, 0.4, 0.75), Color(0.9, 0.5, 0.6)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	for def: Vector3 in [Vector3(-3.2, 0, 17), Vector3(3.2, 0, 20), Vector3(-14, 0, 9),
			Vector3(9, 0, -13), Vector3(-4, 0, -15)]:
		_add_box(Vector3(2.0, 0.35, 1.2), def + Vector3(0, 0.5, 0), Color(0.55, 0.48, 0.4))
		for k in 7:
			var f := MeshInstance3D.new()
			var fs := SphereMesh.new()
			fs.radius = 0.09
			fs.height = 0.18
			f.mesh = fs
			f.material_override = _mat(flower_colors[rng.randi_range(0, flower_colors.size() - 1)])
			f.position = def + Vector3(rng.randf_range(-0.8, 0.8), 0.75, rng.randf_range(-0.4, 0.4))
			add_child(f)

func _bench(pos: Vector3, yrot: float) -> void:
	var bench := Node3D.new()
	bench.position = pos
	bench.rotation.y = yrot
	add_child(bench)
	for part: Array in [[Vector3(1.5, 0.07, 0.45), Vector3(0, 0.45, 0), 0.0],
			[Vector3(1.5, 0.5, 0.06), Vector3(0, 0.75, -0.24), -0.15]]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mi.mesh = box
		mi.material_override = _mat(PARK_GREEN)
		mi.position = part[1]
		mi.rotation.x = part[2]
		bench.add_child(mi)
		mi.create_trimesh_collision()
	for s in [-0.6, 0.6]:
		var leg := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.08, 0.45, 0.4)
		leg.mesh = lb
		leg.material_override = _mat(Color(0.25, 0.27, 0.26))
		leg.position = Vector3(s, 0.22, 0)
		bench.add_child(leg)

func _picnic_table(pos: Vector3) -> void:
	_add_box(Vector3(1.8, 0.08, 0.9), pos + Vector3(0, 0.78, 0), WOOD)
	for s in [-1.0, 1.0]:
		_add_box(Vector3(1.8, 0.07, 0.3), pos + Vector3(0, 0.45, s * 0.72), WOOD)
		_add_box(Vector3(0.09, 0.78, 0.8), pos + Vector3(s * 0.75, 0.39, 0), WOOD.darkened(0.15))

# --- green things ---

func _scatter_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 26:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(20.0, 38.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if p.z > 12.0 and absf(p.x) < 7.0:
			continue  # dock approach stays open
		if p.z < -21.0 and absf(p.x) < 9.0:
			continue  # the meadow keeps its one tree
		var lag := Vector2(p.x - LAGOON_CENTER.x, p.z - LAGOON_CENTER.y)
		if Vector2(lag.x / LAGOON_RADII.x, lag.y / LAGOON_RADII.y).length() < 1.35:
			continue
		var h := _terrain_height(p.x, p.z)
		if h < 0.3:
			continue
		if rng.randf() < 0.7:
			_cottonwood(Vector3(p.x, h, p.z), rng.randf_range(0.9, 1.6))
		else:
			_spruce(Vector3(p.x, h, p.z), rng.randf_range(0.8, 1.3))

func _cottonwood(pos: Vector3, s: float) -> void:
	var trunk := _add_mesh(_cyl(0.16 * s, 0.24 * s, 2.1 * s), pos + Vector3(0, 1.05 * s, 0), Color(0.45, 0.4, 0.34))
	var _keep := trunk
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(pos.x * 13.0 + pos.z * 29.0)) + 7
	for def: Array in [[Vector3(0, 2.6, 0), 1.35], [Vector3(0.8, 2.2, 0.4), 0.95],
			[Vector3(-0.7, 2.3, -0.35), 0.9], [Vector3(0.1, 3.1, -0.2), 0.85]]:
		var blob := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = (def[1] as float) * s
		bs.height = (def[1] as float) * 1.7 * s
		blob.mesh = bs
		blob.material_override = _mat(Color(0.3, 0.52, 0.26).lightened(rng.randf_range(0.0, 0.12)))
		blob.position = pos + (def[0] as Vector3) * s
		add_child(blob)

func _spruce(pos: Vector3, s: float) -> void:
	_add_mesh(_cyl(0.1 * s, 0.14 * s, 0.8 * s), pos + Vector3(0, 0.4 * s, 0), Color(0.35, 0.26, 0.2))
	for tier in 3:
		var cone := MeshInstance3D.new()
		cone.mesh = _cyl(0.02, (1.15 - tier * 0.28) * s, 1.0 * s)
		cone.material_override = _mat(Color(0.18, 0.38, 0.26))
		cone.position = pos + Vector3(0, (0.9 + tier * 0.62) * s, 0)
		add_child(cone)

func _scatter_grass_blades() -> void:
	var blade := SurfaceTool.new()
	blade.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rot: float in [0.0, PI / 2.0]:
		var basis := Basis(Vector3.UP, rot)
		for v: Vector3 in [Vector3(-0.03, 0, 0), Vector3(0.03, 0, 0), Vector3(0, 0.19, 0)]:
			blade.set_normal(Vector3.UP)
			blade.add_vertex(basis * v)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade.commit()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var transforms: Array[Transform3D] = []
	var attempts := 0
	while transforms.size() < 11000 and attempts < 70000:
		attempts += 1
		var x := rng.randf_range(-42.0, 42.0)
		var z := rng.randf_range(-42.0, 42.0)
		var d := Vector2(x, z).length()
		var theta := atan2(z, x)
		if d > _coast_radius(theta) - 5.0:
			continue
		var h := _terrain_height(x, z)
		if h < 0.3 or h > 0.45:
			continue
		var ang_gap := absf(wrapf(theta - PI / 2.0, -PI, PI))
		if absf(d - PATH_R) < 2.0 and ang_gap > 0.5:
			continue  # the path ring
		if absf(x) < 2.2 and (z > 13.0 or z < -15.0):
			continue  # the two gravel spurs
		var lag := Vector2(x - LAGOON_CENTER.x, z - LAGOON_CENTER.y)
		if Vector2(lag.x / LAGOON_RADII.x, lag.y / LAGOON_RADII.y).length() < 1.3:
			continue
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU))
				.scaled(Vector3.ONE * rng.randf_range(0.75, 1.25)), Vector3(x, h, z)))
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass_blade.gdshader")
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _build_fluff() -> void:
	# Cottonwood fluff riding the Bow breeze: the island's signature air.
	var fluff := CPUParticles3D.new()
	fluff.amount = 160
	fluff.lifetime = 12.0
	fluff.preprocess = 12.0
	fluff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fluff.emission_box_extents = Vector3(46.0, 4.0, 46.0)
	fluff.position = Vector3(0, 3.5, 0)
	fluff.direction = Vector3(1, 0, 0)
	fluff.spread = 30.0
	fluff.gravity = Vector3(0.35, -0.06, 0.12)
	fluff.initial_velocity_min = 0.2
	fluff.initial_velocity_max = 0.6
	var mote := QuadMesh.new()
	mote.size = Vector2(0.07, 0.07)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.98, 0.98, 0.95, 0.8)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote.material = mm
	fluff.mesh = mote
	add_child(fluff)

# --- small lives ---

func _spawn_ducks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	var mother := _duck(0.22, Color(0.55, 0.42, 0.3))
	mother.position = Vector3(LAGOON_CENTER.x, -0.05, LAGOON_CENTER.y)
	add_child(mother)
	var flotilla: Array[Node3D] = [mother]
	for i in 3:
		var duckling := _duck(0.1, Color(0.92, 0.85, 0.4))
		duckling.position = mother.position + Vector3(-0.5 - i * 0.4, 0, 0.2 * (i % 2))
		add_child(duckling)
		flotilla.append(duckling)
	# The flotilla laps the lagoon, ducklings trailing on a delay.
	for idx in flotilla.size():
		var bird := flotilla[idx]
		var tw := bird.create_tween().set_loops()
		for k in 6:
			var a := TAU * k / 6.0
			var wp := Vector3(LAGOON_CENTER.x + cos(a) * (LAGOON_RADII.x * 0.5),
					-0.05, LAGOON_CENTER.y + sin(a) * (LAGOON_RADII.y * 0.5))
			tw.tween_property(bird, "position", wp, 4.0 + idx * 0.35) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _duck(size: float, body_col: Color) -> Node3D:
	var duck := Node3D.new()
	var body := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = size
	bs.height = size * 1.5
	body.mesh = bs
	body.scale = Vector3(1.0, 1.0, 1.5)
	body.material_override = _mat(body_col)
	duck.add_child(body)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = size * 0.55
	hs.height = size * 1.1
	head.mesh = hs
	head.material_override = _mat(body_col.darkened(0.2))
	head.position = Vector3(0, size * 0.9, size * 1.1)
	duck.add_child(head)
	var bill := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(size * 0.5, size * 0.2, size * 0.5)
	bill.mesh = bb
	bill.material_override = _mat(Color(0.9, 0.6, 0.2))
	bill.position = Vector3(0, size * 0.8, size * 1.6)
	duck.add_child(bill)
	return duck

func _spawn_gophers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5050
	for i in 6:
		var p := Vector3(rng.randf_range(9.0, 20.0), 0.36, rng.randf_range(-6.0, 8.0))
		_gopher_mounds.append(p)
		_add_mesh(_cyl(0.4, 0.5, 0.1), p, Color(0.62, 0.52, 0.4), false)
		var hole := _add_mesh(_cyl(0.16, 0.16, 0.05), p + Vector3(0, 0.06, 0), Color(0.15, 0.12, 0.1), false)
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gopher_loop(rng.randi())

func _gopher_loop(seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var loop := func() -> void:
		while is_inside_tree():
			await get_tree().create_timer(rng.randf_range(3.0, 7.0)).timeout
			if not is_inside_tree() or _gopher_mounds.is_empty():
				return
			var p := _gopher_mounds[rng.randi_range(0, _gopher_mounds.size() - 1)]
			var gopher := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.09
			cap.height = 0.34
			gopher.mesh = cap
			gopher.material_override = _mat(Color(0.55, 0.42, 0.28))
			gopher.position = p + Vector3(0, -0.12, 0)
			add_child(gopher)
			var tw := gopher.create_tween()
			tw.tween_property(gopher, "position:y", p.y + 0.22, 0.25) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(rng.randf_range(0.8, 2.0))
			tw.tween_property(gopher, "position:y", p.y - 0.14, 0.2) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(gopher.queue_free)
	loop.call()

func _spawn_butterflies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var colors := [Color(0.95, 0.85, 0.3), Color(0.9, 0.55, 0.2), Color(0.6, 0.5, 0.9)]
	for i in 6:
		var b := Node3D.new()
		var wing_mat := StandardMaterial3D.new()
		wing_mat.albedo_color = colors[i % colors.size()]
		wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for side in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.12, 0.16)
			w.mesh = q
			w.material_override = wing_mat
			w.position = Vector3(0.06 * side, 0, 0)
			w.rotation.x = -PI / 2.0
			b.add_child(w)
		var r := rng.randf_range(10.0, 22.0)
		var a := rng.randf_range(0.0, TAU)
		var home := Vector3(cos(a) * r, rng.randf_range(0.8, 1.5), sin(a) * r)
		b.position = home
		add_child(b)
		var path := b.create_tween().set_loops()
		for k in 4:
			var wp := home + Vector3(rng.randf_range(-3.0, 3.0),
					rng.randf_range(-0.3, 0.5), rng.randf_range(-3.0, 3.0))
			path.tween_property(b, "position", wp, rng.randf_range(2.0, 3.5)) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		path.tween_property(b, "position", home, 2.5).set_trans(Tween.TRANS_SINE)
		var flap := b.create_tween().set_loops()
		flap.tween_property(b, "scale:x", 0.45, 0.09)
		flap.tween_property(b, "scale:x", 1.0, 0.09)

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
