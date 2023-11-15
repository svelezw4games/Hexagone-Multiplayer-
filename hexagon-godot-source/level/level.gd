###############################################################################
##
## LEVEL
## 
## - Sets the hexagonal tiles
## - Places a character
## - Controls losing (when touching the bottom layer)
##
class_name Level extends Node

const PLAYER_AVATAR_SCENE := preload("res://player/player_avatar.tscn")
const HEXAGON_TILE_SCENE := preload("res://level/assets/hexagon_tile.tscn")
const ARENA_SIZE := 6
const TILE_DISTANCE := 1.5
const LAYER_COUNT := 3
const LAYER_HEIGHT := 8.0


@export var layers_color_gradient : Gradient


func _ready():
	_populate_layers()
	var player := _place_player("LocalPlayer", 0)
	add_child(player, true)
	player.player_peer_id = multiplayer.get_unique_id()
	player.activate_local_controller()


## Adds a single player to the stage and rotates them towards the center
func _place_player(player_name: String, rotation_y: float) -> PlayerAvatar:
	var player := PLAYER_AVATAR_SCENE.instantiate() as PlayerAvatar
	
	player.position = Vector3(0, 2 +   LAYER_HEIGHT * (LAYER_COUNT - 1), 7.5).rotated(Vector3.UP, rotation_y)
	player.get_node("GobotSkin").rotate_y(PI + rotation_y)
	
	player.player_name = player_name 
	return player
 

## Creates tiles for all layers
func _populate_layers() -> void:
	
	# First we calculate all the tiles positions that we'll reuse on each floor/layer
	var tile_positions: PackedVector3Array = []

	for x in range(-ARENA_SIZE+1, ARENA_SIZE):
		for y in range(-ARENA_SIZE+1, ARENA_SIZE):
			var z := -x-y
			if abs(z) > ARENA_SIZE-1:
				continue

			var x_pos := 1.73205 * TILE_DISTANCE * ((z * 0.5) + x)
			var z_pos := 1.5 * TILE_DISTANCE * z
			var pos := Vector3(x_pos, 0.0, z_pos)

			tile_positions.append(pos)

	# We create a color index
	var start_index = randf_range(0, layers_color_gradient.colors.size() - 1)
	var start_color = layers_color_gradient.get_color(start_index)
	var end_color = layers_color_gradient.get_color(start_index + 1)
	
	# Finally we create layers/floors
	for layer_index in LAYER_COUNT:
		var layer_percent := layer_index / float(LAYER_COUNT - 1)
		var layer_color: Color = lerp(start_color, end_color, layer_percent).lightened(0.15)
		var layer_light_color: Color = lerp(start_color, end_color, layer_percent)
		layer_light_color = Color.from_hsv(wrapf(layer_light_color.h + 0.4, 0.0, 1.0), layer_light_color.s, layer_light_color.v)
 
		for pos in tile_positions:
			var tile := HEXAGON_TILE_SCENE.instantiate()
			pos.y = LAYER_HEIGHT * layer_index
			tile.position = pos
			tile.color = layer_color
			tile.light_color = layer_light_color
			add_child(tile, true)

