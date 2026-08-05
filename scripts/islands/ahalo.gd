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
	_build_river()
	_scatter_trees()
	_scatter_rocks()
	_scatter_flora()
	_scatter_beach_details()
	_spawn_butterflies()
	_place_pickups()
	_add_location_trigger(Vector3(0, 0, 33), 8.0, "South Beach")
	_add_location_trigger(Vector3(33, 0, -4), 9.0, "Echo Cove")
	_add_location_trigger(Vector3(-14.5, 0, 4.4), 8.0, "The Hillside Den")
	_add_location_trigger(Vector3(0, 3.3, 0), 7.0, "The Old Summit")

## The island's coastline, shared analytically with the terrain and water
## shaders so mesh, wet band, and foam all agree. The southern sector is
## damped flat: that's the boat channel.
func _coast_radius(theta: float) -> float:
	var wob := 2.6 * sin(3.0 * theta + 1.7) + 1.7 * sin(5.0 * theta + 4.2) \
			+ 1.1 * sin(8.0 * theta + 0.9)
	var d := absf(wrapf(theta - PI / 2.0, -PI, PI))
	wob *= smoothstep(0.55, 1.1, d)
	return 40.0 + wob

## Terraced height field: beach 0, grass 0.3, tiers 1.3 / 2.3 / 3.3 — the
## same height contract the puzzles were built on, with steep (jump-only)
## terrace lips and a walkable grass ramp.
func _terrain_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var theta := atan2(z, x)
	var coast := _coast_radius(theta)
	if d >= coast:
		return -6.0 * clampf((d - coast) / 12.0, 0.0, 1.0)
	var grass_r := coast * 0.74
	var h := 0.3 * (1.0 - smoothstep(grass_r - 2.0, grass_r - 0.4, d))
	h += 1.0 * (1.0 - smoothstep(12.6, 13.4, d))
	h += 1.0 * (1.0 - smoothstep(9.0, 9.7, d))
	h += 1.0 * (1.0 - smoothstep(5.7, 6.4, d))
	return h

func _build_island() -> void:
	_sand_mat = _terrain_material()
	_grass_mat = _sand_mat
	# One sculpted terrain mesh replaces the old cylinder stack.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 140
	var span := 108.0
	var step := span / (n - 1)
	var heights := []
	for iz in n:
		var row := PackedFloat32Array()
		for ix in n:
			var x := -span / 2.0 + ix * step
			var z := -span / 2.0 + iz * step
			row.append(_terrain_height(x, z))
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
	terrain.material_override = _sand_mat
	add_child(terrain)
	terrain.create_trimesh_collision()
	_scatter_outcrops()
	_scatter_dunes()

## The creek: a spring pond on the first terrace spills over the lip as a
## small waterfall, then winds northwest across the grass to the sea. The
## ribbon drapes over the analytic height field, so it follows the terraces.
const RIVER_XZ: Array[Vector2] = [
	Vector2(-8.8, -6.8), Vector2(-10.3, -7.9), Vector2(-11.8, -9.0),
	Vector2(-14.0, -11.0), Vector2(-16.5, -12.2), Vector2(-19.5, -12.8),
	Vector2(-22.5, -14.2), Vector2(-25.5, -16.2), Vector2(-29.0, -18.5),
	Vector2(-33.0, -21.0), Vector2(-36.0, -23.0),
]

func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _river_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/river.gdshader")
	m.set_shader_parameter("flow_noise", _noise_tex(212, 0.1))
	return m

func _build_river() -> void:
	var river_mat := _river_material()
	# Densify the path with Catmull-Rom so the ribbon bends smoothly.
	var pts: Array[Vector2] = []
	var n_seg := RIVER_XZ.size() - 1
	for i in n_seg:
		var p0 := RIVER_XZ[maxi(i - 1, 0)]
		var p3 := RIVER_XZ[mini(i + 2, RIVER_XZ.size() - 1)]
		for k in 10:
			pts.append(_catmull(p0, RIVER_XZ[i], RIVER_XZ[i + 1], p3, k / 10.0))
	pts.append(RIVER_XZ[-1])
	# Ribbon vertices: left/right banks, draped over the terrain. On steep
	# stretches the analytic height can dip under the coarser render mesh,
	# so the drape offset grows with the local drop.
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var us: Array[float] = []
	var arc := 0.0
	for i in pts.size():
		var p := pts[i]
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var dir := (next - prev).normalized()
		var side := Vector2(-dir.y, dir.x)
		if i > 0:
			arc += (p - prev).length()
		var drop := absf(_terrain_height(prev.x, prev.y) - _terrain_height(next.x, next.y))
		var lift := 0.08 + clampf(drop * 0.55, 0.0, 0.34)
		var w := 0.55 + 0.25 * sin(arc * 0.31 + 1.1) + arc * 0.008
		for pair: Array in [[left, 1.0], [right, -1.0]]:
			var q: Vector2 = p + side * w * (pair[1] as float)
			var y := maxf(_terrain_height(q.x, q.y), -0.5) + lift
			(pair[0] as Array[Vector3]).append(Vector3(q.x, y, q.y))
		us.append(arc * 0.22)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var quad: Array = [
			[left[i], 0.0, us[i]], [right[i], 1.0, us[i]], [right[i + 1], 1.0, us[i + 1]],
			[left[i], 0.0, us[i]], [right[i + 1], 1.0, us[i + 1]], [left[i + 1], 0.0, us[i + 1]],
		]
		for v: Array in quad:
			st.set_uv(Vector2(v[2], v[1]))
			st.add_vertex(v[0])
	st.generate_normals()
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = st.commit()
	ribbon.material_override = river_mat
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ribbon)
	# The spring pond feeding it.
	var pond := MeshInstance3D.new()
	var pond_mesh := CylinderMesh.new()
	pond_mesh.top_radius = 1.25
	pond_mesh.bottom_radius = 1.25
	pond_mesh.height = 0.1
	pond.mesh = pond_mesh
	var pond_mat := _river_material()
	pond_mat.set_shader_parameter("flow_speed", 0.07)
	pond.material_override = pond_mat
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond.position = Vector3(-8.8, 1.34, -6.8)
	add_child(pond)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var rocks: Array = [load("res://assets/nature/rock_smallA.glb"),
			load("res://assets/nature/rock_smallB.glb")]
	for i in 7:  # a rim of stones around the spring
		var a := TAU * i / 7.0 + rng.randf_range(-0.15, 0.15)
		var pos := Vector3(-8.8 + cos(a) * 1.5, 1.3, -6.8 + sin(a) * 1.5)
		_add_scene(rocks[rng.randi_range(0, rocks.size() - 1)], pos,
				rng.randf_range(0.0, TAU), rng.randf_range(0.55, 0.85), false)
	# Stepping stones where the brook crosses the meadow.
	for stone_xz: Vector2 in [Vector2(-16.5, -12.2), Vector2(-19.5, -12.8), Vector2(-25.5, -16.2)]:
		var sy := _terrain_height(stone_xz.x, stone_xz.y)
		var stone := _add_scene(rocks[rng.randi_range(0, rocks.size() - 1)],
				Vector3(stone_xz.x, sy + 0.02, stone_xz.y),
				rng.randf_range(0.0, TAU), rng.randf_range(1.0, 1.3), true)
		stone.scale.y *= 0.5
	# Water sounds, placed where the water works hardest.
	_add_ambient_loop("res://assets/audio/waterfall.wav", Vector3(-11.5, 0.8, -8.8), -6.0, 24.0)
	_add_ambient_loop("res://assets/audio/brook.wav", Vector3(-22.5, 0.4, -14.2), -10.0, 15.0)
	_add_location_trigger(Vector3(-11.8, 0.4, -9.0), 7.0, "The Falls")

func _add_ambient_loop(path: String, pos: Vector3, volume_db: float, max_dist: float) -> void:
	var stream: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2  # 16-bit mono: 2 bytes per frame
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.position = pos
	player.volume_db = volume_db
	player.max_distance = max_dist
	player.bus = "SFX"
	player.autoplay = true
	add_child(player)

func _terrain_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/island.gdshader")
	m.set_shader_parameter("noise_tex", _noise_tex(11, 0.06))
	m.set_shader_parameter("detail_normal", _noise_tex(111, 0.15, true))
	return m

## Rock outcrops along the terrace lips hide their circular geometry.
func _scatter_outcrops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 616
	var pools: Array = [load("res://assets/nature/rock_smallA.glb"),
			load("res://assets/nature/rock_smallB.glb"), load("res://assets/nature/rock_largeB.glb")]
	for def: Array in [[13.0, 10, 0.7], [9.35, 8, 1.7], [6.05, 6, 2.7]]:
		var radius: float = def[0]
		var count: int = def[1]
		var base_y: float = def[2]
		for i in count:
			var a := TAU * i / count + rng.randf_range(-0.2, 0.2)
			var pos := Vector3(cos(a) * radius, base_y + rng.randf_range(-0.1, 0.1), sin(a) * radius)
			_add_scene(pools[rng.randi_range(0, pools.size() - 1)], pos,
					rng.randf_range(0.0, TAU), rng.randf_range(1.3, 2.1), true)

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
	sm.set_shader_parameter("shore_radius", 40.0)
	sm.set_shader_parameter("coast_wobble", 1.0)
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
			var lean := rng.randf_range(-0.06, 0.06)
			t.rotation.z = lean
			# A slow breathing sway in the sea breeze.
			var amp := rng.randf_range(0.008, 0.02)
			var dur := rng.randf_range(2.2, 3.6)
			var sway := t.create_tween().set_loops()
			sway.tween_property(t, "rotation:z", lean + amp, dur) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			sway.tween_property(t, "rotation:z", lean - amp, dur) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
				_clear_channel(Vector3(cos(a) * r, 0.0, sin(a) * r)),
				rng.randf_range(0.0, TAU), rng.randf_range(1.5, 2.5), true)
	# Sea rocks poking above the surface — swim out and climb on.
	for i in 5:
		var r := rng.randf_range(43.0, 50.0)
		var a := rng.randf_range(0.0, TAU)
		_add_scene(big[rng.randi_range(0, big.size() - 1)],
				_clear_channel(Vector3(cos(a) * r, -0.8, sin(a) * r)),
				rng.randf_range(0.0, TAU), rng.randf_range(3.0, 4.0), true)

## The raft sails a fixed southern channel; any scattered rock that lands in
## it gets mirrored to the north side so nothing sits in the boat lane.
func _clear_channel(pos: Vector3) -> Vector3:
	if pos.z > 24.0 and absf(pos.x) < 22.0:
		pos.z = -pos.z
	return pos

func _scatter_flora() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var flora: Array = []
	for p: String in FLORA_PATHS:
		flora.append(load(p))
	for i in 140:
		var r := rng.randf_range(13.5, 28.5)
		var a := rng.randf_range(0.0, TAU)
		var tuft := _add_scene(flora[rng.randi_range(0, flora.size() - 1)],
				Vector3(cos(a) * r, 0.3, sin(a) * r),
				rng.randf_range(0.0, TAU), rng.randf_range(2.0, 3.0))
		if i % 3 == 0:
			var amp := rng.randf_range(0.03, 0.06)
			var dur := rng.randf_range(1.1, 1.9)
			var sway := tuft.create_tween().set_loops()
			sway.tween_property(tuft, "rotation:x", amp, dur) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			sway.tween_property(tuft, "rotation:x", -amp, dur) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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

func _scatter_beach_details() -> void:
	# Shells, starfish, and driftwood: the tideline's leavings.
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var shell_colors := [Color(0.95, 0.9, 0.82), Color(0.92, 0.78, 0.75), Color(0.85, 0.82, 0.7)]
	for i in 16:
		var r := rng.randf_range(31.5, 39.0)
		var a := rng.randf_range(0.0, TAU)
		var pos := _clear_channel(Vector3(cos(a) * r, 0.04, sin(a) * r))
		var shell := CylinderMesh.new()
		shell.top_radius = 0.0
		shell.bottom_radius = rng.randf_range(0.06, 0.1)
		shell.height = 0.05
		_add_mesh(shell, pos, shell_colors[i % shell_colors.size()], false)
	for i in 3:
		var r := rng.randf_range(32.0, 38.0)
		var a := rng.randf_range(0.0, TAU)
		var center := _clear_channel(Vector3(cos(a) * r, 0.04, sin(a) * r))
		for k in 5:
			var arm := BoxMesh.new()
			arm.size = Vector3(0.22, 0.03, 0.07)
			var mi := _add_mesh(arm, center, Color(0.9, 0.5, 0.3), false)
			mi.rotation.y = TAU * k / 5.0
			mi.position += Vector3(cos(TAU * k / 5.0), 0, sin(TAU * k / 5.0)) * 0.08
	for i in 4:
		var r := rng.randf_range(31.0, 37.0)
		var a := rng.randf_range(0.0, TAU)
		var pos := _clear_channel(Vector3(cos(a) * r, 0.12, sin(a) * r))
		var wood := CylinderMesh.new()
		wood.top_radius = rng.randf_range(0.09, 0.13)
		wood.bottom_radius = rng.randf_range(0.13, 0.18)
		wood.height = rng.randf_range(1.6, 2.6)
		var mi := _add_mesh(wood, pos, Color(0.55, 0.47, 0.4), true)
		mi.rotation.z = PI / 2.0
		mi.rotation.y = rng.randf_range(0.0, TAU)

func _spawn_butterflies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var colors := [Color(0.9, 0.55, 0.2), Color(0.6, 0.5, 0.9), Color(0.95, 0.85, 0.3)]
	for i in 8:
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
		var r := rng.randf_range(14.0, 27.0)
		var a := rng.randf_range(0.0, TAU)
		var home := Vector3(cos(a) * r, rng.randf_range(0.8, 1.5), sin(a) * r)
		b.position = home
		add_child(b)
		# Wander a small loop of waypoints forever.
		var path := b.create_tween().set_loops()
		for k in 4:
			var wp := home + Vector3(rng.randf_range(-3.0, 3.0),
					rng.randf_range(-0.3, 0.5), rng.randf_range(-3.0, 3.0))
			path.tween_property(b, "position", wp, rng.randf_range(2.0, 3.5)) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		path.tween_property(b, "position", home, 2.5).set_trans(Tween.TRANS_SINE)
		# Wing flap: pinch on x at speed.
		var flap := b.create_tween().set_loops()
		flap.tween_property(b, "scale:x", 0.45, 0.09)
		flap.tween_property(b, "scale:x", 1.0, 0.09)

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
