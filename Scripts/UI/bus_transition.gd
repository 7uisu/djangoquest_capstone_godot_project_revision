# bus_transition.gd — Bus travel transition overlay
# Animates the bus driving across the city background, then reveals the destination.
extends CanvasLayer

## Emitted when the transition screen is fully opaque (safe to teleport the player)
signal screen_covered
## Emitted when the entire transition is done
signal transition_finished

@onready var background: ColorRect = $Background
@onready var bus_sprite: AnimatedSprite2D = $BusTravelling

## Building layers — add your TileMapLayer node names here
@onready var building_layers: Array = [
	$"generic_buildings-01",
	$"generic_buildings-02",
	$"generic_buildings-03",
]

## Duration of the bus driving across the screen (seconds)
@export var drive_duration: float = 3.0

# Screen dimensions (matches project settings: 1024x576)
const SCREEN_WIDTH := 1024

func _ready():
	layer = 99
	# Start everything invisible
	_set_children_alpha(0.0)

## Play the full transition. Emits screen_covered when safe to teleport.
## goes_right: true = bus drives left-to-right, false = right-to-left
func play_transition(goes_right: bool = true) -> void:
	# --- Randomize which building set is shown ---
	_randomize_buildings()

	# --- Step 1: Fade in the whole transition scene ---
	var fade_in = create_tween()
	fade_in.tween_method(_set_children_alpha, 0.0, 1.0, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await fade_in.finished

	# Screen is now fully covered — safe to teleport the player
	screen_covered.emit()

	# --- Step 2: Animate bus driving across the screen ---
	var start_x: float
	var end_x: float

	if goes_right:
		# Left to right: start off-screen left, end off-screen right
		start_x = -190.0
		end_x = 1158.0
		bus_sprite.position.y = 418.0
		bus_sprite.play("driving_right")
	else:
		# Right to left: start off-screen right, end off-screen left
		start_x = 1158.0
		end_x = -190.0
		bus_sprite.position.y = 335.0
		bus_sprite.play("driving_left")

	bus_sprite.position.x = start_x

	var drive_tween = create_tween()
	drive_tween.tween_property(bus_sprite, "position:x", end_x, drive_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await drive_tween.finished

	bus_sprite.stop()

	# --- Step 3: Brief pause, then fade out ---
	await get_tree().create_timer(0.3).timeout

	var fade_out = create_tween()
	fade_out.tween_method(_set_children_alpha, 1.0, 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await fade_out.finished

	transition_finished.emit()

## Randomly pick one building layer to show and hide the rest
func _randomize_buildings() -> void:
	var chosen_index = randi() % building_layers.size()
	for i in range(building_layers.size()):
		if building_layers[i]:
			building_layers[i].visible = (i == chosen_index)

## Set the alpha on all CanvasItem children (since CanvasLayer has no modulate)
func _set_children_alpha(alpha: float) -> void:
	for child in get_children():
		if child is CanvasItem:
			child.modulate.a = alpha
