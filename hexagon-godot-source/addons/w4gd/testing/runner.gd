extends SceneTree

const Tester = preload("tester.gd")

var tester = Tester.new()
var json = JSON.new()
var tests = []

var files = 0
var errors = 0
var failed = 0
var passed = 0
var skipped = 0


func done():
	print("Tests done.")
	print("Files: ", files)
	print("File errors: ", errors)
	print("Tests: ", failed + skipped + passed)
	print("Passed: ", passed)
	print("Skipped: ", skipped)
	print("Failed: ", failed)
	quit(failed + errors)


func _file_done(file : String, err : int):
	if err:
		print("FAIL: Running file %s failed." % file)
		errors += 1
	else:
		print("DONE: Running file %s done." % file)
	_next_test()


func _test_done(file : String, method : String, logs : Array, err : int, skip : bool):
	if not skip:
		if err:
			print("FAIL: %s|%s with result %d." % [file, method, err])
			print(json.stringify(logs, " ", true))
			failed += 1
		else:
			print("PASS: %s|%s." % [file, method])
			passed += 1
	else:
		skipped += 1
		print("SKIP: %s|%s." % [file, method])


func _initialize():
	root.add_child(tester)
	tester.file_done.connect(_file_done, Node.CONNECT_DEFERRED)
	tester.test_done.connect(_test_done, Node.CONNECT_DEFERRED)
	var dir = DirAccess.open(".")
	for a in OS.get_cmdline_user_args():
		if _is_gd_test(a):
			tests.append(a)
		elif dir.dir_exists(a):
			var subdirs = [a]
			while subdirs:
				var d = subdirs.pop_front()
				_expand(d, subdirs, tests)

	print("Running %d test file(s):\n%s" % [tests.size(), tests])
	_next_test()


func _next_test():
	if tests.is_empty():
		done.call_deferred()
	else:
		files += 1
		var test = tests.pop_front()
		tester.run_file(test)


func _is_gd_test(fname : String):
	return fname.ends_with("_test.gd")


func _expand(p_name, r_dirs, r_tests):
	var dir = DirAccess.open(".")
	if dir.change_dir(p_name) != OK:
		print("Unable to chdir into: %s" % p_name)
		return
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if dir.current_is_dir():
			r_dirs.append("%s/%s" % [p_name, f])
		if _is_gd_test(f):
			r_tests.append("%s/%s" % [p_name, f])
		f = dir.get_next()
	dir.list_dir_end()
