###############################################################################
##
## MULTIPLAYER LEVEL
## 
## - Places all players
## - Displays messages when people have left
##
extends Level

const ServerMessages := preload("server_messages.gd")

@onready var multiplayer_spawner: MultiplayerSpawner = %MultiplayerSpawner
@onready var server_messages: ServerMessages = %ServerMessages

var _alive_player_avatars := {}


func _ready():
	## _ready is a no-op if we're not running on a server
	if GameState.is_server():

		GameState.player_left.connect(
			func _on_player_left(peer_id: int) -> void:
				for alive_player in _alive_player_avatars.keys():
					if alive_player.player_peer_id == peer_id:
						alive_player.set_alive.rpc(false)
						break
				server_messages.create_message.rpc("Player %s exited the match." % GameState.players[peer_id])
		)
		
		randomize()
		_populate_layers()

		if not GameState.are_all_players_ready():
			await GameState.all_players_ready
		_start_match()


## Places all players, and starts the match.
##
## This only runs from the server
func _start_match():
	var players_ready = GameState._players_ready
	var total_players = players_ready.size()
	var i = 0

	_alive_player_avatars = {}

	for peer_id in players_ready:
		var player := _place_player(GameState.players[peer_id], i * 2.0 * PI / total_players)
		player.player_peer_id = peer_id
		player.player_index = i
		_alive_player_avatars[player] = true
		
		player.player_defeated.connect(func():
			_alive_player_avatars.erase(player)
			var alive_players_count = _alive_player_avatars.keys().size()
			if alive_players_count == 1 || alive_players_count == 0:
				var winner_avatar = player
				if alive_players_count == 1:
					winner_avatar = _alive_player_avatars.keys()[0]
				winner_avatar.set_physics_process(false)
				GameState.show_victory_screen.rpc(winner_avatar.player_name, winner_avatar.player_index)
				await get_tree().create_timer(3.0).timeout
				GameState.close_game()
		)
		add_child(player, true)
		player.set_physics_process(false)
		player.activate_local_controller.rpc_id(peer_id)
		i += 1
	
	await get_tree().create_timer(3.2).timeout
	
	for player in _alive_player_avatars.keys():
		player.set_physics_process(true)
