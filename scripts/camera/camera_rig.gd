extends Node3D
## Mouse-orbit camera rig. Yaw on this node, pitch on the SpringArm so the
## player body can rotate independently toward its movement direction.

@export var mouse_sensitivity := 0.003
@export var min_pitch := -1.2
@export var max_pitch := 0.5

@onready var arm: SpringArm3D = $SpringArm

var _pitch := -0.4

func _ready() -> void:
	arm.rotation.x = _pitch
	var parent := get_parent()
	if parent is PhysicsBody3D:
		arm.add_excluded_object(parent.get_rid())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, min_pitch, max_pitch)
		arm.rotation.x = _pitch
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
