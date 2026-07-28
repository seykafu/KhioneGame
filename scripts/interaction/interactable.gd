class_name Interactable
extends Area3D
## Base class for anything Khione can interact with via [E].
## Registers itself with the player while the player stands in range.

@export var prompt: String = "Interact"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.register_interactable(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.unregister_interactable(self)

func interact(_player: Node) -> void:
	pass
