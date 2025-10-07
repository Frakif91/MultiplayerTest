extends MarginContainer

var list_entries : Array[UIListEntryFriend] = []
@onready var box_container_friends: BoxContainer = $BGP/VBoxContainer/BGS2/Separator/ProfileSteam/ScrollContainer/PanelContainer/MarginContainer/BoxContainer

func _ready() -> void:
    print_debug("[Friend List] Using steam to refresh friend list...")
    await get_tree().create_timer(3.0).timeout
    refresh_friend_list()

func refresh_friend_list():
    for entry in list_entries:
        entry.queue_free()
    list_entries.clear()

    var friends = await SteamManager.load_friends()
    print_debug("[Friend List] Found ", friends.size(), " friends")
    for duser in friends:
        add_friend(duser)

func add_friend(duser : DUser):
    var entry = UIListEntryFriend.new()
    entry.duser = duser
    box_container_friends.add_child(entry)
    list_entries.append(entry)

