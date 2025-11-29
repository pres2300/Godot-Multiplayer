extends Node2D

class_name KeyDoor

signal all_players_finished

@export var is_open = false

@onready var door_open: Sprite2D = $DoorOpen
@onready var door_closed: Sprite2D = $DoorClosed
@onready var collider: CollisionShape2D = $Area2D/CollisionShape2D
@onready var exit_area: Area2D = $ExitArea

var finished_players: int = 0

func set_door_properties():
	door_open.visible = is_open
	door_closed.visible = !is_open
	collider.set_deferred("disabled", is_open)
	exit_area.monitoring = is_open

func _on_multiplayer_synchronizer_delta_synchronized() -> void:
	set_door_properties()

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not multiplayer.is_server():
		return

	is_open = true
	set_door_properties()
	area.get_parent().queue_free()

func _on_exit_area_body_entered(body: Node2D) -> void:
	if body.is_multiplayer_authority():
		body.disable_multiplayer_sync()

	if multiplayer.is_server():
		body.call_deferred("queue_free")

	finished_players += 1

	if finished_players > multiplayer.get_peers().size():
		all_players_finished.emit()
