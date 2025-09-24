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
	%ServerCreation.server_created.connect(server_created)


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
		var server_c : DServerContainer = preload("uid://buv14akurqjyc").instantiate()
		server_c.load_profile(server)
		%Favorites.add_child(server_c)
	

#region Aestetics


func blur_disapeer():
	$"CanvasLayer/ColorRect".show()
	$"CanvasLayer".blurry_stop(0.5)
	get_tree().create_timer(0.5).timeout.connect($"CanvasLayer/ColorRect".hide)

func blur_appear():
	$"CanvasLayer/ColorRect".show()
	$"CanvasLayer".blurry_start(0.5)


func _add_server_to_server_list(server_name : String, server_ip : String, server_port : int):
	var dserv : DServer = DServer.new()
	dserv.name = server_name
	dserv.ip = server_ip
	dserv.port = int(server_port)
	dserv.server_confirmed = false
	dserv.server_id = 0
	dserv.icon = preload("res://GDDiscord/icon.svg")

	add_server_to_server_list(dserv)

func add_server_to_server_list(server_info : DServer):
	var server_c : DServerContainer = preload("uid://buv14akurqjyc").instantiate()
	server_c.callback = (func(): current_selected_server = self)
	%Favorites.add_child(server_c)
	server_c.load_profile(server_info)
	server_storage_inst.server_list.merge({server_info.name : server_info})


func try_join_server(server_info : Dictionary):
	if server_info.has("server_ip") and server_info.has("server_enet_port"):
		Networking.target_enet_server_ip = server_info["server_ip"]
		Networking.target_enet_server_port = server_info["server_enet_port"]
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



func server_created(server_info : Dictionary):
	if FileAccess.file_exists(server_info["server_scene"]):
		Networking.server_info = server_info
		Networking.target_enet_server_ip = server_info["server_ip"]
		Networking.target_enet_server_port = server_info["server_enet_port"]
		Networking.is_hosting_enet = true

		Networking.host_server(server_info.get("server_use_steam", false))

		get_tree().change_scene_to_file(server_info["server_scene"])


func _on_server_info_meta_clicked(meta: Variant) -> void:
	var nmeta : String = meta as String
	var urlRegex = RegEx.new()
	urlRegex.compile('^(http|https)://[^ "]+$')
	var result = urlRegex.search(nmeta)
		
	if result:
		OS.shell_open(result.get_string())
		return

func _on_server_list_item_clicked(server_c : DServerContainer) -> void:
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
	for key in server_info:
		#%ServerInfo.push_bold()
		%ServerInfo.append_text("[b]" + key.capitalize() + " :[/b] ")
		%ServerInfo.append_text(str(server_info[key]))
		%ServerInfo.newline()


func _on_server_list_empty_clicked(_at_position: Vector2, mouse_button_index: int) -> void:
	%ServerInfo.set_text("[color=dark_gray] No server info to display.\nOr nothing selected [/color]")


#region Steam

const FRIEND_RELATIONSHIP = {
	0: "None",
	1: "Blocked",
	2: "RequestRecipient",
	3: "Friend",
	4: "RequestInitiator",
	5: "Ignored",
	6: "IgnoredFriend",
	7: "SuggestedFriend",
	8: "Max",
}

const FRIEND_FLAG = {
	0x00: "None",
	0x01: "Blocked",
	0x02: "FriendshipRequested",
	0x04: "Immediate",
	0x08: "ClanMember",
	0x10: "OnGameServer",
	0x20: "RequestingFriendship",
	0x40: "RequestingInfo",
	0x80: "Ignored",
	0x100: "IgnoredFriend",
	0x200: "ChatMember",
	0x400: "All",
}


@export var persona_status_colors : Dictionary[String,Color] = {
	"Offline" : Color(0,0,0,1),
	"Busy" :    Color(0,0,0,1),
	"Away" :    Color(0,0,0,1),
	"Online" :  Color(0,0,0,1),
	"Playing" : Color(0,0,0,1)
}
var friend_lobbies : Array[int]
var loaded_avatars : Dictionary

func _on_steam_init() -> void:
	var friends := []
	var friend_count = Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)

	for i in range(friend_count):
		var friend_id = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		var game_played = Steam.getFriendGamePlayed(friend_id)
		print_debug("[GGDDiscord Scene] Friend " + str(friend_id) + " is playing " + str(game_played))
		if game_played != null and game_played.get("gameID",0) == Steam.getAppID():
			friends.append(friend_id)

func update_friend_servers() -> void:
	server_list.clear()
	friend_lobbies.clear()

	var friend_count := Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)

	for i in range(friend_count):
		var friend_id := Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		var game_played := Steam.getFriendGamePlayed(friend_id)

		# Only care about friends running this same AppID
		if game_played and game_played["gameID"] == Steam.getAppID():
			# Ask Steam for lobby list, filtered to their lobbies
			#Steam.addRequestLobbyListFilter("host", str(friend_id))
			Steam.addRequestLobbyListStringFilter("host", str(friend_id), Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)
			Steam.requestLobbyList()


func _on_lobby_match_list(lobbies: Array) -> void:
	for lobby_id in lobbies:
		var owner := Steam.getLobbyOwner(lobby_id)
		var host_id := Steam.getLobbyData(lobby_id, "host")

		# Check that this lobby is from a friend
		if host_id != "" and int(host_id) == owner:
			friend_lobbies.append(lobby_id)

			var persona := Steam.getFriendPersonaName(owner)

			var tex : Texture = await Networking.get_steam_avatar(owner)

			# Add to server_list
			var idx := server_list.add_item("(Steam) %s's Server" % persona, tex)
			server_list.set_item_metadata(idx, lobby_id)


func _on_lobby_data_update(success: bool, lobby_id: int, member_id: int) -> void:
	# Optional: handle dynamic lobby data changes here (like player count)
	pass
