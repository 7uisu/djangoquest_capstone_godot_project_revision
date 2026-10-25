extends Area2D

## Editor-placeable directory that lists the current floor's visible office NPCs
## and their live room/map positions.

@export var interaction_text := "[F] View Staff Directory"
@export var directory_title := "DJQ Corp — Staff Directory"

@onready var prompt: Label = $Label

var player_is_inside := false


func _ready() -> void:
	if prompt:
		prompt.text = interaction_text
		prompt.visible = false


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = true
		if prompt:
			prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = false
		if prompt:
			prompt.visible = false


func interact() -> void:
	var dialogue_box := _get_dialogue_box()
	if dialogue_box == null or bool(dialogue_box.get("is_active")):
		return
	var entries := _build_directory_entries()
	if entries.is_empty():
		entries.append({"name": directory_title, "text": "No staff are currently listed on this floor."})
	dialogue_box.start(entries)


func _build_directory_entries() -> Array:
	var result: Array = []
	var scene := get_tree().current_scene
	if scene == null:
		return result
	var room_indicator := scene.find_child("RoomIndicator", true, false)
	var floor_name := str(room_indicator.get("floor_name")) if room_indicator and "floor_name" in room_indicator else "Office"

	for npc in get_tree().get_nodes_in_group("office_npcs"):
		if not is_instance_valid(npc) or not npc is Node2D or not npc.visible:
			continue
		var npc_name: String = str(npc.name)
		if "speaker_name" in npc:
			var configured_name: Variant = npc.get("speaker_name")
			if configured_name != null and not str(configured_name).is_empty():
				npc_name = str(configured_name)
		var location := "Hallway"
		if room_indicator:
			for zone in room_indicator.get_children():
				if zone.has_method("contains_point") and zone.contains_point(npc.global_position):
					location = str(zone.get("room_name"))
					break
		var map_position := Vector2i(roundi(npc.global_position.x), roundi(npc.global_position.y))
		result.append({
			"name": directory_title,
			"text": "%s — %s, %s (map position %s)." % [npc_name, floor_name, location, map_position]
		})
	return result


func _get_dialogue_box() -> CanvasLayer:
	for node in get_tree().get_nodes_in_group("dialogue_box"):
		if node is CanvasLayer:
			return node
	var scene := get_tree().current_scene
	return scene.get_node_or_null("DialogueBox") as CanvasLayer if scene else null
