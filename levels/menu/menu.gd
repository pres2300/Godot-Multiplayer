extends Node

@onready var ui = $UI
@onready var level_container = $Level
@onready var not_connected_hbox = $UI/NotConnectedHBox
@onready var host_hbox = $UI/HostHBox
@onready var status_label = $UI/StatusLabel
@onready var server_list = $UI/MarginContainer/ScrollContainer/ServerList

@export var level_scene: PackedScene

func _ready() -> void:
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	Lobby.lobbies_found.connect(create_lobbies_list)

func _on_host_button_pressed() -> void:
	not_connected_hbox.hide()
	host_hbox.show()
	Lobby.create_game()
	status_label.text = "Hosting!"

func _on_join_button_pressed() -> void:
	Lobby.get_lobby_list()

	# Old code for reference
	#not_connected_hbox.hide()
	#Lobby.join_game(ip_line_edit.text)
	#status_label.text = "Connecting..."

func _on_start_button_pressed() -> void:
	hide_menu.rpc()
	change_level.call_deferred(level_scene)

func _on_connection_failed() -> void:
	status_label.text = "Failed to connect"
	not_connected_hbox.show()

func _on_connected_to_server() -> void:
	status_label.text = "Connected!"

@rpc("call_local", "authority", "reliable")
func hide_menu():
	ui.hide()

func create_lobbies_list(these_lobbies):
	for this_lobby in these_lobbies:
		# Pull lobby data from Steam, these are specific to our example
		var lobby_name: String = Steam.getLobbyData(this_lobby, "name")
		var lobby_mode: String = Steam.getLobbyData(this_lobby, "mode")

		# Get the current number of members
		var lobby_num_members: int = Steam.getNumLobbyMembers(this_lobby)

		# Create a button for the lobby
		var lobby_button: Button = Button.new()
		lobby_button.set_text("Lobby %s: %s [%s] - %s Player(s)" % [this_lobby, lobby_name, lobby_mode, lobby_num_members])
		lobby_button.set_size(Vector2(800, 50))
		lobby_button.set_name("lobby_%s" % this_lobby)
		lobby_button.connect("pressed", Callable(self, "join_lobby").bind(this_lobby))

		# Add the new lobby to the list
		server_list.add_child(lobby_button)

func join_lobby(lobby):
	print("Joining lobby: ", lobby)

func change_level(scene):
	for c in level_container.get_children():
		level_container.remove_child(c)
		c.level_complete.disconnect(_on_level_complete)
		c.queue_free()

	var new_level = scene.instantiate()
	level_container.add_child(new_level)
	new_level.level_complete.connect(_on_level_complete)

func _on_level_complete():
	# this is where you would change to the next level if available, etc.
	call_deferred("change_level", level_scene)
