extends "../../testing/base_test.gd"

const URL = "http://127.0.0.1"

const Client = preload("../client.gd")
const LocalServer = preload("local_server.gd")

var server = LocalServer.new()
var client : Client
var result : Client.Result

func setup():
	client = Client.new(self, URL + ":9882")
	server.listen(9882, "127.0.0.1")
	assert_cond(server.is_listening())


func teardown():
	server.stop()


func _process(_delta):
	server.poll()


func _test_code(p_method, p_code):
	result = await client.call(p_method, "/%d" % p_code).async()
	if p_code > 0:
		assert_cond(result.get_http_status_code() == p_code)
		assert_equal(result.text_result(), p_method)


func _test_method(p_method : String):
	await _test_code(p_method, 200)
	assert_cond(result.is_http_success())
	await _test_code(p_method, 299)
	assert_cond(result.is_http_success())
	await _test_code(p_method, 0)
	# Our Godot request is very permissive, 0 OK is a valid reponse.
	assert_cond(not result.is_error())
	assert_cond(not result.is_http_error())
	await _test_code(p_method, 400)
	assert_cond(not result.is_error())
	assert_cond(result.is_http_error())
	await _test_code(p_method, 500)
	assert_cond(not result.is_error())
	assert_cond(result.is_http_error())
	# This asks the local server to immediately terminate the connection.
	await _test_code(p_method, -1)
	assert_cond(result.is_error())
	assert_cond(not result.is_http_error())


func test_get():
	await _test_method("GET")


func test_post():
	await _test_method("POST")


func test_put():
	await _test_method("PUT")


func test_delete():
	await _test_method("DELETE")


func test_patch():
	await _test_method("PATCH")
