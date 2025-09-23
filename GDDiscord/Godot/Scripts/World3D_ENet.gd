class_name  World3D_ENet extends Node3D

signal received_player_name(id, player_name)

var random_player_name = ["John Pork","John Cena","Dave","Dwayne Johnson","Kevin","Stevie Ray","Kurt Cobain","Will Smith", "James", "Matthew", "Noah", "The Rock"]
var enet : ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var max_player_count : int = 8

## Returns the first occurence of the player's id in the player list
func find_player_by_id(player_id : int) -> Player:
	for player in players:
		if player.player_id == player_id:
			return player
	return null

## Returns the first occurence of the player's name in the player list
func find_player_by_name(player_name : String) -> Player:
	for player in players:
		if player.player_name == player_name:
			return player
	return null

func _on_item_list_item_activated(index:int) -> void:
	pass # Replace with function body.

@export var players : Array[Player]

@export var print_instance_name : bool = false

@export var player_scene_instance : PackedScene
@export var particle_disconnect : PackedScene
@export var ip_text : LineEdit
@export var port_text : LineEdit
@export var join_button : Button
@export var host_button : Button
@export var disconnect_button : Button
@export var server_name_text : LineEdit
@export var server_info_text : Label
@export var player_list : ItemList
@export var multiplayer_spawner : MultiplayerSpawner
@export var spawnpoint : Node3D
@export var join_audioplayer : AudioStreamPlayer
@export var leave_audioplayer : AudioStreamPlayer
@export var terminate_connection_sfx : AudioStreamPlayer
@export var gddiscord_scene : PackedScene = preload("res://GDDiscord/Godot/Scenes/DiscordScene.tscn")

var dialog_confirm : ConfirmationDialog
var is_dedicated_server : bool = OS.has_feature("dedicated_server")

@export var cur_player : Player

const connection_status_names = {
	MultiplayerPeer.CONNECTION_CONNECTED : "Connected",
	MultiplayerPeer.CONNECTION_CONNECTING : "Connecting...",
	MultiplayerPeer.CONNECTION_DISCONNECTED : "Disconnected",
}

class ServerInfo:
	enum Gamemode {FREEPLAY, COOP, VS}
	var players : Array[Player]
	var cur_players : int = 0
	var max_players : int = 8
	var server_name : String = "Cool Server"
	var server_motd : String = "Welcome to my server !"
	var server_ip : String = "127.0.0.1"
	var server_port : int = 0
	var server_gamemode : int = (0 as Gamemode)
	var server_gamestate : int
	var server_map : String

	func _init(_server_name : String = "Cool Server", _server_ip : String = "127.0.0.1", _server_port : int = 4046, _server_motd : String = "Hello There !", _max_players : int = 8):
		server_name = _server_name
		server_ip = _server_ip
		server_port = _server_port
		server_gamemode = Gamemode.FREEPLAY
		server_gamestate = 0
		server_map = "None"
		server_motd = _server_motd
		max_players = _max_players

	func _to_string() -> String:
		return "[ Server: " + server_name + "\nIP: " + server_ip + "\nPort: " + str(server_port) + "Players : " + str(cur_players) + "/" + str(max_players) + " ]"

#region Virtuals Functions
func _ready():
	multiplayer.server_disconnected.connect(func(): get_tree().change_scene_to_packed(gddiscord_scene))
	server_name_text.text = cur_player.player_name
	server_name_text.text_submitted.connect(func(text):cur_player.player_name = text)
	#multiplayer.peer_connected.connect(player_connected)
	#multiplayer.peer_disconnected.connect(player_disconnected)
	multiplayer_spawner.spawn_function = summon_player

func _process(_delta : float) -> void:
	if multiplayer.has_multiplayer_peer():
		#server_name_text.text = "Server Status: " + connection_status_names[multiplayer.multiplayer_peer.get_connection_status()]
		server_info_text.text = "\n".join(PackedStringArray(
			[
				"Player ID: " + str(cur_player.player_id) + (" (Host)" if multiplayer.is_server() else ""),
				"Server slots: " + str(spawnpoint.get_child_count()) + "/" + str(max_player_count),
				#"Players: " + str(multiplayer.get_peers().size())
			]
		))

	disconnect_button.disabled = (not multiplayer.has_multiplayer_peer())
	join_button.disabled = not(multiplayer.has_multiplayer_peer()) and not multiplayer.is_server()
	host_button.disabled = not(multiplayer.has_multiplayer_peer()) and multiplayer.is_server()

func summon_player(id : int) -> Node:
	var player = player_scene_instance.instantiate()
	return player

#endregion Godot Virtuals Functions


func add_player(player : Player):
	players.append(player)
	player_list.add_item(player.player_name)

func remove_player(player : Player):
	players.erase(player)
	player_list.remove_item(player_list.find_item_by_text(player.player_name))


#region Networking
func join_server(ip, port):
	if multiplayer.has_multiplayer_peer():
		terminate_networking() # If joins

	var status = enet.create_client(ip, port)
	print("[WORLD ENET] Joining Server Status : " + error_string(status))
	if status == OK:
		multiplayer.multiplayer_peer = enet
		get_tree().set_multiplayer(multiplayer)
		multiplayer.server_disconnected.connect(player_fail_to_connect)
		multiplayer.server_disconnected.connect(player_leave_server)
		summon_player(multiplayer.multiplayer_peer.get_unique_id())
	
func host_server(port):
	if  (multiplayer.multiplayer_peer != null) or (multiplayer.has_multiplayer_peer()):
		multiplayer.multiplayer_peer.close()

	var status = enet.create_server(port,max_player_count)
	print("[WORLD ENET] Hosting Server Status : " + error_string(status))

	players.clear()
	player_list.clear()

	if status == OK:
		multiplayer.multiplayer_peer = enet
		get_tree().set_multiplayer(multiplayer)

		multiplayer.peer_connected.connect(player_connected)
		multiplayer.peer_disconnected.connect(player_disconnected)
		
		multiplayer_spawner.spawn(multiplayer.multiplayer_peer.get_unique_id())
		add_player(cur_player)
	

func terminate_networking():
	players.clear()
	if multiplayer.has_multiplayer_peer():
		print("Disconnecting from Server...")
		#player_leave_server()
		if multiplayer.peer_connected.is_connected(player_connected):
			multiplayer.peer_connected.disconnect(player_connected)
		if multiplayer.peer_disconnected.is_connected(player_disconnected):
			multiplayer.peer_disconnected.disconnect(player_disconnected)

		multiplayer.multiplayer_peer.disconnect_peer(1)
		multiplayer.multiplayer_peer.close()

enum DisconnectionType {
	FAILED_TO_CONNECT,
	DISCONNECTED,
	KICKED,
	BANNED,
	TIMED_OUT
}

func player_got_disconnected(id : int, reason : int):
	pass


#endregion Networking

enum REQUEST_TYPE { SET, GET}

#region Client Functions

## Emitted when someone connect to the server, even called when YOU join and it emit with the ID of the Server
func player_connected(id : int = 0):
	join_audioplayer.play()
	await await_player_name(id)
	print_rich("[WORLD ENET] [color=green]Player : ",id," (",find_player_by_id(id).player_name,") connected [/color]")
	#emit_signal("player_connected",id)
	multiplayer_spawner.spawn(id)
	add_player(Player.new(find_player_by_id(id).player_name,id))

func player_disconnected(id : int):
	leave_audioplayer.play()
	unregister_player(id)
	
	
	#emit_signal("player_disconnected",id)
	var child = spawnpoint.get_node_or_null(str(id))
	if child:
		var p : GPUParticles3D = particle_disconnect.instantiate()
		p.global_position = child.global_position
		p.finished.connect(p.queue_free)
		spawnpoint.add_child(p)
		p.emitting = true
		child.queue_free()
		
	else:
		push_warning("Player: " + str(id) + " not found")

func player_leave_server(): # Self
	#for child in spawnpoint.get_children():
		#child.queue_free()
	unregister_player(multiplayer.multiplayer_peer.get_unique_id())
	terminate_connection_sfx.play()

func player_fail_to_connect():
	terminate_connection_sfx.play()
	unregister_player(multiplayer.multiplayer_peer.get_unique_id())
#endregion



#region Addons

## Kicks this player, called by the host only
@rpc("authority","call_local","reliable")
func kick_peer(id : int):
	if multiplayer.is_server() and id != multiplayer.multiplayer_peer.get_unique_id():
		multiplayer.multiplayer_peer.disconnect_peer(id)

func _set_players_name(player_id : int, player_name : String):
	var player := find_player_by_id(player_id)
	if player:
		player.player_name = player_name

func ask_player_name(id):
	rpc_id(id,&"get_player_name")

func await_player_name(id):
	ask_player_name(id)
	await received_player_name

@rpc("any_peer","call_remote","reliable")
func get_player_name():
	rpc_id(multiplayer.get_remote_sender_id(),&"receive_player_name",multiplayer.multiplayer_peer.get_unique_id(),cur_player.player_name)

@rpc("any_peer","call_remote","reliable")
func receive_player_name(id : int, playername : String):
	players[id].player_name = playername
	received_player_name.emit(id,playername)

func register_player(player_id : int, player_name : String):
	players.append(Player.new(player_name, player_id))
	var idx = player_list.add_item(player_name)
	player_list.set_item_metadata(idx,player_id)

func unregister_player(player_id : int):
	players.erase(find_player_by_id(player_id))
	player_list.remove_item(player_list.find_item_by_metadata(player_id))

#endregion Addons

