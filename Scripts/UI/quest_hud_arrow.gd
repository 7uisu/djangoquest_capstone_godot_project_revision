# quest_hud_arrow.gd — Full-screen overlay: edge arrow that eases toward the target + fades when close
extends Control

## World distance (px): pure edge indicator, full opacity
const DIST_EDGE_FULL := 380.0
## World distance (px): arrow sits near player↔target on screen
const DIST_INTERIOR_FULL := 110.0
## World distance (px): stop drawing
const DIST_HIDE := 28.0
## Screen inset from viewport border
const EDGE_INSET := 36.0
const ARROW_SIZE := 22.0
## On screen, arrow sits along player→target (0 = on player, 1 = on target)
const INTERIOR_TOWARD_TARGET := 0.58


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var qm := get_node_or_null("/root/QuestManager")
	if qm == null or not qm.is_quest_content_visible():
		return
	if qm.target_node_names.is_empty():
		return
	var player := _find_player()
	if player == null:
		return
	var target: Vector2 = qm.get_arrow_target_global_position()
	if target == Vector2.ZERO:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return

	var dist_world: float = player.global_position.distance_to(target)
	if dist_world < DIST_HIDE:
		return

	var half := size * 0.5
	var canvas_xf := cam.get_canvas_transform()
	var p_screen: Vector2 = canvas_xf * player.global_position
	var t_screen: Vector2 = canvas_xf * target
	var to_target: Vector2 = t_screen - p_screen
	if to_target.length_squared() < 0.25:
		return

	var angle_edge: float = to_target.angle()
	var edge: Vector2 = _screen_edge_from_angle(angle_edge, half, EDGE_INSET)

	# Screen point between player and quest target (quest "hotspot" direction)
	var interior: Vector2 = p_screen.lerp(t_screen, INTERIOR_TOWARD_TARGET)
	var m := EDGE_INSET + ARROW_SIZE
	interior.x = clampf(interior.x, m, size.x - m)
	interior.y = clampf(interior.y, m, size.y - m)

	# 0 = far (locked to edge), 1 = close (slides toward player/target)
	var raw_blend: float = 1.0 - smoothstep(DIST_INTERIOR_FULL, DIST_EDGE_FULL, dist_world)
	# Ease so it "slowly" leaves the corner rather than snapping
	var interior_blend: float = raw_blend * raw_blend * (3.0 - 2.0 * raw_blend)

	var pos: Vector2 = edge.lerp(interior, interior_blend)
	# Point at target from drawn position (reads correctly when pulled inward)
	var angle: float = (t_screen - pos).angle()

	# Opacity: full when far; drops as we approach + extra dip when arrow is interior
	var alpha_far: float = smoothstep(DIST_HIDE, DIST_HIDE + 55.0, dist_world)
	var alpha_prox: float = lerpf(0.22, 1.0, smoothstep(45.0, 220.0, dist_world))
	var alpha: float = clampf(alpha_far * alpha_prox, 0.0, 1.0)
	# Slightly dimmer while arrow is migrating off the edge
	alpha *= lerpf(1.0, 0.88, interior_blend)

	if alpha < 0.04:
		return

	var arrow_xf := Transform2D(angle, pos)
	draw_set_transform_matrix(arrow_xf)
	var pts := PackedVector2Array([
		Vector2(ARROW_SIZE, 0),
		Vector2(-ARROW_SIZE * 0.65, ARROW_SIZE * 0.55),
		Vector2(-ARROW_SIZE * 0.65, -ARROW_SIZE * 0.55),
	])
	draw_colored_polygon(pts, Color(0.96, 0.82, 0.28, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D


func _screen_edge_from_angle(angle: float, half: Vector2, margin: float) -> Vector2:
	var d := Vector2.from_angle(angle)
	var ox := (half.x - margin) / maxf(absf(d.x), 0.001)
	var oy := (half.y - margin) / maxf(absf(d.y), 0.001)
	var t := minf(ox, oy)
	return half + d * t
