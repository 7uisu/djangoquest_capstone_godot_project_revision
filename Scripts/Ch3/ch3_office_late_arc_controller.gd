extends Node

signal accountability_choice_selected(choice_index: int)

const DIALOGUE_BOX_SCENE := preload("res://Scenes/UI/dialogue_box.tscn")
const CHAT_BUBBLE_SCENE := preload("res://Scenes/UI/chat_bubble.tscn")
const INTERVIEW_CHOICE_SCENE := preload("res://Scenes/Ch3/interview_choice_panel.tscn")
const GETHUB_ISSUES_SCENE := preload("res://Scenes/UI/gethub_issues_ui.tscn")
const GETHUB_PULL_REQUEST_SCENE := preload("res://Scenes/UI/gethub_pull_request_ui.tscn")
const SERVER_RACK_TERMINAL_SCENE := preload("res://Scenes/Interactables/server_rack_terminal_ui.tscn")
const FAILURE_SCREEN_SCENE := preload("res://Scenes/UI/failure_screen_ui.tscn")
const TUTORIAL_OVERLAY_SCRIPT := preload("res://Scripts/UI/tutorial_overlay.gd")

signal gethub_ticket_batch_finished(success: bool, issue_number: int)
signal pull_request_modal_result(approved: bool, pr_number: int, comment: String, dismissed: bool)
signal server_traceback_acknowledged
signal server_root_cause_acknowledged
signal server_migration_requested
signal server_terminal_continued

@export_node_path("Node2D") var player_path: NodePath = ^"YSortLayer/Player"
@export_node_path("CanvasLayer") var dialogue_box_path: NodePath = ^"DialogueBox"
@export var placeholder_overlay_color := Color(0.055, 0.075, 0.12, 0.97)
@export_group("Story Transition Destinations")
@export_file("*.tscn") var ground_floor_scene_path := "res://Scenes/Ch3/main_office_3_floor_map.tscn"
@export var graduation_reception_spawn_position := Vector2(607.0, 594.0)
@export_file("*.tscn") var second_floor_scene_path := "res://Scenes/Ch3/Office Floors/main_office_3_floor_map_2nd_floor.tscn"
@export var reynalda_arrival_position := Vector2(316.0, 70.0)
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
	"NPCLukaNeri": "luka",
	"NPCPatricioMateo": "patricio",
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
		server_rack_terminal_ui.connect("root_cause_acknowledged", _on_server_root_cause_acknowledged)
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
			server_rack.set("interaction_text", _server_terminal_text("migration_interaction_prompt"))
			var rack_label := server_rack.get_node_or_null("Label") as Label
			if rack_label:
				rack_label.text = _server_terminal_text("migration_interaction_prompt")
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
	# Keep Mario hidden until the boardroom arrival sequence explicitly summons him.
	var mario_f3 := scene_root.find_child("NPCMarioEllanCruz", true, false) as Node2D
	if mario_f3:
		var mario_boardroom_active := _stage() >= 14 and bool(get_tree().root.get_meta("ch3_boardroom_attendees_arrived", false))
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
			var triage_objective := _server_terminal_text("triage_objective_text", "Access the primary console.")
			var migration_objective := _server_terminal_text("migration_objective_text", "Run the authorized migration at the primary console.")
			if not bool(get_tree().root.get_meta("ch3_server_alert_started", false)):
				_set_stage(121, "ch12_production_incident", "Report to Divino in the Server Room.", "NPCDivinoCinaon")
			elif not bool(get_tree().root.get_meta("ch3_divino_incident_briefed", false)):
				_set_stage(121, "ch12_production_incident", "Find Divino in the Server Room for incident triage.", "NPCDivinoCinaon")
			elif server_incident_phase == 0:
				_set_stage(121, "ch12_production_incident", triage_objective, "ServerRackInteractable")
			else:
				_set_stage(121, "ch12_production_incident", migration_objective, "ServerRackInteractable")
		122:
			_set_stage(122, "ch12_secrets_audit", "Go to IT Storage with Tercio for a configuration security check.", "NPCTercioMateoRamos")
		123:
			_set_stage(123, "ch12_code_review", "Meet Ivana in the Lead's Office to review a teammate's pull request.", "NPCIvanaDanielaGabani")
		13:
			_set_stage(13, "ch13_executive_presentation", "Present the completed Student Learning Portal to Julia Roa.", "NPCJuliaRoa")
		14:
			_set_stage(14, "ch14_conclusion", "Speak with Ivana in the Boardroom Corridor on Floor 3.", "NPCIvanaDanielaGabani", "3rd Floor")
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
	_face_npc_toward_player(npc)
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
			_set_stage(121, "ch12_production_incident", _server_terminal_text("triage_objective_text", "Access the primary console."), "ServerRackInteractable")
			sequence_running = false
			_restore_walk_hud()
		else:
			await _play_bubble(npc, [{"name": "Divino Cinaon", "text": "The traceback is waiting at the primary console. Interact with the rack when you're ready to review the incident and decide who owns the release."}])
			_set_stage(121, "ch12_production_incident", _server_terminal_text("triage_objective_text", "Access the primary console."), "ServerRackInteractable")
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
			if role == "ivana":
				await _chapter_14_epilogue(npc)
			elif role == "mario":
				await _play_bubble(npc, [
					{"name": "Mario Ellan Cruz", "text": "Whew... man, my heart was pounding the whole time!"},
					{"name": "Mario Ellan Cruz", "text": "When that board member demanded overnight AI grading, I almost folded."},
					{"name": "Mario Ellan Cruz", "text": "You stood your ground and defended the system architecture. That took real guts."},
					{"name": "Mario Ellan Cruz", "text": "Ivana is waiting for you in her office. Go see her—you earned this."}
				])
			elif role == "julia":
				await _play_bubble(npc, [
					{"name": "Julia Roa", "text": "Outstanding presentation earlier."},
					{"name": "Julia Roa", "text": "Standing up to executive pressure to protect software reliability is the hallmark of a true engineer."},
					{"name": "Julia Roa", "text": "Ivana wants to debrief with you in her office. Don't keep her waiting."}
				])
			elif role == "noriela":
				await _play_bubble(npc, [
					{"name": "Noriela Asahan", "text": "Congratulations on the successful launch presentation! The whole team is celebrating."}
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
			return role == "ivana" or role == "mario" or role == "julia" or role == "noriela"
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
			{"name": "August Creed", "text": "Mid-term evaluation milestone reached. 18 resolved tickets across QA, Frontend, and Backend. Zero unexcused absences."},
			{"name": "August Creed", "text": "Outstanding peer reviews from Celestina, Kenna, and Abel. 260 hours logged."}
		])
	else:
		await _play_dialogue([
			{"name": "Ivana Daniela Gabani", "text": "August sent up your evaluation file. Mid-term milestone reached with 260 hours logged across QA, Frontend, and Backend. Zero unexcused absences."}
		])

	# Ivana opens the defense
	await _play_dialogue([
		{"name": "Ivana Daniela Gabani", "text": "Let's see if the understanding matches the hours."},
		{"name": "Ivana Daniela Gabani", "text": "Six questions. Three I want answered now."}
	])

	# — Defense Question 1: Auth separation —
	var q1_text := "Question one. Why do we separate user authentication from the student profile model? What breaks if they're in the same table?"
	await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": q1_text}])
	accountability_choice_ui.call("show_choices", [
		"Because the auth user handles login security; the student profile holds academic data. Mixing them violates single responsibility and makes future role changes or multi-tenant schools impossible to manage cleanly.",
		"It's just convention. Django's built-in user model has fields we don't need for student records.",
		"So that QA can test each model independently without touching real credentials."
	], q1_text)
	var auth_choice: int = await accountability_choice_selected
	accountability_choice_ui.call("hide_choices")
	if player:
		player.can_move = false
	if auth_choice == 0:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Correct. Single responsibility isn't just a design philosophy—it protects every school's data when we onboard new clients."}])
	else:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Incorrect. The separation protects login security from academic data leaks and makes multi-tenant scaling possible. Remember that."}])

	# — Defense Question 2: N+1 queries —
	var q2_text := "Question two. Our student list view was loading 200 enrollment records. How do you prevent it from hitting the database 201 times?"
	await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": q2_text}])
	accountability_choice_ui.call("show_choices", [
		"Use select_related() for ForeignKey fields and prefetch_related() for ManyToMany—this tells Django to JOIN or batch the lookup in one query instead of one per record.",
		"Add a database index to the foreign key column so lookups are faster.",
		"Cache the queryset in Redis so the database is only queried once per session."
	], q2_text)
	var nplus1_choice: int = await accountability_choice_selected
	accountability_choice_ui.call("hide_choices")
	if player:
		player.can_move = false
	if nplus1_choice == 0:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Correct. select_related and prefetch_related are the first tools you reach for before any caching layer."}])
	else:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "Indexes help, but they don't solve N+1. select_related and prefetch_related collapse the round trips at the ORM level first."}])

	# — Defense Question 3: Malicious UUID —
	var q3_text := "Question three. An unauthenticated user sends a POST to /api/students/{uuid}/grade/ with a forged UUID. What stops them?"
	await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": q3_text}])
	accountability_choice_ui.call("show_choices", [
		"The view must check request.user.is_authenticated and verify the requesting user owns that student record before the queryset even executes. Server-side authorization, every time.",
		"UUIDs are hard to guess, so forged requests are statistically unlikely to match a real record.",
		"Our HTTPS certificate ensures requests are encrypted, so outsiders cannot see the UUID format."
	], q3_text)
	var uuid_choice: int = await accountability_choice_selected
	accountability_choice_ui.call("hide_choices")
	if player:
		player.can_move = false
	if uuid_choice == 0:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "That is the only correct answer. Encryption protects transit. Authorization protects the data. They are not the same thing."}])
	else:
		await _play_dialogue([{"name": "Ivana Daniela Gabani", "text": "UUIDs are not a security control—they are identifiers. Server-side authorization is what blocks unauthorized access, not entropy or encryption."}])

	var correct_count: int = (1 if auth_choice == 0 else 0) + (1 if nplus1_choice == 0 else 0) + (1 if uuid_choice == 0 else 0)
	var sign_off_text := ""
	match correct_count:
		3:
			sign_off_text = "Your technical performance evaluation is cleared with top marks. You defended enterprise architecture cleanly across authentication, query optimization, and permissions."
		2:
			sign_off_text = "You passed the technical evaluation, but keep your discipline sharp. One slip in a production codebase can create memory leaks or access bugs."
		1:
			sign_off_text = "You scraped by the minimum evaluation requirements today. In an enterprise system, guessing on queries or authorization creates severe liabilities. Review those fundamentals before the final release."
		_:
			sign_off_text = "I have severe concerns about your technical judgment today. You missed every core design check. I am signing off your raw attendance hours, but you must study our architecture standard before touching production code again."

	# Ivana signs off technical evaluation
	await _play_dialogue([
		{"name": "Ivana Daniela Gabani", "text": "When you walked through that door a few weeks ago, you looked terrified every time someone asked you a question—like you were constantly preparing to defend your thesis."},
		{"name": "Ivana Daniela Gabani", "text": "Today's answers show me which parts of your technical judgment are solid and which still need work."},
		{"name": "Ivana Daniela Gabani", "text": sign_off_text}
	])
	await _show_placeholder("Chapter 10 — OJT Evaluation Cleared", "Ivana and August sign the OJT Performance Evaluation Form.\n\n[Item: OJT Evaluation Cleared! High Rating Obtained.]")

	await _show_time_skip_card(
		"THE NEXT SPRINT — ENTERPRISE CRUNCH",
		"260 / 300 HOURS LOGGED",
		"The final stretch of your internship begins. With the 50,000-student portal deployment looming, you arrive at DJQ Corp wearing your green intern badge.\n\nFade in: Ground Floor Lobby. Kendra waves from reception.",
		true
	)
	get_tree().root.set_meta("ch3_graduation_return", true)
	_set_stage(11, "ch11_absorption", "Report to Kendra at reception.", "NPCKendraBarba", "Ground Floor")
	sequence_running = false
	_restore_walk_hud()
	_transition_to_story_destination(ground_floor_scene_path, graduation_reception_spawn_position)


func _chapter_11_offer(npc: Node2D) -> void:
	sequence_running = true
	_hide_walk_hud()
	if player:
		player.can_move = false

	await _show_story_cutscene("Chapter 11 — CUT_06: The Provisional Blue Badge", "Ivana's Floor 3 corner office. The player arrives wearing their green intern pass. Ivana slides a metallic Blue Developer Badge across the desk. Unknown to the player, Ivana is quietly testing whether this intern can carry developer responsibilities.", [
		{"name": "Player", "text": "You wanted to see me, Ma'am Ivana? Is there an issue with my sprint tasks?"},
		{"name": "Ivana Daniela Gabani", "text": "Tomorrow is the enterprise production rollout of the Student Learning Portal for 50,000 students. We are short-handed on Floor 2."},
		{"name": "Player", "text": "Ma'am... that's a Blue Badge. That's for permanent staff."},
		{"name": "Ivana Daniela Gabani", "text": "It's provisional access. It unlocks Floor 2 DevOps and the Server Room. I need all hands on deck for this release."},
		{"name": "Ivana Daniela Gabani", "text": "A blue badge isn't a trophy. It means when production burns, you don't run or point fingers—you fix it and stand behind your code. Don't let this access go to your head. Show me you can handle the responsibility."},
		{"name": "Player", "text": "Understood, Ma'am Ivana. I won't let the team down."}
	])

	await _award_blue_badge()
	await _show_time_skip_card(
		"TOMORROW — 50,000-STUDENT RELEASE",
		"ROLE: PROVISIONAL DEVELOPER",
		"Carrying provisional Blue Badge clearance to Floor 2 and the Server Room, you step into the critical release sprint. Ivana is watching closely to see how you carry developer responsibility under real pressure.",
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
		get_tree().root.set_meta("ch3_restore_walk_hud_after_transition", true)
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
	var blue_badge_icon = load("res://Textures/Items/color_blue_ID_pixelart.png")
	var item_popup := get_node_or_null("/root/ItemPopup")
	if item_popup and item_popup.has_method("show_item"):
		await item_popup.show_item(
			"blue_junior_developer_badge",
			"Blue Badge — Provisional Developer Clearance",
			"Provisional access to Floor 2 and the Server Room for the 50,000-student release sprint.",
			blue_badge_icon
		)
	else:
		inventory.add_item(
			"blue_junior_developer_badge",
			"Blue Badge — Provisional Developer Clearance",
			"Provisional access to Floor 2 and the Server Room for the 50,000-student release sprint.",
			blue_badge_icon
		)


func _pr_42_review_data() -> Dictionary:
	return {
		"pr_number": 42,
		"pr_title": "feat(enrollment): Add student enrollment tracking timestamp",
		"author_name": "You",
		"author_role": "Junior Developer",
		"branch_target": "main ← feature/student-enrollment",
		"description": "Completes and rebases the student enrollment tracking feature originally started on feature/student-enrollment by a previous intern who withdrew from the project. Adds enrolled_at timestamp field to StudentEnrollment. Staging pipeline tests passed.",
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


func _on_server_root_cause_acknowledged() -> void:
	server_root_cause_acknowledged.emit()


func _on_server_migration_requested() -> void:
	server_migration_requested.emit()


func _on_server_terminal_continued() -> void:
	server_terminal_continued.emit()


func _server_terminal_text(property_name: String, fallback: String = "") -> String:
	if server_rack_terminal_ui == null:
		return fallback
	var value: Variant = server_rack_terminal_ui.get(property_name)
	return fallback if value == null else str(value)


func _handle_server_console_interaction() -> void:
	if sequence_running or server_rack == null:
		return
	sequence_running = true
	_hide_walk_hud()
	if player:
		player.can_move = false
	if server_incident_phase == 0:
		var divino := get_parent().find_child("NPCDivinoCinaon", true, false) as Node2D
		await _guide_server_incident_diagnosis()
		await _play_terminal_divino_dialogue(server_rack_terminal_ui.get("step3_dialogue"))
		var accountability_choice := await _ask_accountability_choice()
		while accountability_choice != 2:
			if accountability_choice == 0 or accountability_choice == 1:
				# Await the entire failure sequence, including the HR cutscene and retry banner.
				await _handle_accountability_failure(divino, accountability_choice)
				await _guide_server_incident_diagnosis()
				await _play_terminal_divino_dialogue(server_rack_terminal_ui.get("step3_dialogue"))
			else:
				await _play_terminal_divino_dialogue(server_rack_terminal_ui.get("no_response_dialogue"))
				await _play_terminal_divino_dialogue(server_rack_terminal_ui.get("step3_dialogue"))
			accountability_choice = await _ask_accountability_choice()
		server_incident_phase = 1
		get_tree().root.set_meta("ch3_server_incident_phase", server_incident_phase)
		server_rack.set("interaction_text", _server_terminal_text("migration_interaction_prompt"))
		var rack_label := server_rack.get_node_or_null("Label") as Label
		if rack_label:
			rack_label.text = _server_terminal_text("migration_interaction_prompt")
		await _run_server_migration()
	else:
		await _run_server_migration()
	sequence_running = false
	_restore_walk_hud()


func _guide_server_incident_diagnosis() -> void:
	if server_rack_terminal_ui == null:
		return
	server_rack_terminal_ui.call("present_traceback")
	await _play_terminal_divino_dialogue(server_rack_terminal_ui.get("step1_dialogue"))
	await _run_terminal_spotlight([
		{"text": server_rack_terminal_ui.get("spotlight_traceback_text"), "highlight_node": server_rack_terminal_ui.get_node("Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/OutputPanel/OutputMargin/OutputContent/OutputLabel"), "tooltip_side": "top"}
	])
	await server_traceback_acknowledged

	server_rack_terminal_ui.call("present_root_cause")
	await _play_terminal_divino_dialogue(server_rack_terminal_ui.get("step2_dialogue"))
	await _run_terminal_spotlight([
		{"text": server_rack_terminal_ui.get("spotlight_git_blame_text"), "highlight_node": server_rack_terminal_ui.get_node("Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/OutputPanel/OutputMargin/OutputContent/RootCauseSplit/GitBlamePanel"), "tooltip_side": "bottom"},
		{"text": server_rack_terminal_ui.get("spotlight_migration_status_text"), "highlight_node": server_rack_terminal_ui.get_node("Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/OutputPanel/OutputMargin/OutputContent/RootCauseSplit/MigrationStatusPanel"), "tooltip_side": "bottom"}
	])
	await server_root_cause_acknowledged


func _run_server_migration() -> void:
	if server_rack_terminal_ui == null:
		return
	server_rack_terminal_ui.call("present_authorization")
	await _play_terminal_divino_dialogue(server_rack_terminal_ui.get("step4_dialogue"))
	server_rack_terminal_ui.call("present_migration_prompt")
	await _run_terminal_spotlight([
		{"text": server_rack_terminal_ui.get("spotlight_command_text"), "highlight_node": server_rack_terminal_ui.get_node("Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/CommandRow/CommandMargin/CommandRowContents/CommandLineEdit"), "tooltip_side": "top"}
	])
	await server_migration_requested
	server_rack.call("resolve_emergency")
	server_rack_terminal_ui.call("present_success")
	await server_terminal_continued
	await _play_terminal_divino_dialogue(server_rack_terminal_ui.get("migration_complete_dialogue"))
	_set_stage(122, "ch12_secrets_audit", "Go to IT Storage with Tercio for a configuration security check.", "NPCTercioMateoRamos")
	server_incident_phase = 2
	get_tree().root.set_meta("ch3_server_incident_phase", server_incident_phase)
	get_tree().root.set_meta("ch3_server_alert_started", false)


func _play_terminal_divino_dialogue(lines: Variant) -> void:
	if dialogue_box == null or not (lines is Array) or lines.is_empty():
		return
	var original_layer := dialogue_box.layer
	dialogue_box.layer = maxi(dialogue_box.layer, 130)
	var dialogue_lines: Array = lines.duplicate(true)
	# Do NOT inject a portrait — Divino appears via bubble/NPC sprite, not inside the dialogue box.
	dialogue_box.start(dialogue_lines)
	await dialogue_box.dialogue_finished
	dialogue_box.layer = original_layer
	if player:
		player.can_move = false


func _run_terminal_spotlight(steps: Array) -> void:
	if steps.is_empty():
		return
	var tutorial_overlay: Variant = TUTORIAL_OVERLAY_SCRIPT.new()
	get_parent().add_child(tutorial_overlay)
	tutorial_overlay.call("start_tutorial", steps)
	await tutorial_overlay.tutorial_finished
	tutorial_overlay.queue_free()


func _on_coffee_brewed() -> void:
	get_tree().root.set_meta("ch3_coffee_run_available", true)


func _ask_accountability_choice() -> int:
	if accountability_choice_ui == null:
		return -1
	var choices: Array = server_rack_terminal_ui.get("accountability_choices").duplicate()
	choices.append(server_rack_terminal_ui.get("no_response_choice_label"))
	accountability_choice_ui.call("show_choices", choices, _server_terminal_text("incident_response_question_text", "How do you address the missing migration?"))
	var buttons := accountability_choice_ui.get_node_or_null("CenterContainer/ChoicePanel/MarginContainer/ChoicesBox/Buttons") as VBoxContainer
	if buttons:
		for choice_button in buttons.get_children():
			if choice_button is Button:
				var button := choice_button as Button
				if button.text == str(server_rack_terminal_ui.get("no_response_choice_label")):
					button.hide()
	var selected: int = await accountability_choice_selected
	accountability_choice_ui.call("hide_choices")
	if player:
		player.can_move = false
	# The panel times out by selecting the final index. Use a hidden no-answer
	# sentinel so a timeout can never be mistaken for the ownership response.
	return -1 if selected == 3 else selected


func _on_accountability_choice_selected(choice_index: int) -> void:
	accountability_choice_selected.emit(choice_index)


func _handle_accountability_failure(divino: Node2D, choice: int) -> void:
	if choice != 0 and choice != 1:
		return
	var failure_dialogue: Array = server_rack_terminal_ui.get("choice_a_failure_dialogue") if choice == 0 else server_rack_terminal_ui.get("choice_b_failure_dialogue")
	# Cover live gameplay before the blame response dialogue plays.
	if player:
		player.can_move = false
	overlay_layer.visible = true
	overlay.color = placeholder_overlay_color
	overlay_title.modulate.a = 1.0
	overlay_body.modulate.a = 1.0
	overlay_title.text = "Chapter 12 — Incident Accountability"
	overlay_body.text = "CUT — Blame Deflection\n\nThe intern shifts responsibility to a teammate instead of owning the missing migration.\n\n[Press Space to continue]"
	await get_tree().process_frame
	while not Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	# Overlay stays visible (hides gameplay) while the blame dialogue plays.
	await _play_terminal_divino_dialogue(failure_dialogue)
	# Fade out before the HR story cutscene takes over.
	var _blame_fade := create_tween().set_parallel(true)
	_blame_fade.tween_property(overlay, "color:a", 0.0, 0.35)
	_blame_fade.tween_property(overlay_title, "modulate:a", 0.0, 0.35)
	_blame_fade.tween_property(overlay_body, "modulate:a", 0.0, 0.35)
	await _blame_fade.finished
	overlay_layer.visible = false
	overlay_title.modulate.a = 1.0
	overlay_body.modulate.a = 1.0

	var hr_dialogue: Array = server_rack_terminal_ui.get("hr_cutscene_dialogue")
	await _show_story_cutscene(
		str(server_rack_terminal_ui.get("hr_cutscene_title")),
		str(server_rack_terminal_ui.get("hr_cutscene_visual")),
		hr_dialogue
	)
	var exit_dialogue: Array = server_rack_terminal_ui.get("exit_cutscene_dialogue")
	await _show_story_cutscene(
		str(server_rack_terminal_ui.get("exit_cutscene_title")),
		str(server_rack_terminal_ui.get("exit_cutscene_visual")),
		exit_dialogue
	)

	var fail_ui := FAILURE_SCREEN_SCENE.instantiate() as CanvasLayer
	fail_ui.layer = 120
	get_parent().add_child(fail_ui)
	await get_tree().process_frame
	fail_ui.call(
		"show_failure",
		server_rack_terminal_ui.get("failure_screen_title"),
		server_rack_terminal_ui.get("failure_screen_quote"),
		server_rack_terminal_ui.get("failure_screen_description"),
		server_rack_terminal_ui.get("failure_screen_retry_label")
	)
	fail_ui.visible = true
	var retry_button := fail_ui.get_node_or_null("Screen/CenterContainer/VBox/RetryButton") as Button
	if retry_button:
		retry_button.grab_focus()
	await fail_ui.retry_pressed
	fail_ui.queue_free()


func _chapter_12_secrets(npc: Node2D) -> void:
	sequence_running = true
	_hide_walk_hud()
	if player:
		player.can_move = false
	var divino := get_parent().find_child("NPCDivinoCinaon", true, false) as Node2D
	var server_room_door := get_parent().find_child("ServerRoomSidewayRightGlassDoor1", true, false) as Node
	var it_storage_door := get_parent().find_child("ITStorageSlidingDoor", true, false) as Node

	if divino:
		# 1. Server room exit door interaction
		var server_door_is_open := server_room_door != null and bool(server_room_door.get("is_door_open"))
		if not server_door_is_open:
			# Walk Divino up to the server door trigger zone
			await _walk_divino_to(Vector2(-146.0, 75.0))
			if server_room_door:
				if server_room_door.has_method("set_badge_access_override"):
					server_room_door.call("set_badge_access_override", true)
				if server_room_door.has_method("unlock"):
					server_room_door.call("unlock")
				if server_room_door.has_method("interact"):
					server_room_door.call("interact")
				var door_sprite := server_room_door.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
				if door_sprite:
					while bool(server_room_door.get("is_animating")):
						await door_sprite.animation_looped
				await get_tree().create_timer(0.15).timeout

		# 2. Walk through server door and along hallway toward IT Storage door
		await _walk_divino_to(Vector2(64.0, 75.0))
		await _walk_divino_to(Vector2(64.0, 15.0))

		# 3. IT Storage sliding door interaction (door position is Vector2(64, -30))
		var it_door_is_open := it_storage_door != null and bool(it_storage_door.get("is_door_open"))
		if not it_door_is_open and it_storage_door:
			if it_storage_door.has_method("set_badge_access_override"):
				it_storage_door.call("set_badge_access_override", true)
			if it_storage_door.has_method("unlock"):
				it_storage_door.call("unlock")
			if it_storage_door.has_method("interact"):
				it_storage_door.call("interact")
			var it_door_sprite := it_storage_door.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if it_door_sprite:
				while bool(it_storage_door.get("is_animating")):
					await it_door_sprite.animation_looped
			await get_tree().create_timer(0.15).timeout

		# 4. Walk through IT Storage door and up to Tercio
		await _walk_divino_to(Vector2(64.0, -93.0))
		await _walk_divino_to(Vector2(110.0, -93.0), "up")
		_set_npc_facing(divino, "up")

		# Close IT Storage door behind him
		if it_storage_door and bool(it_storage_door.get("is_door_open")):
			if it_storage_door.has_method("interact"):
				it_storage_door.call("interact")

	await _play_bubble(npc, [
		{"name": "Tercio Mateo Ramos", "text": "Divino, we traced an AWS S3 secret key in the repository history. It was committed in settings.py three commits ago."},
		{"name": "Tercio Mateo Ramos", "text": "It was never public, but anyone with internal repository access could recover it."}
	])
	if divino:
		await _play_bubble(divino, [
			{"name": "Divino Cinaon", "text": "Treat the exposed credential as compromised. Invalidate it on AWS, then move the replacement into a secure .env file."},
			{"name": "Divino Cinaon", "text": "After that, clean the repository history and verify the old key no longer works."}
		])
	else:
		await _play_dialogue([
			{"name": "Divino Cinaon", "text": "Treat the exposed credential as compromised. Invalidate it on AWS and move the replacement to a secure .env file."},
			{"name": "Divino Cinaon", "text": "Then clean the repository history and verify the old key no longer works."}
		])
	if overlay_layer:
		overlay_layer.visible = true
		overlay.color = Color(0.015, 0.02, 0.035, 0.0)
		var fade_to_black := create_tween()
		fade_to_black.tween_property(overlay, "color:a", 1.0, 0.55)
		await fade_to_black.finished
	if divino:
		divino.global_position = Vector2(-242.0, 75.0)
		_set_npc_facing(divino, "down")
	if overlay_layer:
		var fade_back_in := create_tween()
		fade_back_in.tween_property(overlay, "color:a", 0.0, 0.55)
		await fade_back_in.finished
		overlay_layer.visible = false
	await _show_placeholder("Chapter 12 - Secrets Audit", "Gameplay Placeholder\nReplace the exposed configuration value with an environment variable. Verify the safe configuration and check that no credential remains in public project files.")
	_set_stage(123, "ch12_code_review", "Meet Ivana in the Lead's Office to review a teammate's pull request.", "NPCIvanaDanielaGabani")
	sequence_running = false
	_restore_walk_hud()


func _walk_divino_to(target: Vector2, facing_override: String = "") -> void:
	var divino := get_parent().find_child("NPCDivinoCinaon", true, false) as Node2D
	if divino == null:
		return
	var movement := target - divino.global_position
	var direction := facing_override
	if direction.is_empty():
		if absf(movement.x) > absf(movement.y):
			direction = "right" if movement.x >= 0.0 else "left"
		else:
			direction = "down" if movement.y >= 0.0 else "up"
	var sprite := divino.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("walking_" + direction):
		sprite.play("walking_" + direction)
	var duration := maxf(0.25, divino.global_position.distance_to(target) / 145.0)
	var tween := create_tween()
	tween.tween_property(divino, "global_position", target, duration).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	_set_npc_facing(divino, direction)


func _set_npc_facing(npc: Node2D, direction: String) -> void:
	if npc == null:
		return
	var sprite := npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle_" + direction):
		sprite.play("idle_" + direction)


func _chapter_12_code_review(npc: Node2D) -> void:
	sequence_running = true
	var mario := get_parent().find_child("NPCMarioEllanCruz", true, false) as Node2D
	if mario:
		mario.visible = false
		_sync_npc_collision_tree(mario, false)
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
		"Following a grueling night restoring production, the system is stable and passing all checks. Now, company leadership and university trustees convene in the Penthouse Boardroom to review system architecture and discuss Sprint 2.\n\nFade in: Floor 3 Executive Boardroom corridor.",
		true
	)
	# Teleport player while screen is still completely black
	if player:
		player.global_position = Vector2(1165.0, 64.0)
		if "current_dir" in player:
			player.current_dir = "right"
		if player.has_method("play_idle_animation"):
			player.play_idle_animation("right")

	# Fade in smoothly from black at the new position
	var fade_in := create_tween()
	fade_in.tween_property(overlay, "color:a", 0.0, 0.6)
	await fade_in.finished
	if overlay_layer:
		overlay_layer.visible = false
	overlay_title.modulate.a = 1.0
	overlay_body.modulate.a = 1.0

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
	get_tree().root.set_meta("ch3_boardroom_attendees_arrived", false)
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
		{"name": "Julia Roa", "text": "Mario and Ivana are on their way here. Give them a couple of minutes to settle in."},
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

	# Under darkness: move Mario and Ivana into boardroom seats, and player to presentation spot.
	# Boardroom: Rect2(1216, -96, 481, 320). Julia at (1477, -58).
	# Mario sits at the near side of the conference table, looking nervous.
	if mario_f3:
		mario_f3.global_position = Vector2(1423.0, 121.0)
		mario_f3.visible = true
		_sync_npc_collision_tree(mario_f3, true)
		var mario_sprite := mario_f3.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if mario_sprite and mario_sprite.sprite_frames and mario_sprite.sprite_frames.has_animation("idle_up"):
			mario_sprite.play("idle_up")
	get_tree().root.set_meta("ch3_boardroom_attendees_arrived", true)
	# Ivana moves from her corner office into the boardroom, standing along the far wall.
	if ivana:
		ivana.global_position = Vector2(1649.0, 14.0)
		var ivana_sprite := ivana.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if ivana_sprite and ivana_sprite.sprite_frames and ivana_sprite.sprite_frames.has_animation("idle_left"):
			ivana_sprite.play("idle_left")

	# Position player at the presentation display facing down
	if player:
		player.global_position = Vector2(1429.0, -58.0)
		if "current_dir" in player:
			player.current_dir = "down"
		if player.has_method("play_idle_animation"):
			player.play_idle_animation("down")

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
		"[ART PLACEHOLDER — Boardroom Presentation]

Setting: Sunlit Floor 3 penthouse boardroom. Long glass table, university trustees and board executives seated. Julia Roa at the head. Mario and Ivana stand along the side wall.

Shot: The intern stands at the presentation display, clicker in hand. Architecture diagram projected on-screen. Confident posture; room is attentive.

Note to artist: This cutscene needs a full illustrated panel or animated sequence showing the intern mid-presentation. Dialogue follows immediately after this card.",
		[
			{"name": "You", "text": "Our portal combines a secure Django API, a responsive frontend, automated tests, and a verified release process. 50,000 simulated student logins with sub-150 millisecond response times and zero data leakage."},
			{"name": "Board Executive", "text": "Yes, yes, the architecture is lovely. But the school superintendent just called me. They want an automated AI essay grading engine and custom PDF report exports built and deployed by tomorrow morning's press conference. Can we guarantee that goes live tomorrow?"},
			{"name": "Mario Ellan Cruz", "text": "W-well, sir... we could try to push an overnight patch—"}
		]
	)

	var selected := await _ask_scope_choice()
	while selected != 2:
		if selected == 0:
			await _show_story_cutscene("Chapter 13 — CUT_08B: The Midnight Crash",
				"Dimly lit office at 4:00 AM. Stack traces glow red. Morning arrives: 50,000 students log in simultaneously. An unvetted PDF generator leaks memory and crashes the portal during the superintendent's live press conference.",
				[
					{"name": "You", "text": "I pushed the endpoints at 4:30 AM... but they were never load-tested."},
					{"name": "Board Executive", "text": "The entire portal is down on live television! The superintendent is furious!"},
					{"name": "Ivana Daniela Gabani", "text": "Promising overnight delivery without QA is how production dies. We have to roll back."}
				]
			)
			await _show_scope_failure_screen(
				"LAUNCH DAY OUTAGE",
				"Saying yes to impossible deadlines isn't dedication—it's negligence.",
				"Deploying unscoped features without testing caused critical memory leaks and brought down production for 50,000 students during the superintendent's press conference. Protect system stability first.",
				"Reconsider Boardroom Pitch"
			)
		elif selected == 1:
			await _show_story_cutscene("Chapter 13 — CUT_08C: Executive Impasse",
				"The boardroom atmosphere turns hostile. The board executive leans forward with crossed arms. Julia Roa frowns with quiet concern. Ivana steps in to repair the damage.",
				[
					{"name": "You", "text": "No. We can't do that."},
					{"name": "Board Executive", "text": "Then why are we partnering with DJQ Corp if basic requests are met with a brick wall?"},
					{"name": "Ivana Daniela Gabani", "text": "A flat refusal without explaining risks or offering alternatives destroys stakeholder trust. We must guide clients, not dismiss them."}
				]
			)
			await _show_scope_failure_screen(
				"STAKEHOLDER DEADLOCK",
				"Developers are problem-solvers, not gatekeepers.",
				"Shutting down client demands without explaining trade-offs or offering an alternative roadmap damages executive trust and risks contract cancellation.",
				"Reconsider Boardroom Pitch"
			)
		else:
			# An unexpected result is treated as a failed attempt, then the prompt is shown again.
			await _show_scope_failure_screen(
				"DECISION NOT RECORDED",
				"Choose a clear release plan before making a commitment.",
				"The board needs a clear response that protects the launch and gives the requested work a realistic plan.",
				"Reconsider Boardroom Pitch"
			)
		await _play_dialogue([{"name": "Board Executive", "text": "I'll ask once more: can we guarantee those AI grading and export features go live tomorrow morning?"}])
		selected = await _ask_scope_choice()

	# Only the scoped plan reaches Julia's successful verdict.
	await _play_dialogue([
		{"name": "You", "text": "With respect, sir—no. Deploying unvetted AI endpoints and export scripts on launch morning bypasses QA and risks memory leaks for 50,000 students. We guarantee a flawless launch tomorrow and will deliver the export features in Sprint 2 with full security testing."}
	])
	await _show_story_cutscene("Chapter 13 — Julia Roa's Verdict",
		"Julia Roa leans back in her tall executive chair, a radiant and deeply impressed smile breaking across her face. The aggressive board executive sits back down, chastened. Ivana gives an imperceptible nod of supreme respect to the Player.",
		[
			{"name": "Julia Roa", "text": "A web developer who protects our users and product stability instead of saying yes to catastrophic crunch. That is true technical leadership."},
			{"name": "Julia Roa", "text": "Launch tomorrow as scheduled with the vetted architecture. Meeting adjourned."},
			{"name": "Board Executive", "text": "...Hmph. Fine. Deliver the flawless launch first. But we expect Sprint 2 on schedule."},
			{"name": "Mario Ellan Cruz", "text": "Y-yes, sir! We will make sure Sprint 2 is fully tested and scoped!"},
			{"name": "Julia Roa", "text": "Thank you, everyone. Great work today. Let's make tomorrow count."}
		]
	)

	# Aftermath placeholder cutscene card: Boardroom adjourns
	await _show_story_cutscene("Chapter 13 — CUT_08D: Adjournment & Boardroom Aftermath",
		"[ART PLACEHOLDER — Boardroom Adjournment]\n\nSetting: Executive Boardroom, morning light washing over the conference table.\n\nBoard trustees gather their briefing binders and exit through the frosted glass doors, chatting in approval.\n\nJulia Roa gives a warm nod of acknowledgment from the head of the table. Mario lets out an audible sigh of immense relief, patting the Player's shoulder. Ivana packs her laptop, signaling toward her private office down the corridor.",
		[
			{"name": "Narration", "text": "The tension that gripped the room dissipates. Board members nod respectfully on their way out."},
			{"name": "Mario Ellan Cruz", "text": "I can't believe we pulled that off... my hands were shaking under the table."},
			{"name": "Julia Roa", "text": "You held the line, intern. A lot of engineers cave when executives push like that."},
			{"name": "Ivana Daniela Gabani", "text": "Good work today. Both of you."},
			{"name": "Ivana Daniela Gabani", "text": "Meet me in my office once the floor clears. There's one more thing to settle."},
			{"name": "Player", "text": "Yes, Ma'am Ivana. Right behind you."},
			{"name": "Narration", "text": "The portal launch is protected, and DJQ Corp's engineering integrity remains uncompromised."}
		]
	)

	# — Post-verdict transition: fade to black, reposition Ivana to her corner office, fade in. —
	# Ivana needs to be at her desk (Vector2(912, -438)) for the certificate handoff in ch14.
	var ivana_post := get_parent().find_child("NPCIvanaDanielaGabani", true, false) as Node2D
	if overlay_layer:
		overlay_layer.visible = true
		overlay.color.a = 0.0
		overlay_title.modulate.a = 0.0
		overlay_body.modulate.a = 0.0
	var fade_to_black2 := create_tween()
	fade_to_black2.tween_property(overlay, "color:a", 1.0, 0.6)
	await fade_to_black2.finished
	# Move Ivana to her corner office under darkness.
	if ivana_post:
		ivana_post.global_position = Vector2(912.0, -438.0)
		var ivana_sprite2 := ivana_post.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if ivana_sprite2 and ivana_sprite2.sprite_frames and ivana_sprite2.sprite_frames.has_animation("idle_down"):
			ivana_sprite2.play("idle_down")
	await get_tree().create_timer(0.3).timeout
	var fade_in2 := create_tween()
	fade_in2.tween_property(overlay, "color:a", 0.0, 0.6)
	await fade_in2.finished
	if overlay_layer:
		overlay_layer.visible = false
	_set_stage(14, "ch14_conclusion", "Speak with Ivana in her office on Floor 3.", "NPCIvanaDanielaGabani", "3rd Floor")
	sequence_running = false
	_restore_walk_hud()


func _show_scope_failure_screen(title: String, quote: String, explanation: String, retry_label: String) -> void:
	var fail_ui := FAILURE_SCREEN_SCENE.instantiate() as CanvasLayer
	fail_ui.layer = 120
	get_parent().add_child(fail_ui)
	await get_tree().process_frame
	fail_ui.call("show_failure", title, quote, explanation, retry_label)
	fail_ui.visible = true
	var retry_button := fail_ui.get_node_or_null("Screen/CenterContainer/VBox/RetryButton") as Button
	if retry_button:
		retry_button.grab_focus()
	await fail_ui.retry_pressed
	fail_ui.queue_free()


func _ask_scope_choice() -> int:
	if accountability_choice_ui == null:
		return 2
	accountability_choice_ui.call("show_choices", [
		"Agree to deliver both features overnight, without changing the launch plan.",
		"Reject the request without discussing scope, risk, or alternatives.",
		"Protect launch; estimate the work and schedule it for Sprint 2 with QA and security testing."
	], "Can we guarantee those AI grading and export features go live tomorrow morning?")
	var selected: int = await accountability_choice_selected
	accountability_choice_ui.call("hide_choices")
	if player:
		player.can_move = false
	return selected


func _chapter_14_epilogue(npc: Node2D) -> void:
	sequence_running = true
	_hide_walk_hud()
	if player:
		player.can_move = false

	# Dialogue with Ivana debriefing in her office
	await _play_bubble(npc, [
		{"name": "Ivana Daniela Gabani", "text": "Sit down. Take a breath."},
		{"name": "Ivana Daniela Gabani", "text": "300 hours. You arrived here with theory from your college classes, but you leave with production experience."},
		{"name": "Ivana Daniela Gabani", "text": "You handled incident triage, resolved security vulnerabilities, reviewed real code, and held the line before executive stakeholders."},
		{"name": "Player", "text": "Thank you, Ivana. I couldn't have navigated all of that without your guidance."},
		{"name": "Ivana Daniela Gabani", "text": "You did the work. Now, there's one final formality."}
	])

	# Cutscene card transitioning from office debrief to graduation rites
	await _show_story_cutscene("Chapter 14 — CUT_09A: Completion of OJT & University Exit",
		"[ART PLACEHOLDER — OJT Completion Certificate & Offer]\n\nSetting: Lead's Office, sun streaming through floor-to-ceiling glass.\n\nIvana hands over the sealed certificate confirming 300 completed internship hours alongside an official Junior Developer employment offer from DJQ Corp.\n\nPlayer holds both documents. Outside, the campus auditorium prepares for commencement exercises.",
		[
			{"name": "Ivana Daniela Gabani", "text": "Here is your formal certificate completing your 300 OJT hours, alongside your official employment offer as a Junior Developer."},
			{"name": "Ivana Daniela Gabani", "text": "Clear your school credentials and walk that stage. Your adviser and family are waiting."},
			{"name": "Player", "text": "Understood. I'll finish graduation rites and report back ready to build."}
		]
	)

	# Smooth transition to graduation ceremony scene
	var graduation_scene_path := "res://Scenes/Ch3/Cutscenes/college_graduation_after_ojt_scene.tscn"
	var scene_transition := get_node_or_null("/root/SceneTransition")
	if scene_transition and scene_transition.has_method("transition_to_scene"):
		scene_transition.call("transition_to_scene", graduation_scene_path, Vector2(397.0, 266.0), "none")
	else:
		get_tree().change_scene_to_file(graduation_scene_path)


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
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	if player:
		player.can_move = false
	overlay_layer.visible = true
	overlay.color = placeholder_overlay_color
	overlay_title.modulate.a = 1.0
	overlay_body.modulate.a = 1.0
	overlay_title.text = title
	overlay_body.text = visual + "\n\n[Press Space to continue]"
	await get_tree().process_frame
	while not Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame

	# If lines are provided, play dialogue on top of the placeholder before fading it out
	if not lines.is_empty():
		var original_layer := dialogue_box.layer if dialogue_box else 10
		if dialogue_box:
			dialogue_box.layer = maxi(dialogue_box.layer, 130)
		await _play_dialogue(lines)
		if dialogue_box:
			dialogue_box.layer = original_layer

	var fade := create_tween().set_parallel(true)
	fade.tween_property(overlay, "color:a", 0.0, 0.35)
	fade.tween_property(overlay_title, "modulate:a", 0.0, 0.35)
	fade.tween_property(overlay_body, "modulate:a", 0.0, 0.35)
	await fade.finished
	overlay_layer.visible = false
	overlay_title.modulate.a = 1.0
	overlay_body.modulate.a = 1.0


func _show_panel(title: String, body: String) -> void:
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	if player:
		player.can_move = false
	overlay_layer.visible = true
	overlay.color = placeholder_overlay_color
	overlay_title.modulate.a = 1.0
	overlay_body.modulate.a = 1.0
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
	if player and not sequence_running:
		player.can_move = true


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
	if player and not sequence_running:
		player.can_move = true
		_restore_walk_hud()


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
