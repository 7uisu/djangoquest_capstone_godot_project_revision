extends CanvasLayer

signal choice_selected(choice_index: int)

@export_range(1.0, 60.0, 1.0) var time_limit_seconds := 20.0

@onready var panel: PanelContainer = $CenterContainer/ChoicePanel
@onready var timer_label: Label = $CenterContainer/ChoicePanel/MarginContainer/ChoicesBox/TimerLabel
@onready var question_label: Label = $CenterContainer/ChoicePanel/MarginContainer/ChoicesBox/QuestionLabel
@onready var buttons_box: VBoxContainer = $CenterContainer/ChoicePanel/MarginContainer/ChoicesBox/Buttons

var _active := false
var _generation := 0


func _ready() -> void:
	visible = false


func show_choices(choices: Array, question_text: String = "") -> void:
	if choices.is_empty():
		choice_selected.emit(-1)
		return
	_generation += 1
	var this_generation := _generation
	for child in buttons_box.get_children():
		child.queue_free()
	question_label.text = question_text
	question_label.visible = not question_text.is_empty()
	for i in range(choices.size()):
		var button := Button.new()
		button.text = str(choices[i])
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 16)
		_apply_button_styles(button)
		button.pressed.connect(_select.bind(i))
		buttons_box.add_child(button)
	_active = true
	visible = true
	timer_label.text = "Choose an answer  •  %02d seconds" % ceili(time_limit_seconds)
	(buttons_box.get_child(0) as Button).grab_focus()
	_update_timer(this_generation, time_limit_seconds)
	await get_tree().create_timer(time_limit_seconds).timeout
	if _active and this_generation == _generation:
		_select(choices.size() - 1)


func hide_choices() -> void:
	_active = false
	_generation += 1
	visible = false


func _update_timer(generation: int, seconds_left: float) -> void:
	if not _active or generation != _generation:
		return
	timer_label.text = "Choose an answer  •  %02d seconds" % ceili(seconds_left)
	if seconds_left <= 0.0:
		return
	await get_tree().create_timer(1.0).timeout
	_update_timer(generation, maxf(0.0, seconds_left - 1.0))


func _select(index: int) -> void:
	if not _active:
		return
	_active = false
	_generation += 1
	choice_selected.emit(index)


func _apply_button_styles(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.14, 0.22, 1.0)
	normal.border_color = Color(0.24, 0.36, 0.56, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(12)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.24, 0.38, 1.0)
	hover.border_color = Color(0.38, 0.65, 1.0, 1.0)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.09, 0.12, 0.18, 1.0)
	pressed.border_color = Color(0.28, 0.50, 0.85, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)

	button.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.85, 0.92, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
