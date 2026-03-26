# inventory_ui.gd — Inventory overlay panel
# Attach to the CanvasLayer root of inventory_ui.tscn
# Toggle with the "toggle_inventory" input action (I key).
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var empty_label: Label = $Panel/MarginContainer/VBoxContainer/EmptyLabel

var is_open: bool = false

# Preload slot parts — we build them dynamically
const SLOT_SIZE := Vector2(64, 80)

func _ready():
	visible = false
	panel.visible = false
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		inv.inventory_changed.connect(_refresh)

# Note: toggle_inventory input is handled by player.gd which calls open()/close() directly.

func open():
	is_open = true
	visible = true
	panel.visible = true
	_refresh()
	_set_player_can_move(false)

func close():
	is_open = false
	visible = false
	panel.visible = false
	_set_player_can_move(true)

func _refresh():
	# Clear existing slots
	for child in grid.get_children():
		child.queue_free()

	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return

	var items = inv.get_items()

	if items.is_empty():
		empty_label.visible = true
	else:
		empty_label.visible = false

	for item in items:
		var slot = _create_slot(item)
		grid.add_child(slot)

func _create_slot(item: Dictionary) -> PanelContainer:
	# Slot container
	var slot = PanelContainer.new()
	slot.custom_minimum_size = SLOT_SIZE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.22, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.5, 0.8, 0.6)
	slot.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	slot.add_child(vbox)

	# Icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if item.get("icon") is Texture2D:
		icon_rect.texture = item["icon"]
	vbox.add_child(icon_rect)

	# Name
	var name_label = Label.new()
	name_label.text = item.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	vbox.add_child(name_label)

	# Quantity (only show if > 1)
	var qty = item.get("quantity", 1)
	if qty > 1:
		var qty_label = Label.new()
		qty_label.text = "x" + str(qty)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.add_theme_font_size_override("font_size", 9)
		qty_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0, 0.8))
		vbox.add_child(qty_label)

	# Hover tooltip — shows the flavor description
	var item_id = item.get("id", "")
	var desc = item.get("description", "")

	# Check CodingItems for richer descriptions
	if CodingItems.ITEMS.has(item_id):
		var ci = CodingItems.ITEMS[item_id]
		desc = ci.get("description", desc)

	slot.tooltip_text = item.get("name", "???") + "\n" + desc

	# Right-click to show full detail popup with buff info
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_show_item_detail(item)
	)

	return slot

# ─── Item Detail Popup ───────────────────────────────────────────────────────

var _detail_popup: PanelContainer = null

func _show_item_detail(item: Dictionary):
	# Remove old popup
	if _detail_popup and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()

	var item_id = item.get("id", "")
	var item_name = item.get("name", "???")
	var flavor_desc = item.get("description", "")
	var buff_desc = ""

	# Pull rich descriptions from CodingItems
	if CodingItems.ITEMS.has(item_id):
		var ci = CodingItems.ITEMS[item_id]
		flavor_desc = ci.get("description", flavor_desc)
		buff_desc = ci.get("buff_description", "")

	# Build popup
	_detail_popup = PanelContainer.new()
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.08, 0.08, 0.16, 0.95)
	popup_style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(8)
	popup_style.set_content_margin_all(12)
	_detail_popup.add_theme_stylebox_override("panel", popup_style)

	_detail_popup.custom_minimum_size = Vector2(260, 0)
	_detail_popup.layout_mode = 1
	_detail_popup.anchors_preset = Control.PRESET_CENTER
	_detail_popup.anchor_left = 0.5
	_detail_popup.anchor_top = 0.5
	_detail_popup.anchor_right = 0.5
	_detail_popup.anchor_bottom = 0.5
	_detail_popup.offset_left = -130
	_detail_popup.offset_top = -80
	_detail_popup.offset_right = 130
	_detail_popup.offset_bottom = 80
	_detail_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_detail_popup.grow_vertical = Control.GROW_DIRECTION_BOTH

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_detail_popup.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = item_name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Flavor description
	var desc_label = Label.new()
	desc_label.text = flavor_desc
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Buff description
	if buff_desc != "":
		var sep2 = HSeparator.new()
		vbox.add_child(sep2)

		var buff_label = Label.new()
		buff_label.text = buff_desc
		buff_label.add_theme_font_size_override("font_size", 11)
		buff_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.6))
		buff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(buff_label)

	# Consumable warning
	if CodingItems.ITEMS.has(item_id):
		var ci = CodingItems.ITEMS[item_id]
		if ci.get("consumable", false):
			var warn = Label.new()
			warn.text = "⚠ Consumed on use"
			warn.add_theme_font_size_override("font_size", 10)
			warn.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
			warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(warn)

	# Close instruction
	var close_hint = Label.new()
	close_hint.text = "[ Click anywhere to close ]"
	close_hint.add_theme_font_size_override("font_size", 9)
	close_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(close_hint)

	# Add to the CanvasLayer
	add_child(_detail_popup)

	# Close on any click
	_detail_popup.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_detail_popup.queue_free()
			_detail_popup = null
	)
	_detail_popup.mouse_filter = Control.MOUSE_FILTER_STOP

func _set_player_can_move(value: bool):
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = value
