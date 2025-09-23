class_name NetParser extends Node

var hostname := "play.brawltest.fr"

func hostname_to_ip_port(hostname: String, port: int) -> String:
	var ip := IP.resolve_hostname(hostname)
	if ip == "":
		push_error("Impossible de résoudre le hostname : %s" % hostname)
		return ""
	return "%s:%d" % [ip, port]

func resolve_srv_record(service: String, proto: String, domain: String, callback: Callable) -> void:
	var url = "https://dns.google/resolve?name=%s.%s.%s&type=SRV" % [service, proto, domain]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if response_code != 200:
			callback.call(false, "Erreur HTTP %d" % response_code)
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY or not data.has("Answer"):
			callback.call(false, "Pas de record SRV trouvé")
			return
		var srv = data["Answer"][0]["data"].split(" ")
		var port = int(srv[2])
		var target = srv[3].strip_edges(".")
		callback.call(true, {"target": target, "port": port})
	)
	http.request(url)

# (Async) Résoluion de l'adresse en IP (avec ou sans port en seconde partie)
static func parse_address(input: String, tree : SceneTree) -> Array[String]:
	var default_port = 4044
	var address = input
	var port = default_port

	# Vérifie s'il y a un port
	if ":" in input:
		var parts = input.split(":")
		address = parts[0]
		if parts.size() > 1 and (parts[1] as String).is_valid_int():
			port = int(parts[1])

	# Résolution de l'adresse en IP
	var resolved_ip_queue_id = IP.resolve_hostname_queue_item(address, IP.TYPE_IPV4)
	if resolved_ip_queue_id == IP.RESOLVER_INVALID_ID:
		return []

	var status = IP.get_resolve_item_status(resolved_ip_queue_id)
	while status == IP.RESOLVER_STATUS_WAITING:
		status = IP.get_resolve_item_status(resolved_ip_queue_id)
		await tree.process_frame

	if status != IP.RESOLVER_STATUS_DONE:
		printerr("Impossible de resoudre l'adresse : %s" % input, error_string(status))
		return []

	var resolved_ip = IP.get_resolve_item_address(resolved_ip_queue_id)
	
	print_debug("Resolved Host : " + resolved_ip + ":" + str(port))
	return [resolved_ip, port]

enum AddressType { 
	IP, 
	HOSTNAME, 
	IP_W_PORT, 
	HOSTNAME_W_PORT, 
	UNKNOWN 
}

enum AdressType {IP, HOSTNAME, IP_W_PORT, HOSTNAME_W_PORT, UNKNOWN}

static func _is_valid_hostname(host: String) -> bool:
	var regex := RegEx.new()
	# Regex basique pour un hostname/domaine
	# - labels séparés par des points
	# - chaque label = lettres, chiffres ou '-'
	# - pas de '-' en début/fin
	# - TLD = min. 2 lettres
	regex.compile(r"^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.(?!-)[A-Za-z0-9-]{1,63}(?<!-))*\.[A-Za-z]{2,}$")
	return regex.search(host) != null

static func detect_address_type(address: String) -> AddressType:
	var parts = address.split(":")
	
	if parts.size() == 2:
		var host = parts[0]
		var port = parts[1]
		
		if not port.is_valid_int():
			return AddressType.UNKNOWN
		var port_num = int(port)
		if port_num < 1 or port_num > 65535:
			return AddressType.UNKNOWN
		
		if host.is_valid_ip_address():
			return AddressType.IP_W_PORT
		elif _is_valid_hostname(host):
			return AddressType.HOSTNAME_W_PORT
		else:
			return AddressType.UNKNOWN
	
	elif parts.size() == 1:
		var host = parts[0]
		
		if host.is_valid_ip_address():
			return AddressType.IP
		elif _is_valid_hostname(host):
			return AddressType.HOSTNAME
		else:
			return AddressType.UNKNOWN
	
	return AddressType.UNKNOWN
