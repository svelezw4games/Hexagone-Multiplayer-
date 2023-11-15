extends "../../testing/base_test.gd"

const Parser = preload("../poly_result.gd")
const PolyResult = Parser.PolyResult

var result : PolyResult = PolyResult.new()

func test_null():
	assert_cond(result.is_null())
	assert_equal(result.size(), 0)
	assert_equal(result.as_array(), [])
	assert_equal(result.as_dict(), {})
	assert_equal(result.as_string(), "")


func test_dict():
	var data = {
		"A": [1, 2],
		"B": {"C1": 1},
		"C": true,
		"D": 1,
		"E": 2.1,
		"F": null,
	}
	result = PolyResult.new(data)
	assert_equal(result.as_dict(), data)
	assert_equal(result.as_array(), [])
	assert_equal(result.as_string(), "")
	assert_equal(result.get_data(), data)
	assert_equal(result.size(), data.size())
	assert_equal(result.keys(), data.keys())
	assert_equal(result.values(), data.values())
	assert_cond(not result.is_empty())
	assert_equal(result.A.as_array(), data["A"])
	assert_equal(result.B.as_dict(), data["B"])
	assert_equal(result.C.as_bool(), true)
	assert_equal(result.D.as_int(), 1)
	assert_equal(result.E.as_float(), 2.1)
	assert_cond(result.F.is_null())
	assert_cond(result.G.is_error())
	assert_cond(result.get_at(0).is_error())


func test_array():
	var data = [
		"A",
		1,
		null
	]
	result = PolyResult.new(data)
	assert_equal(result.as_array(), data)
	assert_equal(result.as_dict(), {})
	assert_equal(result.as_string(), "")
	assert_equal(result.get_data(), data)
	assert_equal(result.size(), data.size())
	assert_equal(result.values(), data)
	assert_equal(result.keys(), [])
	assert_cond(not result.is_empty())
	assert_equal(result.get_at(0).get_data(), data[0])
	assert_equal(result.get_at(1).get_data(), data[1])
	assert_cond(result.get_at(2).is_null())
	assert_cond(result.get_at(data.size()).is_error())
	assert_cond(result.get_at(-1).is_error())
	assert_cond(result.TEST.is_error())


func test_string():
	var data = "A Test String"
	result = PolyResult.new(data)
	assert_equal(result.as_array(), [])
	assert_equal(result.as_dict(), {})
	assert_equal(result.as_string(), data)
	assert_equal(result.get_data(), data)
	assert_equal(result.size(), data.length())
	assert_equal(result.values(), [])
	assert_equal(result.keys(), [])
	assert_cond(not result.is_empty())
	assert_cond(result.TEST.is_error())
	assert_cond(result.get_at(0).is_error())
