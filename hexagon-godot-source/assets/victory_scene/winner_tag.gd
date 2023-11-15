extends Control

@onready var winner_name = %WinnerName
@onready var animation_player = %AnimationPlayer

func setup(n : String):
	winner_name.text = n
	animation_player.play("enter")
