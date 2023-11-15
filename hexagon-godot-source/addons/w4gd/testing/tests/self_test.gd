extends "../base_test.gd"

var setup_called = false
var test_called = false
var test_done = false
var async_done = false


func pre_run(_runner : Node, method : StringName):
	if method == "test_skip":
		skip()


func setup():
	setup_called = true


func teardown():
	assert_cond(setup_called)
	assert_cond(test_called)
	assert_cond(test_done)


func test_skip():
	# Should not be called (skipped)
	assert_cond(false)


func test_run():
	test_called = true
	test_done = true


func test_async():
	test_called = true
	await get_tree().process_frame
	test_done = true


func test_timer():
	test_called = true
	await timer(3)
	# Should have taken a while
	assert_greater_then(3, get_running_time(), true)
	test_done = true
