# ch2_professor_token_controller.gd — Year 3 Semester 1 Professor Controller
# Manages the teach-code-teach-code flow for Professor Otek (Forms & Security)
# Wired to NPCMaleCollegeProf04 via college_map_manager.gd
#
# Flow:
#   Player interacts with NPCMaleCollegeProf04 → gate check (Y1S1+Y1S2+Y2S1+Y2S2 required) →
#   lecture prompt → 3 modules of (Teaching slides + dialogue) then IDE coding
#   challenges → Mark ch2_y3s1_teaching_done = true
#
# Year 3, Semester 1 Modules:
#   Module 1 — Forms & Validation (ModelForm, validation)
#   Module 2 — CSRF Protection (Security tokens)
#   Module 3 — Messages Framework (User feedback)
extends Node

const CODING_UI_SCENE = preload("res://Scenes/Games/coding_challenge_ui.tscn")
const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")
const GLOSSARY_POPUP_SCENE = preload("res://Scripts/UI/glossary_popup.gd")

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
	print("ProfTokenController: _on_professor_interacted() called!")
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
	
	# ── Gate: Must complete Y1S1, Y1S2, Y2S1, AND Y2S2 first ─────
	var has_markup = character_data and character_data.ch2_y1s1_teaching_done
	var has_syntax = character_data and character_data.ch2_y1s2_teaching_done
	var has_view   = character_data and character_data.ch2_y2s1_teaching_done
	var has_query  = character_data and character_data.ch2_y2s2_teaching_done
	
	if not (has_markup and has_syntax and has_view and has_query):
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Otek", "text": "Hold on. You're not cleared for this class." },
				{ "name": "Professor Otek", "text": "You need to finish [color=#f0c674]Professor Markup[/color], [color=#f0c674]Professor Syntax[/color], [color=#f0c674]Professor View[/color], and [color=#f0c674]Professor Query[/color] first." },
				{ "name": "Professor Otek", "text": "Security without foundations is reckless. Come back when you're ready." }
			])
		return
	
	# ── Post-completion dialogue ──────────────────────────────────
	if character_data and character_data.ch2_y3s1_teaching_done:
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Otek", "text": "You've completed all my lessons for this semester." },
				{ "name": "Professor Otek", "text": "[color=#f0c674]Forms[/color], [color=#f0c674]CSRF protection[/color], [color=#f0c674]user messages[/color]. Your apps are safer now." },
				{ "name": "Professor Otek", "text": "Don't ever ship a form without validation. Ever." }
			])
		return
	
	# ── Lecture prompt ────────────────────────────────────────────
	if dialogue_box:
		var current_mod = 0
		if character_data:
			current_mod = character_data.ch2_y3s1_current_module
		
		var mod_names = ["Forms & Validation", "CSRF Protection", "Messages Framework"]
		var mod_label = mod_names[current_mod] if current_mod < mod_names.size() else "the lesson"
		
		var lines = [{
			"name": "Professor Otek",
			"text": "Ready for the lecture on " + mod_label + "?",
			"choices": ["Yes", "Not yet"]
		}]
		
		dialogue_box.choice_selected.connect(_on_lecture_choice, CONNECT_ONE_SHOT)
		dialogue_box.start(lines)

func _on_lecture_choice(choice_index: int):
	print("ProfTokenController: choice_index = ", choice_index)
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
		current_module = character_data.ch2_y3s1_current_module
	
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
		await _play_module_1_forms(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y3s1_current_module = 1
	
	if current_module <= 1:
		await _play_module_2_csrf(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y3s1_current_module = 2
	
	if current_module <= 2:
		await _play_module_3_messages(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y3s1_current_module = 3
	
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
			{ "name": "Professor Otek", "text": "You survived the semester." },
			{ "name": "Professor Otek", "text": "You now understand [color=#f0c674]form validation[/color], [color=#f0c674]CSRF protection[/color], and [color=#f0c674]user messaging[/color]." },
			{ "name": "Professor Otek", "text": "These aren't optional features. They're the difference between a [color=#f0c674]secure app[/color] and a liability." },
			{ "name": "Professor Otek", "text": "Semester complete. Stay vigilant." }
		])
		await dialogue_box.dialogue_finished
	
	# Mark complete
	if character_data and not is_learning_mode:
		character_data.ch2_y3s1_teaching_done = true
	
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
	# Keep canvas hidden — it will be shown AFTER load_challenge() populates it
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
#  MODULE 1 — Forms & Validation (ModelForm, validation)
# ══════════════════════════════════════════════════════════════════════

func _play_module_1_forms(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 1: Django Forms ───────────────────────────
	_show_teaching_slide({
		"icon": "📋",
		"title": "Django Forms",
		"subtitle": "Handling user input safely",
		"bullets": [
			"Users will submit data through your app — [b]Forms[/b] handle that.",
			"Django's [b]Form[/b] class validates and cleans input automatically.",
			"[b]ModelForm[/b] links a form directly to a database Model.",
			"Never trust raw user input. [b]Always validate.[/b]"
		],
		"code": "from django import forms\nfrom .models import Student\n\nclass StudentForm(forms.ModelForm):\n    class Meta:\n        model = Student\n        fields = ['name', 'grade']",
		"header": "MODULE 1 — FORMS & VALIDATION",
		"header_icon": "🛡️",
		"slide_num": "1 / 6",
		"reference": "Source: Official Django Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "Welcome to [color=#f0c674]Year 3[/color]. This is where your apps start dealing with the real world." },
			{ "name": "Professor Otek", "text": "Users will input data. And they [color=#f0c674]will[/color] break your system." },
			{ "name": "Student", "text": "Break it how?" },
			{ "name": "Professor Otek", "text": "Invalid data. Malicious input. Empty fields where you expected values." },
			{ "name": "Professor Otek", "text": "This is why we use [color=#f0c674]Forms[/color]. They validate everything before it touches your database." },
			{ "name": "Student", "text": "So Django checks the data for us?" },
			{ "name": "Professor Otek", "text": "If you use it properly. A [color=#f0c674]ModelForm[/color] connects directly to your Model." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 2: ModelForm Meta ─────────────────────────
	_show_teaching_slide({
		"icon": "⚙️",
		"title": "ModelForm Meta Class",
		"subtitle": "Linking Form to Model",
		"bullets": [
			"Every [b]ModelForm[/b] needs an inner [b]class Meta[/b].",
			"[b]model[/b] = which database table this form maps to.",
			"[b]fields[/b] = which columns the form exposes.",
			"Django auto-generates form fields from your Model definition."
		],
		"code": "class StudentForm(forms.ModelForm):\n    class Meta:\n        model = Student\n        fields = ['name', 'grade']",
		"header": "MODULE 1 — FORMS & VALIDATION",
		"header_icon": "🛡️",
		"slide_num": "2 / 6",
		"reference": "Source: Official Django Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "The key to a [color=#f0c674]ModelForm[/color] is the inner [color=#f0c674]class Meta[/color]." },
			{ "name": "Professor Otek", "text": "Inside Meta, you specify the [color=#f0c674]model[/color] and the [color=#f0c674]fields[/color] you want." },
			{ "name": "Student", "text": "So we don't have to define each form field manually?" },
			{ "name": "Professor Otek", "text": "Exactly. Django reads your Model and builds the form for you." },
			{ "name": "Professor Otek", "text": "Less code, fewer mistakes. That's the Django way." },
			{ "name": "Professor Otek", "text": "Now define one yourself." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"token_modelform", "Define a ModelForm", "python", "forms.py",
		["from django import forms", "from .models import Student", "", "class StudentForm(forms.ModelForm):", "    # Define the Meta class linking to the Student model", "    "],
		["Define class Meta with model = Student and fields = ['name', 'grade']"],
		"Type your code here...",
		[
			"class Meta:\n        model = Student\n        fields = ['name', 'grade']",
			"class Meta:\n        model = Student\n        fields = [\"name\", \"grade\"]"
		],
		"✅ ModelForm created successfully!\n  Linked to: Student\n  Fields: name, grade\n  Validation: Active",
		"Error: Invalid ModelForm — check your Meta class definition!",
		[
			"Start with: class Meta:",
			"Inside Meta, set: model = Student",
			"Then set: fields = ['name', 'grade']"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "Define the [color=#f0c674]Meta[/color] class inside our StudentForm." },
			{ "name": "Professor Otek", "text": "Set [color=#f0c674]model = Student[/color] and [color=#f0c674]fields = ['name', 'grade'][/color]." },
			{ "name": "Professor Otek", "text": "Start with [color=#f0c674]class Meta:[/color] then define the model and fields inside it." }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "Good. Your form now maps directly to the database." },
			{ "name": "Professor Otek", "text": "Django will validate every field before saving. No garbage gets through." },
			{ "name": "Professor Otek", "text": "But validation alone isn't enough. We need to talk about [color=#f0c674]security[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 2 — CSRF Protection (Security tokens)
# ══════════════════════════════════════════════════════════════════════

func _play_module_2_csrf(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 3: What is CSRF ───────────────────────────
	_show_teaching_slide({
		"icon": "🔒",
		"title": "CSRF Attacks",
		"subtitle": "Cross-Site Request Forgery",
		"bullets": [
			"[b]CSRF[/b] = a malicious site tricks your browser into submitting a form.",
			"The attacker exploits your [b]logged-in session[/b].",
			"Without protection, your app can't tell real submissions from fake ones.",
			"Django blocks this with a [b]CSRF token[/b] — a unique, secret key per form."
		],
		"header": "MODULE 2 — CSRF PROTECTION",
		"header_icon": "🔐",
		"slide_num": "3 / 6",
		"reference": "Source: Django Security Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "Here's a question. How does your server know a form submission is [color=#f0c674]legitimate[/color]?" },
			{ "name": "Student", "text": "Because… the user clicked submit?" },
			{ "name": "Professor Otek", "text": "Wrong. A malicious website can submit forms to YOUR server using YOUR user's session." },
			{ "name": "Professor Otek", "text": "This is called a [color=#f0c674]CSRF attack[/color]. Cross-Site Request Forgery." },
			{ "name": "Student", "text": "That sounds terrifying." },
			{ "name": "Professor Otek", "text": "It is. Which is why Django has built-in protection." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 4: CSRF Token ─────────────────────────────
	_show_teaching_slide({
		"icon": "🎫",
		"title": "The CSRF Token",
		"subtitle": "No token, no trust",
		"bullets": [
			"Add [b]{% csrf_token %}[/b] inside every POST form.",
			"Django generates a [b]unique token[/b] for each user session.",
			"The server verifies the token on submission.",
			"If the token is [b]missing or wrong[/b], the request is rejected."
		],
		"code": "<form method=\"POST\">\n    {% csrf_token %}\n    {{ form.as_p }}\n    <button type=\"submit\">Save</button>\n</form>",
		"header": "MODULE 2 — CSRF PROTECTION",
		"header_icon": "🔐",
		"slide_num": "4 / 6",
		"reference": "Source: Django Security Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "The fix is simple. One line." },
			{ "name": "Professor Otek", "text": "Add [color=#f0c674]{% csrf_token %}[/color] inside every POST form." },
			{ "name": "Student", "text": "That's it?" },
			{ "name": "Professor Otek", "text": "That's it. But forget it, and your form is wide open." },
			{ "name": "Professor Otek", "text": "[color=#f0c674]No token, no trust.[/color] Remember that." },
			{ "name": "Professor Otek", "text": "Now add the token to a form." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"token_csrf", "Add CSRF Protection", "html", "form.html",
		["<form method=\"POST\">", "    <!-- Add the CSRF token below -->", "    ", "    {{ form.as_p }}", "    <button type=\"submit\">Save</button>", "</form>"],
		["Add the {% csrf_token %} template tag"],
		"Type the template tag here...",
		[
			"{% csrf_token %}",
			"{%csrf_token%}",
			"{% csrf_token%}",
			"{%csrf_token %}"
		],
		"✅ CSRF token added!\n  Form is now protected against Cross-Site Request Forgery.\n  Token: Unique per session, verified on submit.",
		"SecurityError: CSRF token missing — your form is vulnerable!",
		[
			"Use a Django template tag: {% ... %}",
			"The tag name is: csrf_token",
			"Type: {% csrf_token %}"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "Add the [color=#f0c674]CSRF token[/color] to this POST form." },
			{ "name": "Professor Otek", "text": "Type: [color=#f0c674]{% csrf_token %}[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "Good. Your form is now [color=#f0c674]protected[/color]." },
			{ "name": "Professor Otek", "text": "Every POST form. Every time. No exceptions." },
			{ "name": "Professor Otek", "text": "Now we need to talk about communicating [color=#f0c674]back[/color] to the user." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 3 — Messages Framework (User feedback)
# ══════════════════════════════════════════════════════════════════════

func _play_module_3_messages(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 5: Messages Framework ─────────────────────
	_show_teaching_slide({
		"icon": "💬",
		"title": "Messages Framework",
		"subtitle": "Talking back to the user",
		"bullets": [
			"After a user action, they need [b]feedback[/b] — success, error, warning.",
			"Django's [b]messages[/b] framework handles this cleanly.",
			"[b]messages.success(request, 'Saved!')[/b] queues a success message.",
			"Messages are displayed once, then automatically cleared."
		],
		"code": "from django.contrib import messages\n\ndef save_student(request):\n    # After saving...\n    messages.success(request, 'Student saved!')",
		"header": "MODULE 3 — MESSAGES FRAMEWORK",
		"header_icon": "📢",
		"slide_num": "5 / 6",
		"reference": "Source: Official Django Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "Your form works. It validates. It's secure." },
			{ "name": "Professor Otek", "text": "But after a user submits data… what happens?" },
			{ "name": "Student", "text": "The page refreshes?" },
			{ "name": "Professor Otek", "text": "And the user has [color=#f0c674]no idea[/color] if it worked or failed." },
			{ "name": "Professor Otek", "text": "Systems must communicate clearly. That's what the [color=#f0c674]messages framework[/color] does." },
			{ "name": "Professor Otek", "text": "Success. Error. Warning. Info. One line of code each." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 6: Message Types ──────────────────────────
	_show_teaching_slide({
		"icon": "📊",
		"title": "Message Types",
		"subtitle": "Contextual user feedback",
		"bullets": [
			"[b]messages.success(request, '...')[/b] — green, positive feedback.",
			"[b]messages.error(request, '...')[/b] — red, something went wrong.",
			"[b]messages.warning(request, '...')[/b] — yellow, caution.",
			"[b]messages.info(request, '...')[/b] — blue, neutral information."
		],
		"code": "messages.success(request, 'Saved!')\nmessages.error(request, 'Invalid data.')\nmessages.warning(request, 'Check inputs.')\nmessages.info(request, 'Welcome back.')",
		"header": "MODULE 3 — MESSAGES FRAMEWORK",
		"header_icon": "📢",
		"slide_num": "6 / 6",
		"reference": "Source: Official Django Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "There are four types: [color=#f0c674]success[/color], [color=#f0c674]error[/color], [color=#f0c674]warning[/color], and [color=#f0c674]info[/color]." },
			{ "name": "Professor Otek", "text": "Each carries a different meaning to the user." },
			{ "name": "Student", "text": "So we just call messages.success and it shows up?" },
			{ "name": "Professor Otek", "text": "Yes. Django queues the message and delivers it on the next page render." },
			{ "name": "Professor Otek", "text": "Now write one." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"token_messages", "Send a Success Message", "python", "views.py",
		["from django.contrib import messages", "", "def save_student(request):", "    # Student saved successfully!", "    # Send a success message to the user", "    "],
		["Write: messages.success(request, 'Saved!')"],
		"Type your code here...",
		[
			"messages.success(request, 'Saved!')",
			"messages.success(request, \"Saved!\")",
			"messages.success(request,'Saved!')",
			"messages.success(request,\"Saved!\")"
		],
		"✅ Message queued!\n  Type: SUCCESS\n  Text: \"Saved!\"\n  Will display on next page render.",
		"Error: Invalid message call — use messages.success(request, 'text')",
		[
			"Import is already done. Use: messages.success()",
			"Pass two arguments: request and the message string",
			"Type: messages.success(request, 'Saved!')"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "Send a [color=#f0c674]success message[/color] to the user after saving." },
			{ "name": "Professor Otek", "text": "Type: [color=#f0c674]messages.success(request, 'Saved!')[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Otek", "text": "Well done." },
			{ "name": "Professor Otek", "text": "Your apps can now [color=#f0c674]validate input[/color], [color=#f0c674]prevent attacks[/color], and [color=#f0c674]communicate with users[/color]." },
			{ "name": "Professor Otek", "text": "That's all three pillars of this semester. You've earned your place in Year 3." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout


# ══════════════════════════════════════════════════════════════════════
#  HELPERS — Identical to Professor Query / View pattern
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
		"output_type": "browser" if topic in ["html", "css", "django"] else "terminal",
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
	_teaching_canvas.name = "ProfTokenTeachingCanvas"
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
	header_icon.text = "🛡️"
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
	footer.text = "— Professor Otek's Lecture —"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.40, 0.45, 0.58, 0.6))
	body_vbox.add_child(footer)

	# ── Reference ──
	var reference = Label.new()
	reference.name = "ReferenceLabel"
	reference.text = ""
	reference.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reference.add_theme_font_size_override("font_size", 11)
	reference.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))
	body_vbox.add_child(reference)

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

	# Populate structured fields
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
				bb += "[color=#7dacf0]  ●[/color]  " + GlossaryData.auto_link(b) + "\n"
			bullets_rtl.text = bb.strip_edges()
			bullets_rtl.visible = true
			if not bullets_rtl.meta_clicked.is_connected(_on_slide_glossary_clicked):
				bullets_rtl.meta_underlined = true
				bullets_rtl.meta_clicked.connect(_on_slide_glossary_clicked)
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
		header_icon.text = slide_data.get("header_icon", "🛡️")

	var ref_lbl = placeholder.find_child("ReferenceLabel", true, false)
	if ref_lbl is Label:
		var ref_text = slide_data.get("reference", "")
		ref_lbl.text = ref_text
		ref_lbl.visible = ref_text != ""

	# Hide the legacy Text label
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
		var name_color = "#a3c4f3" if speaker == "Professor Otek" else "#c8e6c9"

		line_label.text = "[color=" + name_color + "][b]" + speaker + ":[/b][/color] [color=#d4d4d8]" + text + "[/color]"
		log_content.add_child(line_label)

	var scroll = _log_overlay.get_node_or_null("LogPanel/VBox/LogScroll")
	if scroll:
		await get_tree().process_frame
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# ─── Glossary ────────────────────────────────────────────────────────────────
func _on_slide_glossary_clicked(meta) -> void:
	var term = str(meta).strip_edges().to_lower()
	var popup = GLOSSARY_POPUP_SCENE.new()
	get_tree().root.add_child(popup)
	popup.show_definition(term)
