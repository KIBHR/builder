extends SceneTree

const GitHubAuth = preload("res://scripts/github_auth.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := JSON.stringify({"hosts": {"github.com": [
		{"login": "alpha-01", "state": "success", "active": false},
		{"login": "beta-02", "state": "success", "active": true},
		{"login": "expired", "state": "error", "active": false},
		{"login": "not valid!", "state": "success", "active": false}
	]}})
	var account_status := GitHubAuth.parse_accounts(fixture)
	if account_status["active"] != "beta-02":
		push_error("Active GitHub account was not resolved")
		quit(1)
		return
	if account_status["accounts"] != ["alpha-01", "beta-02"]:
		push_error("Could not enumerate valid accounts: " + str(account_status["accounts"]))
		quit(1)
		return
	var invalid_status := GitHubAuth.parse_accounts("not-json")
	if str(invalid_status["error"]).is_empty():
		push_error("Invalid gh JSON should produce a helpful error")
		quit(1)
		return
	var app: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app._show_chat()
	var siwc: Node = app.chat_panel.siwc
	# Simulate a fast bridge response, then a late OAuth callback result.
	siwc._connected = true
	siwc._login_busy = true
	siwc._auth_started_ticks = Time.get_ticks_msec()
	siwc._process_result("signin", HTTPRequest.RESULT_SUCCESS, 202, JSON.stringify({"started": true}).to_utf8_buffer())
	if siwc._auth_timer.is_stopped() or not siwc._login_busy:
		push_error("OAuth request must remain pending until callback")
		quit(1)
		return
	siwc._process_result("auth_status", HTTPRequest.RESULT_SUCCESS, 200,
		JSON.stringify({"auth": {"phase": "failed", "error": {"error": "Callback did not finish"}}}).to_utf8_buffer())
	if siwc._login_busy or siwc._auth_timer.is_stopped() == false:
		push_error("A failed callback must allow retry")
		quit(1)
		return
	print("Builder GitHub accounts and ChatGPT callback tests passed.")
	quit(0)
