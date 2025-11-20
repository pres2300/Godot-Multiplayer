extends Node2D

@export var is_down: bool = false

@onready var plate_up: Sprite2D = $PlateUp
@onready var plate_down: Sprite2D = $PlateDown

var bodies_on_plate: int = 0

signal toggle(state)

func _on_area_2d_body_entered(_body: Node2D) -> void:
	if not multiplayer.is_server():
		return

	bodies_on_plate += 1
	update_plate_state()

func _on_area_2d_body_exited(_body: Node2D) -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if not multiplayer.is_server():
		return

	bodies_on_plate -= 1
	update_plate_state()

func update_plate_state() -> void:
	is_down = bodies_on_plate > 0
	toggle.emit(is_down)
	set_plate_properties()

func set_plate_properties() -> void:
	plate_down.visible = is_down
	plate_up.visible = !is_down

func _on_multiplayer_synchronizer_delta_synchronized() -> void:
	set_plate_properties()
