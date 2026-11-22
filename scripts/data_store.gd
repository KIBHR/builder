extends RefCounted
## Local preferences only. Never persist GitHub access tokens or browser cookies.

const CONFIG_PATH := "user://builder.json"

static func defaults() -> Dictionary:
	return {
		"accounts": [],
		"active_account": "",
		"projects": [],
		"git_binary": "git",
		"gh_binary": "gh",
		"ai_model": "gpt-6.2-sol"
	}


static func read() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return defaults()
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return defaults()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return defaults()
	var data: Dictionary = defaults()
	for key in data.keys():
		if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]):
			data[key] = parsed[key]
	return data


static func write(data: Dictionary) -> bool:
	# Write to a temporary file first to avoid truncating a valid configuration.
	var temporary := CONFIG_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(CONFIG_PATH)) == OK
