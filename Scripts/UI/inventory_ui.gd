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

	return slot

func _set_player_can_move(value: bool):
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = value
