extends CanvasLayer

signal choice_selected(choice_index: int)

@export_range(1.0, 60.0, 1.0) var time_limit_seconds := 15.0

@onready var panel: PanelContainer = $CenterContainer/ChoicePanel
@onready var timer_label: Label = $CenterContainer/ChoicePanel/MarginContainer/ChoicesBox/TimerLabel
@onready var buttons_box: VBoxContainer = $CenterContainer/ChoicePanel/MarginContainer/ChoicesBox/Buttons

var _active := false
var _generation := 0


func _ready() -> void:
	visible = false


func show_choices(choices: Array) -> void:
	if choices.is_empty():
		choice_selected.emit(-1)
		return
	_generation += 1
	var this_generation := _generation
	for child in buttons_box.get_children():
		child.queue_free()
	for i in range(choices.size()):
		var button := Button.new()
		button.text = str(choices[i])
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 16)
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
