# Scripts/Autoload or Global/api_manager.gd
# Singleton autoload that handles all HTTP communication with the Django backend.
extends Node

# ─── Configuration ───────────────────────────────────────────────────────────
const BASE_URL: String = "http://127.0.0.1:8000"
const AUTH_FILE: String = "user://auth.cfg"

# ─── Signals ─────────────────────────────────────────────────────────────────
signal login_completed(success: bool, message: String)
signal enroll_completed(success: bool, message: String, classroom_name: String)
signal unenroll_completed(success: bool, message: String)
signal save_uploaded(success: bool, message: String)
signal save_downloaded(success: bool, data: Dictionary)
signal save_deleted(success: bool, message: String)

# ─── State ───────────────────────────────────────────────────────────────────
var _access_token: String = ""
var _refresh_token: String = ""
var _username: String = ""

# ─── Public API ──────────────────────────────────────────────────────────────

func is_logged_in() -> bool:
	return _access_token != ""

func get_username() -> String:
	return _username

func logout():
	_access_token = ""
	_refresh_token = ""
	_username = ""
	_delete_auth_file()

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready():
	_load_saved_token()

# ─── Login ───────────────────────────────────────────────────────────────────

func login(email: String, password: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_login_response.bind(http))

	var body = JSON.stringify({"email": email, "password": password})
	var headers = ["Content-Type: application/json"]
	var error = http.request(BASE_URL + "/api/game/login/", headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		emit_signal("login_completed", false, "Network error. Please check your connection.")
		http.queue_free()

func _on_login_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("login_completed", false, "Could not reach server. Is it running?")
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		emit_signal("login_completed", false, "Invalid server response.")
		return

	if response_code == 200:
		_access_token = json.get("access", "")
		_refresh_token = json.get("refresh", "")
		_username = json.get("username", "")
		_save_token()
		emit_signal("login_completed", true, "Welcome, %s!" % _username)
	else:
		var detail = json.get("detail", "Login failed.")
		emit_signal("login_completed", false, detail)

# ─── Enroll ──────────────────────────────────────────────────────────────────

func enroll(enrollment_code: String):
	if not is_logged_in():
		emit_signal("enroll_completed", false, "You must be logged in to enroll.", "")
		return

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_enroll_response.bind(http))

	var body = JSON.stringify({"enrollment_code": enrollment_code})
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _access_token,
	]
	var error = http.request(BASE_URL + "/api/game/enroll/", headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		emit_signal("enroll_completed", false, "Network error.", "")
		http.queue_free()

func _on_enroll_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("enroll_completed", false, "Could not reach server.", "")
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		emit_signal("enroll_completed", false, "Invalid server response.", "")
		return

	if response_code == 200:
		var classroom_name = json.get("classroom_name", "")
		var teacher = json.get("teacher", "")
		emit_signal("enroll_completed", true, "Enrolled in %s (Teacher: %s)" % [classroom_name, teacher], classroom_name)
	else:
		var detail = json.get("detail", "Enrollment failed.")
		emit_signal("enroll_completed", false, detail, "")

# ─── Unenroll ────────────────────────────────────────────────────────────────

func unenroll_from_class():
	if not is_logged_in():
		emit_signal("unenroll_completed", false, "You must be logged in to unenroll.")
		return

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_unenroll_response.bind(http))

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _access_token,
	]
	var error = http.request(BASE_URL + "/api/game/unenroll/", headers, HTTPClient.METHOD_POST, "")

	if error != OK:
		emit_signal("unenroll_completed", false, "Network error.")
		http.queue_free()

func _on_unenroll_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("unenroll_completed", false, "Could not reach server.")
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		emit_signal("unenroll_completed", false, "Invalid server response.")
		return

	if response_code == 200:
		emit_signal("unenroll_completed", true, json.get("detail", "Successfully unenrolled."))
	else:
		var detail = json.get("detail", "Unenrollment failed.")
		emit_signal("unenroll_completed", false, detail)

# ─── Token Persistence ──────────────────────────────────────────────────────

func _save_token():
	var config = ConfigFile.new()
	config.set_value("auth", "access_token", _access_token)
	config.set_value("auth", "refresh_token", _refresh_token)
	config.set_value("auth", "username", _username)
	config.save(AUTH_FILE)

func _load_saved_token():
	var config = ConfigFile.new()
	if config.load(AUTH_FILE) == OK:
		_access_token = config.get_value("auth", "access_token", "")
		_refresh_token = config.get_value("auth", "refresh_token", "")
		_username = config.get_value("auth", "username", "")
		if _access_token != "":
			print("ApiManager: Restored session for '%s'" % _username)

func _delete_auth_file():
	if FileAccess.file_exists(AUTH_FILE):
		var dir = DirAccess.open("user://")
		dir.remove("auth.cfg")

# ─── Cloud Save ──────────────────────────────────────────────────────────────

func upload_save(save_data: Dictionary):
	if not is_logged_in():
		emit_signal("save_uploaded", false, "Not logged in.")
		return

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_upload_save_response.bind(http))

	var body = JSON.stringify({"save_data": save_data})
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _access_token,
	]
	var error = http.request(BASE_URL + "/api/game/save/", headers, HTTPClient.METHOD_PUT, body)

	if error != OK:
		emit_signal("save_uploaded", false, "Network error.")
		http.queue_free()

func _on_upload_save_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("save_uploaded", false, "Could not reach server.")
		return

	if response_code == 200:
		print("ApiManager: Save uploaded successfully.")
		emit_signal("save_uploaded", true, "Save synced to cloud.")
	else:
		var json = JSON.parse_string(body.get_string_from_utf8())
		var detail = json.get("detail", "Upload failed.") if json else "Upload failed."
		emit_signal("save_uploaded", false, detail)


func download_save():
	if not is_logged_in():
		emit_signal("save_downloaded", false, {})
		return

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_download_save_response.bind(http))

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _access_token,
	]
	var error = http.request(BASE_URL + "/api/game/save/", headers, HTTPClient.METHOD_GET)

	if error != OK:
		emit_signal("save_downloaded", false, {})
		http.queue_free()

func _on_download_save_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("save_downloaded", false, {})
		return

	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json:
			print("ApiManager: Save downloaded successfully.")
			emit_signal("save_downloaded", true, json)
		else:
			emit_signal("save_downloaded", false, {})
	else:
		# 404 = no save exists, which is a valid "success with no data" case
		emit_signal("save_downloaded", false, {})


func delete_cloud_save():
	if not is_logged_in():
		emit_signal("save_deleted", false, "Not logged in.")
		return

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_delete_save_response.bind(http))

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _access_token,
	]
	var error = http.request(BASE_URL + "/api/game/save/", headers, HTTPClient.METHOD_DELETE)

	if error != OK:
		emit_signal("save_deleted", false, "Network error.")
		http.queue_free()

func _on_delete_save_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("save_deleted", false, "Could not reach server.")
		return

	if response_code == 200:
		print("ApiManager: Cloud save deleted.")
		emit_signal("save_deleted", true, "Cloud save deleted.")
	else:
		var json = JSON.parse_string(body.get_string_from_utf8())
		var detail = json.get("detail", "Delete failed.") if json else "Delete failed."
		emit_signal("save_deleted", false, detail)
