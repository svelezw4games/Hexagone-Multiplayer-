###############################################################################
##
## Game State Autoloads
##
## This serves as a global proxy for network state and modes of play.
##
## In many cases, the functions are a simplified version of what W4 already
## offers, and therefore some people may make the choice of reducing this proxy
## autoload a lot and using W4 directly.
##
## Both approaches are fine, but we believe this proxy clarifies intent by
## reducing possibilities.
##
extends Node


# For testing only/
const Flags := preload("res://utils/flags.gd")
# /For testing only

const DatabaseManager := preload("res://data/database_manager.gd")

const W4Lobby := preload("res://addons/w4gd/matchmaker/matchmaker.gd").Lobby
const W4Player := preload("res://addons/w4gd/game_server/game_server_sdk.gd").Player
const W4ServerTicket := preload("res://addons/w4gd/matchmaker/matchmaker.gd").ServerTicket


## Default game server port. Can be any number between 1024 and 49151.
## Not on the list of registered or common ports as of November 2020:
## https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
const DEFAULT_PORT := 10567

## Max number of players. This is an arbitrary number.
const MAX_PEERS := 12

## emitted when a player joins or leaves
signal player_list_changed()

## emitted when a game is starting
signal started_joining_server()

## Stores player peer ids for player who are ready to play (connected to the lobby)
var _players_ready: Array[int]= []

## The current lobby a player has either created or joined
var _lobby: W4Lobby = null

## If there was an error in the last operation, it will be saved here
var last_error := ""

## Is true if there was an error in the last operation
var has_error := false:
	set(_value):
		push_error("GameState.has_error is a read-only property")
		assert(false, "has_error is a read only property")
	get:
		return last_error != ""


## Names for remote players in [peer_id: player_name] format.
var players := {}


# Signals to let lobby GUI know what's going on.

## Could not connect
signal connection_failed()
## Connected
signal connection_succeeded()
## Match was won by someone
signal game_round_won()
## Match victory scene played and finished playing
signal game_closed()
## There was an error
signal game_error(what: String)
## All lobby players have responded
signal all_players_ready()
## A player left or got disconnected
signal player_left(peer_id: int)


############################ BOOSTRAPPING ######################################


func _ready() -> void:
	
	# For testing only/
	# grabs a profile id from the command line flags
	if Flags.get_profile() != "":
		ProfileData.PROFILE_NAME = Flags.get_profile()
	if Flags.is_local():
		# if we bootstrap too early, we don't give time for the W4Mock to 
		# replace the original
		await get_tree().physics_frame
	# /For testing only
	
	DatabaseManager.setup_mapper(W4GD.mapper)
	
	multiplayer.peer_authentication_failed.connect(
		func _peer_authentication_failed(p_peer_id: int) -> void:
			if p_peer_id == 1:
				# We failed to authenticate with the server.
				connection_failed.emit()
	)
	
	W4GD.game_server.player_joined.connect(_on_player_joined)
	W4GD.game_server.player_left.connect(_on_player_left)
	
	if not is_server():
		# The following signals will only be emitted on clients.
		multiplayer.connected_to_server.connect(
			func _connected_ok() -> void:
				connection_succeeded.emit()
		)
		multiplayer.connection_failed.connect(
			func _connected_fail() -> void:
				multiplayer.multiplayer_peer = null # Remove peer
				connection_failed.emit()
		)
		multiplayer.server_disconnected.connect(
			func _server_disconnected() -> void:
				game_error.emit("Server disconnected")
				close_game()
		)


## Called when a player joins the lobby
##
func _on_player_joined(player: W4Player) -> void:
	players[player.peer_id] = player.info['player_name']


## Called when a player leaves the lobby
##
func _on_player_left(player: W4Player) -> void:
	if has_node("/root/Level"): # Game is in progress.
		# remove the player from the list of alive players
		player_left.emit(player.peer_id)
	# otherwise, it's not necessary
	players.erase(player.peer_id)


########################## AUTHENTICATION ######################################


## Logins the player
##
## Returns true on successful logins
func login() -> bool:
	last_error = ""
	# More controllable profiles/
	var profile := ProfileData.restore()
	var login_result = await W4GD.auth.login_device(profile.login_uuid, profile.login_key).async()
	# /More controllable profiles
	### var login_result = await W4GD.auth.login_device_auto().async()
	if login_result.is_error():
		last_error = login_result.as_error().message
		return false
	return true


############################### CLUSTERS #######################################


## Returns all the cluster names
## 
func get_cluster_list() -> Array[String]:
	last_error = ""
	var clusters: Array[String] = []
	var result = await W4GD.matchmaker.get_cluster_list().async()
	if result.is_error():
		last_error = str(result.as_error())
		return clusters
	clusters.assign(result.as_array())
	return clusters


############################### LOBBIES ########################################


## Creates a lobby in a given cluster
##
## if a lobby was previously joined, leaves it.
func create_lobby(cluster: String) -> bool:
	last_error = ""
	await leave_lobby()
	
	var player_name := ProfileData.restore().player_name
	
	await DatabaseManager.set_own_username(player_name)
	
	var result = await W4GD.matchmaker.create_lobby(
		W4GD.matchmaker.LobbyType.DEDICATED_SERVER,
		{
			max_players = MAX_PEERS,
			cluster = cluster,
			props = {
				lobby_owner_username = player_name
			}
		}
	).async()
	if result.is_error():
		last_error = result.message.as_string()
		return false
	_lobby = result.get_data() as W4Lobby
	_setup_lobby()
	return true


## Joins a lobby
##
## if a lobby was previously joined, leaves it.
func join_lobby(lobby_id: String) -> bool:
	last_error = ""
	await leave_lobby()
	
	await DatabaseManager.set_own_username(ProfileData.restore().player_name)
	
	var result = await W4GD.matchmaker.join_lobby(lobby_id, false).async()
	
	if result.is_error():
		last_error = result.message.as_string()
		return false
	_lobby = result.get_data() as W4Lobby
	_setup_lobby()
	return true


## Leaves the current lobby.
##
## If no lobby was setup or joined, this is a no-op
func leave_lobby():
	if _lobby == null:
		return
	await _lobby.leave().async()
	_lobby = null


## Returns all lobbies
##
func get_lobbies() -> Array[W4Lobby]:
	last_error = ""
	var lobbies: Array[W4Lobby] = []
	
	var result = await W4GD.matchmaker.find_lobbies({
		include_player_count = true,
		only_my_lobbies = false,
		constraints = {
			"state": [W4GD.matchmaker.LobbyState.NEW],
			"player_count": {
				op = ">",
				value = 0,
			},
		},
		
		}).async()

	if result.is_error():
		last_error = str(result.as_error())
		return lobbies

	for lobby_info in result.get_data():
		var lobby_data = await W4GD.matchmaker.get_lobby(lobby_info["id"], false).async()
		var lobby: W4Lobby = lobby_data.get_data()
		lobbies.append(lobby)
	
	lobbies.sort_custom(
		func(l1: W4Lobby, l2: W4Lobby) -> bool:
			return l1.created_at > l2.created_at
	)
	return lobbies


## Subscribes to lobby changes; Makes sure game can start upon receiving a server
## ticket
##
## The lobby must have been initialized first, through join_lobby or create_lobby
func _setup_lobby() -> void:
	if not _lobby:
		assert(_lobby, "lobby was not created before calling setup_lobby")
		return
	
	_lobby.subscribe()

	var _on_player_list_changed := func _on_player_list_changed(_player_id = null):
		player_list_changed.emit()
	
	_lobby.player_joined.connect(_on_player_list_changed)
	_lobby.player_left.connect(_on_player_list_changed)
	_lobby.received_server_ticket.connect(
		func _on_received_server_ticket(p_server_ticket: W4ServerTicket) -> void:
			_join_game(p_server_ticket.ip, p_server_ticket.port, p_server_ticket.secret)
			started_joining_server.emit()
	)


## Returns the current lobby name.
##
## The lobby must have been initialized first, through join_lobby or create_lobby
func get_lobby_id() -> String:
	if not _lobby:
		assert(_lobby, "lobby was not created before requesting id")
		return ""
	return _lobby.id


## Returns all players in the lobby.
##
## The lobby must have been initialized first, through join_lobby or create_lobby
func get_lobby_players() -> Array[String]:
	if not _lobby:
		assert(_lobby, "lobby was not created before requesting players")
		return []
	return _lobby.get_players()


## Returns the player name, as saved in the database
##
func get_player_name(player_id: String) -> String:
	return await DatabaseManager.get_username(player_id)


############################## HOSTING #########################################


## Whichever client calls that methods hosts a game and becomes a server.
##
## This is normally only called from a game hosted on W4.
func host_game() -> bool:
	W4GD.game_server.match_ready.connect(
		func _on_match_ready() -> void:
			begin_game()
	)
	game_closed.connect(
		func _on_game_closed() -> void:
			shutdown_server()
	)
	game_error.connect(
		func _on_game_error(msg: String) -> void:
			printerr("GAME ERROR: %s"%[msg])
			shutdown_server()
	)
	
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(DEFAULT_PORT, MAX_PEERS)
	
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to start multiplayer server.")
		return false
	multiplayer.multiplayer_peer = peer

	# Mark this server as ready, so it can be allocated to a match.
	W4GD.game_server.set_server_state(W4GD.game_server.ServerState.READY)
	return true


## Shuts down the server.
##
## This can only be called from the server
func shutdown_server() -> void:
	W4GD.game_server.set_server_state(W4GD.game_server.ServerState.SHUTDOWN)


## Loads the level for all players
## 
## The authority on this function is server, which calls it on all connected
## clients.
@rpc("authority", "call_local")
func _begin_game() -> void:
	var level = load("res://level/multiplayer_level.tscn").instantiate()
	get_tree().get_root().add_child(level)
	var lobby = get_tree().get_root().get_node_or_null("Lobby")
	if lobby != null:
		lobby.hide()
		_set_player_ready.rpc()


## Returns `true` if all the players are ready
##
func are_all_players_ready() -> bool:
	return _players_ready.size() == players.keys().size()


## Every time a player connects, they call this method.
## 
## Called from any peer, and dispatches to all peers, so everyone can know
## the specific player is ready
@rpc("any_peer")
func _set_player_ready() -> void:
	_players_ready.append(multiplayer.get_remote_sender_id())
	if are_all_players_ready():
		all_players_ready.emit()


## Starts the game for all players.
##
## Run it only from a server.
func begin_game() -> void:
	assert(multiplayer.is_server(), "this function should only run on the server")
	_begin_game.rpc()


############################## ENDING ##########################################


## The server calls this function when the game ends, and it gets called on all
## clients.
## 
## Because we want to play the little win/lose animation before returning to lobby,
## this is separate from `close_game`.
##
## Restores the mouse on all clients, and adds the victory scene.
## TODO: isn't specifying "authority" here redundant?
@rpc("authority", "call_local")
func show_victory_screen(winner_name: String, winner_id: int) -> void:
	var lobby = get_tree().get_root().get_node_or_null("Lobby")
	if lobby != null:
		game_round_won.emit()
		# We wait for the game over animation to finish
		await get_tree().create_timer(2.0).timeout
		disconnect_from_game()
		get_node("/root/Level").queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var victory_scene = load("res://assets/victory_scene/victory_scene.tscn").instantiate()
		get_tree().get_root().add_child(victory_scene)
		victory_scene.setup(winner_name, winner_id)


## Each client calls this function locally after the match has ended and the
## victory animation has played.
## 
## Removes all scenes, disconnects all clients, and restores the lobby.
func close_game() -> void:
	if has_node("/root/Level"): # Game is in progress.
		# End it
		get_node("/root/Level").queue_free()
	if has_node("/root/VictoryScene"):
		get_node("/root/VictoryScene").queue_free()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_closed.emit()
	players.clear()
	_players_ready.clear()


############################## JOINING #########################################


## Appends a client to a W4 session and opens a connection.
##
## Only called from clients.
func _join_game(ip_or_address: String, port: int, ticket_password: String) -> void:
	var player_name := ProfileData.restore().player_name
	var player_id:String = W4GD.get_identity().get_uid()
	W4GD.game_server.start_client(player_id, ticket_password, {player_name = player_name})

	var peer := ENetMultiplayerPeer.new()
	peer.create_client(ip_or_address, port)
	multiplayer.multiplayer_peer = peer


## Clears the network peer and closes the connection
##
func disconnect_from_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


## Starts a match
##
func start_match() -> bool:
	last_error = ""
	if not _lobby:
		assert(_lobby, "lobby was not created before requesting start_match")
		return false
	
	_lobby.state = W4GD.matchmaker.LobbyState.SEALED

	var result = await _lobby.save().async()
	if result.is_error():
		last_error = "Unable to seal the lobby"
		return false
	return true


############################### UTILITIES ######################################


## Returns `true` if the current Godot instance is a server
## 
func is_server() -> bool:
	return W4GD.game_server.is_server()


# For testing only/

## Returns true if:
## 1. The game is running with --headless
## 2. The game is running locally and was the first instance
##
## 
## When running multiple instances in debug mode, we cannot differentiate the
## server from the others.
## While waiting for https://github.com/godotengine/godot-proposals/issues/6232, 
## we hack it by using a file shared and read by all instances
## 
## This is only useful while debugging in the editor, and will always return
## `false` in release builds.
## 
## This function is there for debugging and illustration purposes, it is not 
## used in the current build.
func _is_server() -> bool:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		return true
	if not OS.is_debug_build():
		return false
	if Flags.is_server() == true:
		return true
	# Creates a lock for a few seconds, which should be enough for all debug 
	# instances to launch.
	if _lock_file == null:
		_lock_file = LockFile.get_lock(self, "is_server", 2.0)
	return _lock_file

## if this is true, then this windows was opened first. Useful to identify the
## different windows
var _lock_file = null

# /For testing only
