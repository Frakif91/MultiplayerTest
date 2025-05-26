class_name DiscordMenu extends Control

@onready var server_list : ItemList = %ServerList
@onready var server_info : RichTextLabel = %ServerInfo
@onready var channel_name : Label = %ChannelName
#@onready var channel_info : RichTextLabel = null
@onready var join_button : Button = %JoinButton
@onready var refresh_button : Button = %RefreshButton
@onready var guild_list : ItemList = %GuildList
@onready var channel_chat : VBoxContainer = %ChannelChat
@onready var chat_input : LineEdit = %ChatInput
