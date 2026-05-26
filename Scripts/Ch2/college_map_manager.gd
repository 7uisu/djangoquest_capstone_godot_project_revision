# college_map_manager.gd — Manages the college map scene
# Wires up professor NPCs to their lesson controllers.
# Fullscreen teaching placeholders (before the coding UI) are driven by
# ch2_professor_markup_controller.gd on the wired NPC via lesson_controller meta.
extends Node2D

const ProfMarkupController = preload("res://Scripts/Ch2/ch2_professor_markup_controller.gd")
const ProfSyntaxController = preload("res://Scripts/Ch2/ch2_professor_syntax_controller.gd")
const ProfViewController = preload("res://Scripts/Ch2/ch2_professor_view_controller.gd")
const ProfQueryController = preload("res://Scripts/Ch2/ch2_professor_query_controller.gd")
const ProfTokenController = preload("res://Scripts/Ch2/ch2_professor_token_controller.gd")
const ProfAuthController = preload("res://Scripts/Ch2/ch2_professor_auth_controller.gd")
const ProfRESTController = preload("res://Scripts/Ch2/ch2_professor_rest_controller.gd")
const StudentQuizControllerScript = preload("res://Scripts/Ch2/student_quiz_controller.gd")
const ThesisPanelControllerScript = preload("res://Scripts/Ch2/thesis_panel_controller.gd")

var _professor_markup_controller: Node = null
var _professor_syntax_controller: Node = null
var _professor_view_controller: Node = null
var _professor_query_controller: Node = null
var _professor_token_controller: Node = null
var _professor_auth_controller: Node = null
var _professor_rest_controller: Node = null
var _student_quiz_controller: Node = null
var _thesis_panel_controller: Node = null

# Professor key → teaching_done flag mapping
const PROF_KEY_MAP := {
	"y1s1": "ch2_y1s1_teaching_done",
	"y1s2": "ch2_y1s2_teaching_done",
	"y2s1": "ch2_y2s1_teaching_done",
	"y2s2": "ch2_y2s2_teaching_done",
	"y3s1": "ch2_y3s1_teaching_done",
	"y3s2": "ch2_y3s2_teaching_done",
	"y3mid": "ch2_y3mid_teaching_done",
}

# 1F professor keys (Markup, Syntax, View, Query)
const FLOOR1_PROF_KEYS := ["y1s1", "y1s2", "y2s1", "y2s2"]
# 2F professor keys (Token, Auth, REST)
const FLOOR2_PROF_KEYS := ["y3s1", "y3s2", "y3mid"]

func _ready() -> void:
	print("CollegeMapManager: _ready() called")
	
	var cd = get_node_or_null("/root/CharacterData")
	
	# Wait a frame so all sibling nodes are ready
	await get_tree().process_frame
	print("CollegeMapManager: Frame waited, setting up professors...")
	_setup_professor_markup()
	_setup_professor_syntax()
	_setup_professor_view()
	_setup_professor_query()
	_setup_professor_token()
	_setup_professor_auth()
	_setup_professor_rest()

	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("refresh_college_quest"):
		qm.refresh_college_quest()
	if qm and qm.has_method("refresh_college_2nd_floor_quest"):
		qm.refresh_college_2nd_floor_quest()

	# Mark that the player has reached college (unlocks SIS on laptop)
	if cd:
		cd.has_reached_college = true

	# ── Student Quiz Controller ─────────────────────────────────────────
	_setup_student_quiz_controller(cd)

	# ── Thesis Panel Controller (Panelists) ─────────────────────────────
	_setup_thesis_panel_controller(cd)

	# ── College SIS Tutorial (first time only) ────────────────────────
	if cd and not cd.has_seen_college_sis_tutorial:
		await get_tree().create_timer(0.5).timeout
		await _run_college_sis_tutorial(cd)

	# ── Shop NPC Tutorial (first time, after SIS tutorial) ──────────
	if cd and not cd.has_seen_shop_tutorial:
		await get_tree().create_timer(0.5).timeout
		await _run_shop_pan_tutorial(cd)

func _setup_professor_markup():
	# Find the 1st male professor NPC
	var prof_npc = _find_node_recursive("NPCMaleCollegeProf01")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCMaleCollegeProf01 not found!")
		print("CollegeMapManager: ERROR — NPCMaleCollegeProf01 NOT FOUND")
		# Debug: print all children of Professors node
		var scene_root = get_tree().current_scene
		var profs = scene_root.get_node_or_null("Professors")
		if profs:
			print("CollegeMapManager: Professors node found with children:")
			for child in profs.get_children():
				print("  - ", child.name, " (", child.get_class(), ")")
		else:
			print("CollegeMapManager: No 'Professors' node found under root")
			print("CollegeMapManager: Root children:")
			for child in scene_root.get_children():
				print("  - ", child.name, " (", child.get_class(), ")")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_markup_controller = Node.new()
	_professor_markup_controller.name = "ProfMarkupController"
	_professor_markup_controller.set_script(ProfMarkupController)
	add_child(_professor_markup_controller)
	
	print("CollegeMapManager: Controller created and added as child")
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor Markup"
	
	# Set the controller on the NPC via meta — dialogue_interactable.gd
	# checks for this in interact() and routes to the controller
	prof_npc.set_meta("lesson_controller", _professor_markup_controller)
	prof_npc.set_meta("music_track", "Professor_Markup")
	
	print("CollegeMapManager: Meta 'lesson_controller' set on NPC")
	print("CollegeMapManager: NPC has_meta check = ", prof_npc.has_meta("lesson_controller"))
	print("CollegeMapManager: Professor Markup wired successfully!")

func _setup_professor_syntax():
	# Find the 1st female professor NPC
	var prof_npc = _find_node_recursive("NPCFemaleCollegeProf01")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCFemaleCollegeProf01 not found!")
		print("CollegeMapManager: ERROR — NPCFemaleCollegeProf01 NOT FOUND")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_syntax_controller = Node.new()
	_professor_syntax_controller.name = "ProfSyntaxController"
	_professor_syntax_controller.set_script(ProfSyntaxController)
	add_child(_professor_syntax_controller)
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor Syntax"
	
	# Set the controller on the NPC via meta
	prof_npc.set_meta("lesson_controller", _professor_syntax_controller)
	prof_npc.set_meta("music_track", "Professor_Syntax")
	
	print("CollegeMapManager: Professor Syntax wired to NPCFemaleCollegeProf01 successfully!")

func _setup_professor_view():
	# Find the 2nd male professor NPC
	var prof_npc = _find_node_recursive("NPCMaleCollegeProf02")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCMaleCollegeProf02 not found!")
		print("CollegeMapManager: ERROR — NPCMaleCollegeProf02 NOT FOUND")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_view_controller = Node.new()
	_professor_view_controller.name = "ProfViewController"
	_professor_view_controller.set_script(ProfViewController)
	add_child(_professor_view_controller)
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor View"
	
	# Set the controller on the NPC via meta
	prof_npc.set_meta("lesson_controller", _professor_view_controller)
	prof_npc.set_meta("music_track", "Professor_View")
	
	
	print("CollegeMapManager: Professor View wired to NPCMaleCollegeProf02 successfully!")

func _setup_professor_query():
	# Find the 3rd male professor NPC
	var prof_npc = _find_node_recursive("NPCMaleCollegeProf03")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCMaleCollegeProf03 not found!")
		print("CollegeMapManager: ERROR — NPCMaleCollegeProf03 NOT FOUND")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_query_controller = Node.new()
	_professor_query_controller.name = "ProfQueryController"
	_professor_query_controller.set_script(ProfQueryController)
	add_child(_professor_query_controller)
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor Query"
	
	# Set the controller on the NPC via meta
	prof_npc.set_meta("lesson_controller", _professor_query_controller)
	prof_npc.set_meta("music_track", "Professor_Query")
	
	print("CollegeMapManager: Professor Query wired to NPCMaleCollegeProf03 successfully!")

func _setup_professor_token():
	# Find the 4th male professor NPC (2nd floor)
	var prof_npc = _find_node_recursive("NPCMaleCollegeProf04")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCMaleCollegeProf04 not found!")
		print("CollegeMapManager: ERROR — NPCMaleCollegeProf04 NOT FOUND")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_token_controller = Node.new()
	_professor_token_controller.name = "ProfTokenController"
	_professor_token_controller.set_script(ProfTokenController)
	add_child(_professor_token_controller)
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor Token"
	
	# Set the controller on the NPC via meta
	prof_npc.set_meta("lesson_controller", _professor_token_controller)
	prof_npc.set_meta("music_track", "Professor_Token")
	
	print("CollegeMapManager: Professor Token wired to NPCMaleCollegeProf04 successfully!")

func _setup_professor_auth():
	# Find the 2nd female professor NPC (2nd floor)
	var prof_npc = _find_node_recursive("NPCFemaleCollegeProf02")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCFemaleCollegeProf02 not found!")
		print("CollegeMapManager: ERROR — NPCFemaleCollegeProf02 NOT FOUND")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_auth_controller = Node.new()
	_professor_auth_controller.name = "ProfAuthController"
	_professor_auth_controller.set_script(ProfAuthController)
	add_child(_professor_auth_controller)
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor Auth"
	
	# Set the controller on the NPC via meta
	prof_npc.set_meta("lesson_controller", _professor_auth_controller)
	prof_npc.set_meta("music_track", "Professor_Auth")
	
	print("CollegeMapManager: Professor Auth wired to NPCFemaleCollegeProf02 successfully!")

func _setup_professor_rest():
	# Find the 3rd female professor NPC (2nd floor)
	var prof_npc = _find_node_recursive("NPCFemaleCollegeProf03")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCFemaleCollegeProf03 not found!")
		print("CollegeMapManager: ERROR — NPCFemaleCollegeProf03 NOT FOUND")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_rest_controller = Node.new()
	_professor_rest_controller.name = "ProfRESTController"
	_professor_rest_controller.set_script(ProfRESTController)
	add_child(_professor_rest_controller)
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor REST"
	
	# Set the controller on the NPC via meta
	prof_npc.set_meta("lesson_controller", _professor_rest_controller)
	prof_npc.set_meta("music_track", "Professor_Rest")
	
	print("CollegeMapManager: Professor REST wired to NPCFemaleCollegeProf03 successfully!")

func _find_node_recursive(node_name: String) -> Node:
	# Check Professors group first
	var scene_root = get_tree().current_scene
	var profs = scene_root.get_node_or_null("Professors")
	if profs:
		var n = profs.get_node_or_null(node_name)
		if n: return n
	# Fallback: deep search
	return _deep_find(scene_root, node_name)

func _deep_find(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var result = _deep_find(child, target)
		if result:
			return result
	return null

# ─── Student Quiz Controller Setup ───────────────────────────────────────────

func _setup_student_quiz_controller(cd) -> void:
	if cd == null:
		return

	# Create the controller
	_student_quiz_controller = Node.new()
	_student_quiz_controller.name = "StudentQuizController"
	_student_quiz_controller.set_script(StudentQuizControllerScript)
	add_child(_student_quiz_controller)

	# Connect completion signal
	_student_quiz_controller.student_sequence_completed.connect(_on_student_sequence_completed)

	# Run the check now
	check_and_activate_student_sequences()

func check_and_activate_student_sequences() -> void:
	"""Public method to dynamically trigger student sequences after a lesson ends."""
	var cd = get_node_or_null("/root/CharacterData")
	if cd == null or _student_quiz_controller == null:
		return

	# Determine which floor we're on
	var scene_path = String(get_tree().current_scene.scene_file_path)
	var is_2nd_floor = scene_path.ends_with("college_2nd_floor_map.tscn")
	var prof_keys = FLOOR2_PROF_KEYS if is_2nd_floor else FLOOR1_PROF_KEYS

	# Check if there's an active student sequence to resume
	if cd.student_seq_active_professor != "" and cd.student_seq_active_professor in prof_keys:
		if not _student_quiz_controller.is_active():
			_resume_student_sequence(cd)
		return

	# Check if a professor is done but students not yet completed
	for prof_key in prof_keys:
		var flag = PROF_KEY_MAP.get(prof_key, "")
		if flag == "":
			continue
		var teaching_done = cd.get(flag)
		var students_done = cd.student_seq_progress.get(prof_key, 0) >= 5
		if teaching_done and not students_done:
			# This professor is done but students aren't — activate!
			if not _student_quiz_controller.is_active() or _student_quiz_controller._prof_key != prof_key:
				_activate_student_sequence(prof_key)
			break

func _resume_student_sequence(cd) -> void:
	"""Resume an in-progress student sequence from saved NPC names."""
	var prof_key = cd.student_seq_active_professor
	var saved_npcs = cd.student_seq_active_npcs
	var npc_nodes: Array = []

	for npc_name in saved_npcs:
		var npc = _find_node_recursive(str(npc_name))
		if npc:
			npc_nodes.append(npc)

	if npc_nodes.size() >= 5:
		_student_quiz_controller.start_sequence(prof_key, npc_nodes)
		print("CollegeMapManager: Resumed student sequence for %s" % prof_key)
	else:
		# NPCs not found (maybe wrong floor), re-activate fresh
		_activate_student_sequence(prof_key)

func _activate_student_sequence(prof_key: String) -> void:
	"""Pick 5 random student NPCs and start the student quiz sequence."""
	var scene_root = get_tree().current_scene
	var students_parent = scene_root.get_node_or_null("Students")
	if students_parent == null:
		push_warning("CollegeMapManager: No 'Students' node found!")
		return

	# Collect all student NPC nodes
	var all_students: Array = []
	for child in students_parent.get_children():
		if child.name.begins_with("NPCMaleCollegeStudent") or child.name.begins_with("NPCFemaleCollegeStudent"):
			all_students.append(child)

	if all_students.size() < 5:
		push_warning("CollegeMapManager: Not enough student NPCs! Found: %d" % all_students.size())
		return

	# Shuffle and pick 5
	all_students.shuffle()
	var selected: Array = all_students.slice(0, 5)

	_student_quiz_controller.start_sequence(prof_key, selected)
	print("CollegeMapManager: Activated student sequence for %s with NPCs: %s" % [prof_key, selected.map(func(n): return n.name)])

func _on_student_sequence_completed(prof_key: String) -> void:
	print("CollegeMapManager: Student sequence completed for %s!" % prof_key)
	# Refresh quests to point to the next professor
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("refresh_college_quest"):
		qm.refresh_college_quest()
	if qm and qm.has_method("refresh_college_2nd_floor_quest"):
		qm.refresh_college_2nd_floor_quest()

	# Check if Prof REST students just finished → activate panelists
	if prof_key == "y3mid":
		var cd = get_node_or_null("/root/CharacterData")
		if cd and cd.student_seq_progress.get("y3mid", 0) >= 5:
			# Wait for the student's success dialogue to finish first
			await get_tree().create_timer(0.5).timeout
			var dbox = _get_dialogue_box()
			if dbox and dbox.visible:
				await dbox.dialogue_finished
				await get_tree().create_timer(0.3).timeout
			_activate_panelists(cd)

# ── Thesis Panel Controller ──────────────────────────────────────────────────

func _setup_thesis_panel_controller(cd) -> void:
	var scene_path = String(get_tree().current_scene.scene_file_path)
	if not scene_path.ends_with("college_2nd_floor_map.tscn"):
		return  # Panelists only exist on 2nd floor

	# Create the controller
	_thesis_panel_controller = Node.new()
	_thesis_panel_controller.name = "ThesisPanelController"
	_thesis_panel_controller.set_script(ThesisPanelControllerScript)
	add_child(_thesis_panel_controller)

	# Find panelist NPCs
	var p1 = _find_node_recursive("NPCPanelist01")
	var p2 = _find_node_recursive("NPCPanelist02")
	var p3 = _find_node_recursive("NPCPanelist03")

	# Register NPCs with the controller
	if p1:
		_thesis_panel_controller.register_panelist_npc(1, p1)
		p1.set_meta("lesson_controller", _thesis_panel_controller)
		p1.set_meta("panelist_index", 1)
		p1.set_meta("music_track", "PPT")
	if p2:
		_thesis_panel_controller.register_panelist_npc(2, p2)
		p2.set_meta("lesson_controller", _thesis_panel_controller)
		p2.set_meta("panelist_index", 2)
		p2.set_meta("music_track", "PPT")
	if p3:
		_thesis_panel_controller.register_panelist_npc(3, p3)
		p3.set_meta("lesson_controller", _thesis_panel_controller)
		p3.set_meta("panelist_index", 3)
		p3.set_meta("music_track", "PPT")

	# Check if panelists should be active right now
	if cd and cd.student_seq_progress.get("y3mid", 0) >= 5 and cd.thesis_panelist_progress < 3:
		_activate_panelists(cd)
	elif cd and cd.thesis_panelist_progress >= 3:
		# All panelists done — just show done labels
		_thesis_panel_controller._update_npc_visuals()
		_unlock_panelist_doors()

func _unlock_panelist_doors() -> void:
	for door_name in ["SidewayRightDoor5", "SidewayRightDoor6"]:
		var d = _find_node_recursive(door_name)
		if d and "is_locked" in d:
			d.is_locked = false
			print("CollegeMapManager: Unlocked %s for panelist access" % door_name)

func _activate_panelists(cd) -> void:
	if _thesis_panel_controller == null:
		return

	_unlock_panelist_doors()

	# Update NPC visuals (done/available/locked)
	_thesis_panel_controller._update_npc_visuals()

	# Fire contextual spotlight (one-time) — camera pan to first panelist
	if cd and not cd.thesis_spotlight_shown:
		cd.thesis_spotlight_shown = true
		var p1_npc = _find_node_recursive("NPCPanelist01")
		if p1_npc:
			var player = _get_player()
			if player:
				player.can_move = false
			await get_tree().create_timer(0.5).timeout
			var dark_overlay = await _camera_pan_to_npc(p1_npc)
			var dbox = _get_dialogue_box()
			if dbox:
				dbox.start([
					{ "name": "", "text": "[color=#f0c674]📢 The Thesis Panel has assembled![/color]" },
					{ "name": "", "text": "Three panelists are waiting to evaluate your thesis defense." },
					{ "name": "", "text": "Start with [color=#61afef]Panelist Cruz[/color] — the Setup Specialist." },
					{ "name": "", "text": "[color=#e06c75]Prepare your defense![/color] Good luck!" },
				])
				await dbox.dialogue_finished
			await _camera_pan_back(dark_overlay)
			if player:
				player.can_move = true

		# Auto-save spotlight flag
		var sm = get_node_or_null("/root/SaveManager")
		if sm:
			sm.save_game(true, "Saving progress...")

	# Update quest HUD
	_thesis_panel_controller._update_quest_hud()

# ── College SIS Tutorial ─────────────────────────────────────────────────────

const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")
const TUTORIAL_OVERLAY_SCRIPT = preload("res://Scripts/UI/tutorial_overlay.gd")

func _run_college_sis_tutorial(cd) -> void:
	var player = _get_player()
	if player:
		player.can_move = false
		player.block_ui_input = true

	var dbox = _get_dialogue_box()
	if not dbox:
		_finish_sis_tutorial(cd, player)
		return

	# Welcome dialogue
	dbox.start([
		{ "name": "", "text": "Welcome to [color=#f0c674]College[/color]!" },
		{ "name": "", "text": "Open your [color=#f0c674]Laptop[/color] (press Esc) to check the Student Information System." },
	])
	await dbox.dialogue_finished

	# Allow Esc
	if player:
		player.block_ui_input = false
		player.can_move = false

	# Show the Esc key node on the player
	var esc_node = null
	if player:
		var esc_scene = load("res://Scenes/Button Keys/esc_button.tscn")
		if esc_scene:
			esc_node = esc_scene.instantiate()
			esc_node.position = Vector2(0, -50)
			esc_node.scale = Vector2(2.0, 2.0)
			player.add_child(esc_node)
			# Auto-play animations
			for child in esc_node.get_children():
				if child is AnimatedSprite2D:
					child.play("default")

	# Wait for Esc press
	await _wait_for_action("ui_cancel")

	# IMMEDIATELY block further input to prevent double-tap Esc closing the laptop
	if player:
		player.block_ui_input = true

	# Hide the Esc key node
	if esc_node and is_instance_valid(esc_node):
		esc_node.queue_free()

	# Explicitly open the laptop (no built-in Esc handler exists)
	var laptop = get_node_or_null("/root/GlobalLaptopUI")
	if laptop and laptop.has_method("open") and not laptop.is_open:
		laptop.open()

	await get_tree().create_timer(0.5).timeout

	if laptop and laptop.is_open:
		# Spotlight the SIS button
		var sis_btn = _find_app_button(laptop, "🎓")
		if sis_btn:
			var overlay = await _create_tutorial_overlay()
			overlay.start_tutorial([
				{
					"text": "The [color=#f0c674]Student Information System[/color] is now active!\nClick it to view your academic records, grades, and GWA.",
					"highlight_node": sis_btn,
					"tooltip_side": "bottom"
				}
			])
			await overlay.tutorial_finished
			overlay.queue_free()

		# Spotlight the Certificate button
		var cert_btn = _find_app_button(laptop, "🏆")
		if cert_btn:
			var cert_overlay = await _create_tutorial_overlay()
			cert_overlay.start_tutorial([
				{
					"text": "The [color=#f0c674]Certificates[/color] app is now unlocked!\nComplete each professor's coursework to earn ECertificates.",
					"highlight_node": cert_btn,
					"tooltip_side": "bottom"
				}
			])
			await cert_overlay.tutorial_finished
			cert_overlay.queue_free()

		# Spotlight the credit display
		var credit_display = laptop.find_child("CreditDisplay", true, false)
		if credit_display:
			var cred_overlay = await _create_tutorial_overlay()
			cred_overlay.start_tutorial([
				{
					"text": "These are your [color=#f0c674]Credits[/color]!\nYou earn them by completing lessons from professors and helping others around campus, and in the future, in other places.\nSpend them wisely!",
					"highlight_node": credit_display,
					"tooltip_side": "top"
				}
			])
			await cred_overlay.tutorial_finished
			cred_overlay.queue_free()

		# Close laptop
		if laptop.has_method("close"):
			laptop.close()
		await get_tree().create_timer(0.3).timeout

	_finish_sis_tutorial(cd, player)

func _finish_sis_tutorial(cd, player) -> void:
	cd.has_seen_college_sis_tutorial = true
	if player:
		player.can_move = true
		player.block_ui_input = false

func _get_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _get_dialogue_box():
	var boxes = get_tree().get_nodes_in_group("dialogue_box")
	if boxes.size() > 0:
		return boxes[0]
	var root = get_tree().current_scene
	for child in root.get_children():
		if child.has_method("start") and child is CanvasLayer:
			return child
	var instance = DIALOGUE_BOX_SCENE.instantiate()
	root.add_child(instance)
	return instance

func _create_tutorial_overlay():
	var overlay = CanvasLayer.new()
	overlay.set_script(TUTORIAL_OVERLAY_SCRIPT)
	overlay.layer = 150
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(overlay)
	await get_tree().process_frame
	return overlay

func _wait_for_action(action_name: String) -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed(action_name):
			return

func _find_app_button(laptop, emoji: String) -> Control:
	if not laptop or not "desktop_view" in laptop:
		return null
	for child in _get_all_descendants(laptop.desktop_view):
		if child is Button and child.text.strip_edges() == emoji:
			return child
	return null

func _get_all_descendants(node: Node) -> Array:
	var result = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_descendants(child))
	return result

# ─── Camera Pan Spotlight Helpers ─────────────────────────────────────────────

func _camera_pan_to_npc(target_npc: Node2D) -> CanvasLayer:
	"""Pan camera to a world NPC with a spotlight overlay. Returns the overlay to remove later."""
	var player = _get_player()
	if not player:
		return null
	var cam = player.get_node_or_null("Camera2D")
	if not cam:
		return null

	# Spotlight overlay behind dialogue (layer 9, dialogue is 10)
	var dark_overlay = CanvasLayer.new()
	dark_overlay.layer = 9
	dark_overlay.name = "PanDarkOverlay"
	var dark_rect = ColorRect.new()
	dark_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Apply the spotlight shader
	var shader = load("res://Shaders/spotlight_overlay.gdshader")
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	# Start with no spotlight and fully transparent
	shader_mat.set_shader_parameter("spotlight_pos", Vector2(0.5, 0.5))
	shader_mat.set_shader_parameter("spotlight_size", Vector2(0.0, 0.0))
	shader_mat.set_shader_parameter("overlay_color", Color(0, 0, 0, 0.0))
	shader_mat.set_shader_parameter("softness", 0.06)
	dark_rect.material = shader_mat
	dark_rect.color = Color(1, 1, 1, 1)  # White base for shader to work

	dark_overlay.add_child(dark_rect)
	get_tree().current_scene.add_child(dark_overlay)

	# Calculate offset to pan camera to target
	var offset_to_target = target_npc.global_position - player.global_position

	# Tween camera offset to target
	var tween = create_tween()
	tween.tween_property(cam, "offset", offset_to_target, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	# After camera arrives, calculate NPC screen position and animate spotlight in
	var screen_size = get_viewport().get_visible_rect().size
	var npc_screen_pos = target_npc.get_global_transform_with_canvas().origin
	var norm_pos = npc_screen_pos / screen_size

	shader_mat.set_shader_parameter("spotlight_pos", norm_pos)
	shader_mat.set_shader_parameter("spotlight_size", Vector2(0.12, 0.18))

	# Fade in the overlay darkness with spotlight hole
	var fade_tween = create_tween()
	fade_tween.tween_method(func(alpha: float):
		shader_mat.set_shader_parameter("overlay_color", Color(0, 0, 0, alpha))
	, 0.0, 0.75, 0.5)
	await fade_tween.finished

	return dark_overlay

func _camera_pan_back(dark_overlay: CanvasLayer) -> void:
	"""Pan camera back to player and remove the dark overlay."""
	var player = _get_player()
	if not player:
		if dark_overlay:
			dark_overlay.queue_free()
		return
	var cam = player.get_node_or_null("Camera2D")
	if not cam:
		if dark_overlay:
			dark_overlay.queue_free()
		return

	# Fade out the spotlight overlay
	var dark_rect = null
	if dark_overlay:
		for child in dark_overlay.get_children():
			if child is ColorRect:
				dark_rect = child
				break

	if dark_rect and dark_rect.material is ShaderMaterial:
		var shader_mat = dark_rect.material as ShaderMaterial
		var fade_tween = create_tween()
		fade_tween.tween_method(func(alpha: float):
			shader_mat.set_shader_parameter("overlay_color", Color(0, 0, 0, alpha))
		, 0.75, 0.0, 0.4)
		await fade_tween.finished

	# Pan camera back to player
	var pan_tween = create_tween()
	pan_tween.tween_property(cam, "offset", Vector2.ZERO, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await pan_tween.finished

	# Cleanup
	if dark_overlay and is_instance_valid(dark_overlay):
		dark_overlay.queue_free()

# ─── Shop NPC Pan Tutorial ───────────────────────────────────────────────────

func _run_shop_pan_tutorial(cd) -> void:
	var shop_npc = _find_node_recursive("ShopNPC")
	if not shop_npc:
		cd.has_seen_shop_tutorial = true
		return

	var player = _get_player()
	if player:
		player.can_move = false

	# Pan camera to shop NPC
	var dark_overlay = await _camera_pan_to_npc(shop_npc)

	var dbox = _get_dialogue_box()
	if dbox:
		dbox.start([
			{ "name": "", "text": "This is the [color=#f0c674]Campus Shop[/color]!" },
			{ "name": "", "text": "You can spend your [color=#61afef]Credits[/color] here to buy useful items." },
			{ "name": "", "text": "These items can help you when [color=#98c379]assisting other students[/color] with their problems." },
			{ "name": "", "text": "However, items [color=#e06c75]cannot[/color] be used during [color=#e06c75]professor lessons[/color], [color=#e06c75]panelist evaluations[/color], or other main challenges." },
			{ "name": "", "text": "Use them wisely!" },
		])
		await dbox.dialogue_finished

	# Pan back
	await _camera_pan_back(dark_overlay)

	cd.has_seen_shop_tutorial = true
	if player:
		player.can_move = true

	# Auto-save
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.save_game(true, "Saving progress...")
