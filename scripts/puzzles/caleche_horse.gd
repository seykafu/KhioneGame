extends Node3D
## Island 5 — the calèche horse: growl teacher.
## A big grey horse stands blinkered across the only road up the mountain.
## Meow: nothing. Hiss: one ear flick, hooves planted harder. Oreo barks
## and it backs a step. Khione squares up to bark, and what comes out is
## her first growl. The horse steps aside with enormous dignity.
## Lesson: growl is command; big things listen.

var _horse: Node3D
var _hull: StaticBody3D
var _ear: Node3D
var _body: MeshInstance3D
var _tail_node: Node3D
var _idle_t := 0.0
var _tries := 0
var _demonstrated := false

func _process(delta: float) -> void:
	if _horse == null:
		return
	# Idle life: slow breathing, a tail swish, the occasional ear flick.
	_idle_t += delta
	if _body:
		var breath := 1.0 + 0.025 * sin(_idle_t * 1.4)
		_body.scale = Vector3(breath, breath, 1.0)
	if _tail_node:
		_tail_node.rotation.z = 0.25 * sin(_idle_t * 0.9) * (1.0 + 0.4 * sin(_idle_t * 0.23))
	if _ear and fmod(_idle_t, 6.5) < delta:
		var t := create_tween()
		t.tween_property(_ear, "rotation:z", 0.6, 0.1)
		t.tween_property(_ear, "rotation:z", 0.0, 0.25)

func _ready() -> void:
	var island := get_parent()
	_horse = Node3D.new()
	_horse.name = "Horse"
	_horse.position = island.HORSE_POS
	_horse.rotation.y = PI / 2.0   # standing across the road
	add_child(_horse)
	# A proper horse: dapple-grey coat, dark points, harness leather.
	var grey := Color(0.62, 0.62, 0.66)
	var dark := Color(0.32, 0.32, 0.36)
	var charcoal := Color(0.18, 0.18, 0.22)
	var leather := Color(0.24, 0.18, 0.14)
	# Barrel (the breathing part), chest, hindquarters, withers.
	_body = MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.44
	bm.height = 1.5
	_body.mesh = bm
	_body.material_override = _mat(grey)
	_body.rotation.x = PI / 2.0
	_body.position = Vector3(0, 1.32, -0.12)
	_horse.add_child(_body)
	var chest := MeshInstance3D.new()
	var chm := SphereMesh.new()
	chm.radius = 0.38
	chest.mesh = chm
	chest.material_override = _mat(grey)
	chest.position = Vector3(0, 1.26, 0.6)
	_horse.add_child(chest)
	var rump := MeshInstance3D.new()
	var rm := SphereMesh.new()
	rm.radius = 0.42
	rump.mesh = rm
	rump.material_override = _mat(grey)
	rump.position = Vector3(0, 1.38, -0.82)
	rump.scale = Vector3(1.0, 1.05, 1.1)
	_horse.add_child(rump)
	var withers := MeshInstance3D.new()
	var wm := SphereMesh.new()
	wm.radius = 0.24
	withers.mesh = wm
	withers.material_override = _mat(grey)
	withers.position = Vector3(0, 1.66, 0.38)
	_horse.add_child(withers)
	# Dapples: a few lighter patches along the barrel.
	for dp: Vector3 in [Vector3(0.3, 1.45, -0.3), Vector3(-0.32, 1.4, 0.1), Vector3(0.28, 1.5, -0.7), Vector3(-0.3, 1.52, -0.5)]:
		var spot := MeshInstance3D.new()
		var spm := SphereMesh.new()
		spm.radius = 0.11
		spot.mesh = spm
		spot.material_override = _mat(Color(0.72, 0.72, 0.76))
		spot.position = dp
		spot.scale = Vector3(1.0, 0.6, 1.0)
		_horse.add_child(spot)
	# The neck, arched forward and up, with a mane along its ridge.
	var neck := MeshInstance3D.new()
	var nm := CapsuleMesh.new()
	nm.radius = 0.21
	nm.height = 1.1
	neck.mesh = nm
	neck.material_override = _mat(grey)
	neck.position = Vector3(0, 1.98, 0.82)
	neck.rotation.x = -0.72
	_horse.add_child(neck)
	for k in 5:
		var tuft := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.07, 0.2, 0.16)
		tuft.mesh = tm
		tuft.material_override = _mat(charcoal)
		tuft.position = Vector3(0.0, 1.86 + k * 0.16, 0.56 + k * 0.14)
		tuft.rotation.x = -0.72
		tuft.rotation.z = 0.08 * (1 if k % 2 == 0 else -1)
		_horse.add_child(tuft)
	# The head: skull, long face, muzzle, nostrils, both eyes, forelock.
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 2.5, 1.3)
	_horse.add_child(head)
	var skull := MeshInstance3D.new()
	var skm := SphereMesh.new()
	skm.radius = 0.17
	skull.mesh = skm
	skull.material_override = _mat(grey)
	head.add_child(skull)
	var face := MeshInstance3D.new()
	var fm := CapsuleMesh.new()
	fm.radius = 0.115
	fm.height = 0.58
	face.mesh = fm
	face.material_override = _mat(grey)
	face.position = Vector3(0, -0.18, 0.18)
	face.rotation.x = -0.5
	head.add_child(face)
	var muzzle := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.1
	muzzle.mesh = mm
	muzzle.material_override = _mat(dark)
	muzzle.position = Vector3(0, -0.34, 0.34)
	muzzle.scale = Vector3(0.9, 0.8, 1.1)
	head.add_child(muzzle)
	for s: float in [-0.04, 0.04]:
		var nostril := MeshInstance3D.new()
		var nsm := SphereMesh.new()
		nsm.radius = 0.022
		nostril.mesh = nsm
		nostril.material_override = _mat(Color(0.1, 0.1, 0.12))
		nostril.position = Vector3(s, -0.31, 0.43)
		head.add_child(nostril)
	for s: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.045
		eye.mesh = em
		eye.material_override = _mat(Color(0.08, 0.07, 0.08))
		eye.position = Vector3(s * 0.13, 0.02, 0.1)
		head.add_child(eye)
	var forelock := MeshInstance3D.new()
	var flm := BoxMesh.new()
	flm.size = Vector3(0.1, 0.16, 0.08)
	forelock.mesh = flm
	forelock.material_override = _mat(charcoal)
	forelock.position = Vector3(0, 0.14, 0.1)
	forelock.rotation.x = -0.3
	head.add_child(forelock)
	# Blinkers flanking the eyes; the calèche horse's whole worldview.
	for s: float in [-1.0, 1.0]:
		var blinker := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.04, 0.22, 0.22)
		blinker.mesh = bb
		blinker.material_override = _mat(leather)
		blinker.position = Vector3(s * 0.19, 0.02, 0.08)
		head.add_child(blinker)
	# Bridle straps.
	var brow := MeshInstance3D.new()
	var brm := BoxMesh.new()
	brm.size = Vector3(0.3, 0.03, 0.03)
	brow.mesh = brm
	brow.material_override = _mat(leather)
	brow.position = Vector3(0, 0.1, 0.12)
	head.add_child(brow)
	var nose_band := MeshInstance3D.new()
	var nbm := BoxMesh.new()
	nbm.size = Vector3(0.22, 0.03, 0.03)
	nose_band.mesh = nbm
	nose_band.material_override = _mat(leather)
	nose_band.position = Vector3(0, -0.22, 0.3)
	nose_band.rotation.x = -0.5
	head.add_child(nose_band)
	# Both ears; the right one is the famous flicker.
	var ear_l := Node3D.new()
	ear_l.position = Vector3(-0.12, 0.16, -0.02)
	head.add_child(ear_l)
	var elm := MeshInstance3D.new()
	elm.mesh = _cyl(0.0, 0.055, 0.2)
	elm.material_override = _mat(grey)
	elm.position = Vector3(0, 0.1, 0)
	elm.rotation.z = -0.15
	ear_l.add_child(elm)
	_ear = Node3D.new()
	_ear.position = Vector3(0.12, 0.16, -0.02)
	head.add_child(_ear)
	var erm := MeshInstance3D.new()
	erm.mesh = _cyl(0.0, 0.055, 0.2)
	erm.material_override = _mat(grey)
	erm.position = Vector3(0, 0.1, 0)
	erm.rotation.z = 0.15
	_ear.add_child(erm)
	# Four proper legs: upper, cannon, fetlock, hoof. Hind pair angled.
	for lp: Array in [[Vector2(-0.24, 0.58), 0.0], [Vector2(0.24, 0.58), 0.0],
			[Vector2(-0.26, -0.78), 0.14], [Vector2(0.26, -0.78), 0.14]]:
		var leg := Node3D.new()
		var lpv: Vector2 = lp[0]
		leg.position = Vector3(lpv.x, 1.1, lpv.y)
		leg.rotation.x = lp[1]
		_horse.add_child(leg)
		var upper := MeshInstance3D.new()
		upper.mesh = _cyl(0.1, 0.07, 0.55)
		upper.material_override = _mat(grey)
		upper.position = Vector3(0, -0.27, 0)
		leg.add_child(upper)
		var cannon := MeshInstance3D.new()
		cannon.mesh = _cyl(0.055, 0.05, 0.42)
		cannon.material_override = _mat(dark)
		cannon.position = Vector3(0, -0.72, 0)
		leg.add_child(cannon)
		var fetlock := MeshInstance3D.new()
		var fem := SphereMesh.new()
		fem.radius = 0.06
		fetlock.mesh = fem
		fetlock.material_override = _mat(dark)
		fetlock.position = Vector3(0, -0.94, 0)
		leg.add_child(fetlock)
		var hoof := MeshInstance3D.new()
		hoof.mesh = _cyl(0.075, 0.085, 0.12)
		hoof.material_override = _mat(Color(0.12, 0.11, 0.1))
		hoof.position = Vector3(0, -1.04, 0)
		leg.add_child(hoof)
	# The tail: an arc of tapered segments from a swishing root.
	_tail_node = Node3D.new()
	_tail_node.position = Vector3(0, 1.62, -1.22)
	_horse.add_child(_tail_node)
	for td: Array in [[Vector3(0, -0.12, -0.06), 0.35, 0.085], [Vector3(0, -0.42, -0.14), 0.18, 0.065],
			[Vector3(0, -0.7, -0.18), 0.08, 0.045]]:
		var seg := MeshInstance3D.new()
		var sgm := CapsuleMesh.new()
		sgm.radius = td[2]
		sgm.height = 0.42
		seg.mesh = sgm
		seg.material_override = _mat(charcoal)
		seg.position = td[0]
		seg.rotation.x = td[1]
		_tail_node.add_child(seg)
	# Harness: collar at the chest, girth round the barrel, reins to the shafts.
	var collar := MeshInstance3D.new()
	var com := TorusMesh.new()
	com.inner_radius = 0.22
	com.outer_radius = 0.28
	collar.mesh = com
	collar.material_override = _mat(leather)
	collar.position = Vector3(0, 1.62, 0.66)
	collar.rotation.x = PI / 2.0 - 0.72
	_horse.add_child(collar)
	var girth := MeshInstance3D.new()
	var gm := TorusMesh.new()
	gm.inner_radius = 0.46
	gm.outer_radius = 0.52
	girth.mesh = gm
	girth.material_override = _mat(leather)
	girth.position = Vector3(0, 1.3, -0.2)
	girth.rotation.x = PI / 2.0
	girth.scale = Vector3(1.0, 1.0, 1.15)
	_horse.add_child(girth)
	for s: float in [-0.16, 0.16]:
		var rein := MeshInstance3D.new()
		rein.mesh = _cyl(0.015, 0.015, 2.0)
		rein.material_override = _mat(leather)
		rein.position = Vector3(s, 2.0, -0.6)
		rein.rotation.x = PI / 2.0 - 0.2
		_horse.add_child(rein)
	# The calèche behind: a black carriage with two big wheels.
	var cart := Node3D.new()
	cart.position = Vector3(0, 0, -2.6)
	_horse.add_child(cart)
	var box := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(1.4, 0.9, 1.8)
	box.mesh = cb
	box.material_override = _mat(Color(0.12, 0.12, 0.13))
	box.position = Vector3(0, 1.0, 0)
	cart.add_child(box)
	var canopy := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.5, 0.08, 1.4)
	canopy.mesh = cm
	canopy.material_override = _mat(Color(0.12, 0.12, 0.13))
	canopy.position = Vector3(0, 2.1, -0.2)
	cart.add_child(canopy)
	for s: float in [-0.8, 0.8]:
		var wheel := MeshInstance3D.new()
		wheel.mesh = _cyl(0.55, 0.55, 0.08)
		wheel.material_override = _mat(Color(0.5, 0.36, 0.2))
		wheel.rotation.z = PI / 2.0
		wheel.position = Vector3(s, 0.55, 0.2)
		cart.add_child(wheel)
	for s: float in [-0.35, 0.35]:
		var shaft := MeshInstance3D.new()
		shaft.mesh = _cyl(0.03, 0.03, 2.2)
		shaft.material_override = _mat(Color(0.4, 0.3, 0.2))
		shaft.rotation.x = PI / 2.0
		shaft.position = Vector3(s, 1.0, 1.4)
		cart.add_child(shaft)
	# One solid hull for horse + carriage: a wall across the road until
	# she growls. (Never a hollow trimesh, never a walk-through wheel.)
	_hull = StaticBody3D.new()
	_horse.add_child(_hull)
	for def: Array in [[Vector3(1.2, 2.2, 3.4), Vector3(0, 1.1, 0.4)],
			[Vector3(1.9, 2.0, 2.2), Vector3(0, 1.0, -2.6)],
			[Vector3(0.6, 0.6, 1.0), Vector3(0, 2.3, 1.55)]]:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = def[0]
		cs.shape = bx
		cs.position = def[1]
		_hull.add_child(cs)
	GameState.vocal_used.connect(_on_vocal)
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("vocal_unknown"):
		player.vocal_unknown.connect(_on_vocal_unknown)
	if GameState.get_flag("horse_moved"):
		_horse.position += Vector3(4.5, 0, 0)

func _player_near() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return player.global_position.distance_to(_horse.global_position) < 9.0

func _on_vocal(kind: String) -> void:
	if GameState.get_flag("horse_moved") or not _player_near():
		return
	if kind == "meow":
		_tries += 1
		_flash("The horse does not so much as flick an ear.", 3.0)
	elif kind == "hiss":
		_tries += 1
		Sfx.play("horse_snort", 0.9, 0.0, -10.0)
		var t := create_tween()
		t.tween_property(_ear, "rotation:z", 0.8, 0.12)
		t.tween_property(_ear, "rotation:z", 0.0, 0.3)
		_flash("One ear flicks. The hooves plant harder. It is not going anywhere for a hiss.", 3.5)
	elif kind == "growl":
		_growl_moves_it()
		return
	if _tries >= 2 and not _demonstrated:
		_demonstrated = true
		get_tree().create_timer(1.6).timeout.connect(_oreo_demonstrates)

func _oreo_demonstrates() -> void:
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	if oreo == null:
		return
	Sfx.play("bark", 1.0, 0.05, -6.0)
	Sfx.play("horse_snort", 1.1, 0.0, -8.0)
	var t := create_tween()
	t.tween_property(_horse, "position:z", _horse.position.z - 0.5, 0.35).set_trans(Tween.TRANS_SINE)
	if oreo.has_method("hop"):
		oreo.hop()
	_flash("Oreo BARKS. The horse snorts and backs one whole step. That voice has weight… Khione squares up. Try to bark. [G]", 5.5)

func _on_vocal_unknown(kind: String) -> void:
	if kind != "growl" or GameState.get_flag("horse_moved") or not _player_near():
		return
	if not _demonstrated:
		_flash("She tries a bark. It comes out as a cough. Not yet; hear how HE does it first.", 3.5)
		return
	# Her first attempt at a bark comes out as her first growl.
	GameState.learn_vocal("growl")
	Sfx.play("growl", 1.0, 0.0, -4.0)
	_flash("What comes out is not a bark. It is a GROWL, low and true.", 3.0)
	get_tree().create_timer(1.2).timeout.connect(_growl_moves_it)

func _growl_moves_it() -> void:
	if GameState.get_flag("horse_moved"):
		return
	GameState.set_flag("horse_moved")
	Sfx.play("horse_snort", 0.8, 0.0, -8.0)
	var t := create_tween()
	t.tween_property(_horse, "position:x", _horse.position.x + 4.5, 2.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flash("The horse regards her for a long moment. Then it steps aside, with enormous dignity. Growl is command. Big things listen.", 6.0)

## Test hook: the lesson, taken.
func force_learn() -> void:
	_demonstrated = true
	GameState.learn_vocal("growl")
	_growl_moves_it()

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
