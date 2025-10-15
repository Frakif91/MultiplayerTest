extends MarginContainer

var list_entries : Array[UIListEntryFriend] = []

@onready var box_container_friends: VBoxContainer = $BGP/VBC/BGS2/Separator/ProfileSteam/ScrollContainer/PanelContainer/MarginContainer/BoxContainer
@onready var current_user_avatar: TextureRect = $BGP/VBC/PC/BGS/VB/MC/HBC/MC/Outline/TextureRect
@onready var current_user_name: Label = $BGP/VBC/PC/BGS/VB/MC/HBC/VBC/UserName
@onready var current_user_status: Label = $BGP/VBC/PC/BGS/VB/MC/HBC/VBC/UserStatus
@onready var quit_lobby: Button = %QuitLobby
@onready var steam_create_lobby: Button = %SteamCreateLobby

func _ready() -> void:
	print_debug("[Friend List] Using steam to refresh friend list...")
	#await get_tree().create_timer(3.0).timeout
	refresh_friend_list()
	refresh_cur_user_profile()

func refresh_friend_list():
	for entry in box_container_friends.get_children():
		entry.queue_free()
	list_entries.clear()

	var friends = await SteamManager.load_friends()
	print_debug("[Friend List] Found ", friends.size(), " friends")
	for duser in friends:
		add_friend(duser)

func refresh_cur_user_profile():
	current_user_avatar.texture = await SteamManager.get_user_avatar(SteamManager.steam_id)
	current_user_name.text = SteamManager.get_user_name(SteamManager.steam_id)
	current_user_status.text = SteamManager.get_user_state(SteamManager.steam_id)
	if SteamManager.get_user_state() == "Online":
		current_user_status.modulate = Color.LIGHT_GREEN

func add_friend(duser : DUser):
	var entry : UIListEntryFriend = preload("res://GDDiscord/Godot/Scenes/DiscordScene/ui_friend.tscn").instantiate()
	entry.duser = duser
	entry.update()
	box_container_friends.add_child(entry)
	if entry.persona_state != "Offline":
		box_container_friends.move_child(entry,0)
	
	list_entries.append(entry)
