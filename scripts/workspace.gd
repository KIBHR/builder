extends Control
## Builder MVP: a local-first GitHub workspace. The GitHub CLI manages credentials.
## No automatic billing-account rotation or workflow dispatch is performed.

const Store = preload("res://scripts/data_store.gd")
const CLI = preload("res://scripts/cli.gd")
const ChatPanel = preload("res://scripts/chat_panel.gd")

var config: Dictionary = {}
var body: VBoxContainer
var heading: Label
var status_label: Label
var content_scroll: ScrollContainer
var chat_panel
var window_mode_button: Button
var previous_window_mode: int = Window.MODE_WINDOWED
var window_restore_size := Vector2i(1180, 760)
var window_restore_position := Vector2i(100, 100)


func _ready() -> void:
	config = Store.read()
	_build_shell()
	_show_projects()


func _build_shell() -> void:
	var base := Color("#101827")
	var surface := Color("#1a2538")
	var text_color := Color("#e9f0fc")
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var background := ColorRect.new()
	background.color = base
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(245, 0)
	var side_style := StyleBoxFlat.new()
	side_style.bg_color = surface
	side_style.set_content_margin_all(18)
	sidebar.add_theme_stylebox_override("panel", side_style)
	root.add_child(sidebar)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	sidebar.add_child(menu)
	var brand := Label.new()
	brand.text = "BUILDER"
	brand.add_theme_font_size_override("font_size", 27)
	brand.add_theme_color_override("font_color", Color("#71c4ff"))
	menu.add_child(brand)
	_add_note(menu, "AI DEVELOPMENT WORKSPACE", Color("#98a7ba"))
	menu.add_child(HSeparator.new())
	_add_button(menu, "Репозитории", Callable(self, "_show_projects"))
	_add_button(menu, "ChatGPT · в Builder", Callable(self, "_show_chat"))
	_add_button(menu, "GitHub-аккаунты", Callable(self, "_show_accounts"))
	_add_button(menu, "Настройки", Callable(self, "_show_settings"))
	var push_down := Control.new()
	push_down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(push_down)
	_add_button(menu, "ChatGPT.com ↗", func(): OS.shell_open("https://chatgpt.com/"))
	_add_note(menu, "Встроенный чат использует OpenAI API.\nВеб-версия открывается отдельно.", Color("#98a7ba"))

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)
	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_right", 22)
	main.add_child(top)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	top.add_child(header_row)
	heading = Label.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_color_override("font_color", text_color)
	heading.add_theme_font_size_override("font_size", 28)
	header_row.add_child(heading)
	window_mode_button = Button.new()
	window_mode_button.custom_minimum_size = Vector2(185, 38)
	window_mode_button.tooltip_text = "Переключение оконного и полноэкранного режимов (F11)"
	window_mode_button.pressed.connect(_toggle_window_mode)
	header_row.add_child(window_mode_button)
	_update_window_button()
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(content_scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 13)
	var margins := MarginContainer.new()
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margins.add_theme_constant_override("margin_left", 2)
	margins.add_theme_constant_override("margin_right", 22)
	margins.add_theme_constant_override("margin_bottom", 18)
	content_scroll.add_child(margins)
	margins.add_child(body)
	chat_panel = ChatPanel.new()
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_panel.visible = false
	main.add_child(chat_panel)
	chat_panel.model_changed.connect(_on_ai_model_changed)
	status_label = Label.new()
	status_label.text = "Готово. Для приватных репозиториев выполните gh auth login в терминале."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#a4c7de"))
	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_right", 22)
	footer.add_theme_constant_override("margin_bottom", 14)
	main.add_child(footer)
	footer.add_child(status_label)


func _clear_page(title: String) -> void:
	chat_panel.hide()
	content_scroll.show()
	heading.text = title
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


func _add_note(parent: Node, content: String, tint: Color = Color("#b2c2d6")) -> Label:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


func _add_button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0, 38)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _field(parent: VBoxContainer, title: String, hint: String, initial: String = "") -> LineEdit:
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(holder)
	_add_note(holder, title)
	var input := LineEdit.new()
	input.placeholder_text = hint
	input.text = initial
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(input)
	return input


func _panel() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1b293c")
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	body.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	return inner


func _message(content: String, is_error: bool = false) -> void:
	status_label.text = content.substr(0, 420)
	status_label.add_theme_color_override("font_color", Color("#ffb6af") if is_error else Color("#a2e6b7"))


func _git() -> String:
	return str(config.get("git_binary", "git"))


func _gh() -> String:
	return str(config.get("gh_binary", "gh"))


func _save() -> bool:
	if not Store.write(config):
		_message("Не удалось записать настройки в user://builder.json", true)
		return false
	return true


func _show_projects() -> void:
	_clear_page("Репозитории")
	_add_note(body, "Локальная рабочая копия — источник для безопасной синхронизации зеркал. Публикация в зеркала производится только по подтверждению.")
	var form := _panel()
	_add_note(form, "Добавить проект", Color("#71c4ff"))
	var full_name := _field(form, "Основной репозиторий", "owner/repository")
	var path := _field(form, "Абсолютный путь к локальной копии", "/Users/you/Projects/project")
	var branch := _field(form, "Ветка синхронизации", "main", "main")
	var mirrors := _field(form, "Зеркала GitHub (через запятую)", "organization-a/project, organization-b/project")
	_add_button(form, "Добавить проект", func(): _add_project(full_name.text, path.text, branch.text, mirrors.text))
	var projects: Array = config.get("projects", [])
	if projects.is_empty():
		_add_note(body, "Проектов пока нет. Добавьте первый репозиторий выше.")
	for project in projects:
		if project is Dictionary:
			_project_card(project)


func _add_project(full_name: String, path: String, branch: String, mirror_input: String) -> void:
	full_name = full_name.strip_edges()
	path = path.strip_edges()
	branch = branch.strip_edges()
	if not CLI.valid_repository(full_name):
		_message("Укажите репозиторий в формате owner/repository.", true)
		return
	if path.is_empty() or not path.is_absolute_path():
		_message("Укажите абсолютный путь к локальному каталогу.", true)
		return
	if branch.is_empty() or branch.contains(" ") or branch.begins_with("-") or branch.contains("..") or branch.contains(":"):
		_message("Некорректное имя ветки.", true)
		return
	var mirror_names: Array = []
	for item in mirror_input.split(",", false):
		var candidate: String = item.strip_edges()
		if not CLI.valid_repository(candidate):
			_message("Некорректное зеркало: " + candidate, true)
			return
		if candidate == full_name or mirror_names.has(candidate):
			_message("Зеркало не должно совпадать с основным репозиторием или повторяться.", true)
			return
		mirror_names.append(candidate)
	for existing in config["projects"]:
		if existing.get("full_name", "") == full_name or existing.get("path", "") == path:
			_message("Этот репозиторий или путь уже добавлен.", true)
			return
	config["projects"].append({"full_name": full_name, "path": path, "branch": branch, "mirrors": mirror_names})
	if _save():
		_message("Проект добавлен: " + full_name)
		_show_projects()


func _project_card(project: Dictionary) -> void:
	var panel := _panel()
	var title := _add_note(panel, str(project.get("full_name", "")), Color("#e9f0fc"))
	title.add_theme_font_size_override("font_size", 20)
	_add_note(panel, "Путь: " + str(project.get("path", "")))
	_add_note(panel, "Ветка: " + str(project.get("branch", "main")) + "  |  зеркал: " + str(project.get("mirrors", []).size()))
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	panel.add_child(buttons)
	_add_button(buttons, "Клонировать", func(): _clone_project(project))
	_add_button(buttons, "Обновить (fetch)", func(): _fetch_project(project))
	_add_button(buttons, "Синхронизировать зеркала", func(): _confirm_mirror_push(project))
	_add_button(buttons, "Последний Actions", func(): _check_actions(project))
	_add_button(buttons, "GitHub ↗", func(): OS.shell_open("https://github.com/" + str(project["full_name"])))
	_add_button(buttons, "Удалить из списка", func(): _remove_project(project))


func _remove_project(project: Dictionary) -> void:
	config["projects"].erase(project)
	if _save():
		_message("Проект удалён из списка. Локальные файлы не удалялись.")
		_show_projects()


func _clone_project(project: Dictionary) -> void:
	var target: String = str(project["path"])
	if DirAccess.dir_exists_absolute(target) or FileAccess.file_exists(target):
		_message("Путь уже существует. Клонирование отменено во избежание потери файлов.", true)
		return
	var mkerr := DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if mkerr != OK:
		_message("Не удалось создать родительскую директорию: " + str(mkerr), true)
		return
	var result: Dictionary = CLI.run(_git(), ["clone", "https://github.com/" + str(project["full_name"]) + ".git", target])
	_message("Репозиторий клонирован: " + target if result["ok"] else "Клонирование не удалось: " + str(result["output"]), not result["ok"])


func _fetch_project(project: Dictionary) -> void:
	var path: String = str(project["path"])
	if not DirAccess.dir_exists_absolute(path):
		_message("Сначала клонируйте проект.", true)
		return
	var result: Dictionary = CLI.run(_git(), ["-C", path, "fetch", "origin", "--prune"])
	_message("Обновлены ссылки на ветки origin. Локальный код не изменён." if result["ok"] else "Ошибка fetch: " + str(result["output"]), not result["ok"])


func _confirm_mirror_push(project: Dictionary) -> void:
	if project.get("mirrors", []).is_empty():
		_message("У этого проекта не заданы зеркала.", true)
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Подтвердите синхронизацию"
	dialog.dialog_text = "Из локальной ветки " + str(project["branch"]) + " будут отправлены коммиты в зеркала. Push может запустить GitHub Actions в каждом зеркале. Принудительная перезапись запрещена."
	dialog.confirmed.connect(func():
		_sync_mirrors(project)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _matches_origin(remote_url: String, full_name: String) -> bool:
	var normalized := remote_url.strip_edges().trim_suffix(".git")
	return normalized.ends_with("/" + full_name) or normalized.ends_with(":" + full_name)


func _sync_mirrors(project: Dictionary) -> void:
	var path: String = str(project["path"])
	var branch: String = str(project["branch"])
	if not DirAccess.dir_exists_absolute(path):
		_message("Рабочая копия не найдена.", true)
		return
	var origin: Dictionary = CLI.run(_git(), ["-C", path, "remote", "get-url", "origin"])
	if not origin["ok"] or not _matches_origin(str(origin["output"]), str(project["full_name"])):
		_message("Адрес origin не совпадает с ожидаемым репозиторием. Push отменён.", true)
		return
	var clean: Dictionary = CLI.run(_git(), ["-C", path, "status", "--porcelain"])
	if not clean["ok"] or not str(clean["output"]).is_empty():
		_message("В рабочей копии есть незакоммиченные изменения или ошибка Git. Push отменён.", true)
		return
	var fetched: Dictionary = CLI.run(_git(), ["-C", path, "fetch", "origin", "--prune"])
	if not fetched["ok"]:
		_message("Не удалось обновить origin: " + str(fetched["output"]), true)
		return
	var local: Dictionary = CLI.run(_git(), ["-C", path, "rev-parse", "refs/heads/" + branch])
	var upstream: Dictionary = CLI.run(_git(), ["-C", path, "rev-parse", "refs/remotes/origin/" + branch])
	if not local["ok"] or not upstream["ok"] or local["output"] != upstream["output"]:
		_message("Ветки origin и локальная разошлись или не совпадают. Сначала выполните merge/rebase вручную.", true)
		return
	var mirrored := 0
	var errors: Array = []
	var index := 0
	for mirror in project["mirrors"]:
		var remote_name := "builder_mirror_" + str(index)
		index += 1
		var url := "https://github.com/" + str(mirror) + ".git"
		var current: Dictionary = CLI.run(_git(), ["-C", path, "remote", "get-url", remote_name])
		if current["ok"] and str(current["output"]) != url:
			errors.append(str(mirror) + ": другое назначение remote " + remote_name)
			continue
		if not current["ok"]:
			var added: Dictionary = CLI.run(_git(), ["-C", path, "remote", "add", remote_name, url])
			if not added["ok"]:
				errors.append(str(mirror) + ": не удалось добавить remote")
				continue
		var pushed: Dictionary = CLI.run(_git(), ["-C", path, "push", "--porcelain", remote_name, "refs/heads/" + branch + ":refs/heads/" + branch])
		if pushed["ok"]:
			mirrored += 1
		else:
			errors.append(str(mirror) + ": " + str(pushed["output"]).substr(0, 120))
	var summary := "Зеркала: успешно " + str(mirrored) + "/" + str(project["mirrors"].size())
	if not errors.is_empty():
		summary += ". Ошибки: " + "; ".join(PackedStringArray(errors))
	_message(summary, not errors.is_empty())


func _check_actions(project: Dictionary) -> void:
	var full_name: String = str(project["full_name"])
	var result: Dictionary = CLI.run(_gh(), ["api", "repos/" + full_name + "/actions/runs?per_page=1"])
	if not result["ok"]:
		_message("Ошибка GitHub CLI: " + str(result["output"]) + ". Проверьте gh auth login.", true)
		return
	var data: Variant = JSON.parse_string(result["output"])
	if not (data is Dictionary) or not (data.get("workflow_runs", []) is Array):
		_message("GitHub вернул неожиданный формат ответа.", true)
		return
	var runs: Array = data["workflow_runs"]
	if runs.is_empty():
		_message("Для " + full_name + " запусков GitHub Actions не найдено.")
		return
	var run: Dictionary = runs[0]
	_message("Последний запуск: " + str(run.get("name", "Workflow")) + " — " + str(run.get("status", "?")) + "/" + str(run.get("conclusion", "?")) + ". Это НЕ показатель оставшегося лимита Actions.")


func _show_accounts() -> void:
	_clear_page("GitHub-аккаунты")
	_add_note(body, "Добавляйте только аккаунты, которыми имеете право пользоваться. Авторизация выполняется официальной утилитой gh; токены Builder не читает и не хранит.")
	var form := _panel()
	_add_note(form, "Подключение учётной записи", Color("#71c4ff"))
	_add_note(form, "Сначала в терминале выполните: gh auth login -h github.com")
	var login := _field(form, "GitHub username", "username")
	_add_button(form, "Добавить в Builder", func(): _add_account(login.text))
	for account in config["accounts"]:
		var row := _panel()
		_add_note(row, "@" + str(account), Color("#e9f0fc"))
		var button_row := HBoxContainer.new()
		row.add_child(button_row)
		_add_button(button_row, "Активировать в gh", func(): _activate_account(str(account)))
		_add_button(button_row, "Убрать из списка", func(): _remove_account(str(account)))
	_add_note(body, "Внимание: gh auth switch меняет активную учётную запись GitHub CLI для github.com на этом компьютере. Это не меняет владельца и лимиты существующего репозитория.")


func _add_account(login: String) -> void:
	login = login.strip_edges()
	if not CLI.valid_login(login):
		_message("Недопустимый GitHub username.", true)
		return
	if config["accounts"].has(login):
		_message("Аккаунт уже добавлен.", true)
		return
	config["accounts"].append(login)
	if _save():
		_message("Добавлен @" + login + ". Активируйте его после gh auth login.")
		_show_accounts()


func _remove_account(login: String) -> void:
	config["accounts"].erase(login)
	if config.get("active_account", "") == login:
		config["active_account"] = ""
	if _save():
		_message("Аккаунт удалён из списка Builder; авторизация gh не затронута.")
		_show_accounts()


func _activate_account(login: String) -> void:
	var result: Dictionary = CLI.run(_gh(), ["auth", "switch", "--hostname", "github.com", "--user", login])
	if not result["ok"]:
		_message("Не удалось активировать @" + login + ": " + str(result["output"]), true)
		return
	var verified: Dictionary = CLI.run(_gh(), ["api", "user", "--jq", ".login"])
	if not verified["ok"] or str(verified["output"]).to_lower() != login.to_lower():
		_message("Проверка пользователя не прошла. Проверьте настройки gh.", true)
		return
	config["active_account"] = login
	_save()
	_message("Активирован GitHub CLI аккаунт @" + login)


func _show_settings() -> void:
	_clear_page("Настройки")
	var form := _panel()
	_add_note(form, "Исполняемые файлы", Color("#71c4ff"))
	var git := _field(form, "Git", "git или полный путь", _git())
	var gh := _field(form, "GitHub CLI", "gh или полный путь", _gh())
	var node := _field(form, "Node.js для ChatGPT", "node или полный путь", str(config.get("node_binary", "node")))
	_add_button(form, "Сохранить настройки", func(): _save_tools(git.text, gh.text, node.text))
	_add_button(form, "Проверить инструменты", func(): _check_tools())
	var panel := _panel()
	_add_note(panel, "Интеграции", Color("#71c4ff"))
	_add_note(panel, "ChatGPT: реализован официальный Sign in with ChatGPT для локальных open-source приложений. Нужна однократная установка DevKit: node bridge/setup.mjs, затем вход в официальном браузере. Использование подписки возможно при наличии соответствующего разрешения и подходящего плана.")
	_add_note(panel, "Ключ API не требуется в режиме «Продолжить с ChatGPT». Опциональный режим OpenAI API оставлен в качестве совместимости; его оплата отдельная.")
	_add_note(panel, "Вход через ChatGPT не даёт доступ к истории разговоров сайта chatgpt.com. Пароли и cookies приложение не собирает.")
	_add_note(panel, "Полноэкранный режим: кнопка в шапке приложения или F11. Возврат — повторное нажатие.")
	_add_note(panel, "GitHub Actions: приложение показывает последний запуск, но не заявляет о наличии несуществующего публичного API для остатка минут каждого пользователя.")
	_add_note(panel, "Автоматическая смена плательщика/репозитория при исчерпании квоты отключена. Для непрерывного CI предпочтительны собственные runners или согласованные организации с независимой оплатой.")
	_add_note(panel, "Локальный файл конфигурации: " + ProjectSettings.globalize_path(Store.CONFIG_PATH))


func _save_tools(git: String, gh: String, node: String) -> void:
	if git.strip_edges().is_empty() or gh.strip_edges().is_empty() or node.strip_edges().is_empty():
		_message("Заполните все пути.", true)
		return
	config["git_binary"] = git.strip_edges()
	config["gh_binary"] = gh.strip_edges()
	config["node_binary"] = node.strip_edges()
	if _save():
		_message("Пути к инструментам сохранены.")


func _check_tools() -> void:
	var git: Dictionary = CLI.run(_git(), ["--version"])
	var gh: Dictionary = CLI.run(_gh(), ["--version"])
	if git["ok"] and gh["ok"]:
		_message("Git и GitHub CLI доступны.")
	else:
		_message("Не найдены или не запускаются: " + ("git " if not git["ok"] else "") + ("gh" if not gh["ok"] else ""), true)


func _show_chat() -> void:
	heading.text = "ChatGPT · встроенный чат"
	content_scroll.hide()
	chat_panel.show()
	chat_panel.configure(config)


func _on_ai_model_changed(model: String) -> void:
	config["ai_model"] = model
	_save()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_window_mode()
		get_viewport().set_input_as_handled()


func _toggle_window_mode() -> void:
	var window := get_window()
	if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window.mode = previous_window_mode
		if previous_window_mode == Window.MODE_WINDOWED:
			window.size = window_restore_size
			window.position = window_restore_position
	else:
		previous_window_mode = window.mode
		if window.mode == Window.MODE_WINDOWED:
			window_restore_size = window.size
			window_restore_position = window.position
		window.mode = Window.MODE_FULLSCREEN
	_update_window_button()


func _update_window_button() -> void:
	if window_mode_button == null:
		return
	var mode := get_window().mode
	window_mode_button.text = "Оконный режим  F11" if mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN else "На весь экран  F11"
