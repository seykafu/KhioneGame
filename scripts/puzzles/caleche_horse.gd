extends Node3D
## Island 5 — the calèche horse: growl teacher.
## A big grey horse stands blinkered across the only road up the mountain.
## Meow: nothing. Hiss: one ear flick, hooves planted harder. Oreo barks
## and it backs a step. Khione squares up to bark, and what comes out is
## her first growl. The horse steps aside with enormous dignity.
## Lesson: growl is command; big things listen.

const ANIM := "AnimalArmature|AnimalArmature|AnimalArmature|"

var _horse: Node3D
var _hull: StaticBody3D
var _anim: AnimationPlayer
var _tries := 0
var _demonstrated := false

## Play a looping animation (Idle, Idle_Eating).
func _loop_anim(name: String) -> void:
	if _anim == null:
		return
	var a := _anim.get_animation(ANIM + name)
	if a:
		a.loop_mode = Animation.LOOP_LINEAR
	_anim.play(ANIM + name, 0.4)

## Play a one-shot (Headbutt, Walk burst), then settle back into a loop.
func _oneshot_anim(name: String, then_loop: String) -> void:
	if _anim == null:
		return
	var a := _anim.get_animation(ANIM + name)
	if a:
		a.loop_mode = Animation.LOOP_NONE
	_anim.play(ANIM + name, 0.25)
	var len := a.length if a else 1.0
	get_tree().create_timer(len + 0.1).timeout.connect(func() -> void:
		if _anim and _anim.current_animation != ANIM + name:
			return
		_loop_anim(then_loop))

func _ready() -> void:
	var island := get_parent()
	_horse = Node3D.new()
	_horse.name = "Horse"
	_horse.position = island.HORSE_POS
	_horse.rotation.y = PI / 2.0   # standing across the road
	add_child(_horse)
	# The horse itself: a real rigged model ("Horse" by Quaternius,
	# poly.pizza/m/D3hAeqeDBE, CC0 — same stable as Khione's own model),
	# scaled to calèche stature and living on its own animations.
	var model: Node3D = (load("res://assets/characters/horse.glb") as PackedScene).instantiate()
	model.scale = Vector3.ONE * 0.85
	model.position = Vector3(0, 0, -0.2)   # hindquarters between the shafts
	_horse.add_child(model)
	_anim = model.get_node("AnimationPlayer") as AnimationPlayer
	_loop_anim("Idle")
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
		_loop_anim("Idle_Eating")

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
		_oneshot_anim("Headbutt", "Idle")
		_flash("One ear flicks, the head tosses. The hooves plant harder. It is not going anywhere for a hiss.", 3.5)
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
	_oneshot_anim("Walk", "Idle")
	var t := create_tween()
	t.tween_property(_horse, "position:z", _horse.position.z - 0.5, 0.6).set_trans(Tween.TRANS_SINE)
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
	_loop_anim("Walk")
	var t := create_tween()
	t.tween_property(_horse, "rotation:y", _horse.rotation.y + PI / 2.0, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_horse, "position:x", _horse.position.x + 4.5, 2.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void:
		var back := create_tween()
		back.tween_property(_horse, "rotation:y", PI / 2.0, 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_loop_anim("Idle_Eating"))
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
