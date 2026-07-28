extends Interactable
## The bottle that washes ashore on Ahalo — the story's inciting incident.

func _init() -> void:
	prompt = "Read the message"

func interact(_player: Node) -> void:
	GameState.set_flag("letter_read")
	GameState.letter_opened.emit()
