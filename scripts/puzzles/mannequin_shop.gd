extends Node3D
## Island 2, Riddle 3 — The Mannequin Quartet.
## A locked shop on the east wall (the fountain's brass key fits). Inside,
## four mannequins on turntable pedestals; on the window glass, a dusty
## poster of a band mid-pose. Copy the poster as read from the atrium and
## the dancers slump: the poster is printed on glass, and glass reads
## backwards. Mirror it (reverse order, flip left and right) and the
## drummer's hand clicks open, holding the skylight crank handle.

# Facing indices: 0 = +z, 1 = -x, 2 = -z, 3 = +x (clockwise steps).
const NAIVE := [2, 1, 0, 3]   # copying the poster literally from outside
const TARGET := [3, 2, 1, 0]  # the mirrored truth
const MANNEQUIN_Z := [6.5, 7.5, 8.5, 9.5]
const ROOM_X := 18.0

const WALL := Color(0.72, 0.7, 0.66)
const CLOTH := Color(0.88, 0.86, 0.82)
const BADGE := Color(0.7, 0.3, 0.3)
const POSTER_PAPER := Color(0.93, 0.9, 0.8)
const POSTER_INK := Color(0.3, 0.25, 0.18)

var _facings := [0, 0, 0, 0]
var _mannequins: Array[Node3D] = []
var _door: MeshInstance3D
var _door_plate: Interactable
var _door_open := false
var _solved := false
var _last_config := []
var _materials := {}

class DoorPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Try the shop door"

	func interact(_player: Node) -> void:
		owner_puzzle.try_open_door()

class MannequinPlate:
	extends Interactable
	var owner_puzzle: Node
	var index := 0

	func _init() -> void:
		prompt = "Turn the mannequin"

	func interact(_player: Node) -> void:
		owner_puzzle.rotate_mannequin(index)

func _ready() -> void:
	_build_room()
	_build_door()
	_build_poster()
	_build_mannequins()

# --- construction ---

func _build_room() -> void:
	_add_box(Vector3(0.3, 3.6, 5.0), Vector3(19.6, 2.1, 8.0), WALL)
	_add_box(Vector3(3.9, 3.6, 0.3), Vector3(17.75, 2.1, 5.6), WALL)
	_add_box(Vector3(3.9, 3.6, 0.3), Vector3(17.75, 2.1, 10.4), WALL)
	_add_box(Vector3(3.9, 0.3, 5.2), Vector3(17.75, 3.95, 8.0), WALL)
	# Glass front panels flanking the door gap.
	for z in [6.35, 9.65]:
		var pane := _add_box(Vector3(0.1, 3.2, 1.5), Vector3(15.95, 1.9, z), Color(0.7, 0.85, 0.92, 0.22))
		pane.material_override = _glass()
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_box(Vector3(0.35, 0.9, 5.4), Vector3(15.8, 3.85, 8.0), Color(0.5, 0.4, 0.62))

func _build_door() -> void:
	_door = _add_box(Vector3(0.12, 3.0, 1.8), Vector3(15.95, 1.8, 8.0), Color(0.28, 0.26, 0.3))
	_door_plate = DoorPlate.new()
	_door_plate.owner_puzzle = self
	_door_plate.position = Vector3(15.6, 1.0, 8.0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.9
	cs.shape = sph
	_door_plate.add_child(cs)
	add_child(_door_plate)

func _build_poster() -> void:
	# On the right-hand pane (as seen from the atrium): a dusty band poster.
	_add_box(Vector3(0.05, 1.25, 1.4), Vector3(15.88, 2.05, 9.65), POSTER_PAPER, false)
	var glyph_z := [9.2, 9.5, 9.8, 10.1]
	# Glyphs, left to right as seen from outside: left arrow, facing-dot,
	# right arrow, away-cross.
	_glyph_arrow(Vector3(15.85, 2.15, glyph_z[0]), -1.0)
	_glyph_dot(Vector3(15.85, 2.15, glyph_z[1]))
	_glyph_arrow(Vector3(15.85, 2.15, glyph_z[2]), 1.0)
	_glyph_cross(Vector3(15.85, 2.15, glyph_z[3]))
	# A worn caption bar under the glyphs.
	_add_box(Vector3(0.04, 0.06, 1.1), Vector3(15.86, 1.72, 9.65), POSTER_INK, false)

func _glyph_arrow(pos: Vector3, dir_z: float) -> void:
	var shaft := _add_box(Vector3(0.03, 0.045, 0.16), pos, POSTER_INK, false)
	shaft.position += Vector3(0, 0, -0.03 * dir_z)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.055
	cone.height = 0.09
	head.mesh = cone
	head.material_override = _mat(POSTER_INK)
	head.rotation.x = PI / 2.0 * dir_z
	head.position = pos + Vector3(0, 0, 0.09 * dir_z)
	add_child(head)

func _glyph_dot(pos: Vector3) -> void:
	var dot := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.055
	cyl.bottom_radius = 0.055
	cyl.height = 0.03
	dot.mesh = cyl
	dot.material_override = _mat(POSTER_INK)
	dot.rotation.z = PI / 2.0
	dot.position = pos
	add_child(dot)

func _glyph_cross(pos: Vector3) -> void:
	for rot in [0.7, -0.7]:
		var bar := _add_box(Vector3(0.03, 0.04, 0.17), pos, POSTER_INK, false)
		bar.rotation.x = rot

func _build_mannequins() -> void:
	for i in MANNEQUIN_Z.size():
		var z: float = MANNEQUIN_Z[i]
		var pedestal := MeshInstance3D.new()
		var ped := CylinderMesh.new()
		ped.top_radius = 0.42
		ped.bottom_radius = 0.48
		ped.height = 0.5
		pedestal.mesh = ped
		pedestal.material_override = _mat(Color(0.45, 0.44, 0.42))
		pedestal.position = Vector3(ROOM_X, 0.63, z)
		add_child(pedestal)
		pedestal.create_trimesh_collision()

		var m := Node3D.new()
		m.position = Vector3(ROOM_X, 0.9, z)
		var torso := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.22
		cap.height = 0.95
		torso.mesh = cap
		torso.material_override = _mat(CLOTH)
		torso.position = Vector3(0, 0.55, 0)
		m.add_child(torso)
		var head := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.16
		hs.height = 0.32
		head.mesh = hs
		head.material_override = _mat(CLOTH)
		head.position = Vector3(0, 1.2, 0)
		m.add_child(head)
		# Face and chest badge mark the front unmistakably.
		var nose := MeshInstance3D.new()
		var nc := CylinderMesh.new()
		nc.top_radius = 0.0
		nc.bottom_radius = 0.04
		nc.height = 0.09
		nose.mesh = nc
		nose.material_override = _mat(BADGE)
		nose.rotation.x = PI / 2.0
		nose.position = Vector3(0, 1.2, 0.17)
		m.add_child(nose)
		var badge := _box_child(m, Vector3(0.16, 0.22, 0.04), Vector3(0, 0.75, 0.21), BADGE)
		badge.rotation.x = 0.1
		var arm_l := _box_child(m, Vector3(0.08, 0.5, 0.08), Vector3(-0.3, 0.55, 0), CLOTH)
		arm_l.rotation.z = 0.35
		var arm_r := _box_child(m, Vector3(0.08, 0.5, 0.08), Vector3(0.3, 0.55, 0), CLOTH)
		arm_r.rotation.z = -0.35
		add_child(m)
		_mannequins.append(m)

		if i == 1:
			# The drummer keeps a little drum in front of the pedestal.
			var drum := MeshInstance3D.new()
			var dc := CylinderMesh.new()
			dc.top_radius = 0.22
			dc.bottom_radius = 0.22
			dc.height = 0.26
			drum.mesh = dc
			drum.material_override = _mat(Color(0.75, 0.35, 0.3))
			drum.position = Vector3(ROOM_X - 0.7, 0.5, z)
			add_child(drum)

		var plate := MannequinPlate.new()
		plate.owner_puzzle = self
		plate.index = i
		plate.position = Vector3(ROOM_X, 1.0, z)
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.1
		cs.shape = sph
		plate.add_child(cs)
		add_child(plate)

# --- the door ---

func try_open_door() -> bool:
	if _door_open:
		return true
	if not Inventory.has_item("brass_key"):
		Sfx.play("coconut_thunk", 1.3, 0.05, -14.0)
		_flash("Locked. The keyhole is small, brass, and smug.", 3.5)
		return false
	_door_open = true
	GameState.set_flag("mannequin_shop_open")
	Sfx.play("coconut_thunk", 1.1, 0.0, -8.0)
	Sfx.play("stone_slide", 1.2, 0.05, -8.0)
	var t := _door.create_tween()
	t.tween_property(_door, "position:y", _door.position.y + 2.7, 1.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_flash("The brass key turns like it never left. The shop exhales dust.", 4.0)
	if _door_plate:
		_door_plate.queue_free()
		_door_plate = null
	return true

# --- the quartet ---

func rotate_mannequin(index: int) -> void:
	if _solved:
		return
	_facings[index] = (_facings[index] + 1) % 4
	Sfx.play("stone_slide", 1.7, 0.08, -16.0)
	var m := _mannequins[index]
	var t := m.create_tween()
	t.tween_property(m, "rotation:y", m.rotation.y - PI / 2.0, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_check_config()

func _check_config() -> void:
	if _facings == _last_config:
		return
	_last_config = _facings.duplicate()
	if _facings == TARGET:
		_solve()
	elif _facings == NAIVE:
		Sfx.play("fail", 1.4, 0.05, -14.0)
		_flash("They strike the pose… hold it… and slump. Something reads backwards.", 4.5)

func _solve() -> void:
	_solved = true
	GameState.set_flag("mannequins_posed")
	Sfx.play("pickup_chime", 1.0, 0.0, -6.0)
	Sfx.play("whisker_shimmer", 0.9, 0.0, -10.0)
	_flash("Click. The drummer's hand opens. It was holding a crank handle all along.", 4.5)
	_spawn_crank(Vector3(ROOM_X - 0.35, 1.35, MANNEQUIN_Z[1]))

func _spawn_crank(pos: Vector3) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/interaction/item_pickup.gd"))
	a.set("item_id", "skylight_crank")
	a.set("display_name", "Skylight Crank")
	a.position = pos
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.3
	cs.shape = sph
	a.add_child(cs)
	var shaft := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.3, 0.05, 0.05)
	shaft.mesh = sb
	shaft.material_override = _mat(Color(0.55, 0.55, 0.6))
	a.add_child(shaft)
	var upright := MeshInstance3D.new()
	var ub := BoxMesh.new()
	ub.size = Vector3(0.05, 0.18, 0.05)
	upright.mesh = ub
	upright.material_override = _mat(Color(0.55, 0.55, 0.6))
	upright.position = Vector3(0.15, 0.09, 0)
	a.add_child(upright)
	var knob := MeshInstance3D.new()
	var ks := SphereMesh.new()
	ks.radius = 0.05
	ks.height = 0.1
	knob.mesh = ks
	knob.material_override = _mat(Color(0.75, 0.35, 0.3))
	knob.position = Vector3(0.15, 0.2, 0)
	a.add_child(knob)
	add_child(a)

# --- helpers ---

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)

func _box_child(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_box(size: Vector3, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	if with_collision:
		mi.create_trimesh_collision()
	return mi

func _glass() -> StandardMaterial3D:
	if not _materials.has("glass"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.85, 0.92, 0.22)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["glass"] = m
	return _materials["glass"]

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[color] = m
	return _materials[color]
