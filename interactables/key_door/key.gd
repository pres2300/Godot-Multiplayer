extends Node2D

@export var follow_offset: Vector2 = Vector2(-50, -60)
@export var lerp_speed: float = 5.0

var following_body

func _process(delta):
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		if following_body != null:
			global_position = lerp(
				following_body.global_position+follow_offset,
				global_position,
				pow(0.5, delta*lerp_speed)
			)

func _on_area_2d_body_entered(body: Node2D) -> void:
	following_body = body
