###############################################################################
##
## Locks Manager
##
## Godot does not provide facilities to differentiate running debug instances.
## This class helps by allowing to create and query locks.
##
## This is only intended to be used as a debug tool while developing, not for
## releases.
## 
## License: MIT GDQuest
##
class_name LockFile

## Lock database location
static var _config_file_path := "res://_locks.cfg":
	set(new_path):
		_config_file_path = new_path
		_config_file = null

## config file
static var _config_file: ConfigFile = null:
	get:
		if _config_file == null:
			_config_file = ConfigFile.new()
			var err = _config_file.load(_config_file_path)
			if err != OK:
				_config_file.save(_config_file_path)
		return _config_file

static var _locks_main_section = "main"

## Saves the config file. Call this after each change
static func _save() -> void:
	_config_file.save(_config_file_path)


## Creates a lock file
##
## @param lock_file_name the name of the lock
## @param lifetime optionally, remove the lock after a set time.
static func create_lock(lock_file_name: String, lifetime := -1.0) -> LockFileWatcher:
	_config_file.set_value(_locks_main_section, lock_file_name, true)
	_save()
	var watcher := LockFileWatcher.new()
	watcher.name = get_node_lock_name(lock_file_name)
	watcher.lock_file_name = lock_file_name
	watcher.lifetime = lifetime
	return watcher

## Lock watchers need a specific name so they can be queried for existence at
## run time.
static func get_node_lock_name(lock_file_name: String) -> String:
	return "Watcher:%s"%[lock_file_name]


## Checks if a lock file is present
static func has_lock(lock_file_name: String) -> bool:
	return _config_file.get_value(_locks_main_section, lock_file_name, false)
	#return FileAccess.file_exists(lock_file_name)


## Creates a lock file if it doesn't exist
##
## @param lock_file_name the name of the lock
## @param lifetime optionally, remove the lock after a set time.
static func create_if_not_exists(lock_file_name: String, lifetime := -1.0) -> LockFileWatcher:
	if !has_lock(lock_file_name):
		return create_lock(lock_file_name, lifetime)
	return null


## Creates a lock for the given name, *if* the lock does not exist.
## 
## Appends a lock watcher that takes care of emptying the db before exiting
## @param node any node; this is just to get access to the scene tree
## @param lock_file_name the name of the lock
## @param lifetime optionally, remove the lock after a set time.
static func get_lock(node: Node, lock_file_name: String, lifetime := -1.0) -> bool:
	var watcher := create_if_not_exists(lock_file_name, lifetime)
	if watcher == null:
		return false
		
	(
		func append_to_tree_when_ready() -> void:
			if not node.is_inside_tree():
				await node.ready
			node.get_tree().root.add_child.call_deferred(watcher, true)
	).call()
	
	return true


## Verifies if a lock has been set with the given name
##
## Note: this can only run after _ready
static func lock_exists(node: Node, lock_file_name: String) -> bool:
	return node.get_tree().root.has_node(get_node_lock_name(lock_file_name))


## Removes a lock if it exists
static func remove_lock(lock_file_name: String) -> void:
	_config_file.set_value(_locks_main_section, lock_file_name, null)
	_save()


## Stays in the tree and listens for exit notification so it can clean the 
## lock database before exiting the software
##
class LockFileWatcher extends Node:
	
	## The name of the lock in the database
	var lock_file_name := ""
	
	## If higher than 0, this node autodestructs after being added to the tree
	var lifetime := -1.0:
		set(new_lifetime):
			lifetime = new_lifetime
			
			if lifetime > 0:
				if not is_inside_tree():
					await ready
				if _timer.is_stopped():
					_timer.start(lifetime)

	var _timer := Timer.new()
	
	func _ready() -> void:
		get_tree().set_auto_accept_quit(false)
		add_child(_timer)
		_timer.one_shot = true
		_timer.timeout.connect(remove)
		tree_exiting.connect(
			func on_before_exiting():
				printerr("LockFileWatcher %s is being removed from the tree, which shouldn't happen"%[lock_file_name])
				remove()
		)
		if lifetime > 0 and _timer.is_stopped():
			_timer.start(lifetime)

	## Runs on general notifications
	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_CLOSE_REQUEST or what == DisplayServer.WINDOW_EVENT_CLOSE_REQUEST:
			remove()
			get_tree().quit()

	## Remove the lock
	func remove() -> void:
		LockFile.remove_lock(lock_file_name)
		_timer.queue_free()
