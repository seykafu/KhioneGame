extends Node3D

func _ready() -> void:
	$Sun.rotation_degrees = Vector3(-50, 30, 0)
	Sfx.play_ambient("ocean_loop", -16.0)
	_schedule_gull()

func _schedule_gull() -> void:
	get_tree().create_timer(randf_range(14.0, 34.0)).timeout.connect(_on_gull_timer)

func _on_gull_timer() -> void:
	Sfx.play("gull", 1.0, 0.15, -10.0)
	_schedule_gull()
