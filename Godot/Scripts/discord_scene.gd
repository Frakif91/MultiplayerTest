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

enum POPUP_STATUS {POPUP_ACCEPT, POPUP_DECLINED, POPUP_CLOSED}

func _ready() -> void:
    $"PopupPanel".close_requested.connect(_on_popup_close)
    $"PopupPanel/VBoxContainer/HBoxContainer/AddButtonServer".pressed.connect(func(): popup_request_status_changed.emit(POPUP_STATUS.POPUP_ACCEPT); $"PopupPanel".hide())
    $"PopupPanel/VBoxContainer/HBoxContainer/Cancel".pressed.connect(func(): popup_request_status_changed.emit(POPUP_STATUS.POPUP_DECLINED); $"PopupPanel".hide())

func _on_popup_close():
    $"PopupPanel".hide()
    emit_signal("popup_request_status_changed", POPUP_STATUS.POPUP_CLOSED)