@tool
class_name OfficeRoomZone
extends Node2D

## An editor-friendly room boundary. Edit the room name and bounds in the
## Inspector instead of changing the room indicator script.

@export var room_name: String = "Room"
@export var bounds: Rect2 = Rect2(0.0, 0.0, 256.0, 160.0):
	set(value):
		bounds = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func contains_point(point: Vector2) -> bool:
	return bounds.has_point(point)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(bounds, Color(0.2, 0.65, 1.0, 0.12), true)
		draw_rect(bounds, Color(0.3, 0.75, 1.0, 0.7), false, 2.0)
