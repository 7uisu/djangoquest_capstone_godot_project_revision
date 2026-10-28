extends Node

signal accountability_choice_selected(choice_index: int)

const DIALOGUE_BOX_SCENE := preload("res://Scenes/UI/dialogue_box.tscn")
const CHAT_BUBBLE_SCENE := preload("res://Scenes/UI/chat_bubble.tscn")
const INTERVIEW_CHOICE_SCENE := preload("res://Scenes/Ch3/interview_choice_panel.tscn")
const GETHUB_ISSUES_SCENE := preload("res://Scenes/UI/gethub_issues_ui.tscn")
const GETHUB_PULL_REQUEST_SCENE := preload("res://Scenes/UI/gethub_pull_request_ui.tscn")
const SERVER_RACK_TERMINAL_SCENE := preload("res://Scenes/Interactables/server_rack_terminal_ui.tscn")

signal gethub_ticket_batch_finished(success: bool, issue_number: int)
signal pull_request_modal_result(approved: bool, pr_number: int, comment: String, dismissed: bool)
signal server_traceback_acknowledged
signal server_migration_requested
signal server_terminal_continued

@export_node_path("Node2D") var player_path: NodePath = ^"YSortLayer/Player"
@export_node_path("CanvasLayer") var dialogue_box_path: NodePath = ^"DialogueBox"
@export var placeholder_overlay_color := Color(0.055, 0.075, 0.12, 0.97)
@export_group("Story Transition Destinations")
@export_file("*.tscn") var ground_floor_scene_path := "res://Scenes/Ch3/main_office_3_floor_map.tscn"
@export var graduation_reception_spawn_position := Vector2(607.0, 554.0)
@export_file("*.tscn") var second_floor_scene_path := "res://Scenes/Ch3/Office Floors/main_office_3_floor_map_2nd_floor.tscn"
@export var reynalda_arrival_position := Vector2(-51.0, 70.0)
@export_group("Chapter 9 GetHub Ticket Batches")
@export var backend_ticket_batch: Array[Resource] = []
@export var frontend_ticket_batch: Array[Resource] = []

var player: CharacterBody2D
var dialogue_box: CanvasLayer
var overlay_layer: CanvasLayer
var overlay: ColorRect
var overlay_title: Label
var overlay_body: Label
var sequence_running := false
var server_rack: Area2D
var server_rack_terminal_ui: CanvasLayer
var coffee_machine: Area2D
var backend_workstation: Area2D
var frontend_workstation: Area2D
var accountability_choice_ui: CanvasLayer
var server_incident_phase := 0
var npc_roles := {
	"NPCKennaLouisaArizobal": "kenna",
	"NPCNathalieMilo": "nathalie",
	"NPCAbelAbendano": "abel",
	"NPCReynaldaPatalinghug": "reynalda",
	"NPCNorielaAsahan": "noriela",
	"NPCIvanaDanielaGabani": "ivana",
	"NPCAugustCreed": "august",
	"NPCHannaLuisaPaday": "hanna",
	"NPCDivinoCinaon": "divino",
	"NPCTercioMateoRamos": "tercio",
	"NPCJuliaRoa": "julia",
	"NPCMarioEllanCruz": "mario"
}


func _ready() -> void:
	# The floor controller is a scene child; wait for the root to finish adding
	# siblings before creating fallback UI nodes under it.
	await get_tree().process_frame
	var scene_root := get_parent()
	player = scene_root.get_node_or_null(player_path) as CharacterBody2D
	if player == null:
		player = scene_root.find_child("Player", true, false) as CharacterBody2D
	dialogue_box = scene_root.get_node_or_null(dialogue_box_path) as CanvasLayer
	if dialogue_box == null:
		dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as CanvasLayer
		dialogue_box.name = "DialogueBox"
		scene_root.add_child(dialogue_box)
	_create_placeholder_overlay(scene_root)
	_create_accountability_choice_ui(scene_root)
	_configure_scene_npcs(scene_root)
	_sync_lead_office_roster(scene_root)
	_sync_floor2_kenna_roster(scene_root)
	server_rack = scene_root.find_child("ServerRackInteractable", true, false) as Area2D
	if server_rack:
		server_rack_terminal_ui = SERVER_RACK_TERMINAL_SCENE.instantiate() as CanvasLayer
		scene_root.add_child(server_rack_terminal_ui)
		server_rack_terminal_ui.connect("traceback_acknowledged", _on_server_traceback_acknowledged)
		server_rack_terminal_ui.connect("migration_requested", _on_server_migration_requested)
		server_rack_terminal_ui.connect("terminal_continued", _on_server_terminal_continued)
	coffee_machine = scene_root.find_child("CoffeeMachineInteractable", true, false) as Area2D
	backend_workstation = scene_root.find_child("BackendWorkstation", true, false) as Area2D
	frontend_workstation = scene_root.find_child("FrontendWorkstation", true, false) as Area2D
	if server_rack and server_rack.has_signal("server_console_interacted"):
		server_rack.connect("server_console_interacted", _on_server_console_interacted)
	if coffee_machine and coffee_machine.has_signal("coffee_brewed"):
		coffee_machine.connect("coffee_brewed", _on_coffee_brewed)
	_configure_workstation(backend_workstation, "[F] Use Workstation")
	_configure_workstation(frontend_workstation, "[F] Use Workstation")
	if backend_workstation and backend_workstation.has_signal("workstation_used"):
		backend_workstation.connect("workstation_used", _on_backend_workstation_used)
	if frontend_workstation and frontend_workstation.has_signal("workstation_used"):
		frontend_workstation.connect("workstation_used", _on_frontend_workstation_used)
	server_incident_phase = int(get_tree().root.get_meta("ch3_server_incident_phase", 0))
	if bool(get_tree().root.get_meta("ch3_server_alert_started", false)) and server_rack:
		server_rack.call("trigger_emergency_state", true)
		if server_incident_phase > 0:
			server_rack.set("interaction_text", "[F] Run python manage.py migrate")
			var rack_label := server_rack.get_node_or_null("Label") as Label
			if rack_label:
				rack_label.text = "[F] Run python manage.py migrate"
	var quest_manager := get_node_or_null("/root/QuestManager")
	var restore_walk_hud_after_transition := bool(get_tree().root.get_meta("ch3_restore_walk_hud_after_transition", false))
	if quest_manager and not restore_walk_hud_after_transition:
		quest_manager.reset_suppression()
	_restore_stage_quest()
	if restore_walk_hud_after_transition:
		var room_indicator := scene_root.get_node_or_null("RoomIndicator")
		if room_indicator:
			room_indicator.visible = false
		if quest_manager:
			quest_manager.hide_quest()
		var scene_transition := get_node_or_null("/root/SceneTransition")
		if scene_transition and scene_transition.has_signal("scene_transition_finished"):
			await scene_transition.scene_transition_finished
		get_tree().root.set_meta("ch3_restore_walk_hud_after_transition", false)
		if room_indicator:
			room_indicator.visible = true
		if quest_manager:
			quest_manager.reset_suppression()


func _configure_scene_npcs(scene_root: Node) -> void:
	for npc_name: String in npc_roles:
		var npc := scene_root.find_child(npc_name, true, false)
		if npc:
			npc.add_to_group("office_npcs")
			npc.set_meta("lesson_controller", self)
			npc.set_meta("ch3_narrative_role", npc_roles[npc_name])


func _sync_lead_office_roster(scene_root: Node) -> void:
	# The Lead's Office is Ivana's private executive office on Floor 3.
	# She becomes present once Chapter 10 reaches the evaluation.
	# Earlier in the shared-building timeline she is assigned to the Ground Floor Sprint Room.
	var quest_manager := get_node_or_null("/root/QuestManager")
	var quest_id := String(quest_manager.current_quest_id) if quest_manager else ""
	var is_early_office_quest := quest_id.begins_with("ch6:") or quest_id.begins_with("ch7:") or quest_id.begins_with("ch8:") or quest_id.begins_with("ch9:")
	var ivana_is_active := _stage() >= 10 and not is_early_office_quest
	var ivana := scene_root.find_child("NPCIvanaDanielaGabani", true, false) as Node2D
	if ivana:
		ivana.visible = ivana_is_active
		_sync_npc_collision_tree(ivana, ivana_is_active)
	# August (Ground Floor HR) and Hanna (Floor 1/2) do not loiter in Ivana's private office.
	for non_lead_name: String in ["NPCAugustCreed", "NPCHannaLuisaPaday"]:
		var npc := scene_root.find_child(non_lead_name, true, false) as Node2D
		if npc:
			npc.visible = false
			_sync_npc_collision_tree(npc, false)
	# Mario joins the Executive Boardroom only during and after Ch13 (stage >= 13).
	# During Ch10–12 he is not a board attendee; hide him so he doesn't appear beforehand.
	var mario_f3 := scene_root.find_child("NPCMarioEllanCruz", true, false) as Node2D
	if mario_f3:
		var mario_boardroom_active := _stage() >= 13
		mario_f3.visible = mario_boardroom_active
		_sync_npc_collision_tree(mario_f3, mario_boardroom_active)


func _sync_floor2_kenna_roster(scene_root: Node) -> void:
	# Kenna appears in the Ground Floor sprint-room sequence first. Her Floor 2
	# instance becomes active only after the 120-hour time skip advances the story.
	var kenna := scene_root.find_child("NPCKennaLouisaArizobal", true, false) as Node2D
	if kenna == null:
		return
	var floor_2_assignment_active := _stage() >= 9
	kenna.visible = floor_2_assignment_active
	_sync_npc_collision_tree(kenna, floor_2_assignment_active)


func _sync_npc_collision_tree(node: Node, enabled: bool) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		if not node.has_meta("ch3_original_disabled"):
			node.set_meta("ch3_original_disabled", node.disabled)
		node.set_deferred("disabled", bool(node.get_meta("ch3_original_disabled")) if enabled else true)
	if node is CollisionObject2D:
		if not node.has_meta("ch3_original_collision_layer"):
			node.set_meta("ch3_original_collision_layer", node.collision_layer)
			node.set_meta("ch3_original_collision_mask", node.collision_mask)
		node.collision_layer = int(node.get_meta("ch3_original_collision_layer")) if enabled else 0
		node.collision_mask = int(node.get_meta("ch3_original_collision_mask")) if enabled else 0
	if node is Area2D:
		if not node.has_meta("ch3_original_monitoring"):
			node.set_meta("ch3_original_monitoring", node.monitoring)
			node.set_meta("ch3_original_monitorable", node.monitorable)
		node.monitoring = bool(node.get_meta("ch3_original_monitoring")) if enabled else false
		node.monitorable = bool(node.get_meta("ch3_original_monitorable")) if enabled else false
	for child in node.get_children():
		_sync_npc_collision_tree(child, enabled)


func _create_accountability_choice_ui(scene_root: Node) -> void:
	accountability_choice_ui = INTERVIEW_CHOICE_SCENE.instantiate() as CanvasLayer
	accountability_choice_ui.name = "AccountabilityChoicePanel"
	accountability_choice_ui.set("time_limit_seconds", 15.0)
	accountability_choice_ui.connect("choice_selected", _on_accountability_choice_selected)
	scene_root.add_child(accountability_choice_ui)


func _configure_workstation(workstation: Area2D, prompt: String) -> void:
	if workstation == null:
		return
	workstation.set("is_locked", true)
	workstation.call("set_interaction_enabled", false)
	workstation.set("lock_message", "You don't need to work on this computer right now.")
	workstation.set("interaction_text", prompt)


func _set_workstation_active(workstation: Area2D, active: bool) -> void:
	if workstation == null:
		return
	workstation.set("is_locked", not active)
	workstation.call("set_interaction_enabled", active)


func _create_placeholder_overlay(scene_root: Node) -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.name = "OfficeNarrativePlaceholderLayer"
	# Keep narrative cards above the quest HUD and ordinary UI, but below the
	# global scene-transition fade so scene changes can still cover the screen.
	overlay_layer.layer = 95
	scene_root.add_child(overlay_layer)
	overlay = ColorRect.new()
	overlay.name = "PlaceholderBackground"
	overlay.color = placeholder_overlay_color
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(overlay)
	overlay_title = Label.new()
	overlay_title.name = "BeatTitle"
	overlay_title.anchor_left = 0.08
	overlay_title.anchor_top = 0.12
	overlay_title.anchor_right = 0.92
	overlay_title.anchor_bottom = 0.28
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_title.add_theme_font_size_override("font_size", 28)
	overlay_title.add_theme_color_override("font_color", Color(0.91, 0.94, 1.0))
	overlay.add_child(overlay_title)
	overlay_body = Label.new()
	overlay_body.name = "BeatDescription"
	overlay_body.anchor_left = 0.12
	overlay_body.anchor_top = 0.3
	overlay_body.anchor_right = 0.88
	overlay_body.anchor_bottom = 0.72
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.add_theme_font_size_override("font_size", 21)
	overlay_body.add_theme_color_override("font_color", Color(0.8, 0.86, 0.97))
	overlay.add_child(overlay_body)
	overlay_layer.visible = false


func _stage() -> int:
	return int(get_tree().root.get_meta("ch3_office_story_stage", 0))


func _set_stage(value: int, quest_id: String, quest_text: String, target: String, floor_name: String = "") -> void:
	get_tree().root.set_meta("ch3_office_story_stage", value)
	if floor_name.is_empty():
		floor_name = _floor_for_stage(value)
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager:
		quest_manager.set_quest(quest_id, "%s — %s" % [floor_name, quest_text], target, floor_name)
		quest_manager.set_tracked_quest(quest_id)


func _floor_for_stage(stage: int) -> String:
	match stage:
		9, 91, 901, 911, 12, 14, 141, 15:
			return "2nd Floor"
		10, 11, 121, 122, 123, 13:
			return "3rd Floor"
	return "3rd Floor"


func _restore_stage_quest() -> void:
	var stage := _stage()
	_set_workstation_active(backend_workstation, false)
	_set_workstation_active(frontend_workstation, false)
	match stage:
		9:
			_set_stage(9, "ch9:_supervised_development", "Week 7 — meet Kenna in the Backend Room on Floor 2 to begin Ticket #151.", "NPCKennaLouisaArizobal", "2nd Floor")
		901:
			_set_workstation_active(backend_workstation, true)
			_set_stage(901, "ch9_backend_workstation", "Work with Kenna on Ticket #151 at the Backend Workstation ([F] Use Workstation).", "BackendWorkstation", "2nd Floor")
		91:
			_set_stage(91, "ch9_frontend_integration", "Tickets #151 and #152 are complete. Meet Abel on Floor 2 to review the frontend API contract for Ticket #153.", "NPCAbelAbendano", "2nd Floor")
		911:
			_set_workstation_active(frontend_workstation, true)
			_set_stage(911, "ch9_frontend_workstation", "Complete Ticket #153 at the Frontend Workstation beside Abel ([F] Use Workstation).", "FrontendWorkstation", "2nd Floor")
		10:
			_set_stage(10, "ch10_ojt_evaluation", "Go to the Lead's Office for your OJT evaluation.", "NPCIvanaDanielaGabani")
		11:
			if bool(get_tree().root.get_meta("ch3_graduation_return", false)):
				_set_stage(11, "ch11_absorption", "Report to Kendra at reception before surrendering your badge.", "NPCKendraBarba", "Ground Floor")
			else:
				_set_stage(11, "ch11_absorption", "Return to Ivana in the Lead's Office.", "NPCIvanaDanielaGabani")
		12:
			_set_stage(12, "ch12_sprint_planning", "Join Reynalda for the release planning meeting.", "NPCReynaldaPatalinghug")
		121:
			if not bool(get_tree().root.get_meta("ch3_server_alert_started", false)):
				_set_stage(121, "ch12_production_incident", "Report to Divino in the Server Room.", "NPCDivinoCinaon")
			elif not bool(get_tree().root.get_meta("ch3_divino_incident_briefed", false)):
				_set_stage(121, "ch12_production_incident", "Find Divino in the Server Room for incident triage.", "NPCDivinoCinaon")
			elif server_incident_phase == 0:
				_set_stage(121, "ch12_production_incident", "Access the primary console ([F] Triage Critical Error!).", "ServerRackInteractable")
			else:
				_set_stage(121, "ch12_production_incident", "Run python manage.py migrate at the primary console ([F]).", "ServerRackInteractable")
		122:
			_set_stage(122, "ch12_secrets_audit", "Go to IT Storage with Tercio for a configuration security check.", "NPCTercioMateoRamos")
		123:
			_set_stage(123, "ch12_code_review", "Meet Ivana in the Lead's Office to review a teammate's pull request.", "NPCIvanaDanielaGabani")
		13:
			_set_stage(13, "ch13_executive_presentation", "Present the completed Student Learning Portal to Julia Roa.", "NPCJuliaRoa")
		14:
			_set_stage(14, "ch14_conclusion", "Spend a moment with Noriela in the Break Room.", "NPCNorielaAsahan")
		141:
			_set_workstation_active(backend_workstation, true)
			if backend_workstation:
				backend_workstation.set("interaction_text", "[F] Open IDE & Start Workday")
			_set_stage(141, "ch14_workstation", "Sit at your permanent developer workstation on Floor 2 ([F] Open IDE).", "BackendWorkstation")
		15:
			_set_stage(15, "story_complete", "The office story arc is complete. Your next ticket is ready.", "Player")


func _on_ch3_narrative_interacted(npc: Node2D) -> void:
	if sequence_running or npc == null:
		return
	var role := String(npc.get_meta("ch3_narrative_role", ""))
	var current_stage := _stage()
	var total_visit_number := _track_npc_total_visit(npc)
	var alert_started := bool(get_tree().root.get_meta("ch3_server_alert_started", false))
	var has_active_story_beat := _has_late_story_beat(role, current_stage)
	if role == "divino" and current_stage == 121 and alert_started:
		if not bool(get_tree().root.get_meta("ch3_divino_incident_briefed", false)):
			sequence_running = true
			await _play_bubble(npc, [
				{"name": "Divino Cinaon", "text": "The login service is failing after the rollout."},
				{"name": "Divino Cinaon", "text": "Go to the primary rack and inspect the traceback first."},
				{"name": "Divino Cinaon", "text": "Then come back to the cause with me before we change production."}
			])
			get_tree().root.set_meta("ch3_divino_incident_briefed", true)
			_set_stage(121, "ch12_production_incident", "Access the primary console ([F] Triage Critical Error!).", "ServerRackInteractable")
			sequence_running = false
			_restore_walk_hud()
		else:
			await _play_npc_repeat(npc, total_visit_number)
		await _offer_optional_npc_choice(npc)
		return
	if not has_active_story_beat:
		if total_visit_number > 1:
			await _play_npc_repeat(npc, total_visit_number)
		else:
			await _play_npc_initial(npc)
		await _offer_optional_npc_choice(npc)
		return
	match _stage():
		9:
			if role == "kenna" or role == "nathalie":
				await _chapter_9_backend(npc)
		91:
			if role == "abel":
				await _chapter_9_frontend(npc)
		10:
			if role == "ivana":
				await _chapter_10_evaluation(npc)
		11:
			if role == "ivana":
				await _chapter_11_offer(npc)
		12:
			if role == "reynalda":
				await _chapter_12_sprint(npc)
		121:
			if role == "divino":
				await _chapter_12_incident(npc)
		122:
			if role == "tercio":
				await _chapter_12_secrets(npc)
		123:
			if role == "ivana":
				await _chapter_12_code_review(npc)
		13:
			if role == "julia":
				await _chapter_13_executive_meeting(npc)
		14:
			if role == "noriela":
				await _chapter_14_epilogue(npc)
			elif role == "mario":
				await _play_bubble(npc, [
					{"name": "Mario Ellan Cruz", "text": "That went better than I expected. You really saved us back there."},
					{"name": "Mario Ellan Cruz", "text": "The school division is excited for launch day."}
				])
			_restore_walk_hud()
		15:
			await _play_bubble(npc, [{"name": "Narration", "text": "The next ticket is ready. Your work as a developer continues."}])


func _has_late_story_beat(role: String, current_stage: int) -> bool:
	match current_stage:
		9:
			return role == "kenna" or role == "nathalie"
		91:
			return role == "abel"
		10, 11, 123:
			return role == "ivana"
		12:
			return role == "reynalda"
		121:
			return role == "divino"
		122:
			return role == "tercio"
		13:
			return role == "julia"
		14:
			return role == "noriela"
		15:
			return true
	return false


func _track_npc_total_visit(npc: Node) -> int:
	var root := get_tree().root
	var visit_counts: Dictionary = root.get_meta("ch3_npc_total_visit_counts", {})
	var key := "late|%s" % npc.name
	var visit_number := int(visit_counts.get(key, 0)) + 1
	visit_counts[key] = visit_number
	root.set_meta("ch3_npc_total_visit_counts", visit_counts)
	return visit_number


func _play_npc_repeat(npc: Node2D, visit_number: int) -> void:
	var lines: Array = npc.call("get_repeat_dialogue_lines", visit_number) if npc.has_method("get_repeat_dialogue_lines") else []
	if lines.is_empty():
		await _play_npc_initial(npc)
		return
	sequence_running = true
	await _play_bubble(npc, lines)
	sequence_running = false
	_restore_walk_hud()


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
		"choices": [str(choice_data.get("choice_a", "Tell me more")), str(choice_data.get("choice_b", "Maybe later"))]
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


func _play_npc_initial(npc: Node2D) -> void:
	var lines: Array = npc.call("get_initial_dialogue_lines") if npc.has_method("get_initial_dialogue_lines") else []
	if lines.is_empty():
		return
	sequence_running = true
	await _play_bubble(npc, lines)
	sequence_running = false
	_restore_walk_hud()


func _chapter_9_backend(npc: Node2D) -> void:
	sequence_running = true
	var kenna := get_parent().find_child("NPCKennaLouisaArizobal", true, false) as Node2D
	var nathalie := get_parent().find_child("NPCNathalieMilo", true, false) as Node2D
	await _play_bubble(player, [
		{"name": "Player", "text": "I've rewritten this query five times..."},
		{"name": "Player", "text": "Why is Django refusing to resolve the classroom relationship?!"}
	])
	await _play_bubble(kenna if kenna else npc, [
		{"name": "Kenna Louisa Arizobal", "text": "Hands off the keyboard, kiddo."},
		{"name": "Kenna Louisa Arizobal", "text": "Breathe."},
		{"name": "Kenna Louisa Arizobal", "text": "Take a bite of the muffin..."},
		{"name": "Kenna Louisa Arizobal", "text": "You've been cruising through small bug tickets for six weeks."},
		{"name": "Kenna Louisa Arizobal", "text": "Ticket #151 is your first real reverse lookup."},
		{"name": "Kenna Louisa Arizobal", "text": "A terminal error isn't calling you stupid."},
		{"name": "Kenna Louisa Arizobal", "text": "It's a compiler telling you where the map is wrong."},
		{"name": "Player", "text": "I feel like an idiot, Kenna."},
		{"name": "Player", "text": "I'm holding everyone up."},
		{"name": "Kenna Louisa Arizobal", "text": "My second week here, I accidentally ran an update query without a where clause on staging."},
		{"name": "Kenna Louisa Arizobal", "text": "I renamed all 500 test students to John Doe."},
		{"name": "Kenna Louisa Arizobal", "text": "I cried in the bathroom stall for an hour."},
		{"name": "Kenna Louisa Arizobal", "text": "Look at the model relationships: how is StudentProfile related to Classroom?"}
	])
	await _play_bubble(player, [
		{"name": "Player", "text": "It's a reverse relation through profile__classroom, not a direct classroom field!"}
	])
	await _play_bubble(nathalie if nathalie else npc, [
		{"name": "Nathalie Milo", "text": "We'll start small: model relationships, CRUD behavior, and URL routing."},
		{"name": "Nathalie Milo", "text": "Then queryset filtering and serializer fields."},
		{"name": "Nathalie Milo", "text": "Ask why each piece belongs where it does."}
	])
	_set_workstation_active(backend_workstation, true)
	_set_stage(901, "ch9_backend_workstation", "Work with Kenna on Ticket #151 at the Backend Workstation ([F] Use Workstation).", "BackendWorkstation", "2nd Floor")
	sequence_running = false
	_restore_walk_hud()


func _on_backend_workstation_used(workstation_id: String) -> void:
	if sequence_running or workstation_id != "backend_trainee_desk":
		return
	match _stage():
		901:
			await _complete_backend_training_workstation()
		141:
			await _complete_epilogue_workstation()


func _complete_backend_training_workstation() -> void:
	sequence_running = true
	_set_workstation_active(backend_workstation, false)
	_hide_walk_hud()
	if player:
		player.can_move = false
	await _play_dialogue([{"name": "Kenna Louisa Arizobal", "text": "Open the sprint issues and start with Ticket #151. Inspect each reference file before changing anything. Use my hint if you need a nudge toward the underlying relationship—I'll leave the solution for you to work out."}])
	var ticket_succeeded := await _run_gethub_ticket_batch(backend_ticket_batch)
	if not ticket_succeeded:
		_set_workstation_active(backend_workstation, true)
		sequence_running = false
		_restore_walk_hud()
		return
	await _show_story_cutscene("Chapter 9 — CUT_05B: The Terminal High-Five", "Dual monitors flash green HTTP 200 OK. Kenna and the player freeze in a triumphant high-five above the keyboard while Nathalie smiles over the cubicle wall.", [
		{"name": "Kenna Louisa Arizobal", "text": "BOOM! That's how a real Django web developer queries reverse lookups!"},
		{"name": "Player", "text": "YES! It's returning 200 OK! All 24 classroom records serialized!"},
		{"name": "Nathalie Milo", "text": "Keep celebrating, kids, but don't break the desk."}
	])
	_set_stage(91, "ch9_frontend_integration", "Tickets #151 and #152 are complete. Meet Abel on Floor 2 to review the frontend API contract for Ticket #153.", "NPCAbelAbendano", "2nd Floor")
	sequence_running = false
	_restore_walk_hud()


func _chapter_9_frontend(npc: Node2D) -> void:
	sequence_running = true
	await _play_bubble(npc, [
		{"name": "Abel Abendaño", "text": "The backend has a real API contract now."},
		{"name": "Abel Abendaño", "text": "Let's connect the portal to those response fields."},
		{"name": "Abel Abendaño", "text": "Don't make up data in the interface."},
		{"name": "Abel Abendaño", "text": "We'll display student progress and validate the form."},
		{"name": "Abel Abendaño", "text": "We'll make loading, error, and narrow-screen states clear."},
		{"name": "Celestina Balon", "text": "I'll verify the behavior against the ticket."},
		{"name": "Celestina Balon", "text": "I'll make sure the frontend displays the API response correctly."}
	])
	_set_workstation_active(frontend_workstation, true)
	_set_stage(911, "ch9_frontend_workstation", "Complete Ticket #153 at the Frontend Workstation beside Abel ([F] Use Workstation).", "FrontendWorkstation", "2nd Floor")
	sequence_running = false
	_restore_walk_hud()


func _on_frontend_workstation_used(workstation_id: String) -> void:
	if sequence_running or workstation_id != "frontend_trainee_desk" or _stage() != 911:
		return
	sequence_running = true
	_set_workstation_active(frontend_workstation, false)
	_hide_walk_hud()
	if player:
		player.can_move = false
	await _play_dialogue([{"name": "Abel Abendaño", "text": "Before editing, compare the response contract with the UI's assumptions. Check what the browser actually receives at runtime; the mentor hint can point you toward validation without writing it for you."}])
	var ticket_succeeded := true
	if frontend_ticket_batch.is_empty():
		await _show_placeholder("Chapter 9 — Frontend Integration", "Gameplay Placeholder\nConnect UI components to the sandbox API. Display student progress, add classroom enrollment, connect a form to an endpoint, map response fields, handle loading and validation errors, and check the mobile layout.")
	else:
		ticket_succeeded = await _run_gethub_ticket_batch(frontend_ticket_batch)
	if not ticket_succeeded:
		_set_workstation_active(frontend_workstation, true)
		sequence_running = false
		_restore_walk_hud()
		return
	var abel := get_parent().find_child("NPCAbelAbendano", true, false) as Node2D
	await _play_bubble(abel, [
		{"name": "Abel Abendaño", "text": "Good work."},
		{"name": "Abel Abendaño", "text": "You used the agreed API contract and communicated the missing pieces instead of guessing."}
	])
	_set_stage(10, "ch10_ojt_evaluation", "Go to the Lead's Office for your OJT evaluation.", "NPCIvanaDanielaGabani")
	sequence_running = false
	_restore_walk_hud()


func _run_gethub_ticket_batch(ticket_batch: Array[Resource]) -> bool:
	if ticket_batch.is_empty():
		push_error("Chapter 9 GetHub ticket batch is empty; assign its ticket resources in the scene Inspector.")
		return false
	var gethub_ui := GETHUB_ISSUES_SCENE.instantiate() as CanvasLayer
	gethub_ui.set("tickets", ticket_batch)
	gethub_ui.connect("finished", _on_gethub_ticket_batch_finished)
	get_parent().add_child(gethub_ui)
	var result: Array = await gethub_ticket_batch_finished
	return not result.is_empty() and bool(result[0])


func _on_gethub_ticket_batch_finished(success: bool, issue_number: int) -> void:
	gethub_ticket_batch_finished.emit(success, issue_number)


func _complete_epilogue_workstation() -> void:
	sequence_running = true
	_set_workstation_active(backend_workstation, false)
	_hide_walk_hud()
	await _show_placeholder("The Journey Continues", "Ticket: Improve the student dashboard\nPriority: Normal\nAssigned to: You\nStatus: Ready for development\n\n[This is the ending of the current story arc. The player opens the IDE and begins another day as a web developer.]")
	await _show_story_cutscene("Chapter 14 — Paying It Forward", "Back in the Ground Floor Lobby Atrium, a nervous new student pauses near reception, checking the time before gathering the courage to approach.", [
		{"name": "You", "text": "Hey there. Looking for the technical interview room? Come on... let me show you the way."}
	])
	await _play_dialogue([{"name": "Narration", "text": "This is not the end of the journey. It is the beginning of a career."}])
	_set_stage(15, "story_complete", "The office story arc is complete. Your next ticket is ready.", "Player")
	sequence_running = false
	_restore_walk_hud()


func _chapter_10_evaluation(npc: Node2D) -> void:
	sequence_running = true
	var ivana := get_parent().find_child("NPCIvanaDanielaGabani", true, false) as Node2D
	var august_npc := get_parent().find_child("NPCAugustCreed", true, false) as Node2D
	_hide_walk_hud()
	if player:
		player.can_move = false

	# Ivana reviews August's HR intern record directly from her desk
	if august_npc and august_npc.visible:
		await _play_bubble(august_npc, [
			{"name": "August Creed", "text": "300 hours completed. 18 resolved tickets across QA, Frontend, and Backend. Zero unexcused absences."},
			{"name": "August Creed", "text": "Outstanding peer reviews from Celestina, Kenna, and Abel."}
		])
	else:
		await _play_dialogue([
			{"name": "Ivana Daniela Gabani", "text": "August sent up your completed file. 300 hours logged across QA, Frontend, and Backend. Zero unexcused absences. Outstanding reviews from Celestina, Kenna, and Abel."}
		])

	# Ivana opens the defense
	await _play_dialogue([
		{"name": "Ivana Daniela Gabani", "text": "Let's see if the understanding matches the hours."},
		{"name": "Ivana Daniela Gabani", "text": "Six questions. Three I want answered now."}
	])

	# — Defense Question 1: Auth separation —
	await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Question one. Why do we separate user authentication from the student profile model? What breaks if they're in the same table?"}])
	accountability_choice_ui.call("show_choices", [
		"Because the auth user handles login security; the student profile holds academic data. Mixing them violates single responsibility and makes future role changes or multi-tenant schools impossible to manage cleanly.",
		"It's just convention. Django's built-in user model has fields we don't need for student records.",
		"So that QA can test each model independently without touching real credentials."
	])
	var auth_choice: int = await accountability_choice_selected
	accountability_choice_ui.call("hide_choices")
	if player:
		player.can_move = false
	if auth_choice == 0:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Correct. Single responsibility isn't just a design philosophy—it protects every school's data when we onboard new clients."}])
	else:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Incorrect. The separation protects login security from academic data leaks and makes multi-tenant scaling possible. Remember that."}])

	# — Defense Question 2: N+1 queries —
	await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Question two. Our student list view was loading 200 enrollment records. How do you prevent it from hitting the database 201 times?"}])
	accountability_choice_ui.call("show_choices", [
		"Use select_related() for ForeignKey fields and prefetch_related() for ManyToMany—this tells Django to JOIN or batch the lookup in one query instead of one per record.",
		"Add a database index to the foreign key column so lookups are faster.",
		"Cache the queryset in Redis so the database is only queried once per session."
	])
	var nplus1_choice: int = await accountability_choice_selected
	accountability_choice_ui.call("hide_choices")
	if player:
		player.can_move = false
	if nplus1_choice == 0:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Correct. select_related and prefetch_related are the first tools you reach for before any caching layer."}])
	else:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Indexes help, but they don't solve N+1. select_related and prefetch_related collapse the round trips at the ORM level first."}])

	# — Defense Question 3: Malicious UUID —
	await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Question three. An unauthenticated user sends a POST to /api/students/{uuid}/grade/ with a forged UUID. What stops them?"}])
	accountability_choice_ui.call("show_choices", [
		"The view must check request.user.is_authenticated and verify the requesting user owns that student record before the queryset even executes. Server-side authorization, every time.",
		"UUIDs are hard to guess, so forged requests are statistically unlikely to match a real record.",
		"Our HTTPS certificate ensures requests are encrypted, so outsiders cannot see the UUID format."
	])
	var uuid_choice: int = await accountability_choice_selected
	accountability_choice_ui.call("hide_choices")
	if player:
		player.can_move = false
	if uuid_choice == 0:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "That is the only correct answer. Encryption protects transit. Authorization protects the data. They are not the same thing."}])
	else:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "UUIDs are not a security control—they are identifiers. Server-side authorization is what blocks unauthorized access, not entropy or encryption."}])

	# Ivana signs off
	await _play_dialogue([
		{"name": "Ivana Daniela Gabani", "text": "When you walked through that door a few weeks ago, you were terrified of touching a stylesheet."},
		{"name": "Ivana Daniela Gabani", "text": "Today, you defended enterprise architecture like a web developer."},
		{"name": "Ivana Daniela Gabani", "text": "You didn't just fulfill hours—you earned our trust."}
	])
	await _show_placeholder("Chapter 10 — OJT Clearance Signed", "Ivana signs the Certificate of Completion with a flourish. August affixes the official company gold seal to the OJT clearance form.\n\n[Item: Signed OJT Clearance & Completion Certificate Obtained!]")

	# Fire-escape phone call home
	await _show_story_cutscene("Chapter 10 — Fire-Escape Phone Call Home", "Warm golden afternoon light falls across the rusty fire-escape railing. The city skyline sprawls below. A lens flare grazes the camera as the player pulls out their phone.", [
		{"name": "Player", "text": "Ma... Pa... Nakapasa ako. Piramado na po lahat ng OJT clearance ko..."},
		{"name": "Player", "text": "Graduate na ako."},
		{"name": "Parent (Over Phone)", "text": "Salamat sa Diyos, anak! Ang galing-galing mo!"},
		{"name": "Parent (Over Phone)", "text": "Umuwi ka nang maaga ha, ipagluluto kita ng paborito mong ulam... Sobrang proud kami sayo ng Papa mo!"}
	])
	await _show_placeholder("Chapter 10 — Academic Clearance", "Story Placeholder\nThe player presents the signed OJT certificate to the college adviser and completes the university graduation clearance.")
	await _show_time_skip_card(
		"TWO WEEKS LATER — GRADUATION CLEARANCE DONE",
		"300 / 300 HOURS VERIFIED",
		"Two weeks pass. University graduation clearances are officially filed. Today, you return to DJQ Corp for the final time to surrender your temporary green intern pass at reception and say goodbye to the team.\n\nFade in: Ground Floor Lobby. Kendra waves from reception.",
		true
	)
	get_tree().root.set_meta("ch3_graduation_return", true)
	_set_stage(11, "ch11_absorption", "Report to Kendra at reception before surrendering your badge.", "NPCKendraBarba", "Ground Floor")
	sequence_running = false
	_restore_walk_hud()
	_transition_to_story_destination(ground_floor_scene_path, graduation_reception_spawn_position)


func _chapter_11_offer(npc: Node2D) -> void:
	sequence_running = true
	_hide_walk_hud()
	if player:
		player.can_move = false

	# Frame 1: Player offers the green badge
	await _show_story_cutscene("Chapter 11 — CUT_06: The Full-Time Contract", "Ivana Daniela Gabani's spacious Floor 3 corner office at sunset. Floor-to-ceiling panoramic windows show the city skyline glowing gold. Ivana sits behind a polished mahogany desk. The player stands respectfully across from her, gently placing the green intern lanyard badge on the desktop.", [
		{"name": "Player", "text": "I brought back my temporary green badge, Ma'am Ivana. I just wanted to say thank you for giving me a chance when no one else would."}
	])

	# Frame 2: Ivana pushes the badge aside and slides the contract
	await _show_story_cutscene("Chapter 11 — CUT_06: The Full-Time Contract", "Ivana uses one finger to slide the green badge aside. She pushes a thick, embossed white contract folder across the desk. On top of it rests a metallic Blue Junior Developer Badge on a heavy navy lanyard, catching the sunset light.", [
		{"name": "Ivana Daniela Gabani", "text": "Keep the pastries you brought the team. But take that badge back—or rather, replace it."},
		{"name": "Player", "text": "Ma'am...?"}
	])

	# Frame 3: Ivana's full speech
	await _show_story_cutscene("Chapter 11 — CUT_06: The Full-Time Contract", "Close-up on the player's stunned face, eyes wide, breath caught in their throat. Ivana's expression is warm—something rarely seen. She gestures toward the contract folder with quiet authority.", [
		{"name": "Ivana Daniela Gabani", "text": "You think we're going to let someone who knows our architecture, respects our users, and takes responsibility for their code walk out that door to work for our competitors?"},
		{"name": "Ivana Daniela Gabani", "text": "That folder is a full-time employment contract for Junior Web Developer on the Student Learning Portal team. Competitive salary, health insurance, and your permanent desk is upstairs on Floor 2."}
	])

	await _award_blue_badge()

	await _show_story_cutscene("Chapter 11 — CUT_06: Signing", "Ivana slides an expensive metal pen across the desk with a warm smirk.", [
		{"name": "Ivana Daniela Gabani", "text": "Say it by signing the contract, developer. We have our first enterprise sprint release coming up next month."},
		{"name": "Player", "text": "I... yes. Yes, Ma'am. Thank you."}
	])

	await _show_time_skip_card(
		"ONE MONTH LATER — FIRST MAJOR RELEASE",
		"ROLE: JUNIOR WEB DEVELOPER",
		"One month into your full-time role. You have your own permanent desk on Floor 2, healthcare, and real deployment responsibilities. Today is the official release of the Student Learning Portal for 50,000 exam students across the region.\n\nFade in: Floor 2 DevOps Room. Reynalda stands at the deployment console.",
		true
	)
	_set_stage(12, "ch12_sprint_planning", "Join Reynalda for the release planning meeting.", "NPCReynaldaPatalinghug")
	sequence_running = false
	_restore_walk_hud()
	_transition_to_story_destination(second_floor_scene_path, reynalda_arrival_position)


func _transition_to_story_destination(scene_path: String, spawn_position: Vector2) -> void:
	if scene_path.is_empty():
		return
	var scene_transition := get_node_or_null("/root/SceneTransition")
	if scene_transition and scene_transition.has_method("transition_to_scene"):
		scene_transition.call("transition_to_scene", scene_path, spawn_position, "none")


func _award_blue_badge() -> void:
	var character_data := get_node_or_null("/root/CharacterData")
	if character_data:
		character_data.ch3_has_green_badge = false
		character_data.ch3_has_blue_badge = true
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory and inventory.has_item("green_ojt_badge"):
		inventory.remove_item("green_ojt_badge", inventory.get_item_quantity("green_ojt_badge"))
	if inventory == null or inventory.has_item("blue_junior_developer_badge"):
		return
	var item_popup := get_node_or_null("/root/ItemPopup")
	if item_popup and item_popup.has_method("show_item"):
		await item_popup.show_item(
			"blue_junior_developer_badge",
			"Blue Junior Developer Badge",
			"Grants full-time access to the Floor 2 Developer Wing and restricted office rooms."
		)
	else:
		inventory.add_item(
			"blue_junior_developer_badge",
			"Blue Junior Developer Badge",
			"Grants full-time access to the Floor 2 Developer Wing and restricted office rooms."
		)


func _pr_42_review_data() -> Dictionary:
	return {
		"pr_number": 42,
		"pr_title": "feat(enrollment): Add student enrollment tracking timestamp",
		"author_name": "You",
		"author_role": "Junior Developer",
		"branch_target": "main ← feature/student-enrollment",
		"description": "Adds enrolled_at timestamp field to track student onboarding time. Staging pipeline tests passed.",
		"checklist": PackedStringArray(["[x] Unit tests pass in CI pipeline", "[x] Staging API smoke tests pass", "[ ] Database migrations included in release runbook: python manage.py migrate"]),
		"diff_content": "diff --git a/student_portal/models.py b/student_portal/models.py\n@@ StudentEnrollment model @@\n+class StudentEnrollment(models.Model):\n+    student = models.ForeignKey(Student, on_delete=models.CASCADE)\n+    enrolled_at = models.DateTimeField(auto_now_add=True)\ndiff --git a/student_portal/views.py b/student_portal/views.py\n@@ enrollment view @@\n+enrollment = StudentEnrollment.objects.filter(student_id=student_id).first()\n+enrolled_date = enrollment.enrolled_at if enrollment else None",
		"approve_action_label": "Approve & Trigger Deployment"
	}


func _pr_43_review_data() -> Dictionary:
	return {
		"pr_number": 43,
		"pr_title": "feat(reports): Student progress detail endpoint",
		"author_name": "Intern / Junior Dev",
		"author_role": "Backend Developer",
		"branch_target": "main ← feature/student-progress-detail",
		"description": "Endpoint to return student progress records by ID.",
		"checklist": PackedStringArray(["[x] Endpoint returns progress records", "[x] Serializer fields reviewed", "[ ] Verify request.user owns the requested student record"]),
		"diff_content": "diff --git a/student_portal/views.py b/student_portal/views.py\n@@ student progress detail endpoint @@\n+@api_view([\"GET\"])\n+def student_progress_detail(request, student_id):\n+    progress = StudentProgress.objects.filter(student_id=student_id)\n+    serializer = StudentProgressSerializer(progress, many=True)\n+    return Response(serializer.data)\n+\n+# Missing: confirm request.user is authorized to access this student's data.",
		"approve_action_label": "Submit Review",
		"default_change_request_comment": "Missing authorization check. Any user can view other students' private progress data."
	}


func _chapter_12_sprint(npc: Node2D) -> void:
	sequence_running = true
	await _play_bubble(npc, [
		{"name": "Reynalda Patalinghug", "text": "You're joining this sprint as a developer now."},
		{"name": "Reynalda Patalinghug", "text": "Let's estimate the cross-team feature and name blockers."},
		{"name": "Reynalda Patalinghug", "text": "Make sure deployment steps have an owner."},
		{"name": "Ivana Daniela Gabani", "text": "The feature is ready to release, but production has its own database."},
		{"name": "Ivana Daniela Gabani", "text": "The migration must be applied and verified there too."}
	])
	await _play_dialogue([{"name": "Reynalda Patalinghug", "text": "Before we release, open PR #42 and review the changed files and deployment checklist. Pay particular attention to whether the database change has a safe production rollout step."}])
	var review_result := await _open_pull_request_review(_pr_42_review_data())
	if bool(review_result.get("dismissed", false)):
		sequence_running = false
		_restore_walk_hud()
		return
	while not bool(review_result.get("approved", false)):
		await _play_bubble(npc, [{"name": "Reynalda Patalinghug", "text": "This is your pull request. Check the unchecked migration runbook item before approving a production deployment."}])
		review_result = await _open_pull_request_review(_pr_42_review_data())
		if bool(review_result.get("dismissed", false)):
			sequence_running = false
			_restore_walk_hud()
			return
	await _play_bubble(npc, [{"name": "Reynalda Patalinghug", "text": "PR #42 approved. I’m triggering the production rollout now."}])
	await _chapter_12_incident(npc)


func _chapter_12_incident(npc: Node2D) -> void:
	sequence_running = true
	server_incident_phase = 0
	get_tree().root.set_meta("ch3_server_alert_started", true)
	get_tree().root.set_meta("ch3_server_incident_phase", 0)
	if server_rack:
		server_rack.call("trigger_emergency_state", true)
	await _show_story_cutscene("Chapter 12 — CUT_07: The Production 500 Alert", "Pulsing red emergency strobe beacons wash across the server room. Sirens sound as a monitor flashes CRITICAL 500 ERROR.", [
		{"name": "System Alert", "text": "[CRITICAL ALERT]: HTTP 500 Internal Server Error on /api/v1/auth/login/. Students are blocked from signing in."}
	])
	get_tree().root.set_meta("ch3_divino_incident_briefed", false)
	_set_stage(121, "ch12_production_incident", "Find Divino in the Server Room for incident triage.", "NPCDivinoCinaon")
	sequence_running = false
	_restore_walk_hud()


func _on_server_console_interacted(_is_emergency: bool) -> void:
	if sequence_running or server_rack == null or not server_rack.get("is_in_emergency"):
		return
	call_deferred("_handle_server_console_interaction")


func _on_server_traceback_acknowledged() -> void:
	server_traceback_acknowledged.emit()


func _on_server_migration_requested() -> void:
	server_migration_requested.emit()


func _on_server_terminal_continued() -> void:
	server_terminal_continued.emit()


func _handle_server_console_interaction() -> void:
	if sequence_running or server_rack == null:
		return
	sequence_running = true
	_hide_walk_hud()
	if player:
		player.can_move = false
	if server_incident_phase == 0:
		var divino := get_parent().find_child("NPCDivinoCinaon", true, false) as Node2D
		await _play_dialogue([{"name": "Divino Cinaon", "text": "You're at the primary console. Read the traceback carefully; identify what the database says is missing before we discuss who owns the change."}])
		if server_rack_terminal_ui:
			server_rack_terminal_ui.call("present_traceback")
			await server_traceback_acknowledged
		await _play_bubble(divino, [{"name": "Divino Cinaon", "text": "Who authored PR #42?"}])
		var accountability_choice := await _ask_accountability_choice()
		while accountability_choice != 2:
			if accountability_choice == 0:
				await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "The deployment automation ran the steps it was given. Check the change history and identify who owned the missing migration."}])
			else:
				await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "QA can only verify the migration if the change is included in the release. The author still needs to own the missed checklist item."}])
			accountability_choice = await _ask_accountability_choice()
		await _play_dialogue([{"name": "You", "text": "It was me, Divino. I added the field but forgot the migration on the checklist. It's entirely my mistake."}])
		await _play_bubble(divino, [
			{"name": "Divino Cinaon", "text": "Good. Real web developers own their code."},
			{"name": "Divino Cinaon", "text": "Sit at console two."},
			{"name": "Divino Cinaon", "text": "Let's run the migration."}
		])
		server_incident_phase = 1
		get_tree().root.set_meta("ch3_server_incident_phase", server_incident_phase)
		server_rack.set("interaction_text", "[F] Run python manage.py migrate")
		var rack_label := server_rack.get_node_or_null("Label") as Label
		if rack_label:
			rack_label.text = "[F] Run python manage.py migrate"
	else:
		if server_rack_terminal_ui:
			server_rack_terminal_ui.call("present_migration_prompt")
			await server_migration_requested
		server_rack.call("resolve_emergency")
		if server_rack_terminal_ui:
			server_rack_terminal_ui.call("present_success")
			await server_terminal_continued
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "The service is restored. We'll improve the release checklist so the migration and verification steps are visible next time."}])
		_set_stage(122, "ch12_secrets_audit", "Go to IT Storage with Tercio for a configuration security check.", "NPCTercioMateoRamos")
		server_incident_phase = 2
		get_tree().root.set_meta("ch3_server_incident_phase", server_incident_phase)
		get_tree().root.set_meta("ch3_server_alert_started", false)
	sequence_running = false
	_restore_walk_hud()


func _on_coffee_brewed() -> void:
	get_tree().root.set_meta("ch3_coffee_run_available", true)


func _ask_accountability_choice() -> int:
	if accountability_choice_ui == null:
		return 2
	accountability_choice_ui.call("show_choices", [
		"Blame DevOps: automation skipped a deployment hook.",
		"Blame QA: staging missed the enrollment-table test.",
		"Own the miss: I added the field and forgot its migration."
	])
	var selected: int = await accountability_choice_selected
	accountability_choice_ui.call("hide_choices")
	if player:
		player.can_move = false
	return selected


func _on_accountability_choice_selected(choice_index: int) -> void:
	accountability_choice_selected.emit(choice_index)


func _chapter_12_secrets(npc: Node2D) -> void:
	sequence_running = true
	await _play_bubble(npc, [
		{"name": "Tercio Mateo Ramos", "text": "We found an AWS S3 secret key hardcoded in settings.py three commits ago."},
		{"name": "Tercio Mateo Ramos", "text": "It wasn't public, but it's in our internal Git history."},
		{"name": "Divino Cinaon", "text": "Treat the exposed credential as compromised."},
		{"name": "Divino Cinaon", "text": "Invalidate it on AWS and move the replacement to a secure .env file."},
		{"name": "Divino Cinaon", "text": "Then clean the repository history."}
	])
	await _show_placeholder("Chapter 12 — Secrets Audit", "Gameplay Placeholder\nReplace the exposed configuration value with an environment variable. Verify the safe configuration and check that no credential remains in public project files.")
	_set_stage(123, "ch12_code_review", "Meet Ivana in the Lead's Office to review a teammate's pull request.", "NPCIvanaDanielaGabani")
	sequence_running = false
	_restore_walk_hud()


func _chapter_12_code_review(npc: Node2D) -> void:
	sequence_running = true
	await _play_bubble(npc, [
		{"name": "Ivana Daniela Gabani", "text": "Review this progress endpoint."},
		{"name": "Ivana Daniela Gabani", "text": "Does it prove the current user is allowed to see the requested student's data?"},
		{"name": "Narration", "text": "The pull request queries StudentProgress by student_id."},
		{"name": "Narration", "text": "But it never checks ownership or authorization."}
	])
	await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Open the pull request and leave a review comment. Trace the access path and decide whether the endpoint proves the current user may see these records."}])
	var review_result := await _open_pull_request_review(_pr_43_review_data())
	if bool(review_result.get("dismissed", false)):
		sequence_running = false
		_restore_walk_hud()
		return
	while bool(review_result.get("approved", false)):
		await _play_bubble(npc, [{"name": "Ivana Daniela Gabani", "text": "Look closer at authorization. Does this prove request.user is allowed to access the requested student's private progress data?"}])
		review_result = await _open_pull_request_review(_pr_43_review_data())
		if bool(review_result.get("dismissed", false)):
			sequence_running = false
			_restore_walk_hud()
			return
	await _play_bubble(npc, [{"name": "Ivana Daniela Gabani", "text": "Exactly. Require an ownership or permission check against request.user before returning these records. That is a clear, actionable review comment."}])
	await _show_time_skip_card(
		"THE NEXT MORNING — 10:00 AM",
		"EXECUTIVE STAKEHOLDER PRESENTATION",
		"Following a grueling night restoring production, the system is stable and passing all checks. Now, company leadership and university trustees convene in the Penthouse Boardroom to review system architecture and discuss Sprint 2.\n\nFade in: Floor 3 Executive Boardroom corridor."
	)
	_set_stage(13, "ch13_executive_presentation", "Present the completed Student Learning Portal to Julia Roa.", "NPCJuliaRoa")
	sequence_running = false
	_restore_walk_hud()


func _open_pull_request_review(review_data: Dictionary) -> Dictionary:
	var review_ui := GETHUB_PULL_REQUEST_SCENE.instantiate() as CanvasLayer
	for property_name: String in review_data:
		review_ui.set(property_name, review_data[property_name])
	review_ui.connect("pr_reviewed", _on_pull_request_reviewed)
	review_ui.connect("closed", _on_pull_request_modal_closed)
	get_parent().add_child(review_ui)
	if player:
		player.can_move = false
	var result: Array = await pull_request_modal_result
	return {
		"approved": bool(result[0]),
		"pr_number": int(result[1]),
		"comment": str(result[2]),
		"dismissed": bool(result[3])
	}


func _on_pull_request_reviewed(approved: bool, pr_number: int, comment: String) -> void:
	pull_request_modal_result.emit(approved, pr_number, comment, false)


func _on_pull_request_modal_closed() -> void:
	pull_request_modal_result.emit(false, -1, "", true)


func _chapter_13_executive_meeting(npc: Node2D) -> void:
	sequence_running = true
	_hide_walk_hud()
	if player:
		player.can_move = false

	# — Pre-meeting: Julia alone in the boardroom. Mario and Ivana are not here yet. —
	var julia := get_parent().find_child("NPCJuliaRoa", true, false) as Node2D
	var mario_f3 := get_parent().find_child("NPCMarioEllanCruz", true, false) as Node2D
	var ivana := get_parent().find_child("NPCIvanaDanielaGabani", true, false) as Node2D

	# Make sure Mario and Ivana are hidden before the player speaks to Julia.
	if mario_f3:
		mario_f3.visible = false
		_sync_npc_collision_tree(mario_f3, false)
	# Ivana stays visible in her corner office at this stage—the boardroom is in the same 3rd-floor
	# scene so we move her to the boardroom position under the black screen instead.

	await _play_bubble(julia if julia else npc, [
		{"name": "Julia Roa", "text": "You made it. The presentation is ready to go—your architecture slides look sharp."},
		{"name": "Julia Roa", "text": "Mario and Ivana are on their way up. Give them a couple of minutes to settle in."},
		{"name": "Julia Roa", "text": "Breathe. You have everything you need."}
	])

	# — Fade to black while the rest of the attendees arrive —
	if overlay_layer:
		overlay_layer.visible = true
		overlay.color.a = 0.0
		overlay_title.modulate.a = 0.0
		overlay_body.modulate.a = 0.0
	var fade_in_black := create_tween()
	fade_in_black.tween_property(overlay, "color:a", 1.0, 1.0)
	await fade_in_black.finished

	# Under darkness: move Mario and Ivana into boardroom seats.
	# Boardroom: Rect2(1216, -96, 481, 320). Julia at (1477, -58).
	# Mario sits at the near side of the conference table, looking nervous.
	if mario_f3:
		mario_f3.global_position = Vector2(1350, 30)
		mario_f3.visible = true
		_sync_npc_collision_tree(mario_f3, true)
		var mario_sprite := mario_f3.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if mario_sprite and mario_sprite.sprite_frames and mario_sprite.sprite_frames.has_animation("idle_up"):
			mario_sprite.play("idle_up")
	# Ivana moves from her corner office into the boardroom, standing along the far wall.
	if ivana:
		ivana.global_position = Vector2(1570, -30)
		var ivana_sprite := ivana.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if ivana_sprite and ivana_sprite.sprite_frames and ivana_sprite.sprite_frames.has_animation("idle_down"):
			ivana_sprite.play("idle_down")

	# Short pause while everyone settles
	await get_tree().create_timer(0.4).timeout

	# Fade back in to the boardroom full of people
	var fade_out_black := create_tween()
	fade_out_black.tween_property(overlay, "color:a", 0.0, 0.8)
	await fade_out_black.finished
	if overlay_layer:
		overlay_layer.visible = false

	# — Main boardroom presentation —
	await _show_story_cutscene("Chapter 13 — CUT_08: Boardroom Presentation",
		"The sunlit Floor 3 penthouse boardroom. The player presents the portal architecture to Julia Roa and the board of trustees. A board executive interrupts with a last-minute overnight AI grading and PDF export demand. Mario anxiously tugs his collar.",
		[
			{"name": "You", "text": "Our portal combines a secure Django API, a responsive frontend, automated tests, and a verified release process. 50,000 simulated student logins with sub-150 millisecond response times and zero data leakage."},
			{"name": "Board Executive", "text": "Yes, yes, the architecture is lovely. But the school superintendent just called me. They want an automated AI essay grading engine and custom PDF report exports built and deployed by tomorrow morning's press conference. Can we guarantee that goes live tomorrow?"},
			{"name": "Mario Ellan Cruz", "text": "W-well, sir... we could try to push an overnight patch—"}
		]
	)

	var selected := await _ask_scope_choice()
	if selected == 2:
		await _play_dialogue([{"name": "You", "text": "With respect, sir—no. Deploying unvetted AI endpoints and export scripts on launch morning bypasses QA and risks memory leaks for 50,000 students. We guarantee a flawless launch tomorrow, and will deliver the export features in Sprint 2 with full security testing."}])
	else:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Before we commit to that, we need to return to the requirements, estimate the impact carefully, and agree on a release plan that doesn't compromise our students."}])

	await _show_story_cutscene("Chapter 13 — Julia Roa's Verdict",
		"Julia Roa leans back in her tall executive chair, a radiant and deeply impressed smile breaking across her face. The aggressive board executive sits back down, chastened. Ivana gives an imperceptible nod of supreme respect to the Player.",
		[
			{"name": "Julia Roa", "text": "A web developer who protects our users and product stability instead of saying yes to catastrophic crunch. That is true technical leadership. Launch tomorrow as scheduled. Meeting adjourned."}
		]
	)

	# — After the meeting: Mario and Ivana stay in the boardroom. No fade-away. —
	# Advance stage so both remain visible via _sync_lead_office_roster (stage >= 13).
	_set_stage(14, "ch14_conclusion", "Spend a moment with Noriela in the Break Room.", "NPCNorielaAsahan")
	sequence_running = false
	_restore_walk_hud()


func _ask_scope_choice() -> int:
	if accountability_choice_ui == null:
		return 2
	accountability_choice_ui.call("show_choices", [
		"Agree to deliver both features overnight, without changing the launch plan.",
		"Reject the request without discussing scope, risk, or alternatives.",
		"Protect launch; estimate the work and schedule it for Sprint 2 with QA and security testing."
	])
	var selected: int = await accountability_choice_selected
	accountability_choice_ui.call("hide_choices")
	if player:
		player.can_move = false
	return selected


func _chapter_14_epilogue(npc: Node2D) -> void:
	sequence_running = true
	await _show_story_cutscene("Chapter 14 — CUT_09: Epilogue at Developer Desk", "At 7:45 AM, golden sunlight falls over the Floor 2 developer desk. Fresh coffee steams beside the keyboard; the clean terminal reads 'Build: PASSING' beside an architecture flowchart. Noriela rolls her chair over with a box of donuts.", [
		{"name": "Narration", "text": "The journey did not end when the thesis was defended."},
		{"name": "Narration", "text": "The thesis proved that I could build a system. The OJT taught me how a team builds systems."},
		{"name": "Narration", "text": "Working at DJQ Corp taught me how to take responsibility for one."},
		{"name": "Narration", "text": "The montage passes through the commute to work, a stable life shared with family, team meetings, bug fixes, code reviews, and helping newer trainees find their footing."},
		{"name": "Noriela Asahan", "text": "Ready for your first ticket as a permanent member of the team?"}
	])
	_set_workstation_active(backend_workstation, true)
	if backend_workstation:
		backend_workstation.set("interaction_text", "[F] Open IDE & Start Workday")
	_set_stage(141, "ch14_workstation", "Sit at your permanent developer workstation on Floor 2 ([F] Open IDE).", "BackendWorkstation")
	sequence_running = false
	_restore_walk_hud()


func _show_placeholder(title: String, body: String) -> void:
	await _show_panel(title, body + "\n\n[Press Space to continue]")


func _show_time_skip_card(title: String, status: String, description: String, hold_dark_overlay_for_transition: bool = false) -> void:
	_hide_walk_hud()
	if player:
		player.can_move = false
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	overlay_layer.visible = true
	overlay.color = Color(0.015, 0.02, 0.035, 0.0)
	overlay_title.text = title
	overlay_body.text = "%s\n\n%s\n\n[Press Space to continue]" % [status, description]
	overlay_title.modulate.a = 0.0
	overlay_body.modulate.a = 0.0
	await get_tree().process_frame
	var fade_to_black := create_tween()
	fade_to_black.tween_property(overlay, "color:a", 1.0, 1.5)
	await fade_to_black.finished
	var fade_card_in := create_tween().set_parallel(true)
	fade_card_in.tween_property(overlay_title, "modulate:a", 1.0, 0.35)
	fade_card_in.tween_property(overlay_body, "modulate:a", 1.0, 0.35)
	await fade_card_in.finished
	while not Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	var fade_card_out := create_tween().set_parallel(true)
	fade_card_out.tween_property(overlay_title, "modulate:a", 0.0, 0.4)
	fade_card_out.tween_property(overlay_body, "modulate:a", 0.0, 0.4)
	if not hold_dark_overlay_for_transition:
		fade_card_out.tween_property(overlay, "color:a", 0.0, 0.4)
	await fade_card_out.finished
	if hold_dark_overlay_for_transition:
		return
	overlay_layer.visible = false
	overlay_title.modulate.a = 1.0
	overlay_body.modulate.a = 1.0


func _show_story_cutscene(title: String, visual: String, lines: Array) -> void:
	sequence_running = true
	_hide_walk_hud()
	await _show_panel(title, visual + "\n\n[Press Space to continue]")
	await _play_dialogue(lines)


func _show_panel(title: String, body: String) -> void:
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	if player:
		player.can_move = false
	overlay_layer.visible = true
	overlay.color = placeholder_overlay_color
	overlay_title.text = title
	overlay_body.text = body
	await get_tree().process_frame
	while not Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	var fade := create_tween().set_parallel(true)
	fade.tween_property(overlay, "color:a", 0.0, 0.35)
	fade.tween_property(overlay_title, "modulate:a", 0.0, 0.35)
	fade.tween_property(overlay_body, "modulate:a", 0.0, 0.35)
	await fade.finished
	overlay_layer.visible = false
	overlay_title.modulate.a = 1.0
	overlay_body.modulate.a = 1.0


func _play_dialogue(lines: Array) -> void:
	if dialogue_box == null:
		return
	if player:
		player.can_move = false
	dialogue_box.start(lines)
	await dialogue_box.dialogue_finished
	if player:
		player.can_move = false


func _play_bubble(npc: Node2D, lines: Array) -> void:
	if npc == null:
		return
	var bubble := npc.get_node_or_null("Ch3ChatBubble")
	if bubble == null:
		bubble = CHAT_BUBBLE_SCENE.instantiate()
		bubble.name = "Ch3ChatBubble"
		npc.add_child(bubble)
	_hide_walk_hud()
	if player:
		player.can_move = false
	bubble.start(lines)
	await bubble.dialogue_finished
	if player:
		player.can_move = false


func _hide_walk_hud() -> void:
	var room_indicator := get_parent().get_node_or_null("RoomIndicator")
	if room_indicator:
		room_indicator.visible = false
	var quest_hud := get_node_or_null("/root/QuestManager/QuestHud")
	if quest_hud:
		quest_hud.visible = false


func _restore_walk_hud() -> void:
	var room_indicator := get_parent().get_node_or_null("RoomIndicator")
	if room_indicator:
		room_indicator.visible = true
	var quest_hud := get_node_or_null("/root/QuestManager/QuestHud")
	if quest_hud:
		quest_hud.visible = true
	if player:
		player.can_move = true
