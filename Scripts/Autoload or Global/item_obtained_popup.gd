extends CanvasLayer

signal popup_closed

@onready var backdrop: ColorRect = $Backdrop
@onready var card: PanelContainer = $Backdrop/CenterContainer/ItemCard
@onready var icon_texture: TextureRect = $Backdrop/CenterContainer/ItemCard/MarginContainer/Contents/IconFrame/IconTexture
@onready var icon_fallback: Label = $Backdrop/CenterContainer/ItemCard/MarginContainer/Contents/IconFrame/IconFallback
@onready var item_title: Label = $Backdrop/CenterContainer/ItemCard/MarginContainer/Contents/ItemTitle
@onready var item_description: Label = $Backdrop/CenterContainer/ItemCard/MarginContainer/Contents/ItemDescription
@onready var continue_button: Button = $Backdrop/CenterContainer/ItemCard/MarginContainer/Contents/ContinueButton
@onready var fanfare_player: AudioStreamPlayer = $FanfarePlayer

var _is_showing := false
var _close_requested := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	continue_button.pressed.connect(_close_popup)
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	card.gui_input.connect(_on_card_gui_input)


func show_item(
	item_id: String,
	item_name: String,
	description: String,
	icon: Texture2D = null,
	quantity: int = 1
) -> void:
	# Player input is blocked while this card is open, so normal gameplay cannot
	# queue a second pickup. Keep a small guard for scripted rewards as well.
	if _is_showing:
		while _is_showing:
			await get_tree().process_frame

	_is_showing = true
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory:
		inventory.add_item(item_id, item_name, description, icon, maxi(quantity, 1))

	item_title.text = "%s OBTAINED!" % item_name.to_upper()
	item_description.text = description
	icon_texture.texture = icon
	icon_texture.visible = icon != null
	icon_fallback.visible = icon == null
	if icon == null:
		var is_green_badge := item_id == "green_ojt_badge"
		var is_blue_badge := item_id == "blue_junior_developer_badge"
		icon_fallback.text = "●" if is_green_badge or is_blue_badge else "▣" if item_id == "ojt_kit" else "★"
		icon_fallback.add_theme_color_override(
			"font_color",
			Color(0.48, 0.83, 0.48, 1.0) if is_green_badge else Color(0.38, 0.66, 0.98, 1.0) if is_blue_badge else Color(0.91, 0.78, 0.37, 1.0)
		)
	continue_button.text = "Press Space / Enter or Click to Continue"
	_close_requested = false
	backdrop.color.a = 0.0
	card.scale = Vector2(0.92, 0.92)
	visible = true
	card.pivot_offset = card.size * 0.5
	var players := get_tree().get_nodes_in_group("player")
	var player: Node = players[0] if not players.is_empty() else null
	var could_move := false
	var had_ui_input_block := false
	if player and "can_move" in player:
		could_move = player.can_move
		player.can_move = false
	if player and "block_ui_input" in player:
		had_ui_input_block = player.block_ui_input
		player.block_ui_input = true
	if fanfare_player.stream:
		fanfare_player.play()
	var pop_in := create_tween().set_parallel(true)
	pop_in.tween_property(backdrop, "color:a", 0.64, 0.18)
	pop_in.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop_in.finished
	# Input can arrive while the card is animating in. Signals are not queued,
	# so only await if the close request has not already been recorded.
	if not _close_requested:
		await popup_closed
	var pop_out := create_tween().set_parallel(true)
	# A warm reward flash and a deliberate card collapse make dismissal read as
	# a transition, rather than the popup simply disappearing.
	pop_out.tween_property(backdrop, "color", Color(0.78, 0.69, 0.35, 0.0), 0.38).set_ease(Tween.EASE_IN_OUT)
	pop_out.tween_property(card, "scale", Vector2(0.78, 0.78), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	pop_out.tween_property(card, "modulate:a", 0.0, 0.30).set_ease(Tween.EASE_IN)
	await pop_out.finished
	visible = false
	card.modulate.a = 1.0
	card.scale = Vector2.ONE
	backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
	if player and is_instance_valid(player) and "can_move" in player:
		player.can_move = could_move
	if player and is_instance_valid(player) and "block_ui_input" in player:
		player.block_ui_input = had_ui_input_block
	_is_showing = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_close_popup()
			get_viewport().set_input_as_handled()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_popup()
		backdrop.accept_event()


func _on_card_gui_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_popup()
		card.accept_event()


func _close_popup() -> void:
	if visible and not _close_requested:
		_close_requested = true
		popup_closed.emit()
