class_name DAdd_Server extends Window

signal add_server_confirmed(server_name : String, server_ip : String, server_port : int)
signal add_server_error(message : String)

@onready var popup_add: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Popup_Add
@onready var popup_cancel: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Popup_Cancel
@onready var progress_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/ProgressBar

func _ready() -> void:
	progress_bar.hide()
	popup_add.pressed.connect(_on_addserver_pressed.bind(POPUP_STATUS.POPUP_ACCEPT))
	popup_cancel.pressed.connect(_on_addserver_pressed.bind(POPUP_STATUS.POPUP_DECLINED))


enum POPUP_STATUS {POPUP_ACCEPT = 0, POPUP_DECLINED = 1, POPUP_CLOSED = 2}
## Fermeture du popup d'ajout d'un serveur
func _on_addserver_pressed(popup_status : POPUP_STATUS):

	if popup_status == POPUP_STATUS.POPUP_ACCEPT:

		# New pos exemple : server_name = $PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/P_ServerNameE

		var server_name : String = $PanelContainer/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/P_ServerNameE.text
		var server_ip : String = $PanelContainer/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/P_ServerIPE.text
		var server_port = 4044

		match(NetParser.detect_address_type(server_ip)):
			NetParser.AddressType.IP:
				server_ip = server_ip
				server_port = 4044
			NetParser.AddressType.IP_W_PORT:
				var spl = server_ip.split(":")
				server_ip = spl[0]
				server_port = int(spl[1])
			NetParser.AddressType.HOSTNAME:
				progress_bar.show()
				var result = await NetParser.parse_address(server_ip, get_tree())
				progress_bar.hide()
				server_ip = result[0]
				server_port = result[1] # which is 4044
			NetParser.AddressType.HOSTNAME_W_PORT:
				progress_bar.show()
				var result = await NetParser.parse_address(server_ip, get_tree())
				progress_bar.hide()
				server_ip = result[0]
				server_port = result[1]
			NetParser.AddressType.UNKNOWN:
				error_popup_show("Adresse IP incorrecte")
				return
		
		add_server_confirmed.emit(server_name, server_ip, server_port)
		close_requested.emit()


func error_popup_show(message : String):
	add_server_error.emit(message)
