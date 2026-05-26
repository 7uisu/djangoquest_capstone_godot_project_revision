# student_quiz_controller.gd — Manages the 5-student challenge loop per professor
# Attach to a Node in the college map scene (or autoload)
# Handles: NPC selection, health system, question sequencing, quest tracking
extends Node

signal student_sequence_completed(prof_key: String)
signal student_defeated(student_index: int, prof_key: String)
signal health_changed(hearts: int)
signal student_failed(student_index: int, prof_key: String)
const IDE_SCENE := preload("res://Scenes/Games/coding_challenge_ui.tscn")
const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")

# ─── State ───────────────────────────────────────────────────────────────────
var _character_data: Node = null
var _quest_manager: Node = null

var _active: bool = false
var _prof_key: String = ""
var _student_challenges: Array = []  # Array of student dicts from StudentChallengeData
var _current_student_idx: int = 0
var _current_question_idx: int = 0
var _hearts: int = 3
var _max_hearts: int = 3
var _student_names: Array = []  # Random names assigned to the 5 NPCs
var _active_npc_nodes: Array = []  # References to the 5 dialogue_interactable nodes
var _completed_students: Array = []  # Indices of students already beaten
var _active_questions: Array = []

var _ide_canvas: CanvasLayer = null
var _ide_instance: Control = null
var _health_ui: Control = null  # Will be created dynamically

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_character_data = get_node_or_null("/root/CharacterData")
	_quest_manager = get_node_or_null("/root/QuestManager")

# ─── Public API ──────────────────────────────────────────────────────────────

## Start the 5-student sequence for a given professor
func start_sequence(prof_key: String, npc_nodes: Array) -> void:
	_prof_key = prof_key
	_active = true
	_hearts = _max_hearts
	_current_student_idx = 0
	_current_question_idx = 0

	# Get challenges from data bank
	_student_challenges = StudentChallengeData.get_challenges_for_professor(prof_key)
	if _student_challenges.is_empty():
		push_error("StudentQuizController: No challenges found for professor: " + prof_key)
		_active = false
		return

	# Generate random student names or load existing
	if _character_data and _character_data.student_seq_active_professor == prof_key:
		if _character_data.student_seq_names and _character_data.student_seq_names.size() > 0:
			_student_names = _character_data.student_seq_names
		else:
			_student_names = StudentChallengeData.get_random_names(5)
			_character_data.student_seq_names = _student_names
			
		if _character_data.student_seq_completed_indices:
			_completed_students = []
			for idx in _character_data.student_seq_completed_indices:
				_completed_students.append(int(idx))
		else:
			_completed_students = []
	else:
		_student_names = StudentChallengeData.get_random_names(5)
		_completed_students = []
		if _character_data:
			_character_data.student_seq_active_professor = prof_key
			_character_data.student_seq_names = _student_names
			_character_data.student_seq_completed_indices = _completed_students

	# Store the NPC node references
	_active_npc_nodes = npc_nodes.duplicate()

	# Save active state to CharacterData
	if _character_data:
		_character_data.student_seq_active_professor = prof_key
		_character_data.student_seq_active_npcs = []
		for npc in npc_nodes:
			if npc is Node:
				_character_data.student_seq_active_npcs.append(npc.name)
		# Initialize retake counter if needed
		if not _character_data.student_retakes.has(prof_key):
			_character_data.student_retakes[prof_key] = 0

	# Wire up the NPC interaction overrides
	_wire_student_npcs()

	# Update quest HUD
	_update_quest_hud()

	# Restore visual done labels for previously completed NPCs
	for idx in _completed_students:
		if idx < _active_npc_nodes.size():
			var npc = _active_npc_nodes[idx]
			if npc and is_instance_valid(npc):
				if npc.has_method("set_passive_label"):
					npc.set_passive_label("✓ Done")
				elif npc.get_node_or_null("Label"):
					npc.get_node("Label").text = "✓ Done"

	health_changed.emit(_hearts)
	print("StudentQuizController: Started sequence for %s with %d students" % [prof_key, _student_challenges.size()])

## Called when a student NPC is interacted with
func on_student_interacted(student_index: int) -> void:
	if not _active:
		return
	if student_index in _completed_students:
		return  # Already beaten
	if get_tree().paused:
		return # Already in challenge

	_current_student_idx = student_index
	_current_question_idx = 0
	_hearts = _max_hearts
	_active_questions = []
	health_changed.emit(_hearts)
	
	var student_data = _student_challenges[student_index]
	var sname = get_student_name(student_index)
	var q_title = "this problem"
	if student_data.get("questions", []).size() > 0:
		q_title = student_data.get("questions")[0].get("title", "this problem")
	
	var is_miniboss = student_data.get("is_miniboss", false)
	
	var lines = []
	if is_miniboss:
		lines.append({ "name": sname, "text": "Hey! I'm stuck on a massive problem related to [color=#f0c674]" + q_title + "[/color]. Can you take a look?" })
	else:
		lines.append({ "name": sname, "text": "Could you help me with [color=#f0c674]" + q_title + "[/color]? I keep getting errors." })
	
	lines.append({ 
		"name": "You", 
		"text": "Do you want to help?",
		"choices": ["Yes, let's see what you have.", "Sorry, I can't right now."]
	})

	# Freeze player during dialogue
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

	# Wait a short frame before opening IDE to prevent input carryover
	await get_tree().create_timer(0.1).timeout

	if choice_state["selected"] == 1 or choice_state["selected"] == -1:
		print("StudentQuizController: Player declined to help student", student_index)
		return

	_open_ide_for_student(student_index)

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

## Check if the sequence is currently active
func is_active() -> bool:
	return _active

## Get remaining hearts
func get_hearts() -> int:
	return _hearts

## Get the student name for a given index
func get_student_name(index: int) -> String:
	if index >= 0 and index < _student_names.size():
		return _student_names[index]
	return "Student"

# ─── IDE Integration ─────────────────────────────────────────────────────────

func _open_ide_for_student(student_index: int) -> void:
	if student_index >= _student_challenges.size():
		return

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_track"):
		audio_manager.play_track("STUDENT_CHALLENGES")

	var student_data = _student_challenges[student_index]
	var questions = student_data.get("questions", [])
	if questions.is_empty():
		return

	_current_question_idx = 0
	_active_questions = _build_attempt_questions(student_data)

	# Instantiate IDE if needed
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

	# Hide overflow stack button, show health
	_configure_ide_for_student()

	# Load first question
	_load_current_question()

	# Pause game
	get_tree().paused = true
	_ide_canvas.visible = true
	_ide_instance.visible = true

func _configure_ide_for_student() -> void:
	if _ide_instance == null:
		return

	# Hide OverflowStack button
	var overflow_btn = _ide_instance.get_node_or_null("IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox/OverflowStackButton")
	if overflow_btn:
		overflow_btn.visible = false

	# Hide close button (can't escape student challenges)
	_ide_instance.hide_close_button = true
	_ide_instance.is_student_sequence = true
	var close_btn = _ide_instance.get_node_or_null("IDEScreen/TitleBar/CloseButton")
	if close_btn:
		close_btn.visible = false

	# Create/update health UI where OverflowStack button was
	_create_health_ui()

func _create_health_ui() -> void:
	# Place hearts where the OverflowStack button normally is
	var mission_vbox = _ide_instance.get_node_or_null("IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox")
	if mission_vbox == null:
		return

	# Remove old health UI if exists
	if _health_ui and is_instance_valid(_health_ui):
		_health_ui.queue_free()

	_health_ui = HBoxContainer.new()
	_health_ui.name = "StudentHealthUI"
	_health_ui.custom_minimum_size = Vector2(0, 32)
	_health_ui.alignment = BoxContainer.ALIGNMENT_CENTER

	_update_heart_display()

	# Insert where OverflowStack button is (after HintButton)
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

	# Clear existing hearts
	for child in _health_ui.get_children():
		child.queue_free()

	# Add title label
	var title = Label.new()
	title.text = "❤️ Health: "
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("e06c75"))
	_health_ui.add_child(title)

	# Add heart icons
	for i in range(_max_hearts):
		var heart = Label.new()
		if i < _hearts:
			heart.text = "♥ "
			heart.add_theme_color_override("font_color", Color("e06c75"))
		else:
			heart.text = "♡ "
			heart.add_theme_color_override("font_color", Color("5c6370"))
		heart.add_theme_font_size_override("font_size", 18)
		_health_ui.add_child(heart)

	# Add student progress
	var prog = Label.new()
	prog.text = "  [%d/%d students]" % [_completed_students.size(), _student_challenges.size()]
	prog.add_theme_font_size_override("font_size", 11)
	prog.add_theme_color_override("font_color", Color("abb2bf"))
	_health_ui.add_child(prog)

func _load_current_question() -> void:
	if _current_student_idx >= _student_challenges.size():
		return

	var student_data = _student_challenges[_current_student_idx]
	var questions = _active_questions
	if questions.is_empty():
		_active_questions = _build_attempt_questions(student_data)
		questions = _active_questions

	if _current_question_idx >= questions.size():
		# All questions for this student answered correctly
		_on_student_completed()
		return

	var question = questions[_current_question_idx].duplicate(true)

	# Set the title to include student name
	var sname = get_student_name(_current_student_idx)
	var is_miniboss = student_data.get("is_miniboss", false)
	var prefix = "⭐ MINI-BOSS: " if is_miniboss else "📝 "
	question["title"] = prefix + sname + " — " + question.get("title", "Question")

	# Set progress in the IDE
	var q_total = questions.size()
	var q_current = _current_question_idx + 1

	# Load into IDE
	_ide_instance.load_challenge(question)
	_ide_instance.progress_label.text = "Q %d/%d — Student %d/%d" % [q_current, q_total, _completed_students.size() + 1, _student_challenges.size()]

	# Re-configure IDE (overflow hidden, health shown)
	_configure_ide_for_student()

# ─── Signal Handlers ─────────────────────────────────────────────────────────

func _on_challenge_completed(success: bool, _challenge_id: String) -> void:
	if not _active:
		return

	if success:
		_current_question_idx += 1
		var student_data = _student_challenges[_current_student_idx]
		var questions = _active_questions
		if questions.is_empty():
			_active_questions = _build_attempt_questions(student_data)
			questions = _active_questions

		if _current_question_idx >= questions.size():
			# Student fully defeated!
			_on_student_completed()
		else:
			# Next question after a short delay
			await get_tree().create_timer(1.0).timeout
			_load_current_question()
	# We intentionally do nothing on 'challenge_completed(false)' because failure
	# is already captured and handled completely by the 'challenge_failed' signal!

func _on_challenge_failed() -> void:
	if not _active:
		return
	_on_wrong_answer()

func _on_wrong_answer() -> void:
	_hearts -= 1
	health_changed.emit(_hearts)
	_update_heart_display()

	# Track retakes
	if _character_data and _character_data.student_retakes.has(_prof_key):
		_character_data.student_retakes[_prof_key] += 1

	if _hearts <= 0:
		# Failed — must restart this student
		_active_questions = []
		student_failed.emit(_current_student_idx, _prof_key)
		
		# Show customized defeat IDE overlay
		if _ide_instance and _ide_instance.has_method("show_custom_result"):
			# Small pause for the red syntax error text to be visible
			await get_tree().create_timer(1.0).timeout
			if is_instance_valid(_ide_instance):
				_ide_instance.show_custom_result("💥 Defeat", "You ran out of hearts. Let's try again later.", "OK")
				await _ide_instance.challenge_completed # Emitted when user clicks OK
			
		_close_ide()

		# Reset hearts
		_hearts = _max_hearts
		health_changed.emit(_hearts)

		print("StudentQuizController: Player ran out of hearts on student %d, must retry" % _current_student_idx)
		
		# Allow a frame to pass so IDE fully closes visually before dialogue opens
		await get_tree().process_frame
		_show_defeat_dialogue()
	else:
		# Still have hearts — retry the SAME question (strict mode)
		await get_tree().create_timer(1.5).timeout
		_load_current_question()

func _on_student_completed() -> void:
	if _completed_students.has(_current_student_idx):
		return

	if _ide_instance and _ide_instance.has_method("show_custom_result"):
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(_ide_instance):
			_ide_instance.show_custom_result("🌟 Great Job!", "You successfully helped this student fix their code.", "Done ✓")
			await _ide_instance.challenge_completed

	_completed_students.append(_current_student_idx)
	_active_questions = []
	if _character_data:
		_character_data.student_seq_completed_indices = _completed_students.duplicate()

	# Award credits
	var student_data = _student_challenges[_current_student_idx]
	var is_miniboss = student_data.get("is_miniboss", false)
	var credits = StudentChallengeData.CREDITS_MINIBOSS if is_miniboss else StudentChallengeData.CREDITS_PER_STUDENT
	if _character_data:
		_character_data.add_credits(credits)
		_character_data.student_seq_progress[_prof_key] = _completed_students.size()

	student_defeated.emit(_current_student_idx, _prof_key)

	# Remove the student NPC's quest marker
	if _current_student_idx < _active_npc_nodes.size():
		var npc = _active_npc_nodes[_current_student_idx]
		if npc and is_instance_valid(npc):
			# Mark as completed visually (remove exclamation, change label)
			if npc.has_method("set_passive_label"):
				npc.set_passive_label("✓ Done")
			elif npc.get_node_or_null("Label"):
				npc.get_node("Label").text = "✓ Done"

	_close_ide()

	# Check if all 5 students are done
	if _completed_students.size() >= _student_challenges.size():
		_on_sequence_completed()
	else:
		# Update quest to point to remaining students
		_update_quest_hud()

	await get_tree().process_frame
	_show_success_dialogue()

func _show_defeat_dialogue() -> void:
	var sname = get_student_name(_current_student_idx)
	var lines = [
		{ "name": sname, "text": "Aww, too bad! The code still isn't working right." },
		{ "name": sname, "text": "Maybe we can try again next time? Take a break!" }
	]
	
	# Freeze player during dialogue
	var players = get_tree().get_nodes_in_group("player")
	var player = players[0] if players.size() > 0 else null
	if player:
		player.can_move = false
		player.can_interact = false
	
	var dialogue_box = _get_dialogue_box()
	if dialogue_box:
		dialogue_box.start(lines)
		await dialogue_box.dialogue_finished

	if player:
		player.can_move = true
		player.can_interact = true

func _show_success_dialogue() -> void:
	var sname = get_student_name(_current_student_idx)
	var lines = [
		{ "name": sname, "text": "Whoa, it works perfectly now! Thank you so much!" },
		{ "name": "You", "text": "No problem! Good luck with your project." }
	]
	
	# Freeze player during dialogue
	var players = get_tree().get_nodes_in_group("player")
	var player = players[0] if players.size() > 0 else null
	if player:
		player.can_move = false
		player.can_interact = false
	
	var dialogue_box = _get_dialogue_box()
	if dialogue_box:
		dialogue_box.start(lines)
		await dialogue_box.dialogue_finished

	if player:
		player.can_move = true
		player.can_interact = true

func _on_sequence_completed() -> void:
	_active = false
	print("StudentQuizController: All students completed for professor %s!" % _prof_key)

	if _character_data:
		_character_data.student_seq_active_professor = ""
		_character_data.student_seq_active_npcs = []
		_character_data.student_seq_miniboss_npc = ""
		_character_data.student_seq_names = []
		_character_data.student_seq_completed_indices = []
		_character_data.student_seq_progress[_prof_key] = _student_challenges.size()

	# Unwire NPCs
	for npc in _active_npc_nodes:
		if npc and is_instance_valid(npc):
			if npc.has_meta("lesson_controller"):
				npc.remove_meta("lesson_controller")

	student_sequence_completed.emit(_prof_key)

# ─── IDE Lifecycle ───────────────────────────────────────────────────────────

func _close_ide() -> void:
	if _ide_canvas and is_instance_valid(_ide_canvas):
		_ide_canvas.visible = false
	if _ide_instance and is_instance_valid(_ide_instance):
		_ide_instance.visible = false
		# Disconnect signals to avoid double-fire
		if _ide_instance.challenge_completed.is_connected(_on_challenge_completed):
			_ide_instance.challenge_completed.disconnect(_on_challenge_completed)
		if _ide_instance.challenge_failed.is_connected(_on_challenge_failed):
			_ide_instance.challenge_failed.disconnect(_on_challenge_failed)
	get_tree().paused = false

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_scene_music"):
		audio_manager.play_scene_music()

func _build_attempt_questions(student_data: Dictionary) -> Array:
	var questions = student_data.get("questions", []).duplicate(true)
	if not student_data.get("is_miniboss", false) and questions.size() > 1:
		questions.shuffle()
	return questions

# ─── NPC Wiring ─────────────────────────────────────────────────────────────

func _wire_student_npcs() -> void:
	for i in range(_active_npc_nodes.size()):
		var npc = _active_npc_nodes[i]
		if npc == null or not is_instance_valid(npc):
			continue

		# Set meta so dialogue_interactable routes interaction to us
		npc.set_meta("lesson_controller", self)
		npc.set_meta("student_index", i)

		# Update the NPC's interaction label
		if npc.has_method("set_passive_label"):
			var sname = get_student_name(i)
			var is_miniboss = _student_challenges[i].get("is_miniboss", false) if i < _student_challenges.size() else false
			if is_miniboss:
				npc.set_passive_label("⭐ " + sname)
			else:
				npc.set_passive_label("❗ " + sname)

		# Set speaker name
		if npc.has_method("set") or "speaker_name" in npc:
			npc.speaker_name = get_student_name(i)

## Called by dialogue_interactable when student NPC is interacted with
## This matches the lesson_controller pattern: ctrl._on_professor_interacted()
func _on_professor_interacted() -> void:
	# Find which student was interacted with based on the calling NPC
	# The NPC sets meta "student_index" on itself
	var scene = get_tree().current_scene
	if scene == null:
		return

	# Get the player's nearest NPC
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0] as Node2D

	var closest_npc: Node = null
	var closest_dist := INF

	for npc in _active_npc_nodes:
		if npc == null or not is_instance_valid(npc):
			continue
		if not npc.has_meta("student_index"):
			continue
		var dist = player.global_position.distance_squared_to(npc.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_npc = npc

	if closest_npc and closest_npc.has_meta("student_index"):
		var idx = closest_npc.get_meta("student_index")
		on_student_interacted(idx)

# ─── Quest HUD ───────────────────────────────────────────────────────────────

func _update_quest_hud() -> void:
	if _quest_manager == null:
		return

	var remaining_count = _student_challenges.size() - _completed_students.size()
	if remaining_count <= 0:
		return

	# Collect target node names for arrows
	var targets: Array = []
	for i in range(_active_npc_nodes.size()):
		if i in _completed_students:
			continue
		var npc = _active_npc_nodes[i]
		if npc and is_instance_valid(npc):
			targets.append(npc.name)

	var quest_text = "Help %d classmates with their coding problems. (%d/%d)" % [
		remaining_count,
		_completed_students.size(),
		_student_challenges.size()
	]

	_quest_manager.set_quest(
		"ch2:student_app_%s" % _prof_key,
		quest_text,
		targets
	)
