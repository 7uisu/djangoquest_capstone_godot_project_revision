# ch2_professor_view_controller.gd — Year 2 Semester 1 Professor Controller
# Manages the teach-code-teach-code flow for Professor View (Django Setup & Views)
# Wired to NPCMaleCollegeProf02 via college_map_manager.gd
#
# Flow:
#   Player interacts with NPCMaleCollegeProf02 → gate check (Y1S1+Y1S2 required) →
#   lecture prompt → 4 modules of (Teaching slides + dialogue) then IDE coding
#   challenges → Mark ch2_y2s1_teaching_done = true
#
# Year 2, Semester 1 Modules:
#   Module 1 — Project Setup (django-admin startproject, startapp) [HEAVY EMPHASIS]
#   Module 2 — Views & Routing (URLs → Views flow)
#   Module 3 — Templates / DTL (Dynamic HTML rendering)
#   Module 4 — Static Files (CSS/JS integration)
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

var _session_wrong_attempts: int = 0
var _session_hints_used: int = 0

# ── Grade Evaluation Config ───────────────────────────────────────────
@export var deduction_wrong_attempt: float = 0.25
@export var deduction_hint_used: float = 0.50
@export var removal_pass_score: int = 3

var reward_credits_retake_0: int = 100
var reward_credits_retake_1: int = 90
var reward_credits_retake_2: int = 80
var reward_credits_retake_3: int = 60
var reward_credits_retake_4_plus: int = 50

# ── Interaction Handler ───────────────────────────────────────────────

func _on_professor_interacted():
	print("ProfViewController: _on_professor_interacted() called!")
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
	
	# ── Gate: Must complete Year 1 Sem 1 AND Sem 2 first ─────────
	if character_data and (not character_data.ch2_y1s1_teaching_done or not character_data.ch2_y1s2_teaching_done):
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor View", "text": "Hold on. I can see you haven't completed your prerequisites." },
				{ "name": "Professor View", "text": "Finish [color=#f0c674]Professor Markup's[/color] and [color=#f0c674]Professor Syntax's[/color] courses first." },
				{ "name": "Professor View", "text": "Django builds on everything you learned in Year 1. No shortcuts." }
			])
		return
	
	# ── Post-completion dialogue ──────────────────────────────────
	if character_data and character_data.ch2_y2s1_teaching_done:
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor View", "text": "You've completed all my lessons for this semester." },
				{ "name": "Professor View", "text": "[color=#f0c674]Project setup[/color], [color=#f0c674]views[/color], [color=#f0c674]templates[/color], and [color=#f0c674]static files[/color]. You know how Django works now." },
				{ "name": "Professor View", "text": "Next semester, you'll learn about databases. Don't get comfortable." }
			])
		return
	
	# ── INC / Removal Exam Check ──────────────────────────────────
	if character_data and character_data.ch2_y2s1_inc_triggered and not character_data.ch2_y2s1_removal_passed:
		_cutscene_running = true
		if player:
			player.can_move = false
			player.can_interact = false
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor View", "text": "Your grade is currently an [color=#f0c674]INC (4.0)[/color]." },
				{ "name": "Professor View", "text": "You accumulated too many errors in your previous attempt." },
				{ "name": "Professor View", "text": "To remove the INC, you must pass my removal exam right now." }
			])
			await dialogue_box.dialogue_finished
		_launch_removal_exam()
		return

	# ── Lecture prompt (Retake-Aware) ────────────────────────────
	if dialogue_box:
		var current_mod = 0
		var r_count = 0
		if character_data:
			current_mod = character_data.ch2_y2s1_current_module
			r_count = character_data.ch2_y2s1_retake_count
		
		var mod_names = ["Project Setup", "Views & Routing", "Templates", "Static Files", "Generic Views"]
		var mod_label = mod_names[current_mod] if current_mod < mod_names.size() else "the lesson"
		
		var intro_text = "Ready to start " + mod_label + "?"
		if r_count == 1:
			intro_text = "Let's review " + mod_label + ". Remember the structure this time."
		elif r_count > 1:
			intro_text = "Back again for " + mod_label + "? Focus. This is a core Django concept."
		
		var lines = [{
			"name": "Professor View",
			"text": intro_text,
			"choices": ["Yes", "Not yet"]
		}]
		
		dialogue_box.choice_selected.connect(_on_lecture_choice, CONNECT_ONE_SHOT)
		dialogue_box.start(lines)

func _on_lecture_choice(choice_index: int):
	print("ProfViewController: choice_index = ", choice_index)
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
		current_module = character_data.ch2_y2s1_current_module
	
	if current_module == 0:
		_session_wrong_attempts = 0
		_session_hints_used = 0
	
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
		await _play_module_1_project_setup(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s1_current_module = 1
	
	if current_module <= 1:
		await _play_module_2_views_routing(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s1_current_module = 2
	
	if current_module <= 2:
		await _play_module_3_templates(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s1_current_module = 3
	
	if current_module <= 3:
		await _play_module_4_static_files(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s1_current_module = 4

	if current_module <= 4:
		await _play_module_5_generic_views(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s1_current_module = 5
	
	# ─── All modules done ─────────────────────────────────────────
	
	if dialogue_box and dialogue_box is CanvasLayer and not DEBUG_SKIP_IDE:
		dialogue_box.layer = _original_dialogue_layer
	
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.queue_free()
	_challenge_canvas = null
	_challenge_ui = null
	
	if is_learning_mode:
		var parent_node = get_parent()
		if parent_node and parent_node.has_method("show_professor_selector_disabled"):
			parent_node.show_professor_selector_disabled()
	
	await get_tree().create_timer(0.3).timeout
	
	# Mark complete / Evaluate Grade
	if not DEBUG_SKIP_IDE:
		character_data.ch2_y2s1_wrong_attempts = _session_wrong_attempts
		character_data.ch2_y2s1_hints_used = _session_hints_used
		var grade_result = await _evaluate_and_finalize_grade()
		if grade_result == "fail" or grade_result == "inc_fail":
			if player:
				player.can_move = true
				player.can_interact = true
				player.set_physics_process(true)
				player.block_ui_input = false
			_cutscene_running = false
			return
	
	await get_tree().create_timer(0.3).timeout
	
	if is_learning_mode or DEBUG_SKIP_IDE:
		dialogue_box = _get_dialogue_box()
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor View", "text": "You made it through." },
				{ "name": "Professor View", "text": "Semester complete." }
			])
			await dialogue_box.dialogue_finished

	# Unfreeze player
	if player:
		player.can_move = true
		player.can_interact = true
		player.set_physics_process(true)
		player.block_ui_input = false
	
	_cutscene_running = false

	# ─── Scene Transition ─────────────────────────────────────────
	if is_learning_mode:
		var parent_node = get_parent()
		if parent_node and parent_node.has_method("enable_professor_selector"):
			parent_node.enable_professor_selector()
		queue_free()
		return

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
	# The coding_challenge_ui has a 2s delay before showing results_overlay.
	# We must wait for it to actually appear before we can dismiss it.
	while not ui.results_overlay.visible:
		await get_tree().create_timer(0.1).timeout
	# Show the continue button and wait for the player to click it
	ui.continue_button.visible = true
	ui.continue_button.text = "Next ▸"
	await ui.continue_button.pressed
	ui.continue_button.visible = false
	ui.results_overlay.visible = false
	ui.lock_typing(true)

func _on_challenge_failed() -> void:
	_session_wrong_attempts += 1

func _on_hint_used() -> void:
	_session_hints_used += 1

func _ensure_challenge_ui() -> Node:
	if _challenge_ui and is_instance_valid(_challenge_ui):
		# Even when reusing, ensure dialogue stays above the challenge canvas
		dialogue_box = _get_dialogue_box()
		if dialogue_box and dialogue_box is CanvasLayer:
			_original_dialogue_layer = dialogue_box.layer if dialogue_box.layer != 60 else _original_dialogue_layer
			dialogue_box.layer = 60
		return _challenge_ui
	_challenge_canvas = CanvasLayer.new()
	_challenge_canvas.layer = 50
	_challenge_canvas.name = "ChallengeCanvasLayer"
	get_tree().current_scene.add_child(_challenge_canvas)
	var dim_bg = ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 1.0)
	dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_challenge_canvas.add_child(dim_bg)

	_challenge_ui = CODING_UI_SCENE.instantiate()
	_challenge_ui.hide_close_button = true
	_challenge_canvas.add_child(_challenge_ui)
	await get_tree().process_frame
	if not _challenge_ui.challenge_failed.is_connected(_on_challenge_failed):
		_challenge_ui.challenge_failed.connect(_on_challenge_failed)
	if not _challenge_ui.hint_used.is_connected(_on_hint_used):
		_challenge_ui.hint_used.connect(_on_hint_used)
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
#  MODULE 1 — Project Setup (HEAVY EMPHASIS)
#  This is the hardest topic for beginners — extra slides & challenges
# ══════════════════════════════════════════════════════════════════════

func _play_module_1_project_setup(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 0: Virtual Environments ─────────────────────────
	_show_teaching_slide({
		"icon": "🛡️",
		"title": "Virtual Environments",
		"subtitle": "Isolating your project",
		"bullets": [
			"Never install Django globally on your computer.",
			"A [b]Virtual Environment (venv)[/b] creates an isolated space.",
			"It keeps project dependencies from conflicting with each other.",
			"[b]python -m venv venv[/b] creates it."
		],
		"code": "python -m venv venv
source venv/bin/activate  # macOS/Linux
venv\\Scripts\\activate  # Windows",
		"header": "MODULE 1 — PROJECT SETUP",
		"header_icon": "🐍",
		"slide_num": "1 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Welcome to [color=#f0c674]Year 2[/color]. This is where Django begins." },
			{ "name": "Professor View", "text": "Before creating a project, you must isolate it. Create a virtual environment." },
			{ "name": "Professor View", "text": "If you fail to do this, your computer's global packages will clash." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	await _transition_from_teaching_to_ide(skip_ide)

	# ─── Coding Challenge 0: venv ─────────────────────────
	if skip_ide:
		pass
	else:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"view_venv", "Create a Virtual Environment", "python", "terminal.py",
			["# Create a new virtual environment called 'venv'", "# Use the built-in python module"],
			["Type the command to create a venv named 'venv'", "Why: Virtual environments isolate your project's packages so they don't conflict with other Python projects on your computer."],
			"Type your command here...",
			[
				"python -m venv venv",
				"python3 -m venv venv",
				"py -m venv venv"
			],
			"✅ Virtual environment 'venv' created successfully!",
			"CommandError: invalid command — use python -m venv <name>",
			[
				"The command uses the venv module: python -m venv",
				"Then the name of the folder: venv",
				"Type: python -m venv venv"
			]
		)
		ch_data["project_tree"] = {}
		ch_data["project_tree_on_success"] = {"venv": {}}
		
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Student", "text": "The command is 'python -m venv venv'? Why 'venv' twice?" },
				{ "name": "Professor View", "text": "The first is the built-in module. The second is the folder name. You could name that folder 'apple', but naming it 'venv' is the universal standard." },
				{ "name": "Professor View", "text": "Create it. Type: [color=#f0c674]python -m venv venv[/color]" }
			])
			await dialogue_box.dialogue_finished
		
		ui.lock_typing(false)
		await _await_challenge_done(ui)
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Good. Your environment is created." },
				{ "name": "Professor View", "text": "But it's not active yet. You have to [color=#f0c674]activate[/color] it first." }
			])
			await dialogue_box.dialogue_finished

	_before_teaching_slides()

	# ─── Teaching Slide 0.3: Activating the Virtual Environment ──
	_show_teaching_slide({
		"icon": "⚡",
		"title": "Activating the venv",
		"subtitle": "Entering the isolated space",
		"bullets": [
			"Creating a venv is not enough — you must [b]activate[/b] it.",
			"On macOS/Linux: [b]source venv/bin/activate[/b]",
			"On Windows: [b]venv\\Scripts\\activate[/b]",
			"Your terminal prompt will change to show [b](venv)[/b] when active."
		],
		"code": "venv\\Scripts\\activate       # Windows\nsource venv/bin/activate    # macOS/Linux\n\n(venv) C:\\Users\\hansu\\...\\DjangoQuest-Backend>   ← You'll see this prefix",
		"header": "MODULE 1 — PROJECT SETUP",
		"header_icon": "🐍",
		"slide_num": "2 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "The virtual environment exists, but your terminal isn't using it yet." },
			{ "name": "Professor View", "text": "You need to [color=#f0c674]activate[/color] it. This tells your terminal to use the isolated packages." },
			{ "name": "Student", "text": "How do we know it's active?" },
			{ "name": "Professor View", "text": "Your terminal prompt will show [color=#f0c674](venv)[/color] at the beginning. That's your indicator." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	await _transition_from_teaching_to_ide(skip_ide)

	# ─── Coding Challenge 0.3: Activate venv ─────────────────────
	if not skip_ide:
		var ui_act = await _ensure_challenge_ui()
		var ch_data_act = _make_challenge(
			"view_activate_venv", "Activate the Virtual Environment", "python", "terminal.py",
			["# Your virtual environment 'venv' has been created", "# Now activate it (Windows command)"],
			["Type the command to activate the venv", "Why: Activating the environment ensures that any packages you install or run are contained within this specific sandbox."],
			"Type your command here...",
			[
				"venv\\Scripts\\activate",
				".\\venv\\Scripts\\activate",
				"venv/Scripts/activate"
			],
			"✅ Virtual environment activated!\n  (venv) C:\\Users\\hansu\\Documents\\Capstone\\DjangoQuest-Backend> _\n  All pip installs will now go into venv/",
			"CommandError: invalid activation command — use venv\\Scripts\\activate",
			[
				"Run the activate script located in the Scripts folder",
				"The path is: venv\\Scripts\\activate",
				"Type: venv\\Scripts\\activate"
			]
		)
		ch_data_act["project_tree"] = {"venv": {}}
		ui_act.load_challenge(ch_data_act)
		_show_challenge_canvas()
		ui_act.lock_typing(true)
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Activate the virtual environment." },
				{ "name": "Professor View", "text": "Type: [color=#f0c674]venv\\Scripts\\activate[/color]" }
			])
			await dialogue_box.dialogue_finished
		ui_act.lock_typing(false)
		await _await_challenge_done(ui_act)

		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Good. Your environment is active." },
				{ "name": "Professor View", "text": "Now we need to install [color=#f0c674]Django[/color] inside this environment." }
			])
			await dialogue_box.dialogue_finished

	_before_teaching_slides()

	# ─── Teaching Slide 0.5: Installing Django ───────────────────
	_show_teaching_slide({
		"icon": "📦",
		"title": "Installing Django",
		"subtitle": "pip install django",
		"bullets": [
			"[b]pip[/b] is Python's package manager.",
			"Django is installed from PyPI using [b]pip install django[/b].",
			"Always install inside your [b]activated venv[/b], never globally.",
			"You can verify with: [b]python -m django --version[/b]"
		],
		"code": "pip install django\n# Successfully installed Django-5.0",
		"header": "MODULE 1 — PROJECT SETUP",
		"header_icon": "🐍",
		"slide_num": "3 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Your virtual environment is empty right now." },
			{ "name": "Professor View", "text": "You must install Django [color=#f0c674]inside[/color] this environment using [color=#f0c674]pip[/color]." },
			{ "name": "Student", "text": "What's pip?" },
			{ "name": "Professor View", "text": "[color=#f0c674]pip[/color] is Python's package installer. Think of it like an app store for Python libraries." },
			{ "name": "Professor View", "text": "One command. That's all it takes." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	await _transition_from_teaching_to_ide(skip_ide)

	# ─── Coding Challenge 0.5: pip install django ─────────────────
	if not skip_ide:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"view_pip_django", "Install Django", "python", "terminal.py",
			["# Install the Django framework using pip", "# Make sure your venv is activated first!"],
			["Type the pip command to install Django", "Why: pip is Python's package manager. Installing Django gives you the framework needed to build powerful web applications."],
			"Type your command here...",
			[
				"pip install django",
				"pip3 install django",
				"pip install Django",
				"pip3 install Django"
			],
			"✅ Collecting django\n  Downloading Django-5.0-py3-none-any.whl (8.1 MB)\nSuccessfully installed Django-5.0 asgiref-3.7.2 sqlparse-0.4.4",
			"ERROR: Could not find a version that satisfies the requirement. Check your command.",
			[
				"Use pip to install packages: pip install <package>",
				"The package name is: django",
				"Type: pip install django"
			]
		)
		ch_data["project_tree"] = {"venv": {}}
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Install Django inside your virtual environment." },
				{ "name": "Professor View", "text": "Type: [color=#f0c674]pip install django[/color]" }
			])
			await dialogue_box.dialogue_finished
		ui.lock_typing(false)
		await _await_challenge_done(ui)
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Django is now installed." },
				{ "name": "Professor View", "text": "Remember: [color=#f0c674]venv first[/color], then [color=#f0c674]pip install[/color]. In that order. Always." }
			])
			await dialogue_box.dialogue_finished

	_before_teaching_slides()

	# ─── Teaching Slide 1: Project vs App ─────────────────────────
	_show_teaching_slide({
		"icon": "🏗️",
		"title": "Project vs App",
		"subtitle": "Understanding Django's architecture",
		"bullets": [
			"A [b]Project[/b] is the entire web application system",
			"An [b]App[/b] is a feature module inside your project",
			"One project can have [b]many apps[/b] (blog, users, api…)",
			"[b]django-admin startproject[/b] creates the project skeleton"
		],
		"code": "django-admin startproject mysite",
		"header": "MODULE 1 — PROJECT SETUP",
		"header_icon": "🐍",
		"slide_num": "4 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Now that your environment is secure, we build the structure." },
			{ "name": "Professor View", "text": "A [color=#f0c674]Project[/color] is the whole system. Your entire website." },
			{ "name": "Professor View", "text": "An [color=#f0c674]App[/color] is a single feature inside it. Like a blog, or user accounts." },
			{ "name": "Student", "text": "So one project can have multiple apps?" },
			{ "name": "Professor View", "text": "Exactly. And that's what makes Django [color=#f0c674]scalable[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge 1: startproject ─────────────────────────
	if not skip_ide:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"view_startproject", "Create a Django Project", "python", "terminal.py",
			["# Create a new Django project called 'mysite'"],
			["Type the command to create a Django project named 'mysite'", "Why: django-admin creates the foundational folder structure and settings files required for every Django app."],
			"Type your command here...",
			[
				"django-admin startproject mysite",
				"django-admin startproject mysite ."
			],
			"✅ Project 'mysite' created successfully!",
			"CommandError: invalid command — use django-admin startproject <name>",
			[
				"The command starts with: django-admin",
				"Then the action: startproject",
				"Type: django-admin startproject mysite"
			]
		)
		ch_data["project_tree"] = {"venv": {}}
		ch_data["project_tree_on_success"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "manage.py": "file"}
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Create a new Django project called [color=#f0c674]mysite[/color]." },
				{ "name": "Student", "text": "Do we have to name it 'mysite'?" },
				{ "name": "Professor View", "text": "No, you can name the project anything. But 'mysite' is standard convention for learning." },
				{ "name": "Professor View", "text": "Type: [color=#f0c674]django-admin startproject mysite[/color]" }
			])
			await dialogue_box.dialogue_finished
		ui.lock_typing(false)
		await _await_challenge_done(ui)

	# ─── Coding Challenge 1.1: cd mysite ─────────────────────────────
	if not skip_ide:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"view_cd_mysite", "Navigate to Project Folder", "python", "terminal.py",
			["# Navigate into your newly created project directory!"],
			["Type the command to change directories into 'mysite'", "Why: manage.py exists only inside the 'mysite' folder. You can't use it if you are not inside the correct folder."],
			"Type your command here...",
			[
				"cd mysite",
				"cd ./mysite",
				"cd mysite/"
			],
			"✅ Changed directory to mysite/",
			"CommandError: invalid command — use cd <name>",
			[
				"The command to change directory is: cd",
				"Type: cd mysite"
			]
		)
		ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "manage.py": "file"}
		ch_data["active_dir"] = "websites"
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Before you can run any commands, you must enter the project." },
				{ "name": "Professor View", "text": "Type: [color=#f0c674]cd mysite[/color]" }
			])
			await dialogue_box.dialogue_finished
		ui.lock_typing(false)
		await _await_challenge_done(ui)

		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Good. You are now inside the project directory where [color=#f0c674]manage.py[/color] lives." }
			])
			await dialogue_box.dialogue_finished

	_before_teaching_slides()

	# ─── Teaching Slide 2: manage.py — The Command Center ────────
	_show_teaching_slide({
		"icon": "⚙️",
		"title": "manage.py",
		"subtitle": "Your project's command center",
		"bullets": [
			"[b]manage.py[/b] is the tool you use to control your project",
			"[b]migrate[/b] — prepares the database infrastructure",
			"[b]runserver[/b] — starts the development server",
			"[b]startapp[/b] — creates a new app inside the project"
		],
		"code": "python manage.py migrate\npython manage.py runserver",
		"header": "MODULE 1 — PROJECT SETUP",
		"header_icon": "🐍",
		"slide_num": "5 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "When you create a project, Django gives you a file called [color=#f0c674]manage.py[/color]." },
			{ "name": "Professor View", "text": "This is your [color=#f0c674]command center[/color]. Everything flows through it." },
			{ "name": "Student", "text": "So we never run Django directly?" },
			{ "name": "Professor View", "text": "Correct. But before you run the server, you must format the initial database." },
			{ "name": "Professor View", "text": "To do this, we [color=#f0c674]migrate[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	await _transition_from_teaching_to_ide(skip_ide)

	# ─── Coding Challenge 1.2: migrate ─────────────────────────────
	if not skip_ide:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"view_migrate", "Migrate Database", "python", "terminal.py",
			["# Apply the initial database migrations"],
			["Type the manage.py command to migrate the database", "Why: 'migrate' prepares the default database tables needed by Django for things like users and sessions."],
			"Type your command here...",
			[
				"python manage.py migrate",
				"python3 manage.py migrate",
				"py manage.py migrate"
			],
			"✅ Operations to perform:
  Apply all migrations: admin, auth, contenttypes, sessions
Running migrations:
  Applying contenttypes.0001_initial... OK
  Applying auth.0001_initial... OK",
			"CommandError: invalid command — use python manage.py migrate",
			[
				"The command uses manage.py.",
				"Type: python manage.py migrate"
			]
		)
		ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "manage.py": "file"}
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Apply the default migrations." },
				{ "name": "Professor View", "text": "Type: [color=#f0c674]python manage.py migrate[/color]" }
			])
			await dialogue_box.dialogue_finished
		ui.lock_typing(false)
		await _await_challenge_done(ui)
		ui.is_completed = false
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Good. The database is prepped." },
				{ "name": "Professor View", "text": "Now start the server so we can see the site." }
			])
			await dialogue_box.dialogue_finished
		await get_tree().create_timer(0.3).timeout
		
		# Now runserver challenge
		var ch_data2 = _make_challenge(
			"view_runserver", "Start the Server", "python", "terminal.py",
			["# Start the Django development server"],
			["Type the command to start the server", "Why: The dev server runs your code locally on port 8000 so you can test your app in the browser."],
			"Type your command here...",
			[
				"python manage.py runserver",
				"python3 manage.py runserver",
				"py manage.py runserver"
			],
			"✅ Django version 5.0, using settings 'mysite.settings'\nStarting development server at http://127.0.0.1:8000/\nQuit the server with CONTROL-C.",
			"CommandError: invalid command — use python manage.py runserver",
			[
				"The command uses manage.py.",
				"Type: python manage.py runserver"
			]
		)
		ch_data2["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "manage.py": "file"}
		ui.load_challenge(ch_data2)
		_show_challenge_canvas()
		ui.lock_typing(true)
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Type: [color=#f0c674]python manage.py runserver[/color]" }
			])
			await dialogue_box.dialogue_finished
		ui.lock_typing(false)
		await _await_challenge_done(ui)

	_before_teaching_slides()

	# ─── Teaching Slide 3: Startapp ─────────────────────────
	_show_teaching_slide({
		"icon": "🧩",
		"title": "Creating an App",
		"subtitle": "Building a feature module",
		"bullets": [
			"[b]python manage.py startapp appname[/b]",
			"Generates a folder for your specific feature.",
			"Contains views.py, models.py, admin.py.",
			"Next step: register it."
		],
		"code": "python manage.py startapp blog",
		"header": "MODULE 1 — PROJECT SETUP",
		"header_icon": "🐍",
		"slide_num": "6 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "The server works. But a project completely devoid of apps is useless." },
			{ "name": "Professor View", "text": "We need to create a dedicated [color=#f0c674]app[/color] module." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	await _transition_from_teaching_to_ide(skip_ide)

	# ─── Coding Challenge 2: startapp ─────────────────────────────
	if not skip_ide:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"view_startapp", "Create a Django App", "python", "terminal.py",
			["# Create a new app called 'blog' inside your project"],
			["Type the command to create a Django app named 'blog'", "Why: Projects are built out of smaller apps (like 'store' or 'blog') to keep code organized and modular."],
			"Type your command here...",
			[
				"python manage.py startapp blog",
				"python3 manage.py startapp blog",
				"py manage.py startapp blog"
			],
			"✅ App 'blog' created successfully!",
			"CommandError: invalid command — use python manage.py startapp <name>",
			[
				"The command uses manage.py: python manage.py",
				"Type: python manage.py startapp blog"
			]
		)
		ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "manage.py": "file"}
		ch_data["project_tree_on_success"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file", "templates": {"home.html": "file", "base.html": "file", "book_list.html": "file", "book_form.html": "file"}, "static": {"css": {"style.css": "file"}}}, "manage.py": "file"}
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Create an app called [color=#f0c674]blog[/color] using manage.py." },
				{ "name": "Student", "text": "And just like 'mysite', I assume we could name this app whatever feature we are building? Like 'store' or 'users'?" },
				{ "name": "Professor View", "text": "Exactly. Whatever feature it will hold. For this module, we build a blog." },
				{ "name": "Professor View", "text": "Type: [color=#f0c674]python manage.py startapp blog[/color]" }
			])
			await dialogue_box.dialogue_finished
		ui.lock_typing(false)
		await _await_challenge_done(ui)

	_before_teaching_slides()

	# ─── Teaching Slide 4: INSTALLED_APPS ─────────────────────────
	_show_teaching_slide({
		"icon": "📋",
		"title": "INSTALLED_APPS",
		"subtitle": "Registering your apps",
		"bullets": [
			"Creating an app isn't enough — you must [b]register[/b] it",
			"[b]settings.py[/b] contains your project's configuration",
			"[b]INSTALLED_APPS[/b] is the list of active apps",
			"If your app isn't here, [b]Django ignores it[/b]"
		],
		"code": "# settings.py\nINSTALLED_APPS = [\n    'django.contrib.admin',\n    'django.contrib.auth',\n    'blog',  # <-- Your new app!\n]",
		"header": "MODULE 1 — PROJECT SETUP",
		"header_icon": "🐍",
		"slide_num": "7 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "This is where [color=#f0c674]most beginners get stuck[/color]." },
			{ "name": "Professor View", "text": "You create an app. You write code. You run the server. [color=#f0c674]Nothing works.[/color]" },
			{ "name": "Student", "text": "Why not?" },
			{ "name": "Professor View", "text": "Because you forgot to [color=#f0c674]register your app[/color] in settings.py." },
			{ "name": "Professor View", "text": "If your app isn't in [color=#f0c674]INSTALLED_APPS[/color], Django doesn't know it exists." },
			{ "name": "Professor View", "text": "Always register your app. [color=#f0c674]Always[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)

	# ─── Coding Challenge 3: Register app ─────────────────────────
	if not skip_ide:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"view_register_app", "Register Your App", "python", "settings.py",
			["INSTALLED_APPS = [", "    'django.contrib.admin',", "    'django.contrib.auth',", "    'django.contrib.contenttypes',", "    # Add your app name below as a string:", "    "],
			["Add 'blog' to the INSTALLED_APPS list", "Why: Django won't recognize your new app until it is explicitly registered in the project's central settings file."],
			"Type the app name as a string...",
			[
				"'blog',",
				"'blog'",
				"\"blog\",",
				"\"blog\""
			],
			"✅ App 'blog' registered!\n  Django now recognizes your app.\n  Models, views, and templates will be loaded.",
			"Error: App not found. Did you add it as a string?",
			[
				"Add the app name as a Python string",
				"Type: 'blog'"
			]
		)
		ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file", "templates": {"home.html": "file", "base.html": "file", "book_list.html": "file", "book_form.html": "file"}, "static": {"css": {"style.css": "file"}}}, "manage.py": "file"}
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Add your [color=#f0c674]blog[/color] app to the INSTALLED_APPS list." },
				{ "name": "Professor View", "text": "Type: [color=#f0c674]'blog'[/color]" }
			])
			await dialogue_box.dialogue_finished
		ui.lock_typing(false)
		await _await_challenge_done(ui)

	_before_teaching_slides()

	# ─── Teaching Slide 5: File Structure ─────────────────────────
	_show_teaching_slide({
		"icon": "📁",
		"title": "Django File Structure",
		"subtitle": "Know what each file does",
		"bullets": [
			"[b]settings.py[/b] — project configuration",
			"[b]urls.py[/b] — URL routing, directs traffic",
			"[b]views.py[/b] — logic that handles requests",
			"[b]models.py[/b] — database definitions, next semester"
		],
		"code": "mysite/\n├── manage.py\n├── mysite/\n│   ├── settings.py\n│   ├── urls.py\n│   └── wsgi.py\n└── blog/\n    ├── views.py\n    ├── models.py\n    └── urls.py",
		"header": "MODULE 1 — PROJECT SETUP",
		"header_icon": "🐍",
		"slide_num": "8 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Let me show you what Django created for you." },
			{ "name": "Professor View", "text": "[color=#f0c674]urls.py[/color] directs traffic. [color=#f0c674]views.py[/color] handles logic." },
			{ "name": "Student", "text": "And models.py?" },
			{ "name": "Professor View", "text": "That's for [color=#f0c674]databases[/color]. You'll learn that next semester with Professor Query." },
			{ "name": "Professor View", "text": "You now have a fully working project setup. Well done." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	if dialogue_box and dialogue_box is CanvasLayer and not skip_ide:
		dialogue_box.layer = _original_dialogue_layer

func _play_module_2_views_routing(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 5: URL Patterns ───────────────────────────
	_show_teaching_slide({
		"icon": "🔗",
		"title": "URL Patterns",
		"subtitle": "Directing traffic in Django",
		"bullets": [
			"[b]urls.py[/b] maps URLs to view functions",
			"[b]path()[/b] defines a single URL route",
			"The first argument is the [b]URL pattern[/b]",
			"The second argument is the [b]view function[/b] to call"
		],
		"code": "# urls.py\nfrom django.urls import path\nfrom . import views\n\nurlpatterns = [\n    path('home/', views.home),\n]",
		"header": "MODULE 2 — VIEWS & ROUTING",
		"header_icon": "🌐",
		"slide_num": "9 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Now that you have a project… how does Django know what to show?" },
			{ "name": "Student", "text": "Like… when someone visits a page?" },
			{ "name": "Professor View", "text": "Exactly. When a user visits [color=#f0c674]/home/[/color], Django checks [color=#f0c674]urls.py[/color]." },
			{ "name": "Professor View", "text": "It looks for a matching [color=#f0c674]path[/color]. If it finds one, it calls the connected [color=#f0c674]view[/color]." },
			{ "name": "Student", "text": "So urls.py is like a traffic director?" },
			{ "name": "Professor View", "text": "Precisely. URL = route. View = logic." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 6: View Functions ─────────────────────────
	_show_teaching_slide({
		"icon": "👁️",
		"title": "View Functions",
		"subtitle": "Where the logic lives",
		"bullets": [
			"A [b]view[/b] is a Python function that takes a [b]request[/b]",
			"It processes data and returns a [b]response[/b]",
			"[b]HttpResponse[/b] sends raw text/HTML back",
			"Views connect [b]URLs[/b] to what the user sees"
		],
		"code": "# views.py\nfrom django.http import HttpResponse\n\ndef home(request):\n    return HttpResponse('Welcome!')",
		"header": "MODULE 2 — VIEWS & ROUTING",
		"header_icon": "🌐",
		"slide_num": "10 / 17",
		"reference": "Source: Django for Beginners (Vincent, 2023)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "A [color=#f0c674]view[/color] is just a Python function." },
			{ "name": "Professor View", "text": "It receives a [color=#f0c674]request[/color] — and returns a [color=#f0c674]response[/color]." },
			{ "name": "Student", "text": "That's it? Just a function?" },
			{ "name": "Professor View", "text": "That's it. But what you do [color=#f0c674]inside[/color] that function is everything." },
			{ "name": "Professor View", "text": "Query databases. Check permissions. Render templates. All inside the view." },
			{ "name": "Professor View", "text": "Now connect them. Write a URL path." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"view_urlpath", "Connect URLs, Views & Templates", "django", "urls.py",
		["from django.urls import path", "from . import views", "", "urlpatterns = [", "    # Add a path for 'home/' that calls views.home", "]"],
		["In urls.py — add the URL route using path()", "In views.py — write the return statement", "In templates/home.html — add your HTML heading", "Why: This represents the core Django flow (MTV). The URL routes traffic, the View processes it, and the Template displays the result."],
		"Type your code here...",
		[],   # replaced by per-file dict below
		"✅ All 3 files connected!\n  urls.py → views.home → home.html\n  Your first Django page is live!",
		"ImproperlyConfigured: Check all 3 files — each tab needs the correct code!",
		[
			"urls.py needs: path('home/', views.home)",
			"views.py needs: return HttpResponse('Welcome!')",
			"home.html needs an <h1> heading"
		]
	)
	ch_data["files"] = {
		"urls.py": "from django.urls import path\nfrom . import views\n\nurlpatterns = [\n    # Add a path for 'home/' that calls views.home\n]",
		"views.py": "from django.http import HttpResponse\n\ndef home(request):\n    # Return an HttpResponse with 'Welcome!'\n    ",
		"templates/home.html": "<!-- Add a heading that says Welcome! -->\n"
	}
	ch_data["active_file"] = "urls.py"
	ch_data["starter_code"] = ""
	# Per-file expected answers (dict = multi-tab-edit mode)
	ch_data["expected_answers"] = {
		"urls.py": [
			"    path('home/', views.home)",
			"    path('home/',views.home)",
			"    path(\"home/\", views.home)",
			"    path('home/', views.home, name='home')",
			"    path(\"home/\", views.home, name=\"home\")"
		],
		"views.py": [
			"    return HttpResponse('Welcome!')",
			"    return HttpResponse(\"Welcome!\")"
		],
		"templates/home.html": [
			"<h1>Welcome!</h1>",
			"<h1>Welcome! </h1>"
		]
	}
	
	ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file", "templates": {"home.html": "file", "base.html": "file", "book_list.html": "file", "book_form.html": "file"}, "static": {"css": {"style.css": "file"}}}, "manage.py": "file"}
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "This time you're editing [color=#f0c674]all three files[/color]." },
			{ "name": "Professor View", "text": "In [color=#f0c674]urls.py[/color]: add [color=#f0c674]path('home/', views.home)[/color]" },
			{ "name": "Professor View", "text": "In [color=#f0c674]views.py[/color]: add [color=#f0c674]return HttpResponse('Welcome!')[/color]" },
			{ "name": "Professor View", "text": "In [color=#f0c674]templates/home.html[/color]: add [color=#f0c674]<h1>Welcome!</h1>[/color]" },
			{ "name": "Professor View", "text": "Switch between tabs to edit each file. All three must be correct." }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Good. You just connected a [color=#f0c674]URL[/color] to a [color=#f0c674]view[/color]." },
			{ "name": "Professor View", "text": "This is the core of Django's routing system. Every page works this way." },
			{ "name": "Professor View", "text": "But returning raw text isn't enough. We need [color=#f0c674]templates[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	# ─── AI Minigame: The Mailman URL Router ──────────────────────
	_show_teaching_slide({
		"icon": "📬",
		"title": "URLs Are Like City Addresses",
		"subtitle": "Every page has a specific route",
		"bullets": [
			"Django's [b]urls.py[/b] is like a city map.",
			"Each URL path is an [b]address[/b] that leads to a specific [b]building[/b] (view).",
			"You can't get to the bakery by going to the police station address.",
			"The same logic applies to web apps — wrong URL = wrong page."
		],
		"code": "# Real life → Django URL:\n# 'Report a crime'    →  /police-station/\n# 'Buy some bread'    →  /bakery/\n# 'See a doctor'      →  /hospital/",
		"header": "MODULE 2 — VIEWS & ROUTING",
		"header_icon": "🌐",
		"slide_num": "★ AI GAME",
		"reference": "Source: Official Django Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Before we move to templates… let me test your routing intuition." },
			{ "name": "Professor View", "text": "Think of Django's urls.py like a [color=#f0c674]city map[/color]. Every URL is an address." },
			{ "name": "Professor View", "text": "Here are two examples:" },
			{ "name": "Professor View", "text": "[color=#f0c674]'I need to report a crime'[/color] → Routes to [color=#98c379]/police-station/[/color]" },
			{ "name": "Professor View", "text": "[color=#f0c674]'I want to buy some bread'[/color] → Routes to [color=#98c379]/bakery/[/color]" },
			{ "name": "Professor View", "text": "Now your turn. Give me [color=#f0c674]4 real-life errands[/color] and the URL path you'd route them to." },
			{ "name": "Professor View", "text": "Make them logical. And no — you can't reuse mine." }
		])
		await dialogue_box.dialogue_finished

	await _transition_from_teaching_to_ide(skip_ide)

	if not skip_ide:
		ui = await _ensure_challenge_ui()
		var ai_data = _make_challenge(
			"view_ai_url_routing", "The Mailman URL Router", "ai_evaluator", "brainstorming.txt",
			[
				"🎯 GOAL: Map 4 real-life errands to Django-style URL paths.",
				"",
				"📬 How Django Routing Works:",
				"  • Every page has a URL path, like a city address.",
				"  • URLs should be lowercase, hyphenated, with slashes.",
				"  • The URL must logically match the destination.",
				"",
				"✅ EXAMPLE (how your answer should look):",
				"  1. 'I want to see a doctor' → /hospital/",
				"  2. 'I need to work out' → /gym/",
				"  3. 'I want to watch a movie' → /cinema/",
				"  4. 'I need to mail a package' → /post-office/",
				"",
				"🚫 BANNED (do NOT use these):",
				"  • 'Report a crime' → /police-station/",
				"  • 'Buy some bread' → /bakery/",
				"",
				"📝 YOUR TURN — supply 4 errand-to-URL mappings:",
				"  1. # your errand → /your-url/",
				"  2. # your errand → /your-url/",
				"  3. # your errand → /your-url/",
				"  4. # your errand → /your-url/"
			],
			[
				"Map 4 real-life errands/destinations to Django-style URL paths.",
				"URLs should be lowercase, hyphenated, with slashes. Cannot reuse tutorial examples."
			],
			"Type your 4 errands and URLs here...",
			[],
			"System is evaluating...",
			"Evaluation failed.",
			["Think of places you visit in real life — what would their URL address be?"]
		)
		ai_data["files"] = {"brainstorming.txt": ""}
		ai_data["active_file"] = "brainstorming.txt"
		ai_data["topic"] = "ai_evaluator"
		ai_data["challenge_type"] = "url_routing"
		ai_data["project_tree"] = {"venv": {}, "mysite": {"urls.py": "file"}, "brainstorming.txt": "file"}
		ai_data["instructions"] = ["url_routing", "Map 4 real-life errands/destinations to Django-style URL paths (lowercase, hyphenated, with slashes)."]

		ui.load_challenge(ai_data)
		_show_challenge_canvas()
		ui.lock_typing(false)
		await _await_challenge_done(ui)

		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Good. You understand routing intuitively." },
				{ "name": "Professor View", "text": "Every web address follows the same logic — specific paths for specific destinations." }
			])
			await dialogue_box.dialogue_finished
		await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 3 — Templates / DTL (Dynamic HTML Rendering)
# ══════════════════════════════════════════════════════════════════════

func _play_module_3_templates(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 7: Django Template Language ────────────────
	_show_teaching_slide({
		"icon": "📄",
		"title": "Django Templates",
		"subtitle": "Dynamic HTML with Python data",
		"bullets": [
			"Templates are [b]HTML files[/b] with special Django tags",
			"[b]{{ variable }}[/b] inserts Python data into HTML",
			"[b]{% tag %}[/b] adds logic like loops and conditions",
			"Views pass data to templates via [b]context[/b] dictionaries"
		],
		"code": "<!-- template.html -->\n<h1>Hello, {{ user.name }}!</h1>\n<p>You have {{ message_count }} messages.</p>",
		"header": "MODULE 3 — TEMPLATES",
		"header_icon": "📄",
		"slide_num": "11 / 17",
		"reference": "Source: MDN Web Docs - Django Templates"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Right now, your views return raw text. That's useless for real websites." },
			{ "name": "Student", "text": "So how do we return actual HTML?" },
			{ "name": "Professor View", "text": "[color=#f0c674]Templates[/color]. They're HTML files with special Django syntax." },
			{ "name": "Professor View", "text": "Double curly braces — [color=#f0c674]{{ variable }}[/color] — inject Python data into HTML." },
			{ "name": "Student", "text": "So we can show different things for different users?" },
			{ "name": "Professor View", "text": "Exactly. That's what makes a website [color=#f0c674]dynamic[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 8: render() and Context ───────────────────
	_show_teaching_slide({
		"icon": "🔄",
		"title": "render() & Context",
		"subtitle": "Connecting views to templates",
		"bullets": [
			"[b]render()[/b] combines a template with data and returns HTML",
			"The [b]context[/b] is a dictionary of variables for the template",
			"Template files go in a [b]templates/[/b] folder inside your app",
			"This replaces [b]HttpResponse[/b] for real pages"
		],
		"code": "# views.py\nfrom django.shortcuts import render\n\ndef home(request):\n    context = {'name': 'Alice'}\n    return render(request, 'home.html', context)",
		"header": "MODULE 3 — TEMPLATES",
		"header_icon": "📄",
		"slide_num": "12 / 17",
		"reference": "Source: Official Django Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "To use a template, you use the [color=#f0c674]render()[/color] function." },
			{ "name": "Professor View", "text": "It takes three things: the [color=#f0c674]request[/color], the [color=#f0c674]template name[/color], and a [color=#f0c674]context dictionary[/color]." },
			{ "name": "Professor View", "text": "The context is just a Python dictionary. Keys become template variables." },
			{ "name": "Student", "text": "So {{ name }} in the template shows whatever 'name' is in the context?" },
			{ "name": "Professor View", "text": "Exactly. Now write a template variable." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"view_template", "Connect View, Template & URL", "django", "templates/home.html",
		["<html>", "<body>", "  <h1>Welcome!</h1>", "  <!-- Display the user's name below -->", "  <p>Hello, </p>", "</body>", "</html>"],
		["In views.py — add the render() return", "In templates/home.html — insert {{ user.name }}", "In urls.py — add the URL path", "Why: The context dictionary is how backend data is injected dynamically into frontend HTML templates."],
		"Type your code here...",
		[],   # replaced by per-file dict below
		"✅ Template rendered!\n  Hello, Alice!\n  All 3 files working together!",
		"TemplateSyntaxError: Check all 3 files — each needs the correct code!",
		[
			"views.py needs: return render(request, 'home.html', context)",
			"home.html needs: {{ user.name }}",
			"urls.py needs: path('home/', views.home)"
		]
	)
	ch_data["files"] = {
		"views.py": "from django.shortcuts import render\n\ndef home(request):\n    context = {'user': {'name': 'Alice'}}\n    # Return the rendered template with context\n    ",
		"templates/home.html": "<html>\n<body>\n  <h1>Welcome!</h1>\n  <!-- Display the user's name below -->\n  <p>Hello, </p>\n</body>\n</html>",
		"urls.py": "from django.urls import path\nfrom . import views\n\nurlpatterns = [\n    # Add a path for 'home/' that calls views.home\n]"
	}
	ch_data["active_file"] = "views.py"
	ch_data["starter_code"] = ""
	# Per-file expected answers (dict = multi-tab-edit mode)
	ch_data["expected_answers"] = {
		"views.py": [
			"    return render(request, 'home.html', context)",
			"    return render(request, \"home.html\", context)"
		],
		"templates/home.html": [
			"{{ user.name }}",
			"{{user.name}}",
			"{{ user.name}}"
		],
		"urls.py": [
			"    path('home/', views.home)",
			"    path('home/', views.home, name='home')",
			"    path(\"home/\", views.home)",
			"    path(\"home/\", views.home, name=\"home\")"
		]
	}
	
	ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file", "templates": {"home.html": "file", "base.html": "file", "book_list.html": "file", "book_form.html": "file"}, "static": {"css": {"style.css": "file"}}}, "manage.py": "file"}
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Now connect [color=#f0c674]all three files[/color] again — this time with templates." },
			{ "name": "Professor View", "text": "In [color=#f0c674]views.py[/color]: return [color=#f0c674]render(request, 'home.html', context)[/color]" },
			{ "name": "Professor View", "text": "In [color=#f0c674]templates/home.html[/color]: insert [color=#f0c674]{{ user.name }}[/color] after 'Hello, '" },
			{ "name": "Professor View", "text": "In [color=#f0c674]urls.py[/color]: add [color=#f0c674]path('home/', views.home)[/color]" },
			{ "name": "Professor View", "text": "Switch tabs and complete all three. That's how Django connects everything." }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Good. You just made your first [color=#f0c674]dynamic template[/color]." },
			{ "name": "Professor View", "text": "Every Django website uses this. Views pass data. Templates display it." },
			{ "name": "Professor View", "text": "One more topic. Your templates look ugly without [color=#f0c674]static files[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 4 — Static Files (CSS/JS Integration)
# ══════════════════════════════════════════════════════════════════════

func _play_module_4_static_files(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 9: What Are Static Files? ─────────────────
	_show_teaching_slide({
		"icon": "🎨",
		"title": "Static Files",
		"subtitle": "CSS, JavaScript, and images in Django",
		"bullets": [
			"[b]Static files[/b] = CSS, JS, images — files that don't change",
			"Django does [b]NOT[/b] serve them automatically",
			"You must use [b]{% load static %}[/b] at the top of your template",
			"Then reference files with [b]{% static 'path' %}[/b]"
		],
		"code": "{% load static %}\n<html>\n<head>\n    <link rel=\"stylesheet\"\n          href=\"{% static 'css/style.css' %}\">\n</head>",
		"header": "MODULE 4 — STATIC FILES",
		"header_icon": "🎨",
		"slide_num": "13 / 17",
		"reference": "Source: Official Django Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Your templates work. But they look [color=#f0c674]terrible[/color]." },
			{ "name": "Student", "text": "Because there's no CSS?" },
			{ "name": "Professor View", "text": "Exactly. CSS, JavaScript, images — Django calls these [color=#f0c674]static files[/color]." },
			{ "name": "Professor View", "text": "And here's what confuses students: Django [color=#f0c674]doesn't serve them automatically[/color]." },
			{ "name": "Student", "text": "So how do we load them?" },
			{ "name": "Professor View", "text": "You tell Django explicitly. With a template tag: [color=#f0c674]{% load static %}[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 10: Static File Structure ─────────────────
	_show_teaching_slide({
		"icon": "📂",
		"title": "Static File Structure",
		"subtitle": "Where to put your CSS and JS",
		"bullets": [
			"Create a [b]static/[/b] folder inside your app",
			"Organize into subfolders: [b]css/[/b], [b]js/[/b], [b]images/[/b]",
			"Always run [b]collectstatic[/b] before deployment",
			"[b]STATIC_URL[/b] in settings.py controls the URL prefix"
		],
		"code": "blog/\n├── static/\n│   └── css/\n│       └── style.css\n├── templates/\n│   └── home.html\n└── views.py",
		"header": "MODULE 4 — STATIC FILES",
		"header_icon": "🎨",
		"slide_num": "14 / 17",
		"reference": "Source: Django for Beginners (Vincent, 2023)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Put your static files in a [color=#f0c674]static/[/color] folder inside your app." },
			{ "name": "Professor View", "text": "Organize them: [color=#f0c674]css/[/color], [color=#f0c674]js/[/color], [color=#f0c674]images/[/color]." },
			{ "name": "Professor View", "text": "In your template, always start with [color=#f0c674]{% load static %}[/color]. Without it, nothing works." },
			{ "name": "Student", "text": "So it's like registering apps — you have to be explicit?" },
			{ "name": "Professor View", "text": "Django never guesses. You [color=#f0c674]tell it everything[/color]. Now write the tag." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"view_static", "Load Static Files", "html", "base.html",
		["<!-- Load Django's static file system -->", "", "<html>", "<head>", "    <title>My Blog</title>", "</head>"],
		["Inspect `settings.py` for STATIC_URL", "Open `templates/base.html`", "Add `{% load static %}` at the very top", "Why: Static files like CSS and images are never served automatically. They must be explicitly loaded in templates."],
		"Type your code here...",
		[
			"{% load static %}",
			"{%load static%}",
			"{% load static  %}"
		],
		"✅ Static files loaded!\n  CSS and JS are now available in your template.",
		"TemplateSyntaxError: 'static' is not a registered tag — did you forget {% load static %}?",
		[
			"Django needs you to explicitly load the static system",
			"The tag goes at the very top of your template",
			"Type: {% load static %}"
		]
	)
	ch_data["files"] = {
		"templates/base.html": "<!-- Load Django's static file system -->\n\n<html>\n<head>\n    <title>My Blog</title>\n    <link rel=\"stylesheet\" href=\"{% static 'css/style.css' %}\">\n</head>\n<body>\n    <h1>Blog</h1>\n</body>\n</html>",
		"settings.py": "STATIC_URL = '/static/'\nSTATICFILES_DIRS = [BASE_DIR / 'static']",
		"static/css/style.css": "body {\n    font-family: Arial, sans-serif;\n    background: #111827;\n    color: #f9fafb;\n}"
	}
	ch_data["active_file"] = "templates/base.html"
	ch_data["starter_code"] = ""
	
	ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file", "templates": {"home.html": "file", "base.html": "file", "book_list.html": "file", "book_form.html": "file"}, "static": {"css": {"style.css": "file"}}}, "manage.py": "file"}
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Load Django's static file system into your template." },
			{ "name": "Professor View", "text": "Use the template tag: [color=#f0c674]{% load static %}[/color]" },
			{ "name": "Professor View", "text": "This goes at the [color=#f0c674]very top[/color] of your HTML file." }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
   # { "name": "Professor View", "text": "Done. You now know how to [color=#f0c674]structure[/color], [color=#f0c674]route[/color], [color=#f0c674]render[/color], and [color=#f0c674]style[/color] a Django app." },
			{ "name": "Professor View", "text": "Project setup. Views. Templates. Static files. That's the foundation." },
			{ "name": "Professor View", "text": "Next semester, you'll learn [color=#f0c674]databases[/color] and [color=#f0c674]models[/color]. The real power of Django." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout


# ══════════════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════════════

func _make_challenge(id: String, title: String, topic: String, file_name: String,
	code_lines: Array, mission_steps: Array, placeholder: String,
	expected_answers: Array, correct_output: String, error_output: String,
	progressive_hints: Array = []) -> Dictionary:
	
	var base_hint = progressive_hints[0] if progressive_hints.size() > 0 else "Read the professor's instructions carefully."

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
		"hint": base_hint,
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


# ── Fullscreen teaching (Ch1 pattern: layer 5, under dialogue layer 10) ───

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
	_teaching_canvas.name = "ProfViewTeachingCanvas"
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
	# Push the panel upward so it sits ABOVE the dialogue box (~180px at bottom)
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
	header_icon.text = "🐍"
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
	footer.text = "— Professor View's Lecture —"
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
# Richer alternative to _show_placeholder_image — displays a polished
# lecture slide with title, bullets, optional code, and slide numbering.
#
# slide_data keys:
#   icon       : String (emoji)         — default "📖"
#   title      : String                 — big slide title
#   subtitle   : String                 — smaller description
#   bullets    : Array[String]          — bullet-point lines (BBCode ok)
#   code       : String                 — optional code example shown in a code panel
#   slide_num  : String                 — e.g. "1 / 6" shown in header

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
		header_icon.text = slide_data.get("header_icon", "🐍")

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

	var challenge_active = _challenge_ui and is_instance_valid(_challenge_ui) and bool(_challenge_ui.get("_challenge_active"))

	for entry in _dialogue_log:
		var line_label = RichTextLabel.new()
		line_label.bbcode_enabled = true
		line_label.fit_content = true
		line_label.scroll_active = false
		line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_label.add_theme_font_size_override("normal_font_size", 13)

		var speaker = entry.get("name", "???")
		var text = entry.get("text", "")
		var name_color = "#a3c4f3" if speaker == "Professor View" else "#c8e6c9"
		if challenge_active and (
			text.find("\n") != -1
			or text.find("def ") != -1
			or text.find("render(") != -1
			or text.find("HttpResponse") != -1
			or text.find("=") != -1
			or text.find("request") != -1
		):
			text = "[REDACTED - solve the challenge first!]"

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


# ══════════════════════════════════════════════════════════════════════
#  MODULE 5 — Generic Views (Class-Based Architecture)
# ══════════════════════════════════════════════════════════════════════

func _play_module_5_generic_views(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()

	# ─── Slide: ListView ───
	_show_teaching_slide({
		"icon": "🏭",
		"title": "Class-Based Generic Views",
		"subtitle": "The CRUD Factories",
		"bullets": [
			"[b]C.R.U.D.[/b] stands for Create, Read, Update, Delete. It is the blood of the web.",
			"Function-Based Views require you to write repetitive CRUD SQL logic manually.",
			"Django provides [b]Class-Based Generic Views[/b] to automate this.",
			"A [b]ListView[/b] automatically queries all objects and passes them to a template."
		],
		"code": "from django.views.generic import ListView\n\nclass BookListView(ListView):\n    model = Book\n    template_name = 'book_list.html'",
		"header": "MODULE 5 — CRUD & GENERIC VIEWS",
		"header_icon": "🗃️",
		"slide_num": "15 / 17"
	})
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Listen closely. The web is built entirely on C.R.U.D." },
			{ "name": "Professor View", "text": "Instead of writing function after function to pull data, Django provides [color=#f0c674]Class-Based Views (CBV)[/color]." }
		])
		await dialogue_box.dialogue_finished
	
	await get_tree().create_timer(0.3).timeout
	await _transition_from_teaching_to_ide(skip_ide)

	# ─── Challenge 1: ListView ───
	if not skip_ide:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"view_generic_list", "Generic ListView (Read All)", "django", "views.py",
			[],
			["Use ListView to display all Books, route it with as_view(), and render object_list.", "Why: Because Django's ORM and Views are heavily abstracted for speed of development."],
			"Type the class-based components...",
			[],
			"✅ Success! ListView successfully routed and rendered.",
			"Error: Ensure you hit all 3 files. Use BookListView in urls, and object_list in the template.",
			[
				"In views.py: inherit from ListView and set 'model = Book'.",
				"In urls.py: use BookListView.as_view().",
				"In book_list.html: loop using {% for book in object_list %}."
			]
		)
		ch_data["files"] = {
			"views.py": "from django.views.generic import ListView\nfrom .models import Book\n\n# TODO: Create a BookListView that inherits from ListView\nclass BookListView(\n    model = \n    template_name = 'book_list.html'\n",
			"urls.py": "from django.urls import path\nfrom .views import BookListView\n\nurlpatterns = [\n    # TODO: Add the path for BookListView using .as_view()\n    path('books/', \n]\n",
			"templates/book_list.html": "<h1>All Books</h1>\n<ul>\n    <!-- TODO: Generic Views automatically inject a variable called 'object_list' -->\n    <!-- Loop through object_list and print book.title! -->\n    {% for book in    %}\n        <li>{{ book.title }}</li>\n    {% endfor %}\n</ul>"
		}
		ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "settings.py": "file", "urls.py": "file"}, "app": {"__init__.py": "file", "models.py": "file", "urls.py": "file", "views.py": "file"}, "templates": {"book_list.html": "file"}, "manage.py": "file"}
		ch_data["active_file"] = "views.py"
		ch_data["expected_answers"] = {
			"views.py": [
				"class BookListView(ListView):\n    model = Book"
			],
			"urls.py": [
				"path('books/', BookListView.as_view()"
			],
			"templates/book_list.html": [
				"{% for book in object_list %}"
			]
		}
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Let's build the R in CRUD. Read All." },
				{ "name": "Professor View", "text": "In views.py, finish the [color=#f0c674]ListView[/color] class." },
				{ "name": "Professor View", "text": "In urls.py, use [color=#f0c674].as_view()[/color] to route it. In book_list.html, loop through [color=#f0c674]object_list[/color]." }
			])
			await dialogue_box.dialogue_finished
		
		ui.lock_typing(false)
		await _await_challenge_done(ui)

	# ─── Slide: DetailView ───
	_before_teaching_slides()
	_show_teaching_slide({
		"icon": "🔍",
		"title": "DetailView",
		"subtitle": "Read a single object",
		"bullets": [
			"[b]DetailView[/b] is used to view a specific item (like a single user profile or specific book).",
			"To do this, the URL must pass a Primary Key ([b]pk[/b]) or Slug to the view.",
			"The view intercepts the [b]<int:pk>[/b] from the URL, automatically fetches the database item, and injects it into the template as [color=#f0c674]object[/color]."
		],
		"code": "from django.views.generic import DetailView\n\nclass BookDetailView(DetailView):\n    model = Book\n    # Automatically looks for book_detail.html and passes 'object'",
		"header": "MODULE 5 — CRUD & GENERIC VIEWS",
		"header_icon": "🗃️",
		"slide_num": "16 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "A list is useless if we cannot drill down into specific items." },
			{ "name": "Professor View", "text": "This is where [color=#f0c674]DetailView[/color] comes in." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	await _transition_from_teaching_to_ide(skip_ide)

	# ─── Challenge 2: DetailView ───
	if not skip_ide:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"view_generic_detail", "Generic DetailView (Read Single)", "django", "urls.py",
			[],
			["Use an integer parameter in the URL route to pass the Primary Key to the DetailView.", "Why: DetailView inherently relies on URL parameters to safely query the exact database record requested."],
			"Type the URL routing...",
			[],
			"✅ Success! DetailView successfully routed via Primary Key.",
			"Error: Use <int:pk> in the URL path, and BookDetailView.as_view().",
			[
				"In urls.py: path('book/<int:pk>/', BookDetailView.as_view(), name='book-detail')"
			]
		)
		ch_data["files"] = {
			"urls.py": "from django.urls import path\nfrom .views import BookDetailView\n\nurlpatterns = [\n    # TODO: Route to BookDetailView.as_view(). Pass an integer 'pk' in the URL!\n    path('book/          /',                            , name='book-detail')\n]\n",
			"views.py": "from django.views.generic import DetailView\nfrom .models import Book\n\nclass BookDetailView(DetailView):\n    model = Book\n    template_name = 'book_detail.html'\n"
		}
		ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "settings.py": "file", "urls.py": "file"}, "app": {"__init__.py": "file", "models.py": "file", "urls.py": "file", "views.py": "file"}, "manage.py": "file"}
		ch_data["active_file"] = "urls.py"
		ch_data["expected_answers"] = {
			"urls.py": [
				"path('book/<int:pk>/', BookDetailView.as_view(), name='book-detail')"
			]
		}
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "I have written the DetailView class for you." },
				{ "name": "Professor View", "text": "I need you to open [color=#f0c674]urls.py[/color] and properly map the [color=#f0c674]<int:pk>[/color] URL parameter to [color=#f0c674]BookDetailView.as_view()[/color]." }
			])
			await dialogue_box.dialogue_finished
		
		ui.lock_typing(false)
		await _await_challenge_done(ui)

	# ─── Slide: Create/Update/Delete ───
	_before_teaching_slides()
	_show_teaching_slide({
		"icon": "🏗️",
		"title": "Create, Update, Delete",
		"subtitle": "Writing data directly to the Database.",
		"bullets": [
			"[b]CreateView / UpdateView[/b]: These automatically generate an HTML Form based on the model's fields, save data on POST, and redirect.",
			"You must specify [color=#f0c674]fields = ['title', 'author'][/color] and a [color=#f0c674]success_url[/color].",
			"[b]DeleteView[/b]: Automatically asks for confirmation and deletes the database record."
		],
		"code": "from django.views.generic import CreateView\n\nclass BookCreateView(CreateView):\n    model = Book\n    fields = ['title', 'author']\n    success_url = '/books/'",
		"header": "MODULE 5 — CRUD & GENERIC VIEWS",
		"header_icon": "🗃️",
		"slide_num": "17 / 17"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "We can read. Now we must alter." },
			{ "name": "Professor View", "text": "CreateView and UpdateView are incredibly aggressive shortcuts. They literally generate HTML forms for you." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	await _transition_from_teaching_to_ide(skip_ide)

	# ─── Challenge 3: CreateView ───
	if not skip_ide:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"view_generic_create", "Generic CreateView (Create Data)", "django", "views.py",
			[],
			["Use CreateView to orchestrate form creation and redirection.", "Why: Without specifying fields and success_url, CreateView does not know what data to permit or where to send the user after saving."],
			"Type the missing variables...",
			[],
			"✅ Success! C.R.U.D is fully complete.",
			"Error: Specify 'fields' as a list containing 'name', and reverse_lazy for the success_url.",
			[
				"In views.py: fields = ['name']",
				"In views.py: success_url = reverse_lazy('books')"
			]
		)
		ch_data["files"] = {
			"views.py": "from django.views.generic import CreateView\nfrom django.urls import reverse_lazy\nfrom .models import Book\n\nclass BookCreateView(CreateView):\n    model = Book\n    # TODO: We only want users to input the 'name' field\n    fields = \n    # TODO: Redirect them back to the /books/ URL upon creation\n    success_url = \n\nclass BookDeleteView(DeleteView):\n    model = Book\n    success_url = reverse_lazy('books')\n"
		}
		ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "settings.py": "file", "urls.py": "file"}, "app": {"__init__.py": "file", "models.py": "file", "urls.py": "file", "views.py": "file"}, "manage.py": "file"}
		ch_data["active_file"] = "views.py"
		ch_data["expected_answers"] = {
			"views.py": [
				"    fields = ['name']\n    # TODO: Redirect them back to the /books/ URL upon creation\n    success_url = reverse_lazy('books')",
				"    fields = [\"name\"]\n    # TODO: Redirect them back to the /books/ URL upon creation\n    success_url = reverse_lazy(\"books\")"
			]
		}
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Declare the required components to validate and lock our [color=#f0c674]CreateView[/color]." },
				{ "name": "Professor View", "text": "Set [color=#f0c674]fields[/color] to an array containing 'name', and use [color=#f0c674]reverse_lazy('books')[/color] to route them upon success." }
			])
			await dialogue_box.dialogue_finished
		
		ui.lock_typing(false)
		await _await_challenge_done(ui)

# ── Grade Evaluation & Backend ───────────────────────────────────────

func _evaluate_and_finalize_grade() -> String:
		
	var grade_calc = get_node_or_null("/root/GradeCalculator")
	if not grade_calc:
		push_error("Professor View: GradeCalculator autoload not found!")
		return "passed"
		
	var final_grade = grade_calc.compute_grade(_session_wrong_attempts, _session_hints_used, deduction_wrong_attempt, deduction_hint_used)
	
	if is_learning_mode:
		character_data.update_learning_mode_grade("view", final_grade)
		await _autosave_progress()
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor View", "text": "Learning mode session complete. Grade is %s." % GradeCalculator.grade_to_label(final_grade) }
			])
			await dialogue_box.dialogue_finished
		return "learning"
	character_data.ch2_y2s1_final_grade = final_grade
	print("Professor View - Final Grade: ", final_grade)
	
	if final_grade == 4.0:
		character_data.ch2_y2s1_inc_triggered = true
		
		# Auto-trigger INC prompt
		dialogue_box = _get_dialogue_box()
		if player:
			player.can_move = false
			player.can_interact = false
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor View", "text": "Your code is failing fundamentally, but not completely." },
				{ "name": "Professor View", "text": "You accumulated too many mistakes. You are receiving an INC (4.0)." },
				{ "name": "Professor View", "text": "Take the removal exam now. Pass it, or fail completely." }
			])
			await dialogue_box.dialogue_finished
		
		var passed = await _launch_removal_exam()
		if passed:
			character_data.ch2_y2s1_removal_passed = true
			character_data.ch2_y2s1_final_grade = 3.0
			character_data.ch2_y2s1_teaching_done = true
			_dispatch_rewards(3.0)
			
			if dialogue_box:
				dialogue_box.start([
					{ "name": "Professor View", "text": "You passed the removal exam. Your grade is [color=#f0c674]3.0[/color]." },
					{ "name": "Professor View", "text": "Do better next semester." }
				])
				await dialogue_box.dialogue_finished
			await _autosave_progress()
			return "inc_pass"
		else:
			character_data.ch2_y2s1_removal_passed = false
			character_data.ch2_y2s1_teaching_done = false
			character_data.ch2_y2s1_retake_count += 1
			character_data.ch2_y2s1_current_module = 0
			character_data.ch2_y2s1_final_grade = 5.0
			
			if dialogue_box:
				dialogue_box.start([
					{ "name": "Professor View", "text": "You failed the removal exam. Your grade is officially a [color=#f0c674]5.0[/color]." },
					{ "name": "Professor View", "text": "You must retake the entire chapter." }
				])
				await dialogue_box.dialogue_finished
			await _autosave_progress()
			return "inc_fail"
	elif final_grade == 5.0:
		character_data.ch2_y2s1_teaching_done = false
		character_data.ch2_y2s1_retake_count += 1
		character_data.ch2_y2s1_current_module = 0
		_dispatch_rewards(final_grade)
		
		# Show fail dialogue
		if player:
			player.can_move = false
			player.can_interact = false
		dialogue_box = _get_dialogue_box()
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor View", "text": "Your code is failing fundamentally. Your grade is [color=#f0c674]5.0[/color]." },
				{ "name": "Professor View", "text": "You must retake the entire chapter from the beginning." }
			])
			await dialogue_box.dialogue_finished
		await _autosave_progress()
		return "fail"
	else:
		# Passing condition
		character_data.ch2_y2s1_teaching_done = true
		_dispatch_rewards(final_grade)
		
		if player:
			player.can_move = false
			player.can_interact = false
		
		dialogue_box = _get_dialogue_box()
		if dialogue_box:
			var grade_str = "%.1f" % final_grade
			dialogue_box.start([
				{ "name": "Professor View", "text": "We are done here. Your final grade for this module is [color=#f0c674]" + grade_str + "[/color]." },
				{ "name": "Professor View", "text": "Keep your project structured." }
			])
			await dialogue_box.dialogue_finished
		await _autosave_progress()
		return "passed"

func _dispatch_rewards(grade: float) -> void:
	if not character_data: return
	
	var r_count = character_data.ch2_y2s1_retake_count
	
	# Only give credits if they pass (grade <= 3.0)
	if grade <= 3.0:
		var reward_amount = reward_credits_retake_0
		if r_count == 2:
			reward_amount = reward_credits_retake_1
		elif r_count == 3:
			reward_amount = reward_credits_retake_2
		elif r_count == 4:
			reward_amount = reward_credits_retake_3
		elif r_count > 4:
			reward_amount = reward_credits_retake_4_plus
			
		character_data.add_credits(reward_amount)
		print("Professor View: Awarded " + str(reward_amount) + " credits.")

# ── Removal Exam System ──────────────────────────────────────────────

const REMOVAL_QUIZ_SCENE = preload("res://Scenes/Games/removal_quiz_game.tscn")
var removal_quiz_instance: Node = null

func _launch_removal_exam() -> bool:
	var canvas = CanvasLayer.new()
	canvas.layer = 75
	get_tree().current_scene.add_child(canvas)
	
	var q_scene = REMOVAL_QUIZ_SCENE
	removal_quiz_instance = q_scene.instantiate()
	
	# The quiz sets the 'correct' key to specify the index
	var all_questions = [
		{
			"question": "Which file serves as your Django project's command center?",
			"options": ["A) admin.py", "B) manage.py", "C) views.py", "D) settings.py"],
			"correct": 1
		},
		{
			"question": "In Django routing (urls.py), what maps a browser path to a specific view?",
			"options": ["A) render()", "B) path()", "C) HttpResponse()", "D) include()"],
			"correct": 1
		},
		{
			"question": "When defining an HTML template context, how is it typically structured?",
			"options": ["A) As a Python list", "B) As a Python Dictionary", "C) As a JSON string", "D) As an array tuple"],
			"correct": 1
		},
		{
			"question": "Which generic view is designed to handle form submissions and save a new object?",
			"options": ["A) CreateView", "B) DetailView", "C) ListView", "D) TemplateView"],
			"correct": 0
		},
		{
			"question": "Where do you register a new app so Django knows it exists?",
			"options": ["A) views.py imports", "B) urls.py pathways", "C) settings.py INSTALLED_APPS", "D) manage.py setup"],
			"correct": 2
		}
	]
	
	removal_quiz_instance.all_questions = all_questions
	removal_quiz_instance.quiz_count = 5
	removal_quiz_instance.pass_score = removal_pass_score
	
	canvas.add_child(removal_quiz_instance)
	
	var score = await removal_quiz_instance.quiz_completed
	var passed = score >= removal_pass_score
	
	canvas.queue_free()
	
	return passed

func _autosave_progress():
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.save_game()

	if player:
		player.can_move = false
		player.block_ui_input = true
		player.set_physics_process(false)

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lbl = Label.new()
	lbl.text = "⏳ Syncing grades to DjangoQuest SIS..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 28)
	canvas.add_child(bg)
	canvas.add_child(lbl)
	get_tree().current_scene.add_child(canvas)

	await get_tree().create_timer(2.5).timeout

	if is_instance_valid(canvas):
		canvas.queue_free()

	if player:
		player.can_move = true
		player.block_ui_input = false
		player.set_physics_process(true)
