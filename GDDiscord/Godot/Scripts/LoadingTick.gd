#class_name LoadingScreen 
extends Control

enum TransitionType {
	FADE,
}

@export var speed = 100.0
@export var blurry_effect : BlurryEffect
@export var alive_ticker : TextureProgressBar

@export_group("Ping Pong","pingpong_")
@export var pingpong_start_value : float = 0.1
@export var pingpong_end_value : float = 0.9
@export var pingpong_easing : Curve = Curve.new()
@export var pingpong_shift_speed : float = 20.0
@export var pingpong_domain_multiplier : float = 1.0
var cur_pingpong_value : float = 0.0

func _ready():
	blurry_effect.blurry_node.hide()

func change_scene(scene_path: String, transition_type: TransitionType = TransitionType.FADE) -> void:
	blurry_effect.blurry_start(0.5)
	if not FileAccess.file_exists(scene_path):
		return
	
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5).from(Color(0, 0, 0, 0.0)).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	var progress = []
	
	ResourceLoader.load_threaded_request(scene_path)
	var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().create_timer(0.1).timeout
		status = ResourceLoader.load_threaded_get_status(scene_path, progress)
		$CanvasLayer/ColorRect/VBoxContainer/ProgressBar.value = progress[0] * 100.0

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			$CanvasLayer/ColorRect/VBoxContainer/ProgressBar.value = 100
			var new_scene = ResourceLoader.load_threaded_get(scene_path)
			blurry_effect.blurry_stop(0.5)
			get_tree().change_scene_to_packed(new_scene)
		ResourceLoader.THREAD_LOAD_FAILED:
			printerr("Failed to load scene (FAILED): ", scene_path)
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			printerr("Failed to load scene (IN_PROGRESS): ", scene_path)
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			printerr("Failed to load scene (INVALID_RESSOURCE): ", scene_path)
		_:
			printerr("Failed to load scene (UNKNOWN): ", scene_path)


func _process(delta):
	alive_ticker.radial_initial_angle += delta * speed
	
	# Move the next value in a ping pong manner
	cur_pingpong_value += delta * pingpong_shift_speed
	alive_ticker.value = remap(pingpong_easing.sample(pingpong(cur_pingpong_value, 1)), 0, 1, pingpong_start_value, pingpong_end_value) * pingpong_domain_multiplier
