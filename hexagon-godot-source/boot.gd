###############################################################################
##
## BOOT SCRIPT
## 
## Runs when the game launches. Determines which scene to run.
## 
## Servers run the server scene, players run the lobby scene
##
extends Control

const ServerScene = preload("res://server/server.tscn")
const LobbyScene = preload("res://lobby/lobby.tscn")

func _ready():
	# Mockup setup/
	const Flags := preload("res://utils/flags.gd")
	if Flags.is_local():
		print("Switching W4GD to Mock")
		W4GD.set_script(load("res://utils/w4_mock.gd"))

		if Flags.has_window_position():
			get_window().position = Flags.get_window_position()

		if Flags.is_server():
			W4GD.set_process_input(true)
			get_tree().change_scene_to_file("res://server/server.tscn")
		else:
			get_tree().change_scene_to_file("res://lobby/lobby.tscn")

		return
	# /Mockup setup
	if GameState.is_server():
		get_tree().change_scene_to_packed(ServerScene)
	else:
		get_tree().change_scene_to_packed(LobbyScene)
