class_name SteamManager extends Node

signal receive_user_invite(user_id: int, payload: Dictionary)

var _avatar_requests: Dictionary = {} # store async avatar callbacks

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


# -----------------------------------------------------------------------------
# --- Initialization
# -----------------------------------------------------------------------------
func _ready() -> void:
	if not Steam.isSteamRunning():
		push_warning("Steam not running; SteamUtil will be inactive.")
		return

	# Listen for join/invite signals from GodotSteam
	if Steam.has_signal("game_rich_presence_join_requested"):
		Steam.connect("game_rich_presence_join_requested", Callable(self, "_on_game_invite"))

# -----------------------------------------------------------------------------
# --- User Info
# -----------------------------------------------------------------------------
static func get_user_name(user_id: int = 0) -> String:
	if not Steam.isSteamRunning(): return "Unknown"
	return Steam.getPersonaName() if user_id == 0 else Steam.getFriendPersonaName(user_id)

static func get_user_state(user_id: int = 0) -> String:
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

static func get_user_game_name(user_id: int = 0) -> String:
	if not Steam.isSteamRunning(): return ""
	if user_id == 0:
		return Steam.getFriendGamePlayed(user_id).get("name", "")
	var info := Steam.getFriendGamePlayed(user_id)
	return info.get("name", "")

# -----------------------------------------------------------------------------
# --- Avatar Handling (Async)
# -----------------------------------------------------------------------------
static func get_user_avatar(user_id: int = 0, size = Steam.AVATAR_MEDIUM) -> ImageTexture:
	if not Steam.isSteamRunning():
		push_error("Steam not running")
		return

	if user_id == 0:
		user_id = Steam.getSteamID()
	
	var loaded_avatar : Image = null
	
	Steam.avatar_loaded.connect(func(id, size, data): loaded_avatar = Image.create_from_data((Steam.getImageSize(size)["width"] as int), (Steam.getImageSize(size)["height"] as int), false, Image.FORMAT_RGBA8, data))
	Steam.getPlayerAvatar(size, user_id)
	await Steam.avatar_loaded

	var target : ImageTexture
	if target != null:
		target.texture = ImageTexture.create_from_image(loaded_avatar)
	
	return target





# -----------------------------------------------------------------------------
# --- Invites
# -----------------------------------------------------------------------------
func create_lobby(server_info : DServer) -> int:
	if not Steam.isSteamRunning():
		push_error("Steam not running")
		return 0
	
	var id : int = 0
	var status : int = 0
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, 8)
	Steam.lobby_created.connect(func(connect, lobby_id):
		id = lobby_id
		status = connect
	)

	Steam.setLobbyJoinable(id, true)
	Steam.allowP2PPacketRelay(true)


	var success = Steam.setLobbyData(id, "host", str(Steam.getSteamID()));
	success = Steam.setLobbyData(id, "ip", server_info.ip);
	success = Steam.setLobbyData(id, "port", str(server_info.port));
	success = Steam.setLobbyData(id, "name", server_info.server_name + " - " + server_info.server_motd);
	success = Steam.setLobbyData(id, "version", ProjectSettings.get_setting("application/config/version"));
	success = Steam.setLobbyData(id, "map", server_info.server_map);
	return id



static func send_user_game_invite(user_id: int, lobby_id: int, payload: Dictionary = {}) -> void:
	if not Steam.isSteamRunning():
		push_error("Steam not running")
		return

	Steam.inviteUserToLobby(lobby_id, lobby_id)

static func load_friends() -> Array[DUser]:
	if not Steam.isSteamRunning():
		print_debug("[SteamManager] Steam not running, returning empty Friend List")
		return []

	var friend_list = []
	for friend_index in range(Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)):
		var friend_duser : DUser = DUser.new()

		var friend_id = Steam.getFriendByIndex(friend_index, Steam.FRIEND_FLAG_IMMEDIATE)
		var friend_name = Steam.getFriendPersonaName(friend_id)
		#var friend_status = Steam.getFriendPersonaState(friend_id)

		friend_duser.name = friend_name
		friend_duser.avatar = await get_user_avatar(friend_id)
		friend_duser.id = friend_id
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
	return friend_list

# -----------------------------------------------------------------------------
# --- Signal Handling
# -----------------------------------------------------------------------------
func _on_game_invite(inviter_id: int, connect_str: String) -> void:
	var payload: Dictionary = {}
	var parsed = JSON.parse_string(connect_str)
	if typeof(parsed) == TYPE_DICTIONARY:
		payload = parsed
	emit_signal("receive_user_invite", inviter_id, payload)
