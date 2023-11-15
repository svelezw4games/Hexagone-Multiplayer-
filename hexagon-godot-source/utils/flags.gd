###############################################################################
##
## CUSTOM FLAGS
## 
## Those are getters for command line flags used in this specific project, kept 
## in this file for convenience.
##
const CommandLineUtils = preload("command_line_utils.gd")

## Returns `true` if Godot was ran with `-- --local`
##
## Useful for debugging. When this is set, we use the W4Mock
static func is_local() -> bool:
	return CommandLineUtils.get_argument("local", false)


## Returns `true` if Godot was ran with `-- --server`
##
## If `true`, forces the W4 to think it's a server
static func is_server() -> bool:
	return CommandLineUtils.get_argument("server", false)


## Returns `true` if Godot was ran with `-- --window_position=XxY`,
static func has_window_position() -> bool:
	return CommandLineUtils.arguments.has("window_position")


## Returns a `Vector2i` if Godot was ran with `-- --window_position=XxY`,
## otherwise returns `null`
static func get_window_position(default_position := Vector2i.ZERO) -> Vector2i:
	var window_position_str: String = CommandLineUtils.get_argument("window_position", "")
	if window_position_str:
		var positions := window_position_str.split("x")
		if positions.size() >=2 and positions[0].is_valid_int() and positions[1].is_valid_int():
			return Vector2i(int(positions[0]) , int(positions[1]))
	return default_position


## Used to pass a custom player Profile name
static func get_profile() -> String:
	return CommandLineUtils.get_argument("profile", "")
