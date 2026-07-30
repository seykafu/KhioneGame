extends CharacterBody3D
## Khione — third-person cat controller.
## Walk / run / jump on land, buoyant swimming in water, camera-relative movement.
## Vocalizations (meow / hiss / growl) are puzzle verbs broadcast through GameState.

signal vocalized(kind: String)
signal vocal_unknown(kind: String)

const WALK_SPEED := 4.0
const RUN_SPEED := 7.0
const SWIM_SPEED := 3.0
const JUMP_VELOCITY := 7.5
const SWIM_KICK := 5.0
const GRAVITY := 20.0
const TURN_SPEED := 10.0
const SWIM_DEPTH := 0.35

const VOCALS := ["meow", "hiss", "growl"]

@onready var rig: Node3D = $CameraRig
@onready var body_visual: Node3D = $Body

var controls_enabled := true
var _water_zones := 0
var _water_surface := 0.0
var _nearby: Array = []
var _spawn := Vector3.ZERO
var anim: AnimationPlayer = null
var _anim_map := {}
var _meow_sfx: AudioStreamPlayer3D
var _step_accum := 0.0
var _was_on_floor := true
var _was_swimming := false
var _idle_time := 0.0
var _prev_yaw := 0.0
var _step_side := 1.0
var _sand_particles: CPUParticles3D

func _ready() -> void:
	_spawn = global_position
	_setup_animations()
	_meow_sfx = AudioStreamPlayer3D.new()
	_meow_sfx.stream = load("res://assets/audio/meow.wav")
	add_child(_meow_sfx)
	_build_sand_particles()

func _build_sand_particles() -> void:
	_sand_particles = CPUParticles3D.new()
	_sand_particles.amount = 14
	_sand_particles.lifetime = 0.5
	_sand_particles.emitting = false
	var grain := SphereMesh.new()
	grain.radius = 0.03
	grain.height = 0.06
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.88, 0.8, 0.6)
	grain.material = m
	_sand_particles.mesh = grain
	_sand_particles.direction = Vector3(0, 1, 0)
	_sand_particles.spread = 40.0
	_sand_particles.initial_velocity_min = 0.5
	_sand_particles.initial_velocity_max = 1.3
	_sand_particles.gravity = Vector3(0, -7, 0)
	_sand_particles.position = Vector3(0, 0.05, 0)
	add_child(_sand_particles)

func _setup_animations() -> void:
	# The imported GLB prefixes animation names ("AnimalArmature|...|Walk"),
	# so map by suffix and force looping on the locomotion clips.
	anim = body_visual.find_child("AnimationPlayer", true, false)
	if anim == null:
		return
	for n in anim.get_animation_list():
		for key in ["Idle_Eating", "Jump_Start", "Jump_Loop", "Idle", "Walk", "Run", "Headbutt", "Death"]:
			if n.ends_with(key) and not _anim_map.has(key):
				_anim_map[key] = n
		if n.ends_with("Idle") or n.ends_with("Walk") or n.ends_with("Run") \
				or n.ends_with("Jump_Loop") or n.ends_with("Idle_Eating"):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_flatten_snout()
	_play_anim("Idle")

func _flatten_snout() -> void:
	# Persian flat face: strip any Head scale tracks from the imported
	# animations, then squash the head bone along the muzzle axis.
	for n in anim.get_animation_list():
		var a := anim.get_animation(n)
		for ti in range(a.get_track_count() - 1, -1, -1):
			if a.track_get_type(ti) == Animation.TYPE_SCALE_3D \
					and String(a.track_get_path(ti)).ends_with("Head"):
				a.remove_track(ti)
	var skel: Skeleton3D = body_visual.find_child("Skeleton3D", true, false)
	if skel:
		var head := skel.find_bone("Head")
		if head != -1:
			skel.set_bone_pose_scale(head, Vector3(1.05, 1.04, 0.72))

func _play_anim(key: String, blend := 0.25, speed := 1.0) -> void:
	if anim == null or not _anim_map.has(key):
		return
	var anim_name: String = _anim_map[key]
	if anim.current_animation == anim_name:
		return
	anim.play(anim_name, blend, speed)

func _physics_process(delta: float) -> void:
	var input_vec := Vector2.ZERO
	if controls_enabled:
		input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input_vec.x, 0.0, input_vec.y).rotated(Vector3.UP, rig.rotation.y)
	var swimming := is_swimming()

	var speed := SWIM_SPEED
	if not swimming:
		speed = RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED

	var blend := clampf(10.0 * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, dir.x * speed, blend)
	velocity.z = lerpf(velocity.z, dir.z * speed, blend)

	if swimming:
		# Buoyancy keeps Khione bobbing just under the surface; Space paddles up
		# so she can climb out onto low shores and rocks.
		var target_y := _water_surface - SWIM_DEPTH
		velocity.y = clampf((target_y - global_position.y) * 4.0, -3.0, 3.0)
		if controls_enabled and Input.is_action_just_pressed("jump"):
			velocity.y = SWIM_KICK
	else:
		velocity.y -= GRAVITY * delta
		if controls_enabled and is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			Sfx.play("jump_whoosh", 1.0, 0.08, -10.0)
			_stretch_jump()

	move_and_slide()

	var moving := dir.length_squared() > 0.01
	if moving:
		var target_yaw := atan2(dir.x, dir.z)
		body_visual.rotation.y = lerp_angle(body_visual.rotation.y, target_yaw, TURN_SPEED * delta)

	# Lean into turns like a real cat.
	var yaw_delta := wrapf(body_visual.rotation.y - _prev_yaw, -PI, PI)
	_prev_yaw = body_visual.rotation.y
	var target_roll := clampf(-yaw_delta * 6.0, -0.25, 0.25)
	body_visual.rotation.z = lerpf(body_visual.rotation.z, target_roll, 8.0 * delta)

	_idle_time = 0.0 if (moving or swimming or not is_on_floor()) else _idle_time + delta
	_sand_particles.emitting = not swimming and is_on_floor() and moving \
			and Input.is_action_pressed("run") and global_position.y <= 0.2

	_update_anim(swimming, moving)
	_update_sfx(delta, swimming, moving)

	if global_position.y < -25.0:
		global_position = _spawn
		velocity = Vector3.ZERO

func _update_sfx(delta: float, swimming: bool, moving: bool) -> void:
	if swimming and not _was_swimming:
		Sfx.play("splash", 1.0, 0.08, -4.0)
	elif _was_swimming and not swimming:
		Sfx.play("splash", 1.3, 0.08, -12.0)
	if not _was_on_floor and is_on_floor() and not swimming:
		Sfx.play("land", 1.0, 0.1, -10.0)
		_squash_land()
	if swimming and moving:
		_step_accum += delta
		if _step_accum >= 0.62:
			_step_accum = 0.0
			Sfx.play("swim_stroke", 1.0, 0.1, -8.0)
			_spawn_splash_ring()
	elif is_on_floor() and moving:
		_step_accum += delta
		var interval := 0.22 if Input.is_action_pressed("run") else 0.34
		if _step_accum >= interval:
			_step_accum = 0.0
			# Grass plateau sits above y=0.2; everything lower is beach sand.
			var on_grass := global_position.y > 0.2
			Sfx.play("paw_grass" if on_grass else "paw_sand", 1.0, 0.12, -14.0)
			if not on_grass:
				_spawn_pawprint()
	else:
		_step_accum = 0.25
	_was_swimming = swimming
	_was_on_floor = is_on_floor()

func _update_anim(swimming: bool, moving: bool) -> void:
	if swimming:
		_play_anim("Walk", 0.3, 0.7)
	elif not is_on_floor():
		if velocity.y > 1.0:
			_play_anim("Jump_Start", 0.1)
		else:
			_play_anim("Jump_Loop", 0.2)
	elif moving:
		if Input.is_action_pressed("run"):
			_play_anim("Run")
		else:
			_play_anim("Walk")
	elif _idle_time > 7.0:
		_play_anim("Idle_Eating", 0.6)  # grooming/nibbling when left alone
	else:
		_play_anim("Idle", 0.4)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event.is_action_pressed("interact"):
		var target := _closest_interactable()
		if target:
			target.interact(self)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_click_interact()
	for kind: String in VOCALS:
		if event.is_action_pressed(kind):
			if GameState.knows_vocal(kind):
				if kind == "meow":
					_meow_sfx.play()
					_whisker_sense()
				vocalized.emit(kind)
				GameState.vocal_used.emit(kind)
			else:
				vocal_unknown.emit(kind)

func is_swimming() -> bool:
	return _water_zones > 0 and global_position.y < _water_surface - 0.25

func enter_water(surface_y: float) -> void:
	_water_zones += 1
	_water_surface = surface_y

func exit_water() -> void:
	_water_zones = maxi(_water_zones - 1, 0)

func register_interactable(i: Interactable) -> void:
	if not _nearby.has(i):
		_nearby.append(i)

func unregister_interactable(i: Interactable) -> void:
	_nearby.erase(i)

func get_prompt_text() -> String:
	var target := _closest_interactable()
	return "[E]  " + target.prompt if target else ""

# --- charm: squash & stretch, pawprints, splash rings ---

func _stretch_jump() -> void:
	var t := create_tween()
	t.tween_property(body_visual, "scale", Vector3(0.94, 1.14, 0.94), 0.1)
	t.tween_property(body_visual, "scale", Vector3.ONE, 0.18)

func _squash_land() -> void:
	var t := create_tween()
	t.tween_property(body_visual, "scale", Vector3(1.12, 0.85, 1.12), 0.08)
	t.tween_property(body_visual, "scale", Vector3.ONE, 0.2)

func _spawn_pawprint() -> void:
	var paw := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.09, 0.13)
	paw.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.74, 0.64, 0.46)
	m.roughness = 1.0
	paw.material_override = m
	_step_side *= -1.0
	get_tree().current_scene.add_child(paw)
	var side: Vector3 = body_visual.global_transform.basis.x * 0.09 * _step_side
	paw.global_position = global_position + side + Vector3(0, 0.02, 0)
	paw.rotation.y = body_visual.global_rotation.y
	var t := paw.create_tween()
	t.tween_interval(6.0)
	t.tween_property(paw, "transparency", 1.0, 3.0)
	t.tween_callback(paw.queue_free)

func _spawn_splash_ring() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.97, 1.0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	get_tree().current_scene.add_child(ring)
	ring.global_position = Vector3(global_position.x, _water_surface + 0.02, global_position.z)
	ring.scale = Vector3(0.5, 0.3, 0.5)
	var t := ring.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector3(2.2, 0.3, 2.2), 1.0)
	t.tween_property(ring, "transparency", 1.0, 1.0)
	t.chain().tween_callback(ring.queue_free)

# --- Whisker Sense: a meow ripples outward and the world answers ---

func _whisker_sense() -> void:
	Sfx.play("whisker_shimmer", 1.0, 0.05, -12.0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.65, 0.9, 1.0, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position + Vector3(0, 0.15, 0)
	ring.scale = Vector3(0.4, 0.25, 0.4)
	var t := ring.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector3(11.0, 0.25, 11.0), 0.9) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "transparency", 1.0, 0.9)
	t.chain().tween_callback(ring.queue_free)
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D and global_position.distance_to(node.global_position) <= 12.0:
			_spawn_glint(node.global_position)

func _spawn_glint(pos: Vector3) -> void:
	var g := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	g.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.5, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.material_override = m
	get_tree().current_scene.add_child(g)
	g.global_position = pos + Vector3(0, 0.5, 0)
	var t := g.create_tween().set_parallel(true)
	t.tween_property(g, "position:y", g.position.y + 0.5, 1.1)
	t.tween_property(g, "transparency", 1.0, 1.1)
	t.chain().tween_callback(g.queue_free)

func _click_interact() -> void:
	# Ray from the camera through the screen centre; falls back to the nearest
	# interactable so a click always behaves at least as well as pressing E.
	var cam: Camera3D = rig.get_node("SpringArm/Camera")
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 9.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit["collider"] is Interactable:
		if global_position.distance_to(hit["collider"].global_position) <= 4.0:
			hit["collider"].interact(self)
			return
	var target := _closest_interactable()
	if target:
		target.interact(self)

func _closest_interactable() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for i in _nearby:
		if not is_instance_valid(i):
			continue
		var d: float = global_position.distance_to(i.global_position)
		if d < best_d:
			best_d = d
			best = i
	return best
