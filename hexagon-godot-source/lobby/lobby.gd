###############################################################################
##
## LOBBY
## 
## Central piece of the multiplayer. Allows to identify
## 
## 
extends Control

const LobbyButton := preload("assets/lobby_button.tscn")

@onready var _login_screen: PanelContainer = %LoginScreen
@onready var _join_screen: PanelContainer = %JoinScreen
@onready var _name_field: LineEdit = %NameField
@onready var _join_error_label: Label = %JoinErrorLabel
@onready var _players_screen: PanelContainer = %PlayersScreen
@onready var _lobby_id_field: LineEdit = %LobbyIdField
@onready var _state_label: Label = %StateLabel
@onready var _players_list: ItemList = %PlayersList
@onready var _start_button: Button = %StartButton
@onready var _error_dialog: AcceptDialog = %ErrorDialog
@onready var _join_lobby_popup: Popup = %JoinLobbyPopup
@onready var _lobby_id_line_edit: LineEdit = %LobbyId
@onready var _cluster_options_button: OptionButton = %ClusterOptions
@onready var _lobbies_list_container: VBoxContainer = %LobbiesList
@onready var _lobbies_loading_image: Control = %LobbiesLoadingImage
@onready var _overlay: TextureButton = %Overlay
@onready var _list_lobbies_popup: Popup = %ListLobbiesPopup


var _cluster_options: Array[String] = []

func _ready() -> void:
	
	# Signals ##################################################################
	
	GameState.connection_failed.connect(
		func _on_connection_failed():
			printerr("====== connection failed ========")
			_show_error("Unable to connect to game server")
	)
	GameState.connection_succeeded.connect(
		func _on_connection_success():
			_state_label.text = "Waiting for match to start..."
	)
	GameState.game_closed.connect(
		func _on_game_closed():
			print("====== game ended ========")
			GameState.disconnect_from_game()
			show()
			_return_to_join_screen()
	)
	GameState.game_error.connect(
		func _on_game_error(errtxt: String):
			print("====== game error ========")
			_show_error(errtxt)
			_return_to_join_screen()
	)

	GameState.started_joining_server.connect(
		func _on_started_joining_server():
			_state_label.text = "Joining server..."
	)

	GameState.player_list_changed.connect(_on_player_list_changed)

	_name_field.text_changed.connect(
		func _on_name_field_text_changed(new_text: String) -> void:
			ProfileData.restore().player_name = new_text
	)
	_overlay.button_down.connect(_close_popups)
	
	_start_button.pressed.connect(_on_start_pressed)
	
	## We used in-script signals instead of editor for expliciteness
	
	(%ResetProfile as Button).pressed.connect(
		func _on_reset_pressed():
			ProfileData.restore().reset()
			_navigate_to_login_screen()
			_login()
	)
	
	(%HostButton as Button).pressed.connect(_on_host_button_pressed)
	(%JoinButton as Button).pressed.connect(
		func _on_join_pressed() -> void:
			_join_lobby_popup.popup_centered()
			_overlay.show()
	)
	(%ListLobbiesButton as Button).pressed.connect(
		func _on_list_lobbies_pressed() -> void:
			_list_lobbies_popup.popup_centered()
			_refresh_lobbies()
			_overlay.show()
	)
	(%BackButton as Button).pressed.connect(
		func _on_back_pressed() -> void:
			GameState.leave_lobby()
			_return_to_join_screen()
	)
	(%JoinLobbyButton as Button).pressed.connect(
		func _on_join_with_id_pressed() -> void:
			_join_lobby(_lobby_id_line_edit.text)
	)
	(%RefreshButton as Button).pressed.connect(_refresh_lobbies)

	# Login ####################################################################

	_navigate_to_login_screen()
	
	# Credentialess logins should never result in an error, so if there's a 
	# problem, just exit.
	if not await _login():
		return

	# Obtain available clusters ################################################
	
	var result := await GameState.get_cluster_list()
	if GameState.has_error:
		_join_screen.visible = true
		_show_error(GameState.last_error)
		return
	
	_cluster_options.assign(result)
	
	if _cluster_options.size() == 0:
		_join_screen.visible = true
		_show_error('No available clusters found')
		return

	for option in _cluster_options:
		_cluster_options_button.add_item(option)
		_cluster_options_button.selected = 0

	_cluster_options_button.item_selected.connect(
		func(_index: int):
			_refresh_lobbies()
	)
		
	
	_login_screen.visible = false
	_join_screen.visible = true
	_name_field.text = ProfileData.restore().player_name
	
	ProfileData.restore().changed.connect(
		func on_profile_changed():
			_name_field.text = ProfileData.restore().player_name
	)


###################### GAME STATE MANAGEMENT ###################################

## Logs the player
##
func _login() -> bool:
	var login_result := await GameState.login()
	if not login_result:
		_show_error(GameState.last_error)
		return false
	return true


## Creates a new lobby and await other players
##
func _on_host_button_pressed() -> void:
	if _name_field.text.strip_edges() == "":
		_join_error_label.text = "Invalid name!"
		return

	_join_screen.visible = false
	_join_error_label.text = ""

	var result = await GameState.create_lobby(_cluster_options.front())
	
	if not result:
		_join_screen.visible = true
		_show_error(GameState.last_error)
		return

	_players_screen.visible = true
	_state_label.text = "Awaiting players..."
	_start_button.disabled = false

	var id := GameState.get_lobby_id()
	_lobby_id_field.text = id
	DisplayServer.clipboard_set(id)

	_on_player_list_changed()


## Refreshes the list of lobbies and creates a button for each
##
## Called when displaying the lobbies screen, when pressing refresh, or when
## switching clusters.
func _refresh_lobbies() -> void:
	for lobby_button in _lobbies_list_container.get_children():
		lobby_button.queue_free()

	_lobbies_list_container.hide()
	_lobbies_loading_image.show()

	var lobbies := await GameState.get_lobbies()
	
	if GameState.has_error:
		_join_screen.visible = true
		_show_error(GameState.last_error)
		return

	_lobbies_list_container.show()
	_lobbies_loading_image.hide()

	for lobby in lobbies:
		var button = LobbyButton.instantiate()

		if lobby.props.has("lobby_owner_username"):
			button.lobby_name = "%s's lobby" % lobby.props["lobby_owner_username"]
		else:
			button.lobby_name = "Lobby"
		button.players_count = lobby.get_players().size()
		button.max_players = lobby.max_players
		button.pressed.connect(_join_lobby.bind(lobby.id))
		_lobbies_list_container.add_child(button)


## When a player presses "join" on a lobby, we attempt to join that lobby
##
func _join_lobby(lobby_id: String) -> void:
	_close_popups()
	_join_screen.visible = false
	_join_error_label.text = ""
	
	var result = await GameState.join_lobby(lobby_id)

	if not result:
		_join_screen.visible = true
		_show_error(GameState.last_error)
		return


	_players_screen.visible = true
	_state_label.text = "Awaiting players..."
	_start_button.disabled = true

	_lobby_id_field.text = GameState.get_lobby_id()

	_on_player_list_changed()


## When players join or leave a lobby, we refresh the list of player names
##
func _on_player_list_changed() -> void:
	var players = GameState.get_lobby_players()
	var players_usernames : Array[String] = []

	for p_id in players:
		players_usernames.append(await GameState.get_player_name(p_id))

	players_usernames.sort()

	_players_list.clear()
	for p in players_usernames:
		_players_list.add_item(p)


## When the host presses the start button, the match commences
##
func _on_start_pressed() -> void:

	if not await GameState.start_match():
		printerr("Could not start match")
		return
	
	_state_label.text = "Waiting for server allocation..."


############################ NAVIGATION ########################################


## Navigates to the first screen
##
func _navigate_to_login_screen() -> void:
	_login_screen.visible = true
	_join_screen.visible = false
	_players_screen.visible = false
	_join_error_label.text = ""


## Goes back to the join screen
## 
func _return_to_join_screen() -> void:
	_login_screen.visible = false
	_join_screen.visible = true
	_players_screen.visible = false
	_join_error_label.text = ""


## Hides all popups
## 
func _close_popups() -> void:
	_overlay.hide()
	_join_lobby_popup.hide()
	_list_lobbies_popup.hide()


## Displays an error to the screen and console; closes popups
## 
func _show_error(msg: String) -> void:
	printerr("ERROR: %s" % msg)
	_close_popups()
	_error_dialog.dialog_text = msg
	_error_dialog.popup_centered()
