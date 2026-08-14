extends Node3D
## Island 5, Riddle 2 — The Cannonball Nine.
## Nine golf holes on the granite shelf feed nine cannon breeches on the
## Santa Maria (the cutaway pipes under the shelf lip tell the truth).
## Each hole's flag wears a pennant; the Jolly Roger wears four colours.
## Load ONLY the matching cannons and the broadside cracks the anchor's
## rust. Any wrong ball in the battery and the volley is confetti.

const HOLE_ORIGIN := Vector3(22.0, 0.75, 11.0)
const HOLE_STEP := Vector2(4.4, 4.6)
const LANYARD_POS := Vector3(7.0, 0.4, 17.0)

var _loaded: Array[bool] = []
var _flags: Array[Node3D] = []

class HolePlate:
	extends Interactable
	var owner_puzzle: Node
	var idx := 0

	func interact(_player: Node) -> void:
		owner_puzzle.putt(idx)

class Lanyard:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Pull the firing lanyard"

	func interact(_player: Node) -> void:
		owner_puzzle.fire()

func _ready() -> void:
	_loaded.resize(9)
	_loaded.fill(false)
	var island := get_parent()
	for i in 9:
		var pos := HOLE_ORIGIN + Vector3((i % 3) * HOLE_STEP.x, 0, (i / 3) * HOLE_STEP.y)
		# Felt pad, cup, flag with its pennant.
		var pad := MeshInstance3D.new()
		pad.mesh = _cyl(1.1, 1.2, 0.08)
		pad.material_override = _flat(Color(0.24, 0.42, 0.3))
		pad.position = pos
		add_child(pad)
		pad.create_convex_collision()
		var cup := MeshInstance3D.new()
		cup.mesh = _cyl(0.14, 0.14, 0.06)
		cup.material_override = _flat(Color(0.1, 0.1, 0.1))
		cup.position = pos + Vector3(0.35, 0.06, 0.1)
		add_child(cup)
		var pole := MeshInstance3D.new()
		pole.mesh = _cyl(0.03, 0.03, 1.5)
		pole.material_override = _flat(Color(0.85, 0.85, 0.85))
		pole.position = pos + Vector3(0.35, 0.8, 0.1)
		add_child(pole)
		var pennant := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, 0.28, 0.03)
		pennant.mesh = pm
		pennant.material_override = _flat(island.PENNANTS[i])
		pennant.position = pos + Vector3(0.6, 1.42, 0.1)
		add_child(pennant)
		_flags.append(pennant)
		var plate := HolePlate.new()
		plate.owner_puzzle = self
		plate.idx = i
		plate.prompt = "Putt into the %s-pennant hole" % _colour_name(i)
		plate.position = pos
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.5
		cs.shape = sph
		plate.add_child(cs)
		add_child(plate)
	var lan := Lanyard.new()
	lan.position = LANYARD_POS
	lan.owner_puzzle = self
	var lcs := CollisionShape3D.new()
	var lsph := SphereShape3D.new()
	lsph.radius = 1.8
	lcs.shape = lsph
	lan.add_child(lcs)
	add_child(lan)
	var post := MeshInstance3D.new()
	post.mesh = _cyl(0.08, 0.1, 1.1)
	post.material_override = _flat(Color(0.4, 0.32, 0.26))
	post.position = LANYARD_POS + Vector3(0, 0.55, 0)
	add_child(post)
	post.create_convex_collision()

func putt(idx: int) -> void:
	if GameState.get_flag("broadside_done"):
		_flash("The battery has said its piece; the anchor chain is cracked clean.", 3.0)
		return
	if not Inventory.has_item("golf_balls"):
		_flash("No balls. The range bag glints up on the wharf's net loft — where only the big wave goes.", 4.5)
		return
	if _loaded[idx]:
		_flash("That breech is already loaded.", 2.0)
		return
	_loaded[idx] = true
	Sfx.play("coconut_thunk", 1.3, 0.05, -14.0)
	Sfx.play("stone_slide", 1.6, 0.0, -20.0)
	_set_cannon_lamp(idx, true)
	_flash("The ball rattles down the cutaway pipe… a breech thunks shut aboard the Santa Maria.", 3.5)

func fire() -> void:
	if GameState.get_flag("broadside_done"):
		_flash("Nothing left to fire but celebration, and she is saving that.", 3.0)
		return
	var any := false
	for l: bool in _loaded:
		if l:
			any = true
	if not any:
		_flash("The lanyard wants loaded cannons first. The holes feed the breeches.", 3.5)
		return
	var island := get_parent()
	var correct := true
	for i in 9:
		var should: bool = i in island.ROGER_HOLES
		if _loaded[i] != should:
			correct = false
	if correct:
		GameState.set_flag("broadside_done")
		for k in 4:
			get_tree().create_timer(0.15 * k).timeout.connect(func() -> void:
				Sfx.play("cannon_boom", 0.95 + 0.05 * k, 0.03, -4.0))
		_rust_burst(island)
		_flash("FOUR TRUE GUNS. The broadside rolls across the cove and the anchor chain sheds its rust like old skin.", 5.5)
	else:
		for i in 9:
			_loaded[i] = false
			_set_cannon_lamp(i, false)
		Sfx.play("confetti_pop", 1.0, 0.05, -6.0)
		_confetti(island)
		_flash("The wrong guns answer with CONFETTI. The parrot approves. The anchor does not. (Match the Jolly Roger's colours.)", 5.0)

func _set_cannon_lamp(idx: int, on: bool) -> void:
	var island := get_parent()
	var cannon: Node3D = (island.ship as Node3D).get_node_or_null("Cannon%d" % idx)
	if cannon == null:
		return
	var lamp := cannon.get_node_or_null("Lamp") as MeshInstance3D
	if lamp:
		var m := StandardMaterial3D.new()
		if on:
			m.albedo_color = Color(1.0, 0.8, 0.35)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.75, 0.3)
			m.emission_energy_multiplier = 1.6
		else:
			m.albedo_color = Color(0.4, 0.38, 0.34)
		lamp.material_override = m
	# The matching pennant dips in salute when its breech is loaded.
	if idx < _flags.size():
		_flags[idx].position.y += (-0.3 if on else 0.3)

func _rust_burst(island: Node) -> void:
	var rig: Node3D = island.anchor_rig
	if rig == null:
		return
	var burst := CPUParticles3D.new()
	burst.amount = 30
	burst.lifetime = 0.8
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 60.0
	burst.gravity = Vector3(0, -6, 0)
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.0
	var flake := SphereMesh.new()
	flake.radius = 0.05
	flake.height = 0.1
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.6, 0.35, 0.2)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = fm
	burst.mesh = flake
	burst.emitting = true
	rig.add_child(burst)

func _confetti(island: Node) -> void:
	var burst := CPUParticles3D.new()
	burst.amount = 80
	burst.lifetime = 1.4
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 75.0
	burst.gravity = Vector3(0, -3, 0)
	burst.initial_velocity_min = 3.0
	burst.initial_velocity_max = 7.0
	var bit := BoxMesh.new()
	bit.size = Vector3(0.1, 0.1, 0.02)
	burst.mesh = bit
	burst.position = (island.ship as Node3D).global_position + Vector3(0, 4.0, 0)
	burst.emitting = true
	add_child(burst)
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)

func _colour_name(i: int) -> String:
	return ["black", "red", "white", "gold", "teal", "purple", "green", "orange", "sky"][i]

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
