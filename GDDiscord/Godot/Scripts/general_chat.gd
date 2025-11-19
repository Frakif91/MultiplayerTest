class_name DChat extends MarginContainer

const MAX_MESSAGE_LENGTH = 512
const message_inst_scene = preload("res://GDDiscord/Godot/Scenes/DiscordChatMessage.tscn")

@onready var channel_title: Label = %ChannelTitle
@onready var channel_chat: VBoxContainer = %ChannelChat
@onready var chat_input: LineEdit = %ChatInput
@onready var send: TextureButton = $ChannelElements/UserInput/Send

func _ready():
    chat_input.text_submitted.connect(_on_chat_submit)
    send.pressed.connect(_on_chat_submit.bind(chat_input.text))
    Steam.lobby_message.connect(_on_chat_received)


func _process(delta):
    pass

func _on_chat_submit(new_text : String):
    print_debug("[GeneralChat] Sending chat message : ", new_text)
    if new_text.length() > MAX_MESSAGE_LENGTH:
        new_text = new_text.substr(0, MAX_MESSAGE_LENGTH)
    chat_input.text = ""
    if SteamManager.lobby_id != 0 and Steam.isLobby(SteamManager.lobby_id):
        print_debug("[GeneralChat] Message sent.")
        Steam.sendLobbyChatMsg(SteamManager.lobby_id, new_text)
    elif SteamManager.lobby_id <= 0:
        print_debug("[GeneralChat] No lobby selected.")
    else:
        print_debug("[GeneralChat] Invalid lobby id (From SteamWorks) : ", SteamManager.lobby_id)

func _on_chat_received(lobby_id: int, user: int, message: String, chat_type: int):
    print_debug("[GeneralChat] Received chat message from %s : %s" % [user, message])
    if lobby_id != SteamManager.lobby_id:
        return

    var steam_profile : DUser = await Networking.get_duser_from_steamid(user)

    var message_inst : DMessage = message_inst_scene.instantiate()
    message_inst.author = user
    message_inst.content = message
    message_inst.icon = steam_profile.icon
    message_inst.timestamp = Time.get_unix_time_from_system()

    message_inst.update()

    channel_chat.add_child(message_inst)