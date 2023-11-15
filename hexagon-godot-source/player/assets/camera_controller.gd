###############################################################################
##
## CAMERA CONTROLLER
## 
## A classical swivel controller for a 3rd person camera.
## 
class_name CameraController
extends Node3D

@export var invert_mouse_y := false
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export_range(0.0, 8.0) var joystick_sensitivity := 2.0
@export var tilt_upper_limit := 0.48
@export var tilt_lower_limit := -0.8

@onready var camera: Camera3D = %Camera3D


var _rotation_input: float
var _tilt_input: float
var _euler_rotation: Vector3


func get_camera_oriented_input(raw_input : Vector2) -> Vector3:
	var input := Vector3(raw_input.x, 0.0, raw_input.y)
	input = camera.global_transform.basis * input
	input.y = 0.0
	return input.normalized() * raw_input.length()


func set_camera_rotation_input(cam_rotation: float, tilt: float) -> void:
	_rotation_input = cam_rotation * mouse_sensitivity
	_tilt_input = tilt * mouse_sensitivity


func _input(event: InputEvent) -> void:
	var active_mouse_input = event is InputEventMouseMotion
	if active_mouse_input:
		set_camera_rotation_input(-event.relative.x, -event.relative.y)


func _process(delta: float) -> void:
	if invert_mouse_y:
		_tilt_input *= -1

	# Rotates camera using euler rotation
	_euler_rotation.x += _tilt_input * delta
	_euler_rotation.x = clamp(_euler_rotation.x, tilt_lower_limit, tilt_upper_limit)
	_euler_rotation.y += _rotation_input * delta

	transform.basis = Basis.from_euler(_euler_rotation)
	camera.rotation.z = 0

	_rotation_input = 0.0
	_tilt_input = 0.0
