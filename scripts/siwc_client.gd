extends Node
## Godot frontend for the official ChatGPT OAuth SDK running in a local Node process.
## OAuth tokens stay in the bridge; Godot only receives safe account/response data.

signal bridge_ready()
signal bridge_failed(reason: String)
signal session_changed(session: Dictionary)
signal models_changed(models: Array)
signal response_received(text: String)
signal response_failed(reason: String)
signal sign_in_failed(reason: String)

var node_binary := "node"
var session: Dictionary = {"status": "disconnected", "sharing": false}
var models: Array = []
var _port := 0
var _secret := ""
var _pid := -1
var _ready := false
var _launch_time := 0
var _handshake_file := ""
var _poll_timer: Timer
var _heartbeat_timer: Timer
var _chat_busy := false
var _login_busy := false


func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.25
	_poll_timer.timeout.connect(_poll_bridge)
	add_child(_poll_timer)
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = 30.0
	_heartbeat_timer.timeout.connect(func(): if _ready: _send("/health", HTTPClient.METHOD_GET, {}, "heartbeat"))
	add_child(_heartbeat_timer)


func start(executable: String = "node") -> void:
	if _pid > 0 or _ready:
		return
	node_binary = executable
	var entry := ProjectSettings.globalize_path("res://bridge/server.mjs")
	var dependency := ProjectSettings.globalize_path("res://third_party/siwc-devkit/packages/local/dist/index.js")
	if not FileAccess.file_exists(entry) or not FileAccess.file_exists(dependency):
		bridge_failed.emit("Не установлен официальный DevKit. Выполните: node bridge/setup.mjs")
		return
	var state_dir := ProjectSettings.globalize_path("user://siwc")
	if DirAccess.make_dir_recursive_absolute(state_dir) != OK:
		bridge_failed.emit("Невозможно создать локальный каталог авторизации.")
		return
	_handshake_file = state_dir.path_join("bridge-handshake.json")
	if FileAccess.file_exists(_handshake_file):
		DirAccess.remove_absolute(_handshake_file)
	_launch_time = Time.get_ticks_msec()
	_pid = OS.create_process(node_binary, [entry, state_dir, _handshake_file])
	if _pid <= 0:
		_pid = -1
		bridge_failed.emit("Не удалось запустить Node.js. Проверьте путь к node в настройках.")
		return
	_poll_timer.start()


func is_available() -> bool:
	return _ready


func is_busy() -> bool:
	return _chat_busy or _login_busy


func can_chat() -> bool:
	return _ready and bool(session.get("sharing", false)) and not models.is_empty()


func sign_in() -> void:
	if not _ready:
		sign_in_failed.emit("Локальный компонент ChatGPT не запущен. Сначала выполните установку.")
		return
	if _login_busy or _chat_busy:
		sign_in_failed.emit("Подождите завершения предыдущего действия.")
		return
	_login_busy = true
	_send("/signin", HTTPClient.METHOD_POST, {}, "signin", 650.0)


func disconnect() -> void:
	if _ready and not is_busy():
		_send("/disconnect", HTTPClient.METHOD_POST, {}, "disconnect")


func refresh() -> void:
	if _ready:
		_send("/session", HTTPClient.METHOD_GET, {}, "session")


func ask(text: String, history: Array, model: String, instructions: String) -> bool:
	if not can_chat() or is_busy():
		response_failed.emit("Необходимо войти через ChatGPT и разрешить использование подписки.")
		return false
	if text.is_empty() or text.length() > 72_000:
		response_failed.emit("Некорректная длина сообщения.")
		return false
	var messages: Array = []
	var first: int = maxi(0, history.size() - 10)
	for index in range(first, history.size()):
		var item: Variant = history[index]
		if item is Dictionary:
			var role: String = str(item.get("role", ""))
			if role == "user" or role == "assistant":
				messages.append({"role": role, "content": str(item.get("content", ""))})
	messages.append({"role": "user", "content": text})
	_chat_busy = true
	_send("/chat", HTTPClient.METHOD_POST, {
		"model": model,
		"instructions": instructions,
		"messages": messages,
	}, "chat", 190.0)
	return true


func cancel() -> void:
	if _ready:
		_send("/cancel", HTTPClient.METHOD_POST, {}, "cancel")


func _poll_bridge() -> void:
	if Time.get_ticks_msec() - _launch_time > 12_000:
		_poll_timer.stop()
		bridge_failed.emit("Локальный ChatGPT-компонент не ответил. Запустите node bridge/server.mjs в терминале для диагностики.")
		return
	if not FileAccess.file_exists(_handshake_file):
		return
	var file := FileAccess.open(_handshake_file, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	if int(parsed.get("pid", -1)) != _pid:
		return
	_port = int(parsed.get("port", 0))
	_secret = str(parsed.get("secret", ""))
	if _port <= 0 or _port > 65535 or _secret.length() != 64:
		bridge_failed.emit("Получены некорректные параметры локального компонента.")
		return
	_poll_timer.stop()
	DirAccess.remove_absolute(_handshake_file)
	_ready = true
	_heartbeat_timer.start()
	bridge_ready.emit()
	refresh()


func _send(path: String, method: int, data: Dictionary, action: String, timeout_seconds: float = 30.0) -> void:
	if not _ready:
		return
	var req := HTTPRequest.new()
	req.timeout = timeout_seconds
	req.max_redirects = 0
	add_child(req)
	req.request_completed.connect(func(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray):
		req.queue_free()
		_process_result(action, result, status, bytes)
	)
	var headers := PackedStringArray(["X-Builder-Session: " + _secret, "Content-Type: application/json"])
	var url := "http://127.0.0.1:%d%s" % [_port, path]
	var body := JSON.stringify(data) if method == HTTPClient.METHOD_POST else ""
	var result: Error = req.request(url, headers, method, body)
	if result != OK:
		req.queue_free()
		_process_result(action, -1, 0, PackedByteArray())


func _process_result(action: String, result: int, status: int, bytes: PackedByteArray) -> void:
	if action == "heartbeat":
		return
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	var valid := result == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300 and data is Dictionary
	if not valid:
		var reason := "Не удалось связаться с локальным ChatGPT-компонентом (HTTP %d)." % status
		if data is Dictionary:
			reason = str(data.get("error", reason))
		if action == "signin":
			_login_busy = false
			sign_in_failed.emit(reason)
		elif action == "chat":
			_chat_busy = false
			response_failed.emit(reason)
		else:
			bridge_failed.emit(reason)
		return
	match action:
		"session", "signin", "disconnect":
			if action == "signin":
				_login_busy = false
			var new_session: Variant = data.get("session", {})
			if new_session is Dictionary:
				session = new_session
				session_changed.emit(session)
				if bool(session.get("sharing", false)):
					_send("/models", HTTPClient.METHOD_GET, {}, "models", 75.0)
				else:
					models = []
					models_changed.emit(models)
		"models":
			var values: Variant = data.get("models", [])
			if values is Array:
				models = values
				models_changed.emit(models)
		"chat":
			_chat_busy = false
			response_received.emit(str(data.get("text", "")))


func _exit_tree() -> void:
	# Shut down only the process launched by this particular Godot instance.
	if _pid > 0:
		OS.kill(_pid)
		_pid = -1
