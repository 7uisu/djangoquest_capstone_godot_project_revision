# scripts/Autoload or Global/save_manager.gd
extends Node

const SAVE_SLOT_COUNT = 3
const SAVE_FILE_PATTERN = "user://save_game_slot_%s.json" # Using .json for readability

signal game_loaded(save_data)
signal save_slots_updated # To refresh UIs displaying save slot info

# Default data for an empty slot or a new game state before first save
func get_default_slot_data() -> Dictionary:
	return {
		"slot_in_use": false,
		"player_name": "Empty Slot",
		"selected_gender": "",
		"current_scene_path": "res://scenes/hub_area.tscn", # Default starting point
		"unlocked_level_1": true, # As per CharacterData default
		"unlocked_level_2": false,
		"unlocked_level_3": false,
		"unlocked_level_4": false,
		"unlocked_book_and_minigame_1": true, # Books/minigames unlock separately
		"unlocked_book_and_minigame_2": false,
		"unlocked_book_and_minigame_3": false,
		"unlocked_book_and_minigame_4": false,
		"timestamp": 0 # Unix timestamp of save
	}

func save_game(slot_index: int, game_data: Dictionary) -> bool:
	if slot_index < 0 or slot_index >= SAVE_SLOT_COUNT:
		printerr("SaveManager: Invalid save slot index: ", slot_index)
		return false

	var character_data_node = get_node("/root/CharacterData")
	if not character_data_node:
		printerr("SaveManager: CharacterData node not found. Cannot determine data to save.")
		return false

	var data_to_save = get_default_slot_data() # Start with defaults
	data_to_save.merge(game_data, true) # Merge provided game_data, overwriting defaults

	# Ensure core data from CharacterData is included
	data_to_save["player_name"] = character_data_node.player_name
	data_to_save["selected_gender"] = character_data_node.selected_gender
	# Level selector unlocks
	data_to_save["unlocked_level_1"] = character_data_node.unlocked_level_1
	data_to_save["unlocked_level_2"] = character_data_node.unlocked_level_2
	data_to_save["unlocked_level_3"] = character_data_node.unlocked_level_3
	data_to_save["unlocked_level_4"] = character_data_node.unlocked_level_4
	# Book/minigame unlocks
	data_to_save["unlocked_book_and_minigame_1"] = character_data_node.unlocked_book_and_minigame_1
	data_to_save["unlocked_book_and_minigame_2"] = character_data_node.unlocked_book_and_minigame_2
	data_to_save["unlocked_book_and_minigame_3"] = character_data_node.unlocked_book_and_minigame_3
	data_to_save["unlocked_book_and_minigame_4"] = character_data_node.unlocked_book_and_minigame_4
	
	data_to_save["current_scene_path"] = get_tree().current_scene.scene_file_path # Save current location
	data_to_save["slot_in_use"] = true
	data_to_save["timestamp"] = Time.get_unix_time_from_system()

	var file_path = SAVE_FILE_PATTERN % slot_index
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if FileAccess.get_open_error() != OK:
		printerr("SaveManager: Error opening file for writing: ", file_path)
		return false

	var json_string = JSON.stringify(data_to_save, "\t") # Pretty print
	file.store_string(json_string)
	file.close()
	print("SaveManager: Game saved to slot %s." % slot_index)
	emit_signal("save_slots_updated")
	return true

func load_game(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SAVE_SLOT_COUNT:
		printerr("SaveManager: Invalid load slot index: ", slot_index)
		return false

	var file_path = SAVE_FILE_PATTERN % slot_index
	if not FileAccess.file_exists(file_path):
		printerr("SaveManager: Save file not found for slot: ", slot_index)
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		printerr("SaveManager: Error opening file for reading: ", file_path)
		return false

	var json_string = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(json_string)
	if parse_result == null:
		printerr("SaveManager: Error parsing save file JSON for slot: ", slot_index)
		# Optionally, try to delete or mark as corrupt
		return false

	var loaded_data: Dictionary = parse_result
	if not loaded_data.get("slot_in_use", false):
		printerr("SaveManager: Attempted to load an empty or invalid slot: ", slot_index)
		return false

	var character_data_node = get_node("/root/CharacterData")
	if character_data_node:
		character_data_node.set_all_data(
			loaded_data.get("player_name", ""),
			loaded_data.get("selected_gender", ""),
			loaded_data.get("unlocked_level_1", true),
			loaded_data.get("unlocked_level_2", false),
			loaded_data.get("unlocked_level_3", false),
			loaded_data.get("unlocked_level_4", false),
			loaded_data.get("unlocked_book_and_minigame_1", true),
			loaded_data.get("unlocked_book_and_minigame_2", false),
			loaded_data.get("unlocked_book_and_minigame_3", false),
			loaded_data.get("unlocked_book_and_minigame_4", false)
		)
	else:
		printerr("SaveManager: CharacterData node not found. Cannot apply loaded data.")
		return false # Critical failure

	print("SaveManager: Game loaded from slot %s." % slot_index)
	emit_signal("game_loaded", loaded_data) # Other systems might want full data

	var scene_to_load = loaded_data.get("current_scene_path", "res://scenes/hub_area.tscn")
	if get_tree().change_scene_to_file(scene_to_load) != OK:
		printerr("SaveManager: Failed to change scene to ", scene_to_load, ". Fallback to hub.")
		get_tree().change_scene_to_file("res://scenes/hub_area.tscn") # Fallback
	return true


func delete_save(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SAVE_SLOT_COUNT:
		printerr("SaveManager: Invalid delete slot index: ", slot_index)
		return false

	var file_path = SAVE_FILE_PATTERN % slot_index
	if FileAccess.file_exists(file_path):
		var dir = DirAccess.open("user://") # DirAccess needed for remove
		var err = dir.remove(file_path.replace("user://", "")) # remove expects relative path
		if err == OK:
			print("SaveManager: Save file deleted for slot: ", slot_index)
			emit_signal("save_slots_updated")
			return true
		else:
			printerr("SaveManager: Error deleting save file for slot ", slot_index, ". Error code: ", err)
			return false
	else:
		print("SaveManager: No save file to delete for slot: ", slot_index)
		return true # No file existed, so it's "deleted" in a sense

func get_save_slot_info(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= SAVE_SLOT_COUNT:
		return get_default_slot_data()

	var file_path = SAVE_FILE_PATTERN % slot_index
	if not FileAccess.file_exists(file_path):
		return get_default_slot_data()

	var file = FileAccess.open(file_path, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		return get_default_slot_data() # Return default on error

	var json_string = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(json_string)
	if parse_result == null or not parse_result.get("slot_in_use", false):
		return get_default_slot_data()

	return parse_result

func get_all_save_slots_info() -> Array[Dictionary]:
	# Explicitly declare the array type to help the type checker
	var slots_data: Array[Dictionary] = []
	for i in range(SAVE_SLOT_COUNT):
		slots_data.append(get_save_slot_info(i))
	return slots_data

func are_all_slots_full() -> bool:
	for i in range(SAVE_SLOT_COUNT):
		var slot_data = get_save_slot_info(i)
		if not slot_data.get("slot_in_use", false):
			return false
	return true

# Unlock level selector levels (for world map/level selection)
func unlock_level_in_character_data(level_number: int):
	var character_data_node = get_node("/root/CharacterData")
	if character_data_node:
		match level_number:
			2: character_data_node.unlocked_level_2 = true
			3: character_data_node.unlocked_level_3 = true
			4: character_data_node.unlocked_level_4 = true
		print("SaveManager: Level %s unlocked in CharacterData for current session." % level_number)
	else:
		printerr("SaveManager: CharacterData not found. Cannot unlock level %s." % level_number)

# Unlock book/minigame content (for Django learning system)
func unlock_book_and_minigame_in_character_data(level_number: int):
	var character_data_node = get_node("/root/CharacterData")
	if character_data_node:
		match level_number:
			2: character_data_node.unlocked_book_and_minigame_2 = true
			3: character_data_node.unlocked_book_and_minigame_3 = true
			4: character_data_node.unlocked_book_and_minigame_4 = true
		print("SaveManager: Book and Minigame %s unlocked in CharacterData for current session." % level_number)
	else:
		printerr("SaveManager: CharacterData not found. Cannot unlock book and minigame %s." % level_number)

# Call this when a new game is truly started (e.g., after intro cutscene/name input)
func prepare_new_game_session_data():
	var character_data_node = get_node("/root/CharacterData")
	if character_data_node:
		character_data_node.reset_data()
		# Player name and gender would be set by name_input.tscn and character_select.tscn
		print("SaveManager: Prepared CharacterData for a new game session.")
