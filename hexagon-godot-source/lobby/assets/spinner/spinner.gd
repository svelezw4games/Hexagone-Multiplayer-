@tool
extends HBoxContainer


var _text := "Loading"
@export var text := "Loading" :
	set(v):
		_text = v
		%Label.text = v
	get:
		return _text
