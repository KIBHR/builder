extends RefCounted
## Unified modern dark UI for Builder. No external fonts or image assets.
const BACKGROUND := Color("#0A1020")
const SIDEBAR := Color("#111B30")
const SURFACE := Color("#152239")
const SURFACE_HOVER := Color("#1D2E4B")
const BORDER := Color("#283C58")
const TEXT := Color("#EBF2FF")
const MUTED := Color("#A2B3CC")
const ACCENT := Color("#8176F8")
const ACCENT_HOVER := Color("#9B93FF")
const GOOD := Color("#58D6B4")
const DANGER := Color("#F29C9C")


static func panel(color: Color = SURFACE, radius: int = 16, outline: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(17)
	if outline:
		style.set_border_width_all(1)
		style.border_color = BORDER
	return style


static func button_style(color: Color, radius: int = 10) -> StyleBoxFlat:
	var result := panel(color, radius, false)
	result.set_content_margin_all(10)
	result.content_margin_left = 15
	result.content_margin_right = 15
	return result


static func apply(root: Control) -> void:
	var theme := Theme.new()
	for type in ["Button", "OptionButton", "CheckBox", "LineEdit", "TextEdit", "Label", "RichTextLabel", "PopupMenu", "AcceptDialog"]:
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, TEXT)
		theme.set_color("font_focus_color", type, TEXT)
		theme.set_color("font_disabled_color", type, MUTED)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("font_placeholder_color", "TextEdit", MUTED)
	theme.set_color("font_uneditable_color", "LineEdit", MUTED)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_color("font_selected_color", "TextEdit", TEXT)
	theme.set_color("selection_color", "TextEdit", ACCENT.darkened(0.4))
	theme.set_color("selection_color", "LineEdit", ACCENT.darkened(0.4))
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, button_style(SURFACE_HOVER))
		theme.set_stylebox("hover", type, button_style(Color("#2A3C61")))
		theme.set_stylebox("pressed", type, button_style(ACCENT.darkened(0.4)))
		theme.set_stylebox("disabled", type, button_style(SURFACE))
		theme.set_stylebox("focus", type, panel(Color.TRANSPARENT, 10))
	theme.set_stylebox("normal", "LineEdit", panel(SURFACE_HOVER, 11))
	theme.set_stylebox("focus", "LineEdit", panel(Color.TRANSPARENT, 11))
	theme.set_stylebox("read_only", "LineEdit", panel(SURFACE, 11))
	theme.set_stylebox("normal", "TextEdit", panel(SURFACE_HOVER, 11))
	theme.set_stylebox("focus", "TextEdit", panel(Color.TRANSPARENT, 11))
	theme.set_stylebox("panel", "PopupMenu", panel(SIDEBAR, 11))
	theme.set_stylebox("panel", "PanelContainer", panel(SURFACE, 15))
	theme.set_stylebox("panel", "AcceptDialog", panel(SURFACE, 15))
	theme.set_font_size("font_size", "Button", 15)
	theme.set_font_size("font_size", "OptionButton", 14)
	theme.set_font_size("font_size", "Label", 15)
	theme.set_font_size("normal_font_size", "RichTextLabel", 15)
	theme.set_font_size("font_size", "LineEdit", 15)
	theme.set_font_size("font_size", "TextEdit", 15)
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	root.theme = theme


static func accent(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(ACCENT))
	button.add_theme_stylebox_override("hover", button_style(ACCENT_HOVER))
	button.add_theme_stylebox_override("pressed", button_style(ACCENT.darkened(0.15)))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)


static func subtle(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(Color.TRANSPARENT))
	button.add_theme_stylebox_override("hover", button_style(SURFACE_HOVER))


static func label(label: Label, font_size: int = 15, muted: bool = false) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MUTED if muted else TEXT)
