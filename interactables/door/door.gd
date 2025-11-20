extends Node2D

@export var is_open = false

@onready var door_open: Sprite2D = $DoorOpen
@onready var door_closed: Sprite2D = $DoorClosed
@onready var collider: CollisionShape2D = $DoorClosed/StaticBody2D/CollisionShape2D

func activate(state):
	if not multiplayer.is_server():
		return

	is_open = state
	set_door_properties()

func set_door_properties():
	door_open.visible = is_open
	door_closed.visible = !is_open
	collider.set_deferred("disabled", is_open)

func _on_multiplayer_synchronizer_delta_synchronized() -> void:
	set_door_properties()
