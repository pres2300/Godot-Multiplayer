extends Node2D

@onready var collider: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

@export var required_activators: int = 2
@export var locked_open: bool = false

var current_activators = 0

func activate(state):
	if not multiplayer.is_server():
		return

	if locked_open:
		return

	if state:
		current_activators += 1
	else:
		current_activators -= 1

	if current_activators >= required_activators:
		locked_open = true
		set_bridge_properties()

func set_bridge_properties():
	collider.set_deferred("disabled", !locked_open)
	sprite.visible = locked_open

func _on_multiplayer_synchronizer_delta_synchronized() -> void:
	set_bridge_properties()
