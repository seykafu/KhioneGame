extends Node3D
## Island 4, Riddle 3 — The Mailbox Morse.
## Six mailboxes, six red flags, and a squall that scrambles them on every
## pass. The curb numbers are painted flat on the ground: readable only
## from up high (the top of the slide). Odd flags up, even flags down, all
## six in one stillness, and the postal truck's tape deck clicks open.

const MAILBOX_R := 19.0
const HOUSE_ANGLES := [2.62, 3.32, 4.01, 4.71, 5.41, 6.11]
const NUMBERS := [3, 8, 5, 12, 7, 4]
const TRUCK_POS := Vector3(17.0, 0.35, 9.5)

var _flags_up: Array[bool] = []
var _flag_meshes: Array[MeshInstance3D] = []
var _materials := {}

class FlagPlate:
	extends Interactable
	var owner_puzzle: Node
	var idx: int

	func _init() -> void:
		prompt = "A mailbox flag"

	func interact(_player: Node) -> void:
		owner_puzzle.toggle_flag(idx)

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	for i in HOUSE_ANGLES.size():
		var a: float = HOUSE_ANGLES[i]
		var pos := Vector3(cos(a) * MAILBOX_R, 0.35, sin(a) * MAILBOX_R)
		_add_mesh(_cyl(0.05, 0.07, 1.0), pos + Vector3(0, 0.5, 0), Color(0.4, 0.34, 0.28), true)
		var box := _add_mesh(_box_mesh(Vector3(0.34, 0.26, 0.5)), pos + Vector3(0, 1.1, 0),
				Color(0.3, 0.34, 0.4), true)
		box.rotation.y = -a
		var flag := _add_mesh(_box_mesh(Vector3(0.05, 0.22, 0.16)), pos + Vector3(0, 1.28, 0),
				Color(0.85, 0.25, 0.2), false)
		flag.rotation.y = -a
		_flag_meshes.append(flag)
		_flags_up.append(rng.randf() < 0.5)
		# The curb number, painted flat: legible from above, mush from the side.
		var num := Label3D.new()
		num.text = str(NUMBERS[i])
		num.font_size = 220
		num.pixel_size = 0.004
		num.modulate = Color(0.95, 0.93, 0.85)
		num.outline_size = 24
		num.outline_modulate = Color(0.4, 0.38, 0.34)
		num.position = Vector3(cos(a) * 17.2, 0.42, sin(a) * 17.2)
		num.rotation.x = -PI / 2.0
		num.rotation.z = -a + PI / 2.0
		add_child(num)
		var plate := FlagPlate.new()
		plate.owner_puzzle = self
		plate.idx = i
		plate.position = pos + Vector3(0, 1.1, 0)
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.5
		cs.shape = sph
		plate.add_child(cs)
		add_child(plate)
		_apply_flag(i, true)
	_build_truck()
	GameState.flag_changed.connect(_on_weather)

func _build_truck() -> void:
	var body := _add_mesh(_box_mesh(Vector3(1.9, 1.6, 3.6)), TRUCK_POS + Vector3(0, 1.15, 0),
			Color(0.92, 0.9, 0.86), true)
	body.rotation.y = 0.5
	var stripe := _add_mesh(_box_mesh(Vector3(1.94, 0.28, 3.62)), TRUCK_POS + Vector3(0, 1.25, 0),
			Color(0.75, 0.3, 0.3), false)
	stripe.rotation.y = 0.5
	var cab := _add_mesh(_box_mesh(Vector3(1.7, 1.0, 1.1)), TRUCK_POS + Vector3(-1.15, 0.85, 2.0)
			.rotated(Vector3.UP, 0.0), Color(0.85, 0.84, 0.8), true)
	cab.position = TRUCK_POS + Vector3(0, 0.85, 0) + Vector3(0, 0, 2.3).rotated(Vector3.UP, 0.5)
	cab.rotation.y = 0.5
	for s: Array in [[-0.8, 1.2], [0.8, 1.2], [-0.8, -1.2], [0.8, -1.2]]:
		var wheel := _add_mesh(_cyl(0.32, 0.32, 0.2), TRUCK_POS + Vector3(0, 0.32, 0)
				+ Vector3(s[0], 0, s[1]).rotated(Vector3.UP, 0.5), Color(0.15, 0.15, 0.17), false)
		wheel.rotation.z = PI / 2.0
		wheel.rotation.y = 0.5

func _apply_flag(i: int, instant := false) -> void:
	var flag := _flag_meshes[i]
	var target := 0.0 if _flags_up[i] else 1.35
	if instant:
		flag.rotation.z = target
		return
	var t := flag.create_tween()
	t.tween_property(flag, "rotation:z", target, 0.3).set_trans(Tween.TRANS_QUAD)

func toggle_flag(i: int) -> void:
	if GameState.get_flag("mailbox_done"):
		_flash("The route is read; the flags can rest.", 2.5)
		return
	_flags_up[i] = not _flags_up[i]
	_apply_flag(i)
	Sfx.play("wood_creak", 1.5, 0.1, -16.0)
	_check()

func _check() -> void:
	var island := get_parent()
	if island.has_method("is_squalling") and island.is_squalling():
		return  # nothing counts in flying snow
	for i in NUMBERS.size():
		var want_up: bool = (NUMBERS[i] % 2) == 1
		if _flags_up[i] != want_up:
			return
	GameState.set_flag("mailbox_done")
	Sfx.play("pickup_chime", 1.1, 0.0, -8.0)
	Sfx.play("stone_slide", 1.2, 0.05, -12.0)
	# The truck's rear door rolls up: salt, and letters nobody delivered.
	var door := _add_mesh(_box_mesh(Vector3(1.7, 1.3, 0.08)), TRUCK_POS + Vector3(0, 1.0, 0)
			+ Vector3(0, 0, -1.85).rotated(Vector3.UP, 0.5), Color(0.6, 0.6, 0.62), false)
	door.rotation.y = 0.5
	var t := door.create_tween()
	t.tween_property(door, "position:y", door.position.y + 1.1, 1.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	for k in 3:
		_add_mesh(_box_mesh(Vector3(0.3, 0.05, 0.2)), TRUCK_POS + Vector3(0, 0.6 + k * 0.06, 0)
				+ Vector3(0.2 - k * 0.2, 0, -1.4).rotated(Vector3.UP, 0.5), Color(0.9, 0.87, 0.8), false)
	if island.has_method("_add_pickup"):
		island._add_pickup(TRUCK_POS + Vector3(0, 0.4, 0) + Vector3(0, 0, -2.6).rotated(Vector3.UP, 0.5),
				"road_salt", "Road Salt", Color(0.6, 0.75, 0.85))
	_flash("Six flags agree, and the tape deck believes them. The truck rolls open: road salt, and a bundle of letters that never made it.", 5.5)

func _on_weather(flag: String, value: bool) -> void:
	if flag != "prairie_gust" or not value or GameState.get_flag("mailbox_done"):
		return
	# The squall has opinions about her progress.
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec() as int
	var flips := rng.randi_range(2, 3)
	for k in flips:
		var i := rng.randi_range(0, _flags_up.size() - 1)
		_flags_up[i] = not _flags_up[i]
		_apply_flag(i)

# --- helpers ---

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)

func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_materials[color] = m
	return _materials[color]

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color, with_collision := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	if with_collision:
		mi.create_trimesh_collision()
	return mi
