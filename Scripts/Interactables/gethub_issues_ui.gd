extends CanvasLayer

signal finished(success: bool, issue_number: int)

@export var tickets: Array[Resource] = []

const IDE_SCENE: PackedScene = preload("res://Scenes/Games/coding_challenge_ui.tscn")
const TUTORIAL_OVERLAY_SCRIPT = preload("res://Scripts/UI/tutorial_overlay.gd")

@onready var ticket_list: VBoxContainer = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueListPane/ListMargin/ListVBox/TicketListScroll/TicketList
@onready var screen: Control = $Screen
@onready var issue_number_label: Label = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/IssueMetaRow/IssueNumberLabel
@onready var status_label: Label = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/IssueMetaRow/StatusLabel
@onready var priority_label: Label = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/IssueMetaRow/PriorityLabel
@onready var issue_title_label: Label = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/IssueTitleLabel
@onready var reporter_label: Label = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/ReporterLabel
@onready var labels_container: HFlowContainer = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/LabelsContainer
@onready var description_label: Label = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/DescriptionLabel
@onready var reproduction_list: VBoxContainer = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/ReproductionList
@onready var criteria_list: VBoxContainer = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/CriteriaList
@onready var attachment_heading_label: Label = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/AttachmentPanel/AttachmentMargin/AttachmentVBox/AttachmentHeadingLabel
@onready var attachment_caption_label: Label = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/DetailsScroll/IssueContent/AttachmentPanel/AttachmentMargin/AttachmentVBox/AttachmentCaptionLabel
@onready var start_work_button: Button = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/ActionRow/StartWorkButton
@onready var submit_button: Button = $Screen/AppWindow/ContentMargin/MainVBox/Workspace/IssueDetailsPane/DetailsMargin/DetailsVBox/ActionRow/SubmitButton
@onready var close_button: Button = $Screen/AppWindow/ContentMargin/MainVBox/TopBar/CloseButton
@onready var issue_count_label: Label = $Screen/AppWindow/ContentMargin/MainVBox/RepoTabs/IssueCountLabel

var _selected_ticket_index: int = -1
var _selected_ticket: Resource
var _statuses: Dictionary = {}
var _ready_issue_numbers: Dictionary = {}
var _ide_active: bool = false
var _ready_to_submit: bool = false
var _ide_instance: Control
var _switching_interface: bool = false


func _ready() -> void:
	start_work_button.pressed.connect(_on_start_work_pressed)
	submit_button.pressed.connect(_on_submit_pressed)
	close_button.pressed.connect(_on_close_pressed)
	issue_count_label.text = "%d OPEN" % tickets.size()
	for ticket_index in tickets.size():
		var ticket: Resource = tickets[ticket_index]
		if ticket:
			_statuses[int(ticket.get("issue_number"))] = str(ticket.get("initial_status"))
	_populate_ticket_list()
	if not tickets.is_empty():
		_select_ticket(0)
	else:
		_show_empty_state()
	if not get_tree().root.has_meta("gethub_context_tutorial_shown") and not tickets.is_empty():
		get_tree().root.set_meta("gethub_context_tutorial_shown", true)
		await _show_context_tutorial()


func _show_context_tutorial() -> void:
	var tutorial = CanvasLayer.new()
	tutorial.name = "GetHubContextTutorial"
	tutorial.set_script(TUTORIAL_OVERLAY_SCRIPT)
	tutorial.layer = 150
	tutorial.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tutorial)
	await get_tree().process_frame
	tutorial.start_tutorial([
		{
			"text": "Every task starts with a tracked issue. Check its number, title, reporter, and priority before editing.",
			"highlight_node": issue_title_label,
			"tooltip_side": "bottom"
		},
		{
			"text": "Labels quickly identify the kind of work and the team involved.",
			"highlight_node": labels_container,
			"tooltip_side": "bottom"
		},
		{
			"text": "Read the description, reproduction steps, and evidence first. Reproduce the problem before changing code.",
			"highlight_node": description_label,
			"tooltip_side": "left"
		},
		{
			"text": "When you understand the issue, open the matching project in the IDE. You can switch between GetHub and the IDE while you work.",
			"highlight_node": start_work_button,
			"tooltip_side": "top"
		}
	])
	await tutorial.tutorial_finished
	if is_instance_valid(tutorial):
		tutorial.queue_free()


func _populate_ticket_list() -> void:
	for child in ticket_list.get_children():
		child.queue_free()
	for index in tickets.size():
		var ticket: Resource = tickets[index]
		if ticket == null:
			continue
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 66)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var issue_number: int = int(ticket.get("issue_number"))
		var initial_status: String = str(ticket.get("initial_status"))
		row.text = "●  #%d  %s\n     %s" % [issue_number, str(_statuses.get(issue_number, initial_status)).to_upper(), str(ticket.get("title"))]
		row.add_theme_font_size_override("font_size", 12)
		row.add_theme_color_override("font_color", Color("#c9d1d9"))
		row.pressed.connect(_select_ticket.bind(index))
		_style_list_button(row, index == _selected_ticket_index)
		ticket_list.add_child(row)


func _select_ticket(index: int) -> void:
	if index < 0 or index >= tickets.size() or _ide_active:
		return
	_selected_ticket_index = index
	_selected_ticket = tickets[index]
	_ready_to_submit = bool(_ready_issue_numbers.get(int(_selected_ticket.get("issue_number")), false))
	_populate_ticket_list()
	_refresh_ticket_details()


func _show_ticket_101_ready_context_tutorial() -> void:
	var tutorial := CanvasLayer.new()
	tutorial.name = "Ticket101ReadyForQAContext"
	tutorial.set_script(TUTORIAL_OVERLAY_SCRIPT)
	tutorial.layer = 150
	tutorial.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tutorial)
	await get_tree().process_frame
	tutorial.start_tutorial([
		{
			"text": "Ready for QA means your coding checks passed and the ticket is prepared for review. It is not closed yet.",
			"highlight_node": status_label,
			"tooltip_side": "bottom"
		},
		{
			"text": "Select Submit to QA / Close Ticket to send your finished work for review and complete this introductory ticket.",
			"highlight_node": submit_button,
			"tooltip_side": "top"
		}
	])
	await tutorial.tutorial_finished
	if is_instance_valid(tutorial):
		tutorial.queue_free()


func _refresh_ticket_details() -> void:
	if _selected_ticket == null:
		_show_empty_state()
		return
	var ticket: Resource = _selected_ticket
	var issue_number: int = int(ticket.get("issue_number"))
	var initial_status: String = str(ticket.get("initial_status"))
	var status := str(_statuses.get(issue_number, initial_status))
	issue_number_label.text = "#%d  ·  %s" % [issue_number, status.to_upper()]
	status_label.text = status.to_upper()
	status_label.add_theme_color_override("font_color", _status_color(status))
	var priority := str(ticket.get("priority"))
	priority_label.text = "▲  %s PRIORITY" % priority.to_upper()
	priority_label.add_theme_color_override("font_color", _priority_color(priority))
	issue_title_label.text = str(ticket.get("title"))
	reporter_label.text = "◉  %s  ·  %s  ·  opened this sprint" % [str(ticket.get("reporter_name")), str(ticket.get("reporter_role"))]
	description_label.text = str(ticket.get("description"))
	attachment_heading_label.text = str(ticket.get("attachment_heading"))
	attachment_caption_label.text = str(ticket.get("attachment_caption"))
	var ticket_labels: PackedStringArray = ticket.get("labels")
	var repro_steps: PackedStringArray = ticket.get("reproduction_steps")
	var acceptance_criteria: PackedStringArray = ticket.get("acceptance_criteria")
	_fill_labels(ticket_labels)
	_fill_numbered_list(reproduction_list, repro_steps, "↳")
	_fill_numbered_list(criteria_list, acceptance_criteria, "✓")
	var is_closed := status == "Closed"
	start_work_button.visible = not is_closed and not _ready_to_submit
	start_work_button.text = "↔  Alt-Tab back to IDE" if _ide_active else "▶  Start Work in IDE"
	submit_button.visible = not is_closed and _ready_to_submit
	close_button.visible = not _ready_to_submit
	start_work_button.disabled = false
	issue_count_label.text = "%d OPEN" % _count_open_tickets()


func _fill_labels(values: PackedStringArray) -> void:
	for child in labels_container.get_children():
		child.queue_free()
	for value in values:
		var pill := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#3a2528") if value == "bug" else Color("#202b3a")
		style.border_color = Color("#6e363b") if value == "bug" else Color("#34445a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(9)
		pill.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = "  %s  " % value
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color("#ff9b93") if value == "bug" else Color("#a5c8ff"))
		pill.add_child(label)
		labels_container.add_child(pill)


func _fill_numbered_list(container: VBoxContainer, values: PackedStringArray, marker: String) -> void:
	for child in container.get_children():
		child.queue_free()
	for index in values.size():
		var entry := Label.new()
		entry.text = "%s  %s" % [marker if marker == "✓" else "%02d" % (index + 1), values[index]]
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_theme_font_size_override("font_size", 12)
		entry.add_theme_color_override("font_color", Color("#c9d1d9") if marker != "✓" else Color("#9da7b3"))
		container.add_child(entry)


func _on_start_work_pressed() -> void:
	if _switching_interface:
		return
	if _ide_active:
		if is_instance_valid(_ide_instance):
			_animate_interface_switch(true)
		return
	if _selected_ticket == null or _ready_to_submit or str(_statuses.get(int(_selected_ticket.get("issue_number")), str(_selected_ticket.get("initial_status")))) == "Closed":
		return
	_ide_active = true
	var issue_number: int = int(_selected_ticket.get("issue_number"))
	_statuses[issue_number] = "In Progress"
	_refresh_ticket_details()
	var ide := IDE_SCENE.instantiate() as Control
	_ide_instance = ide
	ide.hide_close_button = false
	ide.enable_gethub_alt_tab(true)
	ide.challenge_completed.connect(_on_ide_challenge_completed)
	ide.alt_tab_to_gethub.connect(_on_ide_alt_tab_to_gethub)
	add_child(ide)
	screen.hide()
	ide.load_challenge(_selected_ticket.call("build_challenge"))


func _on_ide_alt_tab_to_gethub() -> void:
	if _switching_interface or not is_instance_valid(_ide_instance):
		return
	_animate_interface_switch(false)


func _animate_interface_switch(show_ide: bool) -> void:
	if not is_instance_valid(_ide_instance):
		return
	_switching_interface = true
	var view_width := get_viewport().get_visible_rect().size.x
	if show_ide:
		screen.position.x = 0.0
		_ide_instance.position.x = -view_width
		_ide_instance.show()
	else:
		screen.position.x = -view_width
		screen.show()
		_ide_instance.position.x = 0.0
		_refresh_ticket_details()

	var tween := create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	if show_ide:
		tween.tween_property(screen, "position:x", view_width, 0.32)
		tween.tween_property(_ide_instance, "position:x", 0.0, 0.32)
	else:
		tween.tween_property(_ide_instance, "position:x", view_width, 0.32)
		tween.tween_property(screen, "position:x", 0.0, 0.32)
	tween.chain().tween_callback(func():
		if show_ide:
			screen.hide()
			screen.position.x = 0.0
		else:
			_ide_instance.hide()
			_ide_instance.position.x = 0.0
		_switching_interface = false
	)


func _on_ide_challenge_completed(success: bool, _challenge_id: String) -> void:
	_ide_active = false
	if is_instance_valid(_ide_instance):
		_ide_instance.hide()
	_ide_instance = null
	screen.show()
	_ready_to_submit = success
	var completed_issue_number := int(_selected_ticket.get("issue_number")) if _selected_ticket else -1
	if completed_issue_number >= 0:
		_ready_issue_numbers[completed_issue_number] = success
	if success:
		_statuses[completed_issue_number] = "Ready for QA"
	else:
		_statuses[completed_issue_number] = "Open"
	_refresh_ticket_details()
	if success and completed_issue_number == 101:
		await _show_ticket_101_ready_context_tutorial()


func _on_submit_pressed() -> void:
	if _selected_ticket == null or not _ready_to_submit:
		return
	var issue_number: int = int(_selected_ticket.get("issue_number"))
	_statuses[issue_number] = "Closed"
	_ready_issue_numbers.erase(issue_number)
	_ready_to_submit = false
	close_button.visible = true
	_populate_ticket_list()
	var next_open_index := _find_next_open_ticket()
	if next_open_index >= 0:
		_select_ticket(next_open_index)
		return
	_refresh_ticket_details()
	finished.emit(true, issue_number)
	queue_free()


func _find_next_open_ticket() -> int:
	for index in tickets.size():
		var ticket: Resource = tickets[index]
		if ticket == null:
			continue
		var issue_number: int = int(ticket.get("issue_number"))
		var initial_status: String = str(ticket.get("initial_status"))
		if str(_statuses.get(issue_number, initial_status)) != "Closed":
			return index
	return -1


func _on_close_pressed() -> void:
	if _switching_interface:
		return
	if _ide_active and is_instance_valid(_ide_instance):
		if _ide_instance.visible:
			return
		_ide_instance.queue_free()
		_ide_instance = null
		_ide_active = false
	finished.emit(false, int(_selected_ticket.get("issue_number")) if _selected_ticket else -1)
	queue_free()


func _show_empty_state() -> void:
	issue_number_label.text = "No issue selected"
	status_label.text = ""
	priority_label.text = ""
	issue_title_label.text = "No tickets configured"
	description_label.text = "Add GetHubTicket resources to the Tickets list in the Inspector."
	start_work_button.disabled = true
	submit_button.visible = false


func _count_open_tickets() -> int:
	var count := 0
	for ticket in tickets:
		if ticket and str(_statuses.get(int(ticket.get("issue_number")), str(ticket.get("initial_status")))) != "Closed":
			count += 1
	return count


func _style_list_button(button: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#1f6feb", 0.19) if selected else Color("#161b22", 0.0)
	normal.border_color = Color("#1f6feb", 0.8) if selected else Color("#30363d", 0.0)
	normal.set_border_width_all(1 if selected else 0)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#30363d")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)


func _status_color(status: String) -> Color:
	match status:
		"Closed":
			return Color("#a371f7")
		"In Progress", "Ready for QA":
			return Color("#d29922")
		_:
			return Color("#3fb950")


func _priority_color(priority: String) -> Color:
	return Color("#ff7b72") if priority in ["High", "Critical"] else Color("#d29922")
