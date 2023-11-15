extends Button


var _lobby_name : String
var lobby_name : String :
	set(v):
		_lobby_name = v
		%LobbyName.text = v

var _players_count : int
var players_count : int :
	set(v):
		_players_count = v
		%LobbyPlayersCount.text = "%d / %d" % [_players_count, _max_players]

var _max_players : int
var max_players : int :
	set(v):
		_max_players = v
		%LobbyPlayersCount.text = "%d / %d" % [_players_count, _max_players]
