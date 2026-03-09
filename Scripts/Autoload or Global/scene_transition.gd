# scene_transition.gd — Autoload for polished scene transitions
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

var _spawn_position: Vector2 = Vector2.ZERO
var _has_pending_spawn: bool = false
var _spawn_direction: String = "down"

const FADE_OUT_DURATION := 0.35
const HOLD_DURATION := 0.3
const FADE_IN_DURATION := 0.45

var _bus_transition_scene = preload("res://Scenes/UI/bus_transition.tscn")

func _ready():
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer = 100

func transition_to_scene(scene_path: String, spawn_pos: Vector2 = Vector2.ZERO, entry_dir: String = "up") -> void:
	_spawn_position = spawn_pos
	_has_pending_spawn = spawn_pos != Vector2.ZERO
	_spawn_direction = entry_dir

	# Disable player input during transition
	_set_player_movement(false)

	# --- Step 1: Walk player toward the door briefly ---
	var player = _find_player()
	if player:
		# Set the player's facing direction so it looks like they're walking into the door
		player.current_dir = entry_dir
		player.play_walk_animation(entry_dir)

		# Nudge the player in the entry direction
		var walk_tween = create_tween()
		match entry_dir:
			"up":
				walk_tween.tween_property(player, "global_position:y", player.global_position.y - 12.0, 0.25).set_ease(Tween.EASE_IN)
			"down":
				walk_tween.tween_property(player, "global_position:y", player.global_position.y + 12.0, 0.25).set_ease(Tween.EASE_IN)
			"left":
				walk_tween.tween_property(player, "global_position:x", player.global_position.x - 12.0, 0.25).set_ease(Tween.EASE_IN)
			"right":
				walk_tween.tween_property(player, "global_position:x", player.global_position.x + 12.0, 0.25).set_ease(Tween.EASE_IN)
			_:
				walk_tween.tween_property(player, "global_position:y", player.global_position.y - 12.0, 0.25).set_ease(Tween.EASE_IN)
		await walk_tween.finished

	# --- Step 2: Fade to black with smooth ease ---
	var fade_out = create_tween()
	fade_out.tween_property(color_rect, "color:a", 1.0, FADE_OUT_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await fade_out.finished

	# --- Step 3: Brief hold on black screen ---
	await get_tree().create_timer(HOLD_DURATION).timeout

	# --- Step 4: Change scene ---
	get_tree().change_scene_to_file(scene_path)

	# Wait for the new scene to fully initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# --- Step 5: Reposition the player at the destination door ---
	if _has_pending_spawn:
		var new_player = _find_player()
		if new_player:
			new_player.global_position = _spawn_position
			# Set the player's facing direction in the new scene
			new_player.current_dir = _spawn_direction
			new_player.play_idle_animation(_spawn_direction)
			# Make camera snap immediately so there's no camera lerp visible
			var cam = new_player.get_node_or_null("Camera2D")
			if cam:
				cam.force_update_scroll()
		_has_pending_spawn = false

	# Small delay before fade-in so everything settles
	await get_tree().create_timer(0.1).timeout

	# --- Step 6: Fade back in with a smooth ease ---
	var fade_in = create_tween()
	fade_in.tween_property(color_rect, "color:a", 0.0, FADE_IN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await fade_in.finished

	# Re-enable player movement
	_set_player_movement(true)

func _find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _set_player_movement(enabled: bool) -> void:
	var player = _find_player()
	if player and "can_move" in player:
		player.can_move = enabled

## Fast travel: teleport the player on the SAME map with a bus transition overlay.
## No scene change — just teleport + animation.
func fast_travel(target_position: Vector2) -> void:
	# Disable player input
	_set_player_movement(false)

	# Instantiate the bus transition overlay
	var bus_transition = _bus_transition_scene.instantiate()
	add_child(bus_transition)

	# When the screen is fully covered, teleport the player
	bus_transition.screen_covered.connect(func():
		var player = _find_player()
		if player:
			player.global_position = target_position
			player.current_dir = "down"
			player.play_idle_animation("down")

			# Snap camera so there's no lerp visible
			var cam = player.get_node_or_null("Camera2D")
			if cam:
				cam.force_update_scroll()
	)

	# Play the full transition (fade in → hold → fade out)
	await bus_transition.play_transition()

	# Clean up
	await get_tree().create_timer(0.1).timeout
	bus_transition.queue_free()

	# Re-enable player movement
	_set_player_movement(true)

