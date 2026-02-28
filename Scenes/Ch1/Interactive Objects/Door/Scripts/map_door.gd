# map_door.gd — Door that transitions to another map scene
extends "res://Scenes/Ch1/Interactive Objects/Door/Scripts/door.gd"

@export var target_scene: String = ""
@export var spawn_position: Vector2 = Vector2.ZERO

func interact():
	if show_once and has_interacted:
		return
	if is_animating:
		return
	if is_locked:
		_show_locked_feedback()
		return

	# Play door open animation
	is_animating = true
	has_interacted = true
	anim_sprite.play("open_animation")

	# Wait for the animation to finish (one loop)
	await anim_sprite.animation_looped
	is_animating = false
	is_door_open = true
	anim_sprite.play("open_idle")
	if door_collision:
		door_collision.disabled = true

	# Trigger the scene transition
	if target_scene != "":
		var scene_transition = get_node("/root/SceneTransition")
		if scene_transition:
			scene_transition.transition_to_scene(target_scene, spawn_position)
