###############################################################################
##
## SERVER MESSAGES
## 
## A box with messages to display, mostly, when someone has died
##
extends MarginContainer


@onready var messages_log: VBoxContainer = %MessagesLog

## Displays a message to all players. Sent from the server
@rpc("call_remote")
func create_message(msg: String) -> void:
	var label = Label.new()
	label.text = msg
	label.set("theme_override_colors/font_outline_color", Color.BLACK)
	label.set("theme_override_constants/outline_size", 2)
	messages_log.add_child(label)
	
	await get_tree().create_timer(4.0).timeout
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
