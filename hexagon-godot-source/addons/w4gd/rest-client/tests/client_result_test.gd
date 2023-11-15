extends "../../testing/base_test.gd"

const AsyncResult = preload("../client_async_result.gd")

var result : AsyncResult = null
var request : HTTPRequest


func setup():
	IP.clear_cache()
	request = HTTPRequest.new()
	add_child(request)


func check_pending():
	assert_cond(result != null)
	assert_cond(result.is_pending())
	assert_cond(result.result_status == AsyncResult.ResultStatus.PENDING)


func check_error():
	assert_cond(result.result_status == AsyncResult.ResultStatus.ERROR)
	assert_cond(not result.is_pending())


func check_cancelled():
	assert_cond(result.result_status == AsyncResult.ResultStatus.CANCELLED)
	assert_cond(not result.is_pending())


func check_await_error(p_request):
	check_pending()
	if p_request != null:
		assert_cond(p_request.is_queued_for_deletion())
	await result.completed
	check_error()


func check_cancel_await(p_request):
	check_pending()
	result.cancel()
	if p_request != null:
		assert_cond(p_request.is_queued_for_deletion())
	check_cancelled()
	await timer(1)
	check_cancelled()


func test_null_request():
	result = AsyncResult.new(null)
	await check_await_error(null)


func test_out_of_tree_request():
	var out_of_tree_request := HTTPRequest.new()
	result = AsyncResult.new(out_of_tree_request)
	await check_await_error(out_of_tree_request)


### This is not supported by the AsyncResult
#func test_without_requesting():
#	result = AsyncResult.new(request)
#	await check_await_error(request)


func test_cancel_null_request():
	result = AsyncResult.new(null)
	await check_cancel_await(null)


func test_cancel_without_requesting():
	result = AsyncResult.new(request)
	await check_cancel_await(request)


func test_invalid_domain_request():
	# This may or may not fail immediately, depending on network/CPU.
	var err = request.request("http://no-a-domain-name")
	result = AsyncResult.new(request)
	assert_cond(err == OK or request.is_queued_for_deletion())
	check_pending()
	await result.completed
	assert_cond(request.is_queued_for_deletion())
	check_error()


func test_valid_domain_request():
	request.request("https://www.google.com")
	result = AsyncResult.new(request)
	assert_cond(not request.is_queued_for_deletion())
	check_pending()
	await result.completed
	assert_cond(request.is_queued_for_deletion())
	assert_cond(not result.is_error())
	assert_cond(not result.is_http_error())
	assert_cond(result.is_http_success())
	assert_greater_then(result.text_result().length(), 0)
	assert_greater_then(result.dict_headers().size(), 0)
