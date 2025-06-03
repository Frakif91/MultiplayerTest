extends Node

const PORT = 4044

var udp_server: PacketPeerUDP = PacketPeerUDP.new()
var udp_client: PacketPeerUDP = PacketPeerUDP.new()
var server_info: Dictionary = {
	"server_name": "Dedicated Server",
	"server_motd": "Welcome to my server !",
	"max_players": 8,
	"cur_players": 0,
	"server_gamemode": 0,
	"server_gamestate": 0,
	"server_map": "None"
}

func _ready() -> void:
	if (OS.has_feature("dedicated_server")) or ("--server" in OS.get_cmdline_user_args()):
		print_verbose("[D] Starting server")
		print("[D] Command line arguments : ", OS.get_cmdline_user_args())
		print("[D] Is dedicated server : ", OS.has_feature("dedicated_server"))
		if "--port" in OS.get_cmdline_user_args():
			var port = int(OS.get_cmdline_user_args()[OS.get_cmdline_user_args().find("--port") + 1])
			print("[D] Using user-defined port ", str(port))
			host_server(port)
		else:
			host_server(PORT)

## Ask a server if it exists and is still available
func ask_availability(server_ip: String, server_port: int) -> Error:
	udp_client.set_dest_address(server_ip, server_port)
	udp_client.put_var("request_info")
	print("[C] Sent info request to server.")


	for i in range(30): # Try 30 times (30*0.1) = 3.0 seconds
		if udp_client.get_available_packet_count() == 0:
			await get_tree().create_timer(0.1).timeout # Wait 1 second for response

	if udp_client.get_available_packet_count() > 0:
		var packet := udp_client.get_packet()
		var response := packet.get_string_from_utf8()
		var info = JSON.parse_string(response)
		if info:
			print("[C] Server Info Received:")
			print(info)
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
		print("[D]Server listening on UDP port %d" % server_port)
	else:
		print("[D] Failed to bind UDP socket : ",error_string(result))

	while udp_server.get_available_packet_count() > 0:
		var sender_ip := udp_server.get_packet_ip()
		var sender_port := udp_server.get_packet_port()
		var message := (udp_server.get_var() as String)

		if message == "request_info":
			udp_server.put_var(server_info)
			print("Sent info to %s:%s" % [sender_ip, sender_port])
