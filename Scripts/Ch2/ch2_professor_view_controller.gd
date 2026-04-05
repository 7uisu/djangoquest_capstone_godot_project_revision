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

@onready var character_data = get_node("/root/CharacterData")

var player: Node2D = null
var professor_npc: Area2D = null
var dialogue_box = null

var _cutscene_running: bool = false
var _teaching_canvas: CanvasLayer = null
var _dialogue_log: Array = []
var _log_overlay: CanvasLayer = null

var _challenge_canvas: CanvasLayer = null
var _challenge_ui: Node = null
var _original_dialogue_layer: int = 10

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
	
	# ── Lecture prompt ────────────────────────────────────────────
	if dialogue_box:
		var current_mod = 0
		if character_data:
			current_mod = character_data.ch2_y2s1_current_module
		
		var mod_names = ["Project Setup", "Views & Routing", "Templates", "Static Files"]
		var mod_label = mod_names[current_mod] if current_mod < mod_names.size() else "the lesson"
		
		var lines = [{
			"name": "Professor View",
			"text": "Ready for the lecture on " + mod_label + "?",
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
			{ "name": "Professor View", "text": "You made it through the entire semester." },
			{ "name": "Professor View", "text": "You now understand [color=#f0c674]project structure[/color], [color=#f0c674]views[/color], [color=#f0c674]templates[/color], and [color=#f0c674]static files[/color]." },
			{ "name": "Professor View", "text": "This is how every Django application begins. From here, it only gets deeper." },
			{ "name": "Professor View", "text": "Semester complete. Well done." }
		])
		await dialogue_box.dialogue_finished
	
	# Mark complete
	if character_data:
		character_data.ch2_y2s1_teaching_done = true
	
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
	# The coding_challenge_ui has a 2s delay before showing results_overlay.
	# We must wait for it to actually appear before we can dismiss it.
	while not ui.results_overlay.visible:
		await get_tree().create_timer(0.1).timeout
	# Let the player see the "Challenge Solved!" screen briefly
	await get_tree().create_timer(1.5).timeout
	ui.results_overlay.visible = false
	ui.lock_typing(true)

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
		"slide_num": "1 / 15"
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
			["Type the command to create a venv named 'venv'"],
			"Type your command here...",
			[
				"python -m venv venv",
				"python3 -m venv venv",
				"py -m venv venv"
			],
			"✅ Virtual environment 'venv' created successfully!
  venv/
  ├── bin/
  ├── include/
  └── lib/",
			"CommandError: invalid command — use python -m venv <name>",
			[
				"The command uses the venv module: python -m venv",
				"Then the name of the folder: venv",
				"Type: python -m venv venv"
			]
		)
		
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Create a virtual environment called [color=#f0c674]venv[/color]." },
				{ "name": "Professor View", "text": "Type: [color=#f0c674]python -m venv venv[/color]" }
			])
			await dialogue_box.dialogue_finished
		
		ui.lock_typing(false)
		await _await_challenge_done(ui)
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Good. Your environment is isolated." },
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
		"slide_num": "2 / 15"
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
			["Type the pip command to install Django"],
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
		"slide_num": "2 / 15"
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
			["Type the command to create a Django project named 'mysite'"],
			"Type your command here...",
			[
				"django-admin startproject mysite",
				"django-admin startproject mysite ."
			],
			"✅ Project 'mysite' created successfully!
  mysite/
  ├── manage.py
  └── mysite/
      ├── settings.py
	  └── urls.py",
			"CommandError: invalid command — use django-admin startproject <name>",
			[
				"The command starts with: django-admin",
				"Then the action: startproject",
				"Type: django-admin startproject mysite"
			]
		)
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Create a new Django project called [color=#f0c674]mysite[/color]." },
				{ "name": "Professor View", "text": "Type: [color=#f0c674]django-admin startproject mysite[/color]" }
			])
			await dialogue_box.dialogue_finished
		ui.lock_typing(false)
		await _await_challenge_done(ui)

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
		"code": "python manage.py migrate
python manage.py runserver",
		"header": "MODULE 1 — PROJECT SETUP",
		"header_icon": "🐍",
		"slide_num": "3 / 15"
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
			["Type the manage.py command to migrate the database"],
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
			["Type the command to start the server"],
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
		"slide_num": "4 / 15"
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
			["Type the command to create a Django app named 'blog'"],
			"Type your command here...",
			[
				"python manage.py startapp blog",
				"python3 manage.py startapp blog",
				"py manage.py startapp blog"
			],
			"✅ App 'blog' created successfully!
  blog/
  ├── views.py
  ├── models.py
  ├── admin.py
  └── apps.py",
			"CommandError: invalid command — use python manage.py startapp <name>",
			[
				"The command uses manage.py: python manage.py",
				"Type: python manage.py startapp blog"
			]
		)
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor View", "text": "Create an app called [color=#f0c674]blog[/color] using manage.py." },
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
		"slide_num": "5 / 15"
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
			["Add 'blog' to the INSTALLED_APPS list"],
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
		"slide_num": "6 / 15"
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
		"slide_num": "5 / 10"
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
		"slide_num": "6 / 10"
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
		"view_urlpath", "Define a URL Route", "python", "urls.py",
		["from django.urls import path", "from . import views", "", "urlpatterns = [", "    # Add a path for 'home/' that calls views.home", "]"],
		["Add a path() entry that maps 'home/' to views.home"],
		"Type your code here...",
		[
			"path('home/', views.home)",
			"path('home/',views.home)",
			"path(\"home/\", views.home)",
			"path('home/', views.home, name='home')",
			"path(\"home/\", views.home, name=\"home\")"
		],
		"✅ URL pattern registered!\n  /home/ → views.home",
		"ImproperlyConfigured: URL pattern error — check your path() syntax!",
		[
			"Use the path() function: path('url/', views.function)",
			"The URL is 'home/' and the view is views.home",
			"Type: path('home/', views.home)"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Define a URL route for [color=#f0c674]'home/'[/color]." },
			{ "name": "Professor View", "text": "Use [color=#f0c674]path()[/color] to connect it to [color=#f0c674]views.home[/color]." },
			{ "name": "Professor View", "text": "Type: [color=#f0c674]path('home/', views.home)[/color]" }
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
		"slide_num": "7 / 10"
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
		"slide_num": "8 / 10"
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
		"view_template", "Render a Template Variable", "html", "home.html",
		["<html>", "<body>", "  <h1>Welcome!</h1>", "  <!-- Display the user's name below -->", "  <p>Hello, </p>", "</body>", "</html>"],
		["Insert {{ user.name }} to display the user's name"],
		"Type your code here...",
		[
			"{{ user.name }}",
			"{{user.name}}",
			"{{ user.name}}"
		],
		"✅ Template rendered!\n  Hello, Alice!",
		"TemplateSyntaxError: invalid variable — use {{ variable }} syntax!",
		[
			"Django template variables use double curly braces: {{ }}",
			"The variable name is: user.name",
			"Type: {{ user.name }}"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor View", "text": "Insert the user's name into the template." },
			{ "name": "Professor View", "text": "Use Django's template syntax: [color=#f0c674]{{ user.name }}[/color]" },
			{ "name": "Professor View", "text": "Double curly braces. That's how you inject data into HTML." }
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
		"slide_num": "9 / 10"
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
		"slide_num": "10 / 10"
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
		["Add the {% load static %} tag at the very top of the template"],
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
			{ "name": "Professor View", "text": "Done. You now know how to [color=#f0c674]structure[/color], [color=#f0c674]route[/color], [color=#f0c674]render[/color], and [color=#f0c674]style[/color] a Django app." },
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
		header_icon.text = slide_data.get("header_icon", "🐍")

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
		var name_color = "#a3c4f3" if speaker == "Professor View" else "#c8e6c9"

		line_label.text = "[color=" + name_color + "][b]" + speaker + ":[/b][/color] [color=#d4d4d8]" + text + "[/color]"
		log_content.add_child(line_label)

	var scroll = _log_overlay.get_node_or_null("LogPanel/VBox/LogScroll")
	if scroll:
		await get_tree().process_frame
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
