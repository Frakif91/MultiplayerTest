class_name ServerCreation extends MarginContainer

signal server_created(server_info : Dictionary)


@onready var name_edit : LineEdit = %NameEdit
@onready var desc_edit : LineEdit = %DescEdit
@onready var pass_edit : LineEdit = %PassEdit
@onready var port_edit : LineEdit = %PortEdit
@onready var max_players_edit : LineEdit = %MaxPlayerEdit
@onready var map_edit : OptionButton = %MapEdit
@onready var port_udp_edit : LineEdit = %PortUDPEdit
@onready var steam_disc_edit : CheckButton = %SteamDiscEdit
@onready var public_ip_edit : LineEdit = %PublicIPEdit
@onready var public_port_edit : LineEdit = %PublicPortEdit
@onready var icon_edit: TextureRect = %IconEdit

func _ready() -> void:
	%ServerCreateButton.disabled = true

func _process(delta):
	%ServerCreateButton.disabled = not check_server_info_valid()

func _on_server_create_button_pressed() -> void:
	pass # Replace with function body.

func _on_server_local_pressed() -> void:
	pass # Replace with function body.

func check_server_info_valid() -> bool:
	if name_edit.text.length() < 3:
		set_error_message("Nom de Serveur trop court")
		return false
	#desc_edit
	
	if not port_edit.text.is_valid_int() or int(port_edit.text) < 1000 or int(port_edit.text) >= 65535:
		set_error_message("Port Enet : entre 1000 et 65535")
		return false
	
	if not port_udp_edit.text.is_valid_int() or int(port_udp_edit.text) < 1000 or int(port_udp_edit.text) >= 65535:
		set_error_message("Port UDP : entre 1000 et 65535")
		return false

	#pass_edit
	
	if not max_players_edit.text.is_valid_int() or int(max_players_edit.text) < 1 or int(max_players_edit.text) >= 256:
		set_error_message("Max Players : entre 1 et 255")
		return false
	if map_edit.selected < 0:
		set_error_message("Map non séléctionnée")
	
	if steam_disc_edit.pressed:
		if NetParser.detect_address_type(public_ip_edit.text) == NetParser.AddressType.UNKNOWN:
			set_error_message("Adresse IP publique incorrecte")
			return false
		
		# public_port_edit

	if icon_edit.texture == null:
		set_error_message("Icone non séléctionnée")
		return false

	set_error_message("")
	return true

func _on_local_server_button_pressed() -> void:
	var server_info : Dictionary = {
		"status" : "AVAILABLE",
		"server_name" : "Local Server",
		"server_motd" : "This is a local server",
		"server_password" : "",
		"server_port" : 4044,
		"server_enet_port" : 4046,
		"server_has_password" : false,
		"max_players" : 8,
		"server_map" : "res://GDDiscord/Godot/Scenes/World3D.tscn",
		"server_scene" : "res://GDDiscord/Godot/Scenes/World3D.tscn",
		"server_use_steam" : false,
	}

	server_created.emit(server_info)


func _on_create_server_button_pressed() -> void:

	if not check_server_info_valid():
		return

	var server_name = name_edit.text
	var server_has_password = false
	var server_description = desc_edit.text
	var server_password = pass_edit.text
	var server_port = port_edit.text
	var server_max_players = max_players_edit.text
	var server_map = map_edit.get_item_metadata(map_edit.selected)
	var server_map_name = map_edit.get_item_text(map_edit.selected)
	var server_port_udp = port_udp_edit.text
	var server_steam_availability = steam_disc_edit.pressed
	var server_public_ip = public_ip_edit.text
	var server_public_port = public_port_edit.text

	var server_info : Dictionary = {
		"status" : "AVAILABLE",
		"server_name" : server_name,
		"server_motd" : server_description,
		"server_password" : server_password,
		"server_port" : server_port_udp,
		"server_enet_port" : server_port,
		"server_has_password" : server_has_password,
		"max_players" : server_max_players,
		"server_map" : server_map_name,
		"server_scene" : server_map,
		"server_use_steam" : server_steam_availability,
		"server_public_ip" : server_public_ip if server_steam_availability else "127.0.0.1",
		"server_public_port" : server_public_port if server_steam_availability else server_port
	}

	server_created.emit(server_info)


func set_error_message(message : String) -> void:
	%ServerErrorLbl.text = message
	if message.is_empty():
		%ServerErrorLbl.hide()
	else:
		%ServerErrorLbl.show()
