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

var _professor_markup_controller: Node = null
var _professor_syntax_controller: Node = null
var _professor_view_controller: Node = null
var _professor_query_controller: Node = null
var _professor_token_controller: Node = null
var _professor_auth_controller: Node = null
var _professor_rest_controller: Node = null

func _ready() -> void:
	print("CollegeMapManager: _ready() called")
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
	var cd = get_node_or_null("/root/CharacterData")
	if cd:
		cd.has_reached_college = true

	# ── College SIS Tutorial (first time only) ────────────────────────
	if cd and not cd.has_seen_college_sis_tutorial:
		await get_tree().create_timer(0.5).timeout
		await _run_college_sis_tutorial(cd)

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
