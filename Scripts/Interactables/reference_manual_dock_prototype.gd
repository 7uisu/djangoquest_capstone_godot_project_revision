extends PanelContainer
class_name ReferenceManualDockPrototype

signal rule_clicked(rule_id: String)

@export var manual_title: String = "DJQ Corp Engineering Reference"
@export var manual_subtitle: String = "Internal Development Guidelines & Incident Runbooks"
@export var rule_entries: Array[Dictionary] = [
	{
		"id": "SEC-01",
		"title": "Private Resource Ownership (IDOR Prevention)",
		"badge": "SECURITY",
		"description": "Never retrieve private student or exam records using only a URL student_id. The query must always filter against request.user.",
		"bad_code": "Student.objects.filter(student_id=student_id).first()",
		"good_code": "Student.objects.filter(student_id=student_id, user=request.user).first()"
	},
	{
		"id": "RUN-02",
		"title": "Production Release Runbook: Schema Check",
		"badge": "DEVOPS",
		"description": "If logs show relation does not exist or column missing, inspect pending migrations before restarting services.",
		"bad_code": "systemctl restart gunicorn  # Fails if DB schema is desynced",
		"good_code": "python manage.py showmigrations\npython manage.py migrate"
	}
]
@export var is_collapsible: bool = true
@export var start_opened: bool = true
@export_multiline var footer_tip: String = "Compare this standard against the open change before submitting."
@export_range(280.0, 560.0, 1.0) var expanded_width: float = 380.0
@export_range(60.0, 100.0, 1.0) var collapsed_width: float = 72.0
@export_range(0.0, 1.0, 0.05) var animation_duration: float = 0.22

@onready var manual_title_label: Label = $ManualMargin/ManualVBox/Header/ManualTitle
@onready var subtitle_label: Label = $ManualMargin/ManualVBox/Subtitle
@onready var toggle_button: Button = $ManualMargin/ManualVBox/Header/ToggleButton
@onready var category_tabs: OptionButton = $ManualMargin/ManualVBox/CategoryRow/CategoryTabs
@onready var rules_scroll: ScrollContainer = $ManualMargin/ManualVBox/RulesScroll
@onready var rules_container: VBoxContainer = $ManualMargin/ManualVBox/RulesScroll/RulesContainer
@onready var footer_label: Label = $ManualMargin/ManualVBox/FooterPanel/FooterMargin/FooterLabel
@onready var category_row: HBoxContainer = $ManualMargin/ManualVBox/CategoryRow

var _is_open: bool = true
var _filter_badge: String = ""
var _active_tween: Tween


func _ready() -> void:
	manual_title_label.text = manual_title
	subtitle_label.text = manual_subtitle
	footer_label.text = footer_tip
	toggle_button.pressed.connect(toggle_manual)
	toggle_button.visible = is_collapsible
	category_tabs.item_selected.connect(_on_category_selected)
	_build_categories()
	_build_rule_cards()
	_is_open = start_opened
	_apply_open_state(false)


func load_ruleset(title: String, rules: Array[Dictionary]) -> void:
	manual_title = title
	rule_entries = rules
	if is_node_ready():
		manual_title_label.text = manual_title
		_build_categories()
		_build_rule_cards()


func toggle_manual() -> void:
	if not is_collapsible:
		return
	_set_open(not _is_open, true)


func open_manual() -> void:
	show()
	_set_open(true, true)


func close_manual() -> void:
	if is_collapsible:
		_set_open(false, true)
	else:
		hide()


func _set_open(opened: bool, animate: bool) -> void:
	_is_open = opened
	_apply_open_state(animate)


func _apply_open_state(animate: bool) -> void:
	var target_width := expanded_width if _is_open else collapsed_width
	var body_visible := _is_open
	manual_title_label.visible = body_visible
	subtitle_label.visible = body_visible
	category_row.visible = body_visible
	rules_scroll.visible = body_visible
	$ManualMargin/ManualVBox/FooterPanel.visible = body_visible
	toggle_button.text = "◀" if _is_open else "▶"
	toggle_button.tooltip_text = "Collapse manual" if _is_open else "Open manual"
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
	if animate:
		_active_tween = create_tween()
		_active_tween.set_trans(Tween.TRANS_CUBIC)
		_active_tween.set_ease(Tween.EASE_IN_OUT)
		_active_tween.tween_property(self, "custom_minimum_size", Vector2(target_width, custom_minimum_size.y), animation_duration)
	else:
		custom_minimum_size.x = target_width


func _build_categories() -> void:
	category_tabs.clear()
	category_tabs.add_item("All guidelines")
	var seen: Dictionary = {}
	for rule in rule_entries:
		var badge := str(rule.get("badge", "GENERAL"))
		if not seen.has(badge):
			seen[badge] = true
			category_tabs.add_item(badge)
	category_tabs.select(0)
	_filter_badge = ""


func _on_category_selected(index: int) -> void:
	_filter_badge = "" if index == 0 else category_tabs.get_item_text(index)
	for card_data in rules_container.get_children():
		var badge := str(card_data.get_meta("badge", "GENERAL"))
		card_data.visible = _filter_badge.is_empty() or badge == _filter_badge


func _build_rule_cards() -> void:
	for child in rules_container.get_children():
		child.queue_free()
	for rule in rule_entries:
		var rule_id := str(rule.get("id", "RULE"))
		var title := str(rule.get("title", "Engineering guideline"))
		var badge := str(rule.get("badge", "GENERAL"))
		var card := PanelContainer.new()
		card.set_meta("badge", badge)
		card.add_theme_stylebox_override("panel", _card_style("#161b22", "#30363d"))
		rules_container.add_child(card)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 12)
		card_margin.add_theme_constant_override("margin_right", 12)
		card_margin.add_theme_constant_override("margin_top", 10)
		card_margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(card_margin)
		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 8)
		card_margin.add_child(card_box)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		card_box.add_child(header)
		var title_button := Button.new()
		title_button.text = rule_id
		title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_button.add_theme_color_override("font_color", Color("#f0c674"))
		title_button.pressed.connect(_emit_rule_clicked.bind(rule_id))
		header.add_child(title_button)
		var badge_label := Label.new()
		badge_label.text = "[ " + badge + " ]"
		badge_label.add_theme_color_override("font_color", Color("#e3b341"))
		header.add_child(badge_label)

		var title_label := Label.new()
		title_label.text = title
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.add_theme_color_override("font_color", Color("#f0f6fc"))
		card_box.add_child(title_label)

		var description := Label.new()
		description.text = str(rule.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", Color("#c9d1d9"))
		card_box.add_child(description)

		card_box.add_child(_make_code_panel("❌  Vulnerable example", str(rule.get("bad_code", "")), "#3b2028", "#f85149", "#ff7b72"))
		card_box.add_child(_make_code_panel("✅  Compliant example", str(rule.get("good_code", "")), "#173b2b", "#3fb950", "#7ee787"))

	_apply_filter()


func _make_code_panel(heading: String, code: String, background: String, border: String, heading_color: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(background, border))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.add_theme_color_override("font_color", Color(heading_color))
	heading_label.add_theme_font_size_override("font_size", 12)
	box.add_child(heading_label)
	var code_label := RichTextLabel.new()
	code_label.bbcode_enabled = false
	code_label.fit_content = true
	code_label.scroll_active = false
	code_label.text = code
	code_label.add_theme_color_override("default_color", Color("#e6edf3"))
	code_label.add_theme_font_size_override("normal_font_size", 12)
	var mono_font = load("res://Textures/Fonts/JetBrainsMono/JetBrainsMono-Regular.ttf")
	if mono_font:
		code_label.add_theme_font_override("normal_font", mono_font)
	box.add_child(code_label)
	return panel


func _apply_filter() -> void:
	for card in rules_container.get_children():
		var badge := str(card.get_meta("badge", "GENERAL"))
		card.visible = _filter_badge.is_empty() or badge == _filter_badge


func _emit_rule_clicked(rule_id: String) -> void:
	rule_clicked.emit(rule_id)


func _card_style(background: String, border: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style