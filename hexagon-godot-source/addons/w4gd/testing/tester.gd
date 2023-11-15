extends Node

const Test = preload("base_test.gd")

signal file_done(file : String, error : int)
signal test_done(file : String, method : String, logs : Array, error : int, skipped : bool)

var current : Test = null
var max_time = 30.0
var test_script : GDScript
var cur_method : String
var methods := []
var timer : Timer

func _ready():
	timer = Timer.new()
	timer.timeout.connect(_test_timeout)
	timer.one_shot = true
	timer.autostart = false
	add_child(timer)


func _test_timeout():
	if current == null:
		return
	current.assert_max_time(max_time)
	current.fail()
	push_error("Test exceeded default timeout.")
	_collect_and_finish()


func run_file(file : String):
	var gd = load(file)
	if not (gd is GDScript):
		file_done.emit(file, 1)
		return
	test_script = gd
	var instance = test_script.new()
	if not (instance is Test):
		file_done.emit(file, 1)
		return
	for m in instance.get_method_list():
		if instance.should_test(m.name):
			methods.append(m.name)
	instance.free()
	print("Testing %d method(s) from file %s: %s" % [methods.size(), file, methods])
	_next_method()


func run_test(test : Test, method : StringName):
	assert(current == null)
	cur_method = method
	test.logging.info("Pre run", {
		"script": test_script.resource_path,
		"test": method
	})
	timer.wait_time = max_time
	timer.start()
	current = test
	await test.pre_run(self, method)
	if test.was_collected():
		return
	if test.is_skip() or not test.is_pass():
		timer.stop()
		_collect_and_finish()
		return
	add_child(test)
	await test.setup()
	if test.was_collected():
		return
	if not test.is_pass():
		await test.teardown()
		if not test.was_collected():
			timer.stop()
			_collect_and_finish()
		return
	await current[method].call()
	if test.was_collected():
		return
	await test.teardown()
	if test.was_collected():
		return
	timer.stop()
	_collect_and_finish()


func _next_method():
	if methods.is_empty():
		file_done.emit(test_script.resource_path, 0)
		test_script = null
	else:
		var m = methods.pop_front()
		print("Testing method '%s' on file '%s'" % [m, test_script.resource_path])
		run_test(test_script.new(), m)


func _collect_and_finish():
	assert(current != null)
	var logs = current.logging.get_logs()
	var success = current.is_pass()
	var skip = current.is_skip()
	current.collect()
	current.queue_free()
	current = null
	test_done.emit(test_script.resource_path, cur_method, logs, 0 if success else 1, skip)
	get_tree().create_timer(1).timeout.connect(_next_method)
