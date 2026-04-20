# quest_manager.gd — Autoload: guided quest text + target names for the HUD arrow
extends Node

signal quest_changed(quest_id: String, quest_text: String)
signal quest_visibility_changed(visible: bool)
signal tracked_quest_changed(quest_id: String)

const HUD_SCENE := preload("res://Scenes/UI/quest_hud.tscn")

var _character_data: Node = null
var _hud: CanvasLayer = null

var current_quest_id: String = ""
var current_quest_text: String = ""
var target_node_names: PackedStringArray = PackedStringArray()

# Which quest the player has chosen to actively track (defaults to current_quest_id)
var tracked_quest_id: String = ""

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
	# Auto-track the new main quest unless player manually chose something else
	if tracked_quest_id.is_empty() or tracked_quest_id == current_quest_id:
		tracked_quest_id = quest_id
		tracked_quest_changed.emit(tracked_quest_id)
	quest_changed.emit(current_quest_id, current_quest_text)
	_sync_hud()


func clear_quest() -> void:
	current_quest_id = ""
	current_quest_text = ""
	tracked_quest_id = ""
	target_node_names = PackedStringArray()
	_has_quest = false
	_suppress_depth = 0
	quest_changed.emit("", "")
	tracked_quest_changed.emit("")
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
		set_quest("ch1:_a_new_chapter", "Head toward the exit doors and begin your journey to college.", ["ExitDoor1", "ExitDoor2"])
	elif _character_data.ch1_quiz_done:
		set_quest("ch1:_goodbyes", "Chat with your friends before leaving the school grounds.", ["MaleBestFriend", "FemaleBestFriend"])
	elif not _character_data.ch1_teaching_done:
		set_quest("ch1:_the_first_lesson", "Speak with the Senior High School Professor to begin your web development journey.", "SHSTeacherInteractable")
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
		set_quest("ch1:_the_internet_cafe", "Step inside the Internet Cafe and find a computer.", ["InternetCafeFrontDoor", "InternetCafeFrontDoor2"])
	elif _character_data.ch1_post_quiz_dialogue_done:
		set_quest("ch1:_catching_the_bus", "Board the bus and travel to the Internet Cafe.", ["BusFastTravel", "BusFastTravel2"])
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
		set_quest("ch1:_an_unusual_encounter", "Talk to the unusual person hanging out at the cafe.", "SpaghettiGuyNPC")


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
		set_quest("ch2:_html_fundamentals", "Find Professor Markup for your first College module.", "NPCMaleCollegeProf01")
	elif not cd.ch2_y1s2_teaching_done:
		set_quest("ch2:_css_styling", "Speak with Professor Syntax to learn about styling websites.", "NPCFemaleCollegeProf01")
	elif not cd.ch2_y2s1_teaching_done:
		set_quest("ch2:_django_views", "Locate Professor View to start working with backend templates.", "NPCMaleCollegeProf02")
	elif not cd.ch2_y2s2_teaching_done:
		set_quest("ch2:_database_models", "Find Professor Query to learn about databases and ORMs.", "NPCMaleCollegeProf03")
	elif not cd.ch2_y3s1_teaching_done:
		set_quest("ch2:_finding_token", "Head to the 2nd Floor to meet Professor Token.", ["CollegeStairsLeft", "CollegeStairsRight"])
	elif not cd.ch2_y3s2_teaching_done:
		set_quest("ch2:_finding_auth", "Head to the 2nd Floor to meet Professor Auth.", ["CollegeStairsLeft", "CollegeStairsRight"])
	elif not cd.ch2_y3mid_teaching_done:
		set_quest("ch2:_finding_rest", "Head to the 2nd Floor to meet Professor REST.", ["CollegeStairsLeft", "CollegeStairsRight"])
	else:
		clear_quest()


func refresh_college_2nd_floor_quest() -> void:
	if _character_data == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path: String = String(scene.scene_file_path)
	if not path.ends_with("college_2nd_floor_map.tscn"):
		return
	var cd = _character_data
	# Only show 2nd floor quests if all 1st floor profs are done
	if not (cd.ch2_y1s1_teaching_done and cd.ch2_y1s2_teaching_done and cd.ch2_y2s1_teaching_done and cd.ch2_y2s2_teaching_done):
		set_quest("ch2:_missing_prerequisites", "Return to the 1st Floor and finish your earlier modules first.", ["CollegeStairsLeft", "CollegeStairsRight"])
	elif not cd.ch2_y3s1_teaching_done:
		set_quest("ch2:_deployment_basics", "Speak with Professor Token about deploying your website.", "NPCMaleCollegeProf04")
	elif not cd.ch2_y3s2_teaching_done:
		set_quest("ch2:_user_authentication", "Find Professor Auth to learn how to secure your app.", "NPCFemaleCollegeProf02")
	elif not cd.ch2_y3mid_teaching_done:
		set_quest("ch2:_api_architecture", "Speak with Professor REST to master application interfaces.", "NPCFemaleCollegeProf03")
	else:
		clear_quest()


# Called when the player clicks a quest entry in the Laptop UI
func set_tracked_quest(id: String) -> void:
	tracked_quest_id = id
	tracked_quest_changed.emit(id)
	# Note: do NOT call _sync_hud() here.
	# The game is paused while the laptop is open, and syncing the HUD
	# at this point could incorrectly hide it. The HUD will refresh
	# automatically when the laptop closes and the game unpauses.


func get_tracked_quest_text() -> String:
	if tracked_quest_id == current_quest_id:
		return current_quest_text
	return ""


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
