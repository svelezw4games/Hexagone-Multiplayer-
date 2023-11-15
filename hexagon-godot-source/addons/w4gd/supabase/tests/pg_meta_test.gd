extends "integration_base.gd"

var table_id := ""
var field_id := ""

func setup():
	table_id = await setup_tables()
	if not assert_not_equal(table_id, ""):
		return
	var field = await service_client.pg.create_column(table_id, "id",
		"uuid", "uuid_generate_v4()", "expression", false, true, true).async()
	assert_cond(!field.is_error())
	field_id = field.id.as_string()
	assert_cond(!field.is_empty())


func teardown():
	if not table_id.is_empty():
		await service_client.pg.delete_table(table_id).async()


func test_create_table():
	var pg = service_client.pg
	var del = await pg.query("DROP TABLE IF EXISTS %s;" % pg.sql_identifier(VOLATILE_TABLE)).async()
	assert_cond(!del.is_error())
	var result = await service_client.pg.create_table(VOLATILE_TABLE).async()
	if not assert_cond(!result.is_error()):
		return
	result = await pg.delete_table(result.id.as_string()).async()
	assert_cond(!result.is_error())


func test_query():
	var result = await service_client.pg.query('select 2 as "key";').async()
	assert_cond(!result.is_error())
	assert_equal(result.get_at(0).key.as_int(), 2)


func test_get_tables():
	var tables = await service_client.pg.get_tables().async()
	assert_cond(!tables.is_error())
	assert_cond(tables.is_array())


func test_get_table():
	var table = await service_client.pg.get_table(table_id).async()
	assert_cond(!table.is_error())
	assert_equal(table.name.as_string(), BASE_TABLE)


func test_update_table():
	var result = await service_client.pg.alter_table(table_id, null, null, null, true).async()
	var table = await service_client.pg.get_table(table_id).async()
	assert_cond(table.rls_enabled.is_bool())
	assert_equal(table.rls_enabled.as_bool(), true)
	await service_client.pg.alter_table(table_id, null, null, null, false).async()
	table = await service_client.pg.get_table(table_id).async()
	assert_cond(table.rls_enabled.is_bool())
	assert_equal(table.rls_enabled.as_bool(), false)


func test_create_column():
	var result = await service_client.pg.create_column(table_id, "create_test",
		"uuid", "uuid_generate_v4()", "expression", false, false, true).async()
	assert_cond(!result.is_error())


func test_update_column():
	var result = await service_client.pg.update_column(field_id, "rename_test").async()
	assert_cond(!result.is_error())


func test_delete_column():
	var result = await service_client.pg.delete_column(field_id).async()
	assert_cond(!result.is_error())

func test_get_column():
	var result = await service_client.pg.get_column(field_id).async()
	assert_cond(!result.is_error())
	assert_equal(result.table_id.as_string(), table_id)


func test_get_columns():
	var result = await service_client.pg.get_columns(false, 1).async()
	assert_cond(!result.is_error())
	assert_cond(result.is_array())
	assert_equal(result.size(), 1)
