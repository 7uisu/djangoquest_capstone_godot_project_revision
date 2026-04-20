# ch2_professor_query_controller.gd — Year 2 Semester 2 Professor Controller
# Manages the teach-code-teach-code flow for Professor Query (Models, ORM & Databases)
# Wired to NPCMaleCollegeProf03 via college_map_manager.gd
#
# Flow:
#   Player interacts with NPCMaleCollegeProf03 → gate check (Y1S1+Y1S2+Y2S1 required) →
#   lecture prompt → 4 modules of (Teaching slides + dialogue) then IDE coding
#   challenges → Mark ch2_y2s2_teaching_done = true
#
# Semester 2 Modules:
#   Module 1 — Models & Migrations
#   Module 2 — Django ORM (QuerySets)
#   Module 3 — Admin Panel
#   Module 4 — MVT Flow (Review)
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

# ─── AI Evaluator Skip Tracking (current session) ────────────────────────────
# Tracks which AI challenges were skipped in the CURRENT RUN so the controller
# can show partial-skip dialogue and handle the full-offline edge case.
var _session_ai_oto_skipped: bool = false
var _session_ai_otm_skipped: bool = false
var _session_ai_mtm_skipped: bool = false

func _on_ai_challenge_skipped(challenge_id: String) -> void:
	match challenge_id:
		"query_ai_evaluator_1": _session_ai_oto_skipped = true
		"query_ai_evaluator_2": _session_ai_otm_skipped = true
		"query_ai_evaluator_3": _session_ai_mtm_skipped = true
	var skip_count = (1 if _session_ai_oto_skipped else 0) + \
					 (1 if _session_ai_otm_skipped else 0) + \
					 (1 if _session_ai_mtm_skipped else 0)
	print("[ProfQuery] AI challenge skipped: %s | Session skip total: %d/3" % [challenge_id, skip_count])

const deduction_wrong_attempt: float = 0.25
const deduction_hint_used: float = 0.50
const removal_pass_score: int = 3

var reward_credits_retake_0: int = 300
var reward_credits_retake_1: int = 250
var reward_credits_retake_2: int = 200
var reward_credits_retake_3: int = 150
var reward_credits_retake_4_plus: int = 100

const REMOVAL_QUIZ_SCENE = preload("res://Scenes/Games/removal_quiz_game.tscn")

var retake_dialogues: Array = [
	# Index 0 — first time (normal intro, handled by existing code)
	[],
	# Index 1 — retake 1
	[{ "name": "Professor Query", "text": "Back again. Let's review the data layer from scratch." }],
	# Index 2 — retake 2
	[
		{ "name": "Professor Query", "text": "Two attempts now." },
		{ "name": "Professor Query", "text": "Pay closer attention to migrations and querysets this time." }
	],
	# Index 3 — retake 3+
	[
		{ "name": "Professor Query", "text": "I've seen students struggle with the ORM before." },
		{ "name": "Professor Query", "text": "But persistence is a valid algorithm. One more time." }
	]
]

# ── Interaction Handler ───────────────────────────────────────────────

func _on_professor_interacted():
	print("ProfQueryController: _on_professor_interacted() called!")
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
		
	# Check INC loop state
	if character_data and character_data.get("ch2_y2s2_inc_triggered"):
		_cutscene_running = true
		if player:
			player.can_move = false
			player.can_interact = false
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Query", "text": "You still have an INC (4.0) unresolved." },
				{ "name": "Professor Query", "text": "Take the removal exam now." }
			])
			await dialogue_box.dialogue_finished
			
		var passed = await _launch_removal_exam()
		if passed:
			character_data.ch2_y2s2_removal_passed = true
			character_data.ch2_y2s2_teaching_done = true
			character_data.ch2_y2s2_inc_triggered = false
			character_data.ch2_y2s2_final_grade = 3.0
			_dispatch_rewards()
			
			if dialogue_box:
				dialogue_box.start([
					{ "name": "Professor Query", "text": "You passed. Grade finalized at [color=#f0c674]3.0[/color]." },
					{ "name": "Professor Query", "text": "Do not fail me again." }
				])
				await dialogue_box.dialogue_finished
		else:
			character_data.ch2_y2s2_removal_passed = false
			character_data.ch2_y2s2_teaching_done = false
			character_data.ch2_y2s2_inc_triggered = false
			character_data.ch2_y2s2_retake_count += 1
			character_data.ch2_y2s2_current_module = 0
			character_data.ch2_y2s2_final_grade = 5.0
			
			if dialogue_box:
				dialogue_box.start([
					{ "name": "Professor Query", "text": "You failed the removal exam. Grade is [color=#f0c674]5.0[/color]." },
					{ "name": "Professor Query", "text": "You must retake my class from the beginning." }
				])
				await dialogue_box.dialogue_finished
		
		if player:
			player.can_move = true
			player.can_interact = true
		_cutscene_running = false
		return
	
	# ── Gate: Must complete Y1S1, Y1S2, AND Y2S1 first ────────
	var has_markup = character_data and character_data.ch2_y1s1_teaching_done
	var has_syntax = character_data and character_data.ch2_y1s2_teaching_done
	var has_view = character_data and character_data.ch2_y2s1_teaching_done
	
	if not (has_markup and has_syntax and has_view):
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Query", "text": "You're not ready for my class yet." },
				{ "name": "Professor Query", "text": "You need to finish [color=#f0c674]Professor Markup[/color], [color=#f0c674]Professor Syntax[/color], and [color=#f0c674]Professor View[/color] first." },
				{ "name": "Professor Query", "text": "Come back when you've completed all three." }
			])
		return
	
	# ── Post-completion dialogue ──────────────────────────────────
	if character_data and character_data.ch2_y2s2_teaching_done:
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Query", "text": "You've completed all my lessons for this semester." },
				{ "name": "Professor Query", "text": "[color=#f0c674]Models[/color], [color=#f0c674]ORM[/color], [color=#f0c674]Admin Panel[/color], [color=#f0c674]MVT Flow[/color]. The database layer is yours." },
				{ "name": "Professor Query", "text": "Do not let your data corrupt. Move forward." }
			])
		return
	
	# ── Retake dialogue ───────────────────────────────────────────
	if dialogue_box and character_data:
		var retake_count = character_data.ch2_y2s2_retake_count
		if retake_count > 0:
			var dialogue_index = min(retake_count, retake_dialogues.size() - 1)
			var dialogue_lines = retake_dialogues[dialogue_index]
			if dialogue_lines.size() > 0:
				dialogue_box.start(dialogue_lines)
				await dialogue_box.dialogue_finished
	
	# ── Lecture prompt ────────────────────────────────────────────
	if dialogue_box:
		var current_mod = 0
		if character_data:
			current_mod = character_data.ch2_y2s2_current_module
		
		var mod_names = ["Models & Migrations", "Django ORM", "Admin Panel", "MVT Flow"]
		var mod_label = mod_names[current_mod] if current_mod < mod_names.size() else "the lesson"
		
		var lines = [{
			"name": "Professor Query",
			"text": "Ready for the lecture on " + mod_label + "?",
			"choices": ["Yes", "Not yet"]
		}]
		
		dialogue_box.choice_selected.connect(_on_lecture_choice, CONNECT_ONE_SHOT)
		dialogue_box.start(lines)

func _on_lecture_choice(choice_index: int):
	print("ProfQueryController: choice_index = ", choice_index)
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
		current_module = character_data.ch2_y2s2_current_module
	
	_session_wrong_attempts = 0
	_session_hints_used = 0
	
	# ─── Reset per-session AI skip trackers ───────────────────────────────────
	_session_ai_oto_skipped = false
	_session_ai_otm_skipped = false
	_session_ai_mtm_skipped = false
	
	# ─── Retake Loop Guard ─────────────────────────────────────────────────────
	# If the player is retaking AND all 3 AI challenges were previously flagged as
	# skipped, clear the flags now so they get a fresh chance this run.
	# Without this, the flags would stay "skipped" forever across all retakes.
	if character_data and character_data.ch2_y2s2_retake_count > 0:
		if character_data.get_ai_skip_count_y2s2() == 3:
			character_data.reset_ai_skip_flags_y2s2()
			print("[ProfQuery] Retake loop guard triggered — AI skip flags cleared for fresh run.")
	
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
		await _play_module_1_models(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s2_current_module = 1
	
	if current_module <= 1:
		await _play_module_2_orm(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s2_current_module = 2
	
	if current_module <= 2:
		await _play_module_3_admin(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s2_current_module = 3
	
	if current_module <= 3:
		await _play_module_4_mvt(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s2_current_module = 4
	
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
	
	# Evaluate Grade
	if not is_learning_mode and not DEBUG_SKIP_IDE:
		character_data.ch2_y2s2_wrong_attempts = _session_wrong_attempts
		character_data.ch2_y2s2_hints_used = _session_hints_used
		var grade_result = await _evaluate_and_finalize_grade()
		if grade_result == "fail" or grade_result == "inc_fail":
			if player:
				player.can_move = true
				player.can_interact = true
				player.set_physics_process(true)
				player.block_ui_input = false
			_cutscene_running = false
			return
			
	if is_learning_mode or DEBUG_SKIP_IDE:
		dialogue_box = _get_dialogue_box()
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Query", "text": "Database migrations applied. Models normalized." },
				{ "name": "Professor Query", "text": "You now understand [color=#f0c674]models[/color], [color=#f0c674]ORM queries[/color], [color=#f0c674]admin registration[/color], and the [color=#f0c674]MVT flow[/color]." },
				{ "name": "Professor Query", "text": "These aren't just topics. They're the data backbone of every Django application." },
				{ "name": "Professor Query", "text": "Year 2 complete. Do not let your data corrupt." }
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
	while not ui.results_overlay.visible:
		await get_tree().create_timer(0.1).timeout
	# Show the continue button and wait for the player to click it
	ui.continue_button.visible = true
	ui.continue_button.text = "Next ▸"
	await ui.continue_button.pressed
	ui.continue_button.visible = false
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
	
	var dim_bg = ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 1.0)
	dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_challenge_canvas.add_child(dim_bg)

	_challenge_ui = CODING_UI_SCENE.instantiate()
	_challenge_ui.hide_close_button = true
	_challenge_canvas.add_child(_challenge_ui)
	
	if not _challenge_ui.is_connected("challenge_failed", Callable(self, "_on_wrong_attempt")):
		_challenge_ui.connect("challenge_failed", Callable(self, "_on_wrong_attempt"))
	if not _challenge_ui.is_connected("hint_used", Callable(self, "_on_hint_used")):
		_challenge_ui.connect("hint_used", Callable(self, "_on_hint_used"))
	if not _challenge_ui.is_connected("ai_challenge_skipped", Callable(self, "_on_ai_challenge_skipped")):
		_challenge_ui.connect("ai_challenge_skipped", Callable(self, "_on_ai_challenge_skipped"))
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
#  MODULE 1 — Models & Migrations
# ══════════════════════════════════════════════════════════════════════

func _play_module_1_models(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 1: What are Models ─────────────────────────
	_show_teaching_slide({
		"icon": "🗄️",
		"title": "Django Models",
		"subtitle": "Your database, defined in Python",
		"bullets": [
			"[b]Models[/b] define your database structure using Python classes.",
			"Each model class = One database table.",
			"Each class attribute = One database column.",
			"Django auto-generates SQL from your Models."
		],
		"code": "class Student(models.Model):\n    name = models.CharField(max_length=100)\n    grade = models.CharField(max_length=2)",
		"header": "MODULE 1 — MODELS & MIGRATIONS",
		"header_icon": "🗃️",
		"slide_num": "1 / 8"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Welcome. This semester, we deal with data." },
			{ "name": "Professor Query", "text": "Every application needs a way to store and organize information." },
			{ "name": "Student", "text": "So we write SQL?" },
			{ "name": "Professor Query", "text": "No. That's the old way." },
			{ "name": "Professor Query", "text": "In Django, we use [color=#f0c674]Models[/color] to define database tables using Python classes." },
			{ "name": "Professor Query", "text": "One class equals one table. Each attribute is a column. Clean and simple." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 2: Migrations ─────────────────────────
	_show_teaching_slide({
		"icon": "🔄",
		"title": "Migrations",
		"subtitle": "Version control for your database",
		"bullets": [
			"[b]python manage.py makemigrations[/b]",
			"→ Creates instructions for database changes.",
			"[b]python manage.py migrate[/b]",
			"→ Applies those instructions to the actual database."
		],
		"code": "python manage.py makemigrations\npython manage.py migrate",
		"header": "MODULE 1 — MODELS & MIGRATIONS",
		"header_icon": "🗃️",
		"slide_num": "2 / 8"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Writing the Python class isn't enough. You need to tell the database to actually create the table." },
			{ "name": "Student", "text": "How do we do that?" },
			{ "name": "Professor Query", "text": "Two commands. [color=#f0c674]makemigrations[/color] prepares the changes. [color=#f0c674]migrate[/color] applies them." },
			{ "name": "Professor Query", "text": "Think of migrations like version control for your database." },
			{ "name": "Professor Query", "text": "Now let's see if you can define a model field." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"query_model", "Define a Model Field", "python", "models.py",
		["from django.db import models", "", "class Student(models.Model):", "    # Define a name field using a CharField with max_length=100", "    "],
		["Define the 'name' field using models.CharField(max_length=100)", "Why: Models define your database schema in Python code. Django automatically translates this class into full SQL database tables."],
		"Type the field definition here...",
		[
			"name = models.CharField(max_length=100)",
			"name=models.CharField(max_length=100)"
		],
		"✅ Success! Table column 'name' defined.\n  Column type: VARCHAR(100)\n  Nullable: False",
		"Error: Invalid Field Definition. Did you use models.CharField?",
		[
			"You need to define the class variable: name",
			"Set it equal to models.CharField(max_length=100)"
		]
	)
	
	ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file"}, "manage.py": "file"}
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Define the [color=#f0c674]name[/color] field for our Student model." },
			{ "name": "Professor Query", "text": "It should be a CharField that can hold up to 100 characters." },
			{ "name": "Professor Query", "text": "Type: [color=#f0c674]name = models.CharField(max_length=100)[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Good. That column can now hold up to 100 characters of text." },
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 2.1: Database Backends ─────────────────────────
	_show_teaching_slide({
		"icon": "🗄️",
		"title": "Database Backends",
		"subtitle": "SQLite vs PostgreSQL",
		"bullets": [
			"[b]SQLite[/b] comes built into Django by default. It's stored as a simple file (db.sqlite3).",
			"Perfect for local development.",
			"[b]PostgreSQL[/b] or [b]MySQL[/b] is what you use in production.",
			"You configure this inside [b]settings.py[/b]!"
		],
		"code": "DATABASES = {\n    'default': {\n        'ENGINE': 'django.db.backends.sqlite3',\n        'NAME': BASE_DIR / 'db.sqlite3',\n    }\n}",
		"header": "MODULE 1 — MODELS & MIGRATIONS",
		"header_icon": "🗃️",
		"slide_num": "3 / 10"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Out of the box, Django is configured to use [color=#f0c674]SQLite[/color]." },
			{ "name": "Professor Query", "text": "It's lightweight. But when you deploy to production, you will usually swap it out for PostgreSQL." },
			{ "name": "Professor Query", "text": "Now, let's test your structural intuition before moving on to Relationships." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge 1.2: Guess the Field Minigame ────────────
	if not skip_ide:
		ui = await _ensure_challenge_ui()
		ch_data = _make_challenge(
			"query_guess_fields", "Guess The Field Mapping", "python", "models.py",
			[
				"from django.db import models", 
				"", 
				"class Book(models.Model):",
				"    # 1. Stores a short Title string (max length 200)",
				"    title = ",
				"",
				"    # 2. Stores a gigantic text block (unlimited length)",
				"    synopsis = ",
				"",
				"    # 3. Stores True or False",
				"    is_published = ",
				""
			],
			["Fill in the missing field types (models.CharField, models.TextField, models.BooleanField)", "Why: Matching the right type to the data requirement ensures efficient, uncorrupted SQL mapping."],
			"Type the field declarations here...",
			[],
			"✅ Success! Fields mapped properly to VARCHAR, TEXT, and BOOLEAN.",
			"Error: Invalid Field Definition. Check spelling and capitalization.",
			[
				"For Title: title = models.CharField(max_length=200)",
				"For Synopsis: synopsis = models.TextField()",
				"For is_published: is_published = models.BooleanField(default=False)"
			]
		)
		ch_data["files"] = {
			"models.py": "from django.db import models\n\nclass Book(models.Model):\n    # 1. Stores a short Title string (max length 200)\n    title = \n\n    # 2. Stores a gigantic text block (unlimited length)\n    synopsis = \n\n    # 3. Stores True or False\n    is_published = \n"
		}
		ch_data["active_file"] = "models.py"
		ch_data["starter_code"] = ""
		ch_data["expected_answers"] = {
			"models.py": [
				"    title = models.CharField(max_length=200)\n\n    # 2. Stores a gigantic text block (unlimited length)\n    synopsis = models.TextField()\n\n    # 3. Stores True or False\n    is_published = models.BooleanField()",
				"    title = models.CharField(max_length=200)\n\n    # 2. Stores a gigantic text block (unlimited length)\n    synopsis = models.TextField()\n\n    # 3. Stores True or False\n    is_published = models.BooleanField(default=False)"
			]
		}
		ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "settings.py": "file", "urls.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "migrations": {"0001_initial.py": "file"}, "models.py": "file", "views.py": "file"}, "db.sqlite3": "file", "manage.py": "file"}
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor Query", "text": "Replace the blanks with the correct Django Field constraints." },
				{ "name": "Professor Query", "text": "Look closely at [color=#f0c674]models.py[/color] and read the comments to deduce the correct Model field." },
			])
			await dialogue_box.dialogue_finished
		
		ui.lock_typing(false)
		await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Perfect. Moving along." }
		])
		await dialogue_box.dialogue_finished

	# ─── Teaching Slide 2.2: DB Relationships ─────────────────────────
	_show_teaching_slide({
		"icon": "🔗",
		"title": "Database Relationships",
		"subtitle": "Connecting your tables",
		"bullets": [
			"[b]One-to-Many (ForeignKey)[/b]: One Author has Many Books.",
			"[b]One-to-One (OneToOneField)[/b]: One User has One Profile.",
			"[b]Many-to-Many (ManyToManyField)[/b]: Many Students take Many Courses."
		],
		"code": "author = models.ForeignKey(Author, on_delete=models.CASCADE)",
		"header": "MODULE 1 — MODELS & MIGRATIONS",
		"header_icon": "🗃️",
		"slide_num": "4 / 10"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Data rarely exists in isolation. Tables connect to other tables." },
			{ "name": "Professor Query", "text": "A Book isn't just a book. It belongs to an Author." },
			{ "name": "Professor Query", "text": "Before you write code, you must understand the real-world semantics." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge 1.3: AI Evaluator (OTO) ────────────
	if not skip_ide:
		ui = await _ensure_challenge_ui()
		
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor Query", "text": "I will judge your theoretical understanding before we write the physical query." },
				{ "name": "Professor Query", "text": "First, give me exactly two examples for a One-to-One relationship." }
			])
			await dialogue_box.dialogue_finished

		var ch_data1 = _make_challenge(
			"query_ai_evaluator_1", "Relationship Architecture", "ai_evaluator", "brainstorming.txt",
			[
				"Write out 2 real-world examples for a One-to-One relationship.",
				"",
				"Example format: 'A Car has a OneToOne with an Engine.'",
				"",
				"1. # Place first answer here",
				"2. # Place second answer here"
			],
			[
				"Provide exactly 2 real-world examples for a OneToOne relationship.",
				"",
				"Expected Format:",
				"1. [First analogy]",
				"2. [Second analogy]"
			],
			"Type your database analogies here...",
			[],
			"System is evaluating...",
			"Evaluation failed.",
			["Provide strict, real world examples."]
		)
		ch_data1["files"] = {"brainstorming.txt": ""}
		ch_data1["active_file"] = "brainstorming.txt"
		ch_data1["topic"] = "ai_evaluator"
		ch_data1["project_tree"] = {"venv": {}, "mysite": {"settings.py": "file"}, "brainstorming.txt": "file"}
		ch_data1["instructions"] = ["OneToOne"]
		
		ui.load_challenge(ch_data1)
		_show_challenge_canvas()
		ui.lock_typing(false)
		await _await_challenge_done(ui)

		# ─── OTM ───
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor Query", "text": "Good. Now for the second one." },
				{ "name": "Professor Query", "text": "Provide exactly two examples for a One-to-Many relationship." }
			])
			await dialogue_box.dialogue_finished

		var ch_data2 = _make_challenge(
			"query_ai_evaluator_2", "Relationship Architecture", "ai_evaluator", "brainstorming.txt",
			[
				"Write out 2 real-world examples for a One-to-Many relationship.",
				"",
				"Example format: 'A Library has a OneToMany with Books.'",
				"",
				"1. # Place first answer here",
				"2. # Place second answer here"
			],
			[
				"Provide exactly 2 real-world examples for a OneToMany relationship.",
				"",
				"Expected Format:",
				"1. [First analogy]",
				"2. [Second analogy]"
			],
			"Type your database analogies here...",
			[],
			"System is evaluating...",
			"Evaluation failed.",
			["Provide strict, real world examples."]
		)
		ch_data2["files"] = {"brainstorming.txt": ""}
		ch_data2["active_file"] = "brainstorming.txt"
		ch_data2["topic"] = "ai_evaluator"
		ch_data2["project_tree"] = {"venv": {}, "mysite": {"settings.py": "file"}, "brainstorming.txt": "file"}
		ch_data2["instructions"] = ["OneToMany"]
		
		ui.load_challenge(ch_data2)
		_show_challenge_canvas()
		ui.lock_typing(false)
		await _await_challenge_done(ui)

		# ─── MTM ───
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor Query", "text": "Great. Finally, the Many-to-Many relationship." }
			])
			await dialogue_box.dialogue_finished

		var ch_data3 = _make_challenge(
			"query_ai_evaluator_3", "Relationship Architecture", "ai_evaluator", "brainstorming.txt",
			[
				"Write out 2 real-world examples for a Many-to-Many relationship.",
				"",
				"Example format: 'Students have a ManyToMany with Classes.'",
				"",
				"1. # Place first answer here",
				"2. # Place second answer here"
			],
			[
				"Provide exactly 2 real-world examples for a ManyToMany relationship.",
				"",
				"Expected Format:",
				"1. [First analogy]",
				"2. [Second analogy]"
			],
			"Type your database analogies here...",
			[],
			"System is evaluating...",
			"Evaluation failed.",
			["Provide strict, real world examples."]
		)
		ch_data3["files"] = {"brainstorming.txt": ""}
		ch_data3["active_file"] = "brainstorming.txt"
		ch_data3["topic"] = "ai_evaluator"
		ch_data3["project_tree"] = {"venv": {}, "mysite": {"settings.py": "file"}, "brainstorming.txt": "file"}
		ch_data3["instructions"] = ["ManyToMany"]
		
		ui.load_challenge(ch_data3)
		_show_challenge_canvas()
		ui.lock_typing(false)
		await _await_challenge_done(ui)

		# ─── Post AI-evaluator block: handle partial or full skips ────────────────
		var skip_count = (1 if _session_ai_oto_skipped else 0) + \
						 (1 if _session_ai_otm_skipped else 0) + \
						 (1 if _session_ai_mtm_skipped else 0)
		dialogue_box = _get_dialogue_box()

		if skip_count == 3:
			# ── Full offline: all three were skipped ──────────────────────────────
			print("[ProfQuery] All 3 AI challenges skipped — showing full offline message.")
			if dialogue_box:
				_show_dialogue_with_log(dialogue_box, [
					{ "name": "Professor Query", "text": "[color=#e5c07b]⚠️ The AI evaluation system is completely unreachable.[/color]" },
					{ "name": "Professor Query", "text": "All three relationship exercises — [color=#f0c674]One-to-One[/color], [color=#f0c674]One-to-Many[/color], and [color=#f0c674]Many-to-Many[/color] — have been auto-skipped." },
					{ "name": "Professor Query", "text": "This has been logged. Your teacher can review which exercises were skipped on their dashboard." },
					{ "name": "Professor Query", "text": "This will NOT penalize your grade, but I recommend revisiting these concepts when the server is back online." }
				])
				await dialogue_box.dialogue_finished
		elif skip_count >= 1:
			# ── Partial skip: 1 or 2 were skipped ────────────────────────────────
			var skipped_labels: Array = []
			if _session_ai_oto_skipped: skipped_labels.append("[color=#e5c07b]One-to-One[/color]")
			if _session_ai_otm_skipped: skipped_labels.append("[color=#e5c07b]One-to-Many[/color]")
			if _session_ai_mtm_skipped: skipped_labels.append("[color=#e5c07b]Many-to-Many[/color]")
			var skipped_str = ", ".join(skipped_labels)
			var completed_str = str(3 - skip_count) + " of 3"
			print("[ProfQuery] Partial skip: %d/3 skipped — %s" % [skip_count, skipped_str])
			if dialogue_box:
				_show_dialogue_with_log(dialogue_box, [
					{ "name": "Professor Query", "text": "[color=#e5c07b]⚠️ Connection issues interrupted the AI evaluation.[/color]" },
					{ "name": "Professor Query", "text": "Only [color=#f0c674]" + completed_str + "[/color] relationship exercises were completed. The following were auto-skipped: " + skipped_str + "." },
					{ "name": "Professor Query", "text": "These skips have been logged for your teacher. They will not count against your grade directly, but review the skipped topics on your own." }
				])
				await dialogue_box.dialogue_finished

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Adequate logic. Now we need to learn how to actually [color=#f0c674]get data out[/color] of these tables using the ORM." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 2 — Django ORM
# ══════════════════════════════════════════════════════════════════════

func _play_module_2_orm(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 3: ORM Basics ─────────────────────────
	_show_teaching_slide({
		"icon": "🤖",
		"title": "Django ORM",
		"subtitle": "Object Relational Mapper",
		"bullets": [
			"You don't write SQL. Django writes it for you.",
			"Django translates Python into optimized SQL queries.",
			"[b]Model.objects.all()[/b] → Retrieves every row.",
			"[b]Model.objects.get(id=1)[/b] → Retrieves one specific row."
		],
		"code": "# Get ALL students\nstudents = Student.objects.all()\n\n# Get ONE student by ID\nstudent = Student.objects.get(id=1)",
		"header": "MODULE 2 — THE ORM",
		"header_icon": "🔎",
		"slide_num": "3 / 8",
		"reference": "Source: Official Django Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Storing data is only half the job. You also need to retrieve it." },
			{ "name": "Professor Query", "text": "Django has a built-in system called the [color=#f0c674]ORM[/color] for this." },
			{ "name": "Student", "text": "So we never write SQL at all?" },
			{ "name": "Professor Query", "text": "Correct. Django handles all the SQL behind the scenes." },
			{ "name": "Professor Query", "text": "Every model has a manager called [color=#f0c674]objects[/color]. That's how you access data." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 4: QuerySets ─────────────────────────
	_show_teaching_slide({
		"icon": "🔎",
		"title": "QuerySets & Filtering",
		"subtitle": "Precision data extraction",
		"bullets": [
			"[b]Model.objects.filter()[/b] returns a QuerySet.",
			"A QuerySet is a list of results matching a condition.",
			"You can chain filters for complex lookups.",
			"The database does the heavy lifting, not Python."
		],
		"code": "# Get students with grade 'A'\nhonor_roll = Student.objects.filter(grade='A')\n\n# Chain filters\nseniors = Student.objects.filter(grade='A', year=4)",
		"header": "MODULE 2 — THE ORM",
		"header_icon": "🔎",
		"slide_num": "4 / 8",
		"reference": "Source: Official Django Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Student", "text": "What if I only need certain records?" },
			{ "name": "Professor Query", "text": "Then you use [color=#f0c674]filter[/color]." },
			{ "name": "Professor Query", "text": "It tells the database to only return the rows that match your condition." },
			{ "name": "Professor Query", "text": "Don't pull everything into Python and loop through it yourself. That's wasteful." },
			{ "name": "Professor Query", "text": "Let me see if you can write a filter query." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"query_orm", "Extract Specific Data", "python", "views.py",
		["from .models import Student", "", "def get_excellent_students():", "    # Use ORM to get all students whose grade is 'A'", "    return "],
		["Write: Student.objects.filter(grade='A')", "Why: Filtering allows you to efficiently retrieve only the specific records you need, rather than loading the entire database into memory."],
		"Type the ORM query here...",
		[
			"Student.objects.filter(grade='A')",
			"Student.objects.filter(grade=\"A\")"
		],
		"✅ QuerySet generated successfully!\n  <QuerySet [<Student: Alice>, <Student: Bob>]>\n  2 records matched.",
		"Error: QuerySet invalid. Use the model's objects manager.",
		[
			"Call the default manager: Student.objects",
			"Use the filter method: .filter(grade='A')"
		]
	)
	
	ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file"}, "manage.py": "file"}
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Get all students who earned an [color=#f0c674]A[/color] grade." },
			{ "name": "Professor Query", "text": "Type: [color=#f0c674]Student.objects.filter(grade='A')[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Good. The database filtered the records for you." },
			{ "name": "Professor Query", "text": "Python just received the results. That's the right way to do it." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 3 — Admin Panel
# ══════════════════════════════════════════════════════════════════════

func _play_module_3_admin(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 5: Admin Overview ─────────────────────────
	_show_teaching_slide({
		"icon": "🔑",
		"title": "Django Admin",
		"subtitle": "A free, built-in CMS",
		"bullets": [
			"Django comes with a fully-featured admin GUI out of the box.",
			"You do NOT have to build CRUD interfaces for your staff.",
			"Access it at [b]/admin/[/b] after creating a superuser.",
			"Models are hidden by default — you must [b]register[/b] them."
		],
		"header": "MODULE 3 — ADMIN PANEL",
		"header_icon": "🛠️",
		"slide_num": "5 / 8",
		"reference": "Source: Django for Beginners (Vincent, 2023)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Student", "text": "The data is in the database now. But how do I actually see it?" },
			{ "name": "Professor Query", "text": "Django gives you a built-in [color=#f0c674]admin panel[/color]." },
			{ "name": "Professor Query", "text": "It's a full management interface. You get it for free just by using Django." },
			{ "name": "Student", "text": "So my models just show up there?" },
			{ "name": "Professor Query", "text": "Not automatically. You have to [color=#f0c674]register[/color] them first." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 6: Registering Models ─────────────────────
	_show_teaching_slide({
		"icon": "📝",
		"title": "Registering Models",
		"subtitle": "Connecting to the Admin Site",
		"bullets": [
			"Edit [b]admin.py[/b] inside your app folder.",
			"Import your model from [b]models.py[/b].",
			"Use [b]admin.site.register(ModelName)[/b].",
			"The model will now appear in your Admin dashboard."
		],
		"code": "# admin.py\nfrom django.contrib import admin\nfrom .models import Student\n\nadmin.site.register(Student)",
		"header": "MODULE 3 — ADMIN PANEL",
		"header_icon": "🛠️",
		"slide_num": "6 / 8",
		"reference": "Source: Django for Beginners (Vincent, 2023)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "To make a model visible in the admin, you edit [color=#f0c674]admin.py[/color]." },
			{ "name": "Professor Query", "text": "Import your model and register it. One line of code." },
			{ "name": "Professor Query", "text": "Go ahead and register the Student model." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"query_admin", "Register to Admin", "python", "admin.py",
		["from django.contrib import admin", "from .models import Student", "", "# Register the Student model below:", ""],
		["Type admin.site.register(Student)", "Why: Registering your model tells Django to automatically generate a graphical CRUD interface for it in the /admin/ panel."],
		"Type the admin register command...",
		[
			"admin.site.register(Student)"
		],
		"✅ Success! Student Model registered.\n  Admin panel: /admin/blog/student/\n  Actions: Add, Change, Delete, View",
		"Error: Not registered correctly. Did you use admin.site.register?",
		[
			"Invoke the admin site registration: admin.site.register()",
			"Pass 'Student' into it: admin.site.register(Student)"
		]
	)
	
	ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file"}, "manage.py": "file"}
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Register the Student model to the admin panel." },
			{ "name": "Professor Query", "text": "Type: [color=#f0c674]admin.site.register(Student)[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Done. Your staff can now manage Student records through the browser." },
			{ "name": "Professor Query", "text": "One line of code gave you an entire admin dashboard. That's Django." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 4 — MVT Flow Review
# ══════════════════════════════════════════════════════════════════════

func _play_module_4_mvt(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 7: MVT Triangle ─────────────────────────
	_show_teaching_slide({
		"icon": "🔄",
		"title": "MVT Convergence",
		"subtitle": "Model → View → Template",
		"bullets": [
			"[b]Model[/b]: Defines and queries the database.",
			"[b]View[/b]: Fetches data from Models, processes logic.",
			"[b]Template[/b]: Receives context from View, renders HTML.",
			"They form the structural triangle of every Django app."
		],
		"header": "MODULE 4 — MVT FLOW",
		"header_icon": "🔁",
		"slide_num": "7 / 8",
		"reference": "Source: Master Django MVT Architecture"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Student", "text": "So MVT means Model, View, Template?" },
			{ "name": "Professor Query", "text": "Yes. The View sits in the middle. It pulls data from the Model and sends it to the Template." },
			{ "name": "Professor Query", "text": "Without the View passing data, the Template has nothing to show." },
			{ "name": "Student", "text": "So the View connects everything?" },
			{ "name": "Professor Query", "text": "Exactly. It's the glue that holds the whole system together." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 8: The View Bridge ─────────────────────────
	_show_teaching_slide({
		"icon": "🌉",
		"title": "The View Bridge",
		"subtitle": "Extracting and packing context",
		"bullets": [
			"1. Retrieve data: [b]data = Model.objects.all()[/b]",
			"2. Pack context: [b]context = {'items': data}[/b]",
			"3. Pass to render: [b]return render(request, 'page.html', context)[/b]"
		],
		"code": "def student_list(request):\n    students = Student.objects.all()\n    return render(request, 'list.html', {'students': students})",
		"header": "MODULE 4 — MVT FLOW",
		"header_icon": "🔁",
		"slide_num": "8 / 8",
		"reference": "Source: Django for Beginners (Vincent, 2023)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Time for the final exercise." },
			{ "name": "Professor Query", "text": "Pull every student record from the database and pass it to the template." },
			{ "name": "Professor Query", "text": "This brings together everything you learned this semester." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"query_mvt", "Complete the View", "python", "views.py",
		["from django.shortcuts import render", "from .models import Student", "", "def list_students(request):", "    # Retrieve ALL student records to pass to the template", "    students = ", "", "    return render(request, 'list.html', {'students': students})"],
		["Use ORM to extract all records using objects.all()", "Why: The ORM lets you retrieve data from the database using Python objects instead of writing raw SQL queries."],
		"Type the extraction query here...",
		[
			"Student.objects.all()"
		],
		"✅ Correct! The View successfully bridges the Database and the Template.\n  Context: {'students': <QuerySet [...]>}\n  Template: list.html",
		"Error: Could not retrieve records. Use objects.all()",
		[
			"Use the Student model provided.",
			"Call: Student.objects.all()"
		]
	)
	
	ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file"}, "manage.py": "file"}
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Retrieve all student records from the database." },
			{ "name": "Professor Query", "text": "Type: [color=#f0c674]Student.objects.all()[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Well done." },
			{ "name": "Professor Query", "text": "Model feeds the View. View feeds the Template. That's how Django works." },
			{ "name": "Professor Query", "text": "You've finished everything I have to teach you this semester." },
			{ "name": "Professor Query", "text": "Next up is [color=#f0c674]Year 3[/color]. Forms and security. Good luck." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout


# ══════════════════════════════════════════════════════════════════════
#  HELPERS — Identical to Professor Syntax / Markup pattern
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
	_teaching_canvas.name = "ProfQueryTeachingCanvas"
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

	var outer_vbox = VBoxContainer.new()
	outer_vbox.name = "OuterVBox"
	outer_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(outer_vbox)

	var header = PanelContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 56)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.14, 0.22, 0.42, 1.0)
	header_style.set_corner_radius_all(0)
	header_style.corner_radius_top_left = 14
	header_style.corner_radius_top_right = 14
	header_style.set_content_margin_all(12)
	header_style.content_margin_left = 20
	header.add_theme_stylebox_override("panel", header_style)
	outer_vbox.add_child(header)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	header.add_child(header_hbox)

	var header_icon = Label.new()
	header_icon.name = "HeaderIcon"
	header_icon.text = "🎓"
	header_icon.add_theme_font_size_override("font_size", 28)
	header_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(header_icon)

	var header_title = Label.new()
	header_title.name = "HeaderTitle"
	header_title.text = "LECTURE SLIDE"
	header_title.add_theme_font_size_override("font_size", 18)
	header_title.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var custom_font = load("res://Textures/Fonts/Pixelify_Sans/static/PixelifySans-Regular.ttf")
	if custom_font:
		header_title.add_theme_font_override("font", custom_font)
	header_hbox.add_child(header_title)

	var slide_num = Label.new()
	slide_num.name = "SlideNum"
	slide_num.text = ""
	slide_num.add_theme_font_size_override("font_size", 13)
	slide_num.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 0.7))
	slide_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(slide_num)

	var body_margin = MarginContainer.new()
	body_margin.name = "BodyMargin"
	body_margin.add_theme_constant_override("margin_left", 32)
	body_margin.add_theme_constant_override("margin_right", 32)
	body_margin.add_theme_constant_override("margin_top", 20)
	body_margin.add_theme_constant_override("margin_bottom", 24)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(body_margin)

	var body_vbox = VBoxContainer.new()
	body_vbox.name = "BodyVBox"
	body_vbox.add_theme_constant_override("separation", 14)
	body_margin.add_child(body_vbox)

	var slide_icon = Label.new()
	slide_icon.name = "SlideIcon"
	slide_icon.text = "📖"
	slide_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slide_icon.add_theme_font_size_override("font_size", 44)
	body_vbox.add_child(slide_icon)

	var title_label = Label.new()
	title_label.name = "SlideTitle"
	title_label.text = ""
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	if custom_font:
		title_label.add_theme_font_override("font", custom_font)
	body_vbox.add_child(title_label)

	var subtitle = Label.new()
	subtitle.name = "SlideSubtitle"
	subtitle.text = ""
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.70, 0.82))
	body_vbox.add_child(subtitle)

	var bullets = RichTextLabel.new()
	bullets.name = "SlideBullets"
	bullets.bbcode_enabled = true
	bullets.fit_content = true
	bullets.scroll_active = false
	bullets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bullets.add_theme_font_size_override("normal_font_size", 17)
	bullets.add_theme_color_override("default_color", Color(0.82, 0.85, 0.95))
	body_vbox.add_child(bullets)

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

	var text_label = Label.new()
	text_label.name = "Text"
	text_label.visible = false
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	body_vbox.add_child(text_label)

	var footer = Label.new()
	footer.name = "Footer"
	footer.text = "— Professor Query's Lecture —"
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
		header_icon.text = slide_data.get("header_icon", "🎓")

	var ref_lbl = placeholder.find_child("ReferenceLabel", true, false)
	if ref_lbl is Label:
		var ref_text = slide_data.get("reference", "")
		ref_lbl.text = ref_text
		ref_lbl.visible = ref_text != ""

	var legacy = placeholder.find_child("Text", true, false)
	if legacy is Label:
		legacy.visible = false

	placeholder.visible = true
	_teaching_canvas.visible = true
	
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
	panel.custom_minimum_size = Vector2(600, 400)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_color = Color(0.4, 0.5, 0.8, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	_log_overlay.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var title_bar = HBoxContainer.new()
	vbox.add_child(title_bar)

	var title = Label.new()
	title.text = "Conversation Log"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(60, 24)
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
		var name_str = entry.get("name", "Unknown")
		var text_str = entry.get("text", "")
		if challenge_active and (
			text_str.find("\n") != -1
			or text_str.find("QuerySet") != -1
			or text_str.find(".filter(") != -1
			or text_str.find(".get(") != -1
			or text_str.find("=") != -1
			or text_str.find("objects.") != -1
		):
			text_str = "[REDACTED - solve the challenge first!]"
		
		var entry_vbox = VBoxContainer.new()
		entry_vbox.add_theme_constant_override("separation", 0)
		
		var name_lbl = Label.new()
		name_lbl.text = name_str
		name_lbl.add_theme_font_size_override("font_size", 12)
		if name_str == "Student" or name_str == "You":
			name_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		else:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		
		var text_lbl = RichTextLabel.new()
		text_lbl.bbcode_enabled = true
		text_lbl.text = "[color=#cccccc]" + text_str + "[/color]"
		text_lbl.fit_content = true
		text_lbl.scroll_active = false
		text_lbl.add_theme_font_size_override("normal_font_size", 14)
		text_lbl.custom_minimum_size = Vector2(500, 0)
		
		entry_vbox.add_child(name_lbl)
		entry_vbox.add_child(text_lbl)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		entry_vbox.add_child(spacer)
		
		log_content.add_child(entry_vbox)

	await get_tree().process_frame
	var scroll = _log_overlay.get_node_or_null("LogPanel/VBox/LogScroll")
	if scroll:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

# ─── Glossary ────────────────────────────────────────────────────────────────
func _on_slide_glossary_clicked(meta) -> void:
	var term = str(meta).strip_edges().to_lower()
	var popup = GLOSSARY_POPUP_SCENE.new()
	get_tree().root.add_child(popup)
	popup.show_definition(term)


# ── Grade Evaluation & Backend ───────────────────────────────────────

func _on_wrong_attempt() -> void:
	_session_wrong_attempts += 1
	var minus_grade = _session_wrong_attempts * deduction_wrong_attempt
	print("[DEBUG] Prof Query: Wrong attempt #", _session_wrong_attempts, "! Added to raw grade: +", deduction_wrong_attempt, " (Total added: ", minus_grade, ")")

func _on_hint_used() -> void:
	_session_hints_used += 1
	var minus_grade = _session_hints_used * deduction_hint_used
	print("[DEBUG] Prof Query: Hint used #", _session_hints_used, "! Added to raw grade: +", deduction_hint_used, " (Total added: ", minus_grade, ")")

func _evaluate_and_finalize_grade() -> String:
	if is_learning_mode:
		return "learning"

	var final_grade = GradeCalculator.compute_grade(_session_wrong_attempts, _session_hints_used, deduction_wrong_attempt, deduction_hint_used)
	character_data.ch2_y2s2_final_grade = final_grade

	print("--- DEBUG QUERY GRADE EVALUATION ---")
	print("Wrong Attempts: ", _session_wrong_attempts, " | Hints Used: ", _session_hints_used)
	print("Raw Computed Grade: ", final_grade, " (", GradeCalculator.grade_to_label(final_grade), ")")
	print("------------------------------------")

	dialogue_box = _get_dialogue_box()

	if GradeCalculator.is_passing(final_grade):
		character_data.ch2_y2s2_teaching_done = true
		_dispatch_rewards()
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Query", "text": "Database migrations applied. Models normalized. Final grade: [color=#f0c674]" + GradeCalculator.grade_to_label(final_grade) + "[/color]." },
				{ "name": "Professor Query", "text": "These aren't just topics. They're the data backbone of every Django application." }
			])
			await dialogue_box.dialogue_finished
		return "pass"

	elif GradeCalculator.is_inc(final_grade):
		character_data.ch2_y2s2_inc_triggered = true
		if player:
			player.can_move = false
			player.can_interact = false
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Query", "text": "Your queries are inefficient and your schemas are messy." },
				{ "name": "Professor Query", "text": "You are receiving an INC (4.0)." },
				{ "name": "Professor Query", "text": "Take the removal exam now. Prove you understand the underlying concepts." }
			])
			await dialogue_box.dialogue_finished

		var passed = await _launch_removal_exam()
		if passed:
			character_data.ch2_y2s2_final_grade = 3.0
			character_data.ch2_y2s2_removal_passed = true
			character_data.ch2_y2s2_teaching_done = true
			character_data.ch2_y2s2_inc_triggered = false
			_dispatch_rewards()
			if dialogue_box:
				dialogue_box.start([
					{ "name": "Professor Query", "text": "You passed the removal exam. Final grade: [color=#f0c674]3.0[/color]." },
					{ "name": "Professor Query", "text": "Review your data structures before the next semester." }
				])
				await dialogue_box.dialogue_finished
			return "inc_pass"
		else:
			character_data.ch2_y2s2_final_grade = 5.0
			character_data.ch2_y2s2_removal_passed = false
			character_data.ch2_y2s2_teaching_done = false
			character_data.ch2_y2s2_inc_triggered = false
			character_data.ch2_y2s2_retake_count += 1
			character_data.ch2_y2s2_current_module = 0
			if dialogue_box:
				var inc_fail_lines = [
					{ "name": "Professor Query", "text": "You failed the removal exam. Final grade: [color=#f0c674]5.0[/color]." },
					{ "name": "Professor Query", "text": "You must retake my class from the beginning." }
				]
				# If all three AI challenges were skipped, warn about retake loop
				if character_data.ch2_y2s2_ai_fully_offline:
					inc_fail_lines.append({ "name": "Professor Query", "text": "[color=#e5c07b]Note:[/color] The AI evaluation system was fully offline this run. On your next attempt, those exercises will reset and you will get a fresh chance to complete them if the server is back up." })
				dialogue_box.start(inc_fail_lines)
				await dialogue_box.dialogue_finished
			return "inc_fail"

	else:
		character_data.ch2_y2s2_final_grade = 5.0
		character_data.ch2_y2s2_retake_count += 1
		character_data.ch2_y2s2_current_module = 0
		character_data.ch2_y2s2_teaching_done = false
		if dialogue_box:
			var fail_lines = [
				{ "name": "Professor Query", "text": "Your code has failed my tests. Final grade: [color=#f0c674]5.0 (FAILED)[/color]." },
				{ "name": "Professor Query", "text": "You must retake all modules from the beginning." }
			]
			# If all three AI challenges were skipped, explain the retake loop guard
			if character_data and character_data.ch2_y2s2_ai_fully_offline:
				fail_lines.append({ "name": "Professor Query", "text": "[color=#e5c07b]Note:[/color] The AI evaluation server was completely offline this run. All three relationship exercises were skipped. On your next retake, those skip flags will be cleared so you can attempt them again if the server recovers." })
			elif character_data and character_data.get_ai_skip_count_y2s2() > 0:
				var n = character_data.get_ai_skip_count_y2s2()
				fail_lines.append({ "name": "Professor Query", "text": "[color=#e5c07b]Note:[/color] " + str(n) + " of the 3 relationship exercises were auto-skipped due to connection issues. Your teacher has been notified. These will persist on your record but will not loop — you can re-attempt them on the next run if the server is up." })
			dialogue_box.start(fail_lines)
			await dialogue_box.dialogue_finished
		return "fail"

func _dispatch_rewards() -> void:
	if not character_data: return
	var retake = character_data.ch2_y2s2_retake_count
	var credits_reward = 0
	match retake:
		0: credits_reward = reward_credits_retake_0
		1: credits_reward = reward_credits_retake_1
		2: credits_reward = reward_credits_retake_2
		3: credits_reward = reward_credits_retake_3
		_: credits_reward = reward_credits_retake_4_plus
	character_data.add_credits(credits_reward)
	print("ProfQueryController: Dispatched %d credits for retake %d" % [credits_reward, retake])

func _launch_removal_exam() -> bool:
	var canvas = CanvasLayer.new()
	canvas.layer = 75
	get_tree().current_scene.add_child(canvas)

	var quiz_instance = REMOVAL_QUIZ_SCENE.instantiate()
	quiz_instance.pass_score = removal_pass_score
	quiz_instance.quiz_count = 5
	
	quiz_instance.all_questions = [
		{
			"question": "Which file is the correct location to define Django Models?",
			"options": ["A) urls.py", "B) views.py", "C) models.py", "D) settings.py"],
			"correct": 2
		},
		{
			"question": "What is the command to apply migrations to the database?",
			"options": ["A) python manage.py migrate", "B) python manage.py apply", "C) python manage.py pushdb", "D) python manage.py makemigrations"],
			"correct": 0
		},
		{
			"question": "Which ORM method retrieves all records from a Model?",
			"options": ["A) select_all()", "B) get_all()", "C) objects.all()", "D) query.all()"],
			"correct": 2
		},
		{
			"question": "What field type should be used for a short text string like a Title?",
			"options": ["A) BooleanField", "B) TextField", "C) IntegerField", "D) CharField"],
			"correct": 3
		},
		{
			"question": "In which file do you register models so they appear in the Django Admin interface?",
			"options": ["A) settings.py", "B) admin.py", "C) urls.py", "D) views.py"],
			"correct": 1
		}
	]
	
	canvas.add_child(quiz_instance)
	var score = await quiz_instance.quiz_completed
	var passed = score >= removal_pass_score
	
	canvas.queue_free()
	return passed


# ══════════════════════════════════════════════════════════════════════════════
#  AI MINIGAME DEBUGGER
#  Toggle with the exported flag below. Creates an in-game overlay panel that
#  shows real-time state of the three AI evaluator challenges, the session skip
#  counters, the CharacterData flags, and the retake loop guard status.
#  Set DEBUG_AI_MINIGAME = false before shipping.
# ══════════════════════════════════════════════════════════════════════════════

@export var DEBUG_AI_MINIGAME: bool = false

var _debug_panel: CanvasLayer = null
var _debug_labels: Dictionary = {}   # key -> Label

func _input(event: InputEvent) -> void:
	if not DEBUG_AI_MINIGAME:
		return
	# Press F9 to toggle the AI minigame debugger overlay
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		if _debug_panel and is_instance_valid(_debug_panel):
			_debug_panel.visible = not _debug_panel.visible
			if _debug_panel.visible:
				_refresh_debug_panel()
		else:
			_build_debug_panel()

func _build_debug_panel() -> void:
	_debug_panel = CanvasLayer.new()
	_debug_panel.layer = 200
	_debug_panel.name = "AIMinigameDebugger"
	get_tree().current_scene.add_child(_debug_panel)

	var bg = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.94)
	style.border_color = Color(0.9, 0.5, 0.1, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	bg.add_theme_stylebox_override("panel", style)
	bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bg.offset_left = -420
	bg.offset_top = 10
	bg.offset_right = -10
	bg.offset_bottom = 10
	bg.custom_minimum_size = Vector2(400, 0)
	_debug_panel.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	bg.add_child(vbox)

	# Title row
	var title_hbox = HBoxContainer.new()
	vbox.add_child(title_hbox)

	var title = Label.new()
	title.text = "🤖 AI Minigame Debugger  [F9]"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.65, 0.1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func(): _debug_panel.visible = false)
	title_hbox.add_child(close_btn)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Section: Session State
	_add_debug_section(vbox, "SESSION  (current run)")
	_debug_labels["session_oto"] = _add_debug_row(vbox, "OTO skipped (session):", "false")
	_debug_labels["session_otm"] = _add_debug_row(vbox, "OTM skipped (session):", "false")
	_debug_labels["session_mtm"] = _add_debug_row(vbox, "MTM skipped (session):", "false")
	_debug_labels["session_count"] = _add_debug_row(vbox, "Session skip total:", "0 / 3")

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Section: CharacterData Flags
	_add_debug_section(vbox, "CHARACTER DATA  (persisted)")
	_debug_labels["cd_oto"] = _add_debug_row(vbox, "ch2_y2s2_ai_oto_skipped:", "—")
	_debug_labels["cd_otm"] = _add_debug_row(vbox, "ch2_y2s2_ai_otm_skipped:", "—")
	_debug_labels["cd_mtm"] = _add_debug_row(vbox, "ch2_y2s2_ai_mtm_skipped:", "—")
	_debug_labels["cd_fully_offline"] = _add_debug_row(vbox, "ch2_y2s2_ai_fully_offline:", "—")
	_debug_labels["cd_skip_count"] = _add_debug_row(vbox, "get_ai_skip_count_y2s2():", "—")
	_debug_labels["cd_retake"] = _add_debug_row(vbox, "ch2_y2s2_retake_count:", "—")

	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# Section: Loop Guard
	_add_debug_section(vbox, "RETAKE LOOP GUARD")
	_debug_labels["loop_guard"] = _add_debug_row(vbox, "Loop guard would trigger:", "—")
	_debug_labels["loop_note"] = _add_debug_row(vbox, "Note:", "Triggers if retake_count > 0 AND all 3 skipped")

	var sep4 = HSeparator.new()
	vbox.add_child(sep4)

	# Refresh and Force buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_hbox)

	var refresh_btn = Button.new()
	refresh_btn.text = "🔄 Refresh"
	refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_btn.pressed.connect(_refresh_debug_panel)
	btn_hbox.add_child(refresh_btn)

	var force_oto_btn = Button.new()
	force_oto_btn.text = "Skip OTO"
	force_oto_btn.pressed.connect(func():
		_session_ai_oto_skipped = true
		if character_data: character_data.ch2_y2s2_ai_oto_skipped = true
		_refresh_debug_panel()
	)
	btn_hbox.add_child(force_oto_btn)

	var force_otm_btn = Button.new()
	force_otm_btn.text = "Skip OTM"
	force_otm_btn.pressed.connect(func():
		_session_ai_otm_skipped = true
		if character_data: character_data.ch2_y2s2_ai_otm_skipped = true
		_refresh_debug_panel()
	)
	btn_hbox.add_child(force_otm_btn)

	var force_mtm_btn = Button.new()
	force_mtm_btn.text = "Skip MTM"
	force_mtm_btn.pressed.connect(func():
		_session_ai_mtm_skipped = true
		if character_data: character_data.ch2_y2s2_ai_mtm_skipped = true
		_refresh_debug_panel()
	)
	btn_hbox.add_child(force_mtm_btn)

	var btn_hbox2 = HBoxContainer.new()
	btn_hbox2.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_hbox2)

	var skip_all_btn = Button.new()
	skip_all_btn.text = "⚡ Skip ALL 3"
	skip_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip_all_btn.pressed.connect(func():
		_session_ai_oto_skipped = true
		_session_ai_otm_skipped = true
		_session_ai_mtm_skipped = true
		if character_data:
			character_data.ch2_y2s2_ai_oto_skipped = true
			character_data.ch2_y2s2_ai_otm_skipped = true
			character_data.ch2_y2s2_ai_mtm_skipped = true
			character_data.ch2_y2s2_ai_fully_offline = true
		_refresh_debug_panel()
	)
	btn_hbox2.add_child(skip_all_btn)

	var clear_btn = Button.new()
	clear_btn.text = "🗑 Clear All Flags"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(func():
		_session_ai_oto_skipped = false
		_session_ai_otm_skipped = false
		_session_ai_mtm_skipped = false
		if character_data:
			character_data.reset_ai_skip_flags_y2s2()
		_refresh_debug_panel()
	)
	btn_hbox2.add_child(clear_btn)

	_refresh_debug_panel()

func _add_debug_section(parent: VBoxContainer, title: String) -> void:
	var lbl = Label.new()
	lbl.text = "▸ " + title
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	parent.add_child(lbl)

func _add_debug_row(parent: VBoxContainer, key: String, initial_val: String) -> Label:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)

	var key_lbl = Label.new()
	key_lbl.text = "  " + key
	key_lbl.add_theme_font_size_override("font_size", 11)
	key_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(key_lbl)

	var val_lbl = Label.new()
	val_lbl.text = initial_val
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hbox.add_child(val_lbl)

	return val_lbl

func _refresh_debug_panel() -> void:
	if not _debug_panel or not is_instance_valid(_debug_panel):
		return

	# ── Session values ────────────────────────────────────────────────────────
	_set_debug_bool("session_oto", _session_ai_oto_skipped)
	_set_debug_bool("session_otm", _session_ai_otm_skipped)
	_set_debug_bool("session_mtm", _session_ai_mtm_skipped)
	var sess_count = (1 if _session_ai_oto_skipped else 0) + \
					 (1 if _session_ai_otm_skipped else 0) + \
					 (1 if _session_ai_mtm_skipped else 0)
	_debug_labels["session_count"].text = str(sess_count) + " / 3"
	_debug_labels["session_count"].add_theme_color_override("font_color",
		Color(0.9, 0.35, 0.35) if sess_count == 3 else
		Color(0.9, 0.65, 0.15) if sess_count > 0 else
		Color(0.5, 0.9, 0.5)
	)

	# ── CharacterData values ──────────────────────────────────────────────────
	if character_data:
		_set_debug_bool("cd_oto", character_data.ch2_y2s2_ai_oto_skipped)
		_set_debug_bool("cd_otm", character_data.ch2_y2s2_ai_otm_skipped)
		_set_debug_bool("cd_mtm", character_data.ch2_y2s2_ai_mtm_skipped)
		_set_debug_bool("cd_fully_offline", character_data.ch2_y2s2_ai_fully_offline)
		var cd_count = character_data.get_ai_skip_count_y2s2()
		_debug_labels["cd_skip_count"].text = str(cd_count) + " / 3"
		_debug_labels["cd_skip_count"].add_theme_color_override("font_color",
			Color(0.9, 0.35, 0.35) if cd_count == 3 else
			Color(0.9, 0.65, 0.15) if cd_count > 0 else
			Color(0.5, 0.9, 0.5)
		)
		_debug_labels["cd_retake"].text = str(character_data.ch2_y2s2_retake_count)
		# Loop guard check
		var guard_would_fire = character_data.ch2_y2s2_retake_count > 0 and cd_count == 3
		_debug_labels["loop_guard"].text = "YES — flags would be cleared" if guard_would_fire else "no"
		_debug_labels["loop_guard"].add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if guard_would_fire else Color(0.6, 0.65, 0.75)
		)
	else:
		for key in ["cd_oto", "cd_otm", "cd_mtm", "cd_fully_offline", "cd_skip_count", "cd_retake", "loop_guard"]:
			_debug_labels[key].text = "CharacterData not found"
			_debug_labels[key].add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))

func _set_debug_bool(key: String, value: bool) -> void:
	if not _debug_labels.has(key):
		return
	_debug_labels[key].text = "true" if value else "false"
	_debug_labels[key].add_theme_color_override("font_color",
		Color(0.9, 0.35, 0.35) if value else Color(0.5, 0.9, 0.5)
	)
