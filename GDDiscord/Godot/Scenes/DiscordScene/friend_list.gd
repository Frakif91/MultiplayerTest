extends MarginContainer

var list_entries : Array[UIListEntryFriend] = []
@onready var box_container_friends: BoxContainer = $BGP/VBoxContainer/BGS2/Separator/ProfileSteam/ScrollContainer/PanelContainer/MarginContainer/BoxContainer

func _ready() -> void:
    pass


func add_friend(duser : DUser):
    var entry = UIListEntryFriend.new()
    entry.duser = duser
    box_container_friends.add_child(entry)
    list_entries.append(entry)

