###############################################################################
##
## PLAYER CONTROLLER
## 
## This Scene and script have two main functions:
## 
## 1. instanciate nodes that should exist for the local player only, such as:
##    - Local Camera (the one that the player controls)
##    - Death Camera (the one that rotates around the stage when the player dies)
##    - Countdown
##    - Potentially other player-specific controls such as mobile controls
## 2. capturing inputs
##    - the inputs modify a value `move_direction`, which then gets synchronized
##      to all players.
## 
extends Node3D

@onready var camera_controller: CameraController = %CameraController
@onready var camera_3d: Camera3D = %Camera3D
@onready var death_camera_controller: Node3D = %DeathCameraController
@onready var death_camera_3d: Camera3D = %DeathCamera3D
@export var move_direction := Vector3.ZERO


## When this is `true`, the main camera gets disabled, and this floating,
## rotating camera becomes the enabled one.
var death_camera_enabled := false:
	set(enabled):
		death_camera_enabled = enabled
		if enabled:
			death_camera_3d.current = true
			death_camera_controller.show()
		else:
			death_camera_3d.current = false
			death_camera_controller.hide()


## We need this to call the jump rpc function
var _player_avatar: PlayerAvatar


func _physics_process(_delta: float) -> void:
	# The physics process is only called when the current running game has authority
	# In our setup, each player has authority over their own player controller.
	# This is guaranteed inside the player_avatar script, which gives authority
	# to a provided `player_peer_id`.
	#
	# In case no multiplayer peer is set, then this is running locally, in which
	# case we also want to exit and do nothing
	if multiplayer.multiplayer_peer == null or not is_multiplayer_authority():
		return
	
	# avoir errors while not ready
	if not _player_avatar or not is_instance_valid(_player_avatar):
		return

	# we cannot synchronize a variable that is on for one frame, so we do an RPC
	# call for this.
	if Input.is_action_just_pressed("jump"):
		_player_avatar.jump.rpc()

	# The input will set a direction; this direction gets synchronized from all
	# clients to the server; the server then moves the avatars.
	# If a player was to cheat and provide a direction that is not normalized,
	# the server could easily check that direction for valid values.
	var raw_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_direction = camera_controller.get_camera_oriented_input(raw_input)


## Mouse handling
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.is_pressed():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## This is called by the player avatar to make the camera active and enable controls
func activate(player_avatar: PlayerAvatar) -> void:
	_player_avatar = player_avatar
	
	# We cannot count on the signal being there because at the start of the tutorial,
	# GameState is empty. This can be removed in the final game
	if GameState.has_signal("game_round_won"):
		GameState.game_round_won.connect(
			func _on_game_round_won() -> void:
				var finish_scene := preload("assets/level_finish.tscn").instantiate()
				add_child(finish_scene)
		)
	
	death_camera_controller.global_position = Vector3.ZERO
	camera_3d.current = true
	
	# mobile setup/
	var os_name := OS.get_name()
	var is_mobile = os_name == "Android" or os_name == "iOS"
	if is_mobile:
		var mobile_controls := preload("assets/mobile_controls/mobile_controls.tscn").instantiate()
		add_child(mobile_controls)
		mobile_controls.setup(camera_controller)
	set_process_input(not is_mobile)
	camera_controller.set_process_input(not is_mobile)
	# /mobile setup
	
