extends "../../testing/base_test.gd"

const Client = preload("../client.gd")

const URL = "https://api.github.com"

var client : Client

func setup():
	client = Client.new(self, URL)


func test_set_headers():
	var size = client.default_headers.size()
	client.set_header("a", "a")
	assert_equal(client.default_headers[size], "a:a")
	client.set_header("b", "b")
	assert_equal(client.default_headers[size+1], "b:b")
	client.set_header("a", "b")
	assert_equal(client.default_headers[size], "a:b")
	client.set_header("b", "a")
	assert_equal(client.default_headers[size+1], "b:a")
	client.set_header("a")
	assert_equal(client.default_headers.size(), size+1)
	client.set_header("b")
	assert_equal(client.default_headers.size(), size)


func test_query_from_dict():
	var query = {
		1: 2,
		"a": 2.0,
		"b": false,
		[]: ""
	}
	assert_cond(!client.query_from_dict(query).is_empty())


func test_text_get():
	var result = await client.GET("/zen").async()
	assert_cond(result.is_http_success())
	assert_greater_then(result.text_result().length(), 0)


func test_post_fail():
	var result = await client.POST("/zen").async()
	assert_cond(result.is_http_error())
	assert_greater_then(result.text_result().length(), 0)


func test_put_fail():
	var result = await client.PUT("/zen").async()
	assert_cond(result.is_http_error())
	assert_greater_then(result.text_result().length(), 0)


func test_delete_fail():
	var result = await client.DELETE("/zen").async()
	assert_cond(result.is_http_error())
	assert_greater_then(result.text_result().length(), 0)


func test_json_get():
	var result = await client.GET("/users/godotengine").async()
	assert_cond(result.is_http_success())
	var json = result.json_result()
	assert_cond(json != null)
	assert_greater_then(json.size(), 0)


func test_get_fail():
	var result = await client.POST("/invalid_endpoint").async()
	assert_cond(result.is_http_error())
