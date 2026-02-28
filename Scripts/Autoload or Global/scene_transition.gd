# scene_transition.gd — Autoload for polished scene transitions
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

var _spawn_position: Vector2 = Vector2.ZERO
var _has_pending_spawn: bool = false

const FADE_OUT_DURATION := 0.35
const HOLD_DURATION := 0.3
const FADE_IN_DURATION := 0.45

func _ready():
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer = 100

func transition_to_scene(scene_path: String, spawn_pos: Vector2 = Vector2.ZERO) -> void:
	_spawn_position = spawn_pos
	_has_pending_spawn = spawn_pos != Vector2.ZERO

	# Disable player input during transition
	_set_player_movement(false)

	# --- Step 1: Walk player toward the door briefly ---
	var player = _find_player()
	if player:
		# Small nudge toward the door (move up slightly to simulate entering)
		var walk_tween = create_tween()
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
