# scripts/Autoload or Global/character_data.gd
extends Node

var selected_gender: String = ""  # "male" or "female"
var player_name: String = ""
var api_username: String = ""  # Username from Django API login (empty if guest)
var has_seen_tutorial: bool = false
var has_seen_learning_mode_intro: bool = false

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

# Challenges completed counter (for teacher dashboard tracking)
var challenges_completed: int = 0

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
	challenges_completed = 0
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
	return {
		"player_name": player_name,
		"selected_gender": selected_gender,
		"api_username": api_username,
		"has_seen_tutorial": has_seen_tutorial,
		"has_seen_learning_mode_intro": has_seen_learning_mode_intro,
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
		# Tracking
		"challenges_completed": challenges_completed,
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
	}

func from_save_dict(data: Dictionary):
	"""Restore all game progress state from a saved Dictionary."""
	player_name = data.get("player_name", "")
	selected_gender = data.get("selected_gender", "")
	api_username = data.get("api_username", "")
	has_seen_tutorial = data.get("has_seen_tutorial", false)
	has_seen_learning_mode_intro = data.get("has_seen_learning_mode_intro", false)
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
	# Tracking
	challenges_completed = int(data.get("challenges_completed", 0))
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

func _ready():
	if DEBUG_SKIP_TO_REST_PROFESSOR:
		ch2_y1s1_teaching_done = true
		ch2_y1s2_teaching_done = true
		ch2_y2s1_teaching_done = true
		ch2_y2s2_teaching_done = true
		ch2_y3s1_teaching_done = true
		ch2_y3s2_teaching_done = true
		print("DEBUG: All professors prior to REST skipped (Y1S1 -> Y3S2 done).")
