extends Node3D

#################################### SIGNALS ###################################

## Emitted when Gobot's feet hit the ground will running.
signal foot_step


################################## PROPERTIES ##################################

## Gobot's MeshInstance3D model.
@export var gobot_model: MeshInstance3D

## _state_machine animation current node.
@export var animation_state: String

## Determines whether blinking is enabled or disabled.
@export var blink = true:
	set(state):
		if blink == state:
			return
		blink = state
		if blink:
			_blink_timer.start(0.2)
		else:
			_blink_timer.stop()
			_closed_eyes_timer.stop()

## Left eye material
@export var _left_eye_mat_override: String

## Right eye material
@export var _right_eye_mat_override: String

## Eye texture when open
@export var _open_eye: CompressedTexture2D

## Eye texture when closed
@export var _close_eye: CompressedTexture2D

## Tilts Gobot one side or another
@export var tilt : float = 0.0 :
	set(value):
		tilt = clamp(value, -1.0, 1.0)
		_animation_tree.set("parameters/TiltBlend/blend_position", tilt)

## Used to set animations on the little dude
@export var squash_stretch_ratio : float = 0.0 :
	set(ratio):
		squash_stretch_ratio = clamp(ratio, -1.0, 1.0)
		var r = squash_stretch_ratio
		var xz = 1.0 - r
		var y = 1.0 + r
		var value : Vector3 = Vector3(xz, y, xz)
		scale = value

## Changes the base body color of Gobot
@export var color: Color = Color.CORNFLOWER_BLUE:
	set(value):
		color = value
		var material : StandardMaterial3D = gobot_model.get("surface_material_override/0")
		material.albedo_color = value


################################### ONREADY ####################################

@onready var _previous_animation_state: String = ""
@onready var _animation_tree: AnimationTree = %AnimationTree
@onready var _state_machine: AnimationNodeStateMachinePlayback = _animation_tree.get(
		"parameters/StateMachine/playback"
)

@onready var _flip_shot_path: String = "parameters/FlipShot/request"
@onready var _hurt_shot_path: String = "parameters/HurtShot/request"

@onready var _blink_timer: Timer = %BlinkTimer
@onready var _closed_eyes_timer: Timer = %ClosedEyesTimer

@onready var _left_eye_mat: StandardMaterial3D = gobot_model.get(_left_eye_mat_override)
@onready var _right_eye_mat: StandardMaterial3D = gobot_model.get(_right_eye_mat_override)


################################## BOOTSTRAP ###################################

func _ready():
	_blink_timer.timeout.connect(
		func _on_blink_timer_timeout() -> void:
			_left_eye_mat.albedo_texture = _close_eye
			_right_eye_mat.albedo_texture = _close_eye
			_closed_eyes_timer.start(0.2)
	)

	_closed_eyes_timer.timeout.connect(
		func _on_closed_eyes_timer_timeout() -> void:
			_left_eye_mat.albedo_texture = _open_eye
			_right_eye_mat.albedo_texture = _open_eye
			_blink_timer.start(randf_range(1.0, 8.0))
	)


func _physics_process(_delta: float) -> void:
	if _previous_animation_state != animation_state:
		_state_machine.travel(animation_state)
		_previous_animation_state = animation_state


############################## ANIMATION HELPERS ##############################


## Sets the model to a neutral, action-free state.
func idle():
	animation_state = "Idle"


## Sets the model to a running animation or forward movement.
func run():
	animation_state = "Run"


## Sets the model to an upward-leaping animation, simulating a jump.
func jump():
	animation_state = "Jump"


## Sets the model to a downward animation, imitating a fall.
func fall():
	animation_state = "Fall"


## Sets the model to an edge-grabbing animation.
func edge_grab():
	animation_state = "EdgeGrab"

## Sets the model to a wall-sliding animation.
func wall_slide():
	animation_state = "WallSlide"


## Makes a victory sign.
func victory_sign():
	animation_state = "VictorySign"


## Plays a clapping animation
func clap():
	animation_state = "Clap"


## Plays a one-shot front-flip animation.
## This animation does not use the animation player, so it can played in 
## parallel with other animations.
func flip():
	_animation_tree.set(_flip_shot_path, true)


## Plays a one-shot hurt animation.
## This animation does not use the animation player, so it can played in 
## parallel with other animations.
func hurt():
	_animation_tree.set(_hurt_shot_path, true)
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(1.2, 0.8, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.2)


## Plays a simple squash'n'stretch animation, suitable for jumps and landings.
## This animation does not use the animation player, so it can played in 
## parallel with other animations.
func play_squash_stretch(to := 0.2) -> void:
	var t := create_tween().set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "squash_stretch_ratio", to, 0.2)
	t.tween_property(self, "squash_stretch_ratio", 0.0, 0.2)


