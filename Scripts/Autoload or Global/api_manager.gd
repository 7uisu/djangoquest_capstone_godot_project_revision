# Scripts/Autoload or Global/api_manager.gd
# Singleton autoload that handles all HTTP communication with the Django backend.
extends Node

# ─── Configuration ───────────────────────────────────────────────────────────
const BASE_URL: String = "https://djangoquest-backend.onrender.com"
const AUTH_FILE: String = "user://auth.cfg"

# ─── Signals ─────────────────────────────────────────────────────────────────
signal login_completed(success: bool, message: String)
signal enroll_completed(success: bool, message: String, classroom_name: String)
signal unenroll_completed(success: bool, message: String)
signal save_uploaded(success: bool, message: String)
signal save_downloaded(success: bool, data: Dictionary)
signal save_deleted(success: bool, message: String)
signal code_checked(result: Dictionary)  # {success, output, ai_hint, judge0_output}; judge0_output is legacy compatibility

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_saved_token()

# ─── Login ───────────────────────────────────────────────────────────────────

func login(email: String, password: String):
	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
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
	http.process_mode = Node.PROCESS_MODE_ALWAYS
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
	http.process_mode = Node.PROCESS_MODE_ALWAYS
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

var _upload_in_progress: bool = false
var _has_queued_save_upload: bool = false
var _queued_save_data: Dictionary = {}
var _queued_save_allow_refresh: bool = true
var _active_upload_http: HTTPRequest = null
var _active_upload_timer: Timer = null

func upload_save(save_data: Dictionary, allow_refresh: bool = true):
	if not is_logged_in():
		emit_signal("save_uploaded", false, "Not logged in.")
		return

	if _upload_in_progress:
		_has_queued_save_upload = true
		_queued_save_data = save_data.duplicate(true)
		_queued_save_allow_refresh = allow_refresh
		print("ApiManager: Upload already in progress. Queued latest save.")
		return

	_upload_in_progress = true
	var upload_data = save_data.duplicate(true)

	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.timeout = 30.0
	add_child(http)
	_active_upload_http = http

	var timeout_timer = Timer.new()
	timeout_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timeout_timer.one_shot = true
	timeout_timer.wait_time = 35.0
	add_child(timeout_timer)
	_active_upload_timer = timeout_timer

	var body = JSON.stringify({"save_data": upload_data})
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _access_token,
	]
	print("ApiManager: Uploading save. allow_refresh=%s bytes=%s progress=%s modules=%s credits=%s" % [
		str(allow_refresh),
		str(body.length()),
		_get_story_progress_debug(upload_data),
		_get_modules_debug(upload_data),
		str(upload_data.get("credits", 0)),
	])
	http.request_completed.connect(_on_upload_save_response.bind(http, timeout_timer, upload_data, allow_refresh))
	timeout_timer.timeout.connect(_on_upload_save_timeout.bind(http, timeout_timer, upload_data, allow_refresh))
	var error = http.request(BASE_URL + "/api/game/save/", headers, HTTPClient.METHOD_PUT, body)

	if error != OK:
		print("ApiManager: Upload request failed to start. error=%s" % str(error))
		_cleanup_active_upload(http, timeout_timer)
		if _start_queued_save_upload():
			return
		emit_signal("save_uploaded", false, "Network error.")
		return

	timeout_timer.start()

func _on_upload_save_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, timeout_timer: Timer, upload_data: Dictionary, allow_refresh: bool) -> void:
	if http != _active_upload_http:
		return
	_finish_upload_save(result, response_code, body, http, timeout_timer, upload_data, allow_refresh)

func _on_upload_save_timeout(http: HTTPRequest, timeout_timer: Timer, upload_data: Dictionary, allow_refresh: bool) -> void:
	if http != _active_upload_http:
		return
	print("ApiManager: Save upload timed out.")
	if is_instance_valid(http):
		http.cancel_request()
	_finish_upload_save(HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray(), http, timeout_timer, upload_data, allow_refresh)

func _finish_upload_save(result: int, response_code: int, body: PackedByteArray, http: HTTPRequest, timeout_timer: Timer, upload_data: Dictionary, allow_refresh: bool) -> void:
	_cleanup_active_upload(http, timeout_timer)
	var response_text = body.get_string_from_utf8()

	print("ApiManager: Save upload response. result=%s response=%s body=%s" % [
		str(result),
		str(response_code),
		response_text.substr(0, 500),
	])

	if result != HTTPRequest.RESULT_SUCCESS:
		if _start_queued_save_upload():
			return
		emit_signal("save_uploaded", false, "Could not reach server. Upload result: %s" % str(result))
		return

	if response_code == 401 and allow_refresh:
		print("ApiManager: Access token expired during save upload. Refreshing token...")
		_refresh_access_token(func(success: bool):
			if success:
				var retry_data = _take_queued_save_data(upload_data)
				upload_save(retry_data, false)
			else:
				_clear_queued_save_upload()
				emit_signal("save_uploaded", false, "Session expired. Please log in again.")
		)
		return

	if response_code == 200:
		print("ApiManager: Save uploaded successfully.")
		if _start_queued_save_upload():
			return
		emit_signal("save_uploaded", true, "Save synced to cloud.")
	else:
		var json = JSON.parse_string(response_text)
		var detail = json.get("detail", "Upload failed.") if json else "Upload failed."
		if json and json.has("errors") and json["errors"] is Array:
			detail += " " + "; ".join(PackedStringArray(json["errors"]))
		if _start_queued_save_upload():
			return
		emit_signal("save_uploaded", false, detail)

func _cleanup_active_upload(http: HTTPRequest, timeout_timer: Timer) -> void:
	if _active_upload_http == http:
		_active_upload_http = null
	if _active_upload_timer == timeout_timer:
		_active_upload_timer = null
	_upload_in_progress = false
	if is_instance_valid(timeout_timer):
		timeout_timer.stop()
		timeout_timer.queue_free()
	if is_instance_valid(http):
		http.queue_free()

func _start_queued_save_upload() -> bool:
	if not _has_queued_save_upload:
		return false
	var queued_data = _queued_save_data.duplicate(true)
	var queued_allow_refresh = _queued_save_allow_refresh
	_clear_queued_save_upload()
	print("ApiManager: Uploading queued latest save.")
	upload_save(queued_data, queued_allow_refresh)
	return true

func _take_queued_save_data(fallback_data: Dictionary) -> Dictionary:
	if not _has_queued_save_upload:
		return fallback_data.duplicate(true)
	var queued_data = _queued_save_data.duplicate(true)
	_clear_queued_save_upload()
	return queued_data

func _clear_queued_save_upload() -> void:
	_has_queued_save_upload = false
	_queued_save_data = {}
	_queued_save_allow_refresh = true


func _get_story_progress_debug(save_data: Dictionary) -> String:
	var flags = [
		"ch1_teaching_done",
		"ch1_quiz_done",
		"ch1_post_quiz_dialogue_done",
		"ch1_convenience_store_cutscene_done",
		"ch1_spaghetti_guy_cutscene_done",
		"ch2_y1s1_teaching_done",
		"ch2_y1s2_teaching_done",
		"ch2_y2s1_teaching_done",
		"ch2_y2s2_teaching_done",
		"ch2_y3s1_teaching_done",
		"ch2_y3s2_teaching_done",
		"ch2_y3mid_teaching_done",
		"thesis_completed",
	]
	var done = 0
	for flag in flags:
		if save_data.get(flag, false):
			done += 1
	return "%s/%s" % [str(done), str(flags.size())]

func _get_modules_debug(save_data: Dictionary) -> String:
	var prefixes = ["ch2_y1s1", "ch2_y1s2", "ch2_y2s1", "ch2_y2s2", "ch2_y3s1", "ch2_y3s2", "ch2_y3mid"]
	var done_labels := PackedStringArray()
	for prefix in prefixes:
		if save_data.get("%s_teaching_done" % prefix, false):
			done_labels.append("%s grade=%s" % [prefix, str(save_data.get("%s_final_grade" % prefix, 0.0))])
	if done_labels.is_empty():
		return "none"
	return ", ".join(done_labels)


func download_save(allow_refresh: bool = true):
	if not is_logged_in():
		emit_signal("save_downloaded", false, {})
		return

	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)
	http.request_completed.connect(_on_download_save_response.bind(http, allow_refresh))

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _access_token,
	]
	var error = http.request(BASE_URL + "/api/game/save/", headers, HTTPClient.METHOD_GET)

	if error != OK:
		emit_signal("save_downloaded", false, {})
		http.queue_free()

func _on_download_save_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, allow_refresh: bool):
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("save_downloaded", false, {})
		return

	if response_code == 401 and allow_refresh:
		print("ApiManager: Access token expired during save download. Refreshing token...")
		_refresh_access_token(func(success: bool):
			if success:
				download_save(false)
			else:
				emit_signal("save_downloaded", false, {})
		)
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


func _refresh_access_token(done: Callable) -> void:
	if _refresh_token == "":
		done.call(false)
		return

	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)
	http.request_completed.connect(_on_refresh_access_token_response.bind(http, done))

	var body = JSON.stringify({"refresh": _refresh_token})
	var headers = ["Content-Type: application/json"]
	var error = http.request(BASE_URL + "/api/game/token/refresh/", headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		http.queue_free()
		done.call(false)

func _on_refresh_access_token_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, done: Callable) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("ApiManager: Token refresh failed. result=%s response=%s" % [str(result), str(response_code)])
		done.call(false)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		done.call(false)
		return

	_access_token = json.get("access", "")
	if json.has("refresh"):
		_refresh_token = json.get("refresh", _refresh_token)
	_save_token()
	print("ApiManager: Access token refreshed.")
	done.call(_access_token != "")


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

# ─── Code Checking (Controlled Validation + Gemini/Groq) ────────────────────

func check_code(code: Variant, language: String, challenge_id: String, 
				expected_answers: Variant, expected_output: String = "", hint_context: String = "", hint_mode: bool = false):
	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.timeout = 90  # AI-assisted feedback can take a while on a cold backend.
	add_child(http)
	http.request_completed.connect(_on_check_code_response.bind(http))

	var body = JSON.stringify({
		"code": code,
		"language": language,
		"challenge_id": challenge_id,
		"expected_answers": expected_answers,
		"expected_output": expected_output,
		"hint_context": hint_context,
		"hint_mode": hint_mode,
	})
	var headers = ["Content-Type: application/json"]
	
	var url = BASE_URL + "/api/game/check-code/"
	print("[ApiManager] check_code -> POST %s" % url)
	print("[ApiManager] body: %s" % body.substr(0, 100))

	var error = http.request(url, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		print("[ApiManager] ❌ HTTPRequest.request() failed with error: %s" % str(error))
		emit_signal("code_checked", {"offline": true})
		http.queue_free()
	else:
		print("[ApiManager] ✅ Request sent, waiting for response...")

func _on_check_code_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	
	print("[ApiManager] Response received: result=%s, response_code=%s" % [str(result), str(response_code)])

	if result != HTTPRequest.RESULT_SUCCESS:
		print("[ApiManager] ❌ Request failed! result=%s (0=SUCCESS, 1=CHUNKED_BODY_SIZE_MISMATCH, 2=CANT_CONNECT, 3=CANT_RESOLVE, 4=CONNECTION_ERROR, 5=TLS_HANDSHAKE_ERROR, 6=NO_RESPONSE, 7=BODY_SIZE_LIMIT_EXCEEDED, 8=BODY_DECOMPRESS_FAILED, 9=REQUEST_FAILED, 10=DOWNLOAD_FILE_CANT_OPEN, 11=DOWNLOAD_FILE_WRITE_ERROR, 12=REDIRECT_LIMIT_REACHED, 13=TIMEOUT)" % str(result))
		emit_signal("code_checked", {"offline": true})
		return

	var response_text = body.get_string_from_utf8()
	var json = JSON.parse_string(response_text)
	if json == null:
		print("[ApiManager] ❌ Failed to parse JSON response")
		emit_signal("code_checked", {"offline": true})
		return

	if response_code < 200 or response_code >= 300:
		print("[ApiManager] ❌ check_code backend returned HTTP %s: %s" % [str(response_code), response_text.substr(0, 300)])
		emit_signal("code_checked", {
			"offline": true,
			"detail": json.get("detail", json.get("error", "Backend returned HTTP " + str(response_code))),
		})
		return

	print("[ApiManager] ✅ Server response: success=%s" % str(json.get("success", false)))

	emit_signal("code_checked", {
		"offline": false,
		"success": json.get("success", false),
		"output": json.get("output", ""),
		"ai_hint": json.get("ai_hint", ""),
		"ai_hint_source": json.get("ai_hint_source", ""),
		"judge0_output": json.get("judge0_output", ""),
	})


# ─── AI Evaluator Minigame ───────────────────────────────────────────────────

signal ai_evaluated(result_dict)

func check_ai_evaluator(challenge_type: String, student_answer: String, context: String):
	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.timeout = 90
	add_child(http)
	http.request_completed.connect(_on_ai_evaluator_response.bind(http))

	var body = JSON.stringify({
		"challenge_type": challenge_type,
		"student_answer": student_answer,
		"context": context,
	})
	var headers = ["Content-Type: application/json"]
	
	var url = BASE_URL + "/api/game/ai-evaluator/"
	print("[ApiManager] check_ai_evaluator -> POST %s" % url)

	var error = http.request(url, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		print("[ApiManager] ❌ HTTPRequest.request() failed with error: %s" % str(error))
		emit_signal("ai_evaluated", {"offline": true, "success": false, "feedback": "Network error connecting to backend."})
		http.queue_free()

func _on_ai_evaluator_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("ai_evaluated", {"offline": true, "success": false, "feedback": "Failed to reach evaluator endpoint."})
		return

	var response_text = body.get_string_from_utf8()
	var json = JSON.parse_string(response_text)
	if json == null:
		emit_signal("ai_evaluated", {"offline": true, "success": false, "feedback": "Corrupted response geometry from endpoint."})
		return

	if response_code < 200 or response_code >= 300:
		print("[ApiManager] ❌ ai-evaluator backend returned HTTP %s: %s" % [str(response_code), response_text.substr(0, 300)])
		emit_signal("ai_evaluated", {
			"offline": true,
			"success": false,
			"feedback": json.get("feedback", json.get("detail", "AI evaluator returned HTTP " + str(response_code))),
		})
		return

	var feedback = json.get("feedback", "No feedback provided by AI.")
	var success = json.get("success", false)
	var ai_source = json.get("ai_source", "")
	if ai_source != "":
		print("[ApiManager] ai-evaluator source: %s" % ai_source)
	if not success and _is_ai_provider_failure(feedback):
		emit_signal("ai_evaluated", {
			"offline": true,
			"success": false,
			"feedback": feedback,
			"ai_source": ai_source,
		})
		return

	emit_signal("ai_evaluated", {
		"offline": false,
		"success": success,
		"feedback": feedback,
		"ai_source": ai_source,
	})

func _is_ai_provider_failure(feedback: String) -> bool:
	var lower = feedback.to_lower()
	return (
		lower.contains("backend error")
		or lower.contains("ai provided an invalid")
	)
