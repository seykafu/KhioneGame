extends Node3D
## Dev preview: close-up of Khione's face to check the Persian snout squash.
## Run: godot --path . res://tools/preview_cat.tscn

func _ready() -> void:
	var cat: Node3D = load("res://scenes/player/khione.tscn").instantiate()
	add_child(cat)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	cs.shape = box
	cs.position.y = -0.5
	floor_body.add_child(cs)
	add_child(floor_body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	add_child(sun)
	await get_tree().process_frame
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.65, 0.7, 1.5)
	cam.look_at(Vector3(0, 0.45, 0.25))
	cam.current = true
