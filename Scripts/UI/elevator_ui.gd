# elevator_ui.gd — Floor selection popup for elevator
extends CanvasLayer

signal floor_selected(scene_path: String, spawn_pos: Vector2)
signal cancelled

@onready var panel: PanelContainer = $PanelContainer
@onready var button_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ButtonContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var cancel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CancelButton

## The current floor name (e.g., "Ground Floor"). Buttons for this floor will be disabled.
var current_floor: String = ""

var _floors: Array = []

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

## Call this after instantiating to populate the buttons.
## Each floor entry: { "name": String, "scene": String, "spawn": Vector2 }
func setup(floors: Array, current: String = ""):
	_floors = floors
	current_floor = current

	# Clear any existing buttons
	for child in button_container.get_children():
		child.queue_free()

	# Create a button for each floor
	for floor_data in _floors:
		var btn = Button.new()
		btn.text = floor_data["name"]
		btn.custom_minimum_size = Vector2(200, 36)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		# Disable the button for the current floor
		if floor_data["name"] == current_floor:
			btn.disabled = true
			btn.text = floor_data["name"] + " (Current)"

		var target_scene = floor_data["scene"]
		var target_spawn = floor_data["spawn"]
		btn.pressed.connect(func(): _on_floor_pressed(target_scene, target_spawn))
		button_container.add_child(btn)

func _on_floor_pressed(scene_path: String, spawn_pos: Vector2):
	floor_selected.emit(scene_path, spawn_pos)

func _on_cancel_pressed():
	cancelled.emit()

func _input(event):
	# Allow closing with Escape
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
