class_name DServer extends Resource

@export var name : String = ""
@export var ip : String = ""
@export var port : int = 0
@export var server_id : int = 0
@export var found_via_steam := false

@export var max_players : int
@export var cur_players : int
@export var server_motd : String
@export var server_ping : int
@export var icon : Texture = preload("res://GDDiscord/icon.svg")

var server_confirmed := false
var server_data : Dictionary = {}
var server_icon_data : Image

func dserver_to_data(dserv : DServer):
    return {
        "status" : "UNKNOWN",
        "server_name" : dserv.name,
        "server_motd" : dserv.server_motd,
        "server_password" : dserv.server_password,
        "server_port" : dserv.server_port,
        "server_enet_port" : dserv.server_enet_port,
        "server_has_password" : dserv.server_has_password,
        "max_players" : dserv.max_players,
        "server_map" : dserv.server_map,
        "server_scene" : dserv.server_scene,
        "server_use_steam" : dserv.server_use_steam,
        "server_public_ip" : dserv.server_public_ip,
        "server_public_port" : dserv.server_public_port
    }
# Data is server_info of course
func data_to_dserver(data : Dictionary):
    var dserv = DServer.new()

    dserv.name = data["server_name"]
    dserv.server_motd = data["server_motd"]
    dserv.server_password = data["server_password"]
    dserv.server_port = data["server_port"]
    dserv.server_enet_port = data["server_enet_port"]
    dserv.server_has_password = data["server_has_password"]
    dserv.max_players = data["max_players"]
    dserv.server_map = data["server_map"]
    dserv.server_scene = data["server_scene"]
    dserv.server_use_steam = data["server_use_steam"]
    dserv.server_public_ip = data["server_public_ip"]
    dserv.server_public_port = data["server_public_port"]

    return dserv

