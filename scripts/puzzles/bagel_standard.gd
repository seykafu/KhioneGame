extends Node3D
## Island 5, Riddle 1 — The Bagel Standard.
## The wood-fired oven at the mountain's foot still runs. Interact to
## slide a bagel onto the peel; it goes pale, then golden, then black.
## Pull it (interact again) in the golden second and it is yours; miss
## and it is smoke. Squirrels accept bagels as legal tender, strictly by
## the count: the sign says "12 à la douzaine", and the summit cross has
## exactly twelve lantern bases. The staircase toll takes one.

const CYCLE := 2.6
const GOLDEN_FROM := 1.15
const GOLDEN_TO := 1.85

var _baking := false
var _t := 0.0
var _bagel: MeshInstance3D
var _bagel_mat: StandardMaterial3D

class OvenPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Work the oven"

	func interact(_player: Node) -> void:
		owner_puzzle.oven_interact()

func _ready() -> void:
	var island := get_parent()
	var plate := OvenPlate.new()
	plate.owner_puzzle = self
	plate.position = island.OVEN_POS + Vector3(0, 0.6, 1.2)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.0
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)
	# The peel and the bagel on it, over the oven mouth.
	var peel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.5, 0.03, 1.4)
	peel.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.7, 0.58, 0.4)
	peel.material_override = pmat
	peel.position = island.OVEN_POS + Vector3(0, 1.0, 0.9)
	add_child(peel)
	_bagel = MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.09
	bm.outer_radius = 0.2
	_bagel.mesh = bm
	_bagel_mat = StandardMaterial3D.new()
	_bagel_mat.albedo_color = Color(0.92, 0.85, 0.7)
	_bagel.material_override = _bagel_mat
	_bagel.position = island.OVEN_POS + Vector3(0, 1.06, 0.55)
	_bagel.visible = false
	add_child(_bagel)

func _process(delta: float) -> void:
	if not _baking:
		return
	_t += delta
	var c: Color
	if _t < GOLDEN_FROM:
		c = Color(0.92, 0.85, 0.7).lerp(Color(0.85, 0.6, 0.3), _t / GOLDEN_FROM)
	elif _t < GOLDEN_TO:
		c = Color(0.85, 0.6, 0.3)
	else:
		c = Color(0.85, 0.6, 0.3).lerp(Color(0.12, 0.1, 0.09), (_t - GOLDEN_TO) / (CYCLE - GOLDEN_TO))
	_bagel_mat.albedo_color = c
	if _t >= CYCLE:
		_burn()

func oven_interact() -> void:
	if not _baking:
		_baking = true
		_t = 0.0
		_bagel.visible = true
		_bagel_mat.albedo_color = Color(0.92, 0.85, 0.7)
		Sfx.play("wood_creak", 1.4, 0.05, -18.0)
		if not GameState.get_flag("bagel_taught"):
			GameState.set_flag("bagel_taught")
			_flash("A bagel goes onto the peel and into the heat. Pale, golden, black: pull it in the golden second. [E]", 4.5)
		return
	if _t >= GOLDEN_FROM and _t <= GOLDEN_TO:
		_baking = false
		_bagel.visible = false
		Sfx.play("oven_pop", 1.0, 0.05, -10.0)
		Sfx.play("pickup_chime", 1.2, 0.0, -14.0)
		Inventory.add_item("bagel")
		var n := Inventory.count_of("bagel")
		if n == 12:
			_flash("Twelve! A dozen, exactly as the sign spells it. Squirrels count. So does the mountain.", 4.0)
		else:
			_flash("Golden. That is %d." % n, 1.8)
	else:
		_burn()

func _burn() -> void:
	_baking = false
	_bagel.visible = false
	Sfx.play("fail", 0.9, 0.05, -14.0)
	var smoke := CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 1.2
	smoke.one_shot = true
	smoke.explosiveness = 0.8
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 25.0
	smoke.gravity = Vector3(0, 0.6, 0)
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.2
	var puff := SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.3, 0.3, 0.3, 0.6)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = pm
	smoke.mesh = puff
	smoke.position = _bagel.position
	smoke.emitting = true
	add_child(smoke)
	get_tree().create_timer(2.0).timeout.connect(smoke.queue_free)
	_flash("Smoke. Too early is dough; too late is charcoal. The golden second is short.", 3.0)

## Test hook: bake n perfect bagels.
func force_bake(n: int) -> void:
	for i in n:
		Inventory.add_item("bagel")

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
