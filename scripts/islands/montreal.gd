extends Node3D
## Island 5 · Montréal — the mountain in autumn over a downtown of glass
## and grey stone. South: the Old Port dock on the river. Middle: the
## plaza, the Bell Centre with its four bronze legends, Place Ville
## Marie's beacon, the bagel oven, orange cones nobody moved, and a
## calèche horse asleep across the mountain road. North: Mont Royal
## climbing in terraces (tam-tam glade, staircases, the chalet and its
## belvedere, the great cross at the summit, dark), the old funicular on
## the west flank. Teaches: growl, and vertical patience.
##
## TERRACE CONTRACT (everything on the mountain hangs off this):
##   plain 0.35 · T1 y=4.0 (z -10..-14) · T2 chalet y=8.0 (z -19..-23)
##   T3 y=12.0 (z -28..-31) · summit y=15.0 (z -35..-42), |x| < 13.

const WATER_SURFACE_Y := -0.4
const COAST_BASE := 46.0

const TERRACES: Array = [
	# [z_start (south edge of the riser), z_flat (top of riser), height]
	[-4.0, -7.0, 4.0], [-14.0, -17.0, 8.0], [-23.0, -26.0, 12.0], [-31.0, -34.0, 15.0],
]
## Flight k climbs terrace k-1 → k. Foot (south) and head (north) points,
## all at x = 4 - 2k stagger so the zigzag reads from the balcony.
const FLIGHTS: Array = [
	# [foot xz, head xz, foot y, head y]
	[Vector2(3.0, -3.6), Vector2(3.0, -7.4), 0.35, 4.0],
	[Vector2(-2.0, -13.6), Vector2(-2.0, -17.4), 4.0, 8.0],
	[Vector2(3.0, -22.6), Vector2(3.0, -26.4), 8.0, 12.0],
	[Vector2(-2.0, -30.6), Vector2(-2.0, -34.4), 12.0, 15.0],
]
const CHALET_POS := Vector3(-6.0, 8.0, -20.5)
const CROSS_POS := Vector3(0.0, 15.0, -39.0)
const GLADE_POS := Vector3(15.0, 0.35, -1.0)
const OVEN_POS := Vector3(-14.0, 0.35, 4.0)
const HORSE_POS := Vector3(0.0, 0.35, -1.5)
const ARENA_POS := Vector3(16.0, 0.35, 20.0)
const FUNICULAR_TOP := Vector3(-10.0, 15.0, -37.0)
const FUNICULAR_BOTTOM := Vector3(-14.0, 0.45, 32.0)
## The funicular's rail, summit to river. tools/test_montreal.gd sweeps it.
const FUNICULAR_ROUTE: Array[Vector3] = [
	# West along the summit lip, then down the flank, hugging the terrain.
	Vector3(-10.0, 15.0, -37.0), Vector3(-14.2, 15.0, -33.0), Vector3(-19.0, 11.5, -27.0),
	Vector3(-23.0, 7.5, -19.0), Vector3(-25.5, 3.6, -9.0), Vector3(-26.0, 1.2, 3.0),
	Vector3(-22.0, 0.6, 18.0), Vector3(-14.0, 0.45, 32.0),
]

const STONE := Color(0.5, 0.49, 0.47)
const GRANITE_OUT := Color(0.44, 0.44, 0.46)
const GREYSTONE := Color(0.62, 0.6, 0.56)
const GLASS := Color(0.55, 0.66, 0.74)
const WOOD := Color(0.5, 0.38, 0.28)
const WOOD_PALE := Color(0.66, 0.56, 0.42)
const IRON := Color(0.22, 0.22, 0.24)
const MAPLE_COLORS := [Color(0.85, 0.28, 0.16), Color(0.92, 0.5, 0.14), Color(0.9, 0.7, 0.2), Color(0.72, 0.2, 0.14)]
const WARM_WINDOW := Color(1.0, 0.85, 0.55)
const CONE := Color(0.95, 0.45, 0.1)

var cross: Node3D
var chalet: Node3D
var arena: Node3D
var funicular_car: Node3D
var _materials := {}
var _visited_locations := {}
var _dusk := false
var _windows: Array[MeshInstance3D] = []
var _beacon: Node3D
var _fireflies: Array[Node3D] = []

func _ready() -> void:
	_build_island()
	_build_water()
	_build_dock()
	_build_downtown()
	_build_arena_exterior()
	_build_mountain_dressing()
	_build_chalet()
	_build_cross()
	_build_funicular()
	_build_maple_scatter()
	_build_leaf_fall()
	_build_quay_dressing()
	_build_horizon_icons()
	_build_outcrops_and_birches()
	_build_stair_lamps()
	_steeple_bells()
	_mountain_chitter()
	_autumn_light()
	_add_ambient_loop("res://assets/audio/ocean_loop.wav", Vector3(0, 0.5, 42), -14.0, 40.0)
	_add_location_trigger(Vector3(0, 0, 36), 8.0, "The Old Port")
	_add_location_trigger(Vector3(0, 0, 14), 9.0, "Downtown")
	_add_location_trigger(ARENA_POS, 8.0, "The Bell Centre")
	_add_location_trigger(GLADE_POS, 6.0, "The Tam-Tam Glade")
	_add_location_trigger(CHALET_POS + Vector3(0, 0, 3), 7.0, "The Belvedere")
	_add_location_trigger(CROSS_POS, 8.0, "The Summit")
	for def: Array in [
		["CalecheHorse", "res://scripts/puzzles/caleche_horse.gd"],
		["BagelStandard", "res://scripts/puzzles/bagel_standard.gd"],
		["ThreeStars", "res://scripts/puzzles/three_stars.gd"],
		["TamTamCircle", "res://scripts/puzzles/tam_tam_circle.gd"],
		["StaircaseShuffle", "res://scripts/puzzles/staircase_shuffle.gd"],
		["LightTheCross", "res://scripts/puzzles/light_the_cross.gd"],
	]:
		var puzzle := Node3D.new()
		puzzle.name = def[0]
		puzzle.set_script(load(def[1]))
		add_child(puzzle)
	if GameState.get_flag("island5_complete"):
		set_dusk(true)

func _process(delta: float) -> void:
	if _beacon:
		_beacon.rotation.y += delta * 0.9

# --- terrain & water ---

func _coast_radius(theta: float) -> float:
	var wob := 2.6 * sin(3.0 * theta + 1.7) + 1.7 * sin(5.0 * theta + 4.2) \
			+ 1.1 * sin(8.0 * theta + 0.9)
	var d := absf(wrapf(theta - PI / 2.0, -PI, PI))
	wob *= smoothstep(0.55, 1.1, d)
	return COAST_BASE + wob

## The mountain: stepped terraces along -z, steep flanks in x, steep back.
func mountain_height(x: float, z: float) -> float:
	if z > TERRACES[0][0]:
		return 0.35
	# Walk the terraces south→north: each riser climbs from the previous
	# top to its own over 3 m (steep: the stairs are the way up).
	var h := 0.35
	var prev := 0.35
	for t: Array in TERRACES:
		var z0: float = t[0]   # riser foot (south)
		var z1: float = t[1]   # riser head (north)
		var top: float = t[2]
		if z <= z1:
			h = top
		elif z <= z0:
			var s := clampf((z0 - z) / (z0 - z1), 0.0, 1.0)
			s = s * s * (3.0 - 2.0 * s)
			h = lerpf(prev, top, s)
		prev = top
	var lateral := 1.0 - smoothstep(12.5, 15.5, absf(x))
	var back := 1.0 - smoothstep(-42.0, -44.5, z)
	return maxf(0.35, lerpf(0.35, h, lateral * back))

func _terrain_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var theta := atan2(z, x)
	var coast := _coast_radius(theta)
	if d >= coast:
		return -6.0 * clampf((d - coast) / 12.0, 0.0, 1.0)
	var beach := 0.35 * (1.0 - smoothstep(coast - 4.0, coast - 1.5, d))
	var m := mountain_height(x, z)
	if m > 0.36:
		return m
	# The west flank's boulder scramble sits on a gentle rise.
	return beach

func _build_island() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 160
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
	sm.set_shader_parameter("noise_tex", _noise_tex(61, 0.06))
	sm.set_shader_parameter("detail_normal", _noise_tex(611, 0.15, true))
	sm.set_shader_parameter("base_radius", COAST_BASE)
	sm.set_shader_parameter("path_radius", 0.0)
	sm.set_shader_parameter("lawn_color", Color(0.46, 0.42, 0.24))   # autumn lawn
	sm.set_shader_parameter("lawn_alt", Color(0.6, 0.36, 0.18))      # fallen leaves
	sm.set_shader_parameter("gravel", GREYSTONE)
	sm.set_shader_parameter("river_stone", STONE)
	sm.set_shader_parameter("lagoon_center", Vector2(0.0, 200.0))     # no lagoon
	sm.set_shader_parameter("lagoon_radii", Vector2(1.0, 1.0))
	terrain.material_override = sm
	add_child(terrain)
	# Terrain is the ONE mesh that earns a trimesh: it is a heightfield the
	# player walks the top of, never the inside. Every prop is convex.
	terrain.create_trimesh_collision()
	# The downtown plaza: a flat grey slab over the plain (walkable).
	_add_box(Vector3(30.0, 0.1, 22.0), Vector3(2.0, 0.35, 16.0), Color(0.58, 0.57, 0.55))

func _build_water() -> void:
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
	sm.set_shader_parameter("shallow_color", Color(0.4, 0.46, 0.44))
	sm.set_shader_parameter("deep_color", Color(0.1, 0.16, 0.2))   # the St. Lawrence, steel-green
	sm.set_shader_parameter("wave_height", 0.05)
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

# --- the Old Port ---

func _build_dock() -> void:
	for i in 8:
		_add_box(Vector3(3.4, 0.16, 1.9), Vector3(0, 0.42 - i * 0.008, 29.5 + i * 1.85), WOOD)
	for side in [-1.0, 1.0]:
		for i in 4:
			_add_mesh(_cyl(0.14, 0.16, 2.2), Vector3(side * 1.55, -0.4, 30.5 + i * 4.2), WOOD_PALE)
	# The Old Port clock tower on the east quay.
	var tower := Node3D.new()
	tower.position = Vector3(9.0, 0.35, 34.0)
	add_child(tower)
	_child_box(tower, Vector3(2.4, 9.0, 2.4), Vector3(0, 4.5, 0), Color(0.9, 0.88, 0.82), true)
	_child_box(tower, Vector3(2.0, 1.6, 2.0), Vector3(0, 9.8, 0), Color(0.9, 0.88, 0.82), true)
	var cap := _child_mesh(tower, _cyl(0.0, 1.5, 1.6), Vector3(0, 11.4, 0), Color(0.36, 0.5, 0.48), false)
	var _k := cap
	for a: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var face := _child_mesh(tower, _cyl(0.55, 0.55, 0.06), Vector3(sin(a) * 1.02, 9.8, cos(a) * 1.02), Color(0.98, 0.97, 0.9), false)
		face.rotation.x = PI / 2.0
		face.rotation.z = -a
	# The funicular's lower station beside the west quay.
	var station := Node3D.new()
	station.name = "LowerStation"
	station.position = FUNICULAR_BOTTOM + Vector3(-3.2, 0, 0)
	add_child(station)
	_child_box(station, Vector3(2.4, 2.4, 3.0), Vector3(0, 1.2, 0), Color(0.5, 0.42, 0.34), true)
	_child_box(station, Vector3(2.8, 0.4, 3.4), Vector3(0, 2.6, 0), Color(0.36, 0.3, 0.26), true)

# --- downtown ---

func _build_downtown() -> void:
	# Place Ville Marie: the cruciform tower with the beacon on top.
	var pvm := Node3D.new()
	pvm.position = Vector3(-14.0, 0.35, 22.0)
	add_child(pvm)
	_child_box(pvm, Vector3(3.2, 22.0, 8.0), Vector3(0, 11.0, 0), GLASS, true)
	_child_box(pvm, Vector3(8.0, 22.0, 3.2), Vector3(0, 11.0, 0), GLASS, true)
	_beacon = Node3D.new()
	_beacon.position = Vector3(0, 22.4, 0)
	pvm.add_child(_beacon)
	for k in 4:
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.14, 0.14, 12.0)
		beam.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.95, 0.8, 0.5)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(1.0, 0.95, 0.75)
		m.emission_energy_multiplier = 1.4
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam.material_override = m
		beam.position = Vector3(0, 0, 6.0).rotated(Vector3.UP, k * PI / 2.0)
		beam.rotation.y = k * PI / 2.0
		_beacon.add_child(beam)
	# A few more towers, greystone and glass, back from the plaza.
	for def: Array in [
		[Vector3(-16.0, 0.35, 12.0), Vector3(5.0, 14.0, 5.0), GREYSTONE],
		[Vector3(-8.0, 0.35, 26.0), Vector3(4.0, 10.0, 4.0), Color(0.42, 0.5, 0.56)],
		[Vector3(24.0, 0.35, 30.0), Vector3(4.5, 16.0, 4.5), GLASS],
		[Vector3(30.0, 0.35, 8.0), Vector3(4.0, 9.0, 6.0), GREYSTONE],
	]:
		var body := _add_box(def[1], (def[0] as Vector3) + Vector3(0, (def[1] as Vector3).y / 2.0, 0), def[2])
		var _k := body
		# Warm windows in columns; they brighten at dusk.
		var h: float = (def[1] as Vector3).y
		for row in int(h / 2.5):
			for col in 2:
				var win := MeshInstance3D.new()
				var wm := BoxMesh.new()
				wm.size = Vector3(0.7, 0.9, 0.06)
				win.mesh = wm
				var wmat := StandardMaterial3D.new()
				wmat.albedo_color = WARM_WINDOW
				wmat.emission_enabled = true
				wmat.emission = Color(1.0, 0.82, 0.5)
				wmat.emission_energy_multiplier = 0.25
				win.material_override = wmat
				win.position = (def[0] as Vector3) + Vector3(-0.9 + col * 1.8, 1.6 + row * 2.5, (def[1] as Vector3).z / 2.0 + 0.04)
				add_child(win)
				_windows.append(win)
	# The bagel shop: a low brick box with a wood-fired oven mouth and the sign.
	var shop := Node3D.new()
	shop.name = "BagelShop"
	shop.position = OVEN_POS
	add_child(shop)
	_child_box(shop, Vector3(4.6, 3.0, 4.0), Vector3(0, 1.5, -2.6), Color(0.6, 0.36, 0.28), true)
	var oven := _child_box(shop, Vector3(1.6, 1.4, 1.2), Vector3(0, 0.7, -0.2), Color(0.34, 0.3, 0.28), true)
	oven.name = "Oven"
	var mouth := _child_mesh(shop, _cyl(0.4, 0.4, 0.1), Vector3(0, 0.75, 0.42), Color(0.95, 0.5, 0.15), false)
	mouth.name = "OvenMouth"
	mouth.rotation.x = PI / 2.0
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.95, 0.5, 0.15)
	mm.emission_enabled = true
	mm.emission = Color(1.0, 0.45, 0.1)
	mm.emission_energy_multiplier = 1.4
	mouth.material_override = mm
	var sign := _child_box(shop, Vector3(2.4, 0.7, 0.08), Vector3(0, 3.5, -0.55), Color(0.95, 0.9, 0.8), false)
	var _k2 := sign
	var label := Label3D.new()
	label.text = "12 à la douzaine"
	label.font_size = 48
	label.pixel_size = 0.01
	label.modulate = Color(0.3, 0.2, 0.15)
	label.position = Vector3(0, 3.5, -0.5)
	shop.add_child(label)
	# Orange cones: nobody moved them. Nobody ever will.
	for p: Vector3 in [Vector3(-4.0, 0, 8.0), Vector3(-3.0, 0, 9.5), Vector3(6.0, 0, 6.0), Vector3(20.0, 0, 12.0), Vector3(-9.0, 0, 30.0)]:
		var cone := _add_mesh(_cyl(0.05, 0.3, 0.8), p + Vector3(0, 0.75, 0), CONE)
		var _k3 := cone
		_add_box(Vector3(0.6, 0.06, 0.6), p + Vector3(0, 0.38, 0), CONE, false)
	# The low stone wall along the mountain's foot; the calèche road is the
	# one gap. (2.3 m: nobody jumps it.)
	for side in [-1.0, 1.0]:
		_add_box(Vector3(30.0, 2.3, 0.6), Vector3(side * 17.5, 0.35 + 1.15, -3.0), STONE)
	# Lamp posts along the plaza.
	for p: Vector3 in [Vector3(-6.0, 0, 12.0), Vector3(8.0, 0, 12.0), Vector3(-6.0, 0, 24.0), Vector3(8.0, 0, 26.0)]:
		_add_mesh(_cyl(0.06, 0.09, 3.2), p + Vector3(0, 1.95, 0), IRON)
		var head := MeshInstance3D.new()
		head.mesh = _cyl(0.22, 0.28, 0.24)
		var hm := StandardMaterial3D.new()
		hm.albedo_color = WARM_WINDOW
		hm.emission_enabled = true
		hm.emission = Color(1.0, 0.88, 0.6)
		hm.emission_energy_multiplier = 1.2
		head.material_override = hm
		head.position = p + Vector3(0, 3.65, 0)
		add_child(head)

# --- the Bell Centre (exterior; the Three Stars riddle dresses the inside) ---

func _build_arena_exterior() -> void:
	arena = Node3D.new()
	arena.name = "BellCentre"
	arena.position = ARENA_POS
	add_child(arena)
	# Walls as separate pieces (walk-in), a doorway gap on the south face.
	var W := 14.0
	var D := 12.0
	var H := 6.0
	_child_box(arena, Vector3(W, H, 0.5), Vector3(0, H / 2.0, -D / 2.0), GREYSTONE, true)      # north
	_child_box(arena, Vector3(0.5, H, D), Vector3(-W / 2.0, H / 2.0, 0), GREYSTONE, true)      # west
	_child_box(arena, Vector3(0.5, H, D), Vector3(W / 2.0, H / 2.0, 0), GREYSTONE, true)       # east
	_child_box(arena, Vector3(W / 2.0 - 1.4, H, 0.5), Vector3(-W / 4.0 - 0.7, H / 2.0, D / 2.0), GREYSTONE, true)  # south-west
	_child_box(arena, Vector3(W / 2.0 - 1.4, H, 0.5), Vector3(W / 4.0 + 0.7, H / 2.0, D / 2.0), GREYSTONE, true)   # south-east
	_child_box(arena, Vector3(2.9, 1.6, 0.5), Vector3(0, H - 0.8, D / 2.0), GREYSTONE, true)   # lintel over the doors
	_child_box(arena, Vector3(W + 0.6, 0.4, D + 0.6), Vector3(0, H + 0.2, 0), Color(0.36, 0.38, 0.42), true)  # roof
	# The marquee band.
	var band := _child_box(arena, Vector3(W + 0.2, 0.9, 0.1), Vector3(0, H - 1.6, D / 2.0 + 0.32), Color(0.75, 0.16, 0.2), false)
	var _k := band
	var name_label := Label3D.new()
	name_label.text = "CENTRE BELL"
	name_label.font_size = 64
	name_label.pixel_size = 0.012
	name_label.modulate = Color(0.98, 0.96, 0.9)
	name_label.position = Vector3(0, H - 1.6, D / 2.0 + 0.4)
	arena.add_child(name_label)
	# Inside: seat-stripe bands in bleu-blanc-rouge along the long walls,
	# so the walls read as stands, and house pennant strings overhead.
	for side: float in [-1.0, 1.0]:
		for row in 3:
			var stripe := _child_box(arena,
					Vector3(0.08, 0.55, D - 1.0),
					Vector3(side * (W / 2.0 - 0.3), 1.2 + row * 0.85, 0),
					[Color(0.75, 0.16, 0.2), Color(0.92, 0.92, 0.9), Color(0.16, 0.3, 0.6)][row], false)
			stripe.rotation.z = side * 0.28
	for k in 8:
		var pennant := _child_box(arena, Vector3(0.3, 0.4, 0.03),
				Vector3(-4.9 + k * 1.4, H - 1.0, -1.6 + (k % 2) * 3.2),
				Color(0.75, 0.16, 0.2) if k % 2 == 0 else Color(0.92, 0.92, 0.9), false)
		pennant.rotation.x = 0.15
	# The four bronze legends on the plaza out front, mid-stride.
	for i in 4:
		var plinth := _child_box(arena, Vector3(1.0, 0.6, 1.0), Vector3(-4.5 + i * 3.0, 0.3, D / 2.0 + 2.6), STONE, true)
		var _k2 := plinth
		var statue := Node3D.new()
		statue.position = Vector3(-4.5 + i * 3.0, 0.6, D / 2.0 + 2.6)
		statue.rotation.y = 0.2 * (i - 1.5)
		arena.add_child(statue)
		var bronze := Color(0.45, 0.32, 0.18)
		var body := _child_mesh(statue, _capsule(0.28, 1.1), Vector3(0, 0.95, 0), bronze, true)
		var _k3 := body
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.2
		head.mesh = hm
		head.material_override = _mat(bronze)
		head.position = Vector3(0, 1.75, 0)
		statue.add_child(head)
		var stick := _child_mesh(statue, _cyl(0.03, 0.03, 1.5), Vector3(0.35, 0.8, 0.2), bronze, false)
		stick.rotation.z = 0.5
		stick.rotation.x = 0.4 * (i % 2)

# --- the mountain: staircases are built by the puzzle; here the dressing ---

func _build_mountain_dressing() -> void:
	# The west-flank boulder scramble: the long way up to the chalet
	# terrace, one patient hop at a time (each step < the 1.41 m jump).
	var scramble: Array = [
		Vector3(-14.5, 0.35, -5.0), Vector3(-15.5, 1.5, -7.5), Vector3(-16.5, 2.7, -10.0),
		Vector3(-16.0, 3.9, -12.5), Vector3(-15.0, 5.1, -15.0), Vector3(-15.5, 6.3, -17.5),
		Vector3(-14.5, 7.4, -19.5),
	]
	for i in scramble.size():
		var p: Vector3 = scramble[i]
		var rock := _add_box(Vector3(2.2, 1.0, 2.2), p + Vector3(0, 0.5, 0), STONE)
		rock.rotation.y = 0.3 * i
	# A stone ledge bridging the last boulder onto the chalet terrace.
	_add_box(Vector3(3.0, 0.4, 2.0), Vector3(-13.6, 7.8, -20.0), STONE)
	# The tam-tam glade: the George-Étienne Cartier monument, a plinth and
	# a bronze figure with a raised arm (the drums gather at its foot).
	var mon := Node3D.new()
	mon.position = GLADE_POS + Vector3(0, 0, -5.0)
	add_child(mon)
	_child_box(mon, Vector3(2.4, 2.4, 2.4), Vector3(0, 1.2, 0), GREYSTONE, true)
	_child_mesh(mon, _cyl(0.5, 0.6, 3.6), Vector3(0, 4.2, 0), GREYSTONE, true)
	var figure := _child_mesh(mon, _capsule(0.28, 1.2), Vector3(0, 6.6, 0), Color(0.42, 0.34, 0.24), false)
	var _k := figure
	var arm := _child_mesh(mon, _cyl(0.06, 0.06, 0.9), Vector3(0.35, 7.2, 0), Color(0.42, 0.34, 0.24), false)
	arm.rotation.z = -0.9
	# Benches on the belvedere terrace and the glade.
	for def: Array in [[GLADE_POS + Vector3(-4.0, 0, 2.0), 0.4], [CHALET_POS + Vector3(6.0, 0, 3.6), 0.0],
			[CHALET_POS + Vector3(-1.0, 0, 3.6), 0.0]]:
		var b := Node3D.new()
		b.position = def[0]
		b.rotation.y = def[1]
		add_child(b)
		_child_box(b, Vector3(1.8, 0.08, 0.5), Vector3(0, 0.45, 0), WOOD, false)
		_child_box(b, Vector3(1.8, 0.4, 0.06), Vector3(0, 0.75, -0.25), WOOD, false)
		for sx: float in [-0.75, 0.75]:
			_child_box(b, Vector3(0.1, 0.45, 0.45), Vector3(sx, 0.22, 0), IRON, false)
		# One solid hull for the whole bench: seat, back, and the gaps a
		# small cat or a probing dog would otherwise slip through.
		var hull := StaticBody3D.new()
		b.add_child(hull)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(1.8, 0.95, 0.56)
		cs.shape = bx
		cs.position = Vector3(0, 0.48, -0.03)
		hull.add_child(cs)

func _build_chalet() -> void:
	chalet = Node3D.new()
	chalet.name = "Chalet"
	chalet.position = CHALET_POS
	add_child(chalet)
	# The Chalet du Mont-Royal: pale stone, long roof, arched windows,
	# and the belvedere balustrade along its south face.
	_child_box(chalet, Vector3(9.0, 3.6, 5.0), Vector3(0, 1.8, -2.5), Color(0.86, 0.82, 0.74), true)
	var roof := _child_mesh(chalet, PrismMesh.new(), Vector3(0, 4.4, -2.5), Color(0.42, 0.34, 0.3), true)
	(roof.mesh as PrismMesh).size = Vector3(9.8, 1.6, 5.8)
	for wx: float in [-3.2, -1.6, 0.0, 1.6, 3.2]:
		var win := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.9, 1.6, 0.06)
		win.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = WARM_WINDOW
		wmat.emission_enabled = true
		wmat.emission = Color(1.0, 0.82, 0.5)
		wmat.emission_energy_multiplier = 0.25
		win.material_override = wmat
		win.position = Vector3(wx, 1.9, 0.04)
		chalet.add_child(win)
		_windows.append(win)
	# The doorframe: the Oreo artifact lives at dog-shoulder height.
	var frame := _child_box(chalet, Vector3(1.3, 2.4, 0.16), Vector3(0, 1.2, 0.08), WOOD, false)
	frame.name = "Doorframe"
	var tally := _child_box(chalet, Vector3(0.28, 0.14, 0.02), Vector3(0.75, 0.62, 0.17), Color(0.35, 0.27, 0.2), false)
	tally.name = "Tally"
	# The belvedere balustrade: low stone rail along the terrace lip.
	for k in 9:
		_child_box(chalet, Vector3(0.18, 0.9, 0.18), Vector3(-6.0 + k * 1.5, 0.45, 4.6), Color(0.86, 0.82, 0.74), true)
	_child_box(chalet, Vector3(12.4, 0.16, 0.24), Vector3(0, 0.95, 4.6), Color(0.86, 0.82, 0.74), true)
	# The balcony proper: a marked spot with the view.
	var balcony := Area3D.new()
	balcony.name = "Balcony"
	balcony.position = Vector3(0, 0.6, 3.6)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 1.6, 2.0)
	cs.shape = box
	balcony.add_child(cs)
	balcony.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player") and not GameState.get_flag("saw_zigzag"):
			GameState.set_flag("saw_zigzag")
			var hud := get_node_or_null("../HUD")
			if hud:
				hud.flash_message("From the belvedere the whole staircase reads at a glance: a zigzag, all the way up, with two flights pointing off into nothing.", 6.0))
	chalet.add_child(balcony)

func _build_cross() -> void:
	cross = Node3D.new()
	cross.name = "Cross"
	cross.position = CROSS_POS
	add_child(cross)
	# The lattice: post and arms of dark iron, lantern bases every 1.5 m.
	_child_box(cross, Vector3(0.6, 10.0, 0.6), Vector3(0, 5.0, 0), IRON, true)
	_child_box(cross, Vector3(6.0, 0.6, 0.6), Vector3(0, 7.5, 0), IRON, true)
	var bases: Array = []
	for k in 6:
		bases.append(Vector3(0, 0.9 + k * 1.5, 0.45))
	for k in 3:
		bases.append(Vector3(-2.7 + k * 0.9, 7.5, 0.45))
		bases.append(Vector3(0.9 + k * 0.9, 7.5, 0.45))
	for i in bases.size():
		var lantern := Node3D.new()
		lantern.name = "Lantern%d" % i
		lantern.position = bases[i]
		cross.add_child(lantern)
		var frame := _child_box(lantern, Vector3(0.5, 0.6, 0.3), Vector3.ZERO, Color(0.28, 0.26, 0.24), false)
		var _k := frame
		var glass := MeshInstance3D.new()
		glass.name = "Glass"
		var gm := BoxMesh.new()
		gm.size = Vector3(0.42, 0.5, 0.34)
		glass.mesh = gm
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.7, 0.75, 0.8, 0.45)
		gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.material_override = gmat
		# Three lanterns lost their glass to the winters.
		glass.visible = not (i in [2, 7, 10])
		lantern.add_child(glass)
	# The summit's own drum: the tam-tam players always end at the top.
	var drum := Node3D.new()
	drum.name = "SummitDrum"
	drum.position = Vector3(3.5, 0, 3.0)
	cross.add_child(drum)
	_child_mesh(drum, _cyl(0.5, 0.42, 0.7), Vector3(0, 0.35, 0), WOOD, true)
	_child_mesh(drum, _cyl(0.5, 0.5, 0.04), Vector3(0, 0.72, 0), Color(0.86, 0.8, 0.68), false)

func _build_funicular() -> void:
	# The upper station on the summit's west lip, its door shut until the
	# cross's shadow finds it; the rails run down the west flank.
	var station := Node3D.new()
	station.name = "UpperStation"
	station.position = FUNICULAR_TOP + Vector3(-4.2, 0, -1.6)
	add_child(station)
	_child_box(station, Vector3(2.4, 2.4, 3.0), Vector3(0, 1.2, 0), Color(0.5, 0.42, 0.34), true)
	_child_box(station, Vector3(2.8, 0.4, 3.4), Vector3(0, 2.6, 0), Color(0.36, 0.3, 0.26), true)
	var gate := _child_box(station, Vector3(0.14, 2.0, 1.4), Vector3(1.28, 1.0, 0), IRON, true)
	gate.name = "Gate"
	# Rails along the route (decor: no collision, the car carries riders).
	for i in FUNICULAR_ROUTE.size() - 1:
		var a: Vector3 = FUNICULAR_ROUTE[i]
		var b: Vector3 = FUNICULAR_ROUTE[i + 1]
		var mid := (a + b) / 2.0
		var len := a.distance_to(b)
		for side in [-0.5, 0.5]:
			var rail := MeshInstance3D.new()
			rail.mesh = _cyl(0.05, 0.05, len)
			rail.material_override = _mat(IRON)
			rail.position = mid + Vector3(side, 0.05, 0)
			add_child(rail)
			rail.look_at_from_position(rail.position, b + Vector3(side, 0.05, 0), Vector3.UP)
			rail.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	# The car, waiting at the top.
	funicular_car = Node3D.new()
	funicular_car.name = "FunicularCar"
	funicular_car.position = FUNICULAR_TOP
	add_child(funicular_car)
	_child_box(funicular_car, Vector3(1.6, 0.2, 2.4), Vector3(0, 0.3, 0), WOOD, true)
	for side in [-0.75, 0.75]:
		_child_box(funicular_car, Vector3(0.1, 1.2, 2.4), Vector3(side, 0.9, 0), Color(0.62, 0.22, 0.18), true)
	_child_box(funicular_car, Vector3(1.6, 1.0, 0.1), Vector3(0, 0.8, -1.15), Color(0.62, 0.22, 0.18), true)
	_child_box(funicular_car, Vector3(1.8, 0.1, 2.6), Vector3(0, 1.55, 0), Color(0.36, 0.3, 0.26), false)
	_child_box(funicular_car, Vector3(1.4, 0.36, 0.5), Vector3(0, 0.58, 0.6), WOOD_PALE, false)   # the bench

func _build_maple_scatter() -> void:
	# Maples: all over the mountain's terraces and the plain's edges,
	# never on a flight, the scramble, the glade, or the plaza.
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var placed := 0
	var attempts := 0
	while placed < 46 and attempts < 400:
		attempts += 1
		var x := rng.randf_range(-36.0, 36.0)
		var z := rng.randf_range(-43.0, 30.0)
		if not _maple_fits(x, z):
			continue
		var h := _terrain_height(x, z)
		if h < 0.3:
			continue
		_maple(Vector3(x, h, z), rng)
		placed += 1

func _maple_fits(x: float, z: float) -> bool:
	# Keep clear of: the plaza & downtown, the arena, the wall gap/road,
	# every flight, the scramble, the glade, the chalet, the cross, the
	# funicular rail, and the dock.
	if z > 4.0 and absf(x - 2.0) < 17.0:
		return false  # plaza / downtown
	if x > 7.0 and x < 25.0 and z > 12.0 and z < 28.0:
		return false  # the Bell Centre grows no indoor maples
	if z > 26.0:
		return false  # port
	if absf(x) < 5.0 and z > -36.0 and z < 0.0:
		return false  # the staircase spine
	if x < -12.0 and x > -19.0 and z > -22.0 and z < -3.0:
		return false  # boulder scramble
	if Vector2(x, z).distance_to(Vector2(GLADE_POS.x, GLADE_POS.z)) < 6.0:
		return false
	if Vector2(x, z).distance_to(Vector2(CHALET_POS.x, CHALET_POS.z)) < 8.0:
		return false
	if Vector2(x, z).distance_to(Vector2(CROSS_POS.x, CROSS_POS.z)) < 6.0:
		return false
	if Vector2(x, z).distance_to(Vector2(OVEN_POS.x, OVEN_POS.z)) < 5.0:
		return false
	for i in FUNICULAR_ROUTE.size() - 1:
		var a := Vector2(FUNICULAR_ROUTE[i].x, FUNICULAR_ROUTE[i].z)
		var b := Vector2(FUNICULAR_ROUTE[i + 1].x, FUNICULAR_ROUTE[i + 1].z)
		if Vector2(x, z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(x, z), a, b)) < 3.0:
			return false
	# Steep risers: no trees on cliff faces.
	if absf(x) < 15.5 and z < -3.0:
		for t: Array in TERRACES:
			if z < t[0] + 0.5 and z > t[1] - 0.5:
				return false
	return true

func _maple(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var trunk := _add_mesh(_cyl(0.14, 0.22, 1.8), pos + Vector3(0, 0.9, 0), Color(0.34, 0.26, 0.2))
	var _k := trunk
	var col: Color = MAPLE_COLORS[rng.randi_range(0, MAPLE_COLORS.size() - 1)]
	for k in 3:
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := rng.randf_range(1.2, 1.9) - k * 0.25
		sm.radius = r
		sm.height = r * 1.6
		crown.mesh = sm
		crown.material_override = _mat(col.lightened(k * 0.06))
		crown.position = pos + Vector3(rng.randf_range(-0.5, 0.5), 2.2 + k * 0.7, rng.randf_range(-0.5, 0.5))
		add_child(crown)
	# A leaf pile below.
	_add_mesh(_cyl(0.9, 1.1, 0.16), pos + Vector3(rng.randf_range(-0.6, 0.6), 0.08, rng.randf_range(-0.6, 0.6)), col.darkened(0.15), false)

# --- the autumn air: falling maple leaves, island-wide ---

func _build_leaf_fall() -> void:
	var leaves := CPUParticles3D.new()
	leaves.amount = 420
	leaves.lifetime = 11.0
	leaves.preprocess = 11.0
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = Vector3(48.0, 1.0, 44.0)
	leaves.position = Vector3(0, 14.0, -6.0)
	leaves.direction = Vector3(0.3, -1, 0.1)
	leaves.spread = 30.0
	leaves.gravity = Vector3(0.5, -0.65, 0.2)
	leaves.initial_velocity_min = 0.3
	leaves.initial_velocity_max = 0.8
	leaves.angular_velocity_min = -140.0
	leaves.angular_velocity_max = 140.0
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.14, 0.12)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.88, 0.42, 0.16, 0.95)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	leaf.material = lm
	leaves.mesh = leaf
	add_child(leaves)
	# A second, sparser drift in gold, so the fall reads two-toned.
	var gold := leaves.duplicate() as CPUParticles3D
	gold.amount = 180
	var gleaf := QuadMesh.new()
	gleaf.size = Vector2(0.12, 0.1)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.92, 0.72, 0.2, 0.95)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gleaf.material = gm
	gold.mesh = gleaf
	add_child(gold)

# --- the Old Port, dressed: quay stones, bollards, ropes, a ferry ---

func _build_quay_dressing() -> void:
	# Stone quay lip along the shore either side of the dock.
	for side: float in [-1.0, 1.0]:
		for i in 5:
			var p := Vector3(side * (4.0 + i * 3.2), 0.32, 27.5 + i * 0.4)
			_add_box(Vector3(3.0, 0.55, 1.2), p, GREYSTONE)
	# Iron bollards with rope coils.
	for p: Vector3 in [Vector3(-3.2, 0, 29.0), Vector3(4.0, 0, 28.6), Vector3(-8.5, 0, 29.4), Vector3(8.0, 0, 29.2)]:
		_add_mesh(_cyl(0.14, 0.18, 0.55), p + Vector3(0, 0.62, 0), IRON)
		var coil := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.16
		tm.outer_radius = 0.3
		coil.mesh = tm
		coil.material_override = _mat(Color(0.68, 0.58, 0.4))
		coil.position = p + Vector3(0.5, 0.4, 0.2)
		add_child(coil)
		var coil_body := StaticBody3D.new()
		var ccs := CollisionShape3D.new()
		var ccyl := CylinderShape3D.new()
		ccyl.radius = 0.32
		ccyl.height = 0.2
		ccs.shape = ccyl
		coil_body.position = coil.position
		coil_body.add_child(ccs)
		add_child(coil_body)
	# A moored river ferry east of the dock, nodding at its lines.
	var ferry := Node3D.new()
	ferry.name = "Ferry"
	ferry.position = Vector3(15.0, WATER_SURFACE_Y + 0.25, 39.0)
	ferry.rotation.y = 0.35
	add_child(ferry)
	_child_box(ferry, Vector3(2.6, 0.7, 7.0), Vector3(0, 0.2, 0), Color(0.2, 0.24, 0.3), true)
	_child_box(ferry, Vector3(2.2, 1.0, 4.2), Vector3(0, 1.05, -0.4), Color(0.92, 0.9, 0.86), true)
	_child_box(ferry, Vector3(1.6, 0.8, 1.6), Vector3(0, 1.95, -1.0), Color(0.92, 0.9, 0.86), true)
	var stack := _child_mesh(ferry, _cyl(0.16, 0.2, 1.0), Vector3(0, 2.7, -1.0), Color(0.75, 0.2, 0.18), false)
	var _k := stack
	for wz: float in [-2.0, -0.8, 0.4, 1.6]:
		var win := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(0.06, 0.4, 0.7)
		win.mesh = wb
		var wm := StandardMaterial3D.new()
		wm.albedo_color = WARM_WINDOW
		wm.emission_enabled = true
		wm.emission = Color(1.0, 0.82, 0.5)
		wm.emission_energy_multiplier = 0.6
		win.material_override = wm
		win.position = Vector3(1.12, 1.05, wz)
		ferry.add_child(win)
		_windows.append(win)
	var bob := ferry.create_tween().set_loops()
	bob.tween_property(ferry, "position:y", WATER_SURFACE_Y + 0.34, 3.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(ferry, "position:y", WATER_SURFACE_Y + 0.18, 3.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The Farine Five Roses sign on a brick block east of the port.
	var mill := Node3D.new()
	mill.position = Vector3(24.0, 0.35, 38.0)
	mill.rotation.y = -0.3
	add_child(mill)
	_child_box(mill, Vector3(6.0, 7.0, 4.0), Vector3(0, 3.5, 0), Color(0.5, 0.32, 0.26), true)
	for fx in 3:
		for fy in 4:
			var win := MeshInstance3D.new()
			var wb := BoxMesh.new()
			wb.size = Vector3(0.8, 1.0, 0.06)
			win.mesh = wb
			win.material_override = _mat(Color(0.28, 0.24, 0.22))
			win.position = Vector3(-1.8 + fx * 1.8, 1.2 + fy * 1.5, -2.04)
			mill.add_child(win)
	var sign_label := Label3D.new()
	sign_label.text = "FARINE\nFIVE ROSES"
	sign_label.font_size = 52
	sign_label.pixel_size = 0.014
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_label.modulate = Color(1.0, 0.22, 0.18)
	# Facing the river: the first thing an arriving traveller reads.
	sign_label.position = Vector3(0, 8.4, 1.2)
	mill.add_child(sign_label)
	for sx: float in [-1.6, 1.6]:
		_child_box(mill, Vector3(0.1, 1.6, 0.1), Vector3(sx, 7.6, -1.2), IRON, false)

# --- the river horizon: Habitat 67, the Biosphère, the Big O ---

func _build_horizon_icons() -> void:
	# Habitat 67: stacked offset concrete boxes on the south-east shallows.
	var habitat := Node3D.new()
	habitat.position = Vector3(34.0, -0.2, 46.0)
	habitat.rotation.y = -0.4
	add_child(habitat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 67
	for i in 16:
		var bx := _child_box(habitat,
				Vector3(1.8, 1.1, 2.2),
				Vector3(rng.randf_range(-4.5, 4.5), 0.55 + (i % 4) * 1.15 + rng.randf_range(0.0, 0.4),
						rng.randf_range(-2.2, 2.2)),
				Color(0.82, 0.78, 0.72), true)
		bx.rotation.y = rng.randf_range(-0.15, 0.15)
	# The Biosphère: a great pale lattice dome on the west shallows.
	var bio := Node3D.new()
	bio.position = Vector3(-36.0, -0.3, 44.0)
	add_child(bio)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 4.2
	sm.height = 8.4
	sm.radial_segments = 12
	sm.rings = 6
	dome.mesh = sm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.85, 0.9, 0.94, 0.35)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.roughness = 0.3
	dmat.metallic = 0.4
	dome.material_override = dmat
	dome.position = Vector3(0, 2.4, 0)
	bio.add_child(dome)
	dome.create_convex_collision()
	for k in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 4.0 - k * 0.9
		tm.outer_radius = 4.12 - k * 0.9
		ring.mesh = tm
		ring.material_override = _mat(Color(0.7, 0.74, 0.78))
		ring.position = Vector3(0, 2.4 + k * 1.4, 0)
		bio.add_child(ring)
	# The Big O: the leaning tower over its bowl, far north-east.
	var bigo := Node3D.new()
	bigo.position = Vector3(46.0, -1.0, -26.0)
	bigo.rotation.y = 0.5
	add_child(bigo)
	var bowl := _child_mesh(bigo, _cyl(5.0, 6.0, 2.2), Vector3(0, 1.1, 0), Color(0.78, 0.76, 0.72), true)
	var _k := bowl
	var tower := _child_mesh(bigo, _cyl(0.7, 1.3, 11.0), Vector3(-3.2, 6.0, 0), Color(0.85, 0.83, 0.8), true)
	tower.rotation.z = 0.55
	var obs := _child_box(bigo, Vector3(2.0, 0.9, 1.4), Vector3(-6.2, 10.6, 0), Color(0.7, 0.72, 0.74), false)
	var _k2 := obs

# --- the mountain, dressed: outcrops, birches, staircase lamps ---

func _build_outcrops_and_birches() -> void:
	# Granite outcrops shouldering out of the riser faces (east side and
	# west of the stair spine, clear of flights, scramble, and funicular).
	for def: Array in [
		[Vector3(8.0, 0, -5.5), 0.3], [Vector3(-7.5, 0, -6.0), -0.2], [Vector3(10.0, 0, -15.0), 0.5],
		[Vector3(-8.0, 0, -16.0), 0.1], [Vector3(7.0, 0, -24.5), -0.4], [Vector3(-9.0, 0, -25.0), 0.35],
		[Vector3(9.5, 0, -32.5), 0.2], [Vector3(-7.0, 0, -33.0), -0.3],
	]:
		var p: Vector3 = def[0]
		var h := _terrain_height(p.x, p.z)
		var rock := _add_box(Vector3(2.6, 1.6, 1.8), Vector3(p.x, h - 0.2, p.z), GRANITE_OUT)
		rock.rotation.y = def[1]
		rock.rotation.z = 0.12
		var cap := _add_box(Vector3(1.8, 0.8, 1.3), Vector3(p.x + 0.4, h + 0.6, p.z + 0.2), GRANITE_OUT, false)
		cap.rotation.y = (def[1] as float) + 0.4
	# Birches among the maples: white bark, sparse gold crowns.
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	var placed := 0
	var attempts := 0
	while placed < 14 and attempts < 200:
		attempts += 1
		var x := rng.randf_range(-34.0, 34.0)
		var z := rng.randf_range(-41.0, 24.0)
		if not _maple_fits(x, z):
			continue
		var h := _terrain_height(x, z)
		if h < 0.3:
			continue
		var trunk := _add_mesh(_cyl(0.08, 0.12, 2.6), Vector3(x, h + 1.3, z), Color(0.92, 0.9, 0.86))
		var _k := trunk
		for band in 3:
			_add_box(Vector3(0.2, 0.1, 0.03), Vector3(x + 0.02, h + 0.7 + band * 0.7, z + 0.11), Color(0.2, 0.2, 0.2), false)
		var crown := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 1.0
		cm.height = 2.2
		crown.mesh = cm
		crown.material_override = _mat(Color(0.9, 0.76, 0.3))
		crown.position = Vector3(x, h + 3.4, z)
		add_child(crown)
		placed += 1

func _build_stair_lamps() -> void:
	# A park lamp at every flight's foot landing, warm halos up the dark
	# mountain (offset from the levers, clear of the swinging flights).
	for k in FLIGHTS.size():
		var f: Array = FLIGHTS[k]
		var foot: Vector2 = f[0]
		var y: float = f[2]
		var p := Vector3(foot.x - 1.9, y, foot.y + 0.6)
		_add_mesh(_cyl(0.05, 0.08, 2.6), p + Vector3(0, 1.55, 0), IRON)
		var head := MeshInstance3D.new()
		head.mesh = _cyl(0.2, 0.26, 0.22)
		var hm := StandardMaterial3D.new()
		hm.albedo_color = WARM_WINDOW
		hm.emission_enabled = true
		hm.emission = Color(1.0, 0.88, 0.6)
		hm.emission_energy_multiplier = 1.3
		head.material_override = hm
		head.position = p + Vector3(0, 3.0, 0)
		add_child(head)
	# And one on the belvedere, and one by the summit drum.
	for p: Vector3 in [CHALET_POS + Vector3(4.0, 0, 4.2), CROSS_POS + Vector3(4.8, 0, 1.6)]:
		_add_mesh(_cyl(0.05, 0.08, 2.6), p + Vector3(0, 1.55, 0), IRON)
		var head := MeshInstance3D.new()
		head.mesh = _cyl(0.2, 0.26, 0.22)
		var hm := StandardMaterial3D.new()
		hm.albedo_color = WARM_WINDOW
		hm.emission_enabled = true
		hm.emission = Color(1.0, 0.88, 0.6)
		hm.emission_energy_multiplier = 1.3
		head.material_override = hm
		head.position = p + Vector3(0, 3.0, 0)
		add_child(head)

# --- the city of a hundred steeples, and mountain small-talk ---

func _steeple_bells() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	var loop := func() -> void:
		while is_inside_tree():
			await get_tree().create_timer(rng.randf_range(80.0, 150.0)).timeout
			if not is_inside_tree():
				return
			Sfx.play("funicular_bell", rng.randf_range(0.55, 0.7), 0.0, -18.0)
	loop.call()

func _mountain_chitter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var loop := func() -> void:
		while is_inside_tree():
			await get_tree().create_timer(rng.randf_range(25.0, 55.0)).timeout
			if not is_inside_tree():
				return
			var player: Node3D = get_tree().get_first_node_in_group("player")
			if player and player.global_position.z < -3.0:
				Sfx.play("squirrel_chitter", rng.randf_range(0.9, 1.2), 0.0, -20.0)
	loop.call()

# --- light: late-autumn gold, then dusk when the bagels warm the cross ---

func _autumn_light() -> void:
	var mgr := get_parent()
	if mgr == null or not mgr.has_node("Sun"):
		return
	var sun: DirectionalLight3D = mgr.get_node("Sun")
	sun.rotation_degrees = Vector3(-18, 40, 0)
	sun.light_color = Color(1.0, 0.82, 0.6)
	sun.light_energy = 1.15
	var env_node := mgr.get_node_or_null("WorldEnvironment")
	if env_node:
		var sky_mat := (env_node.environment as Environment).sky.sky_material as ProceduralSkyMaterial
		if sky_mat:
			sky_mat.sky_top_color = Color(0.36, 0.5, 0.7)
			sky_mat.sky_horizon_color = Color(0.95, 0.72, 0.5)
			sky_mat.ground_horizon_color = Color(0.8, 0.6, 0.45)

## Dusk: the sun sinks, the sky goes violet, every window comes on.
func set_dusk(instant := false) -> void:
	if _dusk:
		return
	_dusk = true
	var mgr := get_parent()
	if mgr == null or not mgr.has_node("Sun"):
		return
	var sun: DirectionalLight3D = mgr.get_node("Sun")
	var dur := 0.01 if instant else 6.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(sun, "rotation_degrees", Vector3(-6, 55, 0), dur)
	t.tween_property(sun, "light_color", Color(0.75, 0.62, 0.8), dur)
	t.tween_property(sun, "light_energy", 0.55, dur)
	var env_node := mgr.get_node_or_null("WorldEnvironment")
	if env_node:
		var sky_mat := (env_node.environment as Environment).sky.sky_material as ProceduralSkyMaterial
		if sky_mat:
			t.tween_property(sky_mat, "sky_top_color", Color(0.14, 0.14, 0.34), dur)
			t.tween_property(sky_mat, "sky_horizon_color", Color(0.72, 0.42, 0.5), dur)
			t.tween_property(sky_mat, "ground_horizon_color", Color(0.4, 0.3, 0.4), dur)
	for w in _windows:
		var m := w.material_override as StandardMaterial3D
		t.tween_property(m, "emission_energy_multiplier", 1.3, dur)
	# The beacon reaches farther in the dark.
	if _beacon:
		t.tween_property(_beacon, "scale", Vector3(1.0, 1.0, 1.8), dur)
		for beam in _beacon.get_children():
			var bm := (beam as MeshInstance3D).material_override as StandardMaterial3D
			t.tween_property(bm, "emission_energy_multiplier", 2.4, dur)

func is_dusk() -> bool:
	return _dusk

# --- shared plumbing (same contract as the other islands) ---

func _add_pickup(pos: Vector3, id: String, disp: String, color: Color) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/interaction/item_pickup.gd"))
	a.set("item_id", id)
	a.set("display_name", disp)
	a.position = pos
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.3
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
		_materials[color] = m
	return _materials[color]

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	return c

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	if with_collision:
		# Convex, never trimesh: trimesh shells are hollow, and anything
		# that clips inside one is trapped. Only the terrain earns a trimesh.
		mi.create_convex_collision()
	return mi

func _add_box(size: Vector3, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _add_mesh(box, pos, color, with_collision)

func _child_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	if with_collision:
		mi.create_convex_collision()
	return mi

func _child_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _child_mesh(parent, box, pos, color, with_collision)
