class_name DeathCamera
extends Node3D

@onready var camera = %Camera3D


func present() -> void:
	camera.current = true
	show()


func dismiss() -> void:
	camera.current = false
	hide()
