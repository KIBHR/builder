extends RefCounted
## Parse the public, token-free part of gh auth status --json hosts.
## Never persist credentials, tokenSource secrets, or complete raw CLI output.

const CLI = preload("res://scripts/cli.gd")


static func parse_accounts(raw: String) -> Dictionary:
	var result := {"accounts": [], "active": "", "error": ""}
	var data: Variant = JSON.parse_string(raw)
	if not (data is Dictionary):
		result["error"] = "GitHub CLI вернул некорректный JSON. Обновите gh."
		return result
	var hosts: Variant = data.get("hosts", {})
	if not (hosts is Dictionary):
		result["error"] = "Не удалось прочитать список GitHub-аккаунтов."
		return result
	var entries: Variant = hosts.get("github.com", [])
	if not (entries is Array):
		result["error"] = "Некорректный формат списка github.com."
		return result
	var names: Array = []
	for item in entries:
		if not (item is Dictionary):
			continue
		var login := str(item.get("login", "")).strip_edges()
		var state := str(item.get("state", ""))
		if not CLI.valid_login(login) or names.has(login):
			continue
		# Unusable tokens should not appear as selectable authenticated accounts.
		if state != "success":
			continue
		names.append(login)
		if bool(item.get("active", false)):
			result["active"] = login
	result["accounts"] = names
	return result
