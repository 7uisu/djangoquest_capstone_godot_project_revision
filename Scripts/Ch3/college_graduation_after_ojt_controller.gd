extends Node2D

# ---------------------------------------------------------------------------
# College Graduation After OJT ??Ceremony Controller
# Sequence: 3 placeholder cutscenes ??live gameplay congratulations ??#           Prof Syntax walks away ??Mom/Dad dialogue ??Bestfriends walk in
#           ??reunion dialogue ??photo ??group photo placeholder ??End Game
# ---------------------------------------------------------------------------

const DIALOGUE_BOX_SCENE := preload("res://Scenes/UI/dialogue_box.tscn")
const CHAT_BUBBLE_SCENE  := preload("res://Scenes/UI/chat_bubble.tscn")

# Matches the office placeholder style exactly.
const PLACEHOLDER_COLOR    := Color(0.055, 0.075, 0.12, 0.97)
const TITLE_COLOR          := Color(0.91, 0.94, 1.0)
const BODY_COLOR           := Color(0.8, 0.86, 0.97)

# NPC node references
var player: CharacterBody2D
var dialogue_box: CanvasLayer

var prof_markup: Node2D   # NPCMaleCollegeProf01
var prof_elena: Node2D    # NPCFemaleCollegeProf01
var female_bf: Node2D     # FemaleBestFriend
var male_bf: Node2D       # MaleBestFriend
var npc_dad: Node2D       # NPCDad
var npc_mom: Node2D       # NPCMom

# Overlay nodes (same design as ch3_office_late_arc_controller)
var _overlay_layer: CanvasLayer
var _overlay_bg: ColorRect
var _overlay_title: Label
var _overlay_body: Label

# Persistent screen fade layer (layer 150 ??covers overlay 95 and dialogue 130)
var _fade_layer: CanvasLayer
var _fade_cover: ColorRect

# Player facing state
var _player_locked_facing_down: bool = false


func _ready() -> void:
	player      = get_node_or_null("Player") as CharacterBody2D
	prof_markup = get_node_or_null("NPCMaleCollegeProf01")
	prof_elena  = get_node_or_null("NPCFemaleCollegeProf01")
	female_bf   = get_node_or_null("FemaleBestFriend")
	male_bf     = get_node_or_null("MaleBestFriend")
	npc_dad     = get_node_or_null("NPCDad")
	npc_mom     = get_node_or_null("NPCMom")

	_disable_all_npc_interactions()

	# Hide top-left UI (room indicator, guide labels, quest HUD)
	_hide_hud_elements()

	# Dialogue box (layer 130)
	dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as CanvasLayer
	dialogue_box.name = "GraduationDialogueBox"
	dialogue_box.suppress_player_unlock = true
	dialogue_box.layer = 130
	add_child(dialogue_box)

	# Build overlay ??same structure as ch3_office_late_arc_controller (layer 95)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "GraduationPlaceholderLayer"
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

	# Persistent fade layer (layer 150)
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "GraduationFadeLayer"
	_fade_layer.layer = 150
	add_child(_fade_layer)

	_fade_cover = ColorRect.new()
	_fade_cover.name = "FadeCover"
	_fade_cover.color = Color.BLACK
	_fade_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_cover)

	# Initial NPC facings on spawn
	_set_player_facing("up")
	_set_npc_facing(npc_mom,     "idle_up", "npc")
	_set_npc_facing(npc_dad,     "idle_up", "npc")
	_set_npc_facing(prof_markup, "idle_down", "npc")
	_set_npc_facing(prof_elena,  "idle_up", "npc")

	# Set audience student facings
	_set_npc_facing(get_node_or_null("Students/NPCFemaleCollegeStudent01"), "idle_right", "npc")
	_set_npc_facing(get_node_or_null("Students/NPCFemaleCollegeStudent02"), "idle_left",  "npc")
	_set_npc_facing(get_node_or_null("Students/NPCFemaleCollegeStudent05"), "idle_right",  "npc")
	_set_npc_facing(get_node_or_null("Students/NPCMaleCollegeStudent04"),   "idle_right",  "npc")
	_set_npc_facing(get_node_or_null("Students/NPCFemaleCollegeStudent06"), "idle_left",   "npc")
	_set_npc_facing(get_node_or_null("Students/NPCFemaleCollegeStudent08"), "idle_up",     "npc")
	_set_npc_facing(get_node_or_null("Students/NPCFemaleCollegeStudent07"), "idle_right",  "npc")

	# Initial bestfriend facings at spawn positions
	_set_bf_facing(female_bf, "female_student_idle_up")
	_set_bf_facing(male_bf,   "male_student_idle_up")

	call_deferred("_run_ceremony")


# ---------------------------------------------------------------------------
# MAIN SEQUENCE
# ---------------------------------------------------------------------------

func _run_ceremony() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# Fade in from black at scene start
	await _fade_from_black(0.8)

	# --- PHASE 1: Placeholder cutscenes (uses dialogue_box) ---
	await _show_placeholder(
		"Chapter 14 ??Graduation",
		"CUT ??Graduation Ceremony\n\nMany students walk across the stage and receive their diplomas.\nApplause fills the auditorium.\n\n[Press Space to continue]",
		[
			{"name": "Narration", "text": "The auditorium is alive with applause. One by one, names echo through the hall as students cross the stage and receive their diplomas."},
			{"name": "Narration", "text": "Four years of late nights, failed tests, group projects, and breakthroughs ??all of it distilled into a single handshake and a rolled-up certificate."},
		]
	)

	await _show_placeholder(
		"Chapter 14 ??Graduation",
		"CUT ??Player Receives Diploma\n\nThe player walks across the stage.\nThe dean hands the diploma over. Camera flashes. Cheers from the crowd.\n\n[Press Space to continue]",
		[
			{"name": "Narration", "text": "Your name is called. You walk across the stage, heart pounding."},
			{"name": "Narration", "text": "The dean extends a hand and places the diploma in yours. Somewhere in the crowd, someone cheers louder than everyone else."},
		]
	)

	await _show_placeholder(
		"Chapter 14 ??Graduation",
		"CUT ??Ceremony Address\n\nThe ceremony president addresses the audience ??parents, families, and supporters.\n\n[Press Space to continue]",
		[
			{"name": "Ceremony President", "text": "To the families, the parents, the siblings, the friends who stayed up waiting ??thank you. You were part of every breakthrough these graduates made."},
			{"name": "Ceremony President", "text": "Every student who crossed this stage today did so because someone believed in them when they couldn't believe in themselves. Thank you for being that someone."},
			{"name": "Ceremony President", "text": "To the graduating class ??the world is waiting. Go build something worth remembering."},
		]
	)

	# --- PHASE 2: Transition to live gameplay ---
	_hide_placeholder()
	_set_player_facing("up")
	await _fade_from_black(0.6)

	await get_tree().create_timer(0.5).timeout

	# --- PHASE 3: Prof Syntax congratulations (Chat Bubbles) ---
	await _play_lines([
		{"name": "Professor Markup", "text": "Look at you. Standing here with that diploma in your hand after everything you built this year."},
		{"name": "Professor Markup", "text": "Your OJT wasn't just hours logged on a timesheet. You got your hands on a real system, with real users, and real consequences. That's not something every graduate can say."},
		{"name": "Professor Markup", "text": "The Django project, the security work, the team dynamics ??I read Ivana's report. You made your adviser proud."},
		{"name": "Player", "text": "Thank you, Professor Markup. I wouldn't have known where to start without your classes."},
		{"name": "Professor Markup", "text": "Ha. You would have figured it out. You always did."},
		{"name": "Professor Markup", "text": "You raised someone worth knowing. Congratulations to all of you."},
		{"name": "Mom", "text": "Thank you so much, Professor. We're so grateful for everything."},
		{"name": "Dad", "text": "Yes. Thank you, sir. It means a lot."},
	])

	# --- PHASE 4: Prof Syntax walks away ---
	await _walk_npc_to(prof_markup, Vector2(397.0, 230.0))
	await _walk_npc_to(prof_markup, Vector2(487.0, 230.0))
	_set_npc_facing(prof_markup, "idle_left", "npc")

	# --- PHASE 5: Mom & Dad dialogue (Chat Bubbles) ---
	_set_npc_facing(npc_mom, "idle_left", "npc")
	_set_npc_facing(npc_dad, "idle_right", "npc")

	await _play_lines([
		{"name": "Dad", "text": "Anak. We are so, so proud of you."},
		{"name": "Dad", "text": "You didn't take the easy path. You chose something hard, something technical ??and you saw it through."},
		{"name": "Mom", "text": "Every time you called home sounding exhausted, we wanted to tell you to come rest. But we knew you'd push through on your own."},
		{"name": "Mom", "text": "And you did. You always did. Congratulations, anak."},
		{"name": "Player", "text": "I kept going because I knew you were rooting for me. Thank you for not giving up on me even when I almost did."},
		{"name": "Dad", "text": "Never. Not for a single second."},
		{"name": "Mom", "text": "Now ??we may have arranged a little surprise."},
		{"name": "Dad", "text": "They insisted on coming. Wouldn't take no for an answer."},
	])

	# --- PHASE 6: Bestfriends walk in (parallel) ---
	# Segment A ??Walk up from initial scene positions (108, 514) / (690, 514) to (108, 330) / (690, 330)
	_set_bf_facing(female_bf, "female_student_walking_up")
	_set_bf_facing(male_bf,   "male_student_walking_up")

	var dur_f0 := maxf(0.25, female_bf.global_position.distance_to(Vector2(108.0, 330.0)) / 145.0)
	var dur_m0 := maxf(0.25, male_bf.global_position.distance_to(Vector2(690.0, 330.0)) / 145.0)
	var tw_f0 := create_tween()
	var tw_m0 := create_tween()
	tw_f0.tween_property(female_bf, "global_position", Vector2(108.0, 330.0), dur_f0).set_trans(Tween.TRANS_LINEAR)
	tw_m0.tween_property(male_bf,   "global_position", Vector2(690.0, 330.0), dur_m0).set_trans(Tween.TRANS_LINEAR)
	if dur_f0 >= dur_m0:
		await tw_f0.finished
	else:
		await tw_m0.finished
	female_bf.global_position = Vector2(108.0, 330.0)
	male_bf.global_position   = Vector2(690.0, 330.0)

	# Segment B ??Horizontal walk to (238, 330) and (560, 330)
	_set_bf_facing(female_bf, "female_student_walking_right")
	_set_bf_facing(male_bf,   "male_student_walking_left")

	var dur_fa := maxf(0.25, female_bf.global_position.distance_to(Vector2(238.0, 330.0)) / 145.0)
	var dur_ma := maxf(0.25, male_bf.global_position.distance_to(Vector2(560.0, 330.0)) / 145.0)
	var tw_fa := create_tween()
	var tw_ma := create_tween()
	tw_fa.tween_property(female_bf, "global_position", Vector2(238.0, 330.0), dur_fa).set_trans(Tween.TRANS_LINEAR)
	tw_ma.tween_property(male_bf,   "global_position", Vector2(560.0, 330.0), dur_ma).set_trans(Tween.TRANS_LINEAR)
	if dur_fa >= dur_ma:
		await tw_fa.finished
	else:
		await tw_ma.finished
	female_bf.global_position = Vector2(238.0, 330.0)
	male_bf.global_position   = Vector2(560.0, 330.0)

	# Segment C ??Vertical walk up to (238, 258) and (560, 258)
	_set_bf_facing(female_bf, "female_student_walking_up")
	_set_bf_facing(male_bf,   "male_student_walking_up")

	var dur_fb := maxf(0.25, female_bf.global_position.distance_to(Vector2(238.0, 258.0)) / 145.0)
	var dur_mb := maxf(0.25, male_bf.global_position.distance_to(Vector2(560.0, 258.0)) / 145.0)
	var tw_fb := create_tween()
	var tw_mb := create_tween()
	tw_fb.tween_property(female_bf, "global_position", Vector2(238.0, 258.0), dur_fb).set_trans(Tween.TRANS_LINEAR)
	tw_mb.tween_property(male_bf,   "global_position", Vector2(560.0, 258.0), dur_mb).set_trans(Tween.TRANS_LINEAR)
	if dur_fb >= dur_mb:
		await tw_fb.finished
	else:
		await tw_mb.finished
	female_bf.global_position = Vector2(238.0, 258.0)
	male_bf.global_position   = Vector2(560.0, 258.0)

	_set_bf_facing(female_bf, "female_student_idle_up")
	_set_bf_facing(male_bf,   "male_student_idle_up")

	# Mom/Dad convergence runs in background while bestfriends continue to final spots
	_run_mom_dad_convergence()

	# Segment D ??Walk to final destinations (358, 258) and (432, 258)
	_set_bf_facing(female_bf, "female_student_walking_right")
	_set_bf_facing(male_bf,   "male_student_walking_left")

	var dur_fc := maxf(0.25, female_bf.global_position.distance_to(Vector2(358.0, 258.0)) / 145.0)
	var dur_mc := maxf(0.25, male_bf.global_position.distance_to(Vector2(432.0, 258.0)) / 145.0)
	var tw_fc := create_tween()
	var tw_mc := create_tween()
	tw_fc.tween_property(female_bf, "global_position", Vector2(358.0, 258.0), dur_fc).set_trans(Tween.TRANS_LINEAR)
	tw_mc.tween_property(male_bf,   "global_position", Vector2(432.0, 258.0), dur_mc).set_trans(Tween.TRANS_LINEAR)
	if dur_fc >= dur_mc:
		await tw_fc.finished
	else:
		await tw_mc.finished
	female_bf.global_position = Vector2(358.0, 258.0)
	male_bf.global_position   = Vector2(432.0, 258.0)

	_set_bf_facing(female_bf, "female_student_idle_right")
	_set_bf_facing(male_bf,   "male_student_idle_left")

	# --- PHASE 7: Bestfriend reunion dialogue (Chat Bubbles) ---
	# Friends traveled here from their own colleges to celebrate player's graduation.
	await _play_lines([
		{"name": "Female Best Friend", "text": "THERE you are! We came straight to your campus as soon as we could!"},
		{"name": "Male Best Friend", "text": "Bro! We took the bus all the way here to surprise you. You didn't think we'd miss your college graduation, did you?!"},
		{"name": "Female Best Friend", "text": "Congratulations! You actually did it! You survived thesis defense, finished your 300 OJT hours, and now an official college graduate!"},
		{"name": "Player", "text": "You guys came all the way to my school? I thought you were busy at your own colleges!"},
		{"name": "Male Best Friend", "text": "Are you kidding? Different colleges couldn't keep the Senior High 7-Eleven trio apart, bro."},
		{"name": "Female Best Friend", "text": "We knew how hard you worked on your Django project and your internship. We had to be here in person to see you walk that stage."},
		{"name": "Player", "text": "I can't believe both of you are here. Thank you so much, guys."},
		{"name": "Male Best Friend", "text": "Don't get all emotional on us yet! We still need that photo together."},
		{"name": "Female Best Friend", "text": "Yes! We need a photo right now to celebrate!"},
	])

	# --- PHASE 8: Photo sequence (Chat Bubbles) ---
	# When Male Best Friend says "Ma'am", player turns front/downwards and stays like that.
	await _play_lines([
		{"name": "Male Best Friend", "text": "Excuse me, Ma'am! Sorry to bother you ??could you take a photo of us? Just a quick one."},
		{"name": "Professor Elena", "text": "Of course! Come on, all of you ??gather together."},
		{"name": "Female Best Friend", "text": "You too, Mom, Dad! Come join us!"},
		{"name": "Mom", "text": "Oh ??are you sure? We don't want to get in the way."},
		{"name": "Male Best Friend", "text": "Definitely! You're part of the team, Auntie and Uncle!"},
		{"name": "Professor Elena", "text": "Alright, everyone look here and smile! Three... two... one..."},
		{"name": "Professor Elena", "text": "Cheese!"},
	])

	# --- PHASE 9: Group photo placeholder cutscene (uses dialogue_box) ---
	await _fade_to_black(0.5)
	await get_tree().create_timer(0.2).timeout

	_overlay_title.text = "Chapter 14 ??Graduation"
	_overlay_body.text  = "CUT ??Group Photo\n\n[ART PLACEHOLDER]\nA photograph captures the moment:\nPlayer holding the college diploma in the center, flanked by Mom and Dad on one side, and the two best friends on the other, with Professor Markup smiling warmly in the frame.\n\n[Press Space to continue]"
	_overlay_title.modulate.a = 1.0
	_overlay_body.modulate.a  = 1.0
	_overlay_layer.visible = true

	# Fade in to placeholder card (eliminates black screen)
	await _fade_from_black(0.5)

	await get_tree().process_frame
	while not Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame

	# Reflection dialogue on the placeholder using dialogue_box
	dialogue_box.start([
		{"name": "Narration", "text": "The camera clicks, capturing a milestone years in the making."},
		{"name": "Narration", "text": "In the photograph, everyone is smiling. Mom holding your arm, Dad standing proud, Professor Markup nodding with approval, and your two best friends giving thumbs up beside you."},
		{"name": "Narration", "text": "From Senior High School snacks in front of 7-Eleven to building production-grade web systems. From syntax errors in class to completing 300 rigorous OJT hours at DJQ Corp."},
		{"name": "Player", "text": "Four years of lessons, late nights, thesis defense, and office sprints... I finally did it."},
		{"name": "Narration", "text": "College is officially complete. The diploma in your hand proves you've earned your place as a web developer."},
		{"name": "Narration", "text": "Ahead lies DJQ Corp, new features, and the beginning of your professional engineering career."}
	])
	await dialogue_box.dialogue_finished

	# --- PHASE 10: Transition to End Game Office ---
	var end_office_scene_path := "res://Scenes/End Game Office/story_ending_office_cutscene.tscn"
	var scene_trans = get_node_or_null("/root/SceneTransition")
	if scene_trans and scene_trans.has_method("transition_to_scene"):
		# Delegate to autoload so the fade-in runs smoothly across scene change
		scene_trans.transition_to_scene(end_office_scene_path, Vector2(671.0, 9.0), "down", 0.8, 0.8)
	else:
		get_tree().change_scene_to_file(end_office_scene_path)


# ---------------------------------------------------------------------------
# MOM/DAD CONVERGENCE (runs in background during bestfriend final walk)
# ---------------------------------------------------------------------------

func _run_mom_dad_convergence() -> void:
	var sprite_mom := npc_mom.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if is_instance_valid(npc_mom) else null
	var sprite_dad := npc_dad.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if is_instance_valid(npc_dad) else null

	# Mom and Dad both walk toward (432,214) and (362,214) simultaneously
	var mom_move1 := Vector2(432.0, 214.0) - npc_mom.global_position
	var mom_dir1  := "up" if absf(mom_move1.y) > absf(mom_move1.x) else ("left" if mom_move1.x < 0.0 else "right")
	if sprite_mom:
		sprite_mom.play("walking_" + mom_dir1)

	var dad_move1 := Vector2(362.0, 214.0) - npc_dad.global_position
	var dad_dir1  := "up" if absf(dad_move1.y) > absf(dad_move1.x) else ("left" if dad_move1.x < 0.0 else "right")
	if sprite_dad:
		sprite_dad.play("walking_" + dad_dir1)

	var dur_mom1 := maxf(0.25, npc_mom.global_position.distance_to(Vector2(432.0, 214.0)) / 145.0)
	var dur_dad1 := maxf(0.25, npc_dad.global_position.distance_to(Vector2(362.0, 214.0)) / 145.0)
	var tw_mom1 := create_tween()
	var tw_dad1 := create_tween()
	tw_mom1.tween_property(npc_mom, "global_position", Vector2(432.0, 214.0), dur_mom1).set_trans(Tween.TRANS_LINEAR)
	tw_dad1.tween_property(npc_dad, "global_position", Vector2(362.0, 214.0), dur_dad1).set_trans(Tween.TRANS_LINEAR)

	await tw_mom1.finished
	if sprite_mom:
		sprite_mom.play("idle_left")

	await tw_dad1.finished
	if sprite_dad:
		sprite_dad.play("idle_right")

	# Dad continues to (394, 214)
	var dur_dad2 := maxf(0.25, npc_dad.global_position.distance_to(Vector2(394.0, 214.0)) / 145.0)
	if sprite_dad:
		sprite_dad.play("walking_right")
	var tw_dad2 := create_tween()
	tw_dad2.tween_property(npc_dad, "global_position", Vector2(394.0, 214.0), dur_dad2).set_trans(Tween.TRANS_LINEAR)
	await tw_dad2.finished
	if sprite_dad:
		sprite_dad.play("idle_right")

	# When dad reaches (394,214): mom moves to (432,204), dad moves to (394,204)
	var dur_mom2 := maxf(0.25, npc_mom.global_position.distance_to(Vector2(432.0, 204.0)) / 145.0)
	var dur_dad3 := maxf(0.25, npc_dad.global_position.distance_to(Vector2(394.0, 204.0)) / 145.0)
	if sprite_mom:
		sprite_mom.play("walking_up")
	if sprite_dad:
		sprite_dad.play("walking_up")
	var tw_mom2 := create_tween()
	var tw_dad3 := create_tween()
	tw_mom2.tween_property(npc_mom, "global_position", Vector2(432.0, 204.0), dur_mom2).set_trans(Tween.TRANS_LINEAR)
	tw_dad3.tween_property(npc_dad, "global_position", Vector2(394.0, 204.0), dur_dad3).set_trans(Tween.TRANS_LINEAR)
	await tw_mom2.finished
	if sprite_mom:
		sprite_mom.play("idle_left")
	await tw_dad3.finished
	if sprite_dad:
		sprite_dad.play("idle_down")


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

## Set facing and idle animation on the player character.
func _set_player_facing(dir: String) -> void:
	if player:
		if "current_dir" in player:
			player.current_dir = dir
		if player.has_method("play_idle_animation"):
			player.play_idle_animation(dir)


## Update player facing to look at the current speaker.
## When Male Best Friend addresses Professor Elena ("Ma'am"), player locks to facing front/downwards.
func _update_player_facing_for_speaker(speaker_name: String, line_text: String) -> void:
	if _player_locked_facing_down:
		return
	if speaker_name == "Mom":
		_set_player_facing("right")
	elif speaker_name == "Dad":
		_set_player_facing("left")
	elif speaker_name == "Female Best Friend":
		_set_player_facing("left")
	elif speaker_name == "Male Best Friend":
		if "Ma'am" in line_text or "ma'am" in line_text:
			_player_locked_facing_down = true
			_set_player_facing("down")
			# Group lines up facing forward for the photo
			_set_npc_facing(npc_mom, "idle_down", "npc")
			_set_npc_facing(npc_dad, "idle_down", "npc")
			_set_bf_facing(female_bf, "female_student_idle_down")
			_set_bf_facing(male_bf, "male_student_idle_down")
			_set_npc_facing(prof_markup, "idle_down", "npc")
		else:
			_set_player_facing("right")
	elif speaker_name == "Professor Markup":
		_set_player_facing("up")


## Walk a dialogue_interactable NPC to a target with directional animation.
func _walk_npc_to(npc: Node2D, target: Vector2, speed: float = 145.0) -> void:
	if not is_instance_valid(npc):
		return
	if npc.global_position.distance_to(target) <= 1.0:
		return
	var movement := target - npc.global_position
	var direction: String
	if absf(movement.x) > absf(movement.y):
		direction = "right" if movement.x >= 0.0 else "left"
	else:
		direction = "down" if movement.y >= 0.0 else "up"
	var sprite := npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play("walking_" + direction)
	var duration := maxf(0.25, npc.global_position.distance_to(target) / speed)
	var tween := create_tween()
	tween.tween_property(npc, "global_position", target, duration).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	if sprite:
		sprite.play("idle_" + direction)


## Set facing on a dialogue_interactable NPC or player.
## animation_name: full animation string e.g. "idle_up"
func _set_npc_facing(npc: Node2D, animation_name: String, _type: String = "npc") -> void:
	if not is_instance_valid(npc):
		return
	var sprite := npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play(animation_name)


## Set animation on a bestfriend CharacterBody2D (uses their own animation names).
func _set_bf_facing(bf: Node2D, animation_name: String) -> void:
	if not is_instance_valid(bf):
		return
	var sprite := bf.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play(animation_name)


func _hide_hud_elements() -> void:
	# Hide room indicator / guide labels on player Camera2D
	if is_instance_valid(player):
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			for lbl_name in ["Guide1Label", "Guide2Label", "PlayerName"]:
				var lbl := cam.get_node_or_null(lbl_name) as Label
				if lbl:
					lbl.visible = false
	# Hide any lingering RoomIndicatorLayer CanvasLayer in scene tree
	for cl in get_tree().root.find_children("RoomIndicatorLayer", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	# Hide quest HUD
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("hide_quest"):
		qm.hide_quest()


## Disable all player-NPC interactions since this whole scene is a cutscene.
func _disable_all_npc_interactions() -> void:
	if player:
		player.can_move = false
		if "can_interact" in player:
			player.can_interact = false
		var player_area := player.get_node_or_null("InteractionArea") as Area2D
		if player_area:
			player_area.monitoring = false
			player_area.monitorable = false

	for node in find_children("*", "Area2D", true, false):
		var area := node as Area2D
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 0
		var col := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col:
			col.disabled = true
		var label := area.get_node_or_null("Label") as Label
		if label:
			label.visible = false
		if "interaction_label" in area and area.interaction_label:
			area.interaction_label.visible = false
		if "_is_sequencing" in area:
			area.set("_is_sequencing", true)
		area.set_process(false)


## Map speaker names to their corresponding in-scene Node2D.
## Returns null for speakers without an on-screen NPC (Narration, Ceremony President, etc.).
func _get_speaker_node(speaker_name: String) -> Node2D:
	match speaker_name:
		"Professor Markup":
			return prof_markup
		"Professor Elena":
			return prof_elena
		"Player":
			return player
		"Mom":
			return npc_mom
		"Dad":
			return npc_dad
		"Female Best Friend":
			return female_bf
		"Male Best Friend":
			return male_bf
	return null


## Lazily instantiate or retrieve a chat bubble child on a character node.
func _get_or_create_chat_bubble(node: Node2D) -> Control:
	if not is_instance_valid(node):
		return null
	var bubble: Control = node.get_node_or_null("GraduationChatBubble") as Control
	if bubble == null or not is_instance_valid(bubble):
		bubble = CHAT_BUBBLE_SCENE.instantiate() as Control
		bubble.name = "GraduationChatBubble"
		bubble.suppress_player_unlock = true
		bubble.z_index = 100
		node.add_child(bubble)
	else:
		bubble.suppress_player_unlock = true
	return bubble


## Play chat bubble dialogue over a character node.
func _play_bubble(speaker_node: Node2D, lines: Array) -> void:
	if not is_instance_valid(speaker_node) or lines.is_empty():
		return
	var bubble := _get_or_create_chat_bubble(speaker_node)
	if bubble == null:
		return
	bubble.start(lines)
	await bubble.dialogue_finished


## Play a dialogue array: updates player facing towards the speaker,
## uses dialogue_box for narration/no-NPC speakers,
## and chat bubbles above the speaking character for all other lines.
func _play_lines(lines: Array) -> void:
	var i := 0
	while i < lines.size():
		var line_data: Dictionary = lines[i]
		var speaker_name: String = str(line_data.get("name", ""))
		var line_text: String = str(line_data.get("text", ""))
		_update_player_facing_for_speaker(speaker_name, line_text)
		var speaker_node: Node2D = _get_speaker_node(speaker_name)
		if speaker_node != null:
			var chunk: Array = []
			while i < lines.size() and _get_speaker_node(str(lines[i].get("name", ""))) == speaker_node:
				chunk.append(lines[i])
				i += 1
			await _play_bubble(speaker_node, chunk)
		else:
			var chunk: Array = []
			while i < lines.size() and _get_speaker_node(str(lines[i].get("name", ""))) == null:
				chunk.append(lines[i])
				i += 1
			dialogue_box.start(chunk)
			await dialogue_box.dialogue_finished
		await get_tree().process_frame


## Show placeholder card (office-style), play dialogue with dialogue_box, then hold.
func _show_placeholder(title: String, body: String, lines: Array) -> void:
	_overlay_title.text        = title
	_overlay_body.text         = body
	_overlay_title.modulate.a  = 1.0
	_overlay_body.modulate.a   = 1.0
	_overlay_layer.visible     = true
	await get_tree().process_frame
	while not Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	while Input.is_key_pressed(KEY_SPACE):
		await get_tree().process_frame
	if not lines.is_empty():
		dialogue_box.start(lines)
		await dialogue_box.dialogue_finished


## Hide the placeholder overlay.
func _hide_placeholder() -> void:
	_overlay_layer.visible = false


## Fade screen to black using persistent fade cover.
func _fade_to_black(duration: float = 0.6) -> void:
	if _fade_cover == null:
		return
	var tw := create_tween()
	tw.tween_property(_fade_cover, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	await tw.finished


## Fade screen in from black using persistent fade cover.
func _fade_from_black(duration: float = 0.8) -> void:
	if _fade_cover == null:
		return
	var tw := create_tween()
	tw.tween_property(_fade_cover, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	await tw.finished
