extends ScrollContainer

enum LEVEL{
	TRACE,
	INFO,
	WARN,
	ERROR,
	FATAL
}

@export var title:= ""
@export var min_level: LEVEL = LEVEL.INFO

@export var template := "{time}[{level}][{title}] {text}"

func out(text: String, level: LEVEL = LEVEL.TRACE) -> void:
	
	if level < min_level:
		return
	
	if level > LEVEL.size() or level < 0:
		level = LEVEL.TRACE
	
	var level_str := LEVEL.keys()[level] as String
	
	var datetime := Time.get_datetime_string_from_system().split("T")
	
	var formatted_text := template.format({
		title = title,
		text = text,
		level = level_str,
		date = datetime[0],
		time = datetime[1]
	})
		
	match level:
		LEVEL.FATAL:
			push_error(formatted_text)
			assert(false, formatted_text)
			return
		LEVEL.ERROR:
			push_error(formatted_text)
		LEVEL.WARN:
			push_warning(formatted_text)
		LEVEL.INFO:
			print(formatted_text)
		_:
			print(formatted_text)
	
	if not is_inside_tree():
		await ready
	
	var label := Label.new()
	label.text = formatted_text
	
	(%LogVBoxContainer as VBoxContainer).add_child(label)


func trace(text: String) -> void: 
	out(text, LEVEL.TRACE)


func info(text: String) -> void: 
	out(text, LEVEL.INFO)


func warn(text: String) -> void: 
	out(text, LEVEL.WARN)


func error(text: String) -> void: 
	out(text, LEVEL.ERROR)


func fatal(text: String) -> void: 
	out(text, LEVEL.FATAL)
