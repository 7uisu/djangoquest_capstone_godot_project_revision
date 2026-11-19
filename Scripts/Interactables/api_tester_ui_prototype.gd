extends CanvasLayer

@export var reference_manual_rules: Array[Dictionary] = [{"id": "SEC-04", "title": "A valid token does not grant access to every record", "badge": "SECURITY", "description": "The endpoint must verify that the authenticated user is allowed to access the student ID in the URL.", "bad_code": "Student.objects.get(id=student_id)", "good_code": "Student.objects.get(id=student_id, user=request.user)"}]

signal solution_verified(success: bool, status_code: int, response_body: String)
signal closed

@export var target_endpoint: String = "/api/v1/students/{id}/progress/"
@export var expected_method: String = "GET"
@export var requires_auth_token: bool = true
@export var mock_responses: Dictionary = {
	"auth_valid": {"status": 403, "status_label": "403 Forbidden", "body": "{\"detail\":\"You do not have permission to access this student's progress.\"}"},
	"auth_missing": {"status": 401, "status_label": "401 Unauthorized", "body": "{\"detail\":\"Authentication credentials were not provided.\"}"},
	"endpoint_mismatch": {"status": 404, "status_label": "404 Not Found", "body": "{\"detail\":\"Not found.\"}"},
	"method_mismatch": {"status": 405, "status_label": "405 Method Not Allowed", "body": "{\"detail\":\"Method not allowed.\"}"}
}
@export_multiline var mission_brief: String = "Security audit: request another student's progress with your own valid token. Confirm that the API blocks access."
@export var successful_status_codes: PackedInt32Array = [401, 403]
@export_range(0.0, 5.0, 0.1) var latency_seconds: float = 0.3

@onready var method_select: OptionButton = $Screen/CenterContainer/Window/WindowMargin/MainVBox/RequestPanel/RequestBox/RequestRow/MethodSelect
@onready var endpoint_input: LineEdit = $Screen/CenterContainer/Window/WindowMargin/MainVBox/RequestPanel/RequestBox/RequestRow/EndpointInput
@onready var auth_toggle: CheckBox = $Screen/CenterContainer/Window/WindowMargin/MainVBox/RequestPanel/RequestBox/AuthToggle
@onready var token_input: LineEdit = $Screen/CenterContainer/Window/WindowMargin/MainVBox/RequestPanel/RequestBox/TokenInput
@onready var send_button: Button = $Screen/CenterContainer/Window/WindowMargin/MainVBox/RequestPanel/RequestBox/RequestRow/SendButton
@onready var loading_indicator: ProgressBar = $Screen/CenterContainer/Window/WindowMargin/MainVBox/RequestPanel/RequestBox/RequestRow/LoadingIndicator
@onready var status_badge: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ResponseHeader/StatusBadge
@onready var response_text: RichTextLabel = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ResponseText
@onready var result_label: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ResultLabel
var request_count := 0


func _ready() -> void:
	var manual: ReferenceManualDockPrototype = $Screen/ManualDockHost/ReferenceManualDockPrototype
	manual.load_ruleset(manual.manual_title, reference_manual_rules)
	$Screen/CenterContainer/Window/WindowMargin/MainVBox/Header/ReferenceButton.pressed.connect(manual.toggle_manual)
	$Screen/CenterContainer/Window/WindowMargin/MainVBox/MissionBrief.text = mission_brief
	method_select.clear()
	for method in ["GET", "POST", "PATCH", "DELETE"]:
		method_select.add_item(method)
		if method == expected_method:
			method_select.select(method_select.item_count - 1)
	endpoint_input.text = target_endpoint
	auth_toggle.button_pressed = true
	token_input.text = ""
	send_button.pressed.connect(_send_request)
	$Screen/CenterContainer/Window/WindowMargin/MainVBox/Header/CloseButton.pressed.connect(_on_close_pressed)


func _send_request() -> void:
	if send_button.disabled:
		return
	send_button.disabled = true
	send_button.text = "Sending..."
	loading_indicator.show()
	status_badge.text = "Waiting for response..."
	status_badge.add_theme_color_override("font_color", Color("#d29922"))
	await get_tree().create_timer(latency_seconds).timeout

	loading_indicator.hide()
	request_count += 1
	var condition := _request_condition()
	var response: Dictionary = mock_responses.get(condition, {})
	var status := int(response.get("status", 0))
	var body := str(response.get("body", "{\"detail\":\"No mock response is configured for this request.\"}"))
	status_badge.text = str(response.get("status_label", "Response"))
	status_badge.add_theme_color_override("font_color", Color("#7ee787") if successful_status_codes.has(status) else Color("#ff7b72"))
	response_text.text = _pretty_json(body)
	var success := _is_verified_request(condition, status)
	result_label.text = "Protected endpoint verified: the cross-student request was denied." if success else "Request received. Adjust the endpoint, method, or authentication and try again."
	result_label.add_theme_color_override("font_color", Color("#7ee787") if success else Color("#8b949e"))
	solution_verified.emit(success, status, body)
	send_button.disabled = false
	send_button.text = "Send Request"


func _request_condition() -> String:
	if not _endpoint_matches():
		return "endpoint_mismatch"
	if method_select.get_item_text(method_select.selected) != expected_method:
		return "method_mismatch"
	if requires_auth_token and (not auth_toggle.button_pressed or token_input.text.strip_edges().is_empty()):
		return "auth_missing"
	return "auth_valid"


func _endpoint_matches() -> bool:
	var template_parts := target_endpoint.split("/")
	var request_parts := endpoint_input.text.strip_edges().split("/")
	if template_parts.size() != request_parts.size():
		return false
	for i in range(template_parts.size()):
		if template_parts[i].begins_with("{") and template_parts[i].ends_with("}"):
			if request_parts[i].is_empty():
				return false
		elif template_parts[i] != request_parts[i]:
			return false
	return true


func _is_verified_request(condition: String, status: int) -> bool:
	return condition == "auth_valid" and successful_status_codes.has(status)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _pretty_json(body: String) -> String:
	var parsed = JSON.parse_string(body)
	if parsed == null:
		return body
	return JSON.stringify(parsed, "  ")


func _panel_style(background: String, border: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style



