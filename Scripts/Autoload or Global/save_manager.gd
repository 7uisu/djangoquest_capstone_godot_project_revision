# scripts/Autoload or Global/save_manager.gd
# Single-slot save system: one guest save (local only) + one account save (local + cloud).
extends Node

const GUEST_SAVE_FILE: String = "user://guest_save.json"
const ACCOUNT_SAVE_FILE: String = "user://account_save.json"

signal save_completed(success: bool, message: String)
signal load_completed(success: bool)
signal cloud_save_checked(has_cloud_save: bool)

# Set to true while a cloud download is in progress (used by main menu)
var _cloud_check_in_progress: bool = false
var _cloud_save_data: Dictionary = {}

# ─── Public API ──────────────────────────────────────────────────────────────

func save_game() -> void:
	var cd = get_node_or_null("/root/CharacterData")
	if not cd:
		emit_signal("save_completed", false, "CharacterData not found.")
		return

	var save_data: Dictionary = cd.to_save_dict()
	# Add scene path so we can restore position
	save_data["current_scene_path"] = get_tree().current_scene.scene_file_path
	save_data["timestamp"] = Time.get_unix_time_from_system()

	# Save tracked quest
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		save_data["tracked_quest_id"] = qm.tracked_quest_id

	# Save player position within the scene
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player = players[0] as Node2D
		if player:
			save_data["player_x"] = player.global_position.x
			save_data["player_y"] = player.global_position.y

	# Serialize inventory items (excluding non-serializable Texture2D)
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		var inv_items: Array = []
		for item in inv.get_items():
			var ipath = ""
			if item.get("icon") and item["icon"] is Texture2D:
				ipath = item["icon"].resource_path
			inv_items.append({
				"id": item["id"],
				"name": item["name"],
				"description": item.get("description", ""),
				"quantity": item.get("quantity", 1),
				"icon_path": ipath
			})
		save_data["inventory"] = inv_items

	# Write to the correct local file
	var file_path: String = _get_save_path()
	var ok = _write_json(file_path, save_data)
	if not ok:
		emit_signal("save_completed", false, "Failed to write save file.")
		return

	# If logged in, also upload to the cloud
	if ApiManager.is_logged_in():
		ApiManager.upload_save(save_data)
		# We don't wait for the cloud response — local save is the source of truth.
		# The signal from ApiManager will fire when the upload completes.

	print("SaveManager: Game saved to %s" % file_path)
	emit_signal("save_completed", true, "Game saved!")


func load_game() -> bool:
	var file_path: String = _get_save_path()

	# For logged-in users, prefer cloud data if available and newer
	if ApiManager.is_logged_in() and not _cloud_save_data.is_empty():
		var cloud_ts = float(_cloud_save_data.get("timestamp", 0))
		var local_data = _read_json(file_path)
		var local_ts = float(local_data.get("timestamp", 0)) if not local_data.is_empty() else 0.0

		if cloud_ts > local_ts:
			print("SaveManager: Using newer cloud save.")
			_apply_save(_cloud_save_data)
			# Also update local copy
			_write_json(file_path, _cloud_save_data)
			return true

	# Fall back to local save
	var save_data = _read_json(file_path)
	if save_data.is_empty():
		printerr("SaveManager: No save data found at %s" % file_path)
		emit_signal("load_completed", false)
		return false

	_apply_save(save_data)
	return true


func has_save() -> bool:
	var path = _get_save_path()
	if FileAccess.file_exists(path):
		return true
	# For logged-in users, also check if cloud save was found
	if ApiManager.is_logged_in() and not _cloud_save_data.is_empty():
		return true
	return false


func get_save_summary() -> Dictionary:
	"""Return a brief summary for the main menu (player name + timestamp)."""
	var data = _read_json(_get_save_path())
	# Merge with cloud data if available and newer
	if ApiManager.is_logged_in() and not _cloud_save_data.is_empty():
		var cloud_ts = float(_cloud_save_data.get("timestamp", 0))
		var local_ts = float(data.get("timestamp", 0)) if not data.is_empty() else 0.0
		if cloud_ts > local_ts:
			data = _cloud_save_data

	if data.is_empty():
		return {}
	return {
		"player_name": data.get("player_name", "Unknown"),
		"timestamp": data.get("timestamp", 0),
		"current_scene_path": data.get("current_scene_path", ""),
	}


func delete_save() -> void:
	var path = _get_save_path()
	if FileAccess.file_exists(path):
		var dir = DirAccess.open("user://")
		dir.remove(path.replace("user://", ""))
		print("SaveManager: Deleted %s" % path)

	# If logged in, also delete cloud save
	if ApiManager.is_logged_in():
		ApiManager.delete_cloud_save()


func clear_account_save() -> void:
	"""Called on logout — clears the account save file (not the guest save)."""
	if FileAccess.file_exists(ACCOUNT_SAVE_FILE):
		var dir = DirAccess.open("user://")
		dir.remove(ACCOUNT_SAVE_FILE.replace("user://", ""))
		print("SaveManager: Cleared account save on logout.")
	_cloud_save_data = {}


func promote_guest_to_account() -> void:
	"""Checks if a guest save exists, changes its api_username, and saves it as account save."""
	if not FileAccess.file_exists(GUEST_SAVE_FILE):
		return
	var guest_data = _read_json(GUEST_SAVE_FILE)
	if not guest_data.is_empty():
		guest_data["api_username"] = ApiManager.get_username()
		_write_json(ACCOUNT_SAVE_FILE, guest_data)
		# Load the save immediately so we have the state to save to cloud
		_apply_save(guest_data)
		save_game()


func check_cloud_save() -> void:
	"""Trigger a cloud download to check if a save exists (async). Main menu calls this."""
	if not ApiManager.is_logged_in():
		emit_signal("cloud_save_checked", false)
		return
	_cloud_check_in_progress = true
	_cloud_save_data = {}
	ApiManager.download_save()


func prepare_new_game_session_data():
	var cd = get_node_or_null("/root/CharacterData")
	if cd:
		cd.reset_data()
		print("SaveManager: Prepared CharacterData for a new game session.")


# ─── Internal ────────────────────────────────────────────────────────────────

func _ready():
	# Listen for cloud download response
	if not ApiManager.save_downloaded.is_connected(_on_save_downloaded):
		ApiManager.save_downloaded.connect(_on_save_downloaded)

func _on_save_downloaded(success: bool, data: Dictionary):
	_cloud_check_in_progress = false
	if success:
		_cloud_save_data = data.get("save_data", {})
		print("SaveManager: Cloud save found (timestamp: %s)" % _cloud_save_data.get("timestamp", "?"))
	else:
		_cloud_save_data = {}
	emit_signal("cloud_save_checked", not _cloud_save_data.is_empty())


func _get_save_path() -> String:
	if ApiManager.is_logged_in():
		return ACCOUNT_SAVE_FILE
	return GUEST_SAVE_FILE


func _apply_save(save_data: Dictionary) -> void:
	var cd = get_node_or_null("/root/CharacterData")
	if cd:
		cd.from_save_dict(save_data)

	# Restore tracked quest
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		var tracked_id = save_data.get("tracked_quest_id", "")
		if tracked_id != "":
			qm.tracked_quest_id = tracked_id

	# Restore inventory
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		inv.clear()
		var items = save_data.get("inventory", [])
		for item in items:
			var item_id = item.get("id", "")
			# Restore icon from CodingItems registry or from generic resource_path
			var icon: Texture2D = null
			if item_id != "" and CodingItems.ITEMS.has(item_id):
				icon = CodingItems.get_icon(item_id)
			elif item.get("icon_path", "") != "":
				var tex = load(item["icon_path"])
				if tex is Texture2D:
					icon = tex
			inv.add_item(
				item_id,
				item.get("name", ""),
				item.get("description", ""),
				icon,
				int(item.get("quantity", 1))
			)

	# Change to the saved scene
	var scene_path = save_data.get("current_scene_path", "res://Scenes/Ch1/school_map.tscn")
	if get_tree().change_scene_to_file(scene_path) != OK:
		printerr("SaveManager: Failed to load scene %s, falling back." % scene_path)
		get_tree().change_scene_to_file("res://Scenes/Ch1/school_map.tscn")

	# Restore player position after the scene finishes loading
	var px = save_data.get("player_x", null)
	var py = save_data.get("player_y", null)
	if px != null and py != null:
		_pending_position = Vector2(float(px), float(py))
		get_tree().process_frame.connect(_deferred_set_player_position, CONNECT_ONE_SHOT)

	print("SaveManager: Save loaded.")
	emit_signal("load_completed", true)


var _pending_position: Vector2 = Vector2.ZERO

func _deferred_set_player_position():
	# Wait one more frame so the scene's _ready() has finished
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player = players[0] as Node2D
		if player:
			player.global_position = _pending_position
			print("SaveManager: Player position restored to %s" % _pending_position)


func _write_json(path: String, data: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if FileAccess.get_open_error() != OK:
		printerr("SaveManager: Error writing to %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		return {}
	var json_string = file.get_as_text()
	file.close()
	var result = JSON.parse_string(json_string)
	if result == null or not result is Dictionary:
		return {}
	return result
