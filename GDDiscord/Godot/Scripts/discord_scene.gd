class_name DiscordMenu extends Control

# TODO LIST
# V - Ajout d'un serveur
# * - Creation d'un serveur (custom)
# X - Suppression d'un serveur
# * - Censurer des informations sur le serveur (si bouton censuré presser)
# V - Rejoindre un serveur (ENET)
# X - Connect to UDP Server (Chat + Liste Joueur)
# V - Stocker des information sur le disque sur le joueur (liste des serveur, pseudo, etc...)
# X - Intégration d'image (de joueur = avatar)
# * - Intégration de Steam (pseudo + Image (++ Serveur))
# X - Envoi de message (ENET)
# X - Recepteur de message (ENET)
# X - Envoi de message (UDP)
# X - Recepteur de message (UDP)
# X - Recepteur de message (UDP)

@onready var server_list : ItemList = %ServerList
@onready var server_info : RichTextLabel = %ServerInfo
@onready var channel_name : Label = %ChannelName
#@onready var channel_info : RichTextLabel = null
@onready var join_button : Button = %JoinButton
@onready var refresh_button : Button = %RefreshButton
@onready var guild_list : ItemList = %GuildList
@onready var channel_chat : VBoxContainer = %ChannelChat
@onready var chat_input : LineEdit = %ChatInput
@onready var steam_friends_server : ItemList = %FriendsList

#@export_file("*.tscn") var scenes_files : Dictionary[String,String]
@export var scenes_files : Dictionary[String, String] = {
	"koth_speedrun" : "res://GDDiscord/Godot/Scenes/World3D.tscn",
}

#@export_tool_button("Prints Hello") var hello = func(): print("Hello")
@export var discord_message_packed_scene : PackedScene = preload("res://GDDiscord/Godot/Scenes/DiscordChatMessage.tscn")
var current_selected_server : DServerContainer = null

@onready var server_storage_inst : DServerList = DServerList.new()


func _ready() -> void:
	#$"AddServer".close_requested.connect(_on_addserver_popup_close.bind(POPUP_STATUS.POPUP_CLOSED))
	#$"AddServer/VBoxContainer/HBoxContainer/Popup_Add".pressed.connect(_on_addserver_popup_close.bind(POPUP_STATUS.POPUP_ACCEPT))
	#$"AddServer/VBoxContainer/HBoxContainer/Popup_Cancel".pressed.connect(_on_addserver_popup_close.bind(POPUP_STATUS.POPUP_DECLINED))

	%AddButton.pressed.connect(func(): blur_appear() ; $AddServer.popup_centered())
	%RemoveButton.pressed.connect(_on_server_remove_pressed)
	$AddServer.close_requested.connect(func(): blur_disapeer() ; $AddServer.hide())
	$AddServer.add_server_confirmed.connect(_add_server_to_server_list)
	$AddServer.add_server_error.connect(error_popup_show)
	$ErrorMessage.close_requested.connect(_on_error_popup_ok)
	%ServerCreation.server_created.connect(server_got_created)

	var map_choose_menu : OptionButton = %ServerCreation.map_edit
	map_choose_menu.clear()
	var i = 0
	for scene in scenes_files.keys():
		map_choose_menu.add_item(scene, i)
		map_choose_menu.set_item_tooltip(i, scene.capitalize())
		map_choose_menu.set_item_metadata(i, scenes_files[scene])
		i += 1

	server_storage_inst.retrieve_servers_profiles()
	
	for childs in %Favorites.get_children():
		childs.queue_free()
	
	for server in server_storage_inst.server_list.values():
		add_server_to_server_list(server)
	
#region Aestetics

func blur_disapeer():
	#$"CanvasLayer/ColorRect".show()
	$"CanvasLayer".blurry_stop(0.5)
	#get_tree().create_timer(0.5).timeout.connect($"CanvasLayer/ColorRect".hide)

func blur_appear():
	#$"CanvasLayer/ColorRect".show()
	$"CanvasLayer".blurry_start(0.5)

func _add_server_to_server_list(server_name : String, server_ip : String, server_port : int):
	var dserv : DServer = DServer.new()
	dserv.name = server_name
	dserv.ip = server_ip
	dserv.port = int(server_port)
	dserv.server_confirmed = false
	dserv.icon = preload("res://GDDiscord/icon.svg")

	server_storage_inst.add_server_profile(dserv)

	add_server_to_server_list(dserv)

func add_server_to_server_list(server_info : DServer):
	var server_c : DServerContainer = preload("uid://buv14akurqjyc").instantiate()
	server_c.callback = (_on_server_list_item_clicked.bind(server_c))
	%Favorites.add_child(server_c)
	server_c.load_profile(server_info)
	server_storage_inst.server_list.merge({server_info.name : server_info})


func try_join_server(dserv : DServer):
	if dserv.server_confirmed:
		Networking.target_enet_server_ip = dserv.ip
		Networking.target_enet_server_port = dserv.port
		Networking.is_hosting_enet = false
		get_tree().change_scene_to_file(server_info["server_scene"])

func _on_server_remove_pressed():
	if current_selected_server:
		current_selected_server.queue_free()
		current_selected_server = null

func _on_addserver_popup_show():
	$"AddServer".show()
	blur_appear()

func error_popup_show(message : String):
	$ErrorMessage/VBoxContainer/MarginContainer/VBoxContainer/ErrorContainer/ErrorContent.text = (message if not message.is_empty() else "An error has occured")
	$"ErrorMessage".show()

func _on_error_popup_ok():
	$"ErrorMessage".hide()
	blur_disapeer()

func _on_error_popup_copy_to_clipboard():
	DisplayServer.clipboard_set($ErrorMessage/VBoxContainer/MarginContainer/VBoxContainer/ErrorContainer/ErrorContent.text)

func server_got_created(server_info : Dictionary):
	if FileAccess.file_exists(server_info["server_scene"]):
		Networking.server_info = server_info
		Networking.target_enet_server_ip = server_info["server_ip"]
		Networking.target_enet_server_port = server_info["server_enet_port"]
		Networking.is_hosting_enet = true

		Networking.host_server(false)

		LoadingScenes.change_scene(server_info["server_scene"])

		#get_tree().change_scene_to_file(server_info["server_scene"])


func _on_server_info_meta_clicked(meta: Variant) -> void:
	var nmeta : String = meta as String
	var urlRegex = RegEx.new()
	urlRegex.compile('^(http|https)://[^ "]+$')
	var result = urlRegex.search(nmeta)
		
	if result:
		OS.shell_open(result.get_string())
		return

func _on_server_list_item_clicked(server_c : DServerContainer) -> void:
	current_selected_server = server_c
	var choosen_server : Dictionary = server_c.server_info.dserver_to_data()
	## If the server isn't in the list of available servers, Ask the server's information
	if choosen_server.has("server_ip") and not Networking.server_responses.has(choosen_server["server_ip"]):
		%ServerInfo.set_text("[color=orange] Server is being interrogated... [/color]")
		var status = await Networking.ask_availability(choosen_server["server_ip"], choosen_server["server_port"])
		if status == ERR_UNAVAILABLE:
			%ServerInfo.set_text("[color=dark_gray] Server is not available. [/color]")
			return
		if Networking.server_responses.has(choosen_server["server_ip"]):
			server_c.server_info = server_c.server_info.data_to_dserver(Networking.server_responses[choosen_server["server_ip"]])
			server_c.server_info.server_confirmed = true	
	
	%ServerInfo.clear()
	for key in server_c.server_info:
		#%ServerInfo.push_bold()
		%ServerInfo.append_text("[b]" + key.capitalize() + " :[/b] ")
		%ServerInfo.append_text(str(server_info[key]))
		%ServerInfo.newline()


func _on_server_list_empty_clicked(_at_position: Vector2, mouse_button_index: int) -> void:
	current_selected_server = null
	%ServerInfo.set_text("[color=dark_gray] No server info to display.\nOr nothing selected [/color]")


#region Steam
