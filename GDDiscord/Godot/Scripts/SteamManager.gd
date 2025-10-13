#class_name SteamManager
extends Node

signal attempting_to_join_server(query_ip : String, query_port : int)

# Lobbies init
const PACKET_READ_LIMIT: int = 32

var lobby_data

var lobby_id: int = 0
var lobby_connection_error : int = 0

var lobby_members: Array = []
var lobby_members_max: int = 10
var lobby_vote_kick: bool = false
var steam_id: int = 0
var steam_username: String = ""

# Avatar init
var loaded_avatar_dict : Dictionary[int, Image] = {}
var loaded_game_names : Dictionary[int, String] = {}

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

const PERSONA_STATE_STRINGS = {
	Steam.PersonaState.PERSONA_STATE_OFFLINE : "Offline",
	Steam.PersonaState.PERSONA_STATE_ONLINE : "Online",
	Steam.PersonaState.PERSONA_STATE_BUSY : "Busy",
	Steam.PersonaState.PERSONA_STATE_AWAY : "Away",
	Steam.PersonaState.PERSONA_STATE_SNOOZE : "Snooze",
	Steam.PersonaState.PERSONA_STATE_LOOKING_TO_TRADE : "Looking to Trade",
	Steam.PersonaState.PERSONA_STATE_LOOKING_TO_PLAY : "Looking to Play",
	Steam.PersonaState.PERSONA_STATE_MAX : "Max",
}


const RESULTS_STRINGS = {
	Steam.Result.RESULT_OK : "OK",
	Steam.Result.RESULT_FAIL : "FAIL",
	Steam.Result.RESULT_TIMEOUT : "TIMEOUT",
	Steam.Result.RESULT_LIMIT_EXCEEDED : "LIMIT_EXCEEDED",
	Steam.Result.RESULT_ACCESS_DENIED : "ACCESS_DENIED",
	Steam.Result.RESULT_NO_CONNECTION : "NO_CONNECTION",
}


@export var persona_status_colors : Dictionary[String,Color] = {
	"Offline" : Color(0,0,0,1),
	"Busy" :    Color(0,0,0,1),
	"Away" :    Color(0,0,0,1),
	"Online" :  Color(0,0,0,1),
	"Playing" : Color(0,0,0,1)
}


# -----------------------------------------------------------------------------
# --- Initialization
# -----------------------------------------------------------------------------
func _ready() -> void:
	if not Steam.isSteamRunning():
		push_warning("Steam not running; SteamUtil will be inactive.")
		return

	# Listen for join/invite signals from GodotSteam
	Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.avatar_loaded.connect(_on_avatar_recieved)
	#Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_created.connect(_on_lobby_created)
	#Steam.lobby_data_update.connect(_on_lobby_data_update)
	Steam.lobby_invite.connect(_on_lobby_invite)
	Steam.lobby_joined.connect(_on_lobby_joined)
	#Steam.lobby_match_list.connect(_on_lobby_match_list)
	#Steam.lobby_message.connect(_on_lobby_message)
	Steam.persona_state_change.connect(_on_persona_change)

# -----------------------------------------------------------------------------
# --- User Info
# -----------------------------------------------------------------------------
func get_user_name(user_id: int = 0) -> String:
	if not Steam.isSteamRunning(): return "Unknown"
	return Steam.getPersonaName() if user_id == 0 else Steam.getFriendPersonaName(user_id)

func get_user_state(user_id: int = 0) -> String:
	if not Steam.isSteamRunning(): return "Offline"
	var state_id: int = (
		Steam.getPersonaState() if user_id == 0
		else Steam.getFriendPersonaState(user_id)
	)
	match state_id:
		0: return "Offline"
		1: return "Online"
		2: return "Busy"
		3: return "Away"
		4: return "Snooze"
		5: return "Looking to Trade"
		6: return "Looking to Play"
		_: return "Unknown"

# -----------------------------------------------------------------------------
# --- Game Info
# -----------------------------------------------------------------------------
static func get_user_game_id(user_id: int = 0) -> int:
	if not Steam.isSteamRunning(): return 0
	if user_id == 0:
		return Steam.getAppID()
	var info := Steam.getFriendGamePlayed(user_id)
	return info.get("id", 0)

# -----------------------------------------------------------------------------
# --- Avatar Handling (Async)
# -----------------------------------------------------------------------------

func get_user_avatar(user_id: int = 0, size : Steam.AvatarSizes = Steam.AVATAR_MEDIUM) -> ImageTexture:
	if not Steam.isSteamRunning():
		push_error("[Steam - Get User Avatar]Steam not running")
		return

	if user_id == 0:
		user_id = Steam.getSteamID()
	
	if loaded_avatar_dict.has(user_id):
		return ImageTexture.create_from_image(loaded_avatar_dict[user_id])	
	
	Steam.getPlayerAvatar(size,user_id) # Ask
	var timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(1.0)

	while not loaded_avatar_dict.has(user_id) and not timer.is_stopped():
		await get_tree().process_frame
	
	if timer.is_stopped():
		printerr("[Steam] Failed to get avatar for user " + str(user_id) + " (Timeout)")
		timer.queue_free()
		return

	timer.queue_free()
	if not loaded_avatar_dict.has(user_id):
		return
	var target : ImageTexture = ImageTexture.create_from_image(loaded_avatar_dict[user_id])
	
	return target

# -----------------------------------------------------------------------------
# --- Invites
# -----------------------------------------------------------------------------

func create_lobby(server_info : DServer) -> int:
	if not Steam.isSteamRunning():
		push_error("Steam not running")
		return 0

	if lobby_id != 0:
		print("[Steam] Lobby already created -> Destroying lobby")
		Steam.leaveLobby(lobby_id)

	lobby_id = -1 # -1 If pending, 0 if failed, Other if succesful
	lobby_connection_error = 0
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, server_info.max_players)
	print_debug("[Steam] Lobby creating...")
	await Steam.lobby_created # Steam has a builtin timeout !

	if lobby_connection_error != 0:
		printerr("[Steam] Failed to create lobby (Connection Error : " + RESULTS_STRINGS[lobby_connection_error] + ")")
		return 0
	
	# If succesful, continues
	Steam.setLobbyGameServer(lobby_id, server_info.server_public_ip, server_info.server_public_port)
	Steam.setLobbyJoinable(lobby_id, true)
	Steam.allowP2PPacketRelay(true)

	Steam.setLobbyData(lobby_id, "host", str(Steam.getSteamID()));
	Steam.setLobbyData(lobby_id, "ip", server_info.ip);
	Steam.setLobbyData(lobby_id, "port", str(server_info.port));
	Steam.setLobbyData(lobby_id, "name", server_info.server_name + " - " + server_info.server_motd);
	Steam.setLobbyData(lobby_id, "version", ProjectSettings.get_setting("application/config/version"));
	Steam.setLobbyData(lobby_id, "map", server_info.server_map);
	
	return lobby_id


func send_user_game_invite(user_id: int, payload: Dictionary = {}) -> void:
	if not Steam.isSteamRunning():
		push_error("Steam not running")
		return
	Steam.inviteUserToGame(user_id, JSON.stringify(payload))
	
	
func send_user_lobby_invite(user_id: int, lobby_id: int) -> void:
	if not Steam.isSteamRunning():
		push_error("Steam not running")
		return
	if lobby_id == 0:
		push_error("Invalid lobby id")
		return
	Steam.inviteUserToLobby(lobby_id, user_id)
	

func load_friends() -> Array[DUser]:
	if not Steam.isSteamRunning():
		print_debug("[SteamManager] Steam not running, returning empty Friend List")
		return []

	var friend_list : Array[DUser] = []
	for friend_index in range(Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)):
		var friend_duser : DUser = DUser.new()


		var friend_id = Steam.getFriendByIndex(friend_index, Steam.FRIEND_FLAG_IMMEDIATE)
		var friend_name = Steam.getFriendPersonaName(friend_id)
		#var friend_status = Steam.getFriendPersonaState(friend_id)

		var _steam_as_already_loaded_user = Steam.requestUserInformation(friend_id, false)

		friend_duser.name = friend_name
		friend_duser.avatar = await get_user_avatar(friend_id)
		friend_duser._is_steam_user = true
		friend_duser._steam_id = friend_id
		match Steam.getFriendPersonaState(friend_id):
			Steam.PERSONA_STATE_ONLINE:
				friend_duser.status = DUser.DUserStatus.ONLINE
			Steam.PERSONA_STATE_BUSY:
				friend_duser.status = DUser.DUserStatus.AFK
			Steam.PERSONA_STATE_AWAY:
				friend_duser.status = DUser.DUserStatus.AFK
			Steam.PERSONA_STATE_INVISIBLE:
				friend_duser.status = DUser.DUserStatus.DISCONNECTED
			Steam.PERSONA_STATE_OFFLINE:
				friend_duser.status = DUser.DUserStatus.DISCONNECTED
			Steam.PERSONA_STATE_SNOOZE:
				friend_duser.status = DUser.DUserStatus.AFK

		friend_list.append(friend_duser)
	return friend_list

func request_friends_lobby() -> Array[DServer]:
	if not Steam.isSteamRunning():
		print_debug("[SteamManager] Steam not running, returning empty Friend List")
		return []

	var lobby_list : Array[DServer] = []
	for friend_index in range(Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)):
		var friend_lobby : DServer = DServer.new()

		#var _steam_as_already_loaded_user = Steam.requestUserInformation(Steam.getFriendByIndex(friend_index, Steam.FRIEND_FLAG_IMMEDIATE), false)

		var friend_id = Steam.getFriendByIndex(friend_index, Steam.FRIEND_FLAG_IMMEDIATE)
		var friend_name = Steam.getFriendPersonaName(friend_id)
		#var friend_status = Steam.getFriendPersonaState(friend_id)

		friend_lobby.name = friend_name
		friend_lobby.avatar = await get_user_avatar(friend_id)
		friend_lobby._is_steam_user = true
		friend_lobby._steam_id = friend_id

 
		lobby_list.append(friend_lobby)
	return lobby_list

# -----------------------------------------------------------------------------
# --- HTTP API
# -----------------------------------------------------------------------------

func get_game_name_from_steam(app_id: int) -> String:
	if loaded_game_names.has(app_id):
		return loaded_game_names[app_id]

	var url = "https://store.steampowered.com/api/appdetails?appids=%s" % app_id
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_request_completed)
	req.request(url)
	await req.request_completed
	print_debug("[SteamManager] Game name for app id %s : %s" % [app_id, loaded_game_names[app_id]])
	return loaded_game_names[app_id]

# -----------------------------------------------------------------------------
# --- Signal Handling
# -----------------------------------------------------------------------------

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.values()[0]["success"]:
		var gname = (json.values()[0]["data"]["name"] as String)
		#print("Nom du jeu : ", gname)
		if (typeof(json.values()[0]) == TYPE_STRING) and ((json.values()[0] as String).is_valid_int()):
			loaded_game_names[int(json.values()[0])] = gname
		elif typeof(json.values()[0]["data"]["steam_appid"]) == TYPE_FLOAT:
			loaded_game_names[int(json.values()[0]["data"]["steam_appid"])] = gname
		else:
			print("Unknown game id ", json.values()[0])


func _on_lobby_created(connect_r: int, lobby_id: int) -> void:
	lobby_id = lobby_id
	lobby_connection_error = (connect_r as Error)

## Steam.avatar_loaded(avatar_id, width, rawdata) callback
func _on_avatar_recieved(avatar_id: int, size: int, data: PackedByteArray) -> void:
	loaded_avatar_dict[avatar_id] = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)

## Called when a game invite is received (i.e a friend invites you to launch the game)
func _on_game_invite(inviter_id: int, connect_str: String) -> void:
	var payload: Dictionary = {}
	var parsed = JSON.parse_string(connect_str)
	if typeof(parsed) == TYPE_DICTIONARY:
		payload = parsed
	emit_signal("receive_user_invite", inviter_id, payload)


## Called when a lobby invite is received
func _on_lobby_invite(inviter_id: int, lobby_id: int) -> void:
	emit_signal("receive_lobby_invite", inviter_id, lobby_id)


func _on_lobby_join_requested(lobby_id: int, friend_id: int) -> void:
	print("(Steam) Join requested! Lobby:", lobby_id, "from friend:", friend_id)
	Steam.joinLobby(lobby_id)

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# If joining was successful
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		# Set this lobby ID as your lobby ID
		lobby_id = this_lobby_id

		# Get the lobby members
		#get_lobby_members()

		# Make the initial handshake
		#make_p2p_handshake()

	# Else it failed for some reason
	else:
		# Get the failure reason
		var fail_reason: String

		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."

		print("Failed to join this chat room: %s" % fail_reason)

		#Reopen the lobby list
		#_on_open_lobby_list_pressed()


func _on_persona_change(steam_id, flags : Steam.PersonaChange) -> void:
	pass
