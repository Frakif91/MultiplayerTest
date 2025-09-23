class_name DServerContainer extends MarginContainer

@onready var lbl_name: Label = $MarginContainer/ServerInfo/HB/MarginContainer/VBoxContainer/Control/Name
@onready var lbl_desc: Label = $MarginContainer/ServerInfo/HB/MarginContainer/VBoxContainer/Desc
@onready var icon: TextureRect = $MarginContainer/ServerInfo/HB/Icon
@export var callback : Callable
@onready var button: Button = $Button
var server_info : DServer

func _ready():
	button.pressed.connect(callback)

func load_profile(_server_info : DServer):
	server_info = _server_info
	lbl_name.text = server_info.name
	lbl_desc.text = server_info.server_motd
	icon.texture = server_info.icon
