extends "integration_base.gd"


func setup():
	await setup_users()


func delete_user(email):
	var result = await service_client.pg.query(
		"select id from auth.users where auth.users.email = %s;" %
		service_client.pg.sql_string(email)).async()
	if not assert_cond(!result.is_error()):
		return false
	if result.size():
		if not assert_equal(result.size(), 1):
			return false
		service_client.auth.admin.delete_user(result.get_at(0).id.as_string()).async()
		push_error("Deleted user: %s" % VOLATILE_EMAIL)
	return true


func test_settings_endpoint():
	var result = await anon_client.auth.get_settings().async()
	assert_cond(result.is_dict())


func test_signup():
	var valid = await delete_user(VOLATILE_EMAIL)
	if not assert_cond(valid):
		return
	var signup = await anon_client.auth.signup_email(VOLATILE_EMAIL, BASE_PASSWORD).async()
	if not assert_cond(signup.is_dict()):
		return
	var uid = signup.user.id.as_string()
	if uid.is_empty():
		return
	var res = await service_client.auth.admin.delete_user(uid).async()
	assert_cond(!res.is_error())


func test_logout():
	assert_cond(logged_client.get_identity().is_authenticated())
	var logout = await logged_client.auth.logout().async()
	assert_cond(!logout.is_error())
	assert_cond(logged_client.get_identity().is_anon())


func test_get_users():
	var result = await service_client.auth.admin.get_users().async()
	assert_cond(!result.is_error())
	assert_greater_then(result.size(), 0)


func test_get_user():
	var result = await logged_client.auth.get_user().async()
	assert_cond(!result.is_error())
	assert_equal(result.email.as_string(), BASE_EMAIL)


func test_put_user():
	var result = await logged_client.auth.update_user({}).async()
	assert_cond(!result.is_error())
	result = await logged_client.auth.update_user({
		"data": {
			"test": "ci"
		}
	}).async()
	assert_cond(!result.is_error())
	result = await logged_client.auth.get_user().async()
	assert_cond(!result.is_error())
	assert_equal(result.user_metadata.test.as_string(), "ci")
	result = await logged_client.auth.update_user({}).async()
