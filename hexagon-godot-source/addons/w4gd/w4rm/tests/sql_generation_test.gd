extends "../../testing/base_test.gd"

const W4RM = preload("../w4rm.gd")
const W4RMTable = preload("../w4rm_table.gd")
const W4RMMapper = preload("../w4rm_mapper.gd")
const SQL = preload("../w4rm_sql.gd")

var whitespace_re: RegEx


func _init():
	super()

	whitespace_re = RegEx.new()
	whitespace_re.compile("\\s+")


func trim(s: String) -> String:
	return whitespace_re.sub(s, ' ', true).strip_edges()


class RLSTest:
	var id := &""

	static func _w4rm_security_policies(policies):
		policies["Default policy"] = W4RM.security_policy({
			using = "true",
			with_check = "true",
		})
		policies["Insert policy"] = W4RM.security_policy({
			roles = ['authenticated'],
			command = W4RMTable.W4RMCommand.INSERT,
			with_check = "user = auth.uid()",
		})
		policies["Select policy"] = W4RM.security_policy({
			roles = ['anon'],
			command = W4RMTable.W4RMCommand.SELECT,
			using = "is_public = true",
		})
		policies["Restrictive policy"] = W4RM.security_policy({
			type = W4RMTable.W4RMSecurityPolicyType.RESTRICTIVE,
			using = "true",
			with_check = "true",
		})

func test_rls_policies():
	var mapper = W4RMMapper.new()
	var table = mapper.add_table("RLSTest", RLSTest)
	mapper.done()

	var expected = ["""
		ALTER TABLE \"RLSTest_table\" ENABLE ROW LEVEL SECURITY;
		""", """
		DROP POLICY IF EXISTS "Default policy" ON "RLSTest_table";
		CREATE POLICY "Default policy" ON "RLSTest_table"
		AS PERMISSIVE
		FOR ALL
		TO anon, authenticated
		USING (true)
		WITH CHECK (true);
	""", """
		DROP POLICY IF EXISTS "Insert policy" ON "RLSTest_table";
		CREATE POLICY "Insert policy" ON "RLSTest_table"
		AS PERMISSIVE
		FOR INSERT
		TO authenticated
		WITH CHECK (user = auth.uid());
	""", """
		DROP POLICY IF EXISTS "Select policy" ON "RLSTest_table";
		CREATE POLICY "Select policy" ON "RLSTest_table"
		AS PERMISSIVE
		FOR SELECT
		TO anon
		USING (is_public = true);
	""", """
		DROP POLICY IF EXISTS "Restrictive policy" ON "RLSTest_table";
		CREATE POLICY "Restrictive policy" ON "RLSTest_table"
		AS RESTRICTIVE
		FOR ALL
		TO anon, authenticated
		USING (true)
		WITH CHECK (true);
	"""]

	assert_equal(SQL.get_create_table_rls_policies(table), expected)


class DefaultTriggerTest:
	var id := &""

func test_default_triggers():
	var mapper = W4RMMapper.new()
	var table = mapper.add_table("DefaultTriggerTest", DefaultTriggerTest)
	mapper.done()

	var expected = ["""
		CREATE OR REPLACE FUNCTION DefaultTriggerTest_table_before_insert_trigger() RETURNS TRIGGER LANGUAGE plpgsql
		AS $BODY$
		BEGIN

			NEW."id" := extensions.uuid_generate_v4();

			return NEW;

		END;
		$BODY$;

		CREATE OR REPLACE TRIGGER DefaultTriggerTest_table_before_insert_trigger
		BEFORE INSERT ON "DefaultTriggerTest_table"
		FOR EACH ROW
		EXECUTE FUNCTION DefaultTriggerTest_table_before_insert_trigger();
	""", """
		CREATE OR REPLACE FUNCTION DefaultTriggerTest_table_before_update_trigger() RETURNS TRIGGER LANGUAGE plpgsql
		AS $BODY$
		BEGIN

			NEW."id" := OLD."id";

			return NEW;

		END;
		$BODY$;

		CREATE OR REPLACE TRIGGER DefaultTriggerTest_table_before_update_trigger
		BEFORE UPDATE ON "DefaultTriggerTest_table"
		FOR EACH ROW
		EXECUTE FUNCTION DefaultTriggerTest_table_before_update_trigger();
		"""]

	assert_equal(SQL.get_create_table_triggers(table).map(trim), expected.map(trim))


class TriggerBuilderTest:
	var id := &""
	var timestamp := ""
	var seconds_since_epoch := 0
	var with_default := ""

	static func _w4rm_type_options(opts):
		opts['with_default'] = W4RM.option({
			default = "'forever!'",
		})

	static func _w4rm_members(members):
		members['timestamp'] = &"timestamp"

	static func _w4rm_triggers(triggers, builder):
		builder.optional_default("id")
		builder.cannot_update("id")
		builder.force_current_time("timestamp")
		builder.force_current_time("seconds_since_epoch")
		builder.force_value_on_update("with_default", "'nope'")

func test_trigger_builder():
	var mapper = W4RMMapper.new()
	var table = mapper.add_table("TriggerBuilderTest", TriggerBuilderTest)
	mapper.done()

	var expected = ["""
		CREATE OR REPLACE FUNCTION TriggerBuilderTest_table_before_insert_trigger() RETURNS TRIGGER LANGUAGE plpgsql
		AS $BODY$
		BEGIN

			IF NEW."id" IS NULL THEN
				NEW."id" := extensions.uuid_generate_v4();
			END IF;

			NEW."timestamp" := CURRENT_TIMESTAMP();

			NEW."seconds_since_epoch" := FLOOR(EXTRACT(EPOCH FROM NOW()));

			return NEW;

		END;
		$BODY$;

		CREATE OR REPLACE TRIGGER TriggerBuilderTest_table_before_insert_trigger
		BEFORE INSERT ON "TriggerBuilderTest_table"
		FOR EACH ROW
		EXECUTE FUNCTION TriggerBuilderTest_table_before_insert_trigger();
	""", """
		CREATE OR REPLACE FUNCTION TriggerBuilderTest_table_before_update_trigger() RETURNS TRIGGER LANGUAGE plpgsql
		AS $BODY$
		BEGIN

			NEW."id" := OLD."id";

			NEW."timestamp" := CURRENT_TIMESTAMP();

			NEW."seconds_since_epoch" := FLOOR(EXTRACT(EPOCH FROM NOW()));

			NEW."with_default" := 'nope';

			return NEW;

		END;
		$BODY$;

		CREATE OR REPLACE TRIGGER TriggerBuilderTest_table_before_update_trigger
		BEFORE UPDATE ON "TriggerBuilderTest_table"
		FOR EACH ROW
		EXECUTE FUNCTION TriggerBuilderTest_table_before_update_trigger();
		"""]

	assert_equal(SQL.get_create_table_triggers(table).map(trim), expected.map(trim))

