# GameDevTV's Godot Multiplayer course + GodotSteam + Steam Multiplayer Peer

Current versions:
	* Godot v4.5.1
	* GodotSteam v4.17

This repo implements GameDevTV's Godot multiplayer project using Steam to connect online. I roughly followed the [documentation from GodotSteam](https://godotsteam.com/getting_started/introduction/).

In particular (other than basic installation of the extension), you will want to focus on the [Initializing Steam](https://godotsteam.com/tutorials/initializing/) tutorial as well as the [Lobbies](https://godotsteam.com/tutorials/lobbies/) tutorial. [Authentication](https://godotsteam.com/tutorials/authentication/) is done as well, but Multiplayer Peer helps with a lot of that.

Along with GodotSteam, you will need to install the Steam Multiplayer Peer extension. This will allow you to continue using the multiplayer peer functionality built in to Godot and relay it to Steam. You really only need to use Steam Multiplayer Peer to create the host and create the client depending on if you are hosting or joining a game. This will replace the areas of P2P connections mentioned in the GodotSteam docs until they add tutorials on using Multiplayer Peer.

Examples of using Steam Multiplayer Peer to host and join games are shown below.

## Hosting a game

```
var peer = SteamMultiplayerPeer.new()
var error = peer.create_host(0)

if error:
	print("Unable to create host: ", error)
		return error

multiplayer.multiplayer_peer = peer
```

## Joining a game

```
var peer = SteamMultiplayerPeer.new()
var error = peer.create_client(host_id, 0)

if error:
	print("Failed to create peer: ", error)
		return

multiplayer.multiplayer_peer = peer
```

## Other Projects

[I have another example project](https://codeberg.org/Oilyraincloud/GodotSteamMultiplayerPeerAuthenticationExample) that implements a basic lobby system using GodotSteam with lobbies, Multiplayer Peer, and Authentication you are free to checkout and use as a basic starting point.
