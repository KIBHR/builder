extends SceneTree
## Verify onboarding and provider selection do not require connected accounts.
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var app: Control = packed.instantiate()
	root.add_child(app)
	if app.heading.text != "Рабочее пространство":
		push_error("Home screen failed to initialize")
		quit(1)
		return
	app._show_projects()
	if app.heading.text != "Мои проекты":
		push_error("Project screen failed to initialize")
		quit(1)
		return
	app._show_manual_project()
	if app.heading.text != "Добавить репозиторий вручную":
		push_error("Manual project form failed to initialize")
		quit(1)
		return
	app._show_chat()
	var chat: VBoxContainer = app.chat_panel
	if not chat.visible or chat.provider_select.item_count != 4:
		push_error("AI connection selector is not available")
		quit(1)
		return
	if chat.setup_button == null or chat.local_refresh_button == null:
		push_error("Simplified AI onboarding controls are missing")
		quit(1)
		return
	chat.provider_select.select(1)
	chat._select_provider(1, false)
	if chat.ai_provider != "ollama" or chat.local_client.provider != "ollama":
		push_error("Ollama backend was not selected")
		quit(1)
		return
	chat.provider_select.select(2)
	chat._select_provider(2, false)
	if chat.ai_provider != "lm_studio" or chat.local_client.provider != "lm_studio":
		push_error("LM Studio backend was not selected")
		quit(1)
		return
	app._show_home()
	if app.heading.text != "Рабочее пространство":
		push_error("Navigation back to home failed")
		quit(1)
		return
	print("Builder quick-start and AI provider smoke checks passed.")
	quit(0)
