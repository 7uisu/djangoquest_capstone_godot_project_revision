# quest_manager.gd — Autoload: guided quest text + target names for the HUD arrow
extends Node

signal quest_changed(quest_id: String, quest_text: String)
signal quest_visibility_changed(visible: bool)

const HUD_SCENE := preload("res://Scenes/UI/quest_hud.tscn")

var _character_data: Node = null
var _hud: CanvasLayer = null

var current_quest_id: String = ""
var current_quest_text: String = ""
var target_node_names: PackedStringArray = PackedStringArray()

var _has_quest: bool = false
var _suppress_depth: int = 0

func _ready() -> void:
	_character_data = get_node_or_null("/root/CharacterData")
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)


func set_quest(quest_id: String, quest_text: String, target_names: Variant = "") -> void:
	current_quest_id = quest_id
	current_quest_text = quest_text
	target_node_names = _normalize_target_names(target_names)
	_has_quest = not quest_id.is_empty() or not quest_text.is_empty()
	quest_changed.emit(current_quest_id, current_quest_text)
	_sync_hud()


func clear_quest() -> void:
	current_quest_id = ""
	current_quest_text = ""
	target_node_names = PackedStringArray()
	_has_quest = false
	_suppress_depth = 0
	quest_changed.emit("", "")
	_sync_hud()


func hide_quest() -> void:
	_suppress_depth += 1
	quest_visibility_changed.emit(is_quest_content_visible())
	_sync_hud()


func show_quest() -> void:
	_suppress_depth = maxi(0, _suppress_depth - 1)
	quest_visibility_changed.emit(is_quest_content_visible())
	_sync_hud()


## Clears stacked hide_quest() calls (e.g. after teaching + quiz) so the HUD can show again.
func reset_suppression() -> void:
	if _suppress_depth == 0:
		return
	_suppress_depth = 0
	quest_visibility_changed.emit(is_quest_content_visible())
	_sync_hud()


func is_quest_content_visible() -> bool:
	return _has_quest and _suppress_depth == 0


func get_arrow_target_global_position() -> Vector2:
	var scene := get_tree().current_scene
	if scene == null or target_node_names.is_empty():
		return Vector2.ZERO
	var player := _get_player()
	if player == null:
		return Vector2.ZERO
	var best: Vector2 = Vector2.ZERO
	var best_d := INF
	for name in target_node_names:
		var n := scene.find_child(name, true, false)
		if n == null or not is_instance_valid(n):
			continue
		var gp: Vector2
		if n is Node2D:
			gp = (n as Node2D).global_position
		elif n is Control:
			gp = (n as Control).get_global_rect().get_center()
		else:
			continue
		var d := player.global_position.distance_squared_to(gp)
		if d < best_d:
			best_d = d
			best = gp
	return best


func refresh_ch1_school_quest() -> void:
	if _character_data == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path: String = String(scene.scene_file_path)
	if not path.ends_with("school_map.tscn"):
		return
	if not _character_data.has_seen_tutorial:
		clear_quest()
		return
	if _character_data.ch1_post_quiz_dialogue_done:
		set_quest("ch1_exit_school", "Head to the exit door", ["ExitDoor1", "ExitDoor2"])
	elif _character_data.ch1_quiz_done:
		set_quest("ch1_talk_friends", "Talk to your friends before leaving", ["MaleBestFriend", "FemaleBestFriend"])
	elif not _character_data.ch1_teaching_done:
		set_quest("ch1_talk_teacher", "Talk to the SHS Professor to start class", "SHSTeacherInteractable")
	else:
		clear_quest()


func refresh_ch1_outdoor_quest() -> void:
	if _character_data == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path: String = String(scene.scene_file_path)
	if not path.ends_with("outdoor_map_convenience_store_cutscene2.tscn"):
		return
	if _character_data.ch1_spaghetti_guy_cutscene_done:
		clear_quest()
	elif _character_data.ch1_convenience_store_cutscene_done:
		set_quest("ch1_enter_cafe", "Enter the Internet Cafe", ["InternetCafeFrontDoor", "InternetCafeFrontDoor2"])
	elif _character_data.ch1_post_quiz_dialogue_done:
		set_quest("ch1_go_bus", "Go to the bus and travel to the Internet Cafe", ["BusFastTravel", "BusFastTravel2"])
	else:
		clear_quest()


func refresh_ch1_internet_cafe_quest() -> void:
	if _character_data == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path: String = String(scene.scene_file_path)
	if not path.ends_with("internet_cafe_map_cutscene.tscn"):
		return
	if _character_data.ch1_spaghetti_guy_cutscene_done:
		clear_quest()
	else:
		set_quest("ch1_talk_spaghetti", "Talk to the person at the Internet Cafe", "SpaghettiGuyNPC")


func refresh_college_quest() -> void:
	if _character_data == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path: String = String(scene.scene_file_path)
	if not path.ends_with("college_map.tscn"):
		return
	var cd = _character_data
	if not cd.ch2_y1s1_teaching_done:
		set_quest("ch2_talk_markup", "Talk to Professor Markup", "NPCMaleCollegeProf01")
	elif not cd.ch2_y1s2_teaching_done:
		set_quest("ch2_talk_syntax", "Talk to Professor Syntax", "NPCFemaleCollegeProf01")
	elif not cd.ch2_y2s1_teaching_done:
		set_quest("ch2_talk_view", "Talk to Professor View", "NPCMaleCollegeProf02")
	elif not cd.ch2_y2s2_teaching_done:
		set_quest("ch2_talk_query", "Talk to Professor Query", "NPCMaleCollegeProf03")
	else:
		clear_quest()


func _sync_hud() -> void:
	if _hud and _hud.has_method("sync_from_manager"):
		_hud.sync_from_manager()


func _normalize_target_names(target_names: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if target_names is String:
		if not target_names.is_empty():
			out.append(target_names)
	elif target_names is PackedStringArray:
		out = target_names
	elif target_names is Array:
		for x in target_names:
			var s := str(x)
			if not s.is_empty():
				out.append(s)
	return out


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D
