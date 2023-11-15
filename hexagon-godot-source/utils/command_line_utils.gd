@tool
###############################################################################
##
## COMMAND LINE TOOLS
## 
## Generic utilities for parsing command line arguments
## 
## License: MIT - GDQuest
##

static var _arguments_were_parsed := false
static var _arguments_cache := {}
static var arguments := {}:
	get: 
		if not _arguments_were_parsed:
			_arguments_were_parsed = true
			_arguments_cache = get_command_line_arguments()
		return _arguments_cache


## Returns a dictionary of all arguments passed after `--` on the command line
## 
## Arguments take one of 2 forms:
## - `--arg` which is a boolean (using `--no-arg` for `false` is possible)
## - `--arg=value`. If the value is quoted with `"` or `'`, this function will 
##    unsurround the string
## This function does no evaluation and does not attempt to guess the type of
## arguments. You will receive either bools, or strings.
## This function does no caching whatsoever, arguments will be parsed every time.
static func get_command_line_arguments() -> Dictionary:
	var args := {}
	for argument in OS.get_cmdline_user_args():
		argument = argument.lstrip("--").to_lower()
		if argument.find("=") > -1:
			var arg_tuple := argument.split("=")
			var key := arg_tuple[0]
			var value := unsurround(unsurround(arg_tuple[1], '"'), "'")\
				.strip_edges()
			args[key] = value
		else:
			var key := argument
			var value := true
			if argument.begins_with("no-"):
				value = false
				key = argument.lstrip("no-")
			args[key] = value
	_arguments_were_parsed = true
	return args


## Returns a single argument
static func get_argument(argument_name: String, default: Variant = null) -> Variant:
	if arguments.has(argument_name):
		return arguments[argument_name]
	return default


## Checks if an argument was set
static func has_argument(argument_name: String) -> bool:
	return arguments.has(argument_name)


## Removes a single surrounding character at the beginning and end of a string
##
## Used internally to unquote passed arguments
static func unsurround(value: String, quote_str := '"') -> String:
	if value.begins_with(quote_str) \
		and value.ends_with(quote_str) \
		and value[value.length() - 2] != "\\":
		return value.trim_prefix(quote_str).trim_suffix(quote_str)
	return value
