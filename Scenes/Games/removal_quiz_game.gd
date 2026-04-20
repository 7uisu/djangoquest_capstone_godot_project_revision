# Scenes/Games/removal_quiz_game.gd
# Reusable removal exam — circle-the-letter mechanic.
# Based on python_history_quiz_game (v.gd) but accepts dynamic question injection.
#
# Usage from professor controller:
#   var quiz = REMOVAL_QUIZ_SCENE.instantiate()
#   quiz.all_questions = markup_removal_questions   # inject per-professor bank
#   quiz.quiz_count = 5                             # how many to pick
#   quiz.pass_score = 3                             # minimum to pass
#   canvas.add_child(quiz)
#   var score = await quiz.quiz_completed
extends Control

signal quiz_completed(score: int)

# Injected per professor — array of { question, options, correct }
var all_questions: Array = []

# Config
var quiz_count: int = 5
var pass_score: int = 3

# Runtime state
var questions: Array = []
var current_question: int = 0
var score: int = 0
var selected_answer: int = -1
var is_drawing: bool = false
var drawing_points: Array = []
var is_quiz_completed: bool = false
var answer_locked: bool = false
var is_in_tutorial: bool = true

@onready var question_label: Label = $UI_Layer/VBoxContainer/QuestionContainer/QuestionLabel
@onready var option_labels: Array = [
	$UI_Layer/VBoxContainer/OptionsGrid/OptionA, 
	$UI_Layer/VBoxContainer/OptionsGrid/OptionB, 
	$UI_Layer/VBoxContainer/OptionsGrid/OptionC, 
	$UI_Layer/VBoxContainer/OptionsGrid/OptionD
]
@onready var drawing_area: ColorRect = $DrawingArea
@onready var next_button: Button = $UI_Layer/VBoxContainer/BottomBar/NextButton
@onready var score_label: Label = $UI_Layer/VBoxContainer/TopBar/ScoreLabel
@onready var restart_button: Button = $UI_Layer/VBoxContainer/BottomBar/RestartButton
@onready var progress_label: Label = $UI_Layer/VBoxContainer/TopBar/ProgressLabel
@onready var feedback_label: Label = $UI_Layer/VBoxContainer/FeedbackLabel
@onready var continue_button: Button = $UI_Layer/VBoxContainer/BottomBar/ContinueButton
@onready var correct_sfx: AudioStreamPlayer = $CorrectSFX
@onready var wrong_sfx: AudioStreamPlayer = $WrongSFX


func _ready():
	setup_ui()
	shuffle_questions()
	show_tutorial()
	next_button.pressed.connect(_on_next_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)


func show_tutorial():
	is_in_tutorial = true
	question_label.text = "REMOVAL EXAM\n\nInstructions:\nTo select an answer, DRAW A CIRCLE around the letter corresponding to your choice.\n\nYou need at least %d out of %d to pass.\n\nGood Luck!" % [pass_score, quiz_count]

	for label in option_labels:
		label.visible = false

	score_label.visible = false
	progress_label.visible = false
	feedback_label.modulate.a = 0.0

	next_button.text = "Start"
	next_button.disabled = false
	next_button.visible = true


func setup_ui():
	drawing_area.gui_input.connect(_on_drawing_area_gui_input)
	drawing_area.draw.connect(_on_drawing_area_draw)

	next_button.disabled = true
	restart_button.visible = false

	score_label.visible = true
	score_label.text = "Score: 0/%d" % quiz_count

	progress_label.visible = true
	feedback_label.modulate.a = 0.0


func shuffle_questions():
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var pool = all_questions.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	questions = pool.slice(0, mini(quiz_count, pool.size()))


func load_question():
	if current_question >= questions.size():
		show_final_score()
		return

	var q = questions[current_question]
	question_label.text = "Question " + str(current_question + 1) + ": " + q.question

	for i in range(4):
		option_labels[i].text = q.options[i]

	selected_answer = -1
	answer_locked = false
	drawing_points.clear()
	drawing_area.queue_redraw()
	next_button.disabled = true
	feedback_label.modulate.a = 0.0

	progress_label.text = "Question " + str(current_question + 1) + " of " + str(questions.size())
	score_label.text = "Score: " + str(score) + "/" + str(questions.size())

	question_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(question_label, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)


# ── Drawing Input ─────────────────────────────────────────────────────

func _on_drawing_area_gui_input(event):
	if is_quiz_completed or is_in_tutorial or answer_locked:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_drawing = true
				drawing_points.clear()
				drawing_points.append(event.position)
				selected_answer = -1
				for i in range(4):
					option_labels[i].modulate = Color.WHITE
				next_button.disabled = true
				drawing_area.queue_redraw()
			else:
				is_drawing = false
				check_circle_selection()
	elif event is InputEventMouseMotion and is_drawing:
		drawing_points.append(event.position)
		drawing_area.queue_redraw()


func _on_drawing_area_draw():
	if drawing_points.size() > 1:
		var color = Color(0.85, 0.1, 0.1, 0.85)
		for i in range(1, drawing_points.size()):
			drawing_area.draw_line(drawing_points[i - 1], drawing_points[i], color, 4.0)


func check_circle_selection():
	if drawing_points.size() < 10:
		return

	var center = get_drawing_center()
	var radius = get_average_radius(center)

	if is_roughly_circular(center, radius):
		var encircled_options = []
		for i in range(4):
			if is_letter_encircled(i, center, radius):
				encircled_options.append(i)
		
		# Only select if exactly ONE option is encircled. Prevents ambiguous large shapes.
		if encircled_options.size() == 1:
			selected_answer = encircled_options[0]
			highlight_selection(selected_answer)
			next_button.disabled = false


func is_letter_encircled(option_index: int, circle_center: Vector2, circle_radius: float) -> bool:
	var option_label = option_labels[option_index]
	var option_global_pos = option_label.global_position
	var drawing_area_global = drawing_area.global_position

	var letter_pos = option_global_pos - drawing_area_global
	letter_pos.x += 10
	letter_pos.y += option_label.size.y / 2

	var distance_to_letter = circle_center.distance_to(letter_pos)
	var max_distance = 60
	return distance_to_letter < max_distance and circle_radius > 15 and circle_radius < 80


func get_drawing_center() -> Vector2:
	var sum = Vector2.ZERO
	for point in drawing_points:
		sum += point
	return sum / drawing_points.size()


func get_average_radius(center: Vector2) -> float:
	var total_distance = 0.0
	for point in drawing_points:
		total_distance += center.distance_to(point)
	return total_distance / drawing_points.size()


func is_roughly_circular(center: Vector2, expected_radius: float) -> bool:
	var variance_threshold = expected_radius * 0.4
	var good_points = 0
	for point in drawing_points:
		var distance = center.distance_to(point)
		if abs(distance - expected_radius) < variance_threshold:
			good_points += 1
	return good_points > drawing_points.size() * 0.6


func highlight_selection(option_index: int):
	for i in range(4):
		option_labels[i].modulate = Color.WHITE
	option_labels[option_index].modulate = Color.YELLOW


# ── Answer Processing ─────────────────────────────────────────────────

func _on_next_button_pressed():
	if is_in_tutorial:
		is_in_tutorial = false
		next_button.text = "Next"
		for label in option_labels:
			label.visible = true
		score_label.visible = true
		progress_label.visible = true
		load_question()
		return

	if selected_answer == -1:
		return

	answer_locked = true
	next_button.disabled = true

	var correct_answer = questions[current_question].correct

	if selected_answer == correct_answer:
		score += 1
		option_labels[selected_answer].modulate = Color.GREEN
		feedback_label.text = "✓ Correct!"
		feedback_label.add_theme_color_override("font_color", Color(0.1, 0.7, 0.1))
		if correct_sfx.stream:
			correct_sfx.play()
	else:
		option_labels[selected_answer].modulate = Color.RED
		option_labels[correct_answer].modulate = Color.GREEN
		var correct_letter = questions[current_question].options[correct_answer]
		feedback_label.text = "✗ Wrong — answer was " + correct_letter
		feedback_label.add_theme_color_override("font_color", Color(0.8, 0.15, 0.15))
		if wrong_sfx.stream:
			wrong_sfx.play()

	feedback_label.modulate.a = 0.0
	var fb_tween = create_tween()
	fb_tween.tween_property(feedback_label, "modulate:a", 1.0, 0.3)

	score_label.text = "Score: " + str(score) + "/" + str(questions.size())

	await get_tree().create_timer(1.5).timeout

	current_question += 1

	for i in range(4):
		option_labels[i].modulate = Color.WHITE

	load_question()


func show_final_score():
	is_quiz_completed = true

	var passed = score >= pass_score
	var result_text = "PASSED ✓" if passed else "FAILED ✗"
	question_label.text = "Removal Exam Complete!\nFinal Score: %d/%d\n%s" % [score, questions.size(), result_text]

	for label in option_labels:
		label.visible = false

	score_label.visible = true
	score_label.text = "Final: %d/%d" % [score, questions.size()]

	progress_label.visible = false
	feedback_label.modulate.a = 0.0

	next_button.visible = false
	restart_button.visible = false

	continue_button.visible = true
	continue_button.grab_focus()

	drawing_points.clear()
	drawing_area.queue_redraw()


func _on_restart_button_pressed():
	is_in_tutorial = false
	next_button.text = "Next"
	current_question = 0
	score = 0
	selected_answer = -1
	is_quiz_completed = false
	answer_locked = false
	drawing_points.clear()

	for label in option_labels:
		label.visible = true
		label.modulate = Color.WHITE

	next_button.visible = true
	next_button.disabled = true
	restart_button.visible = false

	score_label.visible = true
	score_label.text = "Score: 0/%d" % quiz_count
	progress_label.visible = true
	feedback_label.modulate.a = 0.0

	drawing_area.queue_redraw()
	shuffle_questions()
	load_question()


func _on_continue_pressed():
	emit_signal("quiz_completed", score)
	queue_free()
