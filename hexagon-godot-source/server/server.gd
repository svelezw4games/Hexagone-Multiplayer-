###############################################################################
##
## SERVER
## 
## This scene runs when the game is called from W4
##
## We don't need to extend MarginContainer, the server can be any node
extends MarginContainer

func _ready() -> void:
	GameState.host_game()






























