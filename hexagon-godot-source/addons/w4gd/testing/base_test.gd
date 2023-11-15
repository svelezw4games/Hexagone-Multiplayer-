extends Node

const REAL_ASSERT = false

class Logger extends RefCounted:
	var __logs := []


	func _log(level, msg, data=null):
		__logs.append([level, [msg, data]])


	func info(msg, data=null):
		_log("info", msg, data)


	func error(msg, data=null):
		_log("error", msg, data)


	func get_logs():
		return __logs


var _collected = false
var _success = true
var _start_time = 0
var _skip = false
var logging = Logger.new()
var __me = ""

# Override this to specify pre_run conditions.
# You can skip() or fail() the test from here.
# Runner is the Node you will be added to, method the method name that will be called.
func pre_run(_runner : Node, _method : StringName):
	pass


# Override this to specify test initialization (called on _ready if not skipped)
func setup():
	pass


# Override this to do cleanup, make assertions at the end of the test (called on _exit_tree)
# NOTE: You can still fail here if you like with fail() or by failing an assertion
func teardown():
	pass


# Override this to specify a different filter for the test methods to be run.
func should_test(p_name : StringName):
	return str(p_name).begins_with("test_")


func _init():
	__me = get_script()
	while __me.get_base_script() != null:
		__me = __me.get_base_script()


func _ready():
	_start_time = Time.get_ticks_usec()
	logging.info("RUNNING: %s" % __get_source(self))


func _exit_tree():
	if _skip:
		return

	logging.info("%s: %s" % ["SUCCESS" if _success else "FAILURE", __get_source(self)])


func __get_source(who):
	if who == null or who.get_script() == null:
		return "Unknown source: %s" % str(who)
	return who.get_script().resource_path


func __get_caller():
	for s in get_stack():
		if __me.resource_path != s.source:
			return s
	return null


func __get_assertion():
	var stack = get_stack()
	stack.reverse()
	for s in stack:
		if __me.resource_path == s.source:
			return s
	return null


func __get_stack_dict():
	return {
		"caller": __get_caller(),
		"assertion": __get_assertion(),
		"full_stack": get_stack(),
		"assert_source": __get_source(self),
	}

func __assert(cond, assert_name="", vars=null):
	if not cond:
		logging.error("Assert Failed", {
			"assert": {
				"name": assert_name,
				"vars": vars
			},
			"stack": __get_stack_dict()
		})
		print_tree_pretty()
		_success = false
	if REAL_ASSERT:
		assert(cond)
	if cond:
		return true
	return false


func assert_cond(cond):
	return __assert(cond)


func assert_max_time(max_time):
	var ticks = Time.get_ticks_usec()
	var cond = get_running_time() < max_time
	return __assert(cond, "MaxTime", {
		"start": _start_time,
		"ticks": ticks,
		"max": max_time
	})


func assert_equal(v1, v2):
	return __assert(v1 == v2, "Equal", {"v1": v1, "v2": v2})


func assert_not_equal(v1, v2):
	return __assert(v1 != v2, "NotEqual", {"v1": v1, "v2": v2})


func assert_less_then(v1, v2, equal=false):
	if equal:
		return __assert(v1 <= v2, "LessThenEqual", {"v1": v1, "v2": v2})
	else:
		return __assert(v1 < v2, "LessThen", {"v1": v1, "v2": v2})


func assert_greater_then(v1, v2, equal=false):
	if equal:
		return __assert(v1 >= v2, "GreaterThenEqual", {"v1": v1, "v2": v2})
	else:
		return __assert(v1 > v2, "GreaterThen", {"v1": v1, "v2": v2})


func timer(time):
	await get_tree().create_timer(time).timeout
	return


func fail():
	_success = false
	__assert(false)


func skip():
	logging.info("SKIP: %s" % __get_source(self), __get_stack_dict())
	_skip = true


func is_skip():
	return _skip


func is_pass():
	return _success


func get_running_time():
	return float(_start_time - Time.get_ticks_usec()) / 1000000.0


func collect():
	_collected = true


func was_collected():
	return _collected
