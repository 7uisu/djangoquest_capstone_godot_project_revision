# ch2_professor_rest_controller.gd — Year 3 Midyear Professor Controller
# Manages the teach-code-teach-code flow for Professor REST (APIs & Modern Systems)
# Wired to NPCFemaleCollegeProf03 via college_map_manager.gd
#
# Flow:
#   Player interacts with NPCFemaleCollegeProf03 → gate check (all Y1-Y3S2 required) →
#   lecture prompt → 2 modules of (Teaching slides + dialogue) then IDE coding
#   challenges → Mark ch2_y3mid_teaching_done = true
#
# Year 3, Midyear Modules:
#   Module 1 — APIs & JSON (DRF basics, ModelSerializer)
#   Module 2 — Token Authentication (API security, TokenAuthentication)
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
	print("ProfRESTController: _on_professor_interacted() called!")
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
	
	# ── Gate: Must complete ALL previous semesters (Y1S1 through Y3S2) ──
	var has_markup = character_data and character_data.ch2_y1s1_teaching_done
	var has_syntax = character_data and character_data.ch2_y1s2_teaching_done
	var has_view   = character_data and character_data.ch2_y2s1_teaching_done
	var has_query  = character_data and character_data.ch2_y2s2_teaching_done
	var has_token  = character_data and character_data.ch2_y3s1_teaching_done
	var has_auth   = character_data and character_data.ch2_y3s2_teaching_done
	
	if not (has_markup and has_syntax and has_view and has_query and has_token and has_auth):
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor REST", "text": "You're not ready for APIs yet." },
				{ "name": "Professor REST", "text": "Complete all previous courses first — including [color=#f0c674]Professor Auth's[/color] Authentication & Permissions class." },
				{ "name": "Professor REST", "text": "Come back when every prerequisite is cleared." }
			])
		return
	
	# ── Post-completion dialogue ──────────────────────────────────
	if character_data and character_data.ch2_y3mid_teaching_done:
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor REST", "text": "You've finished my midyear course." },
				{ "name": "Professor REST", "text": "[color=#f0c674]APIs[/color] and [color=#f0c674]token authentication[/color]. Your Django app can now serve data to anything — mobile apps, frontends, other servers." },
				{ "name": "Professor REST", "text": "Year 3 is officially behind you. The capstone awaits." }
			])
		return
	
	# ── Lecture prompt ────────────────────────────────────────────
	if dialogue_box:
		var current_mod = 0
		if character_data:
			current_mod = character_data.ch2_y3mid_current_module
		
		var mod_names = ["APIs & JSON", "Token Authentication"]
		var mod_label = mod_names[current_mod] if current_mod < mod_names.size() else "the lesson"
		
		var lines = [{
			"name": "Professor REST",
			"text": "Ready for the lecture on " + mod_label + "?",
			"choices": ["Yes", "Not yet"]
		}]
		
		dialogue_box.choice_selected.connect(_on_lecture_choice, CONNECT_ONE_SHOT)
		dialogue_box.start(lines)

func _on_lecture_choice(choice_index: int):
	print("ProfRESTController: choice_index = ", choice_index)
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
		current_module = character_data.ch2_y3mid_current_module
	
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
		await _play_module_1_apis_json(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y3mid_current_module = 1
	
	if current_module <= 1:
		await _play_module_2_token_auth(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y3mid_current_module = 2

	if current_module <= 2:
		await _play_module_3_viewsets_routers(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y3mid_current_module = 3
	
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
	
	# Completion dialogue
	dialogue_box = _get_dialogue_box()
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor REST", "text": "That's it. You've completed the midyear." },
			{ "name": "Professor REST", "text": "You now understand [color=#f0c674]APIs[/color], [color=#f0c674]serializers[/color], and [color=#f0c674]token-based authentication[/color]." },
			{ "name": "Professor REST", "text": "Your Django app no longer just renders HTML. It serves [color=#f0c674]data[/color] to anything that asks for it." },
			{ "name": "Professor REST", "text": "Modern systems don't return pages. They return JSON. And now, so does yours." },
			{ "name": "Professor REST", "text": "Year 3 is done. Prepare yourself for the capstone." }
		])
		await dialogue_box.dialogue_finished
	
	# Mark complete
	if character_data and not is_learning_mode:
		character_data.ch2_y3mid_teaching_done = true
	
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
		if qm.has_method("refresh_college_2nd_floor_quest"):
			qm.refresh_college_2nd_floor_quest()

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
#  MODULE 1 — APIs & JSON (DRF basics, ModelSerializer)
# ══════════════════════════════════════════════════════════════════════

func _play_module_1_apis_json(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 1: What is an API? ────────────────────────
	_show_teaching_slide({
		"icon": "🌐",
		"title": "APIs & JSON",
		"subtitle": "Data, not pages",
		"bullets": [
			"An [b]API[/b] (Application Programming Interface) lets apps talk to each other.",
			"Instead of returning HTML, an API returns [b]JSON[/b] data.",
			"[b]Django REST Framework (DRF)[/b] adds API support to Django.",
			"Mobile apps, frontends, and other services consume your API."
		],
		"header": "MODULE 1 — APIs & JSON",
		"header_icon": "📡",
		"slide_num": "1 / 4",
		"reference": "Source: Django REST Framework Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor REST", "text": "Everything you've built so far returns [color=#f0c674]HTML pages[/color]." },
			{ "name": "Professor REST", "text": "But what if a mobile app needs your data? It can't use HTML." },
			{ "name": "Student", "text": "So we send something else?" },
			{ "name": "Professor REST", "text": "Exactly. We send [color=#f0c674]JSON[/color] — raw structured data. No styling. No templates. Just data." },
			{ "name": "Professor REST", "text": "An [color=#f0c674]API[/color] is how your server talks to [color=#f0c674]anything[/color] — not just browsers." },
			{ "name": "Professor REST", "text": "And [color=#f0c674]Django REST Framework[/color] makes building APIs in Django almost trivial." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 2: ModelSerializer ────────────────────────
	_show_teaching_slide({
		"icon": "📦",
		"title": "The ModelSerializer",
		"subtitle": "Converting models to JSON",
		"bullets": [
			"A [b]Serializer[/b] converts Django models into JSON (and back).",
			"[b]ModelSerializer[/b] auto-generates fields from your model.",
			"Define which [b]fields[/b] to expose in the [b]Meta[/b] class.",
			"Think of it as a translator between Python and JSON."
		],
		"code": "from rest_framework import serializers\nfrom .models import Post\n\nclass PostSerializer(serializers.ModelSerializer):\n    class Meta:\n        model = Post\n        fields = ['id', 'title', 'content']",
		"header": "MODULE 1 — APIs & JSON",
		"header_icon": "📡",
		"slide_num": "2 / 4",
		"reference": "Source: Django REST Framework Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor REST", "text": "Your Django models store data in Python objects. APIs need JSON." },
			{ "name": "Professor REST", "text": "A [color=#f0c674]Serializer[/color] is the bridge. It converts your model into JSON automatically." },
			{ "name": "Student", "text": "So we don't have to manually write JSON?" },
			{ "name": "Professor REST", "text": "Correct. [color=#f0c674]ModelSerializer[/color] reads your model and generates the JSON structure for you." },
			{ "name": "Professor REST", "text": "You just tell it which [color=#f0c674]model[/color] and which [color=#f0c674]fields[/color] to include." },
			{ "name": "Professor REST", "text": "Now build one yourself." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"rest_serializer", "Create a ModelSerializer", "python", "serializers.py",
		["from rest_framework import serializers", "from .models import Post", "", "class PostSerializer(serializers.ModelSerializer):", "    class Meta:", "        model = Post", "        "],
		["Write: fields = ['id', 'title', 'content']", "Why: Serializers translate complex database models into simple formats like JSON, making the data ready to be transmitted over an API."],
		"Type your code here...",
		[
			"fields = ['id', 'title', 'content']",
			"fields=['id', 'title', 'content']",
			"fields = ['id','title','content']",
			"fields = [\"id\", \"title\", \"content\"]"
		],
		"✅ Serializer created successfully!\n  PostSerializer → Post model\n  Fields: id, title, content\n  Output: {\"id\": 1, \"title\": \"Hello\", \"content\": \"World\"}",
		"SerializerError: Invalid field definition — check your fields list!",
		[
			"Define which fields to expose as a Python list",
			"Use: fields = ['id', 'title', 'content']",
			"Type: fields = ['id', 'title', 'content']"
		]
	)
	
	ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file", "serializers.py": "file"}, "manage.py": "file"}
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor REST", "text": "Define the [color=#f0c674]fields[/color] list for the serializer." },
			{ "name": "Professor REST", "text": "Include [color=#f0c674]id[/color], [color=#f0c674]title[/color], and [color=#f0c674]content[/color]." },
			{ "name": "Professor REST", "text": "Type: [color=#f0c674]fields = ['id', 'title', 'content'][/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor REST", "text": "Good. Your model now speaks JSON." },
			{ "name": "Professor REST", "text": "Any client — a phone, a website, another server — can now request this data." },
			{ "name": "Professor REST", "text": "But right now, anyone can access it. That's a problem." },
			{ "name": "Professor REST", "text": "Next: securing your API with [color=#f0c674]tokens[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 2 — Token Authentication (API security)
# ══════════════════════════════════════════════════════════════════════

func _play_module_2_token_auth(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 3: Why Tokens? ────────────────────────────
	_show_teaching_slide({
		"icon": "🔑",
		"title": "Token Authentication",
		"subtitle": "Securing your API",
		"bullets": [
			"Browser sessions don't work for APIs — there's no browser.",
			"[b]Tokens[/b] replace sessions for API authentication.",
			"The client sends a [b]token[/b] in the request header.",
			"If the token is valid — access granted. If not — denied."
		],
		"code": "Authorization: Token 9944b09199c62bcf9418ad846dd0e4bbdfc6ee4b",
		"header": "MODULE 2 — TOKEN AUTHENTICATION",
		"header_icon": "🔐",
		"slide_num": "3 / 4",
		"reference": "Source: Django REST Framework Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor REST", "text": "When a mobile app talks to your API, there's no login page. No session cookies." },
			{ "name": "Student", "text": "So how does the server know who's asking?" },
			{ "name": "Professor REST", "text": "[color=#f0c674]Tokens[/color]. The client sends a unique token with every request." },
			{ "name": "Professor REST", "text": "Think of it like an access badge. Show it at the door. If it's valid, you get in." },
			{ "name": "Professor REST", "text": "Django REST Framework handles all of this with [color=#f0c674]TokenAuthentication[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 4: Setting Up Token Auth ──────────────────
	_show_teaching_slide({
		"icon": "⚙️",
		"title": "Configuring DRF Auth",
		"subtitle": "settings.py setup",
		"bullets": [
			"Add [b]TokenAuthentication[/b] to DRF's settings.",
			"Set it in [b]DEFAULT_AUTHENTICATION_CLASSES[/b].",
			"This tells DRF: 'check for tokens on every request'.",
			"Clients must include the token in their [b]Authorization[/b] header."
		],
		"code": "REST_FRAMEWORK = {\n    'DEFAULT_AUTHENTICATION_CLASSES': [\n        'rest_framework.authentication.TokenAuthentication',\n    ]\n}",
		"header": "MODULE 2 — TOKEN AUTHENTICATION",
		"header_icon": "🔐",
		"slide_num": "4 / 4",
		"reference": "Source: Django REST Framework Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor REST", "text": "To enable token auth, you configure it in [color=#f0c674]settings.py[/color]." },
			{ "name": "Professor REST", "text": "Add [color=#f0c674]TokenAuthentication[/color] to the default authentication classes." },
			{ "name": "Student", "text": "And that's all it takes?" },
			{ "name": "Professor REST", "text": "For the config — yes. DRF handles the rest. Token generation, validation, everything." },
			{ "name": "Professor REST", "text": "Now write the configuration." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"rest_token_auth", "Configure Token Authentication", "python", "settings.py",
		["REST_FRAMEWORK = {", "    'DEFAULT_AUTHENTICATION_CLASSES': [", "        "],
		["Write: 'rest_framework.authentication.TokenAuthentication',", "Why: Adding this to DRF settings tells the API to expect and validate token-based authentication headers from clients."],
		"Type your code here...",
		[
			"'rest_framework.authentication.TokenAuthentication',",
			"\"rest_framework.authentication.TokenAuthentication\",",
			"'rest_framework.authentication.TokenAuthentication'"
		],
		"✅ Token Authentication configured!\n  DRF Settings Updated\n  Auth Class: TokenAuthentication\n  All API endpoints now require a valid token.",
		"ConfigurationError: Invalid auth class — check the path to TokenAuthentication!",
		[
			"Add the full dotted path as a string",
			"The path is: rest_framework.authentication.TokenAuthentication",
			"Type: 'rest_framework.authentication.TokenAuthentication',"
		]
	)
	
	ch_data["project_tree"] = {"venv": {}, "mysite": {"__init__.py": "file", "asgi.py": "file", "settings.py": "file", "urls.py": "file", "wsgi.py": "file"}, "blog": {"__init__.py": "file", "admin.py": "file", "apps.py": "file", "models.py": "file", "tests.py": "file", "views.py": "file", "serializers.py": "file"}, "manage.py": "file"}
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor REST", "text": "Add [color=#f0c674]TokenAuthentication[/color] to the authentication classes." },
			{ "name": "Professor REST", "text": "Use the full path: [color=#f0c674]rest_framework.authentication.TokenAuthentication[/color]" },
			{ "name": "Professor REST", "text": "Type: [color=#f0c674]'rest_framework.authentication.TokenAuthentication',[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor REST", "text": "Done. Your API is now protected." },
			{ "name": "Professor REST", "text": "No valid token? No access. That's how modern systems work." },
			{ "name": "Professor REST", "text": "You've gone from building [color=#f0c674]websites[/color] to building [color=#f0c674]systems[/color]." },
			{ "name": "Professor REST", "text": "The midyear is complete. Well done." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout



# ══════════════════════════════════════════════════════════════════════
#  MODULE 3 — ViewSets & Routers (DRF Architecture)
# ══════════════════════════════════════════════════════════════════════

func _play_module_3_viewsets_routers(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()

	# ─── Slide: ViewSets ───
	_show_teaching_slide({
		"icon": "🏗️",
		"title": "ViewSets & Routers",
		"subtitle": "Full CRUD API in minimal code",
		"bullets": [
			"Writing separate views for list, create, retrieve, update, delete is repetitive.",
			"A [b]ModelViewSet[/b] combines ALL of those into a single class.",
			"A [b]Router[/b] automatically generates all the URL patterns.",
			"Together: [b]one class + one router = full REST API[/b]."
		],
		"code": "from rest_framework.viewsets import ModelViewSet\nfrom rest_framework.routers import DefaultRouter\n\nclass PostViewSet(ModelViewSet):\n    queryset = Post.objects.all()\n    serializer_class = PostSerializer\n\nrouter = DefaultRouter()\nrouter.register('posts', PostViewSet)",
		"header": "MODULE 3 — VIEWSETS & ROUTERS",
		"header_icon": "🔧",
		"slide_num": "5 / 6"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor REST", "text": "You wrote a Serializer. You configured Token Auth." },
			{ "name": "Professor REST", "text": "But right now, you'd need to write 5 separate views just for basic CRUD." },
			{ "name": "Student", "text": "That sounds like a lot of repetition." },
			{ "name": "Professor REST", "text": "Exactly. That's why DRF gives you [color=#f0c674]ModelViewSet[/color]." },
			{ "name": "Professor REST", "text": "One class. Full CRUD. And a [color=#f0c674]Router[/color] auto-generates all your URLs." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	await _transition_from_teaching_to_ide(skip_ide)

	# ─── Challenge: ViewSet + Router ───
	if not skip_ide:
		var ui = await _ensure_challenge_ui()
		var ch_data = _make_challenge(
			"rest_viewset", "Build a ViewSet & Router", "django", "views.py",
			[],
			["Create a ModelViewSet with queryset and serializer_class, then register it with a Router.", "Why: ViewSets eliminate the need to write individual API views for each CRUD operation. One class handles list, create, retrieve, update, and delete."],
			"Type the ViewSet and Router...",
			[],
			"✅ Full REST API generated!\n  GET    /api/posts/      → List\n  POST   /api/posts/      → Create\n  GET    /api/posts/{id}/  → Retrieve\n  PUT    /api/posts/{id}/  → Update\n  DELETE /api/posts/{id}/  → Delete",
			"Error: Ensure queryset and serializer_class are set, and the router registers the viewset.",
			[
				"In views.py: queryset = Post.objects.all()",
				"In views.py: serializer_class = PostSerializer",
				"In urls.py: router.register('posts', PostViewSet)"
			]
		)
		ch_data["files"] = {
			"views.py": "from rest_framework.viewsets import ModelViewSet\nfrom .models import Post\nfrom .serializers import PostSerializer\n\nclass PostViewSet(ModelViewSet):\n    # TODO: Set the queryset to all Post objects\n    queryset = \n    # TODO: Set the serializer class\n    serializer_class = \n",
			"urls.py": "from rest_framework.routers import DefaultRouter\nfrom .views import PostViewSet\n\nrouter = DefaultRouter()\n# TODO: Register the PostViewSet with the prefix 'posts'\n\n\nurlpatterns = router.urls\n"
		}
		ch_data["project_tree"] = {"venv": {}, "mysite": {"settings.py": "file", "urls.py": "file"}, "blog": {"__init__.py": "file", "models.py": "file", "serializers.py": "file", "views.py": "file", "urls.py": "file"}, "manage.py": "file"}
		ch_data["active_file"] = "views.py"
		ch_data["expected_answers"] = {
			"views.py": [
				"    queryset = Post.objects.all()\n    # TODO: Set the serializer class\n    serializer_class = PostSerializer"
			],
			"urls.py": [
				"router.register('posts', PostViewSet)",
				"router.register(\"posts\", PostViewSet)"
			]
		}
		ui.load_challenge(ch_data)
		_show_challenge_canvas()
		ui.lock_typing(true)

		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor REST", "text": "In [color=#f0c674]views.py[/color], set [color=#f0c674]queryset[/color] and [color=#f0c674]serializer_class[/color]." },
				{ "name": "Professor REST", "text": "In [color=#f0c674]urls.py[/color], register the ViewSet with the router." }
			])
			await dialogue_box.dialogue_finished

		ui.lock_typing(false)
		await _await_challenge_done(ui)

		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor REST", "text": "That's it. Two files. Five API endpoints. Fully functional CRUD." },
				{ "name": "Professor REST", "text": "This is how production Django REST APIs are built." },
				{ "name": "Professor REST", "text": "Serializers. Authentication. ViewSets. You now build [color=#f0c674]systems[/color], not pages." }
			])
			await dialogue_box.dialogue_finished


#  HELPERS — Identical to other professor controllers
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
	_teaching_canvas.name = "ProfRESTTeachingCanvas"
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
	header_icon.text = "📡"
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
	footer.text = "— Professor REST's Lecture —"
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
		header_icon.text = slide_data.get("header_icon", "📡")

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
		var name_color = "#a3c4f3" if speaker == "Professor REST" else "#c8e6c9"
		if challenge_active and (
			text.find("\n") != -1
			or text.find("GET") != -1
			or text.find("POST") != -1
			or text.find("PUT") != -1
			or text.find("DELETE") != -1
			or text.find("/") != -1
			or text.find("{") != -1
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
