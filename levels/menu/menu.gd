extends Node

@onready var ui = $CanvasLayer/UI
@onready var level_container = $Level
@onready var not_connected_hbox = $CanvasLayer/UI/NotConnectedHBox
@onready var host_hbox = $CanvasLayer/UI/HostHBox
@onready var status_label = $CanvasLayer/UI/StatusLabel
@onready var servers_container = $CanvasLayer/UI/ServersContainer
@onready var server_list = $CanvasLayer/UI/ServersContainer/ScrollContainer/ServerList
@onready var leave_ui = $CanvasLayer/LeaveUI

@export var level_scene: PackedScene

func _ready() -> void:
	Lobby.lobbies_found.connect(create_lobbies_list)
	Lobby.lobby_joined.connect(_on_lobby_joined)
	Lobby.host_left.connect(_on_host_left)

func _on_host_button_pressed() -> void:
	not_connected_hbox.hide()
	host_hbox.show()
	Lobby.create_game()
	status_label.text = "Hosting!"

func _on_join_button_pressed() -> void:
	Lobby.get_lobby_list()

func _on_lobby_joined(joined) -> void:
	if joined:
		# join successful
		status_label.text = "Connected!"
	else:
		# join failed
		# TODO: A confirmation for the user here would be good to let them know the join failed
		server_browser(true)

func _on_start_button_pressed() -> void:
	hide_menu.rpc()
	change_level.call_deferred(level_scene)

func _on_leave_button_pressed() -> void:
	leave_game()

func _on_host_left() -> void:
	leave_game()

func leave_game() -> void:
	Lobby.leave_lobby()

	for c in level_container.get_children():
		level_container.remove_child(c)
		c.level_complete.disconnect(_on_level_complete)
		c.queue_free()

	return_to_menu()

@rpc("call_local", "authority", "reliable")
func hide_menu():
	ui.hide()
	leave_ui.show()

func return_to_menu():
	ui.show()
	server_browser(true)
	leave_ui.hide()
	host_hbox.hide()

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

func join_lobby(lobby_id):
	server_browser(false)
	status_label.text = "Connecting..."

	print("Joining lobby: ", lobby_id)
	Lobby.join_game(lobby_id)

func change_level(scene):
	for c in level_container.get_children():
		level_container.remove_child(c)
		c.level_complete.disconnect(_on_level_complete)
		c.queue_free()

	var new_level = scene.instantiate()
	level_container.add_child(new_level)
	new_level.level_complete.connect(_on_level_complete)

func server_browser(show :bool) -> void:
	# Clear current list
	for c in server_list.get_children():
		c.queue_free()

	if show:
		not_connected_hbox.show()
		servers_container.show()
		status_label.text = ""
	else:
		not_connected_hbox.hide()
		servers_container.hide()

func _on_level_complete():
	# this is where you would change to the next level if available, etc.
	call_deferred("change_level", level_scene)
