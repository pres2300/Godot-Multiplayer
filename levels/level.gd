extends Node2D

@onready var players_container = $Players/PlayersContainer

@export var player_scene: PackedScene
@export var spawn_points: Array[Marker2D]

var next_spawn_point_idx = 0

func _ready():
	if not multiplayer.is_server():
		return

	for id in multiplayer.get_peers():
		add_player(id)

	multiplayer.peer_disconnected.connect(delete_player)

	add_player(1)

func _exit_tree():
	if multiplayer.multiplayer_peer == null:
		return

	if not multiplayer.is_server():
		return

	multiplayer.peer_disconnected.disconnect(delete_player)

func add_player(id):
	var player_instance = player_scene.instantiate()
	player_instance.position = get_spawn_point()
	player_instance.name = str(id)
	players_container.add_child(player_instance)

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
