#ch3_office_ground_floor-controller.gd
extends Node

@export_group("Chapter 6–8 Scene Design")
@export_node_path("CharacterBody2D") var player_path: NodePath = ^"YSortLayer/Player"
@export_node_path("Node2D") var kendra_path: NodePath = ^"YSortLayer/NPCKendraBarba"
@export_node_path("Area2D") var august_path: NodePath = ^"YSortLayer/NPCAugustCreed"
@export_node_path("Node2D") var ivana_path: NodePath = ^"YSortLayer/NPCIvanaDanielaGabani"
@export_node_path("Node2D") var hanna_path: NodePath = ^"YSortLayer/NPCHannaLuisaPaday"
@export_node_path("Node2D") var celestina_path: NodePath = ^"YSortLayer/NPCCelestinaBalon"
@export_node_path("Node2D") var alexa_path: NodePath = ^"YSortLayer/NPCAlexaApuyan"
@export_node_path("Node2D") var mario_path: NodePath = ^"YSortLayer/NPCMarioEllanCruz"
@export_node_path("Node2D") var mario_pacing_left_path: NodePath = ^"YSortLayer/MarioPacingLeftPoint"
@export_node_path("Node2D") var mario_pacing_right_path: NodePath = ^"YSortLayer/MarioPacingRightPoint"
@export_node_path("Node2D") var mario_sprint_door_path: NodePath = ^"YSortLayer/MarioSprintDoorPoint"
@export_node_path("Node2D") var mario_sprint_departure_path: NodePath = ^"YSortLayer/MarioSprintDeparturePoint"
@export_node_path("Node2D") var mario_sprint_inside_path: NodePath = ^"YSortLayer/MarioSprintInsidePoint"
@export_node_path("Node2D") var kenna_path: NodePath = ^"YSortLayer/NPCKennaLouisaArizobal"
@export_group("Chapter 7 QA Arrival")
@export var august_qa_checkin_start: Vector2 = Vector2(598.0, 70.0)
@export_node_path("Node2D") var qa_room_door_path: NodePath = ^"QASidewayRightGlassDoor1"
@export var august_qa_door_approach_position: Vector2 = Vector2(258.0, 70.0)
@export var august_qa_checkin_route: Array[Vector2] = [Vector2(78.0, 70.0)]
@export var august_qa_checkin_final_facing: String = "up"

@export_group("Chapter 9 Time-Skip Arrival")
@export_file("*.tscn") var ch9_arrival_scene_path: String = "res://Scenes/Ch3/Office Floors/main_office_3_floor_map_2nd_floor.tscn"
@export var ch9_arrival_position: Vector2 = Vector2(608.0, 8.0)

const DIALOGUE_BOX_SCENE := preload("res://Scenes/UI/dialogue_box.tscn")
const CHAT_BUBBLE_SCENE := preload("res://Scenes/UI/chat_bubble.tscn")
const INTERVIEW_CHOICE_SCENE := preload("res://Scenes/Ch3/interview_choice_panel.tscn")
const GETHUB_ISSUES_SCENE := preload("res://Scenes/UI/gethub_issues_ui.tscn")
const AUGUST_INTERVIEW_POSITION := Vector2(1077.0, -76.0)
const MEETING_ROOM_RETRY_POSITION := Vector2(944.0, 160.0)
const KENNA_SPRINT_ROOM_POSITION := Vector2(1140.0, -77.0)

signal interview_choice_selected(choice_index: int)
signal ticket_101_finished(success: bool, issue_number: int)

@onready var character_data: Node = get_node_or_null("/root/CharacterData")

var player: CharacterBody2D
var kendra: Node2D
var august: Area2D
var ivana: Node2D
var hanna: Node2D
var celestina: Node2D
var alexa: Node2D
var mario: Node2D
var mario_pacing_left: Node2D
var mario_pacing_right: Node2D
var mario_sprint_door_point: Node2D
var mario_sprint_departure_point: Node2D
var mario_sprint_inside_point: Node2D
var kenna: Node2D
var mario_default_position := Vector2.ZERO
var dialogue_box: CanvasLayer
var intro_layer: CanvasLayer
var intro_overlay: ColorRect
var scene_header: Label
var frame_placeholder: Label
var cutscene_camera: Camera2D
var interview_choice_ui: CanvasLayer
var sequence_running := false
var ch6_stage := 0 # 0: orientation; 1: visit locker; 2: report to QA
var ch7_stage := 0 # 0: ticket briefing; 1: trainee desk placeholder; 2: complete
var ch8_stage := 0 # 0: meet Mario; 1: enter sprint room; 2: complete
var ch6_equipment_collected := false
var ch7_ticket_placeholder_complete := false
var ch8_sprint_placeholder_complete := false
var ch6_role_intros_seen: Dictionary = {}
var locker_interactable: Area2D
var trainee_workstation: Area2D
var mario_pacing_enabled := false
var mario_pacing_tween: Tween
var ground_lead_roster_hidden := false
var kenna_visibility_initialized := false


func _ready() -> void:
	await get_tree().process_frame
	var scene_root := get_parent()
	player = scene_root.get_node_or_null(player_path) as CharacterBody2D
	kendra = scene_root.get_node_or_null(kendra_path) as Node2D
	if kendra == null:
		kendra = scene_root.get_node_or_null("YSortLayer/NPCFemaleOfficeReceptionist01") as Node2D
	august = scene_root.get_node_or_null(august_path) as Area2D
	ivana = scene_root.get_node_or_null(ivana_path) as Node2D
	hanna = scene_root.get_node_or_null(hanna_path) as Node2D
	celestina = scene_root.get_node_or_null(celestina_path) as Node2D
	alexa = scene_root.get_node_or_null(alexa_path) as Node2D
	mario = scene_root.get_node_or_null(mario_path) as Node2D
	mario_pacing_left = scene_root.get_node_or_null(mario_pacing_left_path) as Node2D
	mario_pacing_right = scene_root.get_node_or_null(mario_pacing_right_path) as Node2D
	mario_sprint_door_point = scene_root.get_node_or_null(mario_sprint_door_path) as Node2D
	mario_sprint_departure_point = scene_root.get_node_or_null(mario_sprint_departure_path) as Node2D
	mario_sprint_inside_point = scene_root.get_node_or_null(mario_sprint_inside_path) as Node2D
	kenna = scene_root.get_node_or_null(kenna_path) as Node2D
	if mario:
		mario_default_position = mario.global_position
	locker_interactable = scene_root.find_child("AnimatedLockerInteractable", true, false) as Area2D
	trainee_workstation = scene_root.find_child("WorkstationInteractable", true, false) as Area2D
	if locker_interactable:
		locker_interactable.set("item_id", "ojt_kit")
		locker_interactable.set("item_name", "Internship Kit")
		locker_interactable.set("item_description", "Your company intern uniform, OJT ID, laptop access, developer notebook, and internship checklist.")
		locker_interactable.set("auto_add_to_inventory", true)
		locker_interactable.set("is_locked", true)
		if locker_interactable.has_signal("locker_opened"):
			locker_interactable.connect("locker_opened", _on_locker_opened)
	if trainee_workstation:
		trainee_workstation.set("lock_message", "You don't have an active ticket assigned yet.")
		trainee_workstation.set("is_locked", true)
		if trainee_workstation.has_signal("workstation_used"):
			trainee_workstation.connect("workstation_used", _on_trainee_workstation_used)
	_create_dialogue_box(scene_root)
	_create_intro_overlay(scene_root)
	_create_interview_choice_ui(scene_root)
	_configure_kendra()
	_configure_interview_entry()
	_configure_chapter_narrative_npcs()
	_sync_inner_doors()
	_sync_mario_visibility()
	_sync_kenna_visibility()

	if character_data == null:
		return
	_restore_local_story_progress()
	_sync_ground_lead_roster()
	_sync_locker_availability()
	_sync_mario_visibility()
	_sync_kenna_visibility()
	if trainee_workstation:
		var workstation_available := ch7_stage == 1 and not sequence_running
		trainee_workstation.set("is_locked", not workstation_available)
		trainee_workstation.call("set_interaction_enabled", workstation_available)
	if ch8_stage >= 1 and mario and mario_sprint_inside_point:
		mario.global_position = mario_sprint_inside_point.global_position
		_set_mario_idle("left")
	if ch7_stage >= 2 and ch8_stage == 0 and mario:
		_start_mario_pacing()
	# The Ground Floor controller is loaded whenever the player uses the elevator.
	# Do not replace an active Chapter 9–14 objective with the day-one objective.
	if int(get_tree().root.get_meta("ch3_office_story_stage", 0)) >= 9:
		return
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager and _is_active_act3_quest(String(quest_manager.current_quest_id)):
		return
	if character_data.ch3_intro_cutscene_done:
		if character_data.ch3_interview_passed:
			if character_data.ch3_has_green_badge:
				_set_day1_followup_quest()
			else:
				_set_day1_quest()
		elif character_data.ch3_receptionist_talked:
			_set_meeting_room_quest()
		else:
			_set_reception_quest()
	else:
		call_deferred("_play_intro_cutscene")


func _process(_delta: float) -> void:
	_sync_ground_lead_roster()
	_sync_locker_availability()
	_sync_mario_visibility()
	_sync_kenna_visibility()
	if trainee_workstation:
		var workstation_available := ch7_stage == 1 and not sequence_running
		trainee_workstation.set("is_locked", not workstation_available)
		trainee_workstation.call("set_interaction_enabled", workstation_available)


func _sync_ground_lead_roster() -> void:
	var should_hide := int(get_tree().root.get_meta("ch3_office_story_stage", 0)) >= 10
	if should_hide == ground_lead_roster_hidden:
		return
	ground_lead_roster_hidden = should_hide
	for npc in [ivana, hanna, august]:
		if npc:
			npc.visible = not should_hide
			_set_ground_npc_tree_enabled(npc, not should_hide)


func _sync_kenna_visibility() -> void:
	if not is_instance_valid(kenna):
		return
	var story_stage := int(get_tree().root.get_meta("ch3_office_story_stage", 0))
	var should_show := ch7_stage >= 2 and ch8_stage < 2 and story_stage < 9
	if should_show:
		kenna.global_position = KENNA_SPRINT_ROOM_POSITION
		var sprite := kenna.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle_down"):
			sprite.play("idle_down")
	if kenna_visibility_initialized and kenna.visible == should_show:
		return
	kenna_visibility_initialized = true
	kenna.visible = should_show
	_set_ground_npc_tree_enabled(kenna, should_show)


func _set_ground_npc_tree_enabled(node: Node, enabled: bool) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		if not node.has_meta("ch3_ground_original_disabled"):
			node.set_meta("ch3_ground_original_disabled", node.disabled)
		node.set_deferred("disabled", bool(node.get_meta("ch3_ground_original_disabled")) if enabled else true)
	if node is CollisionObject2D:
		if not node.has_meta("ch3_ground_original_collision_layer"):
			node.set_meta("ch3_ground_original_collision_layer", node.collision_layer)
			node.set_meta("ch3_ground_original_collision_mask", node.collision_mask)
		node.collision_layer = int(node.get_meta("ch3_ground_original_collision_layer")) if enabled else 0
		node.collision_mask = int(node.get_meta("ch3_ground_original_collision_mask")) if enabled else 0
	if node is Area2D:
		if not node.has_meta("ch3_ground_original_monitoring"):
			node.set_meta("ch3_ground_original_monitoring", node.monitoring)
			node.set_meta("ch3_ground_original_monitorable", node.monitorable)
		node.monitoring = bool(node.get_meta("ch3_ground_original_monitoring")) if enabled else false
		node.monitorable = bool(node.get_meta("ch3_ground_original_monitorable")) if enabled else false
	for child in node.get_children():
		_set_ground_npc_tree_enabled(child, enabled)


func _sync_locker_availability() -> void:
	if locker_interactable:
		# The locker is usable only while the active objective is to collect the kit.
		# This is recalculated on every floor load and while the scene is active.
		var already_collected := ch6_stage >= 2
		locker_interactable.set("empty_text", "You already got the things inside.")
		locker_interactable.set("is_empty", already_collected)
		locker_interactable.set("is_locked", ch6_stage != 1 and not already_collected)


func _restore_local_story_progress() -> void:
	var root := get_tree().root
	ch6_stage = int(root.get_meta("ch3_ch6_stage", 0))
	ch7_stage = int(root.get_meta("ch3_ch7_stage", 0))
	ch8_stage = int(root.get_meta("ch3_ch8_stage", 0))
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager == null:
		return
	# QuestManager survives floor changes; use its active chapter objective as a
	# fallback when the player entered this sequence before stage metadata existed.
	match String(quest_manager.current_quest_id):
		"ch6:_meet_celestina":
			ch6_stage = maxi(ch6_stage, 2)
		"ch7:_review_ticket_101":
			ch6_stage = maxi(ch6_stage, 2)
			ch7_stage = maxi(ch7_stage, 1)
		"ch8:_meet_mario":
			ch6_stage = maxi(ch6_stage, 2)
			ch7_stage = maxi(ch7_stage, 2)
		"ch8:_sprint_meeting":
			ch6_stage = maxi(ch6_stage, 2)
			ch7_stage = maxi(ch7_stage, 2)
			ch8_stage = maxi(ch8_stage, 1)
	_persist_local_story_progress()


func _persist_local_story_progress() -> void:
	var root := get_tree().root
	root.set_meta("ch3_ch6_stage", ch6_stage)
	root.set_meta("ch3_ch7_stage", ch7_stage)
	root.set_meta("ch3_ch8_stage", ch8_stage)


func _is_active_act3_quest(quest_id: String) -> bool:
	for chapter in ["ch3:", "ch4:", "ch5:", "ch6:", "ch7:", "ch8:"]:
		if quest_id.begins_with(chapter):
			return true
	return false


func _create_dialogue_box(scene_root: Node) -> void:
	dialogue_box = scene_root.get_node_or_null("DialogueBox") as CanvasLayer
	if dialogue_box == null:
		dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as CanvasLayer
		dialogue_box.name = "DialogueBox"
		scene_root.add_child(dialogue_box)


func _create_intro_overlay(scene_root: Node) -> void:
	intro_layer = CanvasLayer.new()
	intro_layer.name = "Ch3IntroLayer"
	intro_layer.layer = 5
	scene_root.add_child(intro_layer)

	intro_overlay = ColorRect.new()
	intro_overlay.name = "PlaceholderCutscene"
	intro_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_overlay.color = Color(0.08, 0.1, 0.15, 0.95)
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_layer.add_child(intro_overlay)

	scene_header = Label.new()
	scene_header.name = "SceneHeader"
	scene_header.anchor_left = 0.08
	scene_header.anchor_top = 0.12
	scene_header.anchor_right = 0.92
	scene_header.anchor_bottom = 0.28
	scene_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scene_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_header.add_theme_font_size_override("font_size", 28)
	scene_header.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	intro_overlay.add_child(scene_header)

	frame_placeholder = Label.new()
	frame_placeholder.name = "VisualNovelFramePlaceholder"
	frame_placeholder.anchor_left = 0.1
	frame_placeholder.anchor_top = 0.3
	frame_placeholder.anchor_right = 0.9
	frame_placeholder.anchor_bottom = 0.67
	frame_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame_placeholder.add_theme_font_size_override("font_size", 22)
	frame_placeholder.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96))
	intro_overlay.add_child(frame_placeholder)
	intro_layer.visible = false


func _create_interview_choice_ui(scene_root: Node) -> void:
	interview_choice_ui = INTERVIEW_CHOICE_SCENE.instantiate() as CanvasLayer
	interview_choice_ui.name = "Ch4InterviewChoices"
	scene_root.add_child(interview_choice_ui)
	interview_choice_ui.connect("choice_selected", _on_interview_choice_selected)


func _play_intro_cutscene() -> void:
	if sequence_running or character_data == null or character_data.ch3_intro_cutscene_done:
		return
	sequence_running = true
	_set_room_indicator_visible(false)
	_set_quest_hud_visible(false)
	intro_layer.visible = true
	intro_overlay.color.a = 0.95
	if player:
		player.can_move = false

	var pname: String = character_data.player_name if (character_data and character_data.player_name != "") else "You"

	# CUT_01 — Chapter 1: The Faculty Send-Off (University office after defending thesis)
	await _play_frame("CUT_01", 1, "Chapter 1 — CUT_01: The Faculty Send-Off", "University faculty office at sunset. Dusty venetian blinds cast warm orange light across the thesis manuscript on the desk. Professor Markup leans back in his chair with a tired, proud sigh.", [
		{"name": "Professor Markup", "text": "Take a breath, anak. The panel just signed the final defense sheet. You passed."},
		{"name": pname, "text": "I... I can't believe it, sir. Four months of debugging that model... it feels surreal."},
		{"name": "Professor Markup", "text": "It's a milestone. Be proud of it. But the hardest part starts tomorrow."},
		{"name": pname, "text": "The OJT requirement?"},
	])
	await _play_frame("CUT_01", 2, "Chapter 1 — CUT_01: The Faculty Send-Off", "Professor Markup reaches across the cluttered desk, resting a hand gently on the thesis cover. His expression turns serious as he holds forward an official university endorsement envelope.", [
		{"name": "Professor Markup", "text": "In here is your official endorsement letter and your 300-hour checklist. In this faculty room, if your code threw an unhandled exception, we deducted five points and gave you partial credit. Out there, in the tech district... no one curves your grade."},
		{"name": "Professor Markup", "text": "If your backend leaks student records, real families get compromised. If your database crashes on exam day, thousands of students suffer."},
		{"name": "Professor Markup", "text": "I've seen top-of-the-class students get fired in their first week because they were too proud to ask questions. And I've seen average students get hired because they knew how to listen, admit mistakes, and read the documentation."}
	])
	await _play_frame("CUT_01", 3, "Chapter 1 — CUT_01: The Faculty Send-Off", "The player accepts the heavy envelope with trembling fingers as the adviser smiles warmly, gesturing toward the open door.", [
		{"name": pname, "text": "I'll remember that, sir. I won't let you down."},
		{"name": "Professor Markup", "text": "Go. Find a company that will challenge you. Go make our department proud."}
	])

	# CUT_02 — Chapter 2: Midnight Impostor Syndrome (Player's bedroom job hunt)
	await _play_frame("CUT_02", 1, "Chapter 2 — CUT_02: Midnight Impostor Syndrome", "Player's dark bedroom at 1:42 AM. Harsh blue monitor glow on tired face. Empty instant noodle cup, crossed-out company lists. Fingers typing rapidly, screen flickering, shoulders sagging in defeat.", [
		{"name": pname, "text": "Come on... please. Just one opening. Just one..."},
		{"name": "Company A (Automated)", "text": "Dear Applicant, Thank you for your interest. We regret to inform you that our quota for this academic term has already been filled."},
		{"name": "Company B (Automated)", "text": "Requirements for Junior Web Trainee: Must have 3+ years of commercial production experience in Django, React, AWS, and Docker container orchestration."},
		{"name": pname, "text": "Three years of commercial experience... for an unpaid internship? Where am I supposed to get that?!"}
	])
	await _play_frame("CUT_02", 2, "Chapter 2 — CUT_02: Midnight Impostor Syndrome", "A soft knock on the bedroom door. A warm slit of yellow light falls across the floor as a parent peeks in holding a glass of water.", [
		{"name": "Parent", "text": "Gising ka pa, anak? May nahanap ka na ba?"},
		{"name": pname, "text": "Wala pa po, Ma... Naghihintay pa ng callbacks. Baka bukas meron na."},
		{"name": "Parent", "text": "Naku, anak, alas dos na. Pahinga ka muna. Bukas mo na ulit tingnan, ha?"}
	])
	await _play_frame("CUT_02", 3, "Chapter 2 — CUT_02: Midnight Impostor Syndrome", "The door closes. The player stares at the glass of water, clutching their chest as impostor syndrome crushes in. Then a single new thread in the forum feed catches their eye.", [
		{"name": "Company D (Automated)", "text": "We have decided to move forward with candidates whose profiles more closely align with our immediate technical stack. We wish you the best in your future endeavors."},
		{"name": "Narration", "text": "Their family had sacrificed so much for tuition. The thought of letting them down settled in. What if no one gave them a chance?"},
		{"name": "Forum Post", "text": "DJQ Corp — Technical Solutions & Web Systems. Seeking OJT Web Trainee. 1 Slot."},
		{"name": pname, "text": "One shot. Please."}
	])

	# CUT_03 — Chapter 3: The Glass Tower Arrival (Lobby entrance)
	await _play_frame("CUT_03", 1, "Chapter 3 — CUT_03: The Glass Tower Arrival", "Exterior street view looking up at the towering glass and steel skyscraper of DJQ Corp. Sunlight reflects off the windows. DJQ CORP HEADQUARTERS — 8:15 AM. Player in borrowed collared shirt wiping sweaty palms on trousers, staring up in awe.", [
		{"name": "Narration", "text": "The glass tower stretches high into the morning sky. My borrowed leather shoes pinch my feet. My palms are soaked in cold sweat. This is it."}
	])
	await _play_frame("CUT_03", 2, "Chapter 3 — CUT_03: The Glass Tower Arrival", "Inside the Ground Floor lobby atrium. Towering glass ceilings, polished marble floors, corporate air-conditioning hum, faint phone rings, and commuters with lanyards crossing the lobby. The reception counter gleams straight ahead.", [
		{"name": "Narration", "text": "Polished marble. Glass turnstiles. Badge scanners. The lobby is already busy with people who seem to know exactly where they belong."},
		{"name": "Narration", "text": "Four years of late-night coding, thesis defense, and family sacrifices led to this building."}
	])
	await _play_frame("CUT_03", 3, "Chapter 3 — CUT_03: The Glass Tower Arrival", "The player pauses at the lobby entrance, takes one steadying breath, and looks toward the reception desk.", [
		{"name": "Narration", "text": "The application went out at one in the morning. They probably received a hundred. Still, the player made it here."},
		{"name": "Narration", "text": "One deep breath. There is an interview. The player belongs here."}
	])

	character_data.ch3_intro_cutscene_done = true
	await _fade_overlay_away()
	if player:
		player.can_move = true
	_set_reception_quest()
	_set_room_indicator_visible(true)
	_set_quest_hud_visible(true)
	sequence_running = false


func _play_frame(cutscene_id: String, frame_number: int, title: String, art_description: String, lines: Array) -> void:
	scene_header.text = title
	scene_header.modulate.a = 1.0
	frame_placeholder.text = "%s  •  FRAME %d / 3\n\n%s\n\n[Visual placeholder — replace with final cutscene art]" % [cutscene_id, frame_number, art_description]
	frame_placeholder.modulate.a = 1.0
	await get_tree().create_timer(0.35).timeout
	if dialogue_box:
		dialogue_box.start(lines)
		await dialogue_box.dialogue_finished
		# DialogueBox unfreezes the player when it closes; keep the cutscene locked.
		if player:
			player.can_move = false


func _fade_overlay_away() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(intro_overlay, "color:a", 0.0, 0.8).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(scene_header, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(frame_placeholder, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	intro_layer.visible = false


func _configure_kendra() -> void:
	if kendra == null:
		return
	kendra.set_meta("lesson_controller", self)
	if "speaker_name" in kendra:
		kendra.speaker_name = "Kendra Barba"


func _configure_interview_entry() -> void:
	if august:
		august.set_meta("lesson_controller", self)
		if character_data and character_data.ch3_interview_passed:
			august.remove_meta("interview_entry")
		else:
			august.set_meta("interview_entry", true)


func _configure_chapter_narrative_npcs() -> void:
	var roles := {
		"NPCKendraBarba": "kendra",
		"NPCAugustCreed": "august",
		"NPCIvanaDanielaGabani": "ivana",
		"NPCHannaLuisaPaday": "hanna",
		"NPCCelestinaBalon": "celestina",
		"NPCAlexaApuyan": "alexa",
		"NPCMarioEllanCruz": "mario",
		"NPCKennaLouisaArizobal": "kenna"
	}
	for npc_name in roles:
		var npc := get_parent().get_node_or_null("YSortLayer/" + npc_name)
		if npc:
			npc.add_to_group("office_npcs")
			npc.set_meta("lesson_controller", self)
			npc.set_meta("ch3_narrative_role", roles[npc_name])


func _on_ch3_narrative_interacted(npc: Node2D) -> void:
	if sequence_running or character_data == null or npc == null:
		return
	var role := String(npc.get_meta("ch3_narrative_role", ""))
	var total_visit_number := _track_npc_total_visit(npc)
	var repeat_context := _ground_repeat_context()
	_track_npc_context_visit(npc, repeat_context)
	if npc == mario and ch8_stage == 0:
		_stop_mario_pacing()
	if role == "kendra" and bool(get_tree().root.get_meta("ch3_graduation_return", false)):
		await _run_graduation_return_conversation(npc)
		return
	if not character_data.ch3_interview_passed or (not character_data.ch3_has_green_badge and not character_data.ch3_has_blue_badge):
		if npc == kendra:
			await _on_professor_interacted()
		else:
			await _play_unassigned_npc_dialogue(npc, total_visit_number)
		return
	if npc == mario:
		_face_npc_toward_player(mario)

	match role:
		"kendra":
			if int(get_tree().root.get_meta("ch3_office_story_stage", 0)) < 9:
				await _on_kendra_day_one_followup()
			else:
				await _play_unassigned_npc_dialogue(npc, total_visit_number)
		"august":
			var coffee_delivered := await _try_deliver_august_coffee(npc)
			if coffee_delivered:
				return
			if ch6_stage == 0:
				await _run_ch6_orientation()
			elif ch6_stage == 1 or ch6_stage == 11:
				await _run_story_bubble(npc, [
					{"name": "August Creed", "text": "Your orientation kit is in the Locker Room."},
					{"name": "August Creed", "text": "Once you have it, meet Celestina in QA & Design."}
				])
			elif ch6_stage == 2 and ch7_stage == 0:
				await _run_story_bubble(npc, [
					{"name": "August Creed", "text": "Celestina is expecting you in QA & Design."},
					{"name": "August Creed", "text": "She has your first onboarding ticket."}
				])
			elif ch7_stage == 2 and ch8_stage == 0:
				await _run_story_bubble(npc, [
					{"name": "August Creed", "text": "Mario, our client representative, has arrived."},
					{"name": "August Creed", "text": "Speak with him in the hallway, then join us in the Sprint / Meeting Room."}
				])
			elif ch8_stage == 1:
				await _run_ch8_sprint_meeting()
			elif ch8_stage >= 2:
				if character_data.ch3_has_blue_badge:
					await _run_story_bubble(npc, [
						{"name": "August Creed", "text": "Look at you with the blue badge — congratulations, junior developer."},
						{"name": "August Creed", "text": "You earned that desk on Floor 2. Come find me if you have questions."}
					])
				else:
					await _run_story_bubble(npc, [
						{"name": "August Creed", "text": "Good work in the sprint meeting."},
						{"name": "August Creed", "text": "Next, the team will turn that plan into supervised development tasks."}
					])
		"ivana":
			await _run_orientation_role_intro(npc, "ivana")
		"hanna":
			await _run_orientation_role_intro(npc, "hanna")
		"alexa":
			await _run_orientation_role_intro(npc, "alexa")
		"celestina":
			if ch6_stage == 1 or ch6_stage == 11:
				await _run_orientation_role_intro(npc, "celestina")
			elif ch6_stage == 2 and ch7_stage == 0:
				await _run_ch7_ticket_briefing()
			elif ch7_stage == 1 or ch7_stage == 11:
				await _run_story_bubble(npc, [
					{"name": "Celestina Balon", "text": "Your trainee workstation is ready."},
					{"name": "Celestina Balon", "text": "Open GetHub and review Ticket #101 there."}
				])
			elif ch7_stage >= 2:
				if character_data.ch3_has_blue_badge:
					await _run_story_bubble(npc, [
						{"name": "Celestina Balon", "text": "The intern who fixed Ticket #101 is now a junior web developer."},
						{"name": "Celestina Balon", "text": "I need sharp eyes on the team. Good to have you official."}
					])
				else:
					await _run_story_bubble(npc, [
						{"name": "Celestina Balon", "text": "I have sent your verified onboarding update to August."},
						{"name": "Celestina Balon", "text": "We will build on this during supervised development."}
					])
		"mario":
			if ch7_stage >= 2 and ch8_stage == 0:
				await _run_ch8_client_handoff()
			else:
				await _run_orientation_role_intro(npc, "mario")
		"kenna":
			await _run_story_bubble(npc, [
				{"name": "Kenna Louisa Arizobal", "text": "Hey there! Ready for the sprint meeting?"},
				{"name": "Kenna Louisa Arizobal", "text": "Grab a snack if you need energy. We're about to map out the whole portal."}
			])
		_:
			await _play_unassigned_npc_dialogue(npc, total_visit_number)


func _ground_repeat_context() -> String:
	var quest_manager := get_node_or_null("/root/QuestManager")
	var quest_id := String(quest_manager.current_quest_id) if quest_manager else ""
	return "%s|%d|%d|%d" % [quest_id, ch6_stage, ch7_stage, ch8_stage]


func _track_npc_context_visit(npc: Node, context: String) -> int:
	var root := get_tree().root
	var visit_counts: Dictionary = root.get_meta("ch3_npc_context_visit_counts", {})
	var key := "%s|%s" % [context, npc.name]
	var visit_number := int(visit_counts.get(key, 0)) + 1
	visit_counts[key] = visit_number
	root.set_meta("ch3_npc_context_visit_counts", visit_counts)
	return visit_number


func _track_npc_total_visit(npc: Node) -> int:
	var root := get_tree().root
	var visit_counts: Dictionary = root.get_meta("ch3_npc_total_visit_counts", {})
	var visit_number := int(visit_counts.get(npc.name, 0)) + 1
	visit_counts[npc.name] = visit_number
	root.set_meta("ch3_npc_total_visit_counts", visit_counts)
	return visit_number


func _play_npc_repeat(npc: Node2D, visit_number: int) -> void:
	var lines: Array = npc.call("get_repeat_dialogue_lines", visit_number) if npc.has_method("get_repeat_dialogue_lines") else []
	if lines.is_empty():
		await _play_npc_initial(npc)
		return
	await _run_story_bubble(npc, lines)


func _play_npc_initial(npc: Node2D) -> void:
	var lines: Array = npc.call("get_initial_dialogue_lines") if npc.has_method("get_initial_dialogue_lines") else []
	if lines.is_empty():
		return
	await _run_story_bubble(npc, lines)


func _play_unassigned_npc_dialogue(npc: Node2D, total_visit_number: int) -> void:
	if npc == mario:
		_face_npc_toward_player(mario)
	if total_visit_number > 1:
		await _play_npc_repeat(npc, total_visit_number)
	else:
		await _play_npc_initial(npc)


func _run_story_bubble(npc: Node2D, lines: Array) -> void:
	sequence_running = true
	_set_quest_hud_visible(false)
	if player:
		player.can_move = false
	await _play_bubble(npc, lines)
	await _offer_optional_npc_choice(npc)
	sequence_running = false
	_set_room_indicator_visible(true)
	_set_quest_hud_visible(true)
	if player:
		player.can_move = true


func _try_deliver_august_coffee(npc: Node2D) -> bool:
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory == null or not get_tree().root.get_meta("ch3_coffee_run_available", false) or not inventory.has_item("hot_coffee") or get_tree().root.get_meta("ch3_coffee_run_done", false):
		return false
	inventory.remove_item("hot_coffee", 1)
	get_tree().root.set_meta("ch3_coffee_run_available", false)
	get_tree().root.set_meta("ch3_coffee_run_done", true)
	await _run_story_bubble(npc, [
		{"name": "August Creed", "text": "You brought me coffee?"},
		{"name": "August Creed", "text": "You're a lifesaver."},
		{"name": "August Creed", "text": "Thanks, kid."},
		{"name": "August Creed", "text": "A tip for Ivana's architecture reviews."},
		{"name": "August Creed", "text": "Explain why the foreign key belongs on the child model."},
		{"name": "August Creed", "text": "She wants to hear the reasoning, not just the syntax."}
	])
	return true


func _run_ch6_orientation() -> void:
	sequence_running = true
	_set_quest_hud_visible(false)
	if player:
		player.can_move = false
	await _play_bubble(august, [
		{"name": "August Creed", "text": "Welcome to DJQ Corp."},
		{"name": "August Creed", "text": "Our team is building a Student Learning Portal for a client."},
		{"name": "August Creed", "text": "Students will log in, join classrooms, and follow their progress."},
		{"name": "August Creed", "text": "They will also receive feedback from teachers."},
		{"name": "August Creed", "text": "You will meet the people behind each part."},
		{"name": "August Creed", "text": "Hanna designs the system, and Celestina leads QA."},
		{"name": "August Creed", "text": "Alexa coordinates product details."},
		{"name": "August Creed", "text": "Our developers and DevOps team will join you as the work expands."}
	])
	await _offer_optional_npc_choice(august)
	await _play_bubble(ivana, [
		{"name": "Ivana Daniela Gabani", "text": "You are here to learn, but you will not learn by watching us do everything."},
		{"name": "Ivana Daniela Gabani", "text": "You will take real tickets and explain your technical choices."},
		{"name": "Ivana Daniela Gabani", "text": "Ask questions when you need help."},
		{"name": "Ivana Daniela Gabani", "text": "Before coding, understand the request."},
		{"name": "Ivana Daniela Gabani", "text": "Then consider how your change affects the rest of the system."}
	])
	await _offer_optional_npc_choice(ivana)
	await _play_bubble(august, [
		{"name": "August Creed", "text": "First, head to the Locker Room for your OJT ID and laptop access."},
		{"name": "August Creed", "text": "Your developer notebook and internship checklist are there too."},
		{"name": "August Creed", "text": "Then meet Celestina in QA & Design."}
	])
	await _offer_optional_npc_choice(august)
	ch6_stage = 1
	_persist_local_story_progress()
	_sync_locker_availability()
	_set_story_quest("ch6:_collect_ojt_kit", "Go to the Locker Room and search your assigned locker ([F] Search Locker).", "AnimatedLockerInteractable")
	sequence_running = false
	_set_room_indicator_visible(true)
	_set_quest_hud_visible(true)
	if player:
		player.can_move = true


func _run_orientation_role_intro(npc: Node2D, role: String) -> void:
	if ch6_stage == 0:
		if role == "august":
			await _run_story_bubble(npc, [{"name": npc.speaker_name if "speaker_name" in npc else npc.name, "text": "August and Ivana are gathering the new intern in the Sprint / Meeting Room."}])
		else:
			await _play_npc_initial(npc)
		return
	if ch6_role_intros_seen.get(role, false):
		await _run_story_bubble(npc, [
			{"name": npc.speaker_name if "speaker_name" in npc else npc.name, "text": "Glad to have you with the team."},
			{"name": npc.speaker_name if "speaker_name" in npc else npc.name, "text": "August can point you to your next orientation step."}
		])
		return
	ch6_role_intros_seen[role] = true
	var lines: Array = []
	match role:
		"ivana":
			lines = [
				{"name": "Ivana Daniela Gabani", "text": "I lead the team and mentor the OJT trainees."},
				{"name": "Ivana Daniela Gabani", "text": "Bring questions early, and be ready to explain why you chose an approach."}
			]
		"hanna":
			lines = [
				{"name": "Hanna Luisa Paday", "text": "I handle system design."},
				{"name": "Hanna Luisa Paday", "text": "If you ever want to see why flowcharts save projects, come find me."}
			]
		"celestina":
			lines = [
				{"name": "Celestina Balon", "text": "I lead QA."},
				{"name": "Celestina Balon", "text": "We reproduce reported problems and record evidence."},
				{"name": "Celestina Balon", "text": "Then we verify fixes instead of guessing."}
			]
		"alexa":
			lines = [
				{"name": "Alexa Apuyan", "text": "Welcome! I coordinate product usability."},
				{"name": "Alexa Apuyan", "text": "Don't worry, we don't bite—except Celestina before coffee."}
			]
		"mario":
			lines = [
				{"name": "Mario Ellan Cruz", "text": "Client rep here."},
				{"name": "Mario Ellan Cruz", "text": "Just hoping this portal launches on time so my clients stop calling me at 6 AM!"}
			]
	await _run_story_bubble(npc, lines)


func _run_locker_room_placeholder() -> void:
	sequence_running = true
	_set_room_indicator_visible(false)
	_set_quest_hud_visible(false)
	if player:
		player.can_move = false
	if locker_interactable:
		locker_interactable.set("is_locked", true)
	await _show_gameplay_placeholder(
		"Chapter 6 — Orientation Kit",
		"Gameplay Placeholder\nCollect your OJT ID, laptop access, developer notebook, and internship checklist. Change into the company intern uniform and straighten your collar in the locker mirror.\n\nFull equipment gameplay will be added later."
	)
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory and not inventory.has_item("ojt_kit"):
		var item_popup := get_node_or_null("/root/ItemPopup")
		if item_popup and item_popup.has_method("show_item"):
			await item_popup.show_item(
				"ojt_kit",
				"Internship Kit",
				"Your OJT ID, laptop access, developer notebook, and internship checklist."
			)
	await _play_bubble(player, [
		{"name": "You", "text": "No more test simulations. I'm a web developer now."}
	])
	ch6_equipment_collected = true
	ch6_stage = 2
	_persist_local_story_progress()
	_sync_locker_availability()
	_set_story_quest("ch6:_meet_celestina", "Report to Celestina in the QA & Design Room.", "NPCCelestinaBalon")
	sequence_running = false
	_set_room_indicator_visible(true)
	_set_quest_hud_visible(true)
	if player:
		player.can_move = true


func _run_ch7_ticket_briefing() -> void:
	sequence_running = true
	_set_quest_hud_visible(false)
	if player:
		player.can_move = false
	await _play_bubble(celestina, [
		{"name": "Celestina Balon", "text": "Welcome to QA & Design."},
		{"name": "Celestina Balon", "text": "August told me about your interview."},
		{"name": "Celestina Balon", "text": "Your first onboarding issue is GetHub Ticket #101."},
		{"name": "Celestina Balon", "text": "The Student Learning Portal dashboard breaks on narrow mobile screens."},
		{"name": "Celestina Balon", "text": "The ticket has reproduction notes and a screenshot."},
		{"name": "Celestina Balon", "text": "Review those before changing anything."},
		{"name": "Celestina Balon", "text": "Your trainee workstation is marked nearby."},
		{"name": "Celestina Balon", "text": "Open GetHub there, reproduce the issue in the mobile preview, then make a targeted fix in the IDE."},
		{"name": "Celestina Balon", "text": "Submit it to QA only after the dashboard cards wrap cleanly at mobile width."}
	])
	ch7_stage = 1
	_persist_local_story_progress()
	_set_story_quest("ch7:_review_ticket_101", "Go to the Trainee Desk in QA & Design and review Ticket #101.", "WorkstationInteractable")
	sequence_running = false
	_set_room_indicator_visible(true)
	_set_quest_hud_visible(true)
	if player:
		player.can_move = true


func _run_ticket_101_placeholder() -> void:
	sequence_running = true
	if trainee_workstation:
		trainee_workstation.set("is_locked", true)
		trainee_workstation.call("set_interaction_enabled", false)
	_set_room_indicator_visible(false)
	_set_quest_hud_visible(false)
	if player:
		player.can_move = false
	if dialogue_box:
		dialogue_box.start([
			{"name": "Celestina Balon", "text": "Before you start, read the reproduction notes and inspect the narrow-screen evidence."},
			{"name": "Celestina Balon", "text": "Keep the existing layout intact and use the ticket's mentor hint if you need a nudge."}
		])
		await dialogue_box.dialogue_finished
		if player:
			player.can_move = false
	var gethub_ui := GETHUB_ISSUES_SCENE.instantiate()
	gethub_ui.connect("finished", Callable(self, "_on_ticket_101_ui_finished"))
	get_parent().add_child(gethub_ui)
	var ticket_result: Array = await ticket_101_finished
	var ticket_succeeded: bool = not ticket_result.is_empty() and bool(ticket_result[0])
	if not ticket_succeeded:
		ch7_stage = 1
		_persist_local_story_progress()
		sequence_running = false
		_set_room_indicator_visible(true)
		_set_quest_hud_visible(true)
		if player:
			player.can_move = true
		if trainee_workstation:
			trainee_workstation.set("is_locked", false)
			trainee_workstation.call("set_interaction_enabled", true)
		return
	ch7_ticket_placeholder_complete = true
	await _play_bubble(celestina, [
		{"name": "Celestina Balon", "text": "Wait. You didn't rewrite the navbar?"},
		{"name": "Celestina Balon", "text": "You just applied a targeted flex-wrap rule?"},
		{"name": "Celestina Balon", "text": "Huh... August actually sent me a web developer."},
		{"name": "Celestina Balon", "text": "Ticket verified."}
	])
	await _offer_optional_npc_choice(celestina)
	ch7_stage = 2
	_persist_local_story_progress()
	_sync_kenna_visibility()
	await _stage_august_for_desk_checkin()
	await _play_bubble(august, [
		{"name": "August Creed", "text": "Celestina just messaged the general channel that you fixed a ticket with zero regressions!"},
		{"name": "August Creed", "text": "Do you know how hard it is to get her to say something nice?"},
		{"name": "August Creed", "text": "You're doing incredible, kid. Don't forget to drink water."},
		{"name": "August Creed", "text": "When you're ready, join us in the Sprint Room—our client rep is arriving."}
	])
	await _offer_optional_npc_choice(august)
	await _return_august_to_meeting_room()
	_set_story_quest("ch8:_meet_mario", "Meet Mario in the hallway outside the Sprint Room.", "NPCMarioEllanCruz")
	sequence_running = false
	_set_room_indicator_visible(true)
	_set_quest_hud_visible(true)
	if player:
		player.can_move = true
	if trainee_workstation:
		trainee_workstation.set("is_locked", ch7_stage != 1)


func _on_ticket_101_ui_finished(success: bool, issue_number: int) -> void:
	ticket_101_finished.emit(success, issue_number)


func _on_locker_opened(_item_id: String) -> void:
	if sequence_running or ch6_stage != 1:
		return
	ch6_stage = 11
	_persist_local_story_progress()
	call_deferred("_run_locker_room_placeholder")


func _start_mario_pacing() -> void:
	if mario_pacing_enabled or mario == null or not character_data.ch3_has_green_badge or mario_pacing_left == null or mario_pacing_right == null:
		return
	mario_pacing_enabled = true
	call_deferred("_pace_mario_in_hallway")


func _sync_mario_visibility() -> void:
	if not is_instance_valid(mario):
		return
	var should_be_available: bool = character_data != null and (character_data.ch3_has_green_badge or character_data.ch3_has_blue_badge)
	mario.visible = should_be_available
	var mario_area := mario as Area2D
	if mario_area:
		mario_area.monitoring = should_be_available
		mario_area.monitorable = should_be_available
	for collision_node in mario.find_children("*", "CollisionShape2D", true, false):
		var shape := collision_node as CollisionShape2D
		if shape:
			shape.set_deferred("disabled", not should_be_available)


func _stop_mario_pacing() -> void:
	mario_pacing_enabled = false
	if mario_pacing_tween and mario_pacing_tween.is_valid():
		mario_pacing_tween.kill()
	_set_mario_idle()


func _pace_mario_in_hallway() -> void:
	while mario_pacing_enabled and is_instance_valid(mario):
		if sequence_running:
			await get_tree().process_frame
			continue
		var destination := mario_pacing_right.global_position if mario.global_position.distance_squared_to(mario_pacing_left.global_position) < mario.global_position.distance_squared_to(mario_pacing_right.global_position) else mario_pacing_left.global_position
		await _walk_mario_to(destination)
		if mario_pacing_enabled:
			await get_tree().create_timer(0.25).timeout


func _walk_mario_to(destination: Vector2) -> void:
	if mario == null:
		return
	var offset := destination - mario.global_position
	var direction := "right" if offset.x >= 0.0 else "left"
	if absf(offset.y) > absf(offset.x):
		direction = "down" if offset.y >= 0.0 else "up"
	var sprite := mario.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("walking_" + direction):
		sprite.play("walking_" + direction)
	var duration := maxf(0.2, mario.global_position.distance_to(destination) / 70.0)
	mario_pacing_tween = mario.create_tween()
	mario_pacing_tween.tween_property(mario, "global_position", destination, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await mario_pacing_tween.finished
	_set_mario_idle(direction)


func _set_mario_idle(direction: String = "") -> void:
	if mario == null:
		return
	var sprite := mario.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	if direction.is_empty():
		direction = "left" if str(sprite.animation).ends_with("left") else "right"
	var idle_animation := "idle_" + direction
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(idle_animation):
		sprite.play(idle_animation)


func _walk_mario_into_sprint_room() -> void:
	_stop_mario_pacing()
	if mario == null or mario_sprint_door_point == null or mario_sprint_inside_point == null:
		return
	if mario.global_position.distance_squared_to(mario_default_position) > 1.0:
		await _walk_mario_to(mario_default_position)
	if mario_sprint_departure_point:
		await _walk_mario_to(mario_sprint_departure_point.global_position)
	await _walk_mario_to(mario_sprint_door_point.global_position)
	var door := get_parent().get_node_or_null("SprintRoomSidewayRightDoor2")
	if door:
		while bool(door.get("is_animating")):
			await get_tree().process_frame
		if not bool(door.get("is_door_open")):
			door.call("interact")
			while bool(door.get("is_animating")):
				await get_tree().process_frame
	await _walk_mario_to(mario_sprint_inside_point.global_position)


func _offer_optional_npc_choice(npc: Node2D) -> void:
	if npc == null or not npc.has_method("get_optional_choice_data"):
		return
	var choice_data: Dictionary = npc.call("get_optional_choice_data")
	var completed_choices: Dictionary = get_tree().root.get_meta("ch3_optional_npc_choices", {})
	if choice_data.is_empty() or bool(completed_choices.get(npc.name, false)) or dialogue_box == null:
		return
	var was_sequence_running := sequence_running
	var was_player_movable: bool = bool(player.get("can_move")) if player else true
	sequence_running = true
	if player:
		player.can_move = false
	completed_choices[npc.name] = true
	get_tree().root.set_meta("ch3_optional_npc_choices", completed_choices)
	dialogue_box.start([{
		"name": str(choice_data.get("speaker", npc.name)),
		"text": str(choice_data.get("prompt", "")),
		"choices": [str(choice_data.get("choice_a", "Yes")), str(choice_data.get("choice_b", "No"))]
	}])
	var selected: int = await dialogue_box.choice_selected
	await dialogue_box.dialogue_finished
	if player:
		player.can_move = false
	var reply_key := "reply_a" if selected == 0 else "reply_b"
	var reply := str(choice_data.get(reply_key, ""))
	if not reply.is_empty():
		await _play_bubble(npc, [{"name": str(choice_data.get("speaker", npc.name)), "text": reply}])
	sequence_running = was_sequence_running
	if player:
		player.can_move = was_player_movable


func _on_trainee_workstation_used(workstation_id: String) -> void:
	if sequence_running or workstation_id != "trainee_desk" or ch7_stage != 1:
		return
	ch7_stage = 11
	if trainee_workstation:
		trainee_workstation.call("set_interaction_enabled", false)
	_persist_local_story_progress()
	call_deferred("_run_ticket_101_placeholder")


func _stage_august_for_desk_checkin() -> void:
	if august == null:
		return
	august.global_position = august_qa_checkin_start
	var august_collision_layer := august.collision_layer
	august.collision_layer = 0
	await _walk_august_to(august_qa_door_approach_position)
	var qa_door := get_parent().get_node_or_null(qa_room_door_path)
	if qa_door and not qa_door.is_door_open:
		var door_sprite := qa_door.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if qa_door.is_animating and door_sprite:
			await door_sprite.animation_looped
		if not qa_door.is_door_open and not qa_door.is_animating:
			qa_door.interact()
			while qa_door.is_animating and door_sprite:
				await door_sprite.animation_looped
	for waypoint_index in august_qa_checkin_route.size():
		var waypoint: Vector2 = august_qa_checkin_route[waypoint_index]
		await _walk_august_to(waypoint)
	_set_august_facing(august_qa_checkin_final_facing)
	# August is temporarily non-interactable while walking through the QA doorway.
	# Restore his original Area2D layer so the player can talk to him afterward.
	if is_instance_valid(august):
		august.collision_layer = august_collision_layer


func _return_august_to_meeting_room() -> void:
	if august == null:
		return
	var august_collision_layer := august.collision_layer
	august.collision_layer = 0
	await _walk_august_to(august_qa_checkin_start)
	august.global_position = AUGUST_INTERVIEW_POSITION
	if is_instance_valid(august):
		august.collision_layer = august_collision_layer
	_set_august_facing("down")


func _run_ch8_client_handoff() -> void:
	sequence_running = true
	_set_quest_hud_visible(false)
	if player:
		player.can_move = false
	_face_npc_toward_player(mario)
	await _play_bubble(mario, [
		{"name": "Mario Ellan Cruz", "text": "Thanks for joining the project."},
		{"name": "Mario Ellan Cruz", "text": "Teachers need a way to view progress reports for the students in their classrooms."},
		{"name": "Mario Ellan Cruz", "text": "Please bring that request to the Sprint / Meeting Room."},
		{"name": "Mario Ellan Cruz", "text": "The team can clarify the requirements together."}
	])
	await _offer_optional_npc_choice(mario)
	await _walk_mario_into_sprint_room()
	ch8_stage = 1
	_persist_local_story_progress()
	if august and august.global_position != AUGUST_INTERVIEW_POSITION:
		august.global_position = AUGUST_INTERVIEW_POSITION
		august.collision_layer = 1
		_set_august_facing("down")
	_set_story_quest("ch8:_sprint_meeting", "Ground Floor — Enter the Sprint / Meeting Room and speak with August to plan the teacher reports feature.", "NPCAugustCreed", "Ground Floor")
	sequence_running = false
	_set_room_indicator_visible(true)
	_set_quest_hud_visible(true)
	if player:
		player.can_move = true


func _run_ch8_sprint_meeting() -> void:
	sequence_running = true
	_sync_kenna_visibility()
	_set_room_indicator_visible(false)
	_set_quest_hud_visible(false)
	if player:
		player.can_move = false
	intro_layer.visible = true
	intro_overlay.color.a = 0.96
	scene_header.visible = true
	frame_placeholder.visible = true
	scene_header.modulate.a = 1.0
	frame_placeholder.modulate.a = 1.0
	scene_header.text = "Chapter 8 — Sprint Planning"
	frame_placeholder.text = "DJQ Corp • Student Learning Portal\nSprint Conference Room • Client Request: Teacher Progress Reports"
	if dialogue_box:
		dialogue_box.start([
			{"name": "Mario Ellan Cruz", "text": "The school division heads are demanding progress reports by next week! If we don't show working progress charts, they'll freeze our deployment grant!"},
			{"name": "Abel Abendaño", "text": "Mario, I can't build the teacher report cards if I don't know what fields the backend returns! I need mock data! Give me an endpoint or give me peace!"},
			{"name": "Kenna Louisa Arizobal", "text": "If you build on mock data, you'll guess the field names wrong and we'll spend forty hours refactoring when my endpoints land! Be patient, Abel!"},
			{"name": "You", "text": "Excuse me... Abel is right, but so is Kenna."},
			{"name": "You", "text": "The frontend progress-card work depends on the backend roster endpoint. Kenna needs to define the serializer schema first—specifying teacher_name and progress_percentage."},
			{"name": "You", "text": "Once that contract is locked in GetHub, Abel can build against the exact structure without guessing."},
			{"name": "Kenna Louisa Arizobal", "text": "Agreed. I'll publish those response fields with the endpoint details today."},
			{"name": "Abel Abendaño", "text": "Perfect! Then I can build against the real contract instead of mocking data."},
			{"name": "Ivana Daniela Gabani", "text": "The intern just saved this team an entire week of wasted refactoring. Kenna, write the serializer contract today. Abel, hold frontend development until the contract is merged. Meeting adjourned."},
			{"name": "August Creed", "text": "That wraps up Day 1 orientation, kid! You survived Ivana's grilling and saved sprint planning. Go home, celebrate with your family, and get some rest. Next Monday, your real sprint rotation begins upstairs on Floor 2 with Kenna and Abel."}
		])
		await dialogue_box.dialogue_finished
	if player:
		player.can_move = false
	var fade := create_tween().set_parallel(true)
	fade.tween_property(intro_overlay, "color:a", 0.0, 0.45)
	fade.tween_property(scene_header, "modulate:a", 0.0, 0.45)
	fade.tween_property(frame_placeholder, "modulate:a", 0.0, 0.45)
	await fade.finished
	intro_layer.visible = false
	await _show_time_skip_card(
		"WEEKS 2 TO 7 — THE OJT SPRINT ROTATION",
		"120 / 300 HOURS LOGGED",
		"Weeks 2 through 7 fill with morning standups, workstation and hardware setup, minor IT troubleshooting, broken-link fixes, test cases, small styling and validation tickets, and sprint retrospectives. Across those six weeks, you close about a dozen small issues from the off-screen #102–#150 queue and learn the team's codebase and routines. Today is different: Kenna has assigned Ticket #151, your first major backend feature and reverse-lookup challenge.",
		true,
		func():
			# Advance stage and remove Kenna from the 1st floor Sprint Room under total darkness.
			ch8_sprint_placeholder_complete = true
			ch8_stage = 2
			_persist_local_story_progress()
			get_tree().root.set_meta("ch3_office_story_stage", 9)
			_sync_kenna_visibility()
	)
	_set_story_quest("ch9:_supervised_development", "Week 7 of OJT: Meet Kenna in the Backend Room on Floor 2.", "NPCKennaLouisaArizobal", "2nd Floor")
	sequence_running = false
	if player:
		player.can_move = false
	var scene_transition := get_node_or_null("/root/SceneTransition")
	if scene_transition and not ch9_arrival_scene_path.is_empty():
		get_tree().root.set_meta("ch3_restore_walk_hud_after_transition", true)
		scene_transition.call("transition_to_scene", ch9_arrival_scene_path, ch9_arrival_position, "none")
	else:
		_set_room_indicator_visible(true)
		_set_quest_hud_visible(true)


func _show_time_skip_card(title: String, hours_or_role: String, description: String, hold_dark_overlay_for_transition: bool = false, on_black: Callable = Callable()) -> void:
	# The calling story sequence already hides the HUD. Do not increment the
	# QuestManager hide depth a second time; its matching show call happens when
	# the sequence finishes and must be able to restore the quest and arrow.
	_set_room_indicator_visible(false)
	if player:
		player.can_move = false
	var previous_overlay_color := intro_overlay.color
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	intro_layer.visible = true
	intro_overlay.color = Color(0.015, 0.02, 0.035, 0.0)
	scene_header.visible = true
	frame_placeholder.visible = true
	scene_header.text = title
	frame_placeholder.text = "%s\n\n%s\n\n[Press Space to continue]" % [hours_or_role, description]
	scene_header.modulate.a = 0.0
	frame_placeholder.modulate.a = 0.0
	await get_tree().process_frame
	var fade_to_black := create_tween()
	fade_to_black.tween_property(intro_overlay, "color:a", 1.0, 1.5)
	await fade_to_black.finished
	if on_black.is_valid():
		on_black.call()
	var fade_card_in := create_tween().set_parallel(true)
	fade_card_in.tween_property(scene_header, "modulate:a", 1.0, 0.35)
	fade_card_in.tween_property(frame_placeholder, "modulate:a", 1.0, 0.35)
	await fade_card_in.finished
	while not Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	var fade_card_out := create_tween().set_parallel(true)
	fade_card_out.tween_property(scene_header, "modulate:a", 0.0, 0.4)
	fade_card_out.tween_property(frame_placeholder, "modulate:a", 0.0, 0.4)
	if not hold_dark_overlay_for_transition:
		fade_card_out.tween_property(intro_overlay, "color:a", 0.0, 0.4)
	await fade_card_out.finished
	if hold_dark_overlay_for_transition:
		return
	intro_layer.visible = false
	intro_overlay.color = previous_overlay_color
	scene_header.modulate.a = 1.0
	frame_placeholder.modulate.a = 1.0


func _run_graduation_return_conversation(npc: Node2D) -> void:
	await _run_story_bubble(npc, [
		{"name": "Kendra Barba", "text": "Hey, graduate! Congratulations on passing college!"},
		{"name": "Kendra Barba", "text": "Before you turn in your green badge, don't leave yet—Ivana asked to see you in her corner office on Floor 3 immediately."},
		{"name": "You", "text": "Ma'am Ivana wants to see me? Did I forget to file an exit document?"},
		{"name": "Kendra Barba", "text": "Just go upstairs, web developer."},
		{"name": "Kendra Barba", "text": "Take the elevator."}
	])
	get_tree().root.set_meta("ch3_graduation_return", false)
	_set_story_quest("ch11_absorption", "Report to Ivana's Office before surrendering your badge.", "NPCIvanaDanielaGabani", "3rd Floor")


func _show_gameplay_placeholder(title: String, description: String) -> void:
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	var overlay_was_visible := intro_layer.visible
	intro_layer.visible = true
	scene_header.visible = true
	frame_placeholder.visible = true
	if overlay_was_visible:
		var text_out := create_tween().set_parallel(true)
		text_out.tween_property(scene_header, "modulate:a", 0.0, 0.2)
		text_out.tween_property(frame_placeholder, "modulate:a", 0.0, 0.2)
		await text_out.finished
	else:
		intro_overlay.color.a = 0.0
		scene_header.modulate.a = 0.0
		frame_placeholder.modulate.a = 0.0
	scene_header.text = title
	frame_placeholder.text = description + "\n\n[Press Space to continue]"
	var text_in := create_tween().set_parallel(true)
	if not overlay_was_visible:
		text_in.tween_property(intro_overlay, "color:a", 0.96, 0.3)
	text_in.tween_property(scene_header, "modulate:a", 1.0, 0.3)
	text_in.tween_property(frame_placeholder, "modulate:a", 1.0, 0.3)
	await text_in.finished
	while not Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(intro_overlay, "color:a", 0.0, 0.3)
	fade_out.tween_property(scene_header, "modulate:a", 0.0, 0.3)
	fade_out.tween_property(frame_placeholder, "modulate:a", 0.0, 0.3)
	await fade_out.finished
	intro_layer.visible = false


func _set_story_quest(quest_id: String, description: String, target_name: String, floor_name: String = "Ground Floor") -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager:
		quest_manager.set_quest(quest_id, "%s — %s" % [floor_name, description], target_name, floor_name)
		quest_manager.set_tracked_quest(quest_id)


func _on_kendra_day_one_followup() -> void:
	sequence_running = true
	_set_quest_hud_visible(false)
	if player:
		player.can_move = false
	if not character_data.ch3_has_green_badge:
		await _welcome_player_on_day_one()
	else:
		var next_lines: Array = [
			{"name": "Kendra Barba", "text": "Orientation is underway."},
				{"name": "Kendra Barba", "text": "August and Ivana are in the Sprint / Meeting Room."},
				{"name": "Kendra Barba", "text": "After their briefing, collect your OJT kit in the Locker Room."}
		]
		if ch6_stage == 2:
			next_lines = [
				{"name": "Kendra Barba", "text": "Your OJT kit is ready."},
				{"name": "Kendra Barba", "text": "Celestina is waiting for you in QA & Design."}
			]
		elif ch7_stage >= 2:
			next_lines = [
				{"name": "Kendra Barba", "text": "Your first onboarding task is reviewed."},
				{"name": "Kendra Barba", "text": "Mario is in the hallway with the team's next project request."}
			]
		if character_data.ch3_has_blue_badge:
			next_lines = [
				{"name": "Kendra Barba", "text": "A junior web developer — still using the front entrance, I see."},
				{"name": "Kendra Barba", "text": "You could probably skip the check-in line now. Congratulations."}
			]
		await _play_bubble(kendra, next_lines)
		await _offer_optional_npc_choice(kendra)
	sequence_running = false
	_set_room_indicator_visible(true)
	_set_quest_hud_visible(true)
	if player:
		player.can_move = true


func _on_professor_interacted() -> void:
	if sequence_running or character_data == null or dialogue_box == null:
		return
	sequence_running = true
	_set_scene_interaction_lock(true)
	_set_quest_hud_visible(false)
	if character_data.ch3_interview_passed and not character_data.ch3_has_green_badge:
		await _welcome_player_on_day_one()
	elif not character_data.ch3_receptionist_talked:
		var pname: String = character_data.player_name if (character_data and character_data.player_name != "") else "You"
		if player:
			player.can_move = false

		# Reception is a top-down bubble conversation, not a visual-novel panel.
		await _play_bubble(kendra, [
			{"name": "Kendra Barba", "text": "Good morning. Welcome to DJQ Corporation. Guest, delivery, or interview?"},
			{"name": pname, "text": "Good morning, Ma'am. I’m an OJT applicant for the Web Developer internship."},
			{"name": pname, "text": "Here are my endorsement letter and school credentials."},
			{"name": "Kendra Barba", "text": "Let me check the department roster... Ah."},
			{"name": "Kendra Barba", "text": "I’m sorry, dear."},
			{"name": "Kendra Barba", "text": "All thirty internship slots for this cohort were locked as of 5:00 PM yesterday."},
			{"name": "Kendra Barba", "text": "We have zero openings."}
		])

		if august:
			await _stage_august_arrival()
			await _play_bubble(august, [
				{"name": "August Creed", "text": "Kendra! Stop the badge printing! Don't lock the system!"}
			])
			await _pan_camera_to_player()
			await _walk_august_to(Vector2(607.0, 168.0))
			await _open_inner_door_for_august()
			await _walk_august_to(Vector2(607.0, 242.0))
			await _close_inner_door_for_august()
			await _walk_august_to(Vector2(696.0, 242.0))
			await _walk_august_to(Vector2(696.0, 354.0), "down")
			_set_august_facing("left")
			if player:
				player.current_dir = "right"
				player.play_idle_animation("right")
			await _play_bubble(august, [
				{"name": "August Creed", "text": "The trainee assigned to the Student Learning Portal just backed out from the airport!"},
				{"name": "August Creed", "text": "Family got a visa to Canada!"},
				{"name": "August Creed", "text": "The project lead is going to skin me alive if we start this sprint down one developer!"}
			])
			await _play_bubble(kendra, [
				{"name": "Kendra Barba", "text": "August, the portal team's technical bar is impossible."},
				{"name": "Kendra Barba", "text": "Even senior computer science students fail the screening."}
			])
			await _play_bubble(august, [
				{"name": "August Creed", "text": "You. Can you write Python? Do you understand what happens when a browser reaches a web server?"}
			])
			await _ask_august_python_experience(pname)
			await _play_bubble(august, [
				{"name": "August Creed", "text": "Good enough for a shot. Kendra, give them a visitor pass."},
				{"name": "August Creed", "text": "Kid, follow me to Meeting Room 1."},
				{"name": "August Creed", "text": "Don't be nervous... well, be a little nervous."},
				{"name": "August Creed", "text": "The tech lead doesn't sugarcoat anything."}
			])
		else:
			# Keep the dialogue usable if the temporary August NPC has not been placed.
			await _play_bubble(kendra, [
				{"name": "August Creed", "text": "The trainee assigned to the Student Learning Portal just backed out from the airport!"},
				{"name": "August Creed", "text": "Family got a visa to Canada!"},
				{"name": "August Creed", "text": "The project lead is going to skin me alive if we start this sprint down one developer!"},
				{"name": "Kendra Barba", "text": "August, the portal team's technical bar is impossible."},
				{"name": "Kendra Barba", "text": "Even senior computer science students fail the screening."}
			])
			await _play_bubble(kendra, [{"name": "August Creed", "text": "Can you write Python? Do you understand what happens when a browser reaches a web server?"}])
			await _ask_august_python_experience(pname)
			await _play_bubble(kendra, [
				{"name": "August Creed", "text": "Good enough for a shot. Kendra, give them a visitor pass."},
				{"name": "August Creed", "text": "Kid, follow me to Meeting Room 1."},
				{"name": "August Creed", "text": "Don't be nervous... well, be a little nervous."},
				{"name": "August Creed", "text": "The tech lead doesn't sugarcoat anything."}
			])

		await _fade_and_reset_august()
		character_data.ch3_receptionist_talked = true
		_sync_inner_doors()
		_set_meeting_room_quest()
	else:
		await _play_bubble(kendra, [
			{"name": "Kendra Barba", "text": "The interview team is waiting for you in the Meeting Room."}
		])
	sequence_running = false
	_set_scene_interaction_lock(false)
	_set_room_indicator_visible(true)
	_set_quest_hud_visible(true)
	if player:
		player.can_move = true


func _on_interview_interacted() -> void:
	_start_interview()


func _ask_august_python_experience(player_name: String) -> void:
	if dialogue_box == null:
		return
	dialogue_box.start([{
		"name": "August Creed",
		"text": "Can you write Python, and do you understand what happens when a browser reaches a web server?",
		"choices": ["I've built with Python", "I'm still learning"]
	}])
	var selected: int = await dialogue_box.choice_selected
	await dialogue_box.dialogue_finished
	if player:
		player.can_move = false
	if selected == 0:
		await _play_bubble(player, [
			{"name": player_name, "text": "I built my thesis project with Django and PostgreSQL, sir."},
			{"name": player_name, "text": "I understand the request-response cycle, models, and REST APIs."}
		])
	else:
		await _play_bubble(player, [
			{"name": player_name, "text": "I'm still learning, sir, but I built my thesis project with Django and PostgreSQL."},
			{"name": player_name, "text": "I understand the basics and I'm ready to learn from the team."}
		])


func _ask_to_start_interview() -> int:
	if dialogue_box == null:
		return 1
	dialogue_box.start([{
		"name": "August Creed",
		"text": "Are you ready to start your OJT interview?",
		"choices": ["Yes, let's begin", "Not yet"]
	}])
	var choice: int = await dialogue_box.choice_selected
	await dialogue_box.dialogue_finished
	if player:
		player.can_move = false
	return choice


func _fade_into_interview_seat() -> void:
	intro_layer.visible = true
	# This layer is also used for the VN placeholders. Keep its old scene labels
	# hidden here so accepting the interview only produces a clean fade to black.
	scene_header.visible = false
	frame_placeholder.visible = false
	intro_overlay.color.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(intro_overlay, "color:a", 1.0, 0.4)
	await fade_in.finished
	_seat_player_for_interview()
	var fade_out := create_tween()
	fade_out.tween_property(intro_overlay, "color:a", 0.0, 0.5)
	await fade_out.finished
	intro_layer.visible = false
	scene_header.visible = true
	frame_placeholder.visible = true


func _start_interview() -> void:
	if sequence_running or character_data == null or not character_data.ch3_receptionist_talked:
		return
	if character_data.ch3_interview_passed:
		_set_quest_hud_visible(true)
		return
	sequence_running = true
	_set_scene_interaction_lock(true)
	_set_room_indicator_visible(false)
	_set_quest_hud_visible(false)
	if player:
		player.can_move = false
	var start_choice := await _ask_to_start_interview()
	if start_choice != 0:
		sequence_running = false
		_set_scene_interaction_lock(false)
		_set_room_indicator_visible(true)
		_set_quest_hud_visible(true)
		if player:
			player.can_move = true
		return
	await _fade_into_interview_seat()
	intro_layer.visible = true
	intro_overlay.color.a = 0.95
	await _play_frame("CUT_04A", 1, "Chapter 4 — The Boardroom Panel", "Chilled corporate boardroom. Long conference table under fluorescent lights. Hanna Luisa Paday sits on the left tapping her fountain pen on a system diagram. Ivana Daniela Gabani sits in the center, peering over wire-rimmed reading glasses. August Creed sits on the right with a warm, encouraging nod.", [
		{"name": "August Creed", "text": "Take a breath. The panel is ready."}
	])
	await _play_frame("CUT_04A", 2, "Chapter 4 — The Boardroom Panel", "Ivana Daniela Gabani rests her arms on the long mahogany table. Her gaze is sharp, piercing, and completely expressionless.", [
		{"name": "Ivana Daniela Gabani", "text": "You have five minutes. We build enterprise software for public schools. We do not babysit. Hanna, start."}
	])
	await _play_frame("CUT_04A", 3, "Chapter 4 — The Boardroom Panel", "Hanna Luisa Paday taps her sleek fountain pen rhythmically against the printed system diagram and looks up with cool, analytical eyes.", [
		{"name": "Hanna Luisa Paday", "text": "Question one. An intern joins our team and immediately opens their code editor, writing model classes without drawing a flowchart or entity-relationship schema first. Tell me why I shouldn't remove them from the project on day one."}
	])
	await _fade_overlay_away()

	var should_retry := true
	while should_retry:
		var score: int = await _run_interview_questions()
		if score >= 2:
			await _complete_interview_success()
			should_retry = false
		else:
			await _complete_interview_failure()
			var retry_choice := await _ask_retry_interview()
			if retry_choice == 0:
				_seat_player_for_interview()
				await _play_bubble(august, [
					{"name": "August Creed", "text": "Alright"},
					{"name": "August Creed", "text": "Let's begin."}
				])
			else:
				_stand_player_after_interview()
				_set_meeting_room_quest()
				should_retry = false

	sequence_running = false
	_set_scene_interaction_lock(false)
	_set_room_indicator_visible(true)
	_set_quest_hud_visible(true)
	if player:
		player.can_move = true


func _run_interview_questions() -> int:
	var architecture_choice := await _ask_interview_question(
		"Hanna Luisa Paday",
		"Question one. An intern joins our team and immediately opens their code editor, writing model classes without drawing a flowchart or entity-relationship schema first. Tell me why I shouldn't remove them from the project on day one.",
		[
			"Because coding without an architectural flowchart means you're building blind. You risk circular foreign key dependencies and corrupt migrations that cost weeks to untangle.",
			"Because writing code directly saves time, and we can fix bugs later during testing.",
			"Because flowcharts are just academic theory and real programmers don't need them."
		]
	)
	var architecture_good := architecture_choice == 0
	if architecture_good:
		await _play_bubble(_get_panel_npc("NPCHannaLuisaPaday"), [
			{"name": "Hanna Luisa Paday", "text": "...Correct. Code is just syntax; architecture is the foundation. Good."}
		])
	else:
		await _play_bubble(_get_panel_npc("NPCHannaLuisaPaday"), [
			{"name": "Hanna Luisa Paday", "text": "Wrong. Building without a flowchart creates circular foreign key dependencies and corrupt migrations. Never code blind."}
		])

	var privacy_choice := await _ask_interview_question(
		"Ivana Daniela Gabani",
		"Question two. We handle hundreds of schools. What stops a student user from opening their browser dev tools, modifying an API request payload, and viewing another student's disciplinary records or exam grades?",
		[
			"Client-side checks mean nothing. Every request must be validated on the server using request.user to verify that the requesting user owns the record before the database query executes.",
			"We disable right-click inspect element on the browser so students cannot see the API.",
			"We hide the student ID field in the HTML form using CSS display: none."
		]
	)
	var privacy_good := privacy_choice == 0
	if privacy_good:
		await _play_bubble(_get_panel_npc("NPCIvanaDanielaGabani"), [
			{"name": "Ivana Daniela Gabani", "text": "Basic data privacy discipline. Most graduates fail that. Client-side checks mean nothing; server-side authorization is non-negotiable."}
		])
	else:
		await _play_bubble(_get_panel_npc("NPCIvanaDanielaGabani"), [
			{"name": "Ivana Daniela Gabani", "text": "Disastrous answer. Hiding an element in CSS or blocking right-click does not stop an API payload tampering attack. The server must validate request.user."}
		])

	var accountability_choice := await _ask_interview_question(
		"August Creed",
		"Final question from me, kid. You're working late. You push a change to our staging server, and suddenly the login page dies with a 500 error right before a client demonstration. What is your immediate reaction?",
		[
			"I notify the team immediately. I don't hide the mistake or blame the pipeline. I reproduce the traceback locally, find the root cause, and roll back or apply the fix transparently.",
			"Blame the git merge conflict or claim the staging server environment was misconfigured.",
			"Quietly restart the server and hope nobody notices the downtime."
		]
	)
	var accountability_good := accountability_choice == 0
	if accountability_good:
		await _play_bubble(august, [
		{"name": "August Creed", "text": "Honesty before ego. That's what I wanted to hear. Good web developers own their mistakes."}
		])
	else:
		await _play_bubble(august, [
			{"name": "August Creed", "text": "Never hide downtime or blame the pipeline. Transparency and fast rollback are what protect our users."}
		])

	var score := int(architecture_good) + int(privacy_good) + int(accountability_good)
	await _play_bubble(_get_panel_npc("NPCIvanaDanielaGabani"), [
		{"name": "Ivana Daniela Gabani", "text": "Thank you for your time. We have several files to evaluate. You will receive our decision via email tonight."}
	])
	return score


func _ask_retry_interview() -> int:
	if dialogue_box == null:
		return 0
	dialogue_box.start([{
		"name": "Interview Evaluation",
		"text": "You did not pass this attempt. Review the feedback and try the interview again?",
		"choices": ["Yes, retry the interview", "Not right now"]
	}])
	var selected_index: int = await dialogue_box.choice_selected
	await dialogue_box.dialogue_finished
	if player:
		player.can_move = false
	return selected_index


func _ask_interview_question(speaker: String, question: String, choices: Array) -> int:
	if dialogue_box == null:
		return 1
	dialogue_box.start([{"name": speaker, "text": question}])
	await dialogue_box.dialogue_finished
	_show_interview_choices(choices, question)
	var selected_index: int = await interview_choice_selected
	_hide_interview_choices()
	if player:
		player.can_move = false
	return selected_index


func _show_interview_choices(choices: Array, question: String) -> void:
	if interview_choice_ui:
		interview_choice_ui.call("show_choices", choices, question)


func _on_interview_choice_selected(index: int) -> void:
	interview_choice_selected.emit(index)


func _hide_interview_choices() -> void:
	if interview_choice_ui and interview_choice_ui.has_method("hide_choices"):
		interview_choice_ui.hide_choices()


func _set_room_indicator_visible(value: bool) -> void:
	var indicator := get_parent().get_node_or_null("RoomIndicator")
	if indicator and indicator.has_method("set_indicator_visible"):
		indicator.set_indicator_visible(value)


func _set_quest_hud_visible(value: bool) -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager == null:
		return
	if value:
		quest_manager.show_quest()
	else:
		quest_manager.hide_quest()


func _set_scene_interaction_lock(locked: bool) -> void:
	var scene := get_tree().current_scene
	if scene:
		scene.set_meta("ch3_interactions_locked", locked)


func _seat_player_for_interview() -> void:
	if player == null:
		return
	var chair := get_parent().get_node_or_null("YSortLayer/OfficeChairFacingUp")
	if chair:
		var seat_offset: Vector2 = chair.seat_offset if "seat_offset" in chair else Vector2.ZERO
		player.global_position = chair.global_position + seat_offset
		if "is_occupied" in chair:
			chair.is_occupied = true
		if chair.has_method("_hide_label"):
			chair._hide_label()
	else:
		player.global_position = Vector2(1168.0, 52.0)
	player.can_move = false
	player.is_sitting = true
	player.current_dir = "up"
	player.play_sitting_animation("up")
	var shadow := player.get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false


func _stand_player_after_interview() -> void:
	if player == null:
		return
	var chair := get_parent().get_node_or_null("YSortLayer/OfficeChairFacingUp")
	if chair:
		var offset: Vector2 = chair.stand_offset if "stand_offset" in chair else Vector2(-32.0, 0.0)
		if offset == Vector2.ZERO:
			offset = Vector2(-32.0, 0.0)
		player.global_position = chair.global_position + offset
		chair.is_occupied = false
		if chair.has_method("_hide_label"):
			chair._hide_label()
	else:
		player.global_position = Vector2(1136.0, 60.0)
	player.is_sitting = false
	player.can_move = true
	player.current_dir = "left"
	player.play_idle_animation("left")
	var shadow := player.get_node_or_null("Shadow")
	if shadow:
		shadow.visible = true


func _get_panel_npc(node_name: String) -> Node2D:
	return get_parent().get_node_or_null("YSortLayer/" + node_name) as Node2D


func _complete_interview_failure() -> void:
	if player:
		player.can_move = false
	dialogue_box.start([{
		"name": "Interview Panel",
		"text": "Thank you for your time. We have multiple applicants to evaluate and will notify you via email."
	}])
	await dialogue_box.dialogue_finished
	if player:
		player.can_move = false
	await _show_interview_wait()
	await _show_interview_card(
		"Interview Result — You Did Not Pass",
		"The panel did not move forward this time. Review the feedback, then choose whether to retry.\n\nIdentified flaws:\n• Architecture was treated as optional.\n• Data privacy must be enforced by the backend, not only hidden in the interface.\n• Web developers must own errors, inspect logs, and communicate blockers."
	)
	_set_meeting_room_quest()


func _complete_interview_success() -> void:
	await _walk_august_to(Vector2(1010.0, -76.0))
	await _walk_august_to(Vector2(1010.0, 100.0))
	await _walk_august_to(Vector2(1138.0, 100.0))
	_set_august_facing("up")
	await _play_bubble(august, [
		{"name": "August Creed", "text": "Hey! Kid! Don't let Ivana's stone face scare you."},
		{"name": "August Creed", "text": "Between you and me... you basically got it."},
		{"name": "August Creed", "text": "In two years, I haven't seen Hanna stop tapping her pen like that."},
		{"name": "August Creed", "text": "Go home. Eat a good dinner with your parents, and check your inbox tonight!"}
	])
	character_data.ch3_interview_passed = true
	if august and august.has_meta("interview_entry"):
		august.remove_meta("interview_entry")
	await _play_acceptance_placeholder()
	await _transition_to_day_one()
	_set_day1_quest()


func _show_interview_card(title: String, body: String) -> void:
	intro_layer.visible = true
	intro_overlay.color.a = 0.96
	scene_header.text = title
	frame_placeholder.text = body + "\n\n[Press interact to continue]"
	await get_tree().process_frame
	if dialogue_box:
		dialogue_box.start([{"name": "Narration", "text": "Take a moment to reflect on the evaluation, then return to the Meeting Room and try again."}])
		await dialogue_box.dialogue_finished
	intro_layer.visible = false


func _show_interview_wait() -> void:
	intro_layer.visible = true
	intro_overlay.color.a = 0.96
	await _play_frame("CUT_04_FAIL", 1, "Player's Bedroom — The Wait", "The player waits beside the desk with the phone face down.", [
		{"name": "Narration", "text": "The interview is over. Now all you can do is wait."}
	])
	await _play_frame("CUT_04_FAIL", 2, "Player's Bedroom — The Wait", "The phone screen remains dark. No notification arrives.", [
		{"name": "Narration", "text": "Minutes become hours. There is no email buzz."}
	])
	await _play_frame("CUT_04_FAIL", 3, "Player's Bedroom — The Wait", "The player stares at the silent phone in the dim room.", [
		{"name": "You", "text": "Maybe I was not ready yet."}
	])


func _play_acceptance_placeholder() -> void:
	intro_layer.visible = true
	intro_overlay.color.a = 0.0
	var fade_to_cut := create_tween()
	fade_to_cut.tween_property(intro_overlay, "color:a", 1.0, 0.65).set_ease(Tween.EASE_IN_OUT)
	await fade_to_cut.finished
	# Move August only after the local fade fully covers the interview room.
	# This keeps the reset invisible before CUT_04B starts.
	if is_instance_valid(august):
		august.global_position = AUGUST_INTERVIEW_POSITION
		_set_august_facing("down")
	await _play_frame("CUT_04B", 1, "Chapter 4 — CUT_04B: Midnight Acceptance Email", "Player lies awake in bed in the dark bedroom at 11:42 PM. The silent smartphone rests on their chest.", [
		{"name": "Narration", "text": "11:42 PM. You stare at the dark ceiling, clutching your phone against your chest. Every second feels like an eternity."}
	])
	await _play_frame("CUT_04B", 2, "Chapter 4 — CUT_04B: Midnight Acceptance Email", "The smartphone vibrates with a sharp buzz. The screen illuminates the dark room with a glowing green notification banner from hr@djqcorp.com.", [
		{"name": "Notification (hr@djqcorp.com)", "text": "Subject: DJQ Corp — Technical OJT Offer (Student Learning Portal)\n\nDear Intern, We are pleased to formally accept you into our OJT Web Development Program. Report to Floor 1 Reception tomorrow at 8:00 AM."}
	])
	await _play_frame("CUT_04B", 3, "Chapter 4 — CUT_04B: Midnight Acceptance Email", "The player clutches the glowing phone tightly to their chest, burying their face in the pillow as tears of pure relief soak into the fabric.", [
		{"name": "You", "text": "I got it... I actually got it..."}
	])
	await _show_next_day_title_card()


func _show_next_day_title_card() -> void:
	var fade_text_out := create_tween().set_parallel(true)
	fade_text_out.tween_property(scene_header, "modulate:a", 0.0, 0.25)
	fade_text_out.tween_property(frame_placeholder, "modulate:a", 0.0, 0.25)
	await fade_text_out.finished
	scene_header.text = "The Next Day"
	frame_placeholder.text = "DJQ Corp — Ground Floor Lobby\nYour first day as a Web Development OJT intern begins."
	var fade_text_in := create_tween().set_parallel(true)
	fade_text_in.tween_property(scene_header, "modulate:a", 1.0, 0.35)
	fade_text_in.tween_property(frame_placeholder, "modulate:a", 1.0, 0.35)
	await fade_text_in.finished
	await get_tree().create_timer(1.4).timeout


func _transition_to_day_one() -> void:
	var transition := get_node_or_null("/root/SceneTransition")
	var fade_rect: ColorRect = transition.get_node_or_null("ColorRect") if transition else null
	intro_layer.visible = true
	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(intro_overlay, "color:a", 1.0, 0.5)
	fade_out.tween_property(scene_header, "modulate:a", 0.0, 0.5)
	fade_out.tween_property(frame_placeholder, "modulate:a", 0.0, 0.5)
	if fade_rect:
		fade_out.tween_property(fade_rect, "color:a", 1.0, 0.5)
	await fade_out.finished
	if player:
		var chair := get_parent().get_node_or_null("YSortLayer/OfficeChairFacingUp")
		if chair and "is_occupied" in chair:
			chair.is_occupied = false
		player.global_position = Vector2(605.0, 554.0)
		player.is_sitting = false
		player.can_move = false
		player.current_dir = "down"
		player.play_idle_animation("down")
		var shadow := player.get_node_or_null("Shadow")
		if shadow:
			shadow.visible = true
	_sync_inner_doors()
	var fade_in := create_tween().set_parallel(true)
	fade_in.tween_property(intro_overlay, "color:a", 0.0, 0.5)
	if fade_rect:
		fade_in.tween_property(fade_rect, "color:a", 0.0, 0.5)
	await fade_in.finished
	intro_layer.visible = false


func _welcome_player_on_day_one() -> void:
	if is_instance_valid(kendra):
		await _play_bubble(kendra, [
			{"name": "Kendra Barba", "text": "Look who's back! August told me you blew the roof off the boardroom yesterday!"},
			{"name": "Kendra Barba", "text": "Welcome to your first day, intern!"}
		])
		await _offer_optional_npc_choice(kendra)
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory and not inventory.has_item("green_ojt_badge"):
		var item_popup := get_node_or_null("/root/ItemPopup")
		if item_popup and item_popup.has_method("show_item"):
			await item_popup.show_item(
				"green_ojt_badge",
				"Green OJT Badge",
				"Grants access to Floor 1 Trainee Desks, QA & Design, and Sprint Meeting Room."
			)
	if is_instance_valid(kendra):
		await _play_bubble(kendra, [
			{"name": "Kendra Barba", "text": "Go ahead. Tap it against the sensor. You're officially one of us today."}
		])
	character_data.ch3_has_green_badge = true
	_sync_inner_doors()
	_set_day1_followup_quest()


func _set_acceptance_quest() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager:
		quest_manager.set_quest("ch4:_await_acceptance", "Wait for DJQ Corp's interview result at home.", "Player")


func _set_day1_quest() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager:
		quest_manager.set_quest("ch5:_day_one_welcome", "Ground Floor — Talk to Kendra at the reception desk to begin your first day.", "NPCKendraBarba", "Ground Floor")


func _set_day1_followup_quest() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager:
		quest_manager.set_quest("ch5:_day_one_orientation", "Proceed to the Sprint / Meeting Room for your first-day orientation.", "NPCAugustCreed", "Ground Floor")


func _play_bubble(npc: Node2D, lines: Array) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var bubble = npc.get_node_or_null("Ch3ChatBubble")
	if bubble == null:
		bubble = CHAT_BUBBLE_SCENE.instantiate()
		bubble.name = "Ch3ChatBubble"
		npc.add_child(bubble)
	_set_room_indicator_visible(false)
	bubble.start(lines)
	await bubble.dialogue_finished
	_set_room_indicator_visible(not sequence_running)
	if player:
		player.can_move = false


func _face_npc_toward_player(npc: Node2D) -> void:
	if npc == null or player == null:
		return
	var offset := player.global_position - npc.global_position
	var direction := "down"
	if absf(offset.x) > absf(offset.y):
		direction = "right" if offset.x > 0.0 else "left"
	else:
		direction = "down" if offset.y >= 0.0 else "up"
	var sprite := npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle_" + direction):
		sprite.play("idle_" + direction)


func _stage_august_arrival() -> void:
	if august == null:
		return
	august.visible = true
	august.global_position = Vector2(607.0, 49.0)
	# Prevent the moving cutscene character from accepting unrelated player input.
	august.collision_layer = 0
	await _create_cutscene_camera()


func _create_cutscene_camera() -> void:
	if cutscene_camera or player == null:
		return
	cutscene_camera = Camera2D.new()
	cutscene_camera.name = "AugustCutsceneCamera"
	var player_camera := player.get_node_or_null("Camera2D") as Camera2D
	if player_camera:
		cutscene_camera.zoom = player_camera.zoom
	get_parent().add_child(cutscene_camera)
	cutscene_camera.global_position = player_camera.global_position if player_camera else player.global_position
	cutscene_camera.make_current()
	var pan_to_august := create_tween()
	pan_to_august.tween_property(cutscene_camera, "global_position", august.global_position + Vector2(0.0, 80.0), 0.8).set_ease(Tween.EASE_IN_OUT)
	await pan_to_august.finished


func _pan_camera_to_player() -> void:
	if cutscene_camera == null or player == null:
		return
	var player_camera := player.get_node_or_null("Camera2D") as Camera2D
	var player_focus := player_camera.global_position if player_camera else player.global_position
	var pan_to_player := create_tween()
	pan_to_player.tween_property(cutscene_camera, "global_position", player_focus, 0.8).set_ease(Tween.EASE_IN_OUT)
	await pan_to_player.finished


func _walk_august_to(target: Vector2, facing_override: String = "") -> void:
	if august == null:
		return
	var movement := target - august.global_position
	var direction := facing_override
	if direction.is_empty():
		if absf(movement.x) > absf(movement.y):
			direction = "right" if movement.x >= 0.0 else "left"
		else:
			direction = "down" if movement.y >= 0.0 else "up"
	var sprite := august.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play("walking_" + direction)
	var duration := maxf(0.25, august.global_position.distance_to(target) / 145.0)
	var tween := create_tween()
	tween.tween_property(august, "global_position", target, duration).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	if sprite:
		sprite.play("idle_" + direction)


func _open_inner_door_for_august() -> void:
	var door = get_parent().get_node_or_null("YSortLayer/ReceptionistAndHallwaySlidingDoor")
	if door == null:
		return
	if door.has_method("set_badge_access_override"):
		door.set_badge_access_override(true)
	door.unlock()
	if door.is_door_open:
		return
	door.interact()
	var door_sprite := door.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	while door.is_animating and door_sprite:
		await door_sprite.animation_looped


func _close_inner_door_for_august() -> void:
	var door = get_parent().get_node_or_null("YSortLayer/ReceptionistAndHallwaySlidingDoor")
	if door == null:
		return
	if door.is_door_open:
		door.interact()
		var door_sprite := door.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		while door.is_animating and door_sprite:
			await door_sprite.animation_looped
	if door.has_method("set_badge_access_override"):
		door.set_badge_access_override(false)


func _set_august_facing(direction: String) -> void:
	if august == null:
		return
	var sprite := august.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play("idle_" + direction)


func _fade_and_reset_august() -> void:
	var transition := get_node_or_null("/root/SceneTransition")
	var fade_rect: ColorRect = transition.get_node_or_null("ColorRect") if transition else null
	if fade_rect:
		var fade_out := create_tween()
		fade_out.tween_property(fade_rect, "color:a", 1.0, 0.45)
		await fade_out.finished

	if august:
		august.global_position = AUGUST_INTERVIEW_POSITION
		august.visible = true
		august.collision_layer = 1
		var sprite := august.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			sprite.play("idle_down")
	if cutscene_camera:
		cutscene_camera.queue_free()
		cutscene_camera = null
	if player:
		var player_camera := player.get_node_or_null("Camera2D") as Camera2D
		if player_camera:
			player_camera.make_current()
			player_camera.force_update_scroll()
	if fade_rect:
		var fade_in := create_tween()
		fade_in.tween_property(fade_rect, "color:a", 0.0, 0.45)
		await fade_in.finished


func _set_reception_quest() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager:
		quest_manager.set_quest("ch3:_meet_kendra", "Ground Floor — Talk to Kendra at the Reception Desk.", "NPCKendraBarba", "Ground Floor")


func _set_meeting_room_quest() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager:
		quest_manager.set_quest("ch3:_ojt_interview", "Ground Floor — Proceed to the Meeting Room and speak with August Creed for your OJT interview.", "NPCAugustCreed", "Ground Floor")


func _sync_inner_doors() -> void:
	var scene_root := get_parent()
	# The receptionist/hallway door is the inner office threshold. Keep the
	# lobby entrance door usable so the player is never trapped outside.
	var inner_door := scene_root.get_node_or_null("YSortLayer/ReceptionistAndHallwaySlidingDoor")
	if inner_door == null:
		return
	var has_visitor_interview_access: bool = character_data != null and character_data.ch3_receptionist_talked and not character_data.ch3_interview_passed
	if character_data and (character_data.ch3_has_green_badge or character_data.ch3_has_blue_badge or has_visitor_interview_access):
		inner_door.unlock()
		inner_door.interaction_text = ""
	else:
		inner_door.lock()
		inner_door.lock_message = "Speak with Kendra first." if not character_data or not character_data.ch3_receptionist_talked else "Green OJT badge required."
		inner_door.interaction_text = inner_door.lock_message
	if inner_door.get_node_or_null("Label"):
		inner_door.get_node("Label").text = inner_door.interaction_text
