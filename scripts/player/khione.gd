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

var _water_zones := 0
var _water_surface := 0.0
var _nearby: Array = []
var _spawn := Vector3.ZERO

func _ready() -> void:
	_spawn = global_position

func _physics_process(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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
		if Input.is_action_just_pressed("jump"):
			velocity.y = SWIM_KICK
	else:
		velocity.y -= GRAVITY * delta
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY

	move_and_slide()

	if dir.length_squared() > 0.01:
		var target_yaw := atan2(dir.x, dir.z)
		body_visual.rotation.y = lerp_angle(body_visual.rotation.y, target_yaw, TURN_SPEED * delta)

	if global_position.y < -25.0:
		global_position = _spawn
		velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
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
