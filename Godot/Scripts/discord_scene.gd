class_name DiscordMenu extends Control

signal popup_request_status_changed(status : POPUP_STATUS)

@onready var server_list : ItemList = %ServerList
@onready var server_info : RichTextLabel = %ServerInfo
@onready var channel_name : Label = %ChannelName
#@onready var channel_info : RichTextLabel = null
@onready var join_button : Button = %JoinButton
@onready var refresh_button : Button = %RefreshButton
@onready var guild_list : ItemList = %GuildList
@onready var channel_chat : VBoxContainer = %ChannelChat
@onready var chat_input : LineEdit = %ChatInput

enum POPUP_STATUS {POPUP_ACCEPT = 0, POPUP_DECLINED = 1, POPUP_CLOSED = 2}

func _ready() -> void:
	$"PopupPanel".close_requested.connect(_on_popup_close.bind(POPUP_STATUS.POPUP_CLOSED))
	$"PopupPanel/VBoxContainer/HBoxContainer/Popup_Add".pressed.connect(_on_popup_close.bind(POPUP_STATUS.POPUP_ACCEPT))
	$"PopupPanel/VBoxContainer/HBoxContainer/Popup_Cancel".pressed.connect(_on_popup_close.bind(POPUP_STATUS.POPUP_DECLINED))

	%AddButton.pressed.connect(_on_popup_show)

func _on_popup_close(popup_status : POPUP_STATUS):

	if popup_status == POPUP_STATUS.POPUP_ACCEPT:
		var server_name : String = $PopupPanel/VBoxContainer/MarginContainer/VBoxContainer/P_ServerNameE.text
		var server_ip : String = $PopupPanel/VBoxContainer/MarginContainer/VBoxContainer/P_ServerIPE.text
		var server_port : String = $PopupPanel/VBoxContainer/MarginContainer/VBoxContainer/P_ServerPortE.text

		if server_ip.is_valid_ip_address() and server_port.is_valid_int():
			var index = %ServerList.add_item(server_name, preload("res://icon.svg"), false)
			%ServerList.set_item_metadata(index, {"server_name" : server_name, "server_ip" : server_ip, "server_port" : int(server_port)})
			%ServerList.set_item_tooltip(index, server_ip + ":" + server_port)
			%ServerList.set_item_auto_translate_mode(index, Node.AUTO_TRANSLATE_MODE_DISABLED)
		else:
			print_debug("Invalid IP or Port ", server_name, " : S_IP - ", server_ip.is_valid_ip_address(), " - S_Port - ", server_port.is_valid_int())


	$"CanvasLayer/ColorRect".show()
	$"PopupPanel".hide()
	$"CanvasLayer".blurry_stop(0.5)
	get_tree().create_timer(0.5).timeout.connect($"CanvasLayer/ColorRect".hide)

func _on_popup_show():
	$"PopupPanel".show()
	$"CanvasLayer/ColorRect".show()
	$"CanvasLayer".blurry_start(0.5)


func _on_server_info_meta_clicked(meta: Variant) -> void:
	var nmeta : String = meta as String
	var urlRegex = RegEx.new()
	urlRegex.compile('^(http|https)://[^ "]+$')
	var result = urlRegex.search(nmeta)
		
	if result:
		OS.shell_open(result.get_string())
		return


func _on_server_list_server_double_clicked(index: int) -> void:
	pass # Replace with function body.


func _on_server_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	var server_info : Dictionary = server_list.get_item_metadata(index)
	

	## If the server isn't in the list of available servers, Ask the server's information
	if server_info.has("server_ip") and not Networking.server_responses.has(server_info["server_ip"]):
		%ServerInfo.set_text("[color=dark_gray] Server is being interrogated... [/color]")
		var status = await Networking.ask_availability(server_info["server_ip"], server_info["server_port"])
		if status == ERR_UNAVAILABLE:
			%ServerInfo.set_text("[color=dark_gray] Server is not available. [/color]")
			return
		if Networking.server_responses.has(server_info["server_ip"]):
			server_info.merge(Networking.server_responses[server_info["server_ip"]])
			server_list.set_item_metadata(index, server_info)
			server_list.set_item_custom_fg_color(index, Color(0.2, 8.0, 0.2))
			server_list.set_item_disabled(index, false)
	
	%ServerInfo.clear()
	for key in server_info:
		#%ServerInfo.push_bold()
		%ServerInfo.append_text("[b]" +key + " :[/b] ")
		%ServerInfo.append_text(str(server_info[key]))
		%ServerInfo.newline()


func _on_server_list_empty_clicked(at_position: Vector2, mouse_button_index: int) -> void:
	%ServerInfo.set_text("[color=dark_gray] No server info to display.\nOr nothing selected [/color]")
