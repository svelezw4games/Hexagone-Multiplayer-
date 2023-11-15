###############################################################################
##
## W4 MOCK Server
##
## This utility allows to use the W4 APIs without having to connect to an actual
## W4 account.
## This is convenient for cheap local testing, offline or online.
##
## This stub is also useful in unit tests.
##
## To use it, replace W4GD's script like so:
##
## ```gdscript
## W4GD.set_script(load("res://utils/w4_mock.gd"))
## ```
extends Node

const Flags = preload("flags.gd")

const W4RMMapper := preload("res://addons/w4gd/w4rm/w4rm_mapper.gd")
const Lobby := preload("res://addons/w4gd/matchmaker/matchmaker.gd").Lobby
const W4Player := preload("res://addons/w4gd/game_server/game_server_sdk.gd").Player

var analytics: MockAnalytics = MockAnalytics.new()
var matchmaker: MockMatchmaker = MockMatchmaker.new()
var game_server: MockGameServerSDK = MockGameServerSDK.new()
var service : MockW4Client = MockW4Client.new()
var auth : MockAuth = MockAuth.new()
var mapper: MockMapper = MockMapper.new()

var _user_mail := ""

var is_mock := "mock"

var log := SimpleLog.new("W4")

class SimpleLog:

	static var do_log := true
	var title := ""

	func _init(t := ""):
		title = t

	func out(message: String) -> void:
		SimpleLog.flush(message, title)

	static func flush(message: Variant, title:= "") -> void:
		if not SimpleLog.do_log:
			return
		prints(title, "::", message)


@rpc("any_peer")
func mock_join_server(peer_id):
	if not multiplayer.is_server():
		return

	log.out("player %s has requested joining"%[peer_id])
	var player := W4Player.new(peer_id, str(peer_id), { player_name = _user_mail })
	game_server.player_joined.emit(player)
	mock_propagate_join_server.rpc(GameState.players)


@rpc("authority")
func mock_propagate_join_server(players: Dictionary):
	log.out("players: %s"%[players])
	GameState.players = players
	SimpleLog.flush(GameState.players)


func _input(event):
	if Flags.is_server():
		if event is InputEventKey and event.is_pressed():
			if event.keycode == KEY_F1:
				log.out("-- match ready requested --")
				game_server.match_ready.emit()


func has_service():
	log.out("has_service")
	return true


func get_identity():
	log.out("get_identity")
	return MockIdentity.new()


class MockIdentity:
	var log := SimpleLog.new("MockIdentity")
	
	func get_uid():
		log.out("get_uid")
		return str(randi())


class MockAnalytics:
	signal error
	signal session_running_event
	var log := SimpleLog.new("MockAnalytics")

	func lobby_joined(_lobby_id, _options = {}):
		log.out("lobby_joined")
		return

	func start_session(_options):
		log.out("start_session")
		return

	func stop_session(_props):
		log.out("stop_session")
		return

	func flush():
		log.out("flush")
		return

	class UUIDGenerator:
		var log := SimpleLog.new("UUIDGenerator")
		func generate_v4():
			log.out("generate_v4")
			return "abc"


class MockGameServerSDK:
	enum ServerState { READY, SHUTDOWN }

	signal player_joined
	signal player_left
	signal match_ready
	var log := SimpleLog.new("MockGameServerSDK")

	var potat = "POTATO"

	func is_server():
		log.out("is_server")
		return Flags.is_server()

	func start_client(_id, _password, _options):
		log.out("start_client")

	func get_server():
		log.out("get_server")
		return MockServer.new()

	func get_players():
		log.out("get_players")
		return []

	func set_server_state(state):
		log.out("set_server_state %s"%[state])


class MockServer:
	
	var log := SimpleLog.new("MockServer")
	
	func get_lobby_id():
		log.out("get_lobby_id")
		return 0

	func is_server():
		log.out("is_server")
		return Flags.is_server()

	func get_lobby_properties():
		log.out("get_lobby_properties")
		return {}


class MockW4Client:
	pass


class MockAuth:
	var log := SimpleLog.new("MockAuth")
	
	func login_email(email: String, password: String):
		log.out("login_email [%s, %s]"%[email, password])
		W4GD._user_mail = email
		return MockResult.new()

	func login_device(user_uuid, unique_id):
		log.out("login_device [%s, %s]"%[user_uuid, unique_id])
		return MockResult.new()


class MockMatchmaker:
	enum LobbyType { DEDICATED_SERVER }
	enum LobbyState{ SEALED }

	var log := SimpleLog.new("MockMatchmaker")
	signal _bogus

	func get_cluster_list():
		log.out("get_cluster_list")
		var result = MockResult.new()
		result.array = ["mock"]
		return result

	func create_lobby(lobby_type: LobbyType, options: Dictionary):
		log.out("create_lobby [%s, %s]"%[lobby_type, options])
		var result = MockResult.new()
		result.data = MockLobby.new(null, {}, [], _bogus, false)
		return result

	func join_lobby(lobby_id, subscribe):
		log.out("join_lobby [%s, %s]"%[lobby_id, subscribe])
		var result = MockResult.new()
		result.data = MockLobby.new(null, {}, [], _bogus, false)

		W4GD.get_tree().create_timer(1).timeout.connect(func():
			log.out("issuing ticket")
			result.data.received_server_ticket.emit(MockServerTicket.new())
			await W4GD.get_tree().create_timer(1).timeout
			log.out("joining server")
			W4GD.mock_join_server.rpc(W4GD.multiplayer.get_unique_id())
		)

		return result

	func find_lobbies(p):
		log.out("find_lobbies %s"%[p])
		var result = MockResult.new()
		result.data = [{
			"id": "mock_lobby_id",
		}]

		return result

	func get_lobby(id, subscribe):
		log.out("get_lobby [%s, %s]"%[id, subscribe])
		var result = MockResult.new()
		result.data = MockLobby.new(null, {}, [], _bogus, false)
		return result

class MockLobby extends Lobby:
	#signal player_joined
	#signal player_left
	#signal received_server_ticket

	#var state
	#var created_at := 0
	var lobby_name := "mock lobby"
	var log := SimpleLog.new("MockLobby")
	#var max_players := 2
	#var id := ""
	#var props := {
	#	"lobby_owner_username": "mock_user_name"
	#}
	
	func _init(p_client: SupabaseClient, p_data: Dictionary, p_webrtc_ice_servers: Array, p_poll_signal: Signal, p_subscribe: bool):
		props = {
			"lobby_owner_username": "mock_user_name"
		}

	func get_players() -> Array[String]:
		log.out("get_players")
		var players: Array[String] = ["mock_player_id"]
		return players

	func save():
		log.out("save")
		return MockResult.new()

	func subscribe():
		log.out("subscribe")
		return


class MockServerTicket:
	var ip = "127.0.0.1"
	var port = GameState.DEFAULT_PORT
	var secret = "shhhh-its-a-secret"


class MockResult:
	var data
	var array
	var message
	var log := SimpleLog.new("MockResult")
	
	func get_data():
		log.out("get_data")
		return data

	func as_array():
		log.out("as_array")
		return array

	func async() -> MockResult:
		log.out("async")
		return self

	func is_error() -> bool:
		log.out("is_error")
		return false

class MockMapper extends W4RMMapper:
	
	var log := SimpleLog.new("MockMapper")
	
	func add_table(_name: StringName, _schema: Script, _base=null):
		log.out("add_table")

	func done():
		log.out("done")

	func get_by_id(p_base: GDScript, _id):
		log.out("get_by_id")
		var player = p_base.new()
		player.username = "player%s"%[randi()]
		return player

	func create(_orm_object):
		log.out("create")

	func update(_orm_object):
		log.out("update")
