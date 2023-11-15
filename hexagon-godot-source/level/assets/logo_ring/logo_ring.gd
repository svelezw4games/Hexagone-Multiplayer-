@tool
extends MeshInstance3D

@export var perimeter = 40.0 : set = _set_perimeter

func _ready():
	_set_perimeter(perimeter)

func _set_perimeter(value : float):
	perimeter = value
	var radius = perimeter / (PI * 2.0)
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	material_override.set_shader_parameter("logo_scale", perimeter / mesh.height / 2.0)
