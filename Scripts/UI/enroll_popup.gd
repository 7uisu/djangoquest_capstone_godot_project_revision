# Scripts/UI/enroll_popup.gd
# Popup dialog for entering a classroom enrollment code.
extends CanvasLayer

@onready var overlay = $Overlay
@onready var code_input: LineEdit = $Overlay/CenterContainer/PanelContainer/VBoxContainer/CodeInput
@onready var enroll_button: Button = $Overlay/CenterContainer/PanelContainer/VBoxContainer/EnrollButton
@onready var cancel_button: Button = $Overlay/CenterContainer/PanelContainer/VBoxContainer/CancelButton
@onready var status_label: Label = $Overlay/CenterContainer/PanelContainer/VBoxContainer/StatusLabel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	enroll_button.pressed.connect(_on_enroll_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	ApiManager.enroll_completed.connect(_on_enroll_completed)

func _on_enroll_pressed():
	var code = code_input.text.strip_edges()
	if code == "":
		status_label.text = "Please enter an enrollment code."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return

	enroll_button.disabled = true
	status_label.text = "Enrolling..."
	status_label.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	ApiManager.enroll(code)

func _on_enroll_completed(success: bool, message: String, _classroom_name: String):
	enroll_button.disabled = false
	status_label.text = message

	if success:
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		await get_tree().create_timer(1.5).timeout
		_close()
	else:
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

func _on_cancel_pressed():
	_close()

func _close():
	queue_free()
