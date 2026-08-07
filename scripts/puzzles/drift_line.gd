extends Node3D
## Island 4, Riddle 1 — The Drift Line.
## Last night's squall tore the frozen wash off the laundry line and buried
## it in the drifts. Whisker-pulse the lumps (meow), Oreo digs them free,
## and hang each piece back by its paired clothespin color. The neighbour's
## porch light winks on, and a thermos of cocoa waits on the stoop.

const POLE_A := Vector3(-19.0, 0.35, 6.5)
const POLE_B := Vector3(-13.0, 0.35, 10.5)
const STOOP := Vector3(-19.4, 0.4, 12.6)

## pin color name -> [pin tint, buried item id, mound position]
const WASH := {
	"red": [Color(0.8, 0.3, 0.28), "frozen_mitten", Vector3(-23.0, 0.35, 3.5)],
	"blue": [Color(0.35, 0.5, 0.75), "frozen_scarf", Vector3(-17.5, 0.35, 1.5)],
	"yellow": [Color(0.85, 0.75, 0.3), "frozen_sock", Vector3(-12.0, 0.35, 13.5)],
}

var _hung := {}
var _materials := {}

class PinPlate:
	extends Interactable
	var owner_puzzle: Node
	var pin_color: String

	func _init() -> void:
		prompt = "A paired clothespin"

	func interact(_player: Node) -> void:
		owner_puzzle.try_hang(pin_color)

func _ready() -> void:
	for pole: Vector3 in [POLE_A, POLE_B]:
		_add_mesh(_cyl(0.06, 0.08, 1.9), pole + Vector3(0, 0.95, 0), Color(0.45, 0.38, 0.3), true)
	# The line itself, and one towel that survived the squall (the example).
	var top_a := POLE_A + Vector3(0, 1.8, 0)
	var top_b := POLE_B + Vector3(0, 1.8, 0)
	var line := _add_mesh(_cyl(0.015, 0.015, top_a.distance_to(top_b)),
			(top_a + top_b) / 2.0, Color(0.85, 0.83, 0.78), false)
	var dir := (top_b - top_a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		line.rotate(axis.normalized(), Vector3.UP.angle_to(dir))
	var idx := 0
	for pin_color: String in ["green", "red", "blue", "yellow"]:
		var t := 0.2 + idx * 0.2
		var at := top_a.lerp(top_b, t)
		var tint: Color = Color(0.4, 0.65, 0.4) if pin_color == "green" else WASH[pin_color][0]
		_add_mesh(_box_mesh(Vector3(0.05, 0.12, 0.04)), at + Vector3(0, -0.02, 0), tint, false)
		if pin_color == "green":
			_hang_cloth(at, Color(0.9, 0.88, 0.8))  # the surviving towel
		else:
			var plate := PinPlate.new()
			plate.owner_puzzle = self
			plate.pin_color = pin_color
			plate.position = at + Vector3(0, -0.4, 0)
			var cs := CollisionShape3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 1.4
			cs.shape = sph
			plate.add_child(cs)
			add_child(plate)
		idx += 1
	# The buried wash, waiting for the duet.
	for pin_color: String in WASH:
		var mound := Diggable.new()
		mound.mound_radius = 0.55
		mound.position = WASH[pin_color][2]
		add_child(mound)
		mound.dug.connect(_on_dug.bind(pin_color))

func _on_dug(pin_color: String) -> void:
	var island := get_parent()
	var id: String = WASH[pin_color][1]
	if island.has_method("_add_pickup"):
		island._add_pickup((WASH[pin_color][2] as Vector3) + Vector3(0.3, -0.1, 0.2),
				id, Inventory.display_name(id), WASH[pin_color][0])

func try_hang(pin_color: String) -> void:
	if _hung.has(pin_color):
		_flash("That pin already holds its piece, stiff as a board.", 2.5)
		return
	var id: String = WASH[pin_color][1]
	if not Inventory.has_item(id):
		_flash("An empty clothespin, painted %s. Somewhere under the drifts, its laundry waits." % pin_color, 3.5)
		return
	Inventory.remove_item(id)
	_hung[pin_color] = true
	var idx := ["green", "red", "blue", "yellow"].find(pin_color)
	var at := (POLE_A + Vector3(0, 1.8, 0)).lerp(POLE_B + Vector3(0, 1.8, 0), 0.2 + idx * 0.2)
	_hang_cloth(at, WASH[pin_color][0])
	Sfx.play("pickup_chime", 1.0 + 0.1 * _hung.size(), 0.0, -12.0)
	if _hung.size() >= WASH.size():
		_finish()
	else:
		_flash("Hung, frozen solid, faintly heroic. %d to go." % (WASH.size() - _hung.size()), 3.0)

func _hang_cloth(at: Vector3, tint: Color) -> void:
	var cloth := _add_mesh(_box_mesh(Vector3(0.34, 0.42, 0.03)), at + Vector3(0, -0.24, 0), tint, false)
	cloth.rotation.y = 0.35
	var sway := cloth.create_tween().set_loops()
	sway.tween_property(cloth, "rotation:z", 0.06, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(cloth, "rotation:z", -0.06, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _finish() -> void:
	GameState.set_flag("drift_line_done")
	# The nearest porch takes notice: a warm wink, and cocoa on the stoop.
	var glow := _add_mesh(_box_mesh(Vector3(0.9, 0.75, 0.1)), Vector3(-20.2, 1.7, 13.4), Color(1.0, 0.85, 0.55), false)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.85, 0.55)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.8, 0.5)
	gm.emission_energy_multiplier = 0.4
	glow.material_override = gm
	var wink := glow.create_tween()
	for i in 3:
		wink.tween_property(gm, "emission_energy_multiplier", 2.2, 0.35)
		wink.tween_property(gm, "emission_energy_multiplier", 0.4, 0.35)
	var island := get_parent()
	if island.has_method("_add_pickup"):
		island._add_pickup(STOOP, "cocoa_thermos", "Cocoa Thermos", Color(0.75, 0.35, 0.25))
	_flash("The whole line hangs full again. A porch light winks three times, and something warm appears on the stoop.", 5.0)

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
		m.roughness = 0.9
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
