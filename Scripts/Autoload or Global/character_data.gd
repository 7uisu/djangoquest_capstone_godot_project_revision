# scripts/Autoload or Global/character_data.gd
extends Node

var selected_gender: String = ""  # "male" or "female"
var player_name: String = ""
var api_username: String = ""  # Username from Django API login (empty if guest)
var has_seen_tutorial: bool = false
var has_seen_learning_mode_intro: bool = false

# ── Contextual Spotlight Tutorial Flags ───────────────────────────────────────
var has_seen_controls_tutorial: bool = false
var has_seen_inventory_tutorial: bool = false
var has_seen_laptop_tutorial: bool = false
var has_seen_ide_tutorial: bool = false
var has_seen_college_sis_tutorial: bool = false
var has_seen_overflow_stack_tutorial: bool = false
var has_reached_college: bool = false

# Chapter 1 progress
var ch1_teaching_done: bool = false
var ch1_quiz_done: bool = false
var ch1_quiz_score: int = 0
var ch1_did_remedial: bool = false
var ch1_remedial_score: int = 0
var ch1_post_quiz_dialogue_done: bool = false
var ch1_convenience_store_cutscene_done: bool = false
var ch1_spaghetti_guy_cutscene_done: bool = false

# Chapter 2 (College) progress
var ch2_y1s1_teaching_done: bool = false       # Year 1 Sem 1 all modules complete
var ch2_y1s1_current_module: int = 0           # 0-4 (which module player is on)
var ch2_y1s2_teaching_done: bool = false       # Year 1 Sem 2 all modules complete
var ch2_y1s2_current_module: int = 0           # 0-2 (which module player is on)
var ch2_y2s1_teaching_done: bool = false       # Year 2 Sem 1 all modules complete
var ch2_y2s1_current_module: int = 0           # 0-3 (which module player is on)
var ch2_y2s2_teaching_done: bool = false       # Year 2 Sem 2 all modules complete
var ch2_y2s2_current_module: int = 0           # 0-3 (which module player is on)
var ch2_y3s1_teaching_done: bool = false       # Year 3 Sem 1 all modules complete
var ch2_y3s1_current_module: int = 0           # 0-2 (which module player is on)
var ch2_y3s2_teaching_done: bool = false       # Year 3 Sem 2 all modules complete
var ch2_y3s2_current_module: int = 0           # 0-1 (which module player is on)
var ch2_y3mid_teaching_done: bool = false      # Year 3 Midyear all modules complete
var ch2_y3mid_current_module: int = 0          # 0-1 (which module player is on)

# ─── Grade / Retake Tracking (per professor semester) ────────────────────────
# Y1S1 — Professor Markup (HTML, CSS, Web Basics)
var ch2_y1s1_retake_count: int = 0
var ch2_y1s1_wrong_attempts: int = 0
var ch2_y1s1_hints_used: int = 0
var ch2_y1s1_final_grade: float = 0.0
var ch2_y1s1_bonus_item_earned: bool = false
var ch2_y1s1_inc_triggered: bool = false
var ch2_y1s1_removal_passed: bool = false

# Y1S2 — Professor Syntax (Python Core & OOP)
var ch2_y1s2_retake_count: int = 0
var ch2_y1s2_wrong_attempts: int = 0
var ch2_y1s2_hints_used: int = 0
var ch2_y1s2_final_grade: float = 0.0
var ch2_y1s2_bonus_item_earned: bool = false
var ch2_y1s2_inc_triggered: bool = false
var ch2_y1s2_removal_passed: bool = false



# Y2S1 — Professor View (Django Setup & Views)
var ch2_y2s1_retake_count: int = 0
var ch2_y2s1_wrong_attempts: int = 0
var ch2_y2s1_hints_used: int = 0
var ch2_y2s1_final_grade: float = 0.0
var ch2_y2s1_bonus_item_earned: bool = false
var ch2_y2s1_inc_triggered: bool = false
var ch2_y2s1_removal_passed: bool = false

# Y2S2 — Professor Query (Models, ORM & Databases)
var ch2_y2s2_retake_count: int = 0
var ch2_y2s2_wrong_attempts: int = 0
var ch2_y2s2_hints_used: int = 0
var ch2_y2s2_final_grade: float = 0.0
var ch2_y2s2_bonus_item_earned: bool = false
var ch2_y2s2_inc_triggered: bool = false
var ch2_y2s2_removal_passed: bool = false

# ─── AI Minigame Skip Tracking (Prof Query Module 1 — Relationship Architecture) ───
# Tracks which of the three AI evaluator challenges were auto-skipped due to
# connection failures. "true" = skipped (teacher dashboard will flag it).
# These reset on each new full attempt (retake), NOT on individual challenge retries.
var ch2_y2s2_ai_oto_skipped: bool = false    # One-to-One challenge auto-skipped
var ch2_y2s2_ai_otm_skipped: bool = false    # One-to-Many challenge auto-skipped
var ch2_y2s2_ai_mtm_skipped: bool = false    # Many-to-Many challenge auto-skipped
var ch2_y2s2_ai_fully_offline: bool = false  # TRUE = all AI was down, full offline run

# ── AI Minigame skip flags — Prof Syntax (Y1S2: Data Type Detective) ──────
var ch2_y1s2_ai_data_types_skipped: bool = false
var ch2_y1s2_ai_fully_offline: bool = false

# ── AI Minigame skip flags — Prof View (Y2S1: Mailman URL Router) ─────────
var ch2_y2s1_ai_url_routing_skipped: bool = false
var ch2_y2s1_ai_fully_offline: bool = false

# ── AI Minigame skip flags — Prof Auth (Y3S2: ID Checker) ─────────────────
var ch2_y3s2_ai_auth_checker_skipped: bool = false
var ch2_y3s2_ai_fully_offline: bool = false

# ── AI Minigame skip flags — Prof REST (Y3MID: The 4 Verbs) ───────────────
var ch2_y3mid_ai_http_verbs_skipped: bool = false
var ch2_y3mid_ai_fully_offline: bool = false

# ─── Learning Mode Grading ───────────────────────────────────────────────────
var learning_mode_grades: Dictionary = {}

func update_learning_mode_grade(professor_id: String, new_grade: float) -> void:
	# Only keep the best (lowest numerical) grade
	if not learning_mode_grades.has(professor_id) or new_grade < learning_mode_grades[professor_id]:
		learning_mode_grades[professor_id] = new_grade
		print("CharacterData: Saved new best learning mode grade for ", professor_id, " -> ", new_grade)

# ─── Retake Loop Guard ───────────────────────────────────────────────────────
func reset_ai_skip_flags_y2s2() -> void:
	ch2_y2s2_ai_oto_skipped = false
	ch2_y2s2_ai_otm_skipped = false
	ch2_y2s2_ai_mtm_skipped = false
	ch2_y2s2_ai_fully_offline = false
	print("CharacterData: AI skip flags for Y2S2 cleared (retake loop guard).")

func get_ai_skip_count_y2s2() -> int:
	var count = 0
	if ch2_y2s2_ai_oto_skipped: count += 1
	if ch2_y2s2_ai_otm_skipped: count += 1
	if ch2_y2s2_ai_mtm_skipped: count += 1
	return count

func reset_ai_skip_flags_all() -> void:
	reset_ai_skip_flags_y2s2()
	ch2_y1s2_ai_data_types_skipped = false
	ch2_y1s2_ai_fully_offline = false
	ch2_y2s1_ai_url_routing_skipped = false
	ch2_y2s1_ai_fully_offline = false
	ch2_y3s2_ai_auth_checker_skipped = false
	ch2_y3s2_ai_fully_offline = false
	ch2_y3mid_ai_http_verbs_skipped = false
	ch2_y3mid_ai_fully_offline = false
	print("CharacterData: All AI skip flags cleared.")


# Y3S1 — Professor Token (Forms & Security)
var ch2_y3s1_retake_count: int = 0
var ch2_y3s1_wrong_attempts: int = 0
var ch2_y3s1_hints_used: int = 0
var ch2_y3s1_final_grade: float = 0.0
var ch2_y3s1_bonus_item_earned: bool = false
var ch2_y3s1_inc_triggered: bool = false
var ch2_y3s1_removal_passed: bool = false

# Y3S2 — Professor Auth (Authentication & CRUD)
var ch2_y3s2_retake_count: int = 0
var ch2_y3s2_wrong_attempts: int = 0
var ch2_y3s2_hints_used: int = 0
var ch2_y3s2_final_grade: float = 0.0
var ch2_y3s2_bonus_item_earned: bool = false
var ch2_y3s2_inc_triggered: bool = false
var ch2_y3s2_removal_passed: bool = false

# Y3 Midyear — Professor REST (APIs & Modern Systems)
var ch2_y3mid_retake_count: int = 0
var ch2_y3mid_wrong_attempts: int = 0
var ch2_y3mid_hints_used: int = 0
var ch2_y3mid_final_grade: float = 0.0
var ch2_y3mid_bonus_item_earned: bool = false
var ch2_y3mid_inc_triggered: bool = false
var ch2_y3mid_removal_passed: bool = false

# Challenges completed counter (for teacher dashboard tracking)
var challenges_completed: int = 0

# Currency system
var credits: int = 0

# Tracks which ChallengeNPCs have been defeated (one-time rewards)
var defeated_challenge_npcs: Array = []

# Level unlock tracking (index 0 = level 1, etc.)
const LEVEL_COUNT = 4
var unlocked_levels: Array[bool] = [true, false, false, false]
var unlocked_books_and_minigames: Array[bool] = [true, false, false, false]

# Tracks which world items have been picked up (by node name) to prevent respawn
var picked_up_items: Array = []

func reset_data():
	selected_gender = ""
	player_name = ""
	api_username = ""
	has_seen_tutorial = false
	has_seen_learning_mode_intro = false
	has_seen_controls_tutorial = false
	has_seen_inventory_tutorial = false
	has_seen_laptop_tutorial = false
	has_seen_ide_tutorial = false
	has_seen_college_sis_tutorial = false
	has_seen_overflow_stack_tutorial = false
	has_reached_college = false
	ch1_teaching_done = false
	ch1_quiz_done = false
	ch1_quiz_score = 0
	ch1_did_remedial = false
	ch1_remedial_score = 0
	ch1_post_quiz_dialogue_done = false
	ch1_convenience_store_cutscene_done = false
	ch1_spaghetti_guy_cutscene_done = false
	ch2_y1s1_teaching_done = false
	ch2_y1s1_current_module = 0
	ch2_y1s2_teaching_done = false
	ch2_y1s2_current_module = 0
	ch2_y2s1_teaching_done = false
	ch2_y2s1_current_module = 0
	ch2_y2s2_teaching_done = false
	ch2_y2s2_current_module = 0
	ch2_y3s1_teaching_done = false
	ch2_y3s1_current_module = 0
	ch2_y3s2_teaching_done = false
	ch2_y3s2_current_module = 0
	ch2_y3mid_teaching_done = false
	ch2_y3mid_current_module = 0
	# Grade / Retake tracking reset
	for prefix in ["y1s1", "y1s2", "y2s1", "y2s2", "y3s1", "y3s2", "y3mid"]:
		set("ch2_%s_retake_count" % prefix, 0)
		set("ch2_%s_wrong_attempts" % prefix, 0)
		set("ch2_%s_hints_used" % prefix, 0)
		set("ch2_%s_final_grade" % prefix, 0.0)
		set("ch2_%s_bonus_item_earned" % prefix, false)
		set("ch2_%s_inc_triggered" % prefix, false)
		set("ch2_%s_removal_passed" % prefix, false)
	# AI skip flags
	reset_ai_skip_flags_all()
	challenges_completed = 0
	credits = 0
	defeated_challenge_npcs = []
	unlocked_levels = [true, false, false, false]
	unlocked_books_and_minigames = [true, false, false, false]
	picked_up_items = []

func set_all_data(name: String, gender: String, ul1: bool, ul2: bool, ul3: bool, ul4: bool,
	ubam1: bool, ubam2: bool, ubam3: bool, ubam4: bool):
	player_name = name
	selected_gender = gender
	unlocked_levels = [ul1, ul2, ul3, ul4]
	unlocked_books_and_minigames = [ubam1, ubam2, ubam3, ubam4]

# ─── Save / Load helpers ────────────────────────────────────────────────────

func to_save_dict() -> Dictionary:
	"""Serialize all game progress state into a Dictionary for saving."""
	var d: Dictionary = {
		"player_name": player_name,
		"selected_gender": selected_gender,
		"api_username": api_username,
		"has_seen_tutorial": has_seen_tutorial,
		"has_seen_learning_mode_intro": has_seen_learning_mode_intro,
		"has_seen_controls_tutorial": has_seen_controls_tutorial,
		"has_seen_inventory_tutorial": has_seen_inventory_tutorial,
		"has_seen_laptop_tutorial": has_seen_laptop_tutorial,
		"has_seen_ide_tutorial": has_seen_ide_tutorial,
		"has_seen_college_sis_tutorial": has_seen_college_sis_tutorial,
		"has_seen_overflow_stack_tutorial": has_seen_overflow_stack_tutorial,
		"has_reached_college": has_reached_college,
		# Chapter 1
		"ch1_teaching_done": ch1_teaching_done,
		"ch1_quiz_done": ch1_quiz_done,
		"ch1_quiz_score": ch1_quiz_score,
		"ch1_did_remedial": ch1_did_remedial,
		"ch1_remedial_score": ch1_remedial_score,
		"ch1_post_quiz_dialogue_done": ch1_post_quiz_dialogue_done,
		"ch1_convenience_store_cutscene_done": ch1_convenience_store_cutscene_done,
		"ch1_spaghetti_guy_cutscene_done": ch1_spaghetti_guy_cutscene_done,
		# Chapter 2 — semesters
		"ch2_y1s1_teaching_done": ch2_y1s1_teaching_done,
		"ch2_y1s1_current_module": ch2_y1s1_current_module,
		"ch2_y1s2_teaching_done": ch2_y1s2_teaching_done,
		"ch2_y1s2_current_module": ch2_y1s2_current_module,
		"ch2_y2s1_teaching_done": ch2_y2s1_teaching_done,
		"ch2_y2s1_current_module": ch2_y2s1_current_module,
		"ch2_y2s2_teaching_done": ch2_y2s2_teaching_done,
		"ch2_y2s2_current_module": ch2_y2s2_current_module,
		"ch2_y3s1_teaching_done": ch2_y3s1_teaching_done,
		"ch2_y3s1_current_module": ch2_y3s1_current_module,
		"ch2_y3s2_teaching_done": ch2_y3s2_teaching_done,
		"ch2_y3s2_current_module": ch2_y3s2_current_module,
		"ch2_y3mid_teaching_done": ch2_y3mid_teaching_done,
		"ch2_y3mid_current_module": ch2_y3mid_current_module,
	}
	for prefix in ["y1s1", "y1s2", "y2s1", "y2s2", "y3s1", "y3s2", "y3mid"]:
		for suffix in ["retake_count", "wrong_attempts", "hints_used", "final_grade",
			"bonus_item_earned", "inc_triggered", "removal_passed"]:
			var key = "ch2_%s_%s" % [prefix, suffix]
			d[key] = get(key)
	# AI minigame skip flags (Y2S2 — Prof Query)
	d["ch2_y2s2_ai_oto_skipped"] = ch2_y2s2_ai_oto_skipped
	d["ch2_y2s2_ai_otm_skipped"] = ch2_y2s2_ai_otm_skipped
	d["ch2_y2s2_ai_mtm_skipped"] = ch2_y2s2_ai_mtm_skipped
	d["ch2_y2s2_ai_fully_offline"] = ch2_y2s2_ai_fully_offline
	# AI minigame skip flags — other professors
	d["ch2_y1s2_ai_data_types_skipped"] = ch2_y1s2_ai_data_types_skipped
	d["ch2_y1s2_ai_fully_offline"] = ch2_y1s2_ai_fully_offline
	d["ch2_y2s1_ai_url_routing_skipped"] = ch2_y2s1_ai_url_routing_skipped
	d["ch2_y2s1_ai_fully_offline"] = ch2_y2s1_ai_fully_offline
	d["ch2_y3s2_ai_auth_checker_skipped"] = ch2_y3s2_ai_auth_checker_skipped
	d["ch2_y3s2_ai_fully_offline"] = ch2_y3s2_ai_fully_offline
	d["ch2_y3mid_ai_http_verbs_skipped"] = ch2_y3mid_ai_http_verbs_skipped
	d["ch2_y3mid_ai_fully_offline"] = ch2_y3mid_ai_fully_offline
	d.merge({
		# Tracking
		"challenges_completed": challenges_completed,
		"credits": credits,
		"defeated_challenge_npcs": defeated_challenge_npcs,
		"learning_mode_grades": learning_mode_grades,
		# Unlocks
		"unlocked_level_1": unlocked_levels[0],
		"unlocked_level_2": unlocked_levels[1],
		"unlocked_level_3": unlocked_levels[2],
		"unlocked_level_4": unlocked_levels[3],
		"unlocked_book_and_minigame_1": unlocked_books_and_minigames[0],
		"unlocked_book_and_minigame_2": unlocked_books_and_minigames[1],
		"unlocked_book_and_minigame_3": unlocked_books_and_minigames[2],
		"unlocked_book_and_minigame_4": unlocked_books_and_minigames[3],
		# Picked up world items
		"picked_up_items": picked_up_items,
	})
	return d


func from_save_dict(data: Dictionary):
	"""Restore all game progress state from a saved Dictionary."""
	player_name = data.get("player_name", "")
	selected_gender = data.get("selected_gender", "")
	api_username = data.get("api_username", "")
	has_seen_tutorial = data.get("has_seen_tutorial", false)
	has_seen_learning_mode_intro = data.get("has_seen_learning_mode_intro", false)
	has_seen_controls_tutorial = data.get("has_seen_controls_tutorial", false)
	has_seen_inventory_tutorial = data.get("has_seen_inventory_tutorial", false)
	has_seen_laptop_tutorial = data.get("has_seen_laptop_tutorial", false)
	has_seen_ide_tutorial = data.get("has_seen_ide_tutorial", false)
	has_seen_college_sis_tutorial = data.get("has_seen_college_sis_tutorial", false)
	has_seen_overflow_stack_tutorial = data.get("has_seen_overflow_stack_tutorial", false)
	has_reached_college = data.get("has_reached_college", false)
	# Chapter 1
	ch1_teaching_done = data.get("ch1_teaching_done", false)
	ch1_quiz_done = data.get("ch1_quiz_done", false)
	ch1_quiz_score = int(data.get("ch1_quiz_score", 0))
	ch1_did_remedial = data.get("ch1_did_remedial", false)
	ch1_remedial_score = int(data.get("ch1_remedial_score", 0))
	ch1_post_quiz_dialogue_done = data.get("ch1_post_quiz_dialogue_done", false)
	ch1_convenience_store_cutscene_done = data.get("ch1_convenience_store_cutscene_done", false)
	ch1_spaghetti_guy_cutscene_done = data.get("ch1_spaghetti_guy_cutscene_done", false)
	# Chapter 2 — semesters
	ch2_y1s1_teaching_done = data.get("ch2_y1s1_teaching_done", false)
	ch2_y1s1_current_module = int(data.get("ch2_y1s1_current_module", 0))
	ch2_y1s2_teaching_done = data.get("ch2_y1s2_teaching_done", false)
	ch2_y1s2_current_module = int(data.get("ch2_y1s2_current_module", 0))
	ch2_y2s1_teaching_done = data.get("ch2_y2s1_teaching_done", false)
	ch2_y2s1_current_module = int(data.get("ch2_y2s1_current_module", 0))
	ch2_y2s2_teaching_done = data.get("ch2_y2s2_teaching_done", false)
	ch2_y2s2_current_module = int(data.get("ch2_y2s2_current_module", 0))
	ch2_y3s1_teaching_done = data.get("ch2_y3s1_teaching_done", false)
	ch2_y3s1_current_module = int(data.get("ch2_y3s1_current_module", 0))
	ch2_y3s2_teaching_done = data.get("ch2_y3s2_teaching_done", false)
	ch2_y3s2_current_module = int(data.get("ch2_y3s2_current_module", 0))
	ch2_y3mid_teaching_done = data.get("ch2_y3mid_teaching_done", false)
	ch2_y3mid_current_module = int(data.get("ch2_y3mid_current_module", 0))
	# Grade / Retake tracking
	for prefix in ["y1s1", "y1s2", "y2s1", "y2s2", "y3s1", "y3s2", "y3mid"]:
		set("ch2_%s_retake_count" % prefix, int(data.get("ch2_%s_retake_count" % prefix, 0)))
		set("ch2_%s_wrong_attempts" % prefix, int(data.get("ch2_%s_wrong_attempts" % prefix, 0)))
		set("ch2_%s_hints_used" % prefix, int(data.get("ch2_%s_hints_used" % prefix, 0)))
		set("ch2_%s_final_grade" % prefix, float(data.get("ch2_%s_final_grade" % prefix, 0.0)))
		set("ch2_%s_bonus_item_earned" % prefix, data.get("ch2_%s_bonus_item_earned" % prefix, false))
		set("ch2_%s_inc_triggered" % prefix, data.get("ch2_%s_inc_triggered" % prefix, false))
		set("ch2_%s_removal_passed" % prefix, data.get("ch2_%s_removal_passed" % prefix, false))
	# AI skip flags — Prof Query
	ch2_y2s2_ai_oto_skipped = data.get("ch2_y2s2_ai_oto_skipped", false)
	ch2_y2s2_ai_otm_skipped = data.get("ch2_y2s2_ai_otm_skipped", false)
	ch2_y2s2_ai_mtm_skipped = data.get("ch2_y2s2_ai_mtm_skipped", false)
	ch2_y2s2_ai_fully_offline = data.get("ch2_y2s2_ai_fully_offline", false)
	# AI skip flags — other professors
	ch2_y1s2_ai_data_types_skipped = data.get("ch2_y1s2_ai_data_types_skipped", false)
	ch2_y1s2_ai_fully_offline = data.get("ch2_y1s2_ai_fully_offline", false)
	ch2_y2s1_ai_url_routing_skipped = data.get("ch2_y2s1_ai_url_routing_skipped", false)
	ch2_y2s1_ai_fully_offline = data.get("ch2_y2s1_ai_fully_offline", false)
	ch2_y3s2_ai_auth_checker_skipped = data.get("ch2_y3s2_ai_auth_checker_skipped", false)
	ch2_y3s2_ai_fully_offline = data.get("ch2_y3s2_ai_fully_offline", false)
	ch2_y3mid_ai_http_verbs_skipped = data.get("ch2_y3mid_ai_http_verbs_skipped", false)
	ch2_y3mid_ai_fully_offline = data.get("ch2_y3mid_ai_fully_offline", false)
	# Tracking
	learning_mode_grades = data.get("learning_mode_grades", {})
	challenges_completed = int(data.get("challenges_completed", 0))
	credits = int(data.get("credits", 0))
	defeated_challenge_npcs = data.get("defeated_challenge_npcs", [])
	# Unlocks
	unlocked_levels = [
		data.get("unlocked_level_1", true),
		data.get("unlocked_level_2", false),
		data.get("unlocked_level_3", false),
		data.get("unlocked_level_4", false),
	]
	unlocked_books_and_minigames = [
		data.get("unlocked_book_and_minigame_1", true),
		data.get("unlocked_book_and_minigame_2", false),
		data.get("unlocked_book_and_minigame_3", false),
		data.get("unlocked_book_and_minigame_4", false),
	]
	# Picked up world items
	picked_up_items = data.get("picked_up_items", [])
	apply_debug_skips()

# --- Convenience getters/setters for backward compatibility ---
# These properties let existing code like `character_data.unlocked_level_2 = true` still work.

var unlocked_level_1: bool:
	get: return unlocked_levels[0]
	set(v): unlocked_levels[0] = v

var unlocked_level_2: bool:
	get: return unlocked_levels[1]
	set(v): unlocked_levels[1] = v

var unlocked_level_3: bool:
	get: return unlocked_levels[2]
	set(v): unlocked_levels[2] = v

var unlocked_level_4: bool:
	get: return unlocked_levels[3]
	set(v): unlocked_levels[3] = v

var unlocked_book_and_minigame_1: bool:
	get: return unlocked_books_and_minigames[0]
	set(v): unlocked_books_and_minigames[0] = v

var unlocked_book_and_minigame_2: bool:
	get: return unlocked_books_and_minigames[1]
	set(v): unlocked_books_and_minigames[1] = v

var unlocked_book_and_minigame_3: bool:
	get: return unlocked_books_and_minigames[2]
	set(v): unlocked_books_and_minigames[2] = v

var unlocked_book_and_minigame_4: bool:
	get: return unlocked_books_and_minigames[3]
	set(v): unlocked_books_and_minigames[3] = v

# --- Scalable helpers ---

func is_level_unlocked(level_number: int) -> bool:
	var idx = level_number - 1
	if idx >= 0 and idx < unlocked_levels.size():
		return unlocked_levels[idx]
	return false

func unlock_level(level_number: int):
	var idx = level_number - 1
	if idx >= 0 and idx < unlocked_levels.size():
		unlocked_levels[idx] = true

func is_book_unlocked(level_number: int) -> bool:
	var idx = level_number - 1
	if idx >= 0 and idx < unlocked_books_and_minigames.size():
		return unlocked_books_and_minigames[idx]
	return false

func unlock_book(level_number: int):
	var idx = level_number - 1
	if idx >= 0 and idx < unlocked_books_and_minigames.size():
		unlocked_books_and_minigames[idx] = true

# --- Debug skip functionality ---
# --- Make it false after testing ---
@export var DEBUG_SKIP_TO_REST_PROFESSOR: bool = false
@export var DEBUG_SKIP_TO_AUTH_PROFESSOR: bool = false
@export var DEBUG_SKIP_TO_TOKEN_PROFESSOR: bool = false
@export var DEBUG_SKIP_TO_VIEW_PROFESSOR: bool = false
@export var DEBUG_SKIP_TO_QUERY_PROFESSOR: bool = false

func _ready():
	apply_debug_skips()

func apply_debug_skips():
	if DEBUG_SKIP_TO_REST_PROFESSOR:
		ch2_y1s1_teaching_done = true
		ch2_y1s1_final_grade = 1.50
		ch2_y1s2_teaching_done = true
		ch2_y1s2_final_grade = 2.25
		ch2_y2s1_teaching_done = true
		ch2_y2s1_final_grade = 1.75
		ch2_y2s2_teaching_done = true
		ch2_y2s2_final_grade = 2.25
		ch2_y3s1_teaching_done = true
		ch2_y3s1_final_grade = 2.75
		ch2_y3s2_teaching_done = true
		ch2_y3s2_final_grade = 2.00
		print("DEBUG: All professors prior to REST skipped (Y1S1 -> Y3S2 done with mock grades).")
	elif DEBUG_SKIP_TO_AUTH_PROFESSOR:
		ch2_y1s1_teaching_done = true
		ch2_y1s1_final_grade = 1.50
		ch2_y1s2_teaching_done = true
		ch2_y1s2_final_grade = 2.25
		ch2_y2s1_teaching_done = true
		ch2_y2s1_final_grade = 1.75
		ch2_y2s2_teaching_done = true
		ch2_y2s2_final_grade = 2.25
		ch2_y3s1_teaching_done = true
		ch2_y3s1_final_grade = 2.75
		print("DEBUG: Skipped to Professor Auth. Mock grades injected.")
	elif DEBUG_SKIP_TO_TOKEN_PROFESSOR:
		ch2_y1s1_teaching_done = true
		ch2_y1s1_final_grade = 1.50
		ch2_y1s2_teaching_done = true
		ch2_y1s2_final_grade = 2.25
		ch2_y2s1_teaching_done = true
		ch2_y2s1_final_grade = 1.75
		ch2_y2s2_teaching_done = true
		ch2_y2s2_final_grade = 2.25
		print("DEBUG: Skipped to Professor Token. Mock grades injected.")
	elif DEBUG_SKIP_TO_VIEW_PROFESSOR:
		ch2_y1s1_teaching_done = true
		ch2_y1s1_final_grade = 1.50
		ch2_y1s2_teaching_done = true
		ch2_y1s2_final_grade = 2.25
		print("DEBUG: Skipped to Professor View. Mock grades injected.")
	elif DEBUG_SKIP_TO_QUERY_PROFESSOR:
		ch2_y1s1_teaching_done = true
		ch2_y1s1_final_grade = 1.50
		ch2_y1s2_teaching_done = true
		ch2_y1s2_final_grade = 2.25
		ch2_y2s1_teaching_done = true
		ch2_y2s1_final_grade = 1.75
		print("DEBUG: Skipped to Professor Query. Mock grades injected.")

# ─── Currency Helpers ────────────────────────────────────────────────────────

func add_credits(amount: int) -> void:
	credits += amount
	print("Credits: +%d (total: %d)" % [amount, credits])

func spend_credits(amount: int) -> bool:
	if credits >= amount:
		credits -= amount
		print("Credits: -%d (total: %d)" % [amount, credits])
		return true
	return false

func get_credits() -> int:
	return credits

func is_npc_defeated(npc_id: String) -> bool:
	return npc_id in defeated_challenge_npcs

func mark_npc_defeated(npc_id: String) -> void:
	if npc_id not in defeated_challenge_npcs:
		defeated_challenge_npcs.append(npc_id)
