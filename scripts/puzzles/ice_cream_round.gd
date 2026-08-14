extends Node3D
## Island 3, Riddle 2 — The Ice Cream Round.
## The cart's bell lost its clapper years ago. Seat the brass clapper from
## the regatta, then ring the vendor's old round: exactly as many rings as
## the painted note dots, inside one short breath. Get it right and the
## routine wakes: the hatch pops, and the corkboard inside still holds a
## bag of dog biscuits and a spare key with a paw drawn on its tag.

const CART_POS := Vector3(3.0, 0.35, 14.0)
const RING_TARGET := 4
const RING_WINDOW := 6.0

var _rings := 0
var _window_left := 0.0
var _hatch: MeshInstance3D
var _bell_speaker: AudioStreamPlayer3D
var _materials := {}

const BELL_POS := Vector3(3.45, 1.95, 14.2)  # the little brass dome, world space

class BellPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "The cart's little bell"

	func interact(_player: Node) -> void:
		owner_puzzle.bell_interact()

func _ready() -> void:
	# Four painted note dots on the cart's flank: the vendor's round.
	for i in RING_TARGET:
		_box(Vector3(0.09, 0.09, 0.02), CART_POS + Vector3(-0.55 + i * 0.36, 1.05, 0.49),
				Color(0.25, 0.3, 0.5))
		_box(Vector3(0.02, 0.16, 0.02), CART_POS + Vector3(-0.51 + i * 0.36, 1.16, 0.49),
				Color(0.25, 0.3, 0.5))
	# The hatch on the cart's front, shut tight.
	_hatch = _box(Vector3(0.9, 0.6, 0.06), CART_POS + Vector3(0, 0.62, 0.49), Color(0.8, 0.78, 0.74))
	# Convex, never trimesh (hollow shell); the collider rides the hatch
	# when the round pops it open.
	_hatch.create_convex_collision()
	# The bell gets its own voice, right where it hangs: unmissable.
	_bell_speaker = AudioStreamPlayer3D.new()
	_bell_speaker.stream = load("res://assets/audio/bell_ding.wav")
	_bell_speaker.position = BELL_POS
	_bell_speaker.volume_db = 2.0
	_bell_speaker.max_distance = 40.0
	_bell_speaker.bus = "SFX"
	add_child(_bell_speaker)
	var plate := BellPlate.new()
	plate.owner_puzzle = self
	plate.position = CART_POS + Vector3(0.45, 1.6, 0.2)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.9
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

func _ring(pitch: float) -> void:
	_bell_speaker.pitch_scale = pitch
	_bell_speaker.play()
	Sfx.play("bell_ding", pitch, 0.02, -10.0)  # doubled globally, so it always lands
	# A visible ring of sound leaving the bell.
	var ripple := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.18
	ripple.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.5, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ripple.material_override = m
	ripple.position = BELL_POS
	add_child(ripple)
	var t := ripple.create_tween()
	t.set_parallel(true)
	t.tween_property(ripple, "scale", Vector3(4.0, 4.0, 4.0), 0.55)
	t.tween_property(m, "albedo_color:a", 0.0, 0.55)
	t.chain().tween_callback(ripple.queue_free)

func _process(delta: float) -> void:
	if _window_left > 0.0:
		_window_left -= delta
		if _window_left <= 0.0:
			_judge_round()

func bell_interact() -> void:
	if GameState.get_flag("ice_cream_done"):
		_ring(1.0)
		_flash("The bell rings bright and clear. Somewhere, an old routine smiles.", 3.0)
		return
	if not GameState.get_flag("bell_fixed"):
		# A clapperless bell still answers the paw: a dead little clunk.
		Sfx.play("coconut_thunk", 1.7, 0.05, -12.0)
		if Inventory.has_item("brass_clapper"):
			Inventory.remove_item("brass_clapper")
			GameState.set_flag("bell_fixed")
			Sfx.play("pickup_chime", 1.0, 0.0, -10.0)
			_ring(0.9)
			_flash("The clapper seats with a click. The bell has its voice back… and the cart wears four painted notes.", 4.5)
			return
		_flash("A little brass bell, silent. Its clapper is missing, and the lagoon keeps its secrets.", 3.5)
		return
	# Ring, and count the round.
	_rings += 1
	_ring(1.0 + 0.04 * _rings)
	if _rings == 1:
		_window_left = RING_WINDOW
	elif _rings > RING_TARGET:
		_window_left = 0.001  # judged (and failed) almost immediately

func _judge_round() -> void:
	var rings := _rings
	_rings = 0
	_window_left = 0.0
	if rings == RING_TARGET:
		GameState.set_flag("ice_cream_done")
		Sfx.play("stone_slide", 1.3, 0.05, -12.0)
		var t := create_tween()
		t.tween_property(_hatch, "position:y", CART_POS.y + 0.1, 0.8) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		var island := get_parent()
		if island and island.has_method("_add_pickup"):
			island._add_pickup(CART_POS + Vector3(-0.35, 0.3, 0.9), "dog_biscuits",
					"Dog Biscuits", Color(0.72, 0.55, 0.3))
			island._add_pickup(CART_POS + Vector3(0.4, 0.3, 0.9), "paw_key",
					"Paw-Marked Key", Color(0.75, 0.68, 0.4))
		_flash("The round lands! The hatch pops: a bag of biscuits, and a spare key with a paw drawn on the tag.", 5.0)
	else:
		Sfx.play("whisker_shimmer", 0.7, 0.0, -14.0)
		_flash("The bell fades to quiet. Four notes are painted on the flank… ring the round just so.", 3.5)

# --- helpers ---

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_materials[color] = m
	return _materials[color]

func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	return mi
