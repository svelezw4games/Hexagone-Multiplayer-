###############################################################################
##
## PLAYER AVATAR
## 
## Controls physics and movement. The inputs are handled elsewhere.
## When running locally, the inputs handling node sends inputs to the player 
## directly.
## When running on the network, the inputs handling node sends inputs to the 
## server, and the servers moves the player (the player position is then 
## synchronized to all other players).
## 
class_name PlayerAvatar
extends CharacterBody3D


const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MAX_VELOCITY := 10.0
const GobotSkin := preload("res://player/assets/gobot/gobot_skin.gd")
const LocalPlayerController := preload("res://player/local_player_controller.gd")

signal player_defeated

## The player's id as assigned by the multiplayer implementation. We use this to
## set the authority to the proper nodes
@export var player_peer_id : int :
	set(new_player_peer_id):
		player_peer_id = new_player_peer_id
		(%LocalPlayerSynchronizer as MultiplayerSynchronizer).set_multiplayer_authority(player_peer_id)
		(%LocalPlayerController as LocalPlayerController).set_multiplayer_authority(player_peer_id)

## The player's name, arbitrary and used above the player's head
@export var player_name : String:
	set(new_player_name):
		player_name = new_player_name
		if not is_inside_tree():
			await ready
		(%PlayerName as Label3D).text = player_name

## The player index, which defines the order in which a player was added to the 
## lobby. Is also used to pick a color from the gradient so each player has their
## own color.
@export var player_index : int

#
@onready var _gobot_skin: GobotSkin = %GobotSkin
@onready var _foot_step_audio: AudioStreamPlayer3D = %FootStepAudio
@onready var _ground_impact_audio: AudioStreamPlayer3D = %GroundImpactAudio
@onready var _dust_particles: GPUParticles3D = %DustParticles
@onready var _impact_particles: GPUParticles3D = %ImpactParticles
@onready var _local_player_controller: LocalPlayerController = %LocalPlayerController

## All the available colors for players. Set in the editor, not intended to be
## edited at runtime.
var _player_color_palette : Gradient = preload("assets/players_color_gradient.tres")

## Get the gravity from the project settings so you can sync with rigid body nodes.
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

## Gets set by the LocalPlayerController. Used to provoke an impulse, and gets
## immediately set back to false. Is not expected to be `true` for more than 
## one physics frame.
var _jump_buffer := false

var _angular_velocity : float = 0.0

func _ready() -> void:
	# we only set the physics process to `true` if the current player is the 
	# authority on this node. Otherwise, it will move by syncing it.
	# In a networked setup, this is always the server, who moves all avatars.
	set_physics_process(is_multiplayer_authority())
	
	_gobot_skin.color = _player_color_palette.sample(
		# At the start of the tutorial, GameState has no "players"  property
		# in the final game, the conditional can be removed
		(float(player_index) / GameState.players.size()) if "players" in GameState else 0
	)
	
	_gobot_skin.foot_step.connect(
		func _on_foot_step():
			_foot_step_audio.pitch_scale = randfn(1.0, 0.1)
			_foot_step_audio.play()
	)


## physics only run on the server. The position gets then synced back to all
## players on their local instancest
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Handle Jump. The jump is set on one frame, and then immediately reverted back.
	if _jump_buffer and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_gobot_skin.play_squash_stretch(0.2)
	_jump_buffer = false
	
	# Get the input direction and handle the movement/deceleration.
	# we copy the direction from the _local_player_controller, which is synced by
	# the LocalPlayerSynchronized back to the server
	var direction : Vector3 = _local_player_controller.move_direction
	if direction.is_zero_approx():
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	else:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	
	velocity = velocity.limit_length(MAX_VELOCITY)
	
	var xy_velocity := Vector2(velocity.x, velocity.z)
	
	_dust_particles.emitting = is_on_floor() && xy_velocity.length() > 0.2
	
	if xy_velocity.length() > 0.0:
		var target_direction = Vector2(direction.z, direction.x).normalized()
		var current_direction = Vector2.from_angle(_gobot_skin.rotation.y).normalized()
		_gobot_skin.rotation.y = current_direction.slerp(target_direction, delta * 10.0).angle() 
		
		_angular_velocity += (fposmod(_gobot_skin.rotation.y - target_direction.angle() + PI, PI*2) - PI) * 20.0 * delta
		_angular_velocity = clamp(_angular_velocity, -1.0, 1.0)

	_angular_velocity = move_toward(_angular_velocity, 0.0, delta * 2.0)
	_gobot_skin.tilt = _angular_velocity
	
	var is_on_floor_before_collision = is_on_floor()
	var velocity_before_impact = velocity.length()
	
	move_and_slide()
	
	
	if !is_on_floor_before_collision && is_on_floor():
		var impact_strength = velocity_before_impact / MAX_VELOCITY
		_ground_impact_audio.pitch_scale = randfn(1.0, 0.1)
		_ground_impact_audio.volume_db = impact_strength * 2.0
		_ground_impact_audio.play()
		_gobot_skin.play_squash_stretch(-impact_strength * 0.2)
		_impact_particles.emitting = impact_strength > 0.8
	
	# Animation
	if velocity.y > 0.0:
		_gobot_skin.jump()
	elif velocity.y < 0.0 and not is_on_floor():
		_gobot_skin.fall()
	else:
		if velocity.length() > 0.0:
			_gobot_skin.run()
		else:
			_gobot_skin.idle()
	
	if position.y < -10:
		set_alive.rpc(false)


## Flips the jump buffer for one physics frame
##
## Called from a local PlayerController to the server
@rpc("any_peer", "call_local")
func jump() -> void:
	# Guarantees that the RPC call corresponds to the correct player
	if multiplayer.get_remote_sender_id() != player_peer_id:
		return
	
	_jump_buffer = true


## Called from the player when the player falls, or from the server when all
## other players have fallen.
## 
## Called on all clients and server
@rpc("call_local")
func set_alive(alive: bool) -> void:
	if not alive:
		player_defeated.emit()
		velocity = Vector3.ZERO
	
	visible = alive
	set_physics_process(alive)
	_local_player_controller.death_camera_enabled = not alive


## activates local controls and camera.
##
## Called from the server on each client 
@rpc
func activate_local_controller() -> void:
	_local_player_controller.global_transform.basis = _gobot_skin.global_transform.basis
	_local_player_controller.activate(self)
