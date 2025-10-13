class_name UIListEntryFriend extends MarginContainer

signal right_clicked(pos : Vector2)
signal left_clicked(pos : Vector2)

@export var menu_button: MenuButton
@export var button: Button
@export var user_name: Label
@export var status: Label 
@export var status_extra: Label
@export var profile_picture: TextureRect

var duser : DUser : set = set_duser
var primary_status_text : String
var secondary_status_text : String

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	menu_button.get_popup().id_pressed.connect(on_button_pressed)

func update():
	profile_picture.texture = self.duser.avatar
	user_name.text = self.duser.name
	status.text = primary_status_text
	status_extra.text = secondary_status_text

	var subbutton = (menu_button.get_popup() as PopupMenu)
	subbutton.clear()
	if duser._is_steam_user:
		match int(Steam.getFriendPersonaState(duser._steam_id)):
			Steam.PERSONA_STATE_ONLINE, Steam.PERSONA_STATE_BUSY, Steam.PERSONA_STATE_SNOOZE:
				if SteamManager.lobby_id != 0:
					subbutton.add_item("Invite to Lobby", 0)
					subbutton.id_pressed.connect(on_button_pressed)
				else:
					print("[UIListEntryFriend - ID : " + str(duser._steam_id) + "] No lobby to invite to because Persona_State : " + SteamManager.PERSONA_STATE_STRINGS[Steam.getFriendPersonaState(duser._steam_id)])
				if Steam.getFriendGamePlayed(duser._steam_id).has("lobby"):
					subbutton.add_item("Join Lobby", 1)
		subbutton.add_item("Get SteamID64", 2)

func set_duser(_duser : DUser) -> void:
	duser = _duser
	if Steam.isSteamRunning():
		var game_info : Dictionary = Steam.getFriendGamePlayed(_duser._steam_id)
		if game_info.has("lobby"):
			primary_status_text = "Currently Playing"
			var game_name = await SteamManager.get_game_name_from_steam(game_info["id"])
			secondary_status_text = (game_name if (game_name != null or game_name != "") else "Unknown Game")
			#secondary_status_text = "SHUT THE FUCK UP"
	update()

func _on_button_pressed() -> void:
	left_clicked.emit(get_global_mouse_position())
	# Make the menu button apear where the cursor clicked
	menu_button.global_position = get_global_mouse_position()
	menu_button.show_popup()


func on_button_pressed(id : int) -> void:
	if id == 0:
		if Networking.client_or_server == Networking.NetworkType.SERVER and Networking.is_hosting_enet:
			SteamManager.send_user_game_invite(duser._steam_id, Networking.server_info)
	if id == 1:
		if Steam.getFriendGamePlayed(duser._steam_id).has("lobby"):
			Steam.joinLobby(Steam.getFriendGamePlayed(duser._steam_id)["lobby"] as int)
	if id == 2:
		DisplayServer.clipboard_set(str(duser._steam_id))
		print_debug("Copied SteamID64 to clipboard")
