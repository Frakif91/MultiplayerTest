class_name DMessage extends Control

var author : int # Peer ID

var content : String # BBCode formatted
var timestamp : int # Unix timestamp
var icon : ImageTexture

@export var image : TextureRect
@export var name_label : Label
@export var message_label : Label


func _init(author : int = 0, content : String = "", timestamp : int = 0):
    self.author = author
    self.content = content
    self.timestamp = timestamp

func update():
    name_label.text = str(author)
    message_label.text = content
    image.texture = icon


func get_formated_timestamp() -> String:
    return Time.get_date_string_from_unix_time(timestamp)