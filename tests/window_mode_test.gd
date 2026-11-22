extends SceneTree
## Minimal headless regression for Builder's fullscreen UI logic.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var builder: Control = scene.instantiate()
	root.add_child(builder)
	if not builder._is_fullscreen(DisplayServer.WINDOW_MODE_FULLSCREEN):
		push_error("Fullscreen enum was not recognized")
		quit(1)
		return
	if not builder._is_fullscreen(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN):
		push_error("Exclusive fullscreen enum was not recognized")
		quit(1)
		return
	if builder._is_fullscreen(DisplayServer.WINDOW_MODE_WINDOWED):
		push_error("Windowed enum incorrectly reported fullscreen")
		quit(1)
		return
	# Fullscreen changes must be skipped for the headless DisplayServer.
	builder._toggle_window_mode()
	if builder.window_switch_in_progress:
		push_error("Headless fullscreen should be rejected synchronously")
		quit(1)
		return
	print("Builder fullscreen mode regression checks passed.")
	quit(0)
