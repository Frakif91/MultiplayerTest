class_name  World3D_ENet extends Node3D

var random_player_name = ["John Pork","John Cena","Dave","Dwayne Johnson","Kevin","Stevie Ray","Kurt Cobain","Will Smith", "James", "Matthew", "Noah", "The Rock"]
var enet : ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var max_player_count : int = 8

## Returns the first occurence of the player's id in the player list
func find_player_by_id(player_id : int) -> Player:
	if player_id in players:
		return players[player_id]
	return null

## Returns the first occurence of the player's name in the player list
func find_player_by_name(player_name : String) -> Player:
	if player_name in players:
		for player in players.values():
			if player.player_name == player_name:
				return player
	return null

@export var players : Dictionary[int, Player]

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

#region Virtuals Functions
func _ready():
	multiplayer.server_disconnected.connect(func(): get_tree().change_scene_to_packed(gddiscord_scene))
	server_name_text.text = cur_player.player_name
	server_name_text.text_submitted.connect(func(text):cur_player.player_name = text)
	#multiplayer.peer_connected.connect(player_connected)
	#multiplayer.peer_disconnected.connect(player_disconnected)
	multiplayer_spawner.spawn_function = summon_player

func summon_player(id : int) -> Node:
	var player = player_scene_instance.instantiate()
	if player.has_method("set_player_id"):
		player.set_player_id(id)
	player.name = str(id)
	return player

#endregion Godot Virtuals Functions

enum DisconnectionType {
	FAILED_TO_CONNECT,
	DISCONNECTED,
	KICKED,
	BANNED,
	TIMED_OUT
}

## Register a player to this Side (Both Side) | Does not create player, only list them for easy access later
func register_player(player_id : int):
	var duser = DUser.new()
	players.set(player_id,duser)
	var idx = player_list.add_item(duser.name)
	player_list.set_item_metadata(idx,player_id)
	ask_player_user_info(player_id)

func finish_registering(player_id : int, duser : DUser):
	players.set(player_id,duser)
	player_list.set_item_metadata(player_list.find_item_by_metadata(player_id),player_id)

## Unregister a player from this Side (Both Side) on the "data" meaning of things | look for [register_player]
func unregister_player(player_id : int):
	players.erase(find_player_by_id(player_id))
	player_list.remove_item(player_list.find_item_by_metadata(player_id))

func refresh_player_list():
	player_list.clear()
	for player_id in players:
		var idx = player_list.add_item(players[player_id].player_name)
		player_list.set_item_metadata(idx,player_id)



func terminate(conx : DisconnectionType = DisconnectionType.DISCONNECTED):
	if multiplayer.has_multiplayer_peer():
		terminate_networking()
	get_tree().change_scene_to_packed(gddiscord_scene)

#region Networking
func join_server(ip, port):
	if multiplayer.has_multiplayer_peer():
		terminate(DisconnectionType.DISCONNECTED)

	var status = enet.create_client(ip, port)
	print("[WORLD ENET] Joining Server Status : " + error_string(status))

	multiplayer.connection_failed.connect(player_fail_to_connect)
	multiplayer.server_disconnected.connect(player_leave_server)
	multiplayer.peer_connected.connect(player_connected)
	multiplayer.peer_disconnected.connect(player_disconnected)

	if status == OK:
		multiplayer.multiplayer_peer = enet
		get_tree().set_multiplayer(multiplayer)
		summon_player(multiplayer.multiplayer_peer.get_unique_id())
	
func host_server(port):
	if multiplayer.has_multiplayer_peer():
		terminate(DisconnectionType.DISCONNECTED)

	var status = enet.create_server(port,max_player_count)
	print("[WORLD ENET] Hosting Server Status : " + error_string(status))

	if status == OK:
		multiplayer.multiplayer_peer = enet
		get_tree().set_multiplayer(multiplayer)

		multiplayer.peer_connected.connect(player_connected)
		multiplayer.peer_disconnected.connect(player_disconnected)
		
		multiplayer_spawner.spawn(multiplayer.multiplayer_peer.get_unique_id())
		register_player(multiplayer.multiplayer_peer.get_unique_id())
	

func terminate_networking():
	players.clear()
	if multiplayer.has_multiplayer_peer():
		print("Disconnecting from Server...")
		if multiplayer.server_disconnected.is_connected(player_leave_server):
			multiplayer.server_disconnected.disconnect(player_leave_server)
		if multiplayer.connection_failed.is_connected(player_fail_to_connect):
			multiplayer.connection_failed.disconnect(player_fail_to_connect)
		
		if multiplayer.peer_connected.is_connected(player_connected):
			multiplayer.peer_connected.disconnect(player_connected)
		if multiplayer.peer_disconnected.is_connected(player_disconnected):
			multiplayer.peer_disconnected.disconnect(player_disconnected)

		multiplayer.multiplayer_peer.disconnect_peer(1)
		multiplayer.multiplayer_peer.close()


#endregion Networking

#region Client Functions

## Emitted when someone connect to the server, even called when YOU JOIN and it emit with the ID of the Server
func player_connected(id : int = 0): # Client Side
	join_audioplayer.play()
	if id != 0:
		register_player(id)
	print_rich("[WORLD ENET] [color=green]Player : ",id," (",find_player_by_id(id).player_name,") connected [/color]")
	#emit_signal("player_connected",id)
	multiplayer_spawner.spawn(id)

## Both Side (Only active Server Side) | Emitted when someone(else) disconnect from the server
func player_disconnected(id : int = 0):	
	leave_audioplayer.play()
	unregister_player(id)
	
	#emit_signal("player_disconnected",id)
	var child = spawnpoint.get_node_or_null(str(id))
	if child:
		if particle_disconnect:
			var p : GPUParticles3D = particle_disconnect.instantiate()
			p.global_position = child.global_position
			p.finished.connect(p.queue_free)
			spawnpoint.add_child(p)
			p.emitting = true
		child.queue_free()
		
	else:
		push_warning("Player: " + str(id) + " not found")


## Client Side | Emitted if YOU left a server (The leaving User is the sender)
func player_leave_server(): # Client Side Only
	terminate_connection_sfx.play()
	terminate(DisconnectionType.DISCONNECTED)


## Client Side | Emitted if YOU fail to connect to a server
func player_fail_to_connect():
	terminate(DisconnectionType.FAILED_TO_CONNECT)
#endregion



#region Addons

signal received_player_user_info(id : int, userinfo : DServer)
var received_player_user_infos : Dictionary[int, DUser] = {}

func await_player_user_info(id) -> DUser:
	ask_player_user_info(id)
	await received_player_user_info
	return received_player_user_infos[id]

func ask_player_user_info(id):
	rpc_id(id,&"get_player_name")

## Respond to ask_player_name
@rpc("any_peer","call_remote","reliable")
func get_player_user_info():
	rpc_id(multiplayer.get_remote_sender_id(),&"receive_player_user_info",multiplayer.multiplayer_peer.get_unique_id(),cur_player)

@rpc("any_peer","call_remote","reliable")
func receive_player_user_info(id : int, userinfo : DUser):
	received_player_user_infos[id] = userinfo
	received_player_user_info.emit(id,userinfo)



#endregion Addons
