extends Node

const PORT = 4044

enum NetworkType {NONE = -1, CLIENT, SERVER}

var target_enet_server_ip : String
var target_enet_server_port : int
var target_enet_error : Error
var is_hosting_enet : bool = false
var is_using_steam : bool = true

## Steam Lobby, for checking lobby related thing on the last checked lobby
var steam_lobby_id : int = 0
var steam_lobby_creation_error : Error
## Game Lobby, Current connected lobby
var current_lobby_id : int

var client_or_server : NetworkType = NetworkType.NONE
var udp_server: PacketPeerUDP = PacketPeerUDP.new()
var udp_client: PacketPeerUDP = PacketPeerUDP.new()
var server_responses : Dictionary[String, Dictionary] = {}
var server_icons : Dictionary[String, Texture] = {}
var max_timeout : float = 3.0
var server_info: Dictionary = {
	"status" : "AVAILABLE",
	"server_name": "Serveur de Brawltest",
	"server_motd": "Salut Quentin !",
	"max_players": 8,
	"cur_players": 0,
	"server_gamemode": 0,
	"server_gamestate": 0,
	"server_scene" : "res://scene.tscn",
}
var cur_server_icon : Texture = preload("res://GDDiscord/icon.svg")

var current_duser : DUser = await get_duser_by_steam(Steam.getSteamID())

## Returns [000.000.000.000:00000] type of IP from a hostname
func get_ip_from_hostname(hostname : String) -> String:
	var queue_id = IP.resolve_hostname_queue_item(hostname)
	while IP.get_resolve_item_status(queue_id) == IP.ResolverStatus.RESOLVER_STATUS_WAITING:
		await get_tree().process_frame
	return IP.get_resolve_item_address(queue_id)


func _ready() -> void:
	print("[LOCAL IP] ", NetParser.find_local_ip())
	#var initsteam = Steam.steamInit(true,480)
	if Steam.isSteamRunning():
		print_debug("[NetworkUtilities] Steam is running")
		# Connect the important Steam signals once
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.lobby_joined.connect(_on_lobby_joined)
		Steam.lobby_invite.connect(_on_lobby_invited)
	else:
		var failure_reason = Steam.get_steam_init_result()
		print("Steam is not available : reasons follows") # New line
		for reason in failure_reason:
			print("  ", reason, " : ", failure_reason[reason])
		print_debug("... and that's why it's stuck (gameID is %s" % Steam.getAppID())

	if (OS.has_feature("dedicated_server")) or ("--server" in OS.get_cmdline_args()):
		udp_server.set_broadcast_enabled(true)
		client_or_server = NetworkType.SERVER
		print_verbose("[D] Starting server")
		print("[D] Command line arguments : ", OS.get_cmdline_args())
		print("[D] Is dedicated server : ", OS.has_feature("dedicated_server"))
		if "--dedicated_port" in OS.get_cmdline_args():
			var port_str = OS.get_cmdline_user_args().get(OS.get_cmdline_user_args().find("--dedicated_port") + 1)
			if port_str.is_valid_int() and int(port_str) > 2000 and int(port_str) < 65535:
				var port = int(port_str)
				print("[D] Using user-defined port ", str(port))
				host_server()
				return
			else:
				print("[D] User-defined port is not valid. Using default port ", str(PORT))
		host_server(false)
	else:
		udp_client.set_broadcast_enabled(true)
		client_or_server = NetworkType.CLIENT

## Ask a server if it exists and is still available
func ask_availability(server_ip: String, server_port: int) -> Error:
	var timer := Timer.new()
	add_child(timer)
	timer.one_shot = true
	
	udp_client.set_dest_address(server_ip, server_port)
	print("[C] Sent info request to server.")
	udp_client.put_var("request_info")
	
	timer.start(max_timeout)
	while udp_client.get_available_packet_count() == 0 and !timer.is_stopped():
		await get_tree().process_frame

	if udp_client.get_available_packet_count() > 0:
		var packet : Dictionary = udp_client.get_var()
		if packet.get("status") == "AVAILABLE":
			print("[C] Server Info Received : ",packet)
			server_responses[server_ip] = packet
			return OK
		else:
			print("[C] Invalid server response. :", packet.get("status","<null>"))
			return ERR_INVALID_DATA
	else:
		print("[C] No response from server.")

	print("[C] Client disconnected.")
	udp_client.close()
	timer.queue_free()
	return ERR_UNAVAILABLE

func ask_server_icon(server_ip: String, server_port: int) -> Texture:
	var timer := Timer.new()
	add_child(timer)
	timer.one_shot = true
	
	udp_client.set_dest_address(server_ip, server_port)
	print("[C] Sent info request to server.")
	udp_client.put_var("request_icon")
	
	timer.start(max_timeout)
	while udp_client.get_available_packet_count() == 0 and !timer.is_stopped():
		await get_tree().process_frame

	if udp_client.get_available_packet_count() > 0:
		var packet = udp_client.get_var()
		if packet is Texture:
			return packet
		else:
			print("[C] Invalid server response. :", packet.get("status","<null>"))
			return preload("res://GDDiscord/icon.svg")
	else:
		print("[C] No response from server.")

	print("[C] Client disconnected.")
	udp_client.close()
	timer.queue_free()
	return preload("res://GDDiscord/icon.svg")


## Host a MOTD Server that listen other client that ask for [availability : String], and returns a Dictionary with the server's information 
func host_server(use_steam : bool = true) -> void:
	var result := udp_server.bind(target_enet_server_port)
	if result == OK:
		print("[D] Server listening on UDP port %d" % target_enet_server_port)
	else:
		print("[D] Failed to bind UDP socket : ",error_string(result))
		return
	
	if use_steam and Steam.isSteamRunning():
		print_debug("Creating Steam Lobby")
		Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, server_info.get("max_players", 8))

	while udp_server.is_bound():
		while udp_server.get_available_packet_count() > 0:
			var variable : Variant = udp_server.get_var(false)
			var success := host_process(variable)
			if !success:
				print_debug("[D] Received unknown message from %s:%s : %s" % [udp_server.get_packet_ip(), udp_server.get_packet_port(), type_string(variable)])
		await get_tree().process_frame


func host_process(packet : Variant) -> bool:
	if packet is String:
		if (packet as String) == "request_info":
			udp_server.set_dest_address(udp_server.get_packet_ip(), udp_server.get_packet_port())
			udp_server.put_var(server_info)
		elif (packet as String) == "request_icon":
			udp_server.set_dest_address(udp_server.get_packet_ip(), udp_server.get_packet_port())
			udp_server.put_var(cur_server_icon)
		else:
			return false
	return true

#region Steam

## When a join request comes through Steam overlay
func _on_lobby_join_requested(lobby_id: int, friend_id: int) -> void:
	print("(Steam)Join requested! Lobby:", lobby_id, "from friend:", friend_id)
	Steam.joinLobby(lobby_id)

# --- Lobby created by YOU (host) ---
func _on_lobby_created(connect_r: int, lobby_id: int) -> void:
	if connect_r == 1:
		steam_lobby_id = lobby_id
		steam_lobby_creation_error = (connect_r as Error)
		Steam.setLobbyData(lobby_id, "host", str(Steam.getSteamID()));
		Steam.setLobbyData(lobby_id, "ip", target_enet_server_ip);
		Steam.setLobbyData(lobby_id, "port", str(target_enet_server_port));
		Steam.setLobbyData(lobby_id, "name", server_info.server_motd + " - " + server_info.server_name);
		Steam.setLobbyData(lobby_id, "version", ProjectSettings.get_setting("application/config/version","1.0.0"));
		Steam.setLobbyData(lobby_id, "map", server_info.server_map);
	else:
		push_error("Failed to create lobby, EResult = %d" % connect)

##
func refresh_lobby_stat():
	if steam_lobby_id == 0:
		return
	Steam.setLobbyData(steam_lobby_id, "host", str(Steam.getSteamID()));
	Steam.setLobbyData(steam_lobby_id, "ip", target_enet_server_ip);
	Steam.setLobbyData(steam_lobby_id, "port", str(target_enet_server_port));
	Steam.setLobbyData(steam_lobby_id, "name", server_info.get("server_name", "Unknown") + " - " + server_info.get("server_motd", "No Description"));
	Steam.setLobbyData(steam_lobby_id, "version", ProjectSettings.get_setting("application/config/version"));
	Steam.setLobbyData(steam_lobby_id, "gamemode", server_info.get("server_gamemode", 0));



## --- When YOU receive an invite to a lobby (client side) ---
func _on_lobby_invited(inviter_id: int, lobby_id: int, game_id: int) -> void:
	print("(Steam) Invite received! Lobby:", lobby_id, "from friend:", Steam.getFriendPersonaName(inviter_id))


## --- When YOU enter someone’s lobby (client side) ---
func _on_lobby_joined(lobby_id: int, success: int, _steam_id: int) -> void:
	if success != 1:
		push_error("Failed to enter lobby %d" % lobby_id)
		return

	current_lobby_id = lobby_id
	print("Entered lobby:", lobby_id)

	var project_id : String = ProjectSettings.get_setting("application/game_id")
	var lobby_project_id := Steam.getLobbyData(lobby_id, "project_id")

	# Safety: ensure we only join lobbies from this project
	if lobby_project_id != project_id:
		push_error("This lobby is for another project (%s), leaving." % lobby_project_id)
		Steam.leaveLobby(lobby_id)
		return

	# Connect to ENet host
	var ip   := Steam.getLobbyData(lobby_id, "ip")
	var port := int(Steam.getLobbyData(lobby_id, "port"))
	var map := Steam.getLobbyData(lobby_id, "map")

	target_enet_server_ip = ip
	target_enet_server_port = port
	is_hosting_enet = false

	if FileAccess.file_exists(map):
		get_tree().change_scene_to_file(map)
	else:
		push_error("Server scene not found : %s" % server_info["server_scene"])
		Steam.leaveLobby(lobby_id)

#region Steam Avatar

var loaded_avatars : Dictionary

func steam_user_avatar_loaded(id, icon_size, buffer : PackedByteArray):
	var avatarImage = Image.create_from_data(icon_size, icon_size, false, Image.FORMAT_RGBA8, buffer)
	var texture = ImageTexture.create_from_image(avatarImage)
	loaded_avatars.merge({id : texture},true)

func get_steam_avatar(id) -> Texture:
	if not loaded_avatars.has(id):
		Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM,id)
		await Steam.avatar_loaded
	return loaded_avatars.get(id,preload("res://GDDiscord/icon.svg"))

func host_process_image(data : PackedByteArray):
	var image = Image.create_from_data(128, 128, false, Image.FORMAT_RGBA8, data)
	var texture = ImageTexture.create_from_image(image)
	$TextureRect.texture = texture

func get_duser_by_steam(steam_id : int) -> DUser:
	var duser = DUser.new()
	duser._is_steam_user = true
	duser._steam_id = steam_id
	duser.name = (Steam.getPersonaName() if Steam.getSteamID() == steam_id else Steam.getFriendPersonaName(steam_id) )
	duser.avatar = await get_steam_avatar(steam_id)
	return duser
