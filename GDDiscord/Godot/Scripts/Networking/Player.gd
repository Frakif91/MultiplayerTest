class_name Player extends Resource

enum ConnexionOrigin {GDD, STEAM}
enum PlayerState {DISCONNECTED, CONNECTING, CONNECTED}
enum PlayerGamemode {NORMAL, SPECTATOR, GHOST} # Ghost = unavailable

@export var player_id : int
@export var player_connexion_origin : ConnexionOrigin = ConnexionOrigin.GDD
@export var player_duser : DUser
@export_node_path("Node") var associated_node : NodePath # Usually CharacterBody3D
@export var state : PlayerState = PlayerState.DISCONNECTED

func _init(id : int = -1, duser : DUser = null) -> void:
    self.player_id = id
    self.player_duser = duser

func get_player_name() -> String:
    if player_duser:
        return player_duser.name
    return "Unknown"