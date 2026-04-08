# ch2_professor_auth_controller.gd — Year 3 Semester 2 Professor Controller
# Manages the teach-code-teach-code flow for Professor Auth (Authentication & CRUD)
# Wired to NPCFemaleCollegeProf02 via college_map_manager.gd
#
# Flow:
#   Player interacts with NPCFemaleCollegeProf02 → gate check (Y1S1+Y1S2+Y2S1+Y2S2+Y3S1 required) →
#   lecture prompt → 2 modules of (Teaching slides + dialogue) then IDE coding
#   challenges → Mark ch2_y3s2_teaching_done = true
#
# Year 3, Semester 2 Modules:
#   Module 1 — Authentication (Login systems, authenticate())
#   Module 2 — Full CRUD & Permissions (Ownership logic)
extends Node

const CODING_UI_SCENE = preload("res://Scenes/Games/coding_challenge_ui.tscn")
const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")

@onready var character_data = get_node("/root/CharacterData")

var player: Node2D = null
var professor_npc: Area2D = null
var dialogue_box = null

var is_learning_mode: bool = false
var _cutscene_running: bool = false
var _teaching_canvas: CanvasLayer = null
var _dialogue_log: Array = []
var _log_overlay: CanvasLayer = null

var _challenge_canvas: CanvasLayer = null
var _challenge_ui: Node = null
var _original_dialogue_layer: int = 10

# ── Interaction Handler ───────────────────────────────────────────────

func _on_professor_interacted():
	print("ProfAuthController: _on_professor_interacted() called!")
	if _cutscene_running:
		return
	
	# Find player
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	dialogue_box = _get_dialogue_box()
	
	if is_learning_mode:
		_cutscene_running = true
		_start_lesson_sequence()
		return
	
	# ── Gate: Must complete Y1S1, Y1S2, Y2S1, Y2S2, AND Y3S1 first ──
	var has_markup = character_data and character_data.ch2_y1s1_teaching_done
	var has_syntax = character_data and character_data.ch2_y1s2_teaching_done
	var has_view   = character_data and character_data.ch2_y2s1_teaching_done
	var has_query  = character_data and character_data.ch2_y2s2_teaching_done
	var has_token  = character_data and character_data.ch2_y3s1_teaching_done
	
	if not (has_markup and has_syntax and has_view and has_query and has_token):
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Auth", "text": "You're not authorized for this class yet." },
				{ "name": "Professor Auth", "text": "Complete all previous courses first — including [color=#f0c674]Professor Otek's[/color] Forms & Security class." },
				{ "name": "Professor Auth", "text": "Access denied. Come back when you've passed every prerequisite." }
			])
		return
	
	# ── Post-completion dialogue ──────────────────────────────────
	if character_data and character_data.ch2_y3s2_teaching_done:
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Auth", "text": "You've completed all my lessons for this semester." },
				{ "name": "Professor Auth", "text": "[color=#f0c674]Authentication[/color] and [color=#f0c674]permissions[/color]. Your app now controls who gets in and what they can do." },
				{ "name": "Professor Auth", "text": "Year 3 is done. The final year awaits." }
			])
		return
	
	# ── Lecture prompt ────────────────────────────────────────────
	if dialogue_box:
		var current_mod = 0
		if character_data:
			current_mod = character_data.ch2_y3s2_current_module
		
		var mod_names = ["Authentication", "CRUD & Permissions"]
		var mod_label = mod_names[current_mod] if current_mod < mod_names.size() else "the lesson"
		
		var lines = [{
			"name": "Professor Auth",
			"text": "Ready for the lecture on " + mod_label + "?",
			"choices": ["Yes", "Not yet"]
		}]
		
		dialogue_box.choice_selected.connect(_on_lecture_choice, CONNECT_ONE_SHOT)
		dialogue_box.start(lines)

func _on_lecture_choice(choice_index: int):
	print("ProfAuthController: choice_index = ", choice_index)
	if choice_index == 0:
		_cutscene_running = true
		_start_lesson_sequence()


# ── LESSON SEQUENCE ───────────────────────────────────────────────────

func _start_lesson_sequence():
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.hide_quest()

	dialogue_box = _get_dialogue_box()
	
	# Freeze player
	if player:
		player.can_move = false
		player.can_interact = false
		player.set_physics_process(false)
		player.block_ui_input = true
		if player.has_method("play_idle_animation") and "current_dir" in player:
			player.play_idle_animation(player.current_dir)
	
	var current_module = 0
	if character_data:
		current_module = character_data.ch2_y3s2_current_module
	
	if is_learning_mode:
		current_module = 0
	
	# ─── DEBUG SKIP IDE ────────────────────────────────────────────
	# @TODO: CHANGE THIS TO false WHEN DONE TESTING
	var DEBUG_SKIP_IDE = false
	# ─── END OF DEBUG SKIP IDE ────────────────────────────────────
	
	_challenge_canvas = null
	_challenge_ui = null
	
	# ─── Run modules from current progress ────────────────────────
	
	if current_module <= 0:
		await _play_module_1_authentication(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y3s2_current_module = 1
	
	if current_module <= 1:
		await _play_module_2_crud_permissions(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y3s2_current_module = 2
	
	# ─── All modules done ─────────────────────────────────────────
	
	if dialogue_box and dialogue_box is CanvasLayer and not DEBUG_SKIP_IDE:
		dialogue_box.layer = _original_dialogue_layer
	
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.queue_free()
	_challenge_canvas = null
	_challenge_ui = null
	
	await get_tree().create_timer(0.3).timeout
	
	# Completion dialogue
	dialogue_box = _get_dialogue_box()
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor Auth", "text": "You made it through." },
			{ "name": "Professor Auth", "text": "You now understand [color=#f0c674]user authentication[/color] and [color=#f0c674]permission-based access control[/color]." },
			{ "name": "Professor Auth", "text": "Without these, anyone can do anything. That's not a system — that's chaos." },
			{ "name": "Professor Auth", "text": "Year 3 complete. You're ready for the final year." }
		])
		await dialogue_box.dialogue_finished
	
	# Mark complete
	if character_data and not is_learning_mode:
		character_data.ch2_y3s2_teaching_done = true
	
	# Unfreeze player
	if player:
		player.can_move = true
		player.can_interact = true
		player.set_physics_process(true)
		player.block_ui_input = false
	
	_cutscene_running = false

	if qm:
		qm.show_quest()
		if qm.has_method("refresh_college_quest"):
			qm.refresh_college_quest()

# ── Teaching slides (Ch1-style) + lazy IDE ────────────────────────────

func _before_teaching_slides() -> void:
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.visible = false

func _transition_from_teaching_to_ide(skip_ide: bool) -> void:
	if skip_ide:
		_hide_fullscreen_image()
		return
	await _ensure_challenge_ui()
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.visible = false
	_hide_fullscreen_image()

func _show_challenge_canvas() -> void:
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.visible = true

func _await_challenge_done(ui) -> void:
	while not ui.is_completed:
		await get_tree().create_timer(0.1).timeout
	while not ui.results_overlay.visible:
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(1.5).timeout
	ui.results_overlay.visible = false
	ui.lock_typing(true)

func _ensure_challenge_ui() -> Node:
	if _challenge_ui and is_instance_valid(_challenge_ui):
		dialogue_box = _get_dialogue_box()
		if dialogue_box and dialogue_box is CanvasLayer:
			_original_dialogue_layer = dialogue_box.layer if dialogue_box.layer != 60 else _original_dialogue_layer
			dialogue_box.layer = 60
		return _challenge_ui
	_challenge_canvas = CanvasLayer.new()
	_challenge_canvas.layer = 50
	_challenge_canvas.name = "ChallengeCanvasLayer"
	get_tree().current_scene.add_child(_challenge_canvas)
	_challenge_ui = CODING_UI_SCENE.instantiate()
	_challenge_ui.hide_close_button = true
	_challenge_canvas.add_child(_challenge_ui)
	await get_tree().process_frame
	if _challenge_ui.continue_button.pressed.is_connected(_challenge_ui._on_continue_pressed):
		_challenge_ui.continue_button.pressed.disconnect(_challenge_ui._on_continue_pressed)
	_challenge_ui.close_button.visible = false
	_challenge_ui.continue_button.visible = false
	_create_log_button(_challenge_canvas)
	dialogue_box = _get_dialogue_box()
	if dialogue_box and dialogue_box is CanvasLayer:
		_original_dialogue_layer = dialogue_box.layer
		dialogue_box.layer = 60
	return _challenge_ui


# ══════════════════════════════════════════════════════════════════════
#  MODULE 1 — Authentication (Login systems, authenticate())
# ══════════════════════════════════════════════════════════════════════

func _play_module_1_authentication(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 1: Why Authentication ─────────────────────
	_show_teaching_slide({
		"icon": "🔐",
		"title": "Authentication",
		"subtitle": "Who are you?",
		"bullets": [
			"[b]Authentication[/b] = verifying a user's identity.",
			"Without it, anyone can access anything in your app.",
			"Django provides a built-in [b]auth system[/b] out of the box.",
			"Login, logout, password hashing — all handled for you."
		],
		"header": "MODULE 1 — AUTHENTICATION",
		"header_icon": "🔑",
		"slide_num": "1 / 4"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Auth", "text": "Last semester you learned to protect [color=#f0c674]forms[/color]. But who's submitting them?" },
			{ "name": "Professor Auth", "text": "Right now, your app has no idea who anyone is." },
			{ "name": "Student", "text": "Can't we just ask for a username?" },
			{ "name": "Professor Auth", "text": "Anyone can type a username. That proves nothing." },
			{ "name": "Professor Auth", "text": "[color=#f0c674]Authentication[/color] means verifying identity. Username AND password." },
			{ "name": "Professor Auth", "text": "Control access, or lose control entirely." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 2: Django authenticate() ──────────────────
	_show_teaching_slide({
		"icon": "🔑",
		"title": "The authenticate() Function",
		"subtitle": "Verifying credentials",
		"bullets": [
			"[b]authenticate(request, username, password)[/b] checks credentials.",
			"Returns [b]User object[/b] if valid, [b]None[/b] if not.",
			"After authentication, call [b]login(request, user)[/b] to start a session.",
			"Never store raw passwords — Django hashes them automatically."
		],
		"code": "from django.contrib.auth import authenticate, login\n\ndef login_view(request):\n    user = authenticate(\n        request,\n        username='alice',\n        password='secret123'\n    )\n    if user is not None:\n        login(request, user)",
		"header": "MODULE 1 — AUTHENTICATION",
		"header_icon": "🔑",
		"slide_num": "2 / 4"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Auth", "text": "Django gives you [color=#f0c674]authenticate()[/color]. It checks credentials against the database." },
			{ "name": "Professor Auth", "text": "Pass in the [color=#f0c674]username[/color] and [color=#f0c674]password[/color]. It returns the user if valid." },
			{ "name": "Student", "text": "What if the password is wrong?" },
			{ "name": "Professor Auth", "text": "It returns [color=#f0c674]None[/color]. No user. Access denied." },
			{ "name": "Professor Auth", "text": "After a successful check, call [color=#f0c674]login()[/color] to start a session." },
			{ "name": "Professor Auth", "text": "Now write the authentication logic." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"auth_authenticate", "Authenticate a User", "python", "views.py",
		["from django.contrib.auth import authenticate, login", "", "def login_view(request):", "    username = request.POST['username']", "    password = request.POST['password']", "    # Authenticate the user with the provided credentials", "    user = "],
		["Write: authenticate(request, username=username, password=password)"],
		"Type your code here...",
		[
			"authenticate(request, username=username, password=password)",
			"authenticate(request,username=username,password=password)",
			"authenticate(request, username=username, password=password)"
		],
		"✅ Authentication successful!\n  User: alice\n  Session: Started\n  Status: Logged in",
		"AuthenticationError: Invalid credentials — check your authenticate() call!",
		[
			"Use the authenticate function with request and credentials",
			"Pass username and password as keyword arguments",
			"Type: authenticate(request, username=username, password=password)"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Auth", "text": "Write the [color=#f0c674]authenticate()[/color] call." },
			{ "name": "Professor Auth", "text": "Pass [color=#f0c674]request[/color], [color=#f0c674]username=username[/color], and [color=#f0c674]password=password[/color]." },
			{ "name": "Professor Auth", "text": "Type: [color=#f0c674]authenticate(request, username=username, password=password)[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Auth", "text": "Good. You can now verify who a user is." },
			{ "name": "Professor Auth", "text": "But knowing [color=#f0c674]who[/color] they are is only half the problem." },
			{ "name": "Professor Auth", "text": "Next: controlling [color=#f0c674]what[/color] they're allowed to do." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 2 — Full CRUD & Permissions (Ownership logic)
# ══════════════════════════════════════════════════════════════════════

func _play_module_2_crud_permissions(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 3: Permissions ────────────────────────────
	_show_teaching_slide({
		"icon": "🛡️",
		"title": "Permissions & Ownership",
		"subtitle": "Who can do what?",
		"bullets": [
			"[b]Permissions[/b] control what actions a user can perform.",
			"A user should only [b]modify their own data[/b].",
			"Check [b]request.user == object.owner[/b] before allowing edits.",
			"Without this, any logged-in user can modify anyone's records."
		],
		"code": "def edit_post(request, post_id):\n    post = Post.objects.get(id=post_id)\n    if request.user == post.owner:\n        # Allow editing\n    else:\n        # Deny access",
		"header": "MODULE 2 — CRUD & PERMISSIONS",
		"header_icon": "🔒",
		"slide_num": "3 / 4"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Auth", "text": "Your users are logged in. Great. But can User A edit User B's data?" },
			{ "name": "Student", "text": "That shouldn't be allowed… right?" },
			{ "name": "Professor Auth", "text": "Correct. But if you don't [color=#f0c674]enforce[/color] it, nothing stops them." },
			{ "name": "Professor Auth", "text": "Every edit, every delete — check [color=#f0c674]ownership[/color] first." },
			{ "name": "Professor Auth", "text": "Users should not modify what they do not own." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 4: The Check ──────────────────────────────
	_show_teaching_slide({
		"icon": "✅",
		"title": "The Ownership Check",
		"subtitle": "One line that prevents chaos",
		"bullets": [
			"[b]request.user[/b] = the currently logged-in user.",
			"[b]object.owner[/b] = the user who created the record.",
			"Compare them before any destructive action.",
			"If they don't match — [b]reject the request[/b]."
		],
		"code": "if request.user == post.owner:\n    post.delete()\n    messages.success(request, 'Deleted!')\nelse:\n    messages.error(request, 'Permission denied.')",
		"header": "MODULE 2 — CRUD & PERMISSIONS",
		"header_icon": "🔒",
		"slide_num": "4 / 4"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Auth", "text": "The pattern is simple. One [color=#f0c674]if statement[/color]." },
			{ "name": "Professor Auth", "text": "Compare [color=#f0c674]request.user[/color] with [color=#f0c674]object.owner[/color]." },
			{ "name": "Student", "text": "And if they're not the same?" },
			{ "name": "Professor Auth", "text": "You deny the action. No negotiation." },
			{ "name": "Professor Auth", "text": "Now write the check." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"auth_permissions", "Check Ownership", "python", "views.py",
		["def edit_post(request, post_id):", "    post = Post.objects.get(id=post_id)", "    # Check if the current user owns this post", "    "],
		["Write: if request.user == post.owner:"],
		"Type your code here...",
		[
			"if request.user == post.owner:",
			"if request.user==post.owner:",
			"if request.user == post.owner :"
		],
		"✅ Permission check passed!\n  User: alice\n  Post Owner: alice\n  Action: Allowed",
		"PermissionError: Ownership check failed — use request.user == object.owner",
		[
			"Compare the logged-in user with the object's owner",
			"Use: if request.user == post.owner:",
			"Type: if request.user == post.owner:"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Auth", "text": "Write the [color=#f0c674]ownership check[/color]." },
			{ "name": "Professor Auth", "text": "Compare [color=#f0c674]request.user[/color] with [color=#f0c674]post.owner[/color]." },
			{ "name": "Professor Auth", "text": "Type: [color=#f0c674]if request.user == post.owner:[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Auth", "text": "Well done." },
			{ "name": "Professor Auth", "text": "Your app now knows [color=#f0c674]who[/color] users are and [color=#f0c674]what[/color] they're allowed to do." },
			{ "name": "Professor Auth", "text": "Authentication plus permissions. That's the security layer every real app needs." },
			{ "name": "Professor Auth", "text": "Year 3 is complete. You've earned your place." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout


# ══════════════════════════════════════════════════════════════════════
#  HELPERS — Identical to Professor Otek / Query / View pattern
# ══════════════════════════════════════════════════════════════════════

func _make_challenge(id: String, title: String, topic: String, file_name: String,
	code_lines: Array, mission_steps: Array, placeholder: String,
	expected_answers: Array, correct_output: String, error_output: String,
	progressive_hints: Array = []) -> Dictionary:
	
	var base_hint = progressive_hints[0] if progressive_hints.size() > 0 else "Read the professor's instructions carefully."
	var exact_answer = expected_answers[0] if expected_answers.size() > 0 else ""
	var final_hint = base_hint + "\n\n[color=#5c6370]If you're really stuck, here's the exact code:[/color]\n[color=#98c379]" + exact_answer + "[/color]"

	return {
		"id": id,
		"title": title,
		"topic": topic,
		"type": "free_type",
		"file_name": file_name,
		"code_lines": code_lines,
		"mission_steps": mission_steps,
		"placeholder": placeholder,
		"expected_answers": expected_answers,
		"correct_output": correct_output,
		"error_output": error_output,
		"progressive_hints": progressive_hints,
		"show_output": true,
		"hint": final_hint,
		"timed": false
	}

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

func _log_dialogue(lines: Array):
	for line in lines:
		_dialogue_log.append(line)

func _show_dialogue_with_log(dbox, lines: Array):
	_log_dialogue(lines)
	dbox.start(lines)

func _show_fullscreen_image(texture: Texture2D) -> void:
	_ensure_teaching_canvas()
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.texture = texture
		img_rect.visible = true
	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if placeholder:
		placeholder.visible = false
	_teaching_canvas.visible = true

func _show_placeholder_image(text: String) -> void:
	_ensure_teaching_canvas()
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.visible = false
	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if not placeholder:
		placeholder = _create_placeholder_panel()
		_teaching_canvas.add_child(placeholder)
	var lbl = placeholder.find_child("Text", true, false)
	if lbl is Label:
		(lbl as Label).text = text
	placeholder.visible = true
	_teaching_canvas.visible = true

func _hide_fullscreen_image() -> void:
	if _teaching_canvas:
		var ct = _teaching_canvas.get_node_or_null("CenteredTextLabel")
		if ct:
			ct.queue_free()
		_teaching_canvas.visible = false

func _ensure_teaching_canvas() -> void:
	if _teaching_canvas:
		return
	_teaching_canvas = CanvasLayer.new()
	_teaching_canvas.layer = 5
	_teaching_canvas.name = "ProfAuthTeachingCanvas"
	get_tree().current_scene.add_child(_teaching_canvas)

	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_teaching_canvas.add_child(bg)

	var img_rect = TextureRect.new()
	img_rect.name = "TextureRect"
	img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_teaching_canvas.add_child(img_rect)

func _create_placeholder_panel() -> CenterContainer:
	var center = CenterContainer.new()
	center.name = "PlaceholderPanel"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -200
	center.offset_top = 10

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 420)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.97)
	style.border_color = Color(0.30, 0.45, 0.75, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var body_vbox = VBoxContainer.new()
	body_vbox.name = "BodyVBox"
	body_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(body_vbox)

	# ── Header bar ──
	var header_panel = PanelContainer.new()
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.12, 0.16, 0.28, 0.95)
	header_style.set_corner_radius_all(0)
	header_style.corner_radius_top_left = 14
	header_style.corner_radius_top_right = 14
	header_style.set_content_margin_all(8)
	header_panel.add_theme_stylebox_override("panel", header_style)
	body_vbox.add_child(header_panel)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	header_panel.add_child(header_hbox)

	var header_icon = Label.new()
	header_icon.name = "HeaderIcon"
	header_icon.text = "🔑"
	header_icon.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(header_icon)

	var header_title = Label.new()
	header_title.name = "HeaderTitle"
	header_title.text = "LECTURE SLIDE"
	header_title.add_theme_font_size_override("font_size", 13)
	header_title.add_theme_color_override("font_color", Color(0.50, 0.65, 0.90))
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_title)

	var slide_num = Label.new()
	slide_num.name = "SlideNum"
	slide_num.text = ""
	slide_num.add_theme_font_size_override("font_size", 12)
	slide_num.add_theme_color_override("font_color", Color(0.45, 0.55, 0.75, 0.7))
	header_hbox.add_child(slide_num)

	# ── Slide icon ──
	var icon_label = Label.new()
	icon_label.name = "SlideIcon"
	icon_label.text = "📖"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 40)
	body_vbox.add_child(icon_label)

	# ── Title ──
	var font_res = load("res://Textures/Fonts/Pixelify_Sans/static/PixelifySans-Regular.ttf")

	var title_label = Label.new()
	title_label.name = "SlideTitle"
	title_label.text = ""
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	if font_res:
		title_label.add_theme_font_override("font", font_res)
	body_vbox.add_child(title_label)

	# ── Subtitle ──
	var subtitle_label = Label.new()
	subtitle_label.name = "SlideSubtitle"
	subtitle_label.text = ""
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color(0.55, 0.60, 0.75))
	subtitle_label.visible = false
	body_vbox.add_child(subtitle_label)

	# ── Spacer ──
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	body_vbox.add_child(spacer)

	# ── Bullets ──
	var bullets_rtl = RichTextLabel.new()
	bullets_rtl.name = "SlideBullets"
	bullets_rtl.bbcode_enabled = true
	bullets_rtl.fit_content = true
	bullets_rtl.scroll_active = false
	bullets_rtl.add_theme_font_size_override("normal_font_size", 15)
	bullets_rtl.add_theme_color_override("default_color", Color(0.80, 0.82, 0.90))
	bullets_rtl.visible = false
	body_vbox.add_child(bullets_rtl)

	# ── Code panel ──
	var code_panel = PanelContainer.new()
	code_panel.name = "CodePanel"
	code_panel.visible = false
	var code_style = StyleBoxFlat.new()
	code_style.bg_color = Color(0.06, 0.07, 0.11, 0.95)
	code_style.border_color = Color(0.25, 0.40, 0.65, 0.6)
	code_style.set_border_width_all(1)
	code_style.set_corner_radius_all(8)
	code_style.set_content_margin_all(14)
	code_panel.add_theme_stylebox_override("panel", code_style)
	body_vbox.add_child(code_panel)

	var code_label = Label.new()
	code_label.name = "CodeText"
	code_label.text = ""
	code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_label.add_theme_font_size_override("font_size", 15)
	code_label.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55))
	code_panel.add_child(code_label)

	# ── Legacy fallback text ──
	var text_label = Label.new()
	text_label.name = "Text"
	text_label.visible = false
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	body_vbox.add_child(text_label)

	# ── Footer ──
	var footer = Label.new()
	footer.name = "Footer"
	footer.text = "— Professor Auth's Lecture —"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.40, 0.45, 0.58, 0.6))
	body_vbox.add_child(footer)

	return center


# ── Structured Teaching Slide ─────────────────────────────────────────

func _show_teaching_slide(slide_data: Dictionary) -> void:
	_ensure_teaching_canvas()
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.visible = false

	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if not placeholder:
		placeholder = _create_placeholder_panel()
		_teaching_canvas.add_child(placeholder)

	var icon_lbl = placeholder.find_child("SlideIcon", true, false)
	if icon_lbl is Label:
		icon_lbl.text = slide_data.get("icon", "📖")

	var title_lbl = placeholder.find_child("SlideTitle", true, false)
	if title_lbl is Label:
		title_lbl.text = slide_data.get("title", "")

	var subtitle_lbl = placeholder.find_child("SlideSubtitle", true, false)
	if subtitle_lbl is Label:
		var sub = slide_data.get("subtitle", "")
		subtitle_lbl.text = sub
		subtitle_lbl.visible = sub != ""

	var bullets_rtl = placeholder.find_child("SlideBullets", true, false)
	if bullets_rtl is RichTextLabel:
		var bullet_arr: Array = slide_data.get("bullets", [])
		if bullet_arr.size() > 0:
			var bb = ""
			for b in bullet_arr:
				bb += "[color=#7dacf0]  ●[/color]  " + b + "\n"
			bullets_rtl.text = bb.strip_edges()
			bullets_rtl.visible = true
		else:
			bullets_rtl.visible = false

	var code_panel = placeholder.find_child("CodePanel", true, false)
	var code_text = placeholder.find_child("CodeText", true, false)
	var code_str: String = slide_data.get("code", "")
	if code_panel and code_text is Label:
		if code_str != "":
			code_text.text = code_str
			code_panel.visible = true
		else:
			code_panel.visible = false

	var slide_num_lbl = placeholder.find_child("SlideNum", true, false)
	if slide_num_lbl is Label:
		slide_num_lbl.text = slide_data.get("slide_num", "")

	var header_title = placeholder.find_child("HeaderTitle", true, false)
	if header_title is Label:
		header_title.text = slide_data.get("header", "LECTURE SLIDE")

	var header_icon = placeholder.find_child("HeaderIcon", true, false)
	if header_icon is Label:
		header_icon.text = slide_data.get("header_icon", "🔑")

	var legacy = placeholder.find_child("Text", true, false)
	if legacy is Label:
		legacy.visible = false

	placeholder.visible = true
	_teaching_canvas.visible = true


# ── Dialogue Log Overlay UI ──────────────────────────────────────────

func _create_log_button(parent_canvas: CanvasLayer):
	if parent_canvas.get_node_or_null("LogButton"):
		return
	var btn = Button.new()
	btn.name = "LogButton"
	btn.text = "📜 Log"
	btn.custom_minimum_size = Vector2(70, 30)
	btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	btn.offset_left = 10
	btn.offset_right = 80
	btn.offset_top = 6
	btn.offset_bottom = 36

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.28, 0.9)
	style.border_color = Color(0.45, 0.55, 0.85, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.25, 0.25, 0.4, 0.95)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	btn.add_theme_font_size_override("font_size", 12)

	btn.pressed.connect(_toggle_log_overlay)
	parent_canvas.add_child(btn)

func _toggle_log_overlay():
	if _log_overlay and is_instance_valid(_log_overlay):
		_log_overlay.visible = not _log_overlay.visible
		if _log_overlay.visible:
			_refresh_log_content()
		return

	_log_overlay = CanvasLayer.new()
	_log_overlay.layer = 70
	_log_overlay.name = "DialogueLogOverlay"
	get_tree().current_scene.add_child(_log_overlay)

	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_overlay.add_child(backdrop)

	var panel = PanelContainer.new()
	panel.name = "LogPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -250
	panel.offset_bottom = 250

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	panel_style.border_color = Color(0.45, 0.55, 0.85, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	_log_overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title_bar = HBoxContainer.new()
	vbox.add_child(title_bar)

	var title = Label.new()
	title.text = "📜 Dialogue Log"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 28)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.3, 0.1, 0.1, 0.8)
	close_style.set_corner_radius_all(4)
	close_style.set_content_margin_all(2)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	close_btn.pressed.connect(func(): _log_overlay.visible = false)
	title_bar.add_child(close_btn)

	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.55))
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.name = "LogScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var log_vbox = VBoxContainer.new()
	log_vbox.name = "LogContent"
	log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(log_vbox)

	_refresh_log_content()

func _refresh_log_content():
	if not _log_overlay or not is_instance_valid(_log_overlay):
		return

	var log_content = _log_overlay.get_node_or_null("LogPanel/VBox/LogScroll/LogContent")
	if not log_content:
		return

	for child in log_content.get_children():
		child.queue_free()

	for entry in _dialogue_log:
		var line_label = RichTextLabel.new()
		line_label.bbcode_enabled = true
		line_label.fit_content = true
		line_label.scroll_active = false
		line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_label.add_theme_font_size_override("normal_font_size", 13)

		var speaker = entry.get("name", "???")
		var text = entry.get("text", "")
		var name_color = "#a3c4f3" if speaker == "Professor Auth" else "#c8e6c9"

		line_label.text = "[color=" + name_color + "][b]" + speaker + ":[/b][/color] [color=#d4d4d8]" + text + "[/color]"
		log_content.add_child(line_label)

	var scroll = _log_overlay.get_node_or_null("LogPanel/VBox/LogScroll")
	if scroll:
		await get_tree().process_frame
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
