extends Node2D

signal level_complete

@onready var players_container = $Players/PlayersContainer
@onready var key_door: KeyDoor = $Interactables/KeyDoor

@export var player_scenes: Array[PackedScene]
@export var spawn_points: Array[Marker2D]

var next_spawn_point_idx = 0
var next_character_index = 0

func _ready():
	if not multiplayer.is_server():
		return

	for id in multiplayer.get_peers():
		add_player(id)

	multiplayer.peer_disconnected.connect(delete_player)

	add_player(1)

	key_door.all_players_finished.connect(_on_all_players_finished)

func _exit_tree():
	if multiplayer.multiplayer_peer == null:
		return

	if not multiplayer.is_server():
		return

	multiplayer.peer_disconnected.disconnect(delete_player)

func add_player(id):
	var player_instance = player_scenes[next_character_index].instantiate()
	player_instance.position = get_spawn_point()
	player_instance.name = str(id)
	players_container.add_child(player_instance)

	next_character_index += 1
	if next_character_index >= player_scenes.size():
		next_character_index = 0

func delete_player(id):
	if not players_container.has_node(str(id)):
		return

	players_container.get_node(str(id)).queue_free()

func get_spawn_point():
	var spawn_point = spawn_points[next_spawn_point_idx].position
	next_spawn_point_idx += 1

	if next_spawn_point_idx >= len(spawn_points):
		next_spawn_point_idx = 0

	return spawn_point

func _on_all_players_finished():
	key_door.all_players_finished.disconnect(_on_all_players_finished)
	level_complete.emit()
