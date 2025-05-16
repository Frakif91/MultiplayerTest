class_name MarioOW_Movement extends CharacterBody3D

signal did_move(velocity : Vector3)

signal start_move()
signal stop_move()

@export var asprite3D : AnimatedSprite3D
@export var sfx_jump : AudioStreamPlayer3D
@export var sfx_foot_left : AudioStreamPlayer3D
@export var sfx_foot_right : AudioStreamPlayer3D
@export var timer : Timer
@export var camera : Camera3D
@export var player_name_tag : Control
@export var player_name_label : Label3D

@export var center_fall_anim_rspeed : float = 0.3
@export var walk_sound_waittime = 12.0/20./2.
@export var max_distance_from_luigi = 0.6
@export var max_distance_margin = 0.1

var cur_right_foot = false
var old_debug_direction = 0.0

const SORTED_DIRECTION = ["N","NE","E","SE","S","SW","W","NW"]

const ACTIONS : Dictionary = {JUMP = &"jump", IDLE = &"idle", WALK = &"walk"}
enum ALTERNATIVE {NORMAL,ALT,ALT2,ALT3}

var state_direction : StringName = &"S"
var state_action : StringName = &"idle"
var on_floor : bool
var just_touched_floor : bool
var jump_alt = 0
var is_moving = false
var can_play_animation = true
var player_name : String : 
	set(value):
		player_name = value
		if player_name_label:
			player_name_label.text = value
			player_name_label.text = value
			$Label3D.text = value
		else:
			set_deferred(&"player_name",value)

signal touched_floor

@export var SPEED = 5.0
@export var JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func walk_sound():
	if cur_right_foot:
		sfx_foot_right.play()
	else:
		sfx_foot_left.play()
	cur_right_foot = not cur_right_foot
	timer.start(walk_sound_waittime)

func _ready():
	if name.is_valid_int():
		set_multiplayer_authority(int(name))
		print("This Player ID is ",name)
		if multiplayer.multiplayer_peer and is_multiplayer_authority():
			$Camera3D.current = true
	timer.timeout.connect(walk_sound)
	timer.autostart = false
	timer.one_shot = true
	stop_move.connect(timer.stop)
	start_move.connect(func(): timer.start(walk_sound_waittime/2))
	#timer.start(walk_sound_waittime)
	#timer.stop()

func animation_process():
	get_action_and_direction(Vector2(velocity.x,velocity.z))

	if just_touched_floor:
		play_animation(ACTIONS.JUMP,state_direction,&"2")
		can_play_animation = false
		#await asprite3D.animation_finished
		can_play_animation = true
	elif state_action == ACTIONS.WALK:
		play_animation(state_action,state_direction,&"")
		#timer.start()
	elif state_action == ACTIONS.IDLE:
		play_animation(state_action,state_direction,&"0")
		cur_right_foot = true
		#timer.stop()
	elif state_action == ACTIONS.JUMP:
		play_animation(state_action,state_direction,str(jump_alt))

func _process(_delta):
	if can_play_animation and ((multiplayer.has_multiplayer_peer() and is_multiplayer_authority()) or not multiplayer.has_multiplayer_peer()):
		await animation_process()

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	if timer.time_left > 0:
		if not is_on_floor():
			timer.paused = true
		else:
			if timer.paused:
				timer.paused = false
				timer.start(walk_sound_waittime/2)

	# Handle jump.
	if Input.is_action_just_pressed(&"Jump") and is_on_floor() and is_multiplayer_authority():
		velocity.y = JUMP_VELOCITY
		sfx_jump.play()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	if multiplayer.multiplayer_peer != null and is_multiplayer_authority():
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			#did_move.emit(velocity)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			if is_moving:
				is_moving = false
				stop_move.emit()

	move_and_slide()

	camera = get_viewport().get_camera_3d()
	if not camera.is_position_behind(global_position):
		var label_pos = camera.unproject_position(global_position)
		player_name_tag.visible = true
		player_name_tag.global_position = label_pos + Vector2(0,-50)
	else:
		player_name_tag.visible = false



	if velocity.x or velocity.z:
		did_move.emit(global_position)
		if not is_moving:
			is_moving = true
			start_move.emit()

	just_touched_floor = false
	if on_floor != is_on_floor():
		on_floor = not on_floor
		if on_floor:
			touched_floor.emit()
			just_touched_floor = true
	
	if not is_on_floor():
		if velocity.y > center_fall_anim_rspeed:
			jump_alt = ALTERNATIVE.NORMAL
		elif velocity.y <= center_fall_anim_rspeed and velocity.y >= -center_fall_anim_rspeed: # -0.2 < velocity.y < 0.1
			jump_alt = ALTERNATIVE.ALT
		elif velocity.y < -center_fall_anim_rspeed:
			jump_alt = ALTERNATIVE.ALT2
			
		if just_touched_floor:
			jump_alt = ALTERNATIVE.ALT3
		
var direction_angle = 0
func get_action_and_direction(cur_direction : Vector2):

	if cur_direction != Vector2.ZERO:
		direction_angle = (cur_direction.angle())

	if not cur_direction and is_on_floor(): #NO DIRECTION
		state_action = ACTIONS.IDLE
		return

	elif cur_direction and is_on_floor():
		state_action = ACTIONS.WALK
	elif not is_on_floor():
		state_action = ACTIONS.JUMP

	var max_angles = SORTED_DIRECTION.size()
	@warning_ignore("integer_division")
	var each_index = (2*PI)/max_angles
	@warning_ignore("integer_division")
	state_direction = SORTED_DIRECTION[roundi((direction_angle/each_index) + 2) % max_angles]
	#print("action: ",state_action," direction: ",state_direction, " selected result : ", (direction_angle), " with vector : ", cur_direction)


func play_animation(action : StringName, _direction : StringName, _animation_alt : StringName):
	var does_have_alt : bool = false
	var does_have_direction : bool = false
	
	if not _animation_alt.is_empty():
		does_have_alt = true
	
	if not _direction.is_empty():
		does_have_direction = true
	
	var composed_animation_name : String

	if does_have_direction and does_have_alt:
		composed_animation_name = "-".join(PackedStringArray([action,_direction,_animation_alt]))
	elif does_have_direction and not does_have_alt:
		composed_animation_name = "-".join(PackedStringArray([action,_direction]))
	else:
		composed_animation_name = action
	
	if asprite3D.animation != composed_animation_name:
		var old_frame = asprite3D.frame
		@warning_ignore("unused_variable")
		var old_progress = asprite3D.frame_progress
		asprite3D.play(StringName(composed_animation_name))
		if composed_animation_name.begins_with("walk") and asprite3D.animation.begins_with("walk"):
			asprite3D.set_frame_and_progress(old_frame,1)
			
	
