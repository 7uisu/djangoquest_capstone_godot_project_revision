extends Node2D

# ---------------------------------------------------------------------------
# Story Ending Office Cutscene Controller
# Sequence:
# 1. Player arrives at elevator x 671, y 9. Opening reflection.
# 2. August walks (1066,73) -> (874,73), calls out.
# 3. August walks to (671,73) -> (671,49), donut & welcoming dialogue.
# 4. August walks to (303,49), teleports to QA room (-80,-59) looking up;
#    Celestina looks left.
# 5. Player reflection: check locker & tell Kendra about donuts.
# 6. Player walks (671,9) -> (671,97) -> (607,97) -> (607,241).
# 7. Player talks to Kendra about donuts. Kendra politely declines.
# 8. Player moves to (695,241). Simultaneously, New Recruit walks
#    (607,584) -> (607,387) looking up.
# 9. New recruit asks Kendra about the OJT interview.
# 10. Player walks to (687,361) looking left, offers to guide them.
# 11. Recruit moves to (607,361) -> (647,361).
# 12. Both backtrack toward elevator. Screen fades to black during walk.
# 13. Placeholder cutscene card + dialogue.
# 14. Transition to res://Scenes/End Game Office/office_floor_ground.tscn.
# ---------------------------------------------------------------------------

const CHAT_BUBBLE_SCENE := preload("res://Scenes/UI/chat_bubble.tscn")
const DIALOGUE_BOX_SCENE := preload("res://Scenes/UI/dialogue_box.tscn")

const PLACEHOLDER_COLOR := Color(0.055, 0.075, 0.12, 0.97)
const TITLE_COLOR       := Color(0.91, 0.94, 1.0)
const BODY_COLOR        := Color(0.8, 0.86, 0.97)

@onready var player: CharacterBody2D       = get_node_or_null("YSortLayer/Player") as CharacterBody2D
@onready var august: Node2D               = get_node_or_null("YSortLayer/NPCAugustCreed")
@onready var celestina: Node2D            = get_node_or_null("YSortLayer/NPCCelestinaBalon")
@onready var kendra: Node2D               = get_node_or_null("YSortLayer/NPCKendraBarba")
@onready var new_recruit: Node2D          = get_node_or_null("YSortLayer/NewRecruitNPC")
@onready var hallway_door: Node2D         = get_node_or_null("YSortLayer/ReceptionistAndHallwaySlidingDoor")
@onready var entrance_door: Node2D        = get_node_or_null("YSortLayer/EntranceDoorSlidingDoor2")
@onready var sprint_door: Node2D          = get_node_or_null("SprintRoomSidewayRightDoor2")

var dialogue_box: CanvasLayer
var cutscene_active: bool = true
var cutscene_camera: Camera2D

# Placeholder overlay nodes
var _overlay_layer: CanvasLayer
var _overlay_bg: ColorRect
var _overlay_title: Label
var _overlay_body: Label

# Persistent screen fade layer
var _fade_layer: CanvasLayer
var _fade_cover: ColorRect


func _physics_process(_delta: float) -> void:
	if cutscene_active and is_instance_valid(player):
		player.can_move = false
		player.velocity = Vector2.ZERO
		if "can_interact" in player:
			player.can_interact = false


func _ready() -> void:
	# 1. Reset quest suppression
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr and quest_mgr.has_method("reset_suppression"):
		quest_mgr.reset_suppression()

	# 2. Grant full junior developer credentials
	var data: Node = get_node_or_null("/root/CharacterData")
	if data != null:
		data.ch3_has_green_badge = true
		data.ch3_has_blue_badge = true

	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv != null:
		if not inv.has_item("blue_junior_developer_badge"):
			inv.add_item("blue_junior_developer_badge", "Blue Junior Developer Badge", "Permanent Junior Developer Badge.")
		if not inv.has_item("green_ojt_badge"):
			inv.add_item("green_ojt_badge", "Green OJT Badge", "Office OJT Badge.")

	# 3. Disable ordinary NPC trigger areas for scripted cutscene
	_disable_all_npc_interactions()
	if is_instance_valid(sprint_door) and sprint_door.has_method("unlock"):
		sprint_door.unlock()

	# 4. Setup Dialogue Box (layer 130)
	dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as CanvasLayer
	dialogue_box.name = "StoryEndingDialogueBox"
	dialogue_box.suppress_player_unlock = true
	dialogue_box.layer = 130
	add_child(dialogue_box)

	# 5. Build overlay placeholder (layer 95)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "EndingPlaceholderLayer"
	_overlay_layer.layer = 95
	add_child(_overlay_layer)

	_overlay_bg = ColorRect.new()
	_overlay_bg.name = "PlaceholderBackground"
	_overlay_bg.color = PLACEHOLDER_COLOR
	_overlay_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_overlay_bg)

	_overlay_title = Label.new()
	_overlay_title.name = "BeatTitle"
	_overlay_title.anchor_left   = 0.08
	_overlay_title.anchor_top    = 0.12
	_overlay_title.anchor_right  = 0.92
	_overlay_title.anchor_bottom = 0.28
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_overlay_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_title.add_theme_font_size_override("font_size", 28)
	_overlay_title.add_theme_color_override("font_color", TITLE_COLOR)
	_overlay_bg.add_child(_overlay_title)

	_overlay_body = Label.new()
	_overlay_body.name = "BeatDescription"
	_overlay_body.anchor_left   = 0.12
	_overlay_body.anchor_top    = 0.3
	_overlay_body.anchor_right  = 0.88
	_overlay_body.anchor_bottom = 0.72
	_overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.add_theme_font_size_override("font_size", 21)
	_overlay_body.add_theme_color_override("font_color", BODY_COLOR)
	_overlay_bg.add_child(_overlay_body)

	_overlay_layer.visible = false

	# 6. Persistent fade layer (layer 150)
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "EndingFadeLayer"
	_fade_layer.layer = 150
	add_child(_fade_layer)

	_fade_cover = ColorRect.new()
	_fade_cover.name = "FadeCover"
	_fade_cover.color = Color(0, 0, 0, 0)
	_fade_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_cover)

	# 7. Initial positioning & facings
	if is_instance_valid(player):
		player.set_physics_process(false)
		player.global_position = Vector2(671.0, 9.0)
		player.velocity = Vector2.ZERO
		_set_player_facing("down")
		player.can_move = false
		if "can_interact" in player:
			player.can_interact = false
		var p_area := player.get_node_or_null("InteractionArea") as Area2D
		if p_area:
			p_area.monitoring = false
			p_area.monitorable = false

	if is_instance_valid(august):
		august.global_position = Vector2(1066.0, 73.0)
		_set_npc_facing(august, "idle_left")

	if is_instance_valid(kendra):
		kendra.global_position = Vector2(607.0, 297.0)
		_set_npc_facing(kendra, "idle_down")

	if is_instance_valid(new_recruit):
		new_recruit.global_position = Vector2(607.0, 584.0)
		_set_npc_facing(new_recruit, "idle_up")

	# 8. Force player camera active; disable any scene cameras that could steal focus
	_lock_camera_to_player()

	# Start cutscene sequence
	call_deferred("_run_ending_sequence")


# ---------------------------------------------------------------------------
# MAIN CUTSCENE SEQUENCE
# ---------------------------------------------------------------------------

func _run_ending_sequence() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# Wait for SceneTransition autoload to finish its fade-in
	var scene_trans = get_node_or_null("/root/SceneTransition")
	if scene_trans and scene_trans.color_rect and scene_trans.color_rect.color.a > 0.05:
		await scene_trans.scene_transition_finished
	else:
		await get_tree().create_timer(0.4).timeout

	if is_instance_valid(player):
		player.set_physics_process(false)
		player.global_position = Vector2(671.0, 9.0)
		player.velocity = Vector2.ZERO
		player.can_move = false
		_set_player_facing("down")
	# Re-assert player camera after scene transition
	_lock_camera_to_player()

	await get_tree().create_timer(0.3).timeout

	# --- STEP 1: Opening Monologue ---
	await _play_bubble(player, [
		{"name": "Player", "text": "Finally done with Ms. Ivana and HR... passed all my university exit clearances and finalized the permanent employment contract."},
		{"name": "Player", "text": "Official full-time Junior Full-Stack Developer. Still hard to believe it's actually real."}
	])

	# --- STEP 2: August interacts with sprint door and approaches corridor ---
	# August walks to the sprint room door from inside
	await _walk_npc_to(august, Vector2(1004.0, 73.0), 120.0)
	_set_npc_facing(august, "idle_left")

	# August opens the door
	await _open_door(sprint_door)
	await get_tree().create_timer(0.15).timeout

	# August walks through the door into the corridor
	await _walk_npc_to(august, Vector2(944.0, 73.0), 120.0)

	# Close the sprint door behind August
	_close_door(sprint_door)

	# August continues to callout position
	await _walk_npc_to(august, Vector2(874.0, 73.0), 130.0)
	await _play_bubble(august, [
		{"name": "August Creed", "text": "Hey! You're back!"}
	])

	# --- STEP 3: August walks up to player ---
	await _walk_npc_to(august, Vector2(671.0, 73.0), 130.0)
	await _walk_npc_to(august, Vector2(671.0, 49.0), 130.0)
	_set_npc_facing(august, "idle_up")
	_set_player_facing("down")

	await _play_bubble(august, [
		{"name": "August Creed", "text": "Look at that metallic Blue Badge! Official full-time engineer now, huh? Welcome back, kid!"},
		{"name": "August Creed", "text": "The morning donuts just arrived! Raspberry glazed and Boston cream. I already stashed two in my desk drawer before the backend engineers swarm the box."},
		{"name": "August Creed", "text": "I'll just bring some over to the folks at QA as well. See ya around — and get your table tidied up on your permanent desk on Floor 2!"},
		{"name": "August Creed", "text": "Oh, and tell Kendra she can head to the QA room if she wants donuts before they disappear!"}
	])

	await _play_bubble(player, [
		{"name": "Player", "text": "Haha, thanks August! Will do."}
	])

	# --- STEP 4: August walks to QA & teleports inside ---
	await _walk_npc_to(august, Vector2(303.0, 49.0), 140.0)
	if is_instance_valid(august):
		august.global_position = Vector2(-80.0, -59.0)
		_set_npc_facing(august, "idle_up")
	if is_instance_valid(celestina):
		_set_npc_facing(celestina, "idle_left")

	# --- STEP 5: Player reflection ---
	await _play_bubble(player, [
		{"name": "Player", "text": "I should probably grab some things from the locker... oh, and let Kendra know about the donuts."}
	])

	# --- STEP 6: Player walks to Kendra ---
	await _walk_player_to(Vector2(671.0, 97.0), 125.0)
	await _walk_player_to(Vector2(607.0, 97.0), 125.0)

	# Open hallway sliding door smoothly
	_open_sliding_door(hallway_door)
	await get_tree().create_timer(0.2).timeout

	await _walk_player_to(Vector2(607.0, 241.0), 125.0)
	_set_player_facing("down")

	# --- STEP 7: Player talks to Kendra ---
	await _play_bubble(player, [
		{"name": "Player", "text": "Hey Kendra!"}
	])

	await _play_bubble(kendra, [
		{"name": "Kendra Barba", "text": "Ohh hey! Look who's back! How's our newest permanent developer feeling today?"}
	])

	await _play_bubble(player, [
		{"name": "Player", "text": "August said you can grab some fresh donuts in the QA room if you'd like!"}
	])

	await _play_bubble(kendra, [
		{"name": "Kendra Barba", "text": "Aww, that's sweet! But I have guest badges to print and package deliveries arriving soon. You guys enjoy them for me!"}
	])

	await _play_bubble(player, [
		{"name": "Player", "text": "Haha, alright, don't work too hard!"}
	])

	# --- STEP 8: Player steps aside; New Recruit enters simultaneously ---
	_setup_cutscene_camera()
	cutscene_camera.global_position = player.global_position
	cutscene_camera.make_current()

	# Pan camera to Kendra
	var cam_pan := create_tween()
	var kendra_pos := kendra.global_position if is_instance_valid(kendra) else Vector2(607.0, 297.0)
	cam_pan.tween_property(cutscene_camera, "global_position", kendra_pos + Vector2(0.0, 20.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_open_sliding_door(entrance_door)

	# Parallel walk: Player to (695, 241) while New Recruit walks (607, 584) -> (607, 387)
	_play_player_walk("right")
	var tw_player := create_tween()
	var dur_p := player.global_position.distance_to(Vector2(695.0, 241.0)) / 110.0
	tw_player.tween_property(player, "global_position", Vector2(695.0, 241.0), dur_p).set_trans(Tween.TRANS_LINEAR)
	tw_player.tween_callback(func():
		_play_player_idle("down")
		_set_player_facing("down")
	)

	var tw_recruit := create_tween()
	var dur_r := new_recruit.global_position.distance_to(Vector2(607.0, 387.0)) / 95.0
	var spr_recruit := new_recruit.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr_recruit:
		spr_recruit.play("walking_up")
	tw_recruit.tween_property(new_recruit, "global_position", Vector2(607.0, 387.0), dur_r).set_trans(Tween.TRANS_LINEAR)

	await tw_recruit.finished
	if spr_recruit:
		spr_recruit.play("idle_up")
	_play_player_idle("down")
	_set_player_facing("down")
	# Close entrance door behind recruit
	_close_sliding_door(entrance_door)

	# --- STEP 9: New recruit speaks to Kendra ---
	await _play_bubble(new_recruit, [
		{"name": "New Recruit", "text": "G-good morning, Ma'am..."}
	])

	await _play_bubble(kendra, [
		{"name": "Kendra Barba", "text": "Good morning! Welcome to DJQ Corp. How can I help you today?"}
	])

	await _play_bubble(new_recruit, [
		{"name": "New Recruit", "text": "Um, I'm here for the technical interview... for the OJT web development internship. I have my endorsement papers and portfolio here..."}
	])

	# --- STEP 10: Player steps up to New Recruit ---
	await _walk_player_to(Vector2(695.0, 361.0), 115.0)
	_set_player_facing("left")
	_set_npc_facing(new_recruit, "idle_right")

	await _play_bubble(player, [
		{"name": "Player", "text": "Hey there. Looking for the technical interview room? Come on... let me show you the way."}
	])

	await _play_bubble(kendra, [
		{"name": "Kendra Barba", "text": "Oh, perfect! I'll leave him to you then, Engineer!"}
	])

	await _play_bubble(new_recruit, [
		{"name": "New Recruit", "text": "R-really? Thank you so much, sir!"}
	])

	# --- STEP 12: Backtracking to elevator with fade out during walk ---
	_start_backtracking_walk()

	# Camera slowly moves up as they walk away towards elevator
	if is_instance_valid(cutscene_camera):
		var cam_up := create_tween()
		cam_up.tween_property(cutscene_camera, "global_position:y", cutscene_camera.global_position.y - 140.0, 3.0).set_trans(Tween.TRANS_LINEAR)

	# Fade to black while they are walking back
	await get_tree().create_timer(1.8).timeout
	await _fade_to_black(1.0)

	# --- STEP 13: Placeholder Cutscene Card ---
	_overlay_title.text = "Chapter 14 — Paying It Forward"
	_overlay_body.text  = "CUT — Paying It Forward\n\nWalking side by side toward the developer wing, the nervous new intern clutches their brown folder.\nJust months ago, you stood in those exact shoes — anxious, uncertain, and clutching your own endorsement letter.\n\nNow, with a permanent Blue Badge pinned to your chest, you lead the way.\n\n[Press Space to continue]"
	_overlay_title.modulate.a = 1.0
	_overlay_body.modulate.a  = 1.0
	_overlay_layer.visible = true

	await _fade_from_black(0.6)

	await get_tree().process_frame
	while not Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame

	dialogue_box.start([
		{"name": "Narration", "text": "The nervous student clutches their folder tight, looking up at the high ceilings and buzzing workstations with wide eyes."},
		{"name": "Player", "text": "Don't stress too much about the interview. Just explain your logic clearly, listen to their questions, and be honest about what you know."},
		{"name": "New Recruit", "text": "Thank you, sir. I stayed up all night reviewing models, migrations, and serializers... but seeing the real office is overwhelming."},
		{"name": "Player", "text": "Ha. Sounds very familiar. You'll do great. Let's get you introduced to the team."},
		{"name": "Narration", "text": "The journey did not end when the thesis was defended. The thesis proved you could build a system. But DJQ Corp proved you could be a web developer."},
		{"name": "Narration", "text": "One who listens, takes responsibility, and pays it forward to the ones who follow."}
	])
	await dialogue_box.dialogue_finished

	# --- STEP 14: Final Transition to End Game Office ---
	await _fade_to_black(0.6)
	cutscene_active = false
	if is_instance_valid(player):
		player.set_physics_process(true)
		player.can_move = true
	if is_instance_valid(cutscene_camera):
		cutscene_camera.queue_free()
	var end_office_scene_path := "res://Scenes/End Game Office/office_floor_ground.tscn"
	scene_trans = get_node_or_null("/root/SceneTransition")
	if scene_trans and scene_trans.has_method("transition_to_scene"):
		scene_trans.transition_to_scene(end_office_scene_path, Vector2(671.0, 9.0), "down", 0.8, 0.8)
	else:
		get_tree().change_scene_to_file(end_office_scene_path)


# ---------------------------------------------------------------------------
# BACKTRACKING WALK
# ---------------------------------------------------------------------------

func _start_backtracking_walk() -> void:
	# Run player walk back to elevator
	var p_waypoints: Array[Vector2] = [
		Vector2(687.0, 241.0),
		Vector2(607.0, 241.0),
		Vector2(607.0, 97.0),
		Vector2(671.0, 97.0),
		Vector2(671.0, 9.0)
	]

	# Recruit follows player's position (687, 361) first, then follows backtrack path
	var r_waypoints: Array[Vector2] = [
		Vector2(607.0, 361.0),
		Vector2(687.0, 361.0),
		Vector2(687.0, 241.0),
		Vector2(607.0, 241.0),
		Vector2(607.0, 97.0),
		Vector2(671.0, 97.0),
		Vector2(671.0, 9.0)
	]

	_walk_path_async(player, p_waypoints, true, 115.0)
	_walk_recruit_follow(r_waypoints, 115.0)


func _walk_path_async(character: Node2D, waypoints: Array[Vector2], is_player: bool, speed: float) -> void:
	for wp in waypoints:
		if is_player:
			await _walk_player_to(wp, speed)
		else:
			await _walk_npc_to(character, wp, speed)


func _walk_recruit_follow(waypoints: Array[Vector2], speed: float) -> void:
	for wp in waypoints:
		await _walk_npc_to(new_recruit, wp, speed)


# ---------------------------------------------------------------------------
# MOVEMENT & ANIMATION HELPERS
# ---------------------------------------------------------------------------

func _walk_npc_to(npc: Node2D, target: Vector2, speed: float = 130.0) -> void:
	if not is_instance_valid(npc):
		return
	if npc.global_position.distance_to(target) <= 1.0:
		return
	var movement := target - npc.global_position
	var dir := "right" if movement.x >= 0.0 else "left"
	if absf(movement.y) > absf(movement.x):
		dir = "down" if movement.y >= 0.0 else "up"
	var sprite := npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play("walking_" + dir)
	var dur := maxf(0.1, npc.global_position.distance_to(target) / speed)
	var tw := create_tween()
	tw.tween_property(npc, "global_position", target, dur).set_trans(Tween.TRANS_LINEAR)
	await tw.finished
	if sprite:
		sprite.play("idle_" + dir)


func _walk_player_to(target: Vector2, speed: float = 125.0) -> void:
	if not is_instance_valid(player):
		return
	if player.global_position.distance_to(target) <= 1.0:
		return
	var movement := target - player.global_position
	var dir := "right" if movement.x >= 0.0 else "left"
	if absf(movement.y) > absf(movement.x):
		dir = "down" if movement.y >= 0.0 else "up"
	if "current_dir" in player:
		player.current_dir = dir
	_play_player_walk(dir)
	var dur := maxf(0.1, player.global_position.distance_to(target) / speed)
	var tw := create_tween()
	tw.tween_property(player, "global_position", target, dur).set_trans(Tween.TRANS_LINEAR)
	await tw.finished
	_play_player_idle(dir)


func _play_player_walk(dir: String) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("play_walk_animation"):
		player.play_walk_animation(dir)
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		var gender := "male"
		var c_data := get_node_or_null("/root/CharacterData")
		if c_data and "selected_gender" in c_data and c_data.selected_gender == "female":
			gender = "female"
		var anim_name := gender + "_walking_" + dir
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func _play_player_idle(dir: String) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("play_idle_animation"):
		player.play_idle_animation(dir)
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		var gender := "male"
		var c_data := get_node_or_null("/root/CharacterData")
		if c_data and "selected_gender" in c_data and c_data.selected_gender == "female":
			gender = "female"
		var anim_name := gender + "_idle_" + dir
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func _set_player_facing(dir: String) -> void:
	if is_instance_valid(player):
		if "current_dir" in player:
			player.current_dir = dir
		_play_player_idle(dir)


func _set_npc_facing(npc: Node2D, anim_name: String) -> void:
	if not is_instance_valid(npc):
		return
	var sprite := npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play(anim_name)


func _open_sliding_door(door: Node2D) -> void:
	if not is_instance_valid(door):
		return
	var col := door.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)
	var anim := door.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim:
		anim.play("open_animation")
		await anim.animation_looped
		anim.play("open_idle")


func _close_sliding_door(door: Node2D) -> void:
	if not is_instance_valid(door):
		return
	var anim := door.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim:
		anim.play("close_animation")
		await anim.animation_looped
		anim.play("close_idle")
	var col := door.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", false)


func _open_door(door: Node2D) -> void:
	if not is_instance_valid(door):
		return
	if "is_door_open" in door and door.is_door_open:
		return
	if door.has_method("unlock"):
		door.unlock()
	var col := door.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)
	if door.has_method("interact"):
		door.interact()
	await get_tree().create_timer(0.35).timeout


func _close_door(door: Node2D) -> void:
	if not is_instance_valid(door):
		return
	if "is_door_open" in door and not door.is_door_open:
		return
	if door.has_method("interact"):
		door.interact()
	await get_tree().create_timer(0.35).timeout
	var col := door.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", false)


func _disable_all_npc_interactions() -> void:
	if is_instance_valid(player):
		player.can_move = false
		if "can_interact" in player:
			player.can_interact = false
		var p_area := player.get_node_or_null("InteractionArea") as Area2D
		if p_area:
			p_area.monitoring = false
			p_area.monitorable = false

	# Disable sliding door Area2D triggers so player walking through doesn't re-trigger them
	if is_instance_valid(hallway_door):
		var hd_area := hallway_door.get_node_or_null("Area2D") as Area2D
		if hd_area:
			hd_area.monitoring = false
			hd_area.monitorable = false
		# Also check if the door itself IS an Area2D
		if hallway_door is Area2D:
			(hallway_door as Area2D).monitoring = false
			(hallway_door as Area2D).monitorable = false
	if is_instance_valid(entrance_door):
		var ed_area := entrance_door.get_node_or_null("Area2D") as Area2D
		if ed_area:
			ed_area.monitoring = false
			ed_area.monitorable = false
		if entrance_door is Area2D:
			(entrance_door as Area2D).monitoring = false
			(entrance_door as Area2D).monitorable = false

	for node in find_children("*", "Area2D", true, false):
		var area := node as Area2D
		# Don't disable sliding doors completely, only their interaction labels
		var label := area.get_node_or_null("Label") as Label
		if label:
			label.visible = false
		if "interaction_text" in area and area != hallway_door and area != entrance_door and area != sprint_door:
			area.set("interaction_text", "")


func _get_or_create_chat_bubble(node: Node2D) -> Control:
	if not is_instance_valid(node):
		return null
	var bubble: Control = node.get_node_or_null("EndingChatBubble") as Control
	if bubble == null or not is_instance_valid(bubble):
		bubble = CHAT_BUBBLE_SCENE.instantiate() as Control
		bubble.name = "EndingChatBubble"
		bubble.suppress_player_unlock = true
		bubble.z_index = 100
		node.add_child(bubble)
	else:
		bubble.suppress_player_unlock = true
	return bubble


func _play_bubble(speaker_node: Node2D, lines: Array) -> void:
	if not is_instance_valid(speaker_node) or lines.is_empty():
		return
	var bubble := _get_or_create_chat_bubble(speaker_node)
	if bubble == null:
		return
	bubble.start(lines)
	await bubble.dialogue_finished


func _setup_cutscene_camera() -> void:
	if cutscene_camera == null:
		cutscene_camera = Camera2D.new()
		cutscene_camera.name = "StoryEndingCutsceneCamera"
		var player_cam := player.get_node_or_null("Camera2D") as Camera2D if is_instance_valid(player) else null
		if player_cam:
			cutscene_camera.zoom = player_cam.zoom
		add_child(cutscene_camera)


func _lock_camera_to_player() -> void:
	# Disable any scene-level Camera2Ds that could steal focus (ReceptionRoom, etc.)
	var cameras_node := get_node_or_null("CamerasAndTriggers") as Node2D
	if cameras_node:
		for child in cameras_node.get_children():
			if child is Camera2D:
				(child as Camera2D).enabled = false
	# Also scan the whole tree for stray Camera2Ds (not the player's)
	for cam in get_tree().get_nodes_in_group("camera"):
		if cam is Camera2D:
			(cam as Camera2D).enabled = false
	# Force the player camera current
	if is_instance_valid(player):
		var player_cam := player.get_node_or_null("Camera2D") as Camera2D
		if player_cam:
			player_cam.enabled = true
			player_cam.make_current()


func _fade_to_black(duration: float = 0.6) -> void:
	if _fade_cover == null:
		return
	var tw := create_tween()
	tw.tween_property(_fade_cover, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _fade_from_black(duration: float = 0.8) -> void:
	if _fade_cover == null:
		return
	var tw := create_tween()
	tw.tween_property(_fade_cover, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	await tw.finished
