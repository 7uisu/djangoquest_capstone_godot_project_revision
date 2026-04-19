# shop_ui.gd — In-game shop overlay for buying buff items
# Built entirely in code to match the pattern of laptop_ui.gd and inventory_ui.gd
extends CanvasLayer

signal shop_closed

var is_open: bool = false
var _credit_label: Label = null
var _item_container: VBoxContainer = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95  # Above game, below SceneTransition
	visible = false
	_build_ui()

func open():
	is_open = true
	visible = true
	get_tree().paused = true
	_refresh()

func close():
	is_open = false
	visible = false
	get_tree().paused = false
	_set_player_movement(true)
	shop_closed.emit()

# ─── Build Full UI ───────────────────────────────────────────────────────────

func _build_ui():
	# Full screen dimmer
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.7)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close()
	)
	add_child(dimmer)

	# Main panel
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.98)
	panel_style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", panel_style)

	panel.anchor_left = 0.15
	panel.anchor_top = 0.08
	panel.anchor_right = 0.85
	panel.anchor_bottom = 0.92
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	add_child(panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(main_vbox)

	# ─── Header ──────────────────────────────────────────────────────────
	var header = _create_header()
	main_vbox.add_child(header)

	# ─── Scrollable item list ────────────────────────────────────────────
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	_item_container = VBoxContainer.new()
	_item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_item_container)

	# ─── Footer ──────────────────────────────────────────────────────────
	var footer = _create_footer()
	main_vbox.add_child(footer)

func _create_header() -> PanelContainer:
	var header_panel = PanelContainer.new()
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = Color(0.08, 0.12, 0.22)
	h_style.set_content_margin_all(12)
	h_style.corner_radius_top_left = 12
	h_style.corner_radius_top_right = 12
	h_style.border_color = Color(0.2, 0.3, 0.5)
	h_style.border_width_bottom = 1
	header_panel.add_theme_stylebox_override("panel", h_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	header_panel.add_child(hbox)

	# Shop title
	var title = Label.new()
	title.text = "🏪 IT Staff's Supply Closet"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	# Credit display
	var credit_hbox = HBoxContainer.new()
	credit_hbox.add_theme_constant_override("separation", 6)
	hbox.add_child(credit_hbox)

	# Credit icon
	var credit_icon = TextureRect.new()
	credit_icon.custom_minimum_size = Vector2(20, 20)
	credit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	credit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var icon_tex = load("res://Textures/School Textures/Items/Interactable/CreditCard-32x32.png")
	if icon_tex:
		credit_icon.texture = icon_tex
	credit_hbox.add_child(credit_icon)

	_credit_label = Label.new()
	_credit_label.text = "0"
	_credit_label.add_theme_font_size_override("font_size", 16)
	_credit_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	credit_hbox.add_child(_credit_label)

	return header_panel

func _create_footer() -> PanelContainer:
	var footer_panel = PanelContainer.new()
	var f_style = StyleBoxFlat.new()
	f_style.bg_color = Color(0.08, 0.1, 0.16)
	f_style.set_content_margin_all(8)
	f_style.corner_radius_bottom_left = 12
	f_style.corner_radius_bottom_right = 12
	f_style.border_color = Color(0.2, 0.3, 0.5)
	f_style.border_width_top = 1
	footer_panel.add_theme_stylebox_override("panel", f_style)

	var center = CenterContainer.new()
	footer_panel.add_child(center)

	var close_btn = Button.new()
	close_btn.text = "Close Shop"
	close_btn.custom_minimum_size = Vector2(160, 36)
	close_btn.add_theme_font_size_override("font_size", 13)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.5, 0.2, 0.2, 0.8)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(6)
	close_btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style = btn_style.duplicate()
	hover_style.bg_color = Color(0.7, 0.25, 0.25, 0.9)
	close_btn.add_theme_stylebox_override("hover", hover_style)

	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.pressed.connect(close)
	center.add_child(close_btn)

	return footer_panel

# ─── Refresh / Populate Items ────────────────────────────────────────────────

func _refresh():
	# Update credit display
	var cd = get_node_or_null("/root/CharacterData")
	var current_credits = cd.get_credits() if cd else 0
	if _credit_label:
		_credit_label.text = str(current_credits)

	# Clear old items
	for child in _item_container.get_children():
		child.queue_free()

	# Add margin at top
	var spacer_top = Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 4)
	_item_container.add_child(spacer_top)

	# Build item cards
	for item_id in CodingItems.ITEMS:
		var item_def = CodingItems.ITEMS[item_id]
		var card = _create_item_card(item_def, current_credits)
		_item_container.add_child(card)

func _create_item_card(item_def: Dictionary, current_credits: int) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.2, 0.9)
	style.border_color = Color(0.25, 0.3, 0.5, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Icon
	var icon_container = PanelContainer.new()
	var icon_bg = StyleBoxFlat.new()
	icon_bg.bg_color = Color(0.15, 0.18, 0.28)
	icon_bg.set_corner_radius_all(6)
	icon_bg.set_content_margin_all(6)
	icon_container.add_theme_stylebox_override("panel", icon_bg)
	icon_container.custom_minimum_size = Vector2(48, 48)
	hbox.add_child(icon_container)

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var icon_tex = CodingItems.get_icon(item_def["id"])
	if icon_tex:
		icon_rect.texture = icon_tex
	icon_container.add_child(icon_rect)

	# Text info (name + description)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = item_def["name"]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = item_def.get("buff_description", item_def.get("description", ""))
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)

	# Consumable / quantity info
	if item_def.get("consumable", false):
		var uses_label = Label.new()
		uses_label.text = "⚠ %d uses per purchase" % item_def.get("pickup_quantity", 1)
		uses_label.add_theme_font_size_override("font_size", 9)
		uses_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		info_vbox.add_child(uses_label)
	else:
		var perm_label = Label.new()
		perm_label.text = "♾ Unlimited uses"
		perm_label.add_theme_font_size_override("font_size", 9)
		perm_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.5))
		info_vbox.add_child(perm_label)

	# Price + buy button column
	var buy_vbox = VBoxContainer.new()
	buy_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_vbox.add_theme_constant_override("separation", 4)
	buy_vbox.custom_minimum_size = Vector2(90, 0)
	hbox.add_child(buy_vbox)

	var price = item_def.get("price", 0)
	var can_afford = current_credits >= price

	var price_label = Label.new()
	price_label.text = "💰 %d" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if can_afford else Color(0.6, 0.3, 0.3))
	buy_vbox.add_child(price_label)

	var buy_btn = Button.new()
	buy_btn.text = "BUY"
	buy_btn.custom_minimum_size = Vector2(80, 30)
	buy_btn.add_theme_font_size_override("font_size", 12)

	if can_afford:
		var buy_style = StyleBoxFlat.new()
		buy_style.bg_color = Color(0.15, 0.4, 0.2, 0.9)
		buy_style.border_color = Color(0.3, 0.7, 0.4)
		buy_style.set_border_width_all(1)
		buy_style.set_corner_radius_all(4)
		buy_btn.add_theme_stylebox_override("normal", buy_style)

		var buy_hover = buy_style.duplicate()
		buy_hover.bg_color = Color(0.2, 0.55, 0.3, 0.95)
		buy_btn.add_theme_stylebox_override("hover", buy_hover)

		buy_btn.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		var item_id = item_def["id"]
		buy_btn.pressed.connect(func(): _on_buy_pressed(item_id))
	else:
		var disabled_style = StyleBoxFlat.new()
		disabled_style.bg_color = Color(0.15, 0.15, 0.2, 0.5)
		disabled_style.set_corner_radius_all(4)
		buy_btn.add_theme_stylebox_override("normal", disabled_style)
		buy_btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		buy_btn.disabled = true

	buy_vbox.add_child(buy_btn)

	return card

# ─── Purchase Logic ──────────────────────────────────────────────────────────

func _on_buy_pressed(item_id: String):
	var cd = get_node_or_null("/root/CharacterData")
	var inv = get_node_or_null("/root/InventoryManager")
	if not cd or not inv:
		return

	var item_def = CodingItems.get_item(item_id)
	if item_def.is_empty():
		return

	var price = item_def.get("price", 0)
	if not cd.spend_credits(price):
		return  # Can't afford

	# Add item to inventory
	var icon = CodingItems.get_icon(item_id)
	var qty = item_def.get("pickup_quantity", 1)
	inv.add_item(
		item_id,
		item_def["name"],
		item_def.get("description", ""),
		icon,
		qty
	)

	print("[Shop] Purchased %s for %d credits" % [item_def["name"], price])

	# Visual feedback — flash the card
	_refresh()

# ─── Input ───────────────────────────────────────────────────────────────────

func _input(event):
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _set_player_movement(enabled: bool):
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = enabled
