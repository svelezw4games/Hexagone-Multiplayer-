extends Node3D

@onready var gobot_skin = preload("res://player/assets/gobot/gobot_skin.tscn")
@onready var pillar_scene = preload("./pillar.tscn")

var _gobots_refs = []

func set_players(colors : Array):
	var player_count = colors.size()
	_gobots_refs = []
	for child in get_children():
		child.queue_free()

	var per_lines : int = 5

	var circles_count = ceil(player_count / float(per_lines))

	var circles = []
	circles.resize(circles_count)
	circles.fill(per_lines)
	var mod = player_count % (per_lines)
	if mod != 0: circles[-1] = mod

	if circles.size() > 1 && circles[-1] == 1:
		circles.resize(circles_count - 1)
		circles[-1] += 1

	var circles_colors = []
	circles_colors.resize(circles_count)

	var previous_slice : int = 0

	for i in circles.size():
		circles_colors[i] = colors.slice(previous_slice, previous_slice + circles[i])
		previous_slice += circles[i]

	for circle_index in circles.size():
		var count = circles[circle_index]
		for player_index in count:
			var height = circle_index * 0.5
			var radius = 3.0 + circle_index * 1.5
			var percent = player_index / float(max(1, count - 1))
			var o = circle_index / float(max(1, circles.size() - 1)) * 0.1
			var angle = remap(percent, 0.0, 1.0, 0.1 + o, 0.9 - o) * -PI
			var p = Vector3(cos(angle) * radius, height, sin(angle) * radius)
			var gobot = gobot_skin.instantiate()
			gobot.position = p
			add_child(gobot)
			_gobots_refs.append(gobot)
			gobot.rotation.y = Vector2(p.z, p.x).normalized().angle() - PI
			gobot.color = circles_colors[circle_index][player_index]
			var pillar = pillar_scene.instantiate()
			pillar.position = p
			add_child(pillar)

func everyone_clap():
	for gobot in _gobots_refs: gobot.clap()
