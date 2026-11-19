extends CanvasLayer
@export var reference_manual_rules: Array[Dictionary] = [{"id": "ARCH-01", "title": "Route before handling view logic", "badge": "ARCHITECTURE", "description": "Django resolves a URL pattern before running the matching view. The view then uses models to work with data.", "bad_code": "views.py handles the request before urls.py routes it", "good_code": "urls.py routes to views.py, which uses models.py"}]

signal sequence_completed(success: bool)

@export var sequence_title: String = "Django Request-Response Lifecycle"
@export_multiline var reference_rulebook_text: String = "REFERENCE GUIDE\n\n1. urls.py receives the incoming path and selects a route.\n2. middleware applies shared request and response checks.\n3. views.py runs the endpoint logic and coordinates data work.\n4. models.py reads or writes the database.\n5. The response returns to the client.\n\nHelping hand: select a card, then use Move Up / Move Down to organize the pipeline."
@export var stage_items_pool: Array[Dictionary] = [
	{"id": "urls", "label": "urls.py · Route request", "description": "Matches the requested path to the right endpoint."},
	{"id": "middleware", "label": "middleware · Shared checks", "description": "Applies request and response checks across the app."},
	{"id": "views", "label": "views.py · Handle logic", "description": "Runs endpoint logic and coordinates data operations."},
	{"id": "models", "label": "models.py · Work with data", "description": "Reads or changes records in the database."},
	{"id": "response", "label": "Response · Return result", "description": "Sends the result back to the client."}
]
@export var correct_stage_order: PackedStringArray = ["urls", "middleware", "views", "models", "response"]
@export_multiline var success_message: String = "Pipeline verified! The request follows the Django lifecycle in the correct order."
@export_multiline var general_hint: String = "Use the reference guide to trace the request from its incoming URL to the response."
@export var stage_feedback: Dictionary = {
	"middleware": "Shared request checks happen after Django has selected a route.",
	"views": "The view handles endpoint logic after routing and shared request checks.",
	"models": "Data access belongs after the request reaches the view logic.",
	"response": "The response is returned after the application has completed its work."
}

@onready var title_label: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/Header/TitleLabel
@onready var reference_label: RichTextLabel = $Screen/CenterContainer/Window/WindowMargin/MainVBox/Content/ReferencePanel/ReferenceMargin/ReferenceLabel
@onready var card_list: VBoxContainer = $Screen/CenterContainer/Window/WindowMargin/MainVBox/Content/Workspace/CardList
@onready var slot_list: VBoxContainer = $Screen/CenterContainer/Window/WindowMargin/MainVBox/Content/Workspace/SlotList
@onready var feedback_label: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/FeedbackLabel
@onready var verify_button: Button = $Screen/CenterContainer/Window/WindowMargin/MainVBox/VerifyButton

var arranged_ids: PackedStringArray = []
var slot_buttons: Array[Button] = []
var slot_panels: Array[PanelContainer] = []
var card_buttons: Dictionary = {}


func _ready() -> void:
	var manual: ReferenceManualDockPrototype = $Screen/ManualDockHost/ReferenceManualDockPrototype
	manual.load_ruleset(manual.manual_title, reference_manual_rules)
	$Screen/CenterContainer/Window/WindowMargin/MainVBox/Header/ReferenceButton.pressed.connect(manual.toggle_manual)
	title_label.text = sequence_title
	reference_label.text = reference_rulebook_text
	verify_button.pressed.connect(_verify_sequence)
	for _i in range(correct_stage_order.size()):
		arranged_ids.append("")
	_build_slots()
	_build_cards()


func _build_slots() -> void:
	for index in range(correct_stage_order.size()):
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style("#161b22", "#30363d"))
		slot_list.add_child(panel)
		slot_panels.append(panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)
		var number := Label.new()
		number.custom_minimum_size = Vector2(86, 0)
		number.text = "STAGE %02d" % (index + 1)
		number.add_theme_color_override("font_color", Color("#79c0ff"))
		row.add_child(number)
		var item_button := Button.new()
		item_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_button.text = "Choose a stage card"
		item_button.pressed.connect(_clear_slot.bind(index))
		row.add_child(item_button)
		slot_buttons.append(item_button)

		var up := Button.new()
		up.text = "↑"
		up.tooltip_text = "Move this stage up"
		up.pressed.connect(_move_stage.bind(index, -1))
		row.add_child(up)
		var down := Button.new()
		down.text = "↓"
		down.tooltip_text = "Move this stage down"
		down.pressed.connect(_move_stage.bind(index, 1))
		row.add_child(down)
	_refresh_slots()


func _build_cards() -> void:
	for item in stage_items_pool:
		var stage_id := str(item.get("id", ""))
		var label_text := str(item.get("label", stage_id))
		var description_text := str(item.get("description", ""))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style("#161b22", "#30363d"))
		card_list.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var title := Label.new()
		title.text = label_text
		title.add_theme_color_override("font_color", Color("#f0f6fc"))
		details.add_child(title)
		var description := Label.new()
		description.text = description_text
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", Color("#8b949e"))
		details.add_child(description)
		var assign := Button.new()
		assign.text = "Add to Pipeline"
		assign.pressed.connect(_assign_stage.bind(stage_id))
		row.add_child(assign)
		card_buttons[stage_id] = assign


func _assign_stage(stage_id: String) -> void:
	if arranged_ids.has(stage_id):
		return
	for index in range(arranged_ids.size()):
		if arranged_ids[index].is_empty():
			arranged_ids[index] = stage_id
			break
	_refresh_slots()


func _clear_slot(index: int) -> void:
	if index < 0 or index >= arranged_ids.size():
		return
	arranged_ids[index] = ""
	for later in range(index, arranged_ids.size() - 1):
		if arranged_ids[later].is_empty():
			arranged_ids[later] = arranged_ids[later + 1]
			arranged_ids[later + 1] = ""
	_refresh_slots()


func _move_stage(index: int, direction: int) -> void:
	var destination := index + direction
	if destination < 0 or destination >= arranged_ids.size():
		return
	var moved := arranged_ids[index]
	arranged_ids[index] = arranged_ids[destination]
	arranged_ids[destination] = moved
	_refresh_slots()


func _refresh_slots() -> void:
	for index in range(slot_buttons.size()):
		var stage_id := arranged_ids[index]
		slot_buttons[index].text = _stage_label(stage_id) if not stage_id.is_empty() else "Choose a stage card"
		slot_panels[index].add_theme_stylebox_override("panel", _panel_style("#161b22", "#30363d"))
	for stage_id in card_buttons:
		card_buttons[stage_id].disabled = arranged_ids.has(str(stage_id))


func _verify_sequence() -> void:
	var first_invalid := -1
	for index in range(correct_stage_order.size()):
		if index >= arranged_ids.size() or arranged_ids[index] != correct_stage_order[index]:
			first_invalid = index
			break
	if first_invalid < 0:
		feedback_label.text = success_message
		feedback_label.add_theme_color_override("font_color", Color("#7ee787"))
		for panel in slot_panels:
			panel.add_theme_stylebox_override("panel", _panel_style("#173b2b", "#3fb950"))
		sequence_completed.emit(true)
		return

	slot_panels[first_invalid].add_theme_stylebox_override("panel", _panel_style("#3b2028", "#f85149"))
	var wrong_id := arranged_ids[first_invalid] if first_invalid < arranged_ids.size() else ""
	var hint := str(stage_feedback.get(wrong_id, general_hint))
	feedback_label.text = "Stage %d needs another look. %s" % [first_invalid + 1, hint]
	feedback_label.add_theme_color_override("font_color", Color("#ff7b72"))
	sequence_completed.emit(false)


func _stage_label(stage_id: String) -> String:
	for item in stage_items_pool:
		if str(item.get("id", "")) == stage_id:
			return str(item.get("label", stage_id))
	return stage_id


func _panel_style(background: String, border: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style