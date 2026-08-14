extends Node3D
## Island 5 · The Pirate Ship — the Santa Maria of West Edmonton Mall,
## run aground an ocean away in a granite Nova Scotia cove. Crooked
## Lunenburg saltboxes above a working wharf, spruce on the headland,
## lobster traps, dories, a fog bank that never quite lands, and the
## biggest tides in the world. Teaches: growl.
##
## The island owns the TIDE: a fixed Fundy loop of three small swells
## and one big bore that sweeps the cove south-to-north. Riddles read
## it through tide_phase()/is_bore()/bore_ridge_z().

const WATER_SURFACE_Y := -0.4
const COAST_BASE := 46.0

## Tide clock: three small swells then the bore, one bar of four beats.
const TIDE_PERIOD := 16.0
const BORE_START := 12.0          # last quarter of the loop is the bore
const BORE_RUN_Z := [52.0, 16.0]  # the ridge sweeps the cove south→north

## The cove pocket (below waterline) between wharf and golf shelf.
const COVE_CENTER := Vector2(10.0, 29.0)
const COVE_RADII := Vector2(9.0, 8.0)
## The drydock basin the Santa Maria lies keeled in.
const DOCK_CENTER := Vector2(13.0, 18.0)
const DOCK_RADII := Vector2(9.5, 5.0)

const GRANITE := Color(0.52, 0.53, 0.55)
const GRANITE_DARK := Color(0.4, 0.41, 0.44)
const WOOD := Color(0.48, 0.38, 0.28)
const WOOD_PALE := Color(0.62, 0.54, 0.42)
const TRIM := Color(0.94, 0.93, 0.9)
const HULL := Color(0.32, 0.22, 0.16)
const HULL_TRIM := Color(0.75, 0.62, 0.3)
const SAIL := Color(0.9, 0.87, 0.78)
const WARM_WINDOW := Color(1.0, 0.85, 0.55)

## Lunenburg waterfront palette: bold, salt-faded, proudly mismatched.
const HOUSE_COLORS := [
	Color(0.72, 0.28, 0.24),  # red ochre
	Color(0.24, 0.52, 0.54),  # teal
	Color(0.82, 0.66, 0.28),  # mustard
	Color(0.3, 0.45, 0.32),   # forest green
	Color(0.5, 0.34, 0.5),    # plum
]

## Pennant palette for the golf holes; the Jolly Roger wears the first
## four, and only those cannons belong in the broadside.
const PENNANTS := [
	Color(0.12, 0.12, 0.14),  # black
	Color(0.78, 0.22, 0.2),   # red
	Color(0.93, 0.92, 0.9),   # white
	Color(0.88, 0.72, 0.3),   # gold
	Color(0.3, 0.6, 0.62),    # teal
	Color(0.5, 0.34, 0.6),    # purple
	Color(0.35, 0.62, 0.35),  # green
	Color(0.85, 0.5, 0.25),   # orange
	Color(0.45, 0.62, 0.8),   # sky
]
const ROGER_HOLES := [0, 1, 2, 3]

var ship: Node3D
var crow_nest: Node3D
var capstan: Node3D
var helm: Node3D
var anchor_rig: Node3D
var sails: Array[Node3D] = []
var dock_water: MeshInstance3D

var _materials := {}
var _visited_locations := {}
var _tide_t := 0.0
var _tide_locked := -1.0   # test hook: pin the clock
var _storm := false        # storm gate open: the bore runs a tier higher
var _bore_mesh: MeshInstance3D
var _water: MeshInstance3D

func _ready() -> void:
	_build_island()
	_build_water()
	_build_bore()
	_build_wharf()
	_build_village()
	_build_golf_shelf()
	_build_sea_cave()
	_build_drydock()
	_build_ship()
	_build_boathouse()
	_build_dressing()
	_build_fog_bank()
	_maritime_light()
	_add_ambient_loop("res://assets/audio/ocean_loop.wav", Vector3(6, 0.5, 40), -10.0, 60.0)
	_add_location_trigger(Vector3(0, 0, 36), 8.0, "The Wharf")
	_add_location_trigger(Vector3(-20, 1.0, 14), 9.0, "The Painted Row")
	_add_location_trigger(Vector3(26, 0.7, 16), 8.0, "The Cannonball Nine")
	_add_location_trigger(Vector3(13, 0, 18), 7.0, "The Drydock")
	_add_location_trigger(Vector3(31, 0, 27), 5.0, "The Sea Cave")
	_ship_groans()
	for def: Array in [
		["WaveClock", "res://scripts/puzzles/wave_clock.gd"],
		["CannonballNine", "res://scripts/puzzles/cannonball_nine.gd"],
		["ParrotGame", "res://scripts/puzzles/parrot_game.gd"],
		["SeaCaveKey", "res://scripts/puzzles/sea_cave_key.gd"],
		["FloatSantaMaria", "res://scripts/puzzles/float_santa_maria.gd"],
	]:
		var puzzle := Node3D.new()
		puzzle.name = def[0]
		puzzle.set_script(load(def[1]))
		add_child(puzzle)
	if GameState.get_flag("island5_complete"):
		# She already sailed her out: the Santa Maria rides at anchor off
		# the cove mouth, and the drydock keeps its water.
		ship.rotation.z = 0.0
		ship.rotation.y = PI
		ship.position = Vector3(5.0, -0.9, 62.0)
		dock_water.visible = true
		dock_water.position.y = WATER_SURFACE_Y + 0.02

# --- the tide ---

func _process(delta: float) -> void:
	if _tide_locked < 0.0:
		_tide_t = fmod(_tide_t + delta, TIDE_PERIOD)
	else:
		_tide_t = _tide_locked
	var swell := swell_height()
	if _water:
		_water.position.y = WATER_SURFACE_Y + swell
	if dock_water and GameState.get_flag("ship_afloat"):
		dock_water.position.y = WATER_SURFACE_Y + 0.02 + swell
	# The bore: a long ridge of water sweeping the cove northward.
	if _bore_mesh:
		if is_bore():
			_bore_mesh.visible = true
			var amp := bore_amplitude()
			_bore_mesh.position = Vector3(10.0, WATER_SURFACE_Y + amp * 0.5, bore_ridge_z())
			_bore_mesh.scale = Vector3(1.0, amp / 0.55, 1.0)
		else:
			_bore_mesh.visible = false

func tide_phase() -> float:
	return _tide_t

## Small-swell water rise (the bore is separate, a traveling ridge).
func swell_height() -> float:
	if _tide_t >= BORE_START:
		return 0.1
	return 0.1 * (0.5 + 0.5 * sin(_tide_t / BORE_START * 3.0 * TAU - PI / 2.0))

func is_bore() -> bool:
	return _tide_t >= BORE_START

func bore_progress() -> float:
	return clampf((_tide_t - BORE_START) / (TIDE_PERIOD - BORE_START), 0.0, 1.0)

func bore_ridge_z() -> float:
	return lerpf(BORE_RUN_Z[0], BORE_RUN_Z[1], bore_progress())

func bore_amplitude() -> float:
	return 1.1 if _storm else 0.55

## The window when the stepping stones stand clear of the water.
func stones_passable() -> bool:
	return not is_bore() and swell_height() < 0.06

func set_storm(on: bool) -> void:
	_storm = on

func is_storm() -> bool:
	return _storm

## Test hook: pin the tide clock (negative unlocks).
func force_tide(t: float) -> void:
	_tide_locked = t
	if t >= 0.0:
		_tide_t = t

# --- terrain & water ---

func _coast_radius(theta: float) -> float:
	var wob := 2.6 * sin(3.0 * theta + 1.7) + 1.7 * sin(5.0 * theta + 4.2) \
			+ 1.1 * sin(8.0 * theta + 0.9)
	var d := absf(wrapf(theta - PI / 2.0, -PI, PI))
	wob *= smoothstep(0.55, 1.1, d)
	return COAST_BASE + wob

func _basin(x: float, z: float, center: Vector2, radii: Vector2, depth: float) -> float:
	var e := Vector2((x - center.x) / radii.x, (z - center.y) / radii.y).length()
	return -depth * (1.0 - smoothstep(0.62, 1.0, e))

func _terrain_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var theta := atan2(z, x)
	var coast := _coast_radius(theta)
	if d >= coast:
		return -6.0 * clampf((d - coast) / 12.0, 0.0, 1.0)
	# Granite shore plain, dipping to the beach.
	var h := 0.35 * (1.0 - smoothstep(coast - 4.0, coast - 1.5, d))
	# The west slope the painted houses climb.
	var westness := smoothstep(-6.0, -22.0, x)
	var rim := 1.0 - smoothstep(coast - 10.0, coast - 2.0, d)
	h += 1.3 * westness * rim
	# The north-east headland the sea cave hides under.
	var northeast := smoothstep(10.0, 30.0, x) * smoothstep(14.0, -6.0, z)
	h += 2.8 * northeast * rim
	# The golf shelf: a flat granite terrace east of the cove.
	var shelf := smoothstep(17.0, 21.0, x) * (1.0 - smoothstep(35.0, 38.0, x)) \
			* smoothstep(5.0, 9.0, z) * (1.0 - smoothstep(23.0, 26.0, z))
	h = maxf(h, 0.7 * shelf)
	# The cove pocket and the drydock basin, both below the waterline.
	h += _basin(x, z, COVE_CENTER, COVE_RADII, 1.55)
	h += _basin(x, z, DOCK_CENTER, DOCK_RADII, 1.6)
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
	sm.set_shader_parameter("noise_tex", _noise_tex(51, 0.06))
	sm.set_shader_parameter("detail_normal", _noise_tex(511, 0.15, true))
	sm.set_shader_parameter("base_radius", COAST_BASE)
	sm.set_shader_parameter("path_radius", 0.0)
	sm.set_shader_parameter("lawn_color", Color(0.38, 0.5, 0.34))    # salt-moss green
	sm.set_shader_parameter("lawn_alt", Color(0.46, 0.47, 0.42))     # lichen
	sm.set_shader_parameter("gravel", GRANITE)
	sm.set_shader_parameter("river_stone", GRANITE_DARK)
	sm.set_shader_parameter("lagoon_center", COVE_CENTER)
	sm.set_shader_parameter("lagoon_radii", COVE_RADII * 1.15)
	terrain.material_override = sm
	add_child(terrain)
	# Terrain is the ONE mesh that earns a trimesh: it is a heightfield the
	# player walks the top of, never the inside. Every prop is convex.
	terrain.create_trimesh_collision()

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	_water = MeshInstance3D.new()
	_water.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	sm.set_shader_parameter("wave_normal1", _noise_tex(91, 0.08, true))
	sm.set_shader_parameter("wave_normal2", _noise_tex(92, 0.13, true))
	sm.set_shader_parameter("shore_radius", COAST_BASE)
	sm.set_shader_parameter("coast_wobble", 1.0)
	sm.set_shader_parameter("shallow_color", Color(0.36, 0.5, 0.52))
	sm.set_shader_parameter("deep_color", Color(0.05, 0.13, 0.2))    # pewter Atlantic
	sm.set_shader_parameter("wave_height", 0.09)
	_water.material_override = sm
	_water.position = Vector3(0, WATER_SURFACE_Y, 0)
	add_child(_water)
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

func _build_bore() -> void:
	# The bore ridge: a long soft roll of water, sized to the cove mouth.
	var cap := CapsuleMesh.new()
	cap.radius = 1.6
	cap.height = 26.0
	_bore_mesh = MeshInstance3D.new()
	_bore_mesh.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.68, 0.7, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.25
	_bore_mesh.material_override = m
	_bore_mesh.rotation.z = PI / 2.0
	_bore_mesh.visible = false
	add_child(_bore_mesh)

func _on_water_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.enter_water(WATER_SURFACE_Y)

func _on_water_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.exit_water()

# --- the wharf ---

func _build_wharf() -> void:
	for i in 8:
		_add_box(Vector3(3.4, 0.16, 1.9), Vector3(0, 0.42 - i * 0.008, 29.5 + i * 1.85), WOOD)
	for side in [-1.0, 1.0]:
		for i in 4:
			_add_mesh(_cyl(0.14, 0.16, 2.2), Vector3(side * 1.55, -0.4, 30.5 + i * 4.2), WOOD_PALE)
	# The net loft: the high platform only the bore can reach.
	for p: Vector2 in [Vector2(-4.8, 29.0), Vector2(-2.2, 29.0), Vector2(-4.8, 32.2), Vector2(-2.2, 32.2)]:
		_add_box(Vector3(0.22, 3.0, 0.22), Vector3(p.x, 1.85, p.y), WOOD_PALE)
	_add_box(Vector3(3.4, 0.18, 4.0), Vector3(-3.5, 3.32, 30.6), WOOD)
	var roof := _add_box(Vector3(3.8, 0.12, 4.4), Vector3(-3.5, 4.9, 30.6), Color(0.4, 0.32, 0.26))
	roof.rotation.z = 0.12
	for p: Vector2 in [Vector2(-4.9, 29.2), Vector2(-2.1, 32.0)]:
		_add_box(Vector3(0.14, 1.4, 0.14), Vector3(p.x, 4.1, p.y), WOOD_PALE, false)
	# Draped nets on the loft rail (soft decor).
	var net := _add_box(Vector3(3.2, 0.9, 0.06), Vector3(-3.5, 3.9, 28.9), Color(0.55, 0.55, 0.5), false)
	net.rotation.x = 0.2

# --- the painted row ---

func _build_village() -> void:
	var lots: Array = [
		[Vector3(-26.0, 0.0, 4.0), 0.5], [Vector3(-23.0, 0.0, 11.0), 0.32],
		[Vector3(-19.0, 0.0, 17.5), 0.22], [Vector3(-25.5, 0.0, 20.0), 0.6],
		[Vector3(-14.5, 0.0, 23.0), 0.1],
	]
	for i in lots.size():
		var pos: Vector3 = lots[i][0]
		pos.y = _terrain_height(pos.x, pos.z)
		_saltbox(pos, (lots[i][1] as float) + 0.15 * (i % 3 - 1), HOUSE_COLORS[i], i % 2 == 0)
	# A lane of crushed granite down to the wharf.
	for k in 9:
		var t := k / 8.0
		var p := Vector3(lerpf(-21.0, -3.0, t), 0, lerpf(16.0, 27.0, t))
		p.y = _terrain_height(p.x, p.z) + 0.03
		_add_mesh(_cyl(1.3, 1.5, 0.05), p, Color(0.6, 0.58, 0.54), false)

func _saltbox(pos: Vector3, lean: float, color: Color, smokes: bool) -> void:
	var house := Node3D.new()
	house.position = pos
	house.rotation.y = atan2(-pos.x, -pos.z) + lean
	add_child(house)
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(4.6, 2.6, 3.6)
	body.mesh = bb
	body.material_override = _mat(color)
	body.position = Vector3(0, 1.3, 0)
	house.add_child(body)
	body.create_convex_collision()
	# The saltbox roof: short steep front, long low back.
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(5.0, 1.4, 4.6)
	roof.mesh = prism
	roof.material_override = _mat(Color(0.32, 0.3, 0.3))
	roof.position = Vector3(0, 3.3, -0.4)
	house.add_child(roof)
	roof.create_convex_collision()
	var door := MeshInstance3D.new()
	var db := BoxMesh.new()
	db.size = Vector3(0.85, 1.6, 0.1)
	door.mesh = db
	door.material_override = _mat(TRIM)
	door.position = Vector3(-1.2, 0.8, 1.83)
	house.add_child(door)
	for wx: float in [0.5, 1.6]:
		var win := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(0.8, 0.7, 0.08)
		win.mesh = wb
		var wm := StandardMaterial3D.new()
		wm.albedo_color = WARM_WINDOW
		wm.emission_enabled = true
		wm.emission = Color(1.0, 0.82, 0.5)
		wm.emission_energy_multiplier = 1.0
		win.material_override = wm
		win.position = Vector3(wx, 1.35, 1.83)
		house.add_child(win)
	if smokes:
		var chimney := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(0.5, 1.5, 0.5)
		chimney.mesh = cb
		chimney.material_override = _mat(Color(0.45, 0.38, 0.36))
		chimney.position = Vector3(1.5, 3.6, -0.6)
		house.add_child(chimney)

# --- the golf shelf (Cannonball Nine ground; the puzzle dresses it) ---

func _build_golf_shelf() -> void:
	# Granite curb around the terrace lip.
	for k in 10:
		var t := k / 9.0
		var p := Vector3(lerpf(20.5, 33.5, t), 0.72, 8.6)
		_add_box(Vector3(1.3, 0.35, 0.5), p, GRANITE_DARK)
	for k in 10:
		var t := k / 9.0
		_add_box(Vector3(1.3, 0.35, 0.5), Vector3(lerpf(20.5, 33.5, t), 0.72, 24.2), GRANITE_DARK)
	# The cutaway pipes: from under the shelf's south lip toward the dock.
	for i in 9:
		var px := 21.5 + (i % 3) * 4.4
		var pipe := _add_mesh(_cyl(0.16, 0.16, 5.0), Vector3(px, -0.2, 25.8), Color(0.5, 0.42, 0.3), false)
		pipe.rotation.x = PI / 2.0 - 0.22
		pipe.rotation.y = 0.3

# --- the sea cave (built granite passage under the headland lip) ---

func _build_sea_cave() -> void:
	# A dogleg passage of leaning granite slabs, knee-deep at low tide.
	# Piecewise convex slabs keep the inside walkable.
	var slabs: Array = [
		# [size, position, y-rot]
		[Vector3(0.9, 3.4, 5.0), Vector3(28.4, 0.9, 30.0), 0.15],
		[Vector3(0.9, 3.4, 5.0), Vector3(32.6, 0.9, 29.4), -0.2],
		[Vector3(0.9, 3.4, 5.5), Vector3(29.6, 0.9, 24.6), 0.75],
		[Vector3(0.9, 3.4, 5.2), Vector3(34.6, 0.9, 24.4), 0.55],
		[Vector3(0.9, 3.2, 4.2), Vector3(32.2, 0.9, 19.6), 0.9],
	]
	for s: Array in slabs:
		var slab := _add_box(s[0], s[1], GRANITE_DARK)
		slab.rotation.y = s[2]
		slab.rotation.z = 0.06
	# Roof slabs, high enough for a wet cat and a wetter dog.
	for r: Array in [
		[Vector3(5.4, 0.7, 5.6), Vector3(30.4, 2.9, 29.6), 0.1],
		[Vector3(5.8, 0.7, 5.4), Vector3(32.2, 2.9, 23.4), 0.65],
	]:
		var roof := _add_box(r[0], r[1], GRANITE)
		roof.rotation.y = r[2]
		roof.rotation.x = 0.05
	# The grate at the inner end; the spigot wheel gleams behind it.
	var grate := Node3D.new()
	grate.name = "CaveGrate"
	grate.position = Vector3(33.2, 0.4, 20.4)
	grate.rotation.y = 0.9
	add_child(grate)
	for i in 5:
		_child_box(grate, Vector3(0.08, 1.6, 0.08), Vector3(-0.6 + i * 0.3, 0.5, 0), Color(0.35, 0.3, 0.26))
	_child_box(grate, Vector3(1.5, 0.1, 0.1), Vector3(0, 1.25, 0), Color(0.35, 0.3, 0.26))
	var wheel := MeshInstance3D.new()
	wheel.name = "SpigotWheel"
	var wt := TorusMesh.new()
	wt.inner_radius = 0.22
	wt.outer_radius = 0.34
	wheel.mesh = wt
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.7, 0.5, 0.25)
	wmat.metallic = 0.7
	wmat.roughness = 0.35
	wheel.material_override = wmat
	wheel.rotation.x = PI / 2.0
	wheel.position = Vector3(0, 0.6, -0.9)
	grate.add_child(wheel)

# --- the drydock & the Santa Maria ---

func _build_drydock() -> void:
	# Timber sill and bollards around the basin rim.
	for a: Array in [
		[Vector3(6.0, 0.5, 0.6), Vector3(13.0, 0.15, 12.6)],
		[Vector3(0.6, 0.5, 4.5), Vector3(4.6, 0.15, 18.0)],
		[Vector3(0.6, 0.5, 4.5), Vector3(21.4, 0.15, 18.0)],
	]:
		_add_box(a[0], a[1], WOOD_PALE)
	for p: Vector2 in [Vector2(6.0, 14.0), Vector2(20.0, 14.0), Vector2(6.0, 22.0), Vector2(20.0, 22.0)]:
		_add_mesh(_cyl(0.18, 0.22, 0.7), Vector3(p.x, 0.3, p.y), Color(0.3, 0.26, 0.22))
	# The dock's own water: hidden until the spigot floods it.
	var plane := PlaneMesh.new()
	plane.size = Vector2(17.0, 9.0)
	dock_water = MeshInstance3D.new()
	dock_water.mesh = plane
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.42, 0.44, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.2
	dock_water.material_override = m
	dock_water.position = Vector3(13.0, -1.35, 18.0)
	dock_water.visible = false
	add_child(dock_water)
	# The spigot housing at the basin's head, missing its wheel.
	var housing := _add_box(Vector3(0.9, 0.9, 0.6), Vector3(13.0, 0.75, 12.2), Color(0.42, 0.36, 0.3))
	var stem := MeshInstance3D.new()
	stem.name = "SpigotStem"
	stem.mesh = _cyl(0.07, 0.07, 0.5)
	stem.material_override = _mat(Color(0.6, 0.45, 0.25))
	stem.rotation.x = PI / 2.0
	stem.position = Vector3(13.0, 0.95, 11.8)
	add_child(stem)
	var _keep := housing

func _build_ship() -> void:
	ship = Node3D.new()
	ship.name = "SantaMaria"
	ship.position = Vector3(13.0, -1.05, 18.0)
	ship.rotation.y = 0.1
	ship.rotation.z = 0.3   # keeled over in the silt
	add_child(ship)
	# Hull: bottom, flared sides, bow wedge, stern castle. All convex.
	_child_box(ship, Vector3(3.6, 0.5, 12.5), Vector3(0, 0.25, 0), HULL, true)
	for side in [-1.0, 1.0]:
		var wall := _child_box(ship, Vector3(0.35, 1.7, 12.5), Vector3(side * 1.85, 1.15, 0), HULL, true)
		wall.rotation.z = -side * 0.12
		var stripe := _child_box(ship, Vector3(0.1, 0.28, 12.3), Vector3(side * 2.03, 1.75, 0), HULL_TRIM, false)
		stripe.rotation.z = -side * 0.12
	var bow := _child_box(ship, Vector3(2.4, 1.9, 2.4), Vector3(0, 1.1, 6.6), HULL, true)
	bow.rotation.y = PI / 4.0
	# Deck: the walking surface once she floats.
	_child_box(ship, Vector3(3.5, 0.18, 11.8), Vector3(0, 1.95, 0), WOOD_PALE, true)
	# Stern castle with the helm deck.
	_child_box(ship, Vector3(3.3, 1.4, 2.8), Vector3(0, 2.7, -4.6), HULL, true)
	_child_box(ship, Vector3(3.4, 0.16, 3.0), Vector3(0, 3.45, -4.6), WOOD_PALE, true)
	# Rails (thin, collidable: falling through a rail is a betrayal).
	for side in [-1.0, 1.0]:
		_child_box(ship, Vector3(0.08, 0.5, 11.6), Vector3(side * 1.72, 2.28, 0.2), WOOD, true)
	_child_box(ship, Vector3(3.4, 0.5, 0.08), Vector3(0, 2.28, 5.9), WOOD, true)
	# Bowsprit.
	var sprit := _child_mesh(ship, _cyl(0.09, 0.13, 3.6), Vector3(0, 2.3, 8.0), WOOD, false)
	sprit.rotation.x = -1.15
	# Three masts, yards, furled sails; the main crowned by the nest.
	for md: Array in [[Vector3(0, 0, 3.4), 6.5], [Vector3(0, 0, -0.6), 8.6], [Vector3(0, 0, -4.4), 5.8]]:
		var h: float = md[1]
		var mast := _child_mesh(ship, _cyl(0.14, 0.2, h), (md[0] as Vector3) + Vector3(0, 2.0 + h / 2.0, 0), WOOD, true)
		var _k := mast
		var yard := _child_mesh(ship, _cyl(0.07, 0.07, 3.4), (md[0] as Vector3) + Vector3(0, 2.0 + h * 0.72, 0), WOOD, false)
		yard.rotation.z = PI / 2.0
		# Furled sail: a pale roll under the yard; the finale unfurls real ones.
		_child_mesh(ship, _cyl(0.16, 0.16, 3.1), (md[0] as Vector3) + Vector3(0, 1.9 + h * 0.72, 0), SAIL, false).rotation.z = PI / 2.0
	crow_nest = Node3D.new()
	crow_nest.name = "CrowNest"
	crow_nest.position = Vector3(0, 2.0 + 8.6, -0.6)
	ship.add_child(crow_nest)
	var nest_floor := _child_mesh(crow_nest, _cyl(0.6, 0.5, 0.14), Vector3.ZERO, WOOD, false)
	var nest_rail := _child_mesh(crow_nest, _cyl(0.62, 0.62, 0.5), Vector3(0, 0.3, 0), WOOD_PALE, false)
	var _k2 := [nest_floor, nest_rail]
	# Nine cannons: five to port (facing the wharf), four to starboard.
	for i in 9:
		var side := -1.0 if i < 5 else 1.0
		var slot := (i % 5) if i < 5 else (i - 5)
		var cannon := Node3D.new()
		cannon.name = "Cannon%d" % i
		cannon.position = Vector3(side * 1.9, 1.4, 4.2 - slot * 2.1 - (0.9 if i >= 5 else 0.0))
		ship.add_child(cannon)
		var barrel := _child_mesh(cannon, _cyl(0.13, 0.17, 1.1), Vector3.ZERO, Color(0.2, 0.2, 0.22), false)
		barrel.rotation.z = side * (PI / 2.0 - 0.12)
		# Loaded-lamp: glows when this breech takes a ball.
		var lamp := MeshInstance3D.new()
		lamp.name = "Lamp"
		var lm := SphereMesh.new()
		lm.radius = 0.09
		lm.height = 0.18
		lamp.mesh = lm
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.4, 0.38, 0.34)
		lamp.material_override = lmat
		lamp.position = Vector3(-side * 0.35, 0.18, 0)
		cannon.add_child(lamp)
	# The capstan (midship) and the helm (stern deck).
	capstan = Node3D.new()
	capstan.name = "Capstan"
	capstan.position = Vector3(0, 2.05, 1.4)
	ship.add_child(capstan)
	var drum := _child_mesh(capstan, _cyl(0.42, 0.5, 0.7), Vector3(0, 0.35, 0), WOOD, true)
	var _k3 := drum
	for k in 4:
		var bar := _child_mesh(capstan, _cyl(0.05, 0.05, 1.5), Vector3(0, 0.62, 0), WOOD_PALE, false)
		bar.rotation.z = PI / 2.0
		bar.rotation.y = k * PI / 4.0
	# The capstan's tally: sets of four with a diagonal fifth, and a pawprint.
	var tally := _child_box(capstan, Vector3(0.5, 0.2, 0.02), Vector3(0, 0.3, 0.5), Color(0.35, 0.27, 0.2), false)
	tally.name = "Tally"
	helm = Node3D.new()
	helm.name = "Helm"
	helm.position = Vector3(0, 3.55, -3.6)
	ship.add_child(helm)
	var wheel := _child_mesh(helm, TorusMesh.new(), Vector3(0, 0.5, 0), WOOD, false)
	(wheel.mesh as TorusMesh).inner_radius = 0.32
	(wheel.mesh as TorusMesh).outer_radius = 0.42
	for k in 4:
		var spoke := _child_mesh(helm, _cyl(0.03, 0.03, 0.95), Vector3(0, 0.5, 0), WOOD_PALE, false)
		spoke.rotation.z = k * PI / 4.0
	# Anchor and rust-locked chain on the bow.
	anchor_rig = Node3D.new()
	anchor_rig.name = "AnchorRig"
	anchor_rig.position = Vector3(1.6, 1.2, 6.0)
	ship.add_child(anchor_rig)
	_child_box(anchor_rig, Vector3(0.12, 1.1, 0.12), Vector3.ZERO, Color(0.32, 0.3, 0.3), false)
	_child_box(anchor_rig, Vector3(0.7, 0.12, 0.12), Vector3(0, -0.5, 0), Color(0.32, 0.3, 0.3), false)
	for k in 5:
		_child_mesh(anchor_rig, TorusMesh.new(), Vector3(0, 0.75 + k * 0.16, 0), Color(0.45, 0.3, 0.2), false) \
				.scale = Vector3(0.12, 0.12, 0.12)
	# The Jolly Roger: quartered in the four broadside colours.
	var flag := Node3D.new()
	flag.position = Vector3(0, 3.6 + 5.8, -4.4)
	ship.add_child(flag)
	for q in 4:
		_child_box(flag, Vector3(0.5, 0.35, 0.03),
				Vector3(0.26 + 0.5 * (q % 2) - 0.5, -0.18 - 0.35 * (q / 2) + 0.35, 0),
				PENNANTS[ROGER_HOLES[q]], false)

func _ship_groans() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var loop := func() -> void:
		while is_inside_tree():
			await get_tree().create_timer(rng.randf_range(18.0, 40.0)).timeout
			if not is_inside_tree():
				return
			Sfx.play("ship_groan", rng.randf_range(0.9, 1.1), 0.0, -14.0)
	loop.call()

# --- the storm-gate boathouse ---

func _build_boathouse() -> void:
	var house := Node3D.new()
	house.name = "Boathouse"
	house.position = Vector3(-12.0, 0.35, 34.0)
	house.rotation.y = -0.5
	add_child(house)
	_child_box(house, Vector3(3.0, 2.0, 2.4), Vector3(0, 1.0, 0), Color(0.5, 0.44, 0.4), true)
	var roof := _child_box(house, Vector3(3.4, 0.7, 2.8), Vector3(0, 2.3, 0), Color(0.36, 0.32, 0.3), true)
	roof.rotation.z = 0.0
	# The big brass STORM GATE lever, stuck at half-mast.
	var lever := Node3D.new()
	lever.name = "StormLever"
	lever.position = Vector3(1.8, 0.9, 0.6)
	house.add_child(lever)
	var arm := _child_mesh(lever, _cyl(0.05, 0.05, 1.1), Vector3(0, 0.55, 0), Color(0.75, 0.6, 0.28), false)
	arm.rotation.x = -0.9
	var knob := MeshInstance3D.new()
	var kb := SphereMesh.new()
	kb.radius = 0.12
	knob.mesh = kb
	knob.material_override = _mat(Color(0.8, 0.65, 0.3))
	knob.position = Vector3(0, 0.95, 0.45)
	lever.add_child(knob)
	# The pelican holding it down, immune to everything but a growl.
	var pelican := Node3D.new()
	pelican.name = "Pelican"
	pelican.position = Vector3(1.8, 2.0, 0.5)
	house.add_child(pelican)
	var body := _child_mesh(pelican, _capsule(0.28, 0.7), Vector3(0, 0.3, 0), Color(0.92, 0.9, 0.86), false)
	body.rotation.x = PI / 2.0
	var head := MeshInstance3D.new()
	var hb := SphereMesh.new()
	hb.radius = 0.16
	head.mesh = hb
	head.material_override = _mat(Color(0.92, 0.9, 0.86))
	head.position = Vector3(0, 0.62, 0.3)
	pelican.add_child(head)
	var beak := _child_box(pelican, Vector3(0.1, 0.08, 0.5), Vector3(0, 0.58, 0.62), Color(0.85, 0.6, 0.3), false)
	var _k := beak

# --- dressing: traps, dories, buoys, spruce, crates ---

func _build_dressing() -> void:
	# Lobster traps stacked by the wharf root.
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	for i in 7:
		var p := Vector3(-6.5 + (i % 3) * 1.1, 0.62 + (i / 3) * 0.62, 25.0 + rng.randf_range(-0.3, 0.3))
		p.y += _terrain_height(p.x, p.z)
		var trap := _add_box(Vector3(0.95, 0.55, 0.6), p, WOOD_PALE)
		trap.rotation.y = rng.randf_range(-0.2, 0.2)
		for s in 3:
			_add_box(Vector3(0.98, 0.05, 0.05), p + Vector3(0, -0.15 + s * 0.18, 0.31), WOOD, false)
	# Painted trap buoys strung on the shack wall and floating in the cove.
	for i in 5:
		var b := MeshInstance3D.new()
		b.mesh = _capsule(0.14, 0.5)
		b.material_override = _mat(PENNANTS[(i * 2) % PENNANTS.size()])
		b.position = Vector3(3.0 + i * 1.7, WATER_SURFACE_Y + 0.12, 37.0 + (i % 2) * 2.0)
		add_child(b)
		var bob := b.create_tween().set_loops()
		bob.tween_property(b, "position:y", WATER_SURFACE_Y + 0.2, 2.0 + 0.3 * i) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(b, "position:y", WATER_SURFACE_Y + 0.05, 2.0 + 0.3 * i) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Two dories hauled up on the west beach.
	for d: Array in [[Vector3(-8.0, 0.0, 31.0), 0.5, Color(0.72, 0.28, 0.24)],
			[Vector3(-15.0, 0.0, 29.5), -0.3, Color(0.24, 0.52, 0.54)]]:
		var dory := MeshInstance3D.new()
		dory.mesh = _capsule(0.5, 3.0)
		dory.material_override = _mat(d[2])
		var dp: Vector3 = d[0]
		dp.y = _terrain_height(dp.x, dp.z) + 0.3
		dory.position = dp
		dory.rotation.z = PI / 2.0
		dory.rotation.y = d[1]
		dory.scale = Vector3(1.0, 1.0, 0.55)
		add_child(dory)
		var hull_body := StaticBody3D.new()
		hull_body.scale = Vector3(1.0, 1.0, 1.0 / 0.55)
		var hc := CollisionShape3D.new()
		var hbx := BoxShape3D.new()
		hbx.size = Vector3(0.9, 3.0, 0.55)
		hc.shape = hbx
		hull_body.add_child(hc)
		dory.add_child(hull_body)
	# Spruce on the west slope and north rim; none near stones, dock,
	# shelf, cave, or the departure channel (the corridor test enforces).
	for sp: Vector3 in [
		Vector3(-30, 0, -2), Vector3(-26, 0, -9), Vector3(-19, 0, -14), Vector3(-31, 0, 10),
		Vector3(-12, 0, -20), Vector3(-3, 0, -26), Vector3(7, 0, -28), Vector3(16, 0, -24),
		Vector3(25, 0, -18), Vector3(31, 0, -9), Vector3(-8, 0, 12), Vector3(-10, 0, 2),
	]:
		_spruce(Vector3(sp.x, _terrain_height(sp.x, sp.z), sp.z))
	# Crates and barrels by the drydock head.
	for c: Array in [[Vector3(9.0, 0.0, 11.0), 0.3], [Vector3(10.2, 0.0, 11.4), -0.2], [Vector3(9.6, 0.9, 11.2), 0.5]]:
		var p: Vector3 = c[0]
		p.y += _terrain_height(p.x, p.z) + 0.45
		var crate := _add_box(Vector3(0.9, 0.9, 0.9), p, WOOD_PALE)
		crate.rotation.y = c[1]
	_add_mesh(_cyl(0.4, 0.45, 1.0), Vector3(17.5, _terrain_height(17.5, 11.0) + 0.5, 11.0), Color(0.4, 0.3, 0.24))

func _spruce(pos: Vector3) -> void:
	var trunk := _add_mesh(_cyl(0.12, 0.2, 1.4), pos + Vector3(0, 0.7, 0), Color(0.3, 0.22, 0.16))
	var _k := trunk
	for tier in 4:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 1.5 - tier * 0.3
		cm.height = 1.3
		cone.mesh = cm
		cone.material_override = _mat(Color(0.14, 0.28, 0.2).lightened(tier * 0.03))
		cone.position = pos + Vector3(0, 1.3 + tier * 0.85, 0)
		add_child(cone)

# --- fog bank & light ---

func _build_fog_bank() -> void:
	# A pale wall far south that never quite lands. blend_mix, never add.
	for i in 3:
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(220, 26)
		quad.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.86, 0.88, 0.9, 0.24 - i * 0.05)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material_override = m
		quad.position = Vector3(0, 7.0 + i * 3.0, 95.0 + i * 12.0)
		add_child(quad)

func _maritime_light() -> void:
	var mgr := get_parent()
	if mgr == null or not mgr.has_node("Sun"):
		return
	var sun: DirectionalLight3D = mgr.get_node("Sun")
	sun.rotation_degrees = Vector3(-24, -35, 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.0
	var env_node := mgr.get_node_or_null("WorldEnvironment")
	if env_node:
		var sky_mat := (env_node.environment as Environment).sky.sky_material as ProceduralSkyMaterial
		if sky_mat:
			sky_mat.sky_top_color = Color(0.44, 0.54, 0.64)
			sky_mat.sky_horizon_color = Color(0.8, 0.81, 0.8)
			sky_mat.ground_horizon_color = Color(0.72, 0.74, 0.74)

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
