@tool
extends CollisionShape3D

@export var radius = 0.5 : set = _set_radius
@export var depth = 0.5 : set = _set_depth

func _ready():
	_set_hexagon(false)

func _set_radius(value : float):
	radius = value
	if !is_inside_tree(): return
	_set_hexagon()

func _set_depth(value : float):
	depth = value
	if !is_inside_tree(): return
	_set_hexagon()

func _set_hexagon(override : bool = true):
	if shape == null || !(shape is ConvexPolygonShape3D):
		shape = ConvexPolygonShape3D.new()
	if shape.points.is_empty() || override:
		shape.points = get_hexagon_shape()
	
func get_hexagon_shape():
	var points = []
	var count = 6
	var depth_vector = Vector3(0.0, depth, 0.0)
	for i in count:
		var angle = i / float(count) * TAU + PI / 2.0
		var p = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		points.append(p - depth_vector)
		points.append(p + depth_vector)
	return points
