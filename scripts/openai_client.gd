extends Node
## OpenAI Responses API client. Credentials exist only in memory.
signal answered(text: String)
signal failed(reason: String)

const ENDPOINT := "https://api.openai.com/v1/responses"
const MAX_HISTORY_MESSAGES := 10

var _api_key := ""
var _busy := false
var _request: HTTPRequest


func _ready() -> void:
	_api_key = OS.get_environment("OPENAI_API_KEY").strip_edges()
	_request = HTTPRequest.new()
	_request.timeout = 180.0
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)


func has_key() -> bool:
	return not _api_key.is_empty()


func is_busy() -> bool:
	return _busy


func set_session_key(key: String) -> bool:
	var clean := key.strip_edges()
	if clean.is_empty() or clean.contains("\n") or clean.contains("\r"):
		return false
	_api_key = clean
	return true


func clear_session_key() -> void:
	_api_key = ""


func ask(message: String, history: Array, model: String, instructions: String) -> bool:
	if _busy:
		return false
	if not has_key():
		failed.emit("Нужен API-ключ OpenAI (OPENAI_API_KEY или поле ввода в Builder).")
		return false
	var entries: Array = []
	var start: int = maxi(0, history.size() - MAX_HISTORY_MESSAGES)
	for index in range(start, history.size()):
		var record: Variant = history[index]
		if record is Dictionary:
			var role: String = str(record.get("role", ""))
			if role == "user" or role == "assistant":
				entries.append({"role": role, "content": str(record.get("content", ""))})
	entries.append({"role": "user", "content": message})
	var payload := {
		"model": model,
		"instructions": instructions,
		"input": entries,
		"store": false,
		"max_output_tokens": 4096
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + _api_key
	])
	_busy = true
	var result: Error = _request.request(ENDPOINT, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if result != OK:
		_busy = false
		failed.emit("Запрос не отправлен (ошибка Godot: %s)." % str(result))
		return false
	return true


func cancel() -> void:
	if _busy:
		_request.cancel_request()
		_busy = false
		failed.emit("Запрос отменён.")


func _on_request_completed(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	if not _busy:
		return
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Сетевая ошибка (%s). Проверьте подключение к api.openai.com." % str(result))
		return
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if status < 200 or status >= 300:
		var reason := "HTTP %s" % str(status)
		if status == 401:
			reason += ": проверьте API-ключ."
		elif status == 429:
			reason += ": исчерпан лимит API или слишком много запросов."
		elif status == 402:
			reason += ": проверьте оплату API."
		elif data is Dictionary:
			var info: Variant = data.get("error", {})
			if info is Dictionary:
				reason += ": " + str(info.get("message", "Ошибка API")).substr(0, 220)
		failed.emit(reason)
		return
	if not (data is Dictionary):
		failed.emit("Сервер вернул ответ в неизвестном формате.")
		return
	var output: Variant = data.get("output", [])
	var parts := PackedStringArray()
	if output is Array:
		for item in output:
			if item is Dictionary and str(item.get("type", "")) == "message":
				var blocks: Variant = item.get("content", [])
				if blocks is Array:
					for block in blocks:
						if block is Dictionary and str(block.get("type", "")) == "output_text":
							parts.append(str(block.get("text", "")))
	var combined := "\n".join(parts).strip_edges()
	if combined.is_empty():
		failed.emit("Модель не вернула текст. Попробуйте другую модель или повторите запрос.")
		return
	answered.emit(combined)
