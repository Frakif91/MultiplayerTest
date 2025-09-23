class_name ServerImageSelector extends Window

@onready var import_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/ImportButton
@onready var select_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/SelectButton
@onready var image_list: ItemList = $MarginContainer/VBoxContainer/PanelContainer/ImageList
@onready var file_dialog: FileDialog = $FileDialog

signal image_selected(tex : Texture)

var cur_image : Texture2D = null


func _ready() -> void:
	import_button.pressed.connect(_on_import_button_pressed)
	image_list.item_selected.connect(_on_item_selected)
	file_dialog.file_selected.connect(_on_file_selected)
	select_button.disabled = true

	if get_tree().current_scene == self:
		await get_tree().create_timer(0.1).timeout
		self.popup_centered()


func _on_item_selected(index : int) -> void:
	select_button.disabled = not image_list.is_anything_selected()
	cur_image = image_list.get_item_icon(index)

func _on_import_button_pressed() -> void:
	file_dialog.popup_centered()
	

func _on_file_selected(path : String) -> void:
	var image : Texture
	if path.begins_with("res://"):
		image = load(path)
	else:
		image = ImageTexture.create_from_image(Image.load_from_file(path))
	var item = image_list.add_icon_item(image)
	image_list.set_item_text(item, path.get_slice("/", -1) if path.begins_with("res://") else path.get_file())
	image_list.select(item)

func _on_select_button_pressed():
	if cur_image != null:

		# Resize image to 48x48
		var resized_image = cur_image.get_image().duplicate()
		resized_image.resize(48, 48, Image.INTERPOLATE_LANCZOS)
		resized_image.clear_mipmaps()
		var cur_resized_image = ImageTexture.create_from_image(resized_image)
		image_selected.emit(cur_resized_image)
		hide()
