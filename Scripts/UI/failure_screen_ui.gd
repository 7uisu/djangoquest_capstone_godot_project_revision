extends CanvasLayer

signal retry_pressed

@onready var title_label: Label = $Screen/CenterContainer/VBox/TitleLabel
@onready var quote_label: Label = $Screen/CenterContainer/VBox/QuoteLabel
@onready var description_label: Label = $Screen/CenterContainer/VBox/DescriptionLabel
@onready var retry_button: Button = $Screen/CenterContainer/VBox/RetryButton
@onready var background: ColorRect = $Screen/Background

func _ready() -> void:
	visible = false
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)

func show_failure(title: String, quote: String, description: String, button_text: String = "↺  Retry") -> void:
	visible = true
	if title_label:
		title_label.text = title
	if quote_label:
		quote_label.text = "\"%s\"" % quote
	if description_label:
		description_label.text = description
	if retry_button:
		retry_button.text = button_text
		retry_button.disabled = false
		retry_button.grab_focus()

	# Dramatic slow fade-in
	if background:
		background.color.a = 0.0
		var tween := create_tween()
		tween.tween_property(background, "color:a", 0.95, 0.8)

func hide_failure() -> void:
	visible = false

func _on_retry_pressed() -> void:
	if retry_button:
		retry_button.disabled = true
	hide_failure()
	retry_pressed.emit()
