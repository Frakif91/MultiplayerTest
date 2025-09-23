extends Node

const PORT = 4044

enum NetworkType {NONE = -1, CLIENT, SERVER}

var target_enet_server_ip : String
var target_enet_server_port : int
var target_enet_error : Error
var is_hosting_enet : bool = false
var is_using_steam : bool = true
var steam_lobby_id : int = 0
var steam_lobby_creation_error : Error
var current_lobby_id : int


var client_or_server : NetworkType = NetworkType.NONE
var udp_server: PacketPeerUDP = PacketPeerUDP.new()
var udp_client: PacketPeerUDP = PacketPeerUDP.new()
var server_responses : Dictionary = {}
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

## Returns [000.000.000.000:00000] type of IP from a hostname
func get_ip_from_hostname(hostname : String) -> String:
	var queue_id = IP.resolve_hostname_queue_item(hostname)
	while IP.get_resolve_item_status(queue_id) == IP.ResolverStatus.RESOLVER_STATUS_WAITING:
		await get_tree().process_frame
	return IP.get_resolve_item_address(queue_id)


func _ready() -> void:
	print("[LOCAL IP] ", find_ip())
	var initsteam = Steam.steamInit(true,480)
	if Steam.isSteamRunning():
		if Steam.getAppID() == 0:
			push_error("Cannot Initialize Steam") if not initsteam else print_debug("Steam's Good")
		# Connect the important Steam signals once
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.lobby_joined.connect(_on_lobby_entered)

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
		Steam.lobby_created.connect(func(connect, lobby_id):
			steam_lobby_id = lobby_id
			steam_lobby_creation_error = connect
			Steam.setLobbyData(lobby_id, "host", str(Steam.getSteamID()));
			Steam.setLobbyData(lobby_id, "ip", target_enet_server_ip);
			Steam.setLobbyData(lobby_id, "port", str(target_enet_server_port));
			Steam.setLobbyData(lobby_id, "name", server_info.get("server_name", "Unknown") + " - " + server_info.get("server_motd", "No Description"));
			Steam.setLobbyData(lobby_id, "version", ProjectSettings.get_setting("application/config/version"));
			Steam.setLobbyData(lobby_id, "gamemode", server_info.get("server_gamemode", 0));
		)

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
	return true

#region Steam

# When a join request comes through Steam overlay
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
		Steam.setLobbyData(lobby_id, "name", server_info.get("server_name", "Unknown") + " - " + server_info.get("server_motd", "No Description"));
		Steam.setLobbyData(lobby_id, "version", ProjectSettings.get_setting("application/config/version"));
		Steam.setLobbyData(lobby_id, "gamemode", server_info.get("server_gamemode", 0));
	else:
		push_error("Failed to create lobby, EResult = %d" % connect)


# --- When YOU enter someone’s lobby (client side) ---
func _on_lobby_entered(lobby_id: int, success: int, _steam_id: int) -> void:
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

	target_enet_server_ip = ip
	target_enet_server_port = port
	is_hosting_enet = false

	if FileAccess.file_exists(server_info["server_scene"]):
		get_tree().change_scene_to_file(server_info["server_scene"])
	else:
		push_error("Server scene not found : %s" % server_info["server_scene"])
		Steam.leaveLobby(lobby_id)

#region Steam Avatar

var loaded_avatars : Dictionary

func steam_user_avatar_loaded(id, icon_size, buffer : PackedByteArray):
	var avatarImage = Image.create_from_data(icon_size, icon_size, false, Image.FORMAT_RGBA8, buffer)
	var texture = ImageTexture.create_from_image(avatarImage)
	loaded_avatars.merge({id : texture},true)

func get_steam_avatar(id) -> ImageTexture:
	if not loaded_avatars.has(id):
		Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM,id)
		await Steam.avatar_loaded
	return loaded_avatars.get(id,preload("res://GDDiscord/icon.svg"))

# returns the best local IPv4 address on this device that matches private LAN ranges
func find_ip() -> String:
	var addrs = IP.get_local_addresses()   # returns PoolStringArray / Array of strings
	var candidates := {
		"192": [], # 192.168.x.x
		"10":  [], # 10.x.x.x
		"172": []  # 172.16.x.x - 172.31.x.x
	}

	for a in addrs:
		# ignore IPv6 addresses
		if ":" in a:
			continue
		# ignore loopback & link-local (APIPA)
		if a.begins_with("127.") or a.begins_with("169.254."):
			continue
		var parts = a.split(".")
		if parts.size() != 4:
			continue
		var p0 = int(parts[0])
		var p1 = int(parts[1])
		# 192.168.x.x
		if p0 == 192 and p1 == 168:
			candidates["192"].append(a)
			continue
		# 10.x.x.x
		if p0 == 10:
			candidates["10"].append(a)
			continue
		# 172.16.x.x - 172.31.x.x  (private 172.16/12 block)
		if p0 == 172 and p1 >= 16 and p1 <= 31:
			candidates["172"].append(a)
			continue
		# otherwise ignore other public addresses

	# Choose priority: prefer 192.168, then 10, then 172 (adjust order if you want)
	var priority = ["192", "10", "172"]
	for key in priority:
		if candidates.has(key) and candidates[key].size() > 0:
			return candidates[key][0]  # return first found in that range

	# fallback: return any non-loopback IPv4 if present
	for a in addrs:
		if ":" in a:
			continue
		if not a.begins_with("127.") and not a.begins_with("169.254."):
			return a

	return "127.0.0.1"  # ultimate fallback


func host_process_image(data : PackedByteArray):
	var image = Image.create_from_data(128, 128, false, Image.FORMAT_RGBA8, data)
	var texture = ImageTexture.create_from_image(image)
	$TextureRect.texture = texture