extends Node

@export var player_color_gradient : Gradient

@onready var animation_player = %AnimationPlayer
@onready var anchor = %Anchor
@onready var players_holder = %PlayersHolder
@onready var winner = %Winner

# Winner color should be the first color of the players colors array :)
@onready var winner_tag = %WinnerTag

func _ready():
	players_holder.position.y = -4.0
	anchor.position.y = -4.0


func _on_overlay_clicked():
	var input_event = InputEventAction.new()
	input_event.action = "jump"
	input_event.pressed = true
	Input.parse_input_event(input_event)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("jump"):
		GameState.close_game()


func setup(winner_name : String, player_id: int):
	var total_players := GameState.players.size()
	var players_colors = range(total_players).map(
		func(i: int):
			return player_color_gradient.sample(float(i)/total_players)
	) if total_players > 0 else [ player_color_gradient.sample(0) ]
	
	var winner_color : Color = players_colors.pop_at(player_id)
	
	players_holder.set_players(players_colors)
	winner.color = winner_color
	animation_player.play("enter")
	winner_tag.setup(winner_name)
