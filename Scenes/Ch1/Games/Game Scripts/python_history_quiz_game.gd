extends Control

# Quiz data
var questions = [
	{
		"question": "Who created Python?",
		"options": ["A) Dennis Ritchie", "B) Guido van Rossum", "C) Bjarne Stroustrup", "D) James Gosling"],
		"correct": 1  # B) Guido van Rossum
	},
	{
		"question": "What inspired the name \"Python\"?",
		"options": ["A) The snake", "B) A Dutch comic book", "C) Monty Python's\n    Flying Circus", "D) A Greek god"],
		"correct": 2  # C) Monty Python's Flying Circus
	},
	{
		"question": "When did development of Python begin?",
		"options": ["A) 1995", "B) 2008", "C) 1989", "D) 1972"],
		"correct": 2  # C) 1989
	},
	{
		"question": "What is one of Python's core design goals?",
		"options": ["A) Use of lots of punctuation", "B) Machine-only readability", "C) Complex syntax", "D) Readability and simplicity"],
		"correct": 3  # D) Readability and simplicity
	},
	{
		"question": "Which organization uses Python for space-related tasks?",
		"options": ["A) Apple", "B) NASA", "C) Meta", "D) IBM"],
		"correct": 1  # B) NASA
	}
]

# Game state
var current_question = 0
var score = 0
var selected_answer = -1
var is_drawing = false
var drawing_points = []
var quiz_completed = false
var answer_locked = false  # NEW: prevent re-drawing after selection

# UI nodes
@onready var question_label = $QuestionLabel
@onready var option_labels = [$OptionA, $OptionB, $OptionC, $OptionD]
@onready var drawing_area = $DrawingArea
@onready var next_button = $NextButton
@onready var score_label = $ScoreLabel
@onready var restart_button = $RestartButton
@onready var progress_label = $ProgressLabel        # NEW
@onready var feedback_label = $FeedbackLabel        # NEW
@onready var correct_sfx = $CorrectSFX              # NEW
@onready var wrong_sfx = $WrongSFX                  # NEW

func _ready():
	setup_ui()
	shuffle_questions()  # NEW: randomize order
	load_question()
	next_button.pressed.connect(_on_next_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)

func setup_ui():
	# Set up drawing area functionality
	drawing_area.gui_input.connect(_on_drawing_area_gui_input)
	drawing_area.draw.connect(_on_drawing_area_draw)
	
	# Set up initial button states
	next_button.disabled = true
	restart_button.visible = false
	
	# Show live score during quiz (was hidden before)
	score_label.visible = true
	score_label.text = "Score: 0/5"
	
	# NEW: progress & feedback labels
	progress_label.visible = true
	feedback_label.visible = false

# NEW: Shuffle questions for variety on each play
func shuffle_questions():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(questions.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = questions[i]
		questions[i] = questions[j]
		questions[j] = tmp

func load_question():
	if current_question >= questions.size():
		show_final_score()
		return
	
	var q = questions[current_question]
	question_label.text = "Question " + str(current_question + 1) + ": " + q.question
	
	for i in range(4):
		option_labels[i].text = q.options[i]
	
	# Reset drawing state
	selected_answer = -1
	answer_locked = false  # NEW: unlock drawing
	drawing_points.clear()
	drawing_area.queue_redraw()
	next_button.disabled = true
	feedback_label.visible = false  # NEW: hide previous feedback
	
	# NEW: update progress label
	progress_label.text = "Question " + str(current_question + 1) + " of " + str(questions.size())
	
	# NEW: update live score
	score_label.text = "Score: " + str(score) + "/" + str(questions.size())
	
	# NEW: animated fade-in for question text
	question_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(question_label, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)

func _on_drawing_area_gui_input(event):
	if quiz_completed:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_drawing = true
				drawing_points.clear()
				drawing_points.append(event.position)
			else:
				is_drawing = false
				check_circle_selection()
	elif event is InputEventMouseMotion and is_drawing:
		drawing_points.append(event.position)
		drawing_area.queue_redraw()

func _on_drawing_area_draw():
	if drawing_points.size() > 1:
		var color = Color.BLUE
		color.a = 0.7
		for i in range(1, drawing_points.size()):
			drawing_area.draw_line(drawing_points[i-1], drawing_points[i], color, 3.0)

func check_circle_selection():
	if drawing_points.size() < 10:  # Need enough points to form a circle
		return
	
	# Improved circle detection: focus on letter portion only
	var center = get_drawing_center()
	var radius = get_average_radius(center)
	
	# Check if the circle is reasonably circular
	if is_roughly_circular(center, radius):
		# Check which option letter the circle encircles
		for i in range(4):
			if is_letter_encircled(i, center, radius):
				selected_answer = i
				answer_locked = true  # NEW: lock drawing after selection
				print("Detected circle around option ", i, ": ", questions[current_question].options[i])
				highlight_selection(i)
				next_button.disabled = false
				break

# Check if the circle specifically encircles the letter portion
func is_letter_encircled(option_index, circle_center, circle_radius):
	# Get the letter position (left side of the option label)
	var option_label = option_labels[option_index]
	var option_global_pos = option_label.global_position
	var drawing_area_global = drawing_area.global_position
	
	# Calculate letter position relative to drawing area
	var letter_pos = option_global_pos - drawing_area_global
	letter_pos.x += 10  # Adjust based on label padding
	letter_pos.y += option_label.size.y / 2  # Center vertically
	
	# Check if circle center is close to letter position
	var distance_to_letter = circle_center.distance_to(letter_pos)
	
	# UPGRADED: more forgiving detection zone
	var max_distance = 60  # Was 25 — wider tolerance
	
	return distance_to_letter < max_distance and circle_radius > 15 and circle_radius < 80  # Was < 50

func get_drawing_center():
	var sum = Vector2.ZERO
	for point in drawing_points:
		sum += point
	return sum / drawing_points.size()

func get_average_radius(center):
	var total_distance = 0.0
	for point in drawing_points:
		total_distance += center.distance_to(point)
	return total_distance / drawing_points.size()

func is_roughly_circular(center, expected_radius):
	var variance_threshold = expected_radius * 0.4  # Allow 40% variance
	var good_points = 0
	
	for point in drawing_points:
		var distance = center.distance_to(point)
		if abs(distance - expected_radius) < variance_threshold:
			good_points += 1
	
	return good_points > drawing_points.size() * 0.6  # 60% of points should be roughly circular

func highlight_selection(option_index):
	# Reset all option colors
	for i in range(4):
		option_labels[i].modulate = Color.WHITE
	
	# Highlight selected option
	option_labels[option_index].modulate = Color.YELLOW

func _on_next_button_pressed():
	if selected_answer == -1:
		return
	
	var correct_answer = questions[current_question].correct
	print("Selected answer: ", selected_answer, " (", questions[current_question].options[selected_answer], ")")
	print("Correct answer: ", correct_answer, " (", questions[current_question].options[correct_answer], ")")
	
	# Check if answer is correct
	if selected_answer == correct_answer:
		score += 1
		option_labels[selected_answer].modulate = Color.GREEN
		print("Correct! Score: ", score)
		# NEW: feedback text + SFX
		feedback_label.text = "✓ Correct!"
		feedback_label.add_theme_color_override("font_color", Color(0.1, 0.7, 0.1))
		if correct_sfx.stream:
			correct_sfx.play()
	else:
		option_labels[selected_answer].modulate = Color.RED
		option_labels[correct_answer].modulate = Color.GREEN
		print("Wrong! Score remains: ", score)
		# NEW: feedback text + SFX
		var correct_letter = questions[current_question].options[correct_answer]
		feedback_label.text = "✗ Wrong — answer was " + correct_letter
		feedback_label.add_theme_color_override("font_color", Color(0.8, 0.15, 0.15))
		if wrong_sfx.stream:
			wrong_sfx.play()
	
	# NEW: show feedback label with fade-in
	feedback_label.visible = true
	feedback_label.modulate.a = 0.0
	var fb_tween = create_tween()
	fb_tween.tween_property(feedback_label, "modulate:a", 1.0, 0.3)
	
	# NEW: update live score immediately
	score_label.text = "Score: " + str(score) + "/" + str(questions.size())
	
	# Wait a moment to show the result, then move to next question
	await get_tree().create_timer(1.5).timeout
	
	current_question += 1
	
	# Reset option colors
	for i in range(4):
		option_labels[i].modulate = Color.WHITE
	
	load_question()

func show_final_score():
	quiz_completed = true
	question_label.text = "Quiz Complete!\nFinal Score: " + str(score) + "/5"
	
	# Hide options and show score
	for label in option_labels:
		label.visible = false
	
	# Show score label at the end
	score_label.visible = true
	score_label.text = "Final Score: " + str(score) + "/5"
	
	# Hide progress label at end
	progress_label.visible = false
	feedback_label.visible = false
	
	var percentage = (score * 100) / 5
	var grade = ""
	if percentage >= 90:
		grade = "Excellent!"
	elif percentage >= 80:
		grade = "Great job!"
	elif percentage >= 70:
		grade = "Good work!"
	elif percentage >= 60:
		grade = "Not bad!"
	else:
		grade = "Keep studying!"
	
	question_label.text += "\n" + str(percentage) + "% - " + grade
	
	next_button.visible = false
	restart_button.visible = true
	drawing_points.clear()
	drawing_area.queue_redraw()

func _on_restart_button_pressed():
	# Reset game state
	current_question = 0
	score = 0
	selected_answer = -1
	quiz_completed = false
	answer_locked = false
	drawing_points.clear()
	
	# Reset UI
	for label in option_labels:
		label.visible = true
		label.modulate = Color.WHITE
	
	next_button.visible = true
	next_button.disabled = true
	restart_button.visible = false
	
	# Reset labels
	score_label.visible = true
	score_label.text = "Score: 0/5"
	progress_label.visible = true
	feedback_label.visible = false
	
	drawing_area.queue_redraw()
	shuffle_questions()  # NEW: re-shuffle on restart
	load_question()
