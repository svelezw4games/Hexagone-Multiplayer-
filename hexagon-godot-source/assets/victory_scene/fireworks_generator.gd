extends Node3D

@onready var firework_holder = %FireworkHolder
@onready var timer = %Timer

var firework_scene = preload("./fireworks/firework.tscn")

func _ready():
	timer.connect("timeout", _on_timer_timeout)
	
func _on_timer_timeout():
	timer.start(randf_range(0.2, 0.8))
	if firework_holder.get_child_count() >= 8: return
	var firework = firework_scene.instantiate()
	firework_holder.add_child(firework)
	firework.position = Vector3(randfn(0.0, 4.0), randf() * 4.0, randfn(0.0, 2.0))
