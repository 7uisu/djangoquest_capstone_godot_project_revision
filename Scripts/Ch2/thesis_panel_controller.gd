# thesis_panel_controller.gd — Orchestrates the 3-panelist Thesis Defense
# Placed as a child of college_map_manager or the 2nd floor scene.
# Handles: sequential panelist gating, per-panelist challenge loops, heart system,
#           items disabled, overflow stack hidden, dramatic P3 failure, auto-save.
extends Node

signal panelist_defeated(panelist_index: int)
signal thesis_completed

const IDE_SCENE := preload("res://Scenes/Games/coding_challenge_ui.tscn")
const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")
const ThesisChallenges = preload("res://Scripts/Ch2/thesis_challenge_data.gd")

# ─── Panelist Configuration ──────────────────────────────────────────────────

const PANELIST_CONFIG = {
	1: { "name": "Panelist Cruz", "title": "The Setup Specialist", "hearts": 5 },
	2: { "name": "Panelist Santos", "title": "The Data Tester", "hearts": 5 },
	3: { "name": "Panelist Reyes", "title": "The System Debugger", "hearts": 3 },
}

# ─── State ───────────────────────────────────────────────────────────────────
var _character_data: Node = null
var _quest_manager: Node = null

var _active: bool = false
var _current_panelist: int = 0         # 1, 2, or 3
var _current_challenge_idx: int = 0
var _challenges: Array = []
var _hearts: int = 5
var _max_hearts: int = 5

var _ide_canvas: CanvasLayer = null
var _ide_instance: Control = null
var _health_ui: Control = null

var _panelist_npcs: Dictionary = {}    # { 1: Node, 2: Node, 3: Node }

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_character_data = get_node_or_null("/root/CharacterData")
	_quest_manager = get_node_or_null("/root/QuestManager")

# ─── Public API ──────────────────────────────────────────────────────────────

func register_panelist_npc(panelist_index: int, npc_node: Node) -> void:
	_panelist_npcs[panelist_index] = npc_node

## Called by dialogue_interactable via lesson_controller meta pattern
func _on_professor_interacted() -> void:
	# Find which panelist NPC was interacted with (closest to player)
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0] as Node2D

	var closest_idx := -1
	var closest_dist := INF

	for idx in _panelist_npcs.keys():
		var npc = _panelist_npcs[idx]
		if npc == null or not is_instance_valid(npc):
			continue
		var dist = player.global_position.distance_squared_to(npc.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = idx

	if closest_idx > 0:
		on_panelist_interacted(closest_idx)

func get_panelist_progress() -> int:
	if _character_data:
		return _character_data.thesis_panelist_progress
	return 0

func is_panelist_available(panelist_index: int) -> bool:
	var progress = get_panelist_progress()
	# Panelist N is available when progress == N-1 (previous panelists defeated)
	return panelist_index == progress + 1

func is_panelist_defeated(panelist_index: int) -> bool:
	return get_panelist_progress() >= panelist_index

## Called when a panelist NPC is interacted with
func on_panelist_interacted(panelist_index: int) -> void:
	if _active:
		return
	if is_panelist_defeated(panelist_index):
		_show_already_defeated_dialogue(panelist_index)
		return
	if not is_panelist_available(panelist_index):
		_show_locked_dialogue(panelist_index)
		return

	_current_panelist = panelist_index
	_show_intro_dialogue(panelist_index)

# ─── Dialogue ────────────────────────────────────────────────────────────────

func _show_intro_dialogue(panelist_index: int) -> void:
	var config = PANELIST_CONFIG[panelist_index]
	var pname = config["name"]
	var ptitle = config["title"]
	var hearts = config["hearts"]

	var lines = []
	match panelist_index:
		1:
			lines.append({ "name": pname, "text": "I'm [color=#f0c674]%s[/color], %s." % [pname, ptitle] })
			lines.append({ "name": pname, "text": "I'll test your grasp of [color=#61afef]Django fundamentals[/color] — URLs, views, models, templates, and settings. 5 challenges. You have [color=#e06c75]%d hearts[/color]." % hearts })
		2:
			lines.append({ "name": pname, "text": "I'm [color=#f0c674]%s[/color], %s." % [pname, ptitle] })
			lines.append({ "name": pname, "text": "10 rapid-fire questions on [color=#61afef]Models, ORM, and Forms[/color]. [color=#e5c07b]20 seconds each[/color]. You have [color=#e06c75]%d hearts[/color]." % hearts })
		3:
			lines.append({ "name": pname, "text": "I'm [color=#f0c674]%s[/color], %s. The final challenge." % [pname, ptitle] })
			lines.append({ "name": pname, "text": "10 debugging challenges across [color=#61afef]the entire curriculum[/color]. Only [color=#e06c75]%d hearts[/color]. No hints. No items." % hearts })
			lines.append({ "name": pname, "text": "[color=#e06c75]Are you ready to defend your thesis?[/color]" })

	lines.append({
		"name": "You",
		"text": "Begin the defense?",
		"choices": ["Yes, I'm ready.", "Not yet."]
	})

	var players = get_tree().get_nodes_in_group("player")
	var player = players[0] if players.size() > 0 else null
	if player:
		player.can_move = false
		player.can_interact = false

	var dialogue_box = _get_dialogue_box()
	var choice_state = {"selected": -1}

	if dialogue_box:
		var cb = func(idx): choice_state["selected"] = idx
		dialogue_box.choice_selected.connect(cb)
		dialogue_box.start(lines)
		await dialogue_box.dialogue_finished
		if dialogue_box.choice_selected.is_connected(cb):
			dialogue_box.choice_selected.disconnect(cb)

	if player:
		player.can_move = true
		player.can_interact = true

	await get_tree().create_timer(0.1).timeout

	if choice_state["selected"] == 1 or choice_state["selected"] == -1:
		return

	_start_panelist(panelist_index)

func _show_already_defeated_dialogue(panelist_index: int) -> void:
	var config = PANELIST_CONFIG[panelist_index]
	var pname = config["name"]

	var players = get_tree().get_nodes_in_group("player")
	var player = players[0] if players.size() > 0 else null
	if player:
		player.can_move = false
		player.can_interact = false

	var dialogue_box = _get_dialogue_box()
	if dialogue_box:
		dialogue_box.start([
			{ "name": pname, "text": "You've already passed my part of the defense. [color=#98c379]Good work![/color]" }
		])
		await dialogue_box.dialogue_finished

	if player:
		player.can_move = true
		player.can_interact = true

func _show_locked_dialogue(panelist_index: int) -> void:
	var config = PANELIST_CONFIG[panelist_index]
	var pname = config["name"]
	var prev_name = PANELIST_CONFIG.get(panelist_index - 1, {}).get("name", "previous panelist")

	var players = get_tree().get_nodes_in_group("player")
	var player = players[0] if players.size() > 0 else null
	if player:
		player.can_move = false
		player.can_interact = false

	var dialogue_box = _get_dialogue_box()
	if dialogue_box:
		dialogue_box.start([
			{ "name": pname, "text": "You need to pass [color=#e5c07b]%s[/color] first before I can evaluate you." % prev_name }
		])
		await dialogue_box.dialogue_finished

	if player:
		player.can_move = true
		player.can_interact = true

# ─── Challenge Orchestration ─────────────────────────────────────────────────

func _start_panelist(panelist_index: int) -> void:
	_active = true
	_current_panelist = panelist_index
	_current_challenge_idx = 0

	var config = PANELIST_CONFIG[panelist_index]
	_max_hearts = config["hearts"]
	_hearts = _max_hearts

	# Load challenges for this panelist
	_challenges = ThesisChallenges.get_challenges(panelist_index)
	if _challenges.is_empty():
		push_error("ThesisPanelController: No challenges for panelist %d" % panelist_index)
		_active = false
		return

	_open_ide()

func _open_ide() -> void:
	if _ide_instance == null or not is_instance_valid(_ide_instance) or _ide_canvas == null or not is_instance_valid(_ide_canvas):
		if _ide_canvas and is_instance_valid(_ide_canvas):
			_ide_canvas.queue_free()

		_ide_canvas = CanvasLayer.new()
		_ide_canvas.layer = 100
		_ide_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().current_scene.add_child(_ide_canvas)

		_ide_instance = IDE_SCENE.instantiate()
		_ide_canvas.add_child(_ide_instance)

	# Connect signals
	if not _ide_instance.challenge_completed.is_connected(_on_challenge_completed):
		_ide_instance.challenge_completed.connect(_on_challenge_completed)
	if not _ide_instance.challenge_failed.is_connected(_on_challenge_failed):
		_ide_instance.challenge_failed.connect(_on_challenge_failed)

	_configure_ide()
	_load_current_challenge()

	get_tree().paused = true
	_ide_canvas.visible = true
	_ide_instance.visible = true

func _configure_ide() -> void:
	if _ide_instance == null:
		return

	# Hide OverflowStack button
	var overflow_btn = _ide_instance.get_node_or_null("IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox/OverflowStackButton")
	if overflow_btn:
		overflow_btn.visible = false

	# Hide close button
	_ide_instance.hide_close_button = true
	_ide_instance.is_student_sequence = true
	var close_btn = _ide_instance.get_node_or_null("IDEScreen/TitleBar/CloseButton")
	if close_btn:
		close_btn.visible = false

	# Hide items button
	var items_btn = _ide_instance.get_node_or_null("IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox/ItemsButton")
	if items_btn:
		items_btn.visible = false

	# Create health UI
	_create_health_ui()

func _create_health_ui() -> void:
	var mission_vbox = _ide_instance.get_node_or_null("IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox")
	if mission_vbox == null:
		return

	if _health_ui and is_instance_valid(_health_ui):
		_health_ui.queue_free()

	_health_ui = VBoxContainer.new()
	_health_ui.name = "PanelistHealthUI"
	_health_ui.custom_minimum_size = Vector2(0, 40)

	_update_heart_display()

	var overflow_btn = mission_vbox.get_node_or_null("OverflowStackButton")
	if overflow_btn:
		var idx = overflow_btn.get_index()
		mission_vbox.add_child(_health_ui)
		mission_vbox.move_child(_health_ui, idx)
	else:
		mission_vbox.add_child(_health_ui)

func _update_heart_display() -> void:
	if _health_ui == null or not is_instance_valid(_health_ui):
		return

	for child in _health_ui.get_children():
		child.queue_free()

	var config = PANELIST_CONFIG[_current_panelist]

	# Panelist name label
	var title = Label.new()
	title.text = "❤️ %s:" % config["name"]
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("e06c75"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_health_ui.add_child(title)

	# Hearts row
	var hearts_row = HBoxContainer.new()
	hearts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(_max_hearts):
		var heart = Label.new()
		if i < _hearts:
			heart.text = "♥ "
			heart.add_theme_color_override("font_color", Color("e06c75"))
		else:
			heart.text = "♡ "
			heart.add_theme_color_override("font_color", Color("5c6370"))
		heart.add_theme_font_size_override("font_size", 18)
		hearts_row.add_child(heart)
	_health_ui.add_child(hearts_row)

	# Progress label
	var prog = Label.new()
	prog.text = "Challenge %d/%d" % [_current_challenge_idx + 1, _challenges.size()]
	prog.add_theme_font_size_override("font_size", 11)
	prog.add_theme_color_override("font_color", Color("abb2bf"))
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_ui.add_child(prog)

func _load_current_challenge() -> void:
	if _current_challenge_idx >= _challenges.size():
		_on_panelist_completed()
		return

	var challenge = _challenges[_current_challenge_idx].duplicate(true)
	var config = PANELIST_CONFIG[_current_panelist]

	# Prefix title with panelist info
	var prefix = "🎓 %s — " % config["name"]
	if _current_panelist == 3:
		prefix = "⚔️ FINAL BOSS: %s — " % config["name"]
	challenge["title"] = prefix + challenge.get("title", "Challenge")

	_ide_instance.load_challenge(challenge)
	_ide_instance.progress_label.text = "Challenge %d/%d — %s" % [
		_current_challenge_idx + 1, _challenges.size(), config["title"]
	]

	_configure_ide()

# ─── Signal Handlers ─────────────────────────────────────────────────────────

func _on_challenge_completed(success: bool, _challenge_id: String) -> void:
	if not _active:
		return

	if success:
		_current_challenge_idx += 1
		if _current_challenge_idx >= _challenges.size():
			_on_panelist_completed()
		else:
			await get_tree().create_timer(1.0).timeout
			_load_current_challenge()

func _on_challenge_failed() -> void:
	if not _active:
		return

	_hearts -= 1
	_update_heart_display()

	if _hearts <= 0:
		# Failed this panelist
		_increment_retakes()

		if _current_panelist == 3:
			_show_dramatic_failure()
		else:
			_show_normal_failure()
	else:
		# Retry same question
		await get_tree().create_timer(1.5).timeout
		_load_current_challenge()

func _show_normal_failure() -> void:
	if _ide_instance and _ide_instance.has_method("show_custom_result"):
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(_ide_instance):
			_ide_instance.show_custom_result(
				"💥 Defense Failed",
				"You ran out of hearts. Regroup and try again.",
				"OK"
			)
			await _ide_instance.challenge_completed
	_close_ide()
	_active = false

func _show_dramatic_failure() -> void:
	if _ide_instance and _ide_instance.has_method("show_custom_result"):
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(_ide_instance):
			_ide_instance.show_custom_result(
				"⚔️ DEFENSE FAILED!",
				"The panel has found critical gaps in your knowledge.\nYou must start this defense over from the beginning.\n\nStudy harder and come back stronger.",
				"Accept Defeat"
			)
			await _ide_instance.challenge_completed
	_close_ide()
	_active = false

func _on_panelist_completed() -> void:
	_active = false

	# Calculate grade based on hearts remaining
	var config = PANELIST_CONFIG[_current_panelist]
	var max_h = config["hearts"]
	var grade = _calculate_grade(_hearts, max_h)

	# Store grade in character data
	if _character_data:
		_character_data.set("thesis_panelist_%d_grade" % _current_panelist, grade)
		_character_data.thesis_panelist_progress = _current_panelist

		if _current_panelist >= 3:
			_character_data.thesis_completed = true
			_character_data.thesis_completed_at = Time.get_datetime_string_from_system()

	# Show success in IDE
	if _ide_instance and _ide_instance.has_method("show_custom_result"):
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(_ide_instance):
			var result_title = ""
			var result_body = ""
			if _current_panelist == 3:
				# Calculate combined thesis grade (average of all 3 panelists)
				var combined = _get_combined_thesis_grade()
				result_title = "🎓 THESIS DEFENDED!"
				result_body = "Congratulations! You have successfully defended your thesis!"
				result_body += "\n\nPanel Grades:"
				result_body += "\n  Panelist Cruz: %s" % _grade_to_string(_character_data.thesis_panelist_1_grade)
				result_body += "\n  Panelist Santos: %s" % _grade_to_string(_character_data.thesis_panelist_2_grade)
				result_body += "\n  Panelist Reyes: %s" % _grade_to_string(grade)
				result_body += "\n\n★ Combined Thesis Grade: %s ★" % _grade_to_string(combined)
			else:
				result_title = "✅ Panel %d Passed!" % _current_panelist
				result_body = "You passed %s's evaluation.\nGrade: %s" % [config["name"], _grade_to_string(grade)]

			_ide_instance.show_custom_result(result_title, result_body, "Continue")
			await _ide_instance.challenge_completed

	_close_ide()

	panelist_defeated.emit(_current_panelist)

	if _current_panelist >= 3:
		thesis_completed.emit()

	# Auto-save with loading overlay
	await _autosave_progress()

	# Update panelist NPC visuals
	_update_npc_visuals()

	# Update quest HUD
	_update_quest_hud()



func _close_ide() -> void:
	get_tree().paused = false
	if _ide_canvas and is_instance_valid(_ide_canvas):
		_ide_canvas.queue_free()
		_ide_canvas = null
		_ide_instance = null
		_health_ui = null

func _increment_retakes() -> void:
	if _character_data:
		var key = "thesis_panelist_%d_retakes" % _current_panelist
		var current = _character_data.get(key)
		if current != null:
			_character_data.set(key, current + 1)

func _calculate_grade(hearts_remaining: int, max_hearts: int) -> float:
	# Grade scale: all hearts = 1.0, 0 hearts = 5.0
	if max_hearts <= 0:
		return 3.0
	var ratio = float(hearts_remaining) / float(max_hearts)
	if ratio >= 1.0:
		return 1.0
	elif ratio >= 0.8:
		return 1.25
	elif ratio >= 0.6:
		return 1.5
	elif ratio >= 0.4:
		return 2.0
	elif ratio >= 0.2:
		return 2.5
	else:
		return 3.0

func _grade_to_string(grade: float) -> String:
	if grade <= 1.0: return "1.0 — Excellent!"
	elif grade <= 1.25: return "1.25 — Great!"
	elif grade <= 1.5: return "1.5 — Very Good"
	elif grade <= 2.0: return "2.0 — Good"
	elif grade <= 2.5: return "2.5 — Satisfactory"
	else: return "3.0 — Passing"

func _get_combined_thesis_grade() -> float:
	# Average of all 3 panelist grades = one "Thesis Defense" subject grade
	if not _character_data:
		return 3.0
	var g1 = _character_data.thesis_panelist_1_grade
	var g2 = _character_data.thesis_panelist_2_grade
	var g3 = _character_data.thesis_panelist_3_grade
	var avg = (g1 + g2 + g3) / 3.0
	# Snap to nearest standard grade
	if avg <= 1.125: return 1.0
	elif avg <= 1.375: return 1.25
	elif avg <= 1.75: return 1.5
	elif avg <= 2.25: return 2.0
	elif avg <= 2.75: return 2.5
	else: return 3.0

# ─── Auto-save ───────────────────────────────────────────────────────────────

func _autosave_progress() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.save_game()

	var players = get_tree().get_nodes_in_group("player")
	var player = players[0] if players.size() > 0 else null
	if player:
		player.can_move = false
		player.block_ui_input = true
		player.set_physics_process(false)

	var LoadingOverlay = load("res://Scripts/UI/loading_overlay.gd")
	var overlay = LoadingOverlay.create(get_tree(), "Auto Saving, please wait...")
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(overlay):
		await overlay.dismiss()

	if player:
		player.can_move = true
		player.block_ui_input = false
		player.set_physics_process(true)

# ─── NPC Visuals ─────────────────────────────────────────────────────────────

func _update_npc_visuals() -> void:
	for idx in _panelist_npcs.keys():
		var npc = _panelist_npcs[idx]
		if npc == null or not is_instance_valid(npc):
			continue

		var label_text := ""
		if is_panelist_defeated(idx):
			label_text = "✓ Done"
		elif is_panelist_available(idx):
			label_text = "❗"
		else:
			label_text = "🔒"

		if npc.has_method("set_passive_label"):
			npc.set_passive_label(label_text)
		elif npc.get_node_or_null("Label"):
			npc.get_node("Label").text = label_text

# ─── Quest Tracking ─────────────────────────────────────────────────────────

func _update_quest_hud() -> void:
	if not _quest_manager:
		return
	var progress = get_panelist_progress()
	if progress >= 3:
		_quest_manager.set_quest("ch2:_go_to_markup", "🎓 Thesis defended! Go to the 1st Floor and talk to Professor Markup.", ["CollegeStairsLeft", "CollegeStairsRight"])
	elif progress == 2:
		_quest_manager.set_quest("ch2:_final_panelist", "⚔️ Face the final panelist, Reyes!", "NPCPanelist03")
	elif progress == 1:
		_quest_manager.set_quest("ch2:_panelist_santos", "📋 Panelist Santos is waiting to evaluate you.", "NPCPanelist02")
	else:
		_quest_manager.set_quest("ch2:_panelist_cruz", "📋 Defend your thesis! Talk to Panelist Cruz.", "NPCPanelist01")

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _get_dialogue_box() -> Node:
	var boxes = get_tree().get_nodes_in_group("dialogue_box")
	if boxes.size() > 0:
		return boxes[0]
	var scene_root = get_tree().current_scene
	for child in scene_root.get_children():
		if child.has_method("start") and child is CanvasLayer:
			return child
	var instance = DIALOGUE_BOX_SCENE.instantiate()
	scene_root.add_child(instance)
	return instance
