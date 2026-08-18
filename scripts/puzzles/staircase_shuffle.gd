extends Node3D
## Island 5, Riddle 4 — The Staircase Shuffle.
## Four flights climb the mountain's terraces, and each pivots on its
## landing. The levers are LINKED: lever k swings flight k and flight
## k+1 a quarter turn. From below it is a maze of stairs pointing off
## cliffs; from the chalet balcony the whole zigzag reads at a glance,
## exactly two flights wrong (2 and 4). Lever 2 lost its brass handle to
## the squirrels (the tam-tams give it back). The squirrel baron's toll
## rope guards flight 1: one bagel, strictly by the count.

## Quarter turns from aligned. Flights 2 and 4 start wrong.
var _turns: Array[int] = [0, 1, 0, 1]
var _flights: Array[AnimatableBody3D] = []
var _levers: Array[Node3D] = []
var _toll_rope: MeshInstance3D
var _toll_body: StaticBody3D
var _busy := false

class LeverPlate:
	extends Interactable
	var owner_puzzle: Node
	var idx := 0

	func interact(_player: Node) -> void:
		owner_puzzle.pull(idx)

class TollPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "The squirrel baron's toll rope"

	func interact(_player: Node) -> void:
		owner_puzzle.pay_toll()

func _ready() -> void:
	var island := get_parent()
	for k in island.FLIGHTS.size():
		var f: Array = island.FLIGHTS[k]
		var foot: Vector2 = f[0]
		var head: Vector2 = f[1]
		var y0: float = f[2]
		var y1: float = f[3]
		# The flight pivots about its FOOT landing; aligned = pointing north.
		var body := AnimatableBody3D.new()
		body.name = "Flight%d" % (k + 1)
		body.sync_to_physics = true
		body.position = Vector3(foot.x, y0, foot.y)
		add_child(body)
		var run := absf(head.y - foot.y)
		var rise := y1 - y0
		var length := sqrt(run * run + rise * rise)
		var pitch := atan2(rise, run)
		var ramp := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(1.6, 0.25, length)
		ramp.mesh = rm
		ramp.material_override = _mat(Color(0.62, 0.6, 0.56))
		ramp.position = Vector3(0, rise / 2.0 + 0.05, -run / 2.0)
		ramp.rotation.x = pitch
		body.add_child(ramp)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = rm.size
		cs.shape = bs
		cs.position = ramp.position
		cs.rotation = ramp.rotation
		body.add_child(cs)
		# Iron rails either side, and the tread lines.
		for s: float in [-0.75, 0.75]:
			var rail := MeshInstance3D.new()
			rail.mesh = _cyl(0.03, 0.03, length)
			rail.material_override = _mat(Color(0.22, 0.22, 0.24))
			rail.position = ramp.position + Vector3(s, 0.6, 0)
			rail.rotation.x = pitch + PI / 2.0
			body.add_child(rail)
		for tr in 7:
			var t := (tr + 0.5) / 7.0
			var step := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(1.6, 0.04, 0.12)
			step.mesh = sm
			step.material_override = _mat(Color(0.5, 0.48, 0.44))
			step.position = Vector3(0, 0.18 + rise * t, -run * t)
			step.rotation.x = pitch
			body.add_child(step)
		body.rotation.y = -_turns[k] * PI / 2.0
		_flights.append(body)
		# The lever at the flight's foot, on the landing beside it.
		var lever := Node3D.new()
		lever.name = "Lever%d" % (k + 1)
		lever.position = Vector3(foot.x + 1.6, y0, foot.y + 0.6)
		add_child(lever)
		var post := MeshInstance3D.new()
		post.mesh = _cyl(0.1, 0.12, 0.9)
		post.material_override = _mat(Color(0.3, 0.28, 0.26))
		post.position = Vector3(0, 0.45, 0)
		lever.add_child(post)
		post.create_convex_collision()
		var arm := MeshInstance3D.new()
		arm.name = "Arm"
		arm.mesh = _cyl(0.035, 0.035, 0.7)
		arm.material_override = _mat(Color(0.85, 0.7, 0.3))
		arm.position = Vector3(0, 1.15, 0)
		arm.rotation.z = 0.5
		arm.visible = (k != 1)   # lever 2's handle was stolen
		lever.add_child(arm)
		var plate := LeverPlate.new()
		plate.owner_puzzle = self
		plate.idx = k
		plate.prompt = "Pull lever %d" % (k + 1)
		plate.position = Vector3(0, 0.6, 0)
		var pcs := CollisionShape3D.new()
		var psph := SphereShape3D.new()
		psph.radius = 1.6
		pcs.shape = psph
		plate.add_child(pcs)
		lever.add_child(plate)
		_levers.append(lever)
	# The squirrel baron's toll: a rope across flight 1's foot, and the
	# baron himself on the newel post.
	var f0: Array = island.FLIGHTS[0]
	var foot0: Vector2 = f0[0]
	_toll_body = StaticBody3D.new()
	_toll_body.position = Vector3(foot0.x, 0.35, foot0.y + 0.9)
	add_child(_toll_body)
	var tcs := CollisionShape3D.new()
	var tbs := BoxShape3D.new()
	tbs.size = Vector3(1.8, 2.2, 0.2)
	tcs.shape = tbs
	tcs.position = Vector3(0, 1.1, 0)
	_toll_body.add_child(tcs)
	_toll_rope = MeshInstance3D.new()
	_toll_rope.mesh = _cyl(0.04, 0.04, 1.8)
	_toll_rope.material_override = _mat(Color(0.7, 0.6, 0.4))
	_toll_rope.rotation.z = PI / 2.0
	_toll_rope.position = Vector3(0, 0.9, 0)
	_toll_body.add_child(_toll_rope)
	for s: float in [-0.9, 0.9]:
		var newel := MeshInstance3D.new()
		newel.mesh = _cyl(0.07, 0.09, 1.1)
		newel.material_override = _mat(Color(0.4, 0.32, 0.26))
		newel.position = Vector3(s, 0.55, 0)
		_toll_body.add_child(newel)
	var baron := Node3D.new()
	baron.position = Vector3(0.9, 1.1, 0)
	_toll_body.add_child(baron)
	var bb := MeshInstance3D.new()
	var bcm := CapsuleMesh.new()
	bcm.radius = 0.1
	bcm.height = 0.38
	bb.mesh = bcm
	bb.material_override = _mat(Color(0.45, 0.42, 0.4))
	bb.position = Vector3(0, 0.19, 0)
	baron.add_child(bb)
	var crown := MeshInstance3D.new()
	crown.mesh = _cyl(0.09, 0.07, 0.08)
	crown.material_override = _mat(Color(0.9, 0.78, 0.3))
	crown.position = Vector3(0, 0.42, 0)
	baron.add_child(crown)
	var toll := TollPlate.new()
	toll.owner_puzzle = self
	toll.position = Vector3(0, 0.8, 0)
	var ocs := CollisionShape3D.new()
	var osph := SphereShape3D.new()
	osph.radius = 1.8
	ocs.shape = osph
	toll.add_child(ocs)
	_toll_body.add_child(toll)
	if GameState.get_flag("toll_paid"):
		_drop_rope(true)
	if GameState.get_flag("stairs_fixed"):
		_turns = [0, 0, 0, 0]
		for k in 4:
			_flights[k].rotation.y = 0.0

func pay_toll() -> void:
	if GameState.get_flag("toll_paid"):
		_flash("The baron waves her through, one paw raised in a very small salute.", 3.0)
		return
	if not Inventory.has_item("bagel"):
		Sfx.play("squirrel_chitter", 1.1, 0.0, -10.0)
		_flash("The baron holds out one paw. The paw means: one bagel. There is a bagel oven at the mountain's foot… and a longer way up, for the patient.", 5.0)
		return
	Inventory.remove_item("bagel")
	GameState.set_flag("toll_paid")
	Sfx.play("squirrel_chitter", 1.0, 0.0, -8.0)
	Sfx.play("pickup_chime", 1.0, 0.0, -14.0)
	_drop_rope(false)
	_flash("One bagel, taken with ceremony. The rope drops. Contracts honoured to the letter, on this mountain.", 4.5)

func _drop_rope(instant: bool) -> void:
	for c in _toll_body.get_children():
		if c is CollisionShape3D:
			c.disabled = true
	if instant:
		_toll_rope.position.y = 0.05
	else:
		var t := create_tween()
		t.tween_property(_toll_rope, "position:y", 0.05, 0.5).set_trans(Tween.TRANS_BOUNCE)

func pull(idx: int) -> void:
	if _busy:
		return
	if idx == 1 and not GameState.get_flag("lever2_handled"):
		if Inventory.has_item("lever_handle"):
			Inventory.remove_item("lever_handle")
			GameState.set_flag("lever2_handled")
			(_levers[1].get_node("Arm") as MeshInstance3D).visible = true
			Sfx.play("lever_clunk", 1.2, 0.0, -10.0)
			_flash("The brass handle seats with a click. Lever two lives again.", 3.0)
			return
		_flash("A lever with no handle: a bare iron stub. Something on this mountain steals brass.", 3.5)
		return
	if GameState.get_flag("stairs_fixed"):
		_flash("The zigzag is true, top to bottom. Leave it be.", 2.5)
		return
	_busy = true
	Sfx.play("lever_clunk", 1.0, 0.03, -8.0)
	var arm := _levers[idx].get_node("Arm") as MeshInstance3D
	var at := create_tween()
	at.tween_property(arm, "rotation:z", -0.5, 0.25)
	at.tween_property(arm, "rotation:z", 0.5, 0.35)
	# This flight and the next swing a quarter turn.
	var moved: Array[int] = [idx]
	if idx + 1 < _flights.size():
		moved.append(idx + 1)
	var t := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.set_parallel(true)
	for k in moved:
		_turns[k] = (_turns[k] + 1) % 4
		Sfx.play("stone_slide", 0.9, 0.05, -12.0)
		t.tween_property(_flights[k], "rotation:y", _flights[k].rotation.y - PI / 2.0, 1.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.chain().tween_callback(func() -> void:
		_busy = false
		_check())

func _check() -> void:
	for k in _turns.size():
		if _turns[k] != 0:
			return
	GameState.set_flag("stairs_fixed")
	Sfx.play("pickup_chime", 1.2, 0.0, -8.0)
	_flash("Every flight points true: one clean zigzag from the plaza to the summit. The mountain is hers, the short way, forever.", 5.0)

## Whether flight k (0-based) is aligned uphill right now.
func flight_aligned(k: int) -> bool:
	return _turns[k] == 0

## Test hook: solve outright.
func force_fix() -> void:
	_turns = [0, 0, 0, 0]
	for k in 4:
		_flights[k].rotation.y = 0.0
	GameState.set_flag("stairs_fixed")

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
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
