extends Node

const PORT = 4044

var client_or_server : String
var udp_server: PacketPeerUDP = PacketPeerUDP.new()
var udp_client: PacketPeerUDP = PacketPeerUDP.new()
var server_responses : Dictionary = {}
var server_info: Dictionary = {
	"status" : "AVAILABLE",
	"server_name": "Dedicated Server",
	"server_motd": "Welcome to my server !",
	"max_players": 8,
	"cur_players": 0,
	"server_gamemode": 0,
	"server_gamestate": 0,
	"server_map": "None"
}

func _ready() -> void:
	if (OS.has_feature("dedicated_server")) or ("--server" in OS.get_cmdline_args()):
		udp_server.set_broadcast_enabled(true)
		client_or_server = "Server"
		print_verbose("[D] Starting server")
		print("[D] Command line arguments : ", OS.get_cmdline_args())
		print("[D] Is dedicated server : ", OS.has_feature("dedicated_server"))
		if "--dedicated_port" in OS.get_cmdline_args():
			var port_str = OS.get_cmdline_user_args().get(OS.get_cmdline_user_args().find("--dedicated_port") + 1)
			if port_str.is_valid_int() and int(port_str) > 2000 and int(port_str) < 65535:
				var port = int(port_str)
				print("[D] Using user-defined port ", str(port))
				host_server(port)
				return
			else:
				print("[D] User-defined port is not valid. Using default port ", str(PORT))
		host_server(PORT)
	else:
		udp_client.set_broadcast_enabled(true)
		client_or_server = "Client"

## Ask a server if it exists and is still available
func ask_availability(server_ip: String, server_port: int) -> Error:
	var timer := Timer.new()
	add_child(timer)
	timer.one_shot = true
	
	udp_client.set_dest_address(server_ip, server_port)
	print("[C] Sent info request to server.")
	udp_client.put_var("request_info")
	
	timer.start(3.0)
	while udp_client.get_available_packet_count() == 0 and !timer.is_stopped():
		await get_tree().process_frame

	if udp_client.get_available_packet_count() > 0:
		var packet : Dictionary = udp_client.get_var()
		if packet.get("status") == "AVAILABLE":
			print("[C] Server Info Received : ",packet)
			server_responses[server_ip] = packet
			return OK
		else:
			print("[C] Invalid server response.")
			return ERR_INVALID_DATA
	else:
		print("[C] No response from server.")

	print("[C] Client disconnected.")
	udp_client.close()
	return ERR_UNAVAILABLE

## Host a MOTD Server that listen other client that ask for [availability : String], and returns a Dictionary with the server's information 
func host_server(server_port: int) -> void:
	var result := udp_server.bind(server_port)
	if result == OK:
		print("[D] Server listening on UDP port %d" % server_port)
	else:
		print("[D] Failed to bind UDP socket : ",error_string(result))

	while udp_server.is_bound():
		while udp_server.get_available_packet_count() > 0:
			var message := (udp_server.get_var() as String)
			print_debug("[D] Received packet from %s:%s" % [udp_server.get_packet_ip(), udp_server.get_packet_port()])
			var sender_ip := udp_server.get_packet_ip()
			var sender_port := udp_server.get_packet_port()
			if message == "request_info":
				#await get_tree().create_timer(0.1).timeout
				udp_server.set_dest_address(sender_ip, sender_port)
				print("[D] Sent info to %s:%s" % [sender_ip, sender_port])
				udp_server.put_var(server_info)
			else:
				print_debug("[D] Received unknown message from %s:%s : %s" % [sender_ip, sender_port, message])
