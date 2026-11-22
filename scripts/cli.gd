extends RefCounted
## No shell evaluation: commands are executed using a literal argv array.
## MVP executes synchronously; long operations may temporarily block the window.

static func run(executable: String, arguments: Array) -> Dictionary:
	var argv := PackedStringArray()
	for argument in arguments:
		argv.append(str(argument))
	var output: Array = []
	var exit_code: int = OS.execute(executable, argv, output, true)
	var combined := ""
	for item in output:
		combined += str(item)
	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"output": combined.strip_edges()
	}


static func valid_repository(full_name: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
	return regex.search(full_name) != null and not full_name.contains("..")


static func valid_login(login: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9][A-Za-z0-9-]{0,38}$")
	return regex.search(login) != null
