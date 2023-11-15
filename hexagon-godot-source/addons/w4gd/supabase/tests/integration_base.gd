extends "../../testing/base_test.gd"

const BASE_EMAIL = "ci-test@w4games.com"
const VOLATILE_EMAIL = "ci-test2@w4gaames.com"
const BASE_PASSWORD = "password"

const BASE_TABLE = "ci-test-table"
const VOLATILE_TABLE = "ci-test-table2"

const SupabaseClient = preload("../client.gd")

var url := OS.get_environment("CI_SUPABASE_URL")
var anon_key := OS.get_environment("CI_SUPABASE_ANON_KEY")
var service_key := OS.get_environment("CI_SUPABASE_SERVICE_KEY")

var anon_client : SupabaseClient
var logged_client : SupabaseClient
var service_client : SupabaseClient

func pre_run(_runner : Node, _test : StringName):
	if url.is_empty() or anon_key.is_empty() or service_key.is_empty():
		skip()
		return
	anon_client = SupabaseClient.new(self, url, anon_key)
	logged_client = SupabaseClient.new(self, url, anon_key)
	service_client = SupabaseClient.new(self, url, service_key)
	assert_cond(anon_client.get_identity().is_anon())
	assert_cond(service_client.get_identity().is_service())


func setup_users():
	var login = await logged_client.auth.login_email(BASE_EMAIL, BASE_PASSWORD).async()
	if login.is_error():
		var signup = await logged_client.auth.signup_email(BASE_EMAIL, BASE_PASSWORD).async()
		assert_cond(not signup.is_error())
		login = await logged_client.auth.login_email(BASE_EMAIL, BASE_PASSWORD).async()
	assert_cond(not login.is_error())
	assert_cond(logged_client.get_identity().is_authenticated())


func setup_tables():
	var pg = service_client.pg
	var result = await pg.query("DROP TABLE IF EXISTS %s;" % pg.sql_identifier(BASE_TABLE)).async()
	if not assert_cond(!result.is_error()):
		return ""
	var table = await pg.create_table(BASE_TABLE).async()
	assert_cond(!table.is_error())
	return table.id.as_string()
