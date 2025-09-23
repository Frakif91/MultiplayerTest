class_name Player extends Resource

enum ConnexionOrigin {GDD, STEAM}

@export var player_name : String
@export var player_id : int
@export var player_connexion_origin : ConnexionOrigin = ConnexionOrigin.GDD
@export var player_avatar : Texture = preload("res://GDDiscord/icon.svg")
@export var player_color : Color
@export var player_data : Dictionary
@export_node_path("Node") var associated_node : NodePath # Usually CharacterBody3D

func _init(name : String = "Unknown", id : int = -1) -> void:
    self.player_name = name
    self.player_id = id
    self.player_connexion_origin = ConnexionOrigin.GDD
    self.player_avatar = preload("res://GDDiscord/icon.svg")
    self.player_color = Color(1,1,1)
    self.player_data = {}

func _init_player_with_duser(duser : DUser) -> Player:
    var ply = Player.new()
    ply.player_name = duser.name
    ply.player_id = duser.peer_id
    ply.player_connexion_origin = (ConnexionOrigin.GDD if not duser._is_steam_user else ConnexionOrigin.STEAM)
    ply.player_avatar = duser.avatar
    ply.player_color = duser.color
    return ply