# custom_confirm.gd
extends CanvasLayer

@onready var overlay = $Overlay
@onready var title_label = $Overlay/CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var message_label = $Overlay/CenterContainer/PanelContainer/VBoxContainer/MessageLabel
@onready var yes_button = $Overlay/CenterContainer/PanelContainer/VBoxContainer/HBoxContainer/YesButton
@onready var no_button = $Overlay/CenterContainer/PanelContainer/VBoxContainer/HBoxContainer/NoButton

var _current_callable: Callable
var _cancel_callable: Callable

func _ready():
	overlay.visible = false
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)

func prompt(title_text: String, message_text: String, confirm_callable: Callable, cancel_callable: Callable = Callable()):
	title_label.text = title_text
	message_label.text = message_text
	_current_callable = confirm_callable
	_cancel_callable = cancel_callable
	overlay.visible = true

func _on_yes_pressed():
	overlay.visible = false
	if _current_callable.is_valid():
		_current_callable.call()

func _on_no_pressed():
	overlay.visible = false
	if _cancel_callable.is_valid():
		_cancel_callable.call()
