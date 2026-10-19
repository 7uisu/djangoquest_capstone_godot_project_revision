extends Node2D

## Shows the current room using the project's existing theme.

const MENU_FONT = preload("res://Textures/Fonts/Pixelify_Sans/PixelifySans-VariableFont_wght.ttf")

@export_enum("Ground Floor", "2nd Floor", "3rd Floor")
var floor_name: String = "Ground Floor"
@export var indicator_position: Vector2 = Vector2(18.0, 15.0)

var _room_label: Label
var _current_room: String = ""


func _ready() -> void:
	_create_indicator()
	call_deferred("_update_room_label")


func _process(_delta: float) -> void:
	_update_room_label()


func _create_indicator() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "RoomIndicatorLayer"
	canvas.layer = 20
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.name = "RoomIndicator"
	panel.position = indicator_position
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	_room_label = Label.new()
	_room_label.add_theme_font_override("font", MENU_FONT)
	_room_label.add_theme_font_size_override("font_size", 14)
	_room_label.text = floor_name
	margin.add_child(_room_label)


func _update_room_label() -> void:
	if _room_label == null:
		return

	var player_nodes := get_tree().get_nodes_in_group("player")
	if player_nodes.is_empty() or not player_nodes[0] is Node2D:
		return

	var player := player_nodes[0] as Node2D
	var room_name := _get_room_at(player.global_position)
	if not room_name.is_empty():
		_set_room_text(room_name)


func _get_room_at(position: Vector2) -> String:
	for child in get_children():
		if child is OfficeRoomZone and child.contains_point(position):
			return child.room_name
	return ""


func _set_room_text(room_name: String) -> void:
	if room_name == _current_room:
		return
	_current_room = room_name
	_room_label.text = floor_name + " - " + room_name
