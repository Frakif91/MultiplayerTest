extends CanvasLayer

@export var blurry_node : ColorRect
@export_range(0.01, 20.0, 0.1) var blurry_value : float = 0.1 : set = _set_blurry_value


func _set_blurry_value(value : float):
	blurry_value = value
	if blurry_node:
		(blurry_node.material as ShaderMaterial).set_shader_parameter(&"strength", value)
	else:
		push_warning("Blurry node not found")

func _ready():
	blurry_value = 0

func blurry_start(transition_s : float = 0.5, blurry_max : float = 3.0):
	blurry_value = 0.01
	self.create_tween().tween_property(self, "blurry_value", blurry_max, transition_s).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

func blurry_stop(transition_s : float = 0.5, blurry_max : float = 3.0):
	blurry_value = blurry_max
	self.create_tween().tween_property(self, "blurry_value", 0.01, transition_s).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)