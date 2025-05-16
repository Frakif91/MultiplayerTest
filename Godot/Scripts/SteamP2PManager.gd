class_name SteamP2PManager extends Node

var steam_available : bool
var status

func _ready():
    steam_available = Steam.isSteamRunning()

func create_p2p_session():
    pass