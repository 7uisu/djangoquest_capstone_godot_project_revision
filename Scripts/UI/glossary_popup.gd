# glossary_popup.gd — Self-contained glossary popup built entirely in code.
# No .tscn needed — avoids UID/preload issues.
# Usage: var popup = GlossaryPopup.new(); popup.show_definition("django"); get_tree().root.add_child(popup)
extends CanvasLayer

var _panel: PanelContainer
var _term_label: Label
var _definition_label: RichTextLabel

func _init():
	layer = 100  # Above everything (slides=50, dialogue=60)

func _ready():
	# ── Dark overlay backdrop ──
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Click overlay to close
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			queue_free()
	)
	add_child(overlay)

	# ── Centered panel ──
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.97)
	style.border_color = Color(0.88, 0.78, 0.46, 0.9)  # Gold border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# ── Header: 📖 icon + gold term ──
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var icon = Label.new()
	icon.text = "📖"
	icon.add_theme_font_size_override("font_size", 22)
	header.add_child(icon)

	_term_label = Label.new()
	_term_label.text = "Term"
	_term_label.add_theme_font_size_override("font_size", 20)
	_term_label.add_theme_color_override("font_color", Color(0.88, 0.78, 0.46))  # Gold
	var font = load("res://Textures/Fonts/Pixelify_Sans/PixelifySans-VariableFont_wght.ttf")
	if font:
		_term_label.add_theme_font_override("font", font)
	header.add_child(_term_label)

	# ── Divider ──
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_color_override("separator", Color(0.35, 0.35, 0.45))
	vbox.add_child(sep)

	# ── Definition text (RichTextLabel for formatting) ──
	_definition_label = RichTextLabel.new()
	_definition_label.bbcode_enabled = true
	_definition_label.fit_content = true
	_definition_label.scroll_active = false
	_definition_label.custom_minimum_size = Vector2(370, 60)
	_definition_label.add_theme_font_size_override("normal_font_size", 14)
	_definition_label.add_theme_color_override("default_color", Color(0.75, 0.78, 0.85))
	if font:
		_definition_label.add_theme_font_override("normal_font", font)
	vbox.add_child(_definition_label)

	# ── Close button ──
	var close_btn = Button.new()
	close_btn.text = "✕  Close"
	close_btn.add_theme_font_size_override("font_size", 13)
	if font:
		close_btn.add_theme_font_override("font", font)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.22)
	btn_style.border_color = Color(0.4, 0.4, 0.55)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.25, 0.35)
	close_btn.add_theme_stylebox_override("hover", btn_hover)
	close_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	close_btn.pressed.connect(queue_free)
	vbox.add_child(close_btn)

	# ── Animate in ──
	_panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.18)

func show_definition(term: String) -> void:
	_term_label.text = term.capitalize()
	var definition = GlossaryData.get_definition(term)
	_definition_label.text = "[color=#abb2bf]" + definition + "[/color]"

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
