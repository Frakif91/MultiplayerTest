## Global scirpt, contains global function and properties to share accross the project
extends Node

func wait(seconds : float) -> void:
    await get_tree().create_timer(seconds).timeout

func next_frame() -> void:
    await get_tree().process_frame

class PlayerInfo extends Object:
    var name : String
    var player