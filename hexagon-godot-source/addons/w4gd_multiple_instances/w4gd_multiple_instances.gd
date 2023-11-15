@tool
extends EditorPlugin


var menu_button: MenuButton


func _enter_tree() -> void:
	menu_button = MenuButton.new()
	menu_button.icon = load("res://addons/w4gd_multiple_instances/icon.svg")
	menu_button.expand_icon = true
	menu_button.get_popup().add_item("Launch 2 W4 instances", 2)
	menu_button.get_popup().add_item("Launch 3 W4 instances", 3)
	menu_button.get_popup().add_item("Launch 4 W4 instances", 4)
	menu_button.get_popup().id_pressed.connect(func(id):
		for i in range(id):
			OS.create_instance(["--", "--profile=w4_profile_%d" % i])
		)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, menu_button)
	menu_button.custom_minimum_size = Vector2(30,30)


func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, menu_button)
	menu_button.queue_free()
