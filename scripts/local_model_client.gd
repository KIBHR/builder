extends Node
## Local AI model clients. Localhost-only, no account credentials or API keys.
## Ollama: http://127.0.0.1:11434/api ; LM Studio: http://127.0.0.1:1234/v1
signal models_received(models: Array)
signal answered(text: String)
signal failed(reason: String)
signal connection_changed(connected: bool, detail: String)

const PROVIDER_OLLAMA := "ollama"
const PROVIDER_LM_STUDIO := "lm_studio"
const MAX_HISTORY_MESSAGES := 10

var provider := PROVIDER_OLLAMA
var models: Array = []
var busy := false
var _generation_request: HTTPRequest
var _models_request: HTTPRequest
var _request_epoch := 0


func _ready() -> void:
	_models_request = HTTPRequest.new()
	_models_request.timeout = 9.0
	add_child(_models_request)
	_models_request.request_completed.connect(_on_models_completed)
	_generation_request = HTTPRequest.new()
	_generation_request.timeout = 240.0
	add_child(_generation_request)
	_generation_request.request_completed.connect(_on_generation_completed)


func _base_url() -> String:
	return "http://127.0.0.1:11434" if provider == PROVIDER_OLLAMA else "http://127.0.0.1:1234"


func set_provider(value: String) -> void:
	if value != PROVIDER_OLLAMA and value != PROVIDER_LM_STUDIO:
		return
	if provider != value:
		cancel()
		_models_request.cancel_request()
		provider = value
		models.clear()
		_request_epoch += 1
		models_received.emit(models)


func refresh_models() -> void:
	if busy:
		return
	_models_request.cancel_request()
	var endpoint := "/api/tags" if provider == PROVIDER_OLLAMA else "/v1/models"
	var result := _models_request.request(_base_url() + endpoint)
	if result != OK:
		models.clear()
		models_received.emit(models)
		connection_changed.emit(false, "Не удалось обратиться к локальному серверу ИИ.")


func _on_models_completed(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	models.clear()
	if result != HTTPRequest.RESULT_SUCCESS or status != 200:
		models_received.emit(models)
		var name := "Ollama" if provider == PROVIDER_OLLAMA else "LM Studio"
		connection_changed.emit(false, name + " недоступен. Запустите его локальный сервер и обновите список.")
		return
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not (parsed is Dictionary):
		models_received.emit(models)
		connection_changed.emit(false, "Неверный ответ сервера моделей.")
		return
	var items: Variant = parsed.get("models", []) if provider == PROVIDER_OLLAMA else parsed.get("data", [])
	if items is Array:
		for item in items:
			if item is Dictionary:
				var label := str(item.get("name", "")) if provider == PROVIDER_OLLAMA else str(item.get("id", ""))
				if not label.is_empty():
					models.append(label)
	models.sort()
	models_received.emit(models)
	connection_changed.emit(true, "Подключено. Моделей: " + str(models.size()) if not models.is_empty() else "Сервер доступен, но модели пока не загружены.")


func ask(message: String, history: Array, model: String, instructions: String) -> bool:
	if busy:
		return false
	if not models.has(model):
		failed.emit("Выберите модель из списка доступных.")
		return false
	if message.is_empty() or message.length() > 72000:
		failed.emit("Сообщение слишком длинное или пустое.")
		return false
	var entries: Array = [{"role": "system", "content": instructions}]
	var start := maxi(0, history.size() - MAX_HISTORY_MESSAGES)
	for index in range(start, history.size()):
		var item: Variant = history[index]
		if item is Dictionary and str(item.get("role", "")) in ["user", "assistant"]:
			entries.append({"role": str(item["role"]), "content": str(item.get("content", ""))})
	entries.append({"role": "user", "content": message})
	var payload := {"model": model, "messages": entries, "stream": false}
	var endpoint := "/api/chat" if provider == PROVIDER_OLLAMA else "/v1/chat/completions"
	var result := _generation_request.request(
		_base_url() + endpoint,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if result != OK:
		failed.emit("Локальный сервер отказался принять запрос: " + str(result))
		return false
	busy = true
	return true


func cancel() -> void:
	if busy:
		_generation_request.cancel_request()
		busy = false
		failed.emit("Локальный запрос отменён.")


func _on_generation_completed(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	if not busy:
		return
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Не удалось получить ответ локальной модели: код " + str(result))
		return
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if status < 200 or status >= 300:
		var error_message := "HTTP " + str(status) + ". Проверьте, что модель загружена и сервер запущен."
		if parsed is Dictionary:
			error_message += " " + str(parsed.get("error", "")).substr(0, 160)
		failed.emit(error_message)
		return
	if not (parsed is Dictionary):
		failed.emit("Локальная модель вернула неожиданный формат.")
		return
	var text := ""
	if provider == PROVIDER_OLLAMA:
		var message: Variant = parsed.get("message", {})
		if message is Dictionary:
			text = str(message.get("content", ""))
	else:
		var choices: Variant = parsed.get("choices", [])
		if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
			var first: Dictionary = choices[0]
			var message: Variant = first.get("message", {})
			if message is Dictionary:
				text = str(message.get("content", ""))
	if text.strip_edges().is_empty():
		failed.emit("Модель не вернула текст. Возможно, выбранная модель не поддерживает чат.")
	else:
		answered.emit(text)
