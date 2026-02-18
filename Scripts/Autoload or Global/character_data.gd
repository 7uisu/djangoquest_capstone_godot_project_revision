# scripts/Autoload or Global/character_data.gd
extends Node

var selected_gender: String = ""  # "male" or "female"
var player_name: String = ""

# Level unlock tracking (index 0 = level 1, etc.)
const LEVEL_COUNT = 4
var unlocked_levels: Array[bool] = [true, false, false, false]
var unlocked_books_and_minigames: Array[bool] = [true, false, false, false]

func reset_data():
	selected_gender = ""
	player_name = ""
	unlocked_levels = [true, false, false, false]
	unlocked_books_and_minigames = [true, false, false, false]

func set_all_data(name: String, gender: String, ul1: bool, ul2: bool, ul3: bool, ul4: bool,
	ubam1: bool, ubam2: bool, ubam3: bool, ubam4: bool):
	player_name = name
	selected_gender = gender
	unlocked_levels = [ul1, ul2, ul3, ul4]
	unlocked_books_and_minigames = [ubam1, ubam2, ubam3, ubam4]

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
