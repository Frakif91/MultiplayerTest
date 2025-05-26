class_name LanResearcher extends Node

var server_info : World3D_ENet.ServerInfo
var client_ask : PacketPeerUDP = PacketPeerUDP.new()
var server_listen : UDPServer = UDPServer.new()

func _listen_server():
	server_listen.listen(4046)
	print("Listening as LAN server on port 4046")
	while true:
		var data = server_listen.get_packet()
		if data:
			server_info = World3D_ENet.ServerInfo.new()
			server_info.from_bytes(data)
			emit_signal("listen_server_received",server_info)
			print("Received server info: ",server_info._to_string())

func _ask_client():
	client_ask.set_destination(server_info.server_ip,server_info.server_port)
	client_ask.put_packet(server_info.to_bytes())
	print("Asked server: ",server_info._to_string())
	while true:
		var data = client_ask.get_packet()
		if data:
			emit_signal("ask_client_received",data)
