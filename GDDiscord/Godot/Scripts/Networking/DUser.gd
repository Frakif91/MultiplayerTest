class_name DUser extends Resource

enum DUserStatus { CONNECTED, DISCONNECTED, KICKED, BANNED, CONNECTING, AFK, PLAYING}

static var default_profile_path = "user://GDDiscord/profiles/"
static var default_user_profile_extension = ".duser"

@export var name : String
@export var color : Color
@export var grades : Array[int]
@export var avatar : Texture = preload("res://GDDiscord/icon.svg")
@export var _is_steam_user : bool
@export var _steam_id : int

@export var peer_id : int
@export var status : DUserStatus = DUserStatus.DISCONNECTED

func _init(peer_id : int = 0, name : String = "User", ip : String = "0.0.0.0", port : int = 0):
    self.peer_id = peer_id
    self.name = name
    self.ip = ip
    self.port = port

static func user_profile_path(name : String) -> String:
    return default_profile_path + name + default_user_profile_extension

## Retrieve from disk the user profile of "name"
static func retrieve_user_cached_profile(name : String) -> DUser:
    var userpath = user_profile_path(name)
    if FileAccess.file_exists(userpath):
        var user := ResourceLoader.load(userpath)
        if user is DUser:
            return user
    return null

func store_user_profile():
    var file = FileAccess.open(user_profile_path(self.name), FileAccess.ModeFlags.WRITE)
    if file:
        file.store_var(self)
    else:
        push_error("Failed to write file " + user_profile_path(self.name) + " : " + str(file.get_open_error()))
    file.close()
    return FAILED
