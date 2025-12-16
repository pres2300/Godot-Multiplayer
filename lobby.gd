# Global Autoload
extends Node

const MAX_CONNECTIONS = 2
const PACKET_READ_LIMIT: int = 32

# Authentication vars
var connected_clients: Dictionary[int, Dictionary] = {}
var pending_members: Dictionary[int, Dictionary] = {}

# keys in connected_clients and pending_members dictionary
const CLIENT_TICKET: String = "client_ticket"
const MY_TICKET: String = "my_ticket"
const STEAM_ID: String = "steam_id"

# Steam lobby vars
var lobby_id: int = 0
var lobby_members_max: int = 10
var lobby_vote_kick: bool = false
var steam_username: String = ""
var host_id: int = 0

signal lobbies_found(these_lobbies)
signal lobby_joined(joined)
signal lobby_created
signal player_joined(player_name)
signal player_left(player_name)
signal host_left

func _ready():
	# Authentication callbacks
	Steam.get_auth_session_ticket_response.connect(_on_get_auth_session_ticket_response)
	Steam.validate_auth_ticket_response.connect(_on_validate_auth_ticket_response)

	# Steam Lobby callbacks
	Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)

	# Unimplemented callbacks
	#Steam.lobby_message.connect(_on_lobby_message)
	#Steam.persona_state_change.connect(_on_persona_change)
	#Steam.lobby_data_update.connect(_on_lobby_data_update)
	#Steam.lobby_invite.connect(_on_lobby_invite)

	# Godot Multiplayer signal callbacks
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_authenticating.connect(_authenticating)
	multiplayer.peer_authentication_failed.connect(_auth_failed)
	multiplayer.set_auth_callback(_on_authenticate)

	# Check for command line arguments
	check_command_line()

# Callback from getting the auth ticket from Steam
func _on_get_auth_session_ticket_response(this_auth_ticket: int, result: int) -> void:
	print("Auth session result: %s" % result)
	print("Auth session ticket handle: %s" % this_auth_ticket)

func _authenticating(peer_id: int) -> void:
	if multiplayer.is_server():
		# The server won't initiate the authentication, so this shouldn't happen
		return

	var auth_ticket: Dictionary = Steam.getAuthSessionTicket()
	print("Peer authenticating: ", peer_id)

	# Add this client's ticket to pending members dictionary
	# while we wait for authentication to finish
	pending_members[peer_id] = {
		MY_TICKET: auth_ticket,
		STEAM_ID: multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer_id)
	}

	# Send the ticket to the other client
	multiplayer.send_auth(peer_id, auth_ticket.buffer)

func _auth_failed(peer_id: int) -> void:
	print("Auth session failed with peer: ", peer_id)
	lobby_joined.emit(false)

func _on_authenticate(peer_id: int, data: PackedByteArray):
	# Get the peer_steam_id from the peer_id as Multiplayer Peer uses different IDs
	var peer_steam_id: int = multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer_id)

	if multiplayer.is_server():
		if not pending_members.has(peer_id):
			print("Authenticating as server: ", peer_id, data)
			pending_members[peer_id] = {
				CLIENT_TICKET: data,
				STEAM_ID: peer_steam_id
			}
	else:
		print("Authenticating as client", peer_id, data)

		if pending_members.has(peer_id):
			print("I have already sent my auth to this client")
			pending_members[peer_id][CLIENT_TICKET] = data
		else:
			print("New client")
			pending_members[peer_id] = {
				CLIENT_TICKET: data,
				STEAM_ID: peer_steam_id
			}

	# Validate the client's ticket
	var error: int = validate_auth_session(data, peer_id)

	if error != 0:
		print("Starting authentication session with peer %d has failed with error: %d" % [peer_id, error])
		multiplayer.disconnect_peer(peer_id)

		if pending_members[peer_id].has(MY_TICKET):
			Steam.cancelAuthTicket(pending_members[peer_id][MY_TICKET].id)
		Steam.endAuthSession(peer_steam_id)
		pending_members.erase(peer_id)

# Callback from attempting to validate the auth ticket
func _on_validate_auth_ticket_response(auth_id: int, response: int, owner_id: int) -> void:
	var peer_id = 0

	print("Ticket Owner: %s" % auth_id)

	if multiplayer.multiplayer_peer != null:
		peer_id = multiplayer.multiplayer_peer.get_peer_id_for_steam_id(auth_id)

	# Make the response more verbose, highly unnecessary but good for this example
	var verbose_response: String
	match response:
		0: verbose_response = "Steam has verified the user is online, the ticket is valid and ticket has not been reused."
		1: verbose_response = "The user in question is not connected to Steam."
		2: verbose_response = "The user doesn't have a license for this App ID or the ticket has expired."
		3: verbose_response = "The user is VAC banned for this game."
		4: verbose_response = "The user account has logged in elsewhere and the session containing the game instance has been disconnected."
		5: verbose_response = "VAC has been unable to perform anti-cheat checks on this user."
		6: verbose_response = "The ticket has been canceled by the issuer."
		7: verbose_response = "This ticket has already been used, it is not valid."
		8: verbose_response = "This ticket is not from a user instance currently connected to steam."
		9: verbose_response = "The user is banned for this game. The ban came via the Web API and not VAC."
	print("Auth response: %s" % verbose_response)
	print("Game owner ID: %s" % owner_id)

	match response:
		0:
			if multiplayer.is_server():
				if pending_members.has(peer_id):
					var auth_ticket = Steam.getAuthSessionTicket()
					pending_members[peer_id][MY_TICKET] = auth_ticket
					multiplayer.send_auth(peer_id, auth_ticket.buffer)
					multiplayer.complete_auth.call_deferred(peer_id)
			else:
				if pending_members.has(peer_id):
					if not pending_members[peer_id].has(MY_TICKET):
						# Haven't authed back to this client yet
						var auth_ticket = Steam.getAuthSessionTicket()
						pending_members[peer_id][MY_TICKET] = auth_ticket
						multiplayer.send_auth(peer_id, auth_ticket.buffer)
						multiplayer.complete_auth.call_deferred(peer_id)
					else:
						# Client has already been authed
						multiplayer.complete_auth(peer_id)

			connected_clients[peer_id] = pending_members[peer_id]
			pending_members.erase(peer_id)
		6:
			# If the session was canceled, disconnect from the peer.
			# It's possible the peer is already disconnected, so check
			# that multiplayer_peer is still valid.
			if multiplayer.multiplayer_peer != null:
				multiplayer.disconnect_peer(peer_id)
		_:
			# Authentication failed
			multiplayer.disconnect_peer(peer_id)

			if pending_members[peer_id].has(MY_TICKET):
				Steam.cancelAuthTicket(pending_members[peer_id][MY_TICKET].id)
			Steam.endAuthSession(auth_id)
			pending_members.erase(peer_id)

func _on_lobby_created(has_connected: int, this_lobby_id: int) -> void:
	if has_connected == 1:
		# Set the lobby ID
		lobby_id = this_lobby_id
		print("Created a lobby: %s" % lobby_id)

		# Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)

		# Set some lobby data
		Steam.setLobbyData(lobby_id, "name", "GameDevTV Lobby")
		Steam.setLobbyData(lobby_id, "mode", "GodotSteam test")

		# Allow P2P connections to fallback to being relayed through Steam if needed
		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be relay backup: %s" % set_relay)

		# Setup multiplayer peer
		var peer = SteamMultiplayerPeer.new()
		var error = peer.host_with_lobby(lobby_id)

		if error:
			print("Unable to create host: ", error)
			return

		multiplayer.multiplayer_peer = peer
		lobby_created.emit()

		get_lobby_members()

func _on_lobby_match_list(these_lobbies: Array) -> void:
	# Send the lobbies to the menu
	lobbies_found.emit(these_lobbies)

func _on_peer_connected(peer_id: int) -> void:
	var peer_steam_id = multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer_id)
	var peer_name: String = Steam.getFriendPersonaName(peer_steam_id)

	print("Peer connected [%d]: %s" % [peer_id, peer_name])
	player_joined.emit(peer_name)

	if host_id == peer_steam_id:
		# We have successfully joined to the host
		lobby_joined.emit(true)

	get_lobby_members()

func _on_peer_disconnected(peer_id: int) -> void:
	var peer_steam_id = multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer_id)
	var peer_name: String = Steam.getFriendPersonaName(peer_steam_id)

	print("Peer disconnected [%d]: %s" % [peer_id, peer_name])

	Steam.cancelAuthTicket(connected_clients[peer_id][MY_TICKET].id)
	Steam.endAuthSession(peer_steam_id)
	multiplayer.disconnect_peer(peer_id)
	connected_clients.erase(peer_id)

	get_lobby_members()

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# If joining was successful
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		# Set this lobby ID as your lobby ID
		lobby_id = this_lobby_id

		host_id = Steam.getLobbyOwner(this_lobby_id)

		if host_id != Steam.getSteamID():
			print("Joining ID:", host_id)
			# Make the initial handshake
			var peer = SteamMultiplayerPeer.new()
			var error = peer.connect_to_lobby(this_lobby_id)

			if error:
				print("Failed to create peer: ", error)
				return

			multiplayer.multiplayer_peer = peer

	# Else it failed for some reason
	else:
		# Get the failure reason
		var fail_reason: String

		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."

		print("Failed to join this chat room: %s" % fail_reason)
		lobby_joined.emit(false)

func _on_lobby_join_requested(this_lobby_id: int, friend_id: int) -> void:
	# Get the lobby owner's name
	var owner_name: String = Steam.getFriendPersonaName(friend_id)

	print("Joining %s's lobby..." % owner_name)

	# Attempt to join the lobby
	join_game(this_lobby_id)

func _on_lobby_chat_update(_this_lobby_id: int, change_id: int, _making_change_id: int, chat_state: int) -> void:
	# Get the user who has made the lobby change
	var changer_name: String = Steam.getFriendPersonaName(change_id)

	match chat_state:
		# If a player has joined the lobby
		Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
			print("%s has joined the lobby." % changer_name)

		# Else if a player has left the lobby
		Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
			print("%s has left the lobby." % changer_name)

			if change_id == host_id:
				# If the host leaves, we will also leave
				host_left.emit()
				leave_lobby()
			else:
				player_left.emit(changer_name)

		# Else if a player has been kicked
		Steam.CHAT_MEMBER_STATE_CHANGE_KICKED:
			print("%s has been kicked from the lobby." % changer_name)

		# Else if a player has been banned
		Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
			print("%s has been banned from the lobby." % changer_name)

		# Else there was some unknown change
		_:
			print("%s did... something." % changer_name)

func get_lobby_list() -> void:
	# Set distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)

	# NOTE: remove this if you ever get your own Steam game ID.
	# This just makes it easier to filter out SpaceWar lobbies.
	Steam.addRequestLobbyListStringFilter("name", "GameDevTV Lobby", Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)

	print("Requesting a lobby list")
	Steam.requestLobbyList()

func validate_auth_session(ticket_data: PackedByteArray, peer_id: int) -> int:
	var auth_response: int = Steam.beginAuthSession(
		ticket_data,
		ticket_data.size(),
		multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer_id))

	print("Starting auth session with player: ",
		Steam.getFriendPersonaName(multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer_id)))

	# Get a verbose response; unnecessary but useful in this example
	var verbose_response: String
	match auth_response:
		0: verbose_response = "Successfully started auth session."
		1: verbose_response = "The ticket is invalid."
		2: verbose_response = "A ticket has already been submitted for this Steam ID."
		3: verbose_response = "Ticket is from an incompatible interface version."
		4: verbose_response = "Ticket is not for this game."
		5: verbose_response = "Ticket has expired."
	print("Auth session start response: %s" % verbose_response)

	if auth_response == 0:
		print("Auth session creation successful")

	# Wait for _on_validate_auth_ticket_response
	return auth_response

func check_command_line() -> void:
	var these_arguments: Array = OS.get_cmdline_args()

	# There are arguments to process
	if these_arguments.size() > 0:

		# A Steam connection argument exists
		if these_arguments[0] == "+connect_lobby":

			# Lobby invite exists so try to connect to it
			if int(these_arguments[1]) > 0:

				# At this point, you'll probably want to change scenes
				# Something like a loading into lobby screen
				print("Command line lobby ID: %s" % these_arguments[1])
				#TODO: join_lobby(int(these_arguments[1]))

func create_game():
	connected_clients.clear()
	pending_members.clear()

	# Make sure a lobby is not already set
	if lobby_id == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_members_max)

func join_game(join_lobby_id):
	print("Joining lobby: ", join_lobby_id)

	# Clear the connected clients lists to start anew
	connected_clients.clear()
	pending_members.clear()

	# Make the lobby join request to Steam
	Steam.joinLobby(join_lobby_id)

func leave_lobby() -> void:
	# If in a lobby, leave it
	if lobby_id != 0:
		for peer_id in connected_clients.keys():
			Steam.cancelAuthTicket(connected_clients[peer_id][MY_TICKET].id)
			Steam.endAuthSession(connected_clients[peer_id][STEAM_ID])
			connected_clients.erase(peer_id)

		multiplayer.multiplayer_peer = null

		# Send leave request to Steam
		Steam.leaveLobby(lobby_id)

		# Wipe the Steam lobby ID then display the default lobby ID and player list title
		lobby_id = 0

func get_lobby_members() -> void:
	# Get the number of members from this lobby from Steam
	var num_of_members: int = Steam.getNumLobbyMembers(lobby_id)

	# Get the data of these players from Steam
	for this_member in range(0, num_of_members):
		# Get the member's Steam ID
		var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, this_member)

		# Get the member's Steam name
		var member_steam_name: String = Steam.getFriendPersonaName(member_steam_id)
		print("lobby member: ", member_steam_name)

		# Add them to the list
		player_joined.emit(member_steam_name)
