# bus_destination_ui.gd — Destination selection popup for bus fast travel
extends CanvasLayer

signal destination_selected(position: Vector2)
signal cancelled

@onready var panel: PanelContainer = $PanelContainer
@onready var button_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var cancel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CancelButton

var _destinations: Array = []

func _ready():
	layer = 90  # Below SceneTransition (100) but above everything else
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Force an opaque background so world text doesn't bleed through
	var style = StyleBoxFlat.new()
	style.bg_color = Color("24273a")
	style.border_color = Color("1e2030")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	# Fade in
	panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)

## Call this after instantiating to populate the buttons
func setup(destinations: Array):
	_destinations = destinations
	# Clear any existing buttons
	for child in button_container.get_children():
		child.queue_free()

	# Create a button for each destination
	for dest in _destinations:
		var btn = Button.new()
		btn.text = dest["name"]
		btn.custom_minimum_size = Vector2(200, 36)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var target_pos = dest["position"]
		btn.pressed.connect(func(): _on_destination_pressed(target_pos))
		button_container.add_child(btn)

func _on_destination_pressed(target_position: Vector2):
	destination_selected.emit(target_position)

func _on_cancel_pressed():
	cancelled.emit()

func _input(event):
	# Allow closing with Escape or the interact key
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
