class_name UIListEntryFriend extends MarginContainer

signal right_clicked(pos : Vector2)
signal left_clicked(pos : Vector2)

@onready var menu_button: MenuButton = $MenuButton
@onready var button: Button = $Button
@onready var user_name: Label = $Button/Border/UIHB/UserName
@onready var status: Label = $Button/Border/UIHB/PersonaInfo/Status
@onready var status_extra: Label = $Button/Border/UIHB/PersonaInfo/StatusExtra
@onready var profile_picture: TextureRect = $Button/Border/UIHB/Icons/ProfilePicture

var duser : DUser

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)

func update():

	if Steam.isSteamRunning():
		if self.duser.avatar != null:
			profile_picture.texture = self.duser.avatar
		user_name.text = self.duser.name
		status.text = "e"
		status_extra.text = self.duser.status_extra


func _on_button_pressed() -> void:
	left_clicked.emit(get_global_mouse_position())
	
	# Make the menu button apear where the cursor clicked
	menu_button.global_position = get_global_mouse_position()
	menu_button.show_popup()
