# This script does all the necessary initialization for steamworks
extends Node

# NOTE: 480 is Valve's test ID; change this when Valve provides a real app ID
const STEAM_APP_ID = 480

func initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx(STEAM_APP_ID, true)
	print("Did Steam initialize?: %s " % initialize_response)

	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, shutting down: %s" % initialize_response)
		# Show some kind of prompt so the game doesn't suddently stop working
		print("Game exited due to Steam failing to initialize")

		get_tree().quit()

func _ready() -> void:
	initialize_steam()
