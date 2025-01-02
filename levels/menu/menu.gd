extends Node

@onready var ui = $UI
@onready var level_container = $Level
@onready var not_connected_hbox = $UI/NotConnectedHBox
@onready var host_hbox = $UI/HostHBox
@onready var ip_line_edit = $UI/NotConnectedHBox/IPLineEdit
@onready var status_label = $UI/StatusLabel

@export var level_scene: PackedScene

func _ready() -> void:
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_host_button_pressed() -> void:
	not_connected_hbox.hide()
	host_hbox.show()
	Lobby.create_game()
	status_label.text = "Hosting!"

func _on_join_button_pressed() -> void:
	not_connected_hbox.hide()
	Lobby.join_game(ip_line_edit.text)
	status_label.text = "Connecting..."

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

func change_level(scene):
	for c in level_container.get_children():
		level_container.remove_child(c)
		c.queue_free()

	level_container.add_child(scene.instantiate())
