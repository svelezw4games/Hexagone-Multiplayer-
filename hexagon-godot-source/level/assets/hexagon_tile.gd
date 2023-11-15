@tool
extends StaticBody3D

@onready var area := %Area3D
@onready var _falling = false
@onready var hexagon_mesh = %HexagonMesh
@onready var activation_audio = %ActivationAudio
@onready var delete_sound = %DeleteSound
@onready var collision_shape_3d = %CollisionShape3D
@onready var trigger_particles = %TriggerParticles

@export var color : Color
@export var light_color : Color

func _ready():
	if is_multiplayer_authority():
		area.body_entered.connect(_on_body_entered)

	if is_inside_tree():
		hexagon_mesh.material_override.set_shader_parameter("base_color", color)
		hexagon_mesh.material_override.set_shader_parameter("light_color", light_color)
		
func _on_body_entered(body) -> void:
	if body == self or _falling:
		return

	_fall.rpc()


@rpc("call_local")
func _fall():
	_falling = true
	
	activation_audio.pitch_scale = randfn(1.0, 0.15)
	activation_audio.play()
	
	trigger_particles.emitting = true
	var particles_timer = get_tree().create_timer(trigger_particles.lifetime)
	particles_timer.connect("timeout", trigger_particles.queue_free)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(hexagon_mesh, "position:y", hexagon_mesh.position.y - 0.08, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(hexagon_mesh.material_override, "shader_parameter/emission_intensity", 1.2, 0.4)
	tween.tween_property(self, "position:y", position.y - 0.5, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.8)
	tween.tween_callback(func(): 
		collision_shape_3d.disabled = true
		delete_sound.pitch_scale = randfn(1.0, 0.15)
		delete_sound.play()
		).set_delay(0.8)
	tween.tween_property(hexagon_mesh, "scale", Vector3(0.0, 1.0, 0.0), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_delay(0.8)
	tween.tween_property(hexagon_mesh, "transparency", 1.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_delay(1.0)
	
	if is_multiplayer_authority():
		tween.chain().tween_callback(queue_free).set_delay(0.8)
