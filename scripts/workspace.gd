extends Control
## Builder MVP: a local-first GitHub workspace. The GitHub CLI manages credentials.
## No automatic billing-account rotation or workflow dispatch is performed.

const Store = preload("res://scripts/data_store.gd")
const CLI = preload("res://scripts/cli.gd")
const ChatPanel = preload("res://scripts/chat_panel.gd")
const UI = preload("res://scripts/ui_style.gd")
const GithubAuth = preload("res://scripts/github_auth.gd")

var config: Dictionary = {}
var body: VBoxContainer
var heading: Label
var status_label: Label
var content_scroll: ScrollContainer
var chat_panel
var window_mode_button: Button
var repo_catalog: Array = []
var repo_catalog_list: VBoxContainer
var repo_catalog_search: LineEdit
var clone_root_hint: Label
var github_login_poll: Timer
var github_accounts_before: Array = []
var github_login_active_before := ""
var github_login_started := 0
var fullscreen_help_dialog: AcceptDialog
var previous_window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
var window_restore_size := Vector2i(1180, 760)
var window_restore_position := Vector2i(100, 100)
var window_switch_in_progress := false


func _ready() -> void:
	config = Store.read()
	UI.apply(self)
	_build_shell()
	github_login_poll = Timer.new()
	github_login_poll.wait_time = 3.0
	github_login_poll.timeout.connect(_poll_github_login)
	add_child(github_login_poll)
	_show_home()


func _build_shell() -> void:
	var base := UI.BACKGROUND
	var surface := UI.SIDEBAR
	var text_color := UI.TEXT
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 20)
	add_child(root)

	var background := ColorRect.new()
	background.color = base
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(255, 0)
	var side_style := UI.panel(surface, 0, false)
	side_style.set_content_margin_all(20)
	sidebar.add_theme_stylebox_override("panel", side_style)
	root.add_child(sidebar)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	sidebar.add_child(menu)
	var brand := Label.new()
	brand.text = "◈  BUILDER"
	brand.add_theme_font_size_override("font_size", 25)
	brand.add_theme_color_override("font_color", Color("#A49CFF"))
	menu.add_child(brand)
	_add_note(menu, "GITHUB  +  AI WORKSPACE", UI.MUTED)
	menu.add_child(HSeparator.new())
	_add_note(menu, "РАБОЧЕЕ ПРОСТРАНСТВО", UI.MUTED)
	UI.subtle(_add_button(menu, "⌂   Главная", Callable(self, "_show_home")))
	UI.subtle(_add_button(menu, "▦   Мои проекты", Callable(self, "_show_projects")))
	UI.subtle(_add_button(menu, "↓   Загрузить из GitHub", Callable(self, "_show_catalog")))
	UI.subtle(_add_button(menu, "✦   ИИ-помощник", Callable(self, "_show_chat")))
	menu.add_child(HSeparator.new())
	_add_note(menu, "ПОДКЛЮЧЕНИЯ", UI.MUTED)
	UI.subtle(_add_button(menu, "⌘   GitHub-аккаунты", Callable(self, "_show_accounts")))
	UI.subtle(_add_button(menu, "⚙   Настройки", Callable(self, "_show_settings")))
	var push_down := Control.new()
	push_down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(push_down)
	_add_note(menu, "Все проекты и настройки — на вашем устройстве.", UI.MUTED)
	UI.subtle(_add_button(menu, "↗   ChatGPT.com", func(): OS.shell_open("https://chatgpt.com/")))
	var exit_button := _add_button(menu, "⎋   Выйти из Builder", func(): get_tree().quit())
	UI.subtle(exit_button)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)
	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 24)
	top.add_theme_constant_override("margin_right", 22)
	main.add_child(top)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	top.add_child(header_row)
	heading = Label.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_color_override("font_color", text_color)
	heading.add_theme_font_size_override("font_size", 30)
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
	chat_panel.provider_changed.connect(_on_ai_provider_changed)
	status_label = Label.new()
	status_label.text = "Готово. Для приватных репозиториев выполните gh auth login в терминале."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", UI.MUTED)
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
	var style := UI.panel(UI.SURFACE, 16)
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
	var saved := str(config.get("gh_binary", "gh"))
	if saved != "gh":
		return saved
	var common := ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
	for candidate in common:
		if FileAccess.file_exists(candidate):
			return candidate
	return "gh"


func _save() -> bool:
	if not Store.write(config):
		_message("Не удалось записать настройки в user://builder.json", true)
		return false
	return true


func _show_home() -> void:
	_clear_page("Рабочее пространство")
	var welcome := _panel()
	var title := _add_note(welcome, "Проекты, GitHub и искусственный интеллект — в одном месте.", UI.TEXT)
	UI.label(title, 23)
	_add_note(welcome, "Подключите GitHub, выберите репозиторий и начните работу с ChatGPT или локальной моделью. Без ручного копирования ссылок и токенов.", UI.MUTED)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	welcome.add_child(actions)
	UI.accent(_add_button(actions, "Подключить GitHub", _show_accounts))
	_add_button(actions, "Загрузить репозиторий", _show_catalog)
	_add_button(actions, "Открыть ИИ-помощника", _show_chat)
	var steps := _panel()
	var step_title := _add_note(steps, "БЫСТРЫЙ СТАРТ", UI.ACCENT_HOVER)
	UI.label(step_title, 13)
	_add_note(steps, "01   GitHub — авторизация в браузере, без токена в Builder.")
	_add_note(steps, "02   Репозитории — выберите проект из списка и каталог для загрузки.")
	_add_note(steps, "03   ИИ — вход в ChatGPT или Ollama / LM Studio на вашем компьютере.")
	var overview := _panel()
	_add_note(overview, "ВАШИ ПРОЕКТЫ", UI.ACCENT_HOVER)
	var projects: Array = config.get("projects", [])
	var projects_label := _add_note(overview, str(projects.size()) + " подключено", UI.TEXT)
	UI.label(projects_label, 22)
	if not projects.is_empty():
		for index in range(mini(projects.size(), 4)):
			var item: Variant = projects[index]
			if item is Dictionary:
				_add_button(overview, "▦  " + str(item.get("full_name", "Репозиторий")), _show_projects)
	_add_button(overview, "Все проекты", _show_projects)


func _default_clone_root() -> String:
	var saved := str(config.get("clone_root", "")).strip_edges()
	if saved.is_absolute_path():
		return saved
	var documents := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents.is_empty():
		documents = OS.get_user_data_dir()
	return documents.path_join("Builder").path_join("repos")


func _choose_clone_folder() -> void:
	var picker := FileDialog.new()
	picker.title = "Куда загружать репозитории"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	picker.current_dir = _default_clone_root().get_base_dir()
	picker.dir_selected.connect(func(path: String):
		config["clone_root"] = path
		_save()
		_show_catalog()
		picker.queue_free()
	)
	picker.canceled.connect(func(): picker.queue_free())
	add_child(picker)
	picker.popup_centered_ratio(0.8)


func _show_catalog() -> void:
	_clear_page("Загрузка из GitHub")
	var guide := _panel()
	var label := _add_note(guide, "Ваши репозитории — без ручного ввода адресов", UI.TEXT)
	UI.label(label, 21)
	_add_note(guide, "Builder использует официальный GitHub CLI. В списке отображаются репозитории, к которым имеет доступ текущий аккаунт.")
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	guide.add_child(actions)
	UI.accent(_add_button(actions, "Обновить список", _load_github_catalog))
	_add_button(actions, "Подключить GitHub", _show_accounts)
	var folder := _panel()
	_add_note(folder, "КАТАЛОГ ДЛЯ КЛОНИРОВАНИЯ", UI.ACCENT_HOVER)
	clone_root_hint = _add_note(folder, _default_clone_root(), UI.TEXT)
	var folder_button := _add_button(folder, "Изменить папку…", _choose_clone_folder)
	UI.subtle(folder_button)
	var search_panel := _panel()
	repo_catalog_search = _field(search_panel, "ПОИСК ПО НАЗВАНИЮ", "Например, KIBHR или builder")
	repo_catalog_search.text_changed.connect(func(_value: String): _render_github_catalog())
	repo_catalog_list = VBoxContainer.new()
	repo_catalog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(repo_catalog_list)
	_load_github_catalog()


func _load_github_catalog() -> void:
	if repo_catalog_list == null or not is_instance_valid(repo_catalog_list):
		return
	for child in repo_catalog_list.get_children():
		child.queue_free()
	repo_catalog.clear()
	_add_note(repo_catalog_list, "Загружаю список доступных репозиториев…", UI.MUTED)
	var command := ["api", "user/repos?per_page=100&sort=updated&affiliation=owner,collaborator,organization_member"]
	var result: Dictionary = CLI.run(_gh(), command)
	if not result["ok"]:
		for child in repo_catalog_list.get_children():
			child.queue_free()
		_add_note(repo_catalog_list, "Не удалось получить репозитории. Сначала подключите GitHub и нажмите «Обновить список».", UI.DANGER)
		_message("GitHub недоступен: " + str(result["output"]).substr(0, 260), true)
		return
	var data: Variant = JSON.parse_string(str(result["output"]))
	if not (data is Array):
		_message("GitHub вернул неожиданный список репозиториев.", true)
		return
	for item in data:
		if item is Dictionary and CLI.valid_repository(str(item.get("full_name", ""))):
			repo_catalog.append(item)
	_render_github_catalog()


func _render_github_catalog() -> void:
	if repo_catalog_list == null or not is_instance_valid(repo_catalog_list):
		return
	for child in repo_catalog_list.get_children():
		repo_catalog_list.remove_child(child)
		child.queue_free()
	var filter_text := repo_catalog_search.text.strip_edges().to_lower() if repo_catalog_search != null else ""
	var shown := 0
	for project in repo_catalog:
		var fullname := str(project.get("full_name", ""))
		var description := str(project.get("description", ""))
		if not filter_text.is_empty() and not fullname.to_lower().contains(filter_text) and not description.to_lower().contains(filter_text):
			continue
		var entry := PanelContainer.new()
		entry.add_theme_stylebox_override("panel", UI.panel(UI.SURFACE, 14))
		repo_catalog_list.add_child(entry)
		var row := HBoxContainer.new()
		entry.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var title := _add_note(details, "▦  " + fullname, UI.TEXT)
		UI.label(title, 17)
		_add_note(details, ("Приватный" if bool(project.get("private", false)) else "Публичный") + "  •  " + (description.substr(0, 110) if not description.is_empty() else "Без описания"), UI.MUTED)
		var name := fullname
		var branch := str(project.get("default_branch", "main"))
		var action := _add_button(row, "Добавить проект", func(): _import_github_project(name, branch))
		UI.accent(action)
		shown += 1
		if shown >= 80:
			break
	if shown == 0:
		_add_note(repo_catalog_list, "Совпадений нет. Проверьте поисковый запрос или подключите GitHub.", UI.MUTED)
	else:
		_add_note(repo_catalog_list, "Найдено " + str(shown) + " репозиториев. Загрузка запускается только по вашему нажатию.", UI.MUTED)


func _import_github_project(full_name: String, branch: String) -> void:
	if not CLI.valid_repository(full_name):
		_message("Некорректное имя репозитория.", true)
		return
	for existing in config.get("projects", []):
		if existing is Dictionary and str(existing.get("full_name", "")) == full_name:
			_message("Этот репозиторий уже подключён.")
			_show_projects()
			return
	var root_dir := _default_clone_root()
	if not root_dir.is_absolute_path():
		_message("Выберите абсолютный путь для проектов.", true)
		return
	var directory := full_name.replace("/", "__")
	var target := root_dir.path_join(directory)
	if DirAccess.dir_exists_absolute(target):
		var current := CLI.run(_git(), ["-C", target, "remote", "get-url", "origin"])
		if not current["ok"] or not _matches_origin(str(current["output"]), full_name):
			_message("Папка уже существует и не совпадает с этим GitHub-репозиторием: " + target, true)
			return
	else:
		var created := DirAccess.make_dir_recursive_absolute(root_dir)
		if created != OK:
			_message("Не удалось создать папку для репозиториев.", true)
			return
		_message("Клонируется " + full_name + "…")
		var cloned := CLI.run(_gh(), ["repo", "clone", full_name, target])
		if not cloned["ok"]:
			_message("Ошибка клонирования: " + str(cloned["output"]).substr(0, 280), true)
			return
	config["projects"].append({"full_name": full_name, "path": target, "branch": branch, "mirrors": []})
	if _save():
		_show_projects()
		_message("Репозиторий готов: " + full_name + ". Папка: " + target)


func _show_manual_project() -> void:
	_clear_page("Добавить репозиторий вручную")
	_add_note(body, "Используйте этот вариант для уже клонированных проектов или зеркал. Для обычной загрузки проще выбрать проект в каталоге GitHub.")
	var form := _panel()
	var full_name := _field(form, "GitHub-репозиторий", "owner/repository")
	var path := _field(form, "Путь к локальному проекту", "/Users/you/Projects/repository")
	var branch := _field(form, "Ветка", "main", "main")
	var mirrors := _field(form, "Зеркала (необязательно)", "owner/other-repo")
	UI.accent(_add_button(form, "Добавить", func(): _add_project(full_name.text, path.text, branch.text, mirrors.text)))


func _show_projects() -> void:
	_clear_page("Мои проекты")
	var lead := _panel()
	var caption := _add_note(lead, "Ваши репозитории в одном месте", UI.TEXT)
	UI.label(caption, 21)
	_add_note(lead, "Выберите проект для работы. Для новых репозиториев есть импорт прямо из GitHub.")
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	lead.add_child(actions)
	UI.accent(_add_button(actions, "＋  Загрузить из GitHub", _show_catalog))
	_add_button(actions, "Добавить вручную", _show_manual_project)
	var projects: Array = config.get("projects", [])
	if projects.is_empty():
		var hint := _panel()
		_add_note(hint, "Пока нет репозиториев. Подключите GitHub и выберите первый проект.")
		UI.accent(_add_button(hint, "Выбрать из GitHub", _show_catalog))
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
	var result: Dictionary = CLI.run(_gh(), ["repo", "clone", str(project["full_name"]), target])
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
	var welcome := _panel()
	var header := _add_note(welcome, "GitHub без токенов и сложных настроек", UI.TEXT)
	UI.label(header, 21)
	_add_note(welcome, "Подключение через официальный GitHub CLI. Все уже сохранённые аккаунты остаются подключёнными. Чтобы добавить ещё один — в браузере выберите другой GitHub-аккаунт.", UI.MUTED)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	welcome.add_child(actions)
	UI.accent(_add_button(actions, "＋  Добавить ещё аккаунт", _start_github_login))
	_add_button(actions, "Проверить подключение", _refresh_github_accounts)
	_add_button(actions, "Установить GitHub CLI ↗", func(): OS.shell_open("https://cli.github.com/"))
	var current := _detect_github_accounts()
	var status := _panel()
	_add_note(status, "ТЕКУЩЕЕ ПОДКЛЮЧЕНИЕ", UI.ACCENT_HOVER)
	var active := str(config.get("active_account", ""))
	if current.is_empty():
		_add_note(status, "Аккаунт пока не обнаружен. Нажмите «Войти через GitHub» и пройдите авторизацию в терминале/браузере.", UI.MUTED)
	else:
		var title := _add_note(status, "✓  @" + current + " — подключён", UI.GOOD)
		UI.label(title, 20)
		_add_button(status, "Перейти к репозиториям →", _show_catalog)
	if not OS.get_environment("GH_TOKEN").is_empty() or not OS.get_environment("GITHUB_TOKEN").is_empty():
		_add_note(status, "ВНИМАНИЕ: переменная GH_TOKEN/GITHUB_TOKEN перекрывает выбор аккаунта GitHub CLI. Уберите её перед переключением.", UI.DANGER)
	var available: Array = config.get("accounts", [])
	if not available.is_empty():
		var accounts := _panel()
		_add_note(accounts, "ПОДКЛЮЧЁННЫЕ АККАУНТЫ", UI.ACCENT_HOVER)
		for username in available:
			var account := str(username)
			var account_row := HBoxContainer.new()
			accounts.add_child(account_row)
			var label := _add_note(account_row, "●  @" + account + ("  · активен" if account == active else ""), UI.TEXT)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if account != active:
				_add_button(account_row, "Переключить", func(): _activate_account(account))
			_add_button(account_row, "Отключить", func(): _confirm_github_logout(account))
	var help := _panel()
	_add_note(help, "НЕ ОТКРЫВАЕТСЯ ВХОД?", UI.ACCENT_HOVER)
	_add_note(help, "При добавлении второго аккаунта GitHub может автоматически предложить первый. В браузере выберите «Use another account» или войдите через отдельный профиль браузера. Дождитесь сообщения об успехе в терминале, затем нажмите «Проверить подключение».", UI.MUTED)
	_add_note(help, "gh auth login --hostname github.com --web --git-protocol https --clipboard", UI.TEXT)
	_add_button(help, "Копировать команду", func():
		DisplayServer.clipboard_set("gh auth login --hostname github.com --web --git-protocol https --clipboard")
		_message("Команда авторизации скопирована.")
	)


func _github_account_snapshot() -> Dictionary:
	var cmd := CLI.run(_gh(), ["auth", "status", "--hostname", "github.com", "--json", "hosts"])
	if not cmd["ok"]:
		return {"accounts": [], "active": "", "error": "Не удалось выполнить gh auth status. Проверьте установку GitHub CLI."}
	return GithubAuth.parse_accounts(str(cmd["output"]))


func _detect_github_accounts() -> String:
	var snapshot := _github_account_snapshot()
	if not str(snapshot.get("error", "")).is_empty():
		_message(str(snapshot["error"]), true)
		return ""
	var names: Array = snapshot.get("accounts", [])
	var active := str(snapshot.get("active", ""))
	config["accounts"] = names.duplicate()
	config["active_account"] = active
	_save()
	return active


func _poll_github_login() -> void:
	if Time.get_ticks_msec() - github_login_started > 300000:
		github_login_poll.stop()
		_message("Ожидание входа GitHub завершено. Проверьте терминал и нажмите «Проверить подключение».", true)
		return
	var snapshot := _github_account_snapshot()
	if not str(snapshot.get("error", "")).is_empty():
		return
	var current: Array = snapshot.get("accounts", [])
	var active := str(snapshot.get("active", ""))
	var is_new := false
	for item in current:
		if not github_accounts_before.has(item):
			is_new = true
			break
	if not is_new and active == github_login_active_before:
		return
	github_login_poll.stop()
	config["accounts"] = current.duplicate()
	config["active_account"] = active
	_save()
	_show_accounts()
	_message("GitHub: подключён @" + active + ". Теперь можно открыть его репозитории.")




func _refresh_github_accounts() -> void:
	_show_accounts()
	if str(config.get("active_account", "")).is_empty():
		_message("GitHub ещё не подключён. Завершите вход в браузере и повторите проверку.", true)
	else:
		_message("Аккаунт GitHub обнаружен: @" + str(config["active_account"]))


func _start_github_login() -> void:
	if not github_login_poll.is_stopped():
		_message("Вход GitHub уже запущен. Сначала завершите авторизацию в терминале.", true)
		return
	var executable := _gh()
	var gh_check: Dictionary = CLI.run(executable, ["--version"])
	if not gh_check["ok"]:
		OS.shell_open("https://cli.github.com/")
		_message("Не найден GitHub CLI. Установите его с открытой страницы, затем повторите вход.", true)
		return
	var snapshot := _github_account_snapshot()
	github_accounts_before = snapshot.get("accounts", []).duplicate()
	github_login_active_before = str(snapshot.get("active", ""))
	# GitHub CLI login adds an account rather than replacing existing credentials.
	var shell_command := "'" + executable.replace("'", "'\\''") + "' auth login --hostname github.com --web --git-protocol https --clipboard"
	var pid := -1
	match OS.get_name():
		"macOS":
			# Launch a temporary .command file with Terminal; avoid AppleScript's
			# Automation permission, which silently prevented account onboarding.
			var command_file := ProjectSettings.globalize_path("user://github-add-account.command")
			var script := FileAccess.open(command_file, FileAccess.WRITE)
			if script != null:
				script.store_string("#!/bin/zsh\n" + shell_command + "\n" + "echo 'Вернитесь в Builder и нажмите Проверить подключение.'\n" + "read -r '?Нажмите Enter, чтобы закрыть окно… '\n")
				script.close()
				var output: Array = []
				if OS.execute("/bin/chmod", ["700", command_file], output, true) == 0:
					pid = OS.create_process("/usr/bin/open", ["-a", "Terminal", command_file])
		"Windows":
			pid = OS.create_process("powershell.exe", ["-NoProfile", "-Command", "Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoExit','-Command','gh auth login --hostname github.com --web --git-protocol https --clipboard')"])
		"Linux", "FreeBSD", "NetBSD", "OpenBSD":
			pid = OS.create_process("x-terminal-emulator", ["-e", "bash", "-lc", shell_command + "; exec bash"])
	if pid <= 0:
		DisplayServer.clipboard_set("gh auth login --hostname github.com --web --git-protocol https --clipboard")
		_message("Системный терминал не открылся. Команда GitHub скопирована: вставьте её в терминал и выберите другой аккаунт в браузере.", true)
		return
	github_login_started = Time.get_ticks_msec()
	github_login_poll.start()
	_message("Терминал GitHub открыт. Выберите НОВЫЙ аккаунт в браузере, подтвердите код. Builder проверит появление аккаунта автоматически.")


func _confirm_github_logout(login: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Отключить GitHub"
	dialog.dialog_text = "Удалить авторизацию @" + login + " из GitHub CLI на этом компьютере? Это повлияет и на другие программы, использующие gh."
	dialog.confirmed.connect(func():
		var result: Dictionary = CLI.run(_gh(), ["auth", "logout", "--hostname", "github.com", "--user", login])
		if result["ok"]:
			config["accounts"].erase(login)
			if config.get("active_account", "") == login:
				config["active_account"] = ""
			_save()
			_show_accounts()
			_message("Авторизация @" + login + " отключена.")
		else:
			_message("Ошибка выхода из GitHub CLI: " + str(result["output"]).substr(0, 240), true)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


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
	if not OS.get_environment("GH_TOKEN").is_empty() or not OS.get_environment("GITHUB_TOKEN").is_empty():
		_message("GitHub использует переменную GH_TOKEN/GITHUB_TOKEN, которая перекрывает выбранный аккаунт CLI. Уберите её из окружения Builder и перезапустите приложение.", true)
		return
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
	_show_accounts()


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


func _on_ai_provider_changed(provider: String) -> void:
	config["ai_provider"] = provider
	_save()


func _on_ai_model_changed(model: String) -> void:
	config["ai_model"] = model
	_save()


## Handle F11 globally, including when the chat input or another control has focus.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_window_mode()
		get_viewport().set_input_as_handled()


func _is_fullscreen(mode: int) -> bool:
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _show_embedded_fullscreen_help() -> void:
	_message("Полноэкранный режим недоступен при запуске внутри редактора. Game → ⋯ → отключите Embed Game on Next Play, затем перезапустите проект.", true)
	if fullscreen_help_dialog == null:
		fullscreen_help_dialog = AcceptDialog.new()
		fullscreen_help_dialog.title = "Builder: полноэкранный режим"
		fullscreen_help_dialog.dialog_text = "Godot не поддерживает полноэкранный режим для встроенного окна игры.\n\nОстановите Builder, откройте вкладку Game в редакторе Godot, нажмите ⋯ и отключите «Embed Game on Next Play».\n\nЗатем снова запустите проект (F5) и нажмите «На весь экран» или F11."
		add_child(fullscreen_help_dialog)
	fullscreen_help_dialog.popup_centered(Vector2i(540, 270))


func _toggle_window_mode() -> void:
	# A game embedded into Godot's Game tab has no independent native window.
	# Godot 4.7 silently refuses fullscreen requests in this situation.
	if Engine.is_embedded_in_editor():
		_show_embedded_fullscreen_help()
		return
	if window_switch_in_progress:
		return
	if DisplayServer.get_name() == "headless":
		_message("Полноэкранный режим требует графического рабочего стола.", true)
		return

	var mode: int = DisplayServer.window_get_mode(DisplayServer.MAIN_WINDOW_ID)
	var entering := not _is_fullscreen(mode)
	var target: int = previous_window_mode
	if entering:
		previous_window_mode = mode
		if mode == DisplayServer.WINDOW_MODE_WINDOWED:
			window_restore_size = get_window().size
			window_restore_position = get_window().position
		target = DisplayServer.WINDOW_MODE_FULLSCREEN

	window_switch_in_progress = true
	window_mode_button.disabled = true
	# Use the native main window rather than a potentially embedded subwindow.
	DisplayServer.window_set_mode(target, DisplayServer.MAIN_WINDOW_ID)
	# macOS performs a fullscreen Space transition asynchronously.
	await get_tree().create_timer(1.25).timeout
	if not is_inside_tree():
		return

	var actual: int = DisplayServer.window_get_mode(DisplayServer.MAIN_WINDOW_ID)
	if actual == target or (entering and _is_fullscreen(actual)):
		if not entering and target == DisplayServer.WINDOW_MODE_WINDOWED:
			# Restoring position/size before leaving fullscreen can be discarded.
			get_window().size = window_restore_size
			get_window().position = window_restore_position
	else:
		_message("Операционная система не переключила окно. Если Builder запущен из Godot, отключите Embed Game on Next Play.", true)
	window_switch_in_progress = false
	window_mode_button.disabled = false
	_update_window_button()


func _update_window_button() -> void:
	if window_mode_button == null:
		return
	if Engine.is_embedded_in_editor():
		window_mode_button.text = "На весь экран  ⓘ"
		window_mode_button.tooltip_text = "При запуске внутри редактора полноэкранный режим недоступен. Нажмите, чтобы узнать, как запустить отдельное окно."
		return
	var mode: int = DisplayServer.window_get_mode(DisplayServer.MAIN_WINDOW_ID)
	window_mode_button.text = "Оконный режим  F11" if _is_fullscreen(mode) else "На весь экран  F11"
	window_mode_button.tooltip_text = "Нажмите для переключения оконного и полноэкранного режимов (F11)."
