###############################################################################
##
## MOBILE CONTROLS
## 
## Simple on-screen controls that dispatch signals through the project.
## We use those on Android only
## 
extends Control

@export var max_stick_distance = 30.0

var analog_value : Vector2 = Vector2.ZERO :
	get:
		return analog_stick.position / max_stick_distance

@onready var analog_root = %AnalogRoot
@onready var analog_stick = %AnalogStick
@onready var movement_capture = %MovementCapture
@onready var camera_capture = %CameraCapture
@onready var jump_button = %JumpButton

var _camera_controller: CameraController


func setup(camera_controller: CameraController) -> void:
	show()
	_camera_controller = camera_controller
	movement_capture.gui_input.connect(_on_movement_capture_gui_input)
	camera_capture.gui_input.connect(_on_camera_capture_gui_input)
	jump_button.button_down.connect(_on_jump_button_down)
	jump_button.button_up.connect(_on_jump_button_up)
	set_process(true)


func _ready() -> void:
	set_process(false)
	

func _reset_analog_position(pos: Vector2) -> void:
	analog_root.position = pos
	analog_stick.position = Vector2.ZERO

	
func _on_camera_capture_gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenDrag:
		_camera_controller.set_camera_rotation_input(ev.relative.x, ev.relative.y)
	
	
func _on_movement_capture_gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		analog_root.visible = ev.is_pressed()
		_reset_analog_position(ev.position)
	
	if ev is InputEventScreenDrag:
		analog_stick.position = (ev.position - analog_root.position)
		analog_stick.position *= 1.0/analog_root.scale.x
		analog_stick.position = analog_stick.position.limit_length(max_stick_distance)
	
	# TODO: is this necessary?
	get_viewport().set_input_as_handled()


func _on_jump_button_down() -> void:
	var event = InputEventAction.new()
	event.action = "jump"
	event.pressed = true
	Input.parse_input_event(event)


func _on_jump_button_up() -> void:
	var event = InputEventAction.new()
	event.action = "jump"
	event.pressed = false
	Input.parse_input_event(event)

	
func _process(_delta: float) -> void:
	const ACTIONS := ["move_up", "move_down", "move_left", "move_right"]
	const ACTION_DIRECTIONS := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for i in range(4):
		var projected_dir = analog_value.project(ACTION_DIRECTIONS[i])
		if projected_dir.dot(ACTION_DIRECTIONS[i]) > 0:
			var event = InputEventAction.new()
			event.action = ACTIONS[i]
			event.strength = projected_dir.length()
			event.pressed = true
			Input.parse_input_event(event)
		else:
			var event = InputEventAction.new()
			event.action = ACTIONS[i]
			event.strength = 0.0
			event.pressed = false
			Input.parse_input_event(event)
