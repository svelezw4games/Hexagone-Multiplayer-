###############################################################################
##
## LOGGING UTILITY
##
## It's not always easy to obtain server logs. This development utility
## duplicates server logs on all connected clients, allowing a local developer
## to observe logs emitted on a distant server.
##
## License: MIT - GDQuest
extends Node

const Flags := preload("res://utils/flags.gd")


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	# we only want to run this on the server
	if not GameState.is_server():
		return
	var timer := Timer.new()
	add_child(timer)
	timer.timeout.connect(_send_log)
	timer.start(1.0)


func _send_log() -> void:
	if FileAccess.file_exists("user://logs/godot.log"):
		var log_file := FileAccess.get_file_as_string("user://logs/godot.log")
		_receive_log.rpc(log_file)


## Called on all connected clients, except the server.
@rpc("call_remote")
func _receive_log(log_file: String) -> void:
	if Flags.is_local():
		return
	if OS.get_name() == "Android": 
		return
	var dir := DirAccess.open("res://")
	dir.make_dir_recursive("res://logs")
	var file := FileAccess.open("res://logs/server.log", FileAccess.WRITE)
	file.store_string(log_file)
	file.close()
