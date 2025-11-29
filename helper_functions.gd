extends Node

class_name HelperFunctions

# `static` allows this function to be called anywhere without explicit declaration of the class
static func ClientInterpolate(global_position: Vector2, target_position: Vector2, delta: float, lerp_speed: float=25.0):
	# NOTE: There is a chance that the object spawns before the target_position is set.
	# Initializing the target_position to INF enables a check to prevent lerping
	# to an invalid position.
	if target_position == Vector2.INF:
		return global_position

	if (global_position-target_position).length_squared() > 100*100:
		return target_position
	else:
		return lerp(
			target_position,
			global_position,
			pow(0.5, delta*lerp_speed)
		)
