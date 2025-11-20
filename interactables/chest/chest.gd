extends Node2D

@export var is_locked: bool = true

@onready var chest_locked: Sprite2D = $ChestLocked
@onready var chest_unlocked: Sprite2D = $ChestUnlocked

func set_chest_properties():
	chest_locked.visible = is_locked
	chest_unlocked.visible = !is_locked

func _on_test_interact(state):
	if state:
		_on_interactable_interacted()

func _on_interactable_interacted():
	if not multiplayer.is_server():
		return

	if is_locked:
		is_locked = false
		set_chest_properties()


func _on_multiplayer_synchronizer_delta_synchronized() -> void:
	set_chest_properties()
