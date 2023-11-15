extends Node3D

@onready var body = %Body
@onready var sparks = %Sparks

@export var gradient : Gradient

func _ready():
	var color = gradient.sample(randf())
	body.process_material.set("color", color)
	sparks.process_material.set("color", color)
	body.amount = randi_range(8, 16)
	body.emitting = true
	body.one_shot = true
	scale = Vector3.ONE * randf_range(0.8, 1.2)
	await get_tree().create_timer(body.lifetime * 1.2).timeout
	queue_free()
