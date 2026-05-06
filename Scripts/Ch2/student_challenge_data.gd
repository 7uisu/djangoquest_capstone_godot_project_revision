# student_challenge_data.gd — Question bank for the 5-student sequence per professor
# Students 1-4 = multiple-choice (4 options each, 5 questions per student)
# Student 5 = mini-boss (free_type / debug in the IDE)
# Students 2 & 4 are TIMED (rapid fire)
extends RefCounted
class_name StudentChallengeData

# ── Random student flavor names ──────────────────────────────────────────────
const STUDENT_NAMES := [
	"Alex (Struggling)", "Jamie (Caffeinated)", "Sam (Panicking)",
	"Riley (Confused)", "Jordan (Stressed)", "Casey (Cramming)",
	"Morgan (Sleepy)", "Taylor (Determined)", "Avery (Overthinking)",
	"Quinn (Lost)", "Drew (Frantic)", "Blake (Spacing Out)",
	"Charlie (Nervous)", "Skyler (Distracted)", "Reese (Blanking)",
]

# Returns 5 unique random names from the pool
static func get_random_names(count: int = 5) -> Array:
	var pool = STUDENT_NAMES.duplicate()
	pool.shuffle()
	return pool.slice(0, count)

# ── Challenge Retrieval ──────────────────────────────────────────────────────
# Returns Array of 5 student challenge sets for the given professor semester key
static func get_challenges_for_professor(prof_key: String) -> Array:
	match prof_key:
		"y1s1": return _markup_challenges()
		"y1s2": return _syntax_challenges()
		"y2s1": return _view_challenges()
		"y2s2": return _query_challenges()
		"y3s1": return _token_challenges()
		"y3s2": return _auth_challenges()
		"y3mid": return _rest_challenges()
		_: return []

# Credits awarded per student defeated (user will adjust later)
const CREDITS_PER_STUDENT := 50
const CREDITS_MINIBOSS := 100

# ═══════════════════════════════════════════════════════════════════════════════
# PROFESSOR MARKUP (Y1S1) — HTML, CSS, Web Basics
# ═══════════════════════════════════════════════════════════════════════════════
static func _markup_challenges() -> Array:
	return [
		# ── Student 1: Untimed — How the Web Works ──
		{
			"student_index": 0, "timed": false, "is_miniboss": false,
			"questions": [
				{
					"title": "How the Web Works",
					"type": "predict_output", "topic": "html",
					"file_name": "concepts.txt",
					"code_lines": ["# What does a web browser send to a server?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. An HTTP Request", "correct": true},
						{"text": "B. A CSS Stylesheet", "correct": false},
						{"text": "C. A Python Script", "correct": false},
						{"text": "D. A Database Query", "correct": false},
					],
					"correct_output": "Correct! Browsers send HTTP Requests to servers.",
					"error_output": "Not quite — browsers communicate via HTTP.",
				},
				{
					"title": "Client vs Server",
					"type": "predict_output", "topic": "html",
					"file_name": "concepts.txt",
					"code_lines": ["# Which side renders the HTML for the user?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. The Server", "correct": false},
						{"text": "B. The Client (Browser)", "correct": true},
						{"text": "C. The Database", "correct": false},
						{"text": "D. The Router", "correct": false},
					],
					"correct_output": "The browser (client) renders HTML!",
					"error_output": "The client-side browser renders HTML.",
				},
				{
					"title": "HTTP Status Codes",
					"type": "predict_output", "topic": "html",
					"file_name": "concepts.txt",
					"code_lines": ["# What does status code 404 mean?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. Server Error", "correct": false},
						{"text": "B. Redirect", "correct": false},
						{"text": "C. Not Found", "correct": true},
						{"text": "D. Success", "correct": false},
					],
					"correct_output": "404 = Not Found!",
					"error_output": "404 means the page was not found.",
				},
				{
					"title": "URL Components",
					"type": "predict_output", "topic": "html",
					"file_name": "concepts.txt",
					"code_lines": ["# In 'https://example.com/about', what is '/about'?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. The domain", "correct": false},
						{"text": "B. The protocol", "correct": false},
						{"text": "C. The path", "correct": true},
						{"text": "D. The port", "correct": false},
					],
					"correct_output": "/about is the path!",
					"error_output": "That part of the URL is the path.",
				},
				{
					"title": "HTTP Methods",
					"type": "predict_output", "topic": "html",
					"file_name": "concepts.txt",
					"code_lines": ["# Which HTTP method is used to retrieve a webpage?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. POST", "correct": false},
						{"text": "B. DELETE", "correct": false},
						{"text": "C. PUT", "correct": false},
						{"text": "D. GET", "correct": true},
					],
					"correct_output": "GET retrieves data!",
					"error_output": "GET is used to retrieve resources.",
				},
			]
		},
		# ── Student 2: TIMED — HTML Documents ──
		{
			"student_index": 1, "timed": true, "time_limit": 45, "is_miniboss": false,
			"questions": [
				{
					"title": "Missing Tag",
					"type": "predict_output", "topic": "html",
					"file_name": "index.html", "timed": true, "time_limit": 45,
					"code_lines": ["<html>", "<body>", "  <h1>Title</h>", "</body>", "</html>"],
					"mission_steps": ["What is wrong with line 3?"],
					"options": [
						{"text": "A. Should be </h1>", "correct": true},
						{"text": "B. Should be </h2>", "correct": false},
						{"text": "C. Missing src attribute", "correct": false},
						{"text": "D. Nothing is wrong", "correct": false},
					],
					"correct_output": "Correct! Closing tags must match.",
					"error_output": "The closing tag must match the opening tag.",
				},
				{
					"title": "Anchor Tag",
					"type": "predict_output", "topic": "html",
					"file_name": "index.html", "timed": true, "time_limit": 45,
					"code_lines": ["<a ___=\"https://google.com\">Click</a>"],
					"mission_steps": ["What attribute goes in the blank?"],
					"options": [
						{"text": "A. src", "correct": false},
						{"text": "B. href", "correct": true},
						{"text": "C. link", "correct": false},
						{"text": "D. url", "correct": false},
					],
					"correct_output": "href is for hyperlinks!",
					"error_output": "Anchor tags use href for links.",
				},
				{
					"title": "Image Tag",
					"type": "predict_output", "topic": "html",
					"file_name": "index.html", "timed": true, "time_limit": 45,
					"code_lines": ["<img ___=\"photo.png\" alt=\"A photo\">"],
					"mission_steps": ["What attribute loads the image?"],
					"options": [
						{"text": "A. href", "correct": false},
						{"text": "B. link", "correct": false},
						{"text": "C. src", "correct": true},
						{"text": "D. file", "correct": false},
					],
					"correct_output": "src loads the image source!",
					"error_output": "Images use the src attribute.",
				},
				{
					"title": "Heading Hierarchy",
					"type": "predict_output", "topic": "html",
					"file_name": "index.html", "timed": true, "time_limit": 45,
					"code_lines": ["# Which is the LARGEST heading?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. <h6>", "correct": false},
						{"text": "B. <h3>", "correct": false},
						{"text": "C. <h1>", "correct": true},
						{"text": "D. <h4>", "correct": false},
					],
					"correct_output": "<h1> is the largest heading!",
					"error_output": "h1 is the biggest, h6 is the smallest.",
				},
				{
					"title": "Paragraph Tag",
					"type": "predict_output", "topic": "html",
					"file_name": "index.html", "timed": true, "time_limit": 45,
					"code_lines": ["# Which tag creates a paragraph of text?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. <text>", "correct": false},
						{"text": "B. <para>", "correct": false},
						{"text": "C. <div>", "correct": false},
						{"text": "D. <p>", "correct": true},
					],
					"correct_output": "<p> creates paragraphs!",
					"error_output": "The paragraph tag is <p>.",
				},
			]
		},
		# ── Student 3: Untimed — CSS Basics ──
		{
			"student_index": 2, "timed": false, "is_miniboss": false,
			"questions": [
				{
					"title": "CSS Selectors",
					"type": "predict_output", "topic": "css",
					"file_name": "style.css",
					"code_lines": ["# How do you select an element with class='header'?"],
					"mission_steps": ["Select the correct CSS selector."],
					"options": [
						{"text": "A. #header", "correct": false},
						{"text": "B. .header", "correct": true},
						{"text": "C. header", "correct": false},
						{"text": "D. @header", "correct": false},
					],
					"correct_output": ". selects classes!",
					"error_output": "Classes use the dot (.) selector.",
				},
				{
					"title": "ID Selector",
					"type": "predict_output", "topic": "css",
					"file_name": "style.css",
					"code_lines": ["# How do you select an element with id='main'?"],
					"mission_steps": ["Select the correct CSS selector."],
					"options": [
						{"text": "A. .main", "correct": false},
						{"text": "B. main", "correct": false},
						{"text": "C. #main", "correct": true},
						{"text": "D. *main", "correct": false},
					],
					"correct_output": "# selects IDs!",
					"error_output": "IDs use the hash (#) selector.",
				},
				{
					"title": "Padding vs Margin",
					"type": "predict_output", "topic": "css",
					"file_name": "style.css",
					"code_lines": ["# Which property adds space INSIDE the element border?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. margin", "correct": false},
						{"text": "B. padding", "correct": true},
						{"text": "C. border-spacing", "correct": false},
						{"text": "D. gap", "correct": false},
					],
					"correct_output": "Padding is inside the border!",
					"error_output": "Padding is space inside, margin is outside.",
				},
				{
					"title": "Color Values",
					"type": "predict_output", "topic": "css",
					"file_name": "style.css",
					"code_lines": ["color: #ff0000;"],
					"mission_steps": ["What color does this hex code produce?"],
					"options": [
						{"text": "A. Blue", "correct": false},
						{"text": "B. Green", "correct": false},
						{"text": "C. Red", "correct": true},
						{"text": "D. Yellow", "correct": false},
					],
					"correct_output": "#ff0000 is red!",
					"error_output": "#ff0000 = maximum red, no green, no blue.",
				},
				{
					"title": "Display Property",
					"type": "predict_output", "topic": "css",
					"file_name": "style.css",
					"code_lines": ["# Which display value makes items sit side by side?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. display: block", "correct": false},
						{"text": "B. display: none", "correct": false},
						{"text": "C. display: flex", "correct": true},
						{"text": "D. display: static", "correct": false},
					],
					"correct_output": "Flexbox arranges items in a row!",
					"error_output": "display: flex creates flexible layouts.",
				},
			]
		},
		# ── Student 4: TIMED — Flexbox ──
		{
			"student_index": 3, "timed": true, "time_limit": 45, "is_miniboss": false,
			"questions": [
				{
					"title": "Justify Content",
					"type": "predict_output", "topic": "css",
					"file_name": "style.css", "timed": true, "time_limit": 45,
					"code_lines": [".container {", "  display: flex;", "  justify-content: ___;", "}"],
					"mission_steps": ["Which value centers items horizontally?"],
					"options": [
						{"text": "A. flex-start", "correct": false},
						{"text": "B. space-between", "correct": false},
						{"text": "C. center", "correct": true},
						{"text": "D. flex-end", "correct": false},
					],
					"correct_output": "center aligns items to the middle!",
					"error_output": "justify-content: center centers horizontally.",
				},
				{
					"title": "Align Items",
					"type": "predict_output", "topic": "css",
					"file_name": "style.css", "timed": true, "time_limit": 45,
					"code_lines": ["# align-items controls which axis in a row layout?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. Horizontal (main axis)", "correct": false},
						{"text": "B. Vertical (cross axis)", "correct": true},
						{"text": "C. Z-axis (depth)", "correct": false},
						{"text": "D. It doesn't affect layout", "correct": false},
					],
					"correct_output": "align-items = cross axis!",
					"error_output": "align-items controls the cross axis.",
				},
				{
					"title": "Flex Direction",
					"type": "predict_output", "topic": "css",
					"file_name": "style.css", "timed": true, "time_limit": 45,
					"code_lines": ["# Which value stacks flex items vertically?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. flex-direction: row", "correct": false},
						{"text": "B. flex-direction: column", "correct": true},
						{"text": "C. flex-direction: wrap", "correct": false},
						{"text": "D. flex-direction: inline", "correct": false},
					],
					"correct_output": "column stacks vertically!",
					"error_output": "flex-direction: column stacks top to bottom.",
				},
				{
					"title": "Space Between",
					"type": "predict_output", "topic": "css",
					"file_name": "style.css", "timed": true, "time_limit": 45,
					"code_lines": ["# justify-content: space-between does what?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. Centers all items", "correct": false},
						{"text": "B. Puts equal space between items", "correct": true},
						{"text": "C. Removes all spacing", "correct": false},
						{"text": "D. Wraps items to next line", "correct": false},
					],
					"correct_output": "Items spread with equal gaps!",
					"error_output": "space-between distributes items evenly.",
				},
				{
					"title": "Flex Wrap",
					"type": "predict_output", "topic": "css",
					"file_name": "style.css", "timed": true, "time_limit": 45,
					"code_lines": ["# What property allows flex items to wrap to the next line?"],
					"mission_steps": ["Select the correct answer."],
					"options": [
						{"text": "A. flex-wrap: wrap", "correct": true},
						{"text": "B. flex-flow: break", "correct": false},
						{"text": "C. overflow: wrap", "correct": false},
						{"text": "D. display: wrap", "correct": false},
					],
					"correct_output": "flex-wrap: wrap allows wrapping!",
					"error_output": "Use flex-wrap: wrap for multiline flex.",
				},
			]
		},
		# ── Student 5: MINI-BOSS — Debug responsive meta tag ──
		{
			"student_index": 4, "timed": false, "is_miniboss": true,
			"questions": [
				{
					"title": "Fix the Responsive Page",
					"id": "markup_miniboss_meta",
					"type": "free_type", "topic": "html",
					"file_name": "index.html",
					"code_lines": [
						"<!DOCTYPE html>",
						"<html>",
						"<head>",
						"  <title>My Site</title>",
						"  <!-- The page is not responsive on mobile! -->",
						"  <!-- Add the viewport meta tag below -->",
						"</head>",
						"<body>",
						"  <h1>Welcome</h1>",
						"</body>",
						"</html>",
					],
					"starter_code": "",
					"mission_steps": [
						"This page doesn't scale on mobile devices.",
						"Add the viewport meta tag inside <head> to fix it.",
						"Type the full <meta> tag with viewport content.",
					],
					"correct_answer": '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
					"accept_patterns": ["meta", "viewport", "width=device-width"],
					"correct_output": "Page is now responsive!",
					"error_output": "Missing viewport meta tag.",
				},
			]
		},
	]

# ═══════════════════════════════════════════════════════════════════════════════
# PROFESSOR SYNTAX (Y1S2) — Python & Networking
# ═══════════════════════════════════════════════════════════════════════════════
static func _syntax_challenges() -> Array:
	return [
		{"student_index": 0, "timed": false, "is_miniboss": false, "questions": [
			{"title": "Variable Assignment", "type": "predict_output", "topic": "python", "file_name": "main.py", "code_lines": ["x = 10", "print(x)"], "mission_steps": ["What is the output?"], "options": [{"text": "A. 10", "correct": true}, {"text": "B. x", "correct": false}, {"text": "C. Error", "correct": false}, {"text": "D. None", "correct": false}], "correct_output": "10", "error_output": "x holds the value 10."},
			{"title": "List Indexing", "type": "predict_output", "topic": "python", "file_name": "main.py", "code_lines": ["fruits = ['apple', 'banana', 'cherry']", "print(fruits[1])"], "mission_steps": ["What is the output?"], "options": [{"text": "A. apple", "correct": false}, {"text": "B. banana", "correct": true}, {"text": "C. cherry", "correct": false}, {"text": "D. Error", "correct": false}], "correct_output": "banana", "error_output": "Lists are zero-indexed. Index 1 = banana."},
			{"title": "Dictionary Access", "type": "predict_output", "topic": "python", "file_name": "main.py", "code_lines": ["user = {'name': 'Alex', 'age': 20}", "print(user['name'])"], "mission_steps": ["What is the output?"], "options": [{"text": "A. Alex", "correct": true}, {"text": "B. name", "correct": false}, {"text": "C. 20", "correct": false}, {"text": "D. Error", "correct": false}], "correct_output": "Alex", "error_output": "Dictionary keys access their values."},
			{"title": "String Concatenation", "type": "predict_output", "topic": "python", "file_name": "main.py", "code_lines": ["a = 'Hello'", "b = 'World'", "print(a + ' ' + b)"], "mission_steps": ["What is the output?"], "options": [{"text": "A. HelloWorld", "correct": false}, {"text": "B. Hello World", "correct": true}, {"text": "C. Error", "correct": false}, {"text": "D. Hello+World", "correct": false}], "correct_output": "Hello World", "error_output": "The + operator concatenates strings."},
			{"title": "Type Function", "type": "predict_output", "topic": "python", "file_name": "main.py", "code_lines": ["x = 3.14", "print(type(x))"], "mission_steps": ["What type is x?"], "options": [{"text": "A. int", "correct": false}, {"text": "B. str", "correct": false}, {"text": "C. float", "correct": true}, {"text": "D. double", "correct": false}], "correct_output": "<class 'float'>", "error_output": "3.14 is a float."},
		]},
		{"student_index": 1, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "For Loop Output", "type": "predict_output", "topic": "python", "file_name": "main.py", "timed": true, "time_limit": 45, "code_lines": ["for i in range(3):", "    print(i)"], "mission_steps": ["What numbers are printed?"], "options": [{"text": "A. 1 2 3", "correct": false}, {"text": "B. 0 1 2", "correct": true}, {"text": "C. 0 1 2 3", "correct": false}, {"text": "D. Error", "correct": false}], "correct_output": "0 1 2", "error_output": "range(3) produces 0, 1, 2."},
			{"title": "While Loop", "type": "predict_output", "topic": "python", "file_name": "main.py", "timed": true, "time_limit": 45, "code_lines": ["x = 5", "while x > 3:", "    x -= 1", "print(x)"], "mission_steps": ["What is printed?"], "options": [{"text": "A. 5", "correct": false}, {"text": "B. 4", "correct": false}, {"text": "C. 3", "correct": true}, {"text": "D. 0", "correct": false}], "correct_output": "3", "error_output": "Loop stops when x is no longer > 3."},
			{"title": "If/Elif Chain", "type": "predict_output", "topic": "python", "file_name": "main.py", "timed": true, "time_limit": 45, "code_lines": ["grade = 85", "if grade >= 90:", "    print('A')", "elif grade >= 80:", "    print('B')", "else:", "    print('C')"], "mission_steps": ["What is printed?"], "options": [{"text": "A. A", "correct": false}, {"text": "B. B", "correct": true}, {"text": "C. C", "correct": false}, {"text": "D. Error", "correct": false}], "correct_output": "B", "error_output": "85 >= 80 is True, so B is printed."},
			{"title": "Boolean Logic", "type": "predict_output", "topic": "python", "file_name": "main.py", "timed": true, "time_limit": 45, "code_lines": ["x = True", "y = False", "print(x and y)"], "mission_steps": ["What is printed?"], "options": [{"text": "A. True", "correct": false}, {"text": "B. False", "correct": true}, {"text": "C. None", "correct": false}, {"text": "D. Error", "correct": false}], "correct_output": "False", "error_output": "True AND False = False."},
			{"title": "List Length", "type": "predict_output", "topic": "python", "file_name": "main.py", "timed": true, "time_limit": 45, "code_lines": ["items = [1, 2, 3, 4, 5]", "print(len(items))"], "mission_steps": ["What is printed?"], "options": [{"text": "A. 4", "correct": false}, {"text": "B. 5", "correct": true}, {"text": "C. 6", "correct": false}, {"text": "D. Error", "correct": false}], "correct_output": "5", "error_output": "len() counts elements."},
		]},
		{"student_index": 2, "timed": false, "is_miniboss": false, "questions": [
			{"title": "Class Definition", "type": "predict_output", "topic": "python", "file_name": "main.py", "code_lines": ["# What keyword defines a class in Python?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. def", "correct": false}, {"text": "B. class", "correct": true}, {"text": "C. struct", "correct": false}, {"text": "D. object", "correct": false}], "correct_output": "class defines a class!", "error_output": "Use the 'class' keyword."},
			{"title": "Init Method", "type": "predict_output", "topic": "python", "file_name": "main.py", "code_lines": ["# What is the constructor method called?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. __init__", "correct": true}, {"text": "B. __new__", "correct": false}, {"text": "C. __start__", "correct": false}, {"text": "D. __create__", "correct": false}], "correct_output": "__init__ is the constructor!", "error_output": "__init__ initializes objects."},
			{"title": "Self Parameter", "type": "predict_output", "topic": "python", "file_name": "main.py", "code_lines": ["# What does 'self' refer to in a class method?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. The class itself", "correct": false}, {"text": "B. The current instance", "correct": true}, {"text": "C. The parent class", "correct": false}, {"text": "D. Nothing specific", "correct": false}], "correct_output": "self = current instance!", "error_output": "self refers to the object instance."},
			{"title": "Inheritance", "type": "predict_output", "topic": "python", "file_name": "main.py", "code_lines": ["class Dog(Animal):"], "mission_steps": ["What does (Animal) mean?"], "options": [{"text": "A. Dog contains Animal", "correct": false}, {"text": "B. Dog inherits from Animal", "correct": true}, {"text": "C. Dog creates Animal", "correct": false}, {"text": "D. Dog is equal to Animal", "correct": false}], "correct_output": "Dog inherits Animal!", "error_output": "Parentheses indicate inheritance."},
			{"title": "Object Creation", "type": "predict_output", "topic": "python", "file_name": "main.py", "code_lines": ["# How do you create an instance of class Car?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Car.new()", "correct": false}, {"text": "B. new Car()", "correct": false}, {"text": "C. Car()", "correct": true}, {"text": "D. create Car", "correct": false}], "correct_output": "Call the class like a function!", "error_output": "In Python: my_car = Car()"},
		]},
		{"student_index": 3, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "GET Request", "type": "predict_output", "topic": "python", "file_name": "main.py", "timed": true, "time_limit": 45, "code_lines": ["# Which HTTP method retrieves data?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. POST", "correct": false}, {"text": "B. GET", "correct": true}, {"text": "C. PUT", "correct": false}, {"text": "D. PATCH", "correct": false}], "correct_output": "GET retrieves data!", "error_output": "GET is for reading."},
			{"title": "POST Request", "type": "predict_output", "topic": "python", "file_name": "main.py", "timed": true, "time_limit": 45, "code_lines": ["# Which HTTP method sends new data to the server?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. GET", "correct": false}, {"text": "B. DELETE", "correct": false}, {"text": "C. POST", "correct": true}, {"text": "D. HEAD", "correct": false}], "correct_output": "POST sends data!", "error_output": "POST creates new resources."},
			{"title": "Status 200", "type": "predict_output", "topic": "python", "file_name": "main.py", "timed": true, "time_limit": 45, "code_lines": ["# What does status code 200 mean?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Not Found", "correct": false}, {"text": "B. Server Error", "correct": false}, {"text": "C. OK / Success", "correct": true}, {"text": "D. Redirect", "correct": false}], "correct_output": "200 = OK!", "error_output": "200 means success."},
			{"title": "Status 500", "type": "predict_output", "topic": "python", "file_name": "main.py", "timed": true, "time_limit": 45, "code_lines": ["# What does status code 500 mean?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Client Error", "correct": false}, {"text": "B. Redirect", "correct": false}, {"text": "C. Not Found", "correct": false}, {"text": "D. Internal Server Error", "correct": true}], "correct_output": "500 = Server Error!", "error_output": "500 is a server-side error."},
			{"title": "DELETE Method", "type": "predict_output", "topic": "python", "file_name": "main.py", "timed": true, "time_limit": 45, "code_lines": ["# Which HTTP method removes a resource?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. POST", "correct": false}, {"text": "B. PUT", "correct": false}, {"text": "C. GET", "correct": false}, {"text": "D. DELETE", "correct": true}], "correct_output": "DELETE removes resources!", "error_output": "DELETE is for removal."},
		]},
		{"student_index": 4, "timed": false, "is_miniboss": true, "questions": [
			{"title": "Fix the Constructor", "id": "syntax_miniboss_init", "type": "free_type", "topic": "python", "file_name": "student.py", "code_lines": ["class Student:", "    def __init__(self):", "        # This student has no name!", "        # Add: self.name = name", "        pass"], "starter_code": "", "mission_steps": ["This class needs a name parameter.", "Fix __init__ to accept 'name' and store it as self.name."], "correct_answer": "self.name = name", "accept_patterns": ["self.name", "= name"], "correct_output": "Student now has a name!", "error_output": "Add self.name = name inside __init__."},
		]},
	]

# ═══════════════════════════════════════════════════════════════════════════════
# PROFESSOR VIEW (Y2S1) — Django Setup & Routing
# ═══════════════════════════════════════════════════════════════════════════════
static func _view_challenges() -> Array:
	return [
		{"student_index": 0, "timed": false, "is_miniboss": false, "questions": [
			{"title": "Virtual Environment", "type": "predict_output", "topic": "python", "file_name": "terminal", "code_lines": ["# What command creates a Python virtual environment?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. python -m venv myenv", "correct": true}, {"text": "B. pip install venv", "correct": false}, {"text": "C. django-admin venv", "correct": false}, {"text": "D. python create env", "correct": false}], "correct_output": "python -m venv!", "error_output": "Use python -m venv to create one."},
			{"title": "Install Django", "type": "predict_output", "topic": "python", "file_name": "terminal", "code_lines": ["# How do you install Django?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. npm install django", "correct": false}, {"text": "B. pip install django", "correct": true}, {"text": "C. apt-get django", "correct": false}, {"text": "D. python install django", "correct": false}], "correct_output": "pip install django!", "error_output": "pip is Python's package manager."},
			{"title": "Start Project", "type": "predict_output", "topic": "python", "file_name": "terminal", "code_lines": ["# Which command creates a new Django project?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. django-admin startproject mysite", "correct": true}, {"text": "B. django create project", "correct": false}, {"text": "C. python new project", "correct": false}, {"text": "D. pip create mysite", "correct": false}], "correct_output": "django-admin startproject!", "error_output": "Use django-admin startproject."},
			{"title": "Start App", "type": "predict_output", "topic": "python", "file_name": "terminal", "code_lines": ["# How do you create a new app inside a Django project?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. django-admin startapp blog", "correct": false}, {"text": "B. python manage.py startapp blog", "correct": true}, {"text": "C. pip install blog", "correct": false}, {"text": "D. python create app blog", "correct": false}], "correct_output": "manage.py startapp!", "error_output": "Use manage.py startapp."},
			{"title": "Run Server", "type": "predict_output", "topic": "python", "file_name": "terminal", "code_lines": ["# Which command starts Django's development server?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. python manage.py runserver", "correct": true}, {"text": "B. django run", "correct": false}, {"text": "C. npm start", "correct": false}, {"text": "D. python server.py", "correct": false}], "correct_output": "runserver starts the dev server!", "error_output": "Use manage.py runserver."},
		]},
		{"student_index": 1, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "URL Mapping", "type": "predict_output", "topic": "python", "file_name": "urls.py", "timed": true, "time_limit": 45, "code_lines": ["# path('about/', views.___, name='about')"], "mission_steps": ["Which view function should go here?"], "options": [{"text": "A. about_page", "correct": true}, {"text": "B. home_page", "correct": false}, {"text": "C. index", "correct": false}, {"text": "D. main", "correct": false}], "correct_output": "about_page matches /about/!", "error_output": "URL path names should match the view."},
			{"title": "View Return", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["def home(request):", "    return ___('home.html')"], "mission_steps": ["What function renders an HTML template?"], "options": [{"text": "A. HttpResponse", "correct": false}, {"text": "B. render", "correct": true}, {"text": "C. redirect", "correct": false}, {"text": "D. template", "correct": false}], "correct_output": "render() renders templates!", "error_output": "render(request, template) is the standard."},
			{"title": "Include URLs", "type": "predict_output", "topic": "python", "file_name": "urls.py", "timed": true, "time_limit": 45, "code_lines": ["# How do you include an app's URLs in the project?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. path('blog/', include('blog.urls'))", "correct": true}, {"text": "B. path('blog/', blog.urls)", "correct": false}, {"text": "C. import blog.urls", "correct": false}, {"text": "D. url('blog/', blog)", "correct": false}], "correct_output": "include() connects app URLs!", "error_output": "Use include('app.urls')."},
			{"title": "Request Object", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["# Every Django view receives which parameter?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. response", "correct": false}, {"text": "B. context", "correct": false}, {"text": "C. request", "correct": true}, {"text": "D. self", "correct": false}], "correct_output": "Views always get request!", "error_output": "The first parameter is always request."},
			{"title": "Template Folder", "type": "predict_output", "topic": "python", "file_name": "settings.py", "timed": true, "time_limit": 45, "code_lines": ["# Where does Django look for templates by default?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. static/", "correct": false}, {"text": "B. templates/", "correct": true}, {"text": "C. views/", "correct": false}, {"text": "D. html/", "correct": false}], "correct_output": "templates/ folder!", "error_output": "Django looks in templates/ by default."},
		]},
		{"student_index": 2, "timed": false, "is_miniboss": false, "questions": [
			{"title": "Template Variable", "type": "predict_output", "topic": "django", "file_name": "home.html", "code_lines": ["<h1>{{ title }}</h1>"], "mission_steps": ["What does {{ title }} do?"], "options": [{"text": "A. Displays the variable 'title'", "correct": true}, {"text": "B. Creates a title tag", "correct": false}, {"text": "C. Runs Python code", "correct": false}, {"text": "D. Nothing", "correct": false}], "correct_output": "{{ }} outputs variables!", "error_output": "Double curly braces output template variables."},
			{"title": "Template Tag", "type": "predict_output", "topic": "django", "file_name": "base.html", "code_lines": ["{% block content %}{% endblock %}"], "mission_steps": ["What does this do?"], "options": [{"text": "A. Defines a replaceable section", "correct": true}, {"text": "B. Creates a div", "correct": false}, {"text": "C. Imports CSS", "correct": false}, {"text": "D. Loops over data", "correct": false}], "correct_output": "Blocks define overridable sections!", "error_output": "{% block %} creates template inheritance slots."},
			{"title": "For Loop in Template", "type": "predict_output", "topic": "django", "file_name": "list.html", "code_lines": ["{% for item in items %}", "  <li>{{ item }}</li>", "{% endfor %}"], "mission_steps": ["What does this render?"], "options": [{"text": "A. A list of items", "correct": true}, {"text": "B. A single item", "correct": false}, {"text": "C. An error", "correct": false}, {"text": "D. An empty page", "correct": false}], "correct_output": "It renders each item as a list!", "error_output": "{% for %} loops through template data."},
			{"title": "Extends Tag", "type": "predict_output", "topic": "django", "file_name": "child.html", "code_lines": ["{% extends 'base.html' %}"], "mission_steps": ["What does extends do?"], "options": [{"text": "A. Inherits from base.html", "correct": true}, {"text": "B. Imports base.html as CSS", "correct": false}, {"text": "C. Deletes base.html", "correct": false}, {"text": "D. Redirects to base.html", "correct": false}], "correct_output": "extends inherits the parent template!", "error_output": "{% extends %} enables template inheritance."},
			{"title": "If Tag", "type": "predict_output", "topic": "django", "file_name": "page.html", "code_lines": ["{% if user.is_authenticated %}", "  <p>Welcome!</p>", "{% endif %}"], "mission_steps": ["When does 'Welcome!' appear?"], "options": [{"text": "A. Always", "correct": false}, {"text": "B. Only if user is logged in", "correct": true}, {"text": "C. Never", "correct": false}, {"text": "D. Only on mobile", "correct": false}], "correct_output": "Shows only for logged-in users!", "error_output": "{% if %} checks conditions in templates."},
		]},
		{"student_index": 3, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "Load Static", "type": "predict_output", "topic": "django", "file_name": "base.html", "timed": true, "time_limit": 45, "code_lines": ["# What tag loads static files in Django templates?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. {% load static %}", "correct": true}, {"text": "B. {% import static %}", "correct": false}, {"text": "C. {{ static }}", "correct": false}, {"text": "D. {% use static %}", "correct": false}], "correct_output": "{% load static %}!", "error_output": "Use {% load static %} at the top of templates."},
			{"title": "Static File Path", "type": "predict_output", "topic": "django", "file_name": "base.html", "timed": true, "time_limit": 45, "code_lines": ["<link rel='stylesheet' href=\"{% static '___.css' %}\">"], "mission_steps": ["What folder contains CSS files?"], "options": [{"text": "A. templates/style", "correct": false}, {"text": "B. static/css/style", "correct": true}, {"text": "C. media/style", "correct": false}, {"text": "D. assets/style", "correct": false}], "correct_output": "CSS lives in static/css/!", "error_output": "Static files go in the static/ directory."},
			{"title": "STATICFILES_DIRS", "type": "predict_output", "topic": "python", "file_name": "settings.py", "timed": true, "time_limit": 45, "code_lines": ["# Where do you configure extra static file directories?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. STATICFILES_DIRS", "correct": true}, {"text": "B. STATIC_ROOT", "correct": false}, {"text": "C. MEDIA_URL", "correct": false}, {"text": "D. TEMPLATE_DIRS", "correct": false}], "correct_output": "STATICFILES_DIRS!", "error_output": "STATICFILES_DIRS lists additional static dirs."},
			{"title": "Static URL", "type": "predict_output", "topic": "python", "file_name": "settings.py", "timed": true, "time_limit": 45, "code_lines": ["STATIC_URL = '/static/'"], "mission_steps": ["What does STATIC_URL define?"], "options": [{"text": "A. Where static files are stored on disk", "correct": false}, {"text": "B. The URL prefix for static files", "correct": true}, {"text": "C. The upload directory", "correct": false}, {"text": "D. The template directory", "correct": false}], "correct_output": "It's the URL prefix!", "error_output": "STATIC_URL is the web path prefix."},
			{"title": "Collectstatic", "type": "predict_output", "topic": "python", "file_name": "terminal", "timed": true, "time_limit": 45, "code_lines": ["# What command gathers static files for production?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. python manage.py collectstatic", "correct": true}, {"text": "B. python manage.py migrate", "correct": false}, {"text": "C. django collect", "correct": false}, {"text": "D. pip static", "correct": false}], "correct_output": "collectstatic gathers files!", "error_output": "Use collectstatic for production deployment."},
		]},
		{"student_index": 4, "timed": false, "is_miniboss": true, "questions": [
			{"title": "Fix the View Function", "id": "view_miniboss_request", "type": "free_type", "topic": "python", "file_name": "views.py", "code_lines": ["from django.shortcuts import render", "", "def my_view():", "    return render(request, 'home.html')"], "starter_code": "", "mission_steps": ["This view crashes because it's missing a parameter.", "Add the missing 'request' parameter to def my_view()."], "correct_answer": "def my_view(request):", "accept_patterns": ["def my_view(request)"], "correct_output": "View now accepts the request!", "error_output": "Views need the request parameter."},
		]},
	]

# ═══════════════════════════════════════════════════════════════════════════════
# PROFESSOR QUERY (Y2S2) — Databases & Models
# ═══════════════════════════════════════════════════════════════════════════════
static func _query_challenges() -> Array:
	return [
		{"student_index": 0, "timed": false, "is_miniboss": false, "questions": [
			{"title": "CharField", "type": "predict_output", "topic": "python", "file_name": "models.py", "code_lines": ["name = models.CharField(max_length=100)"], "mission_steps": ["What does CharField store?"], "options": [{"text": "A. Numbers", "correct": false}, {"text": "B. Text strings", "correct": true}, {"text": "C. Files", "correct": false}, {"text": "D. Booleans", "correct": false}], "correct_output": "CharField stores text!", "error_output": "CharField is for short text."},
			{"title": "IntegerField", "type": "predict_output", "topic": "python", "file_name": "models.py", "code_lines": ["age = models.IntegerField()"], "mission_steps": ["What does IntegerField store?"], "options": [{"text": "A. Decimal numbers", "correct": false}, {"text": "B. Text", "correct": false}, {"text": "C. Whole numbers", "correct": true}, {"text": "D. Dates", "correct": false}], "correct_output": "IntegerField stores whole numbers!", "error_output": "IntegerField = integers only."},
			{"title": "ForeignKey", "type": "predict_output", "topic": "python", "file_name": "models.py", "code_lines": ["author = models.ForeignKey(User, on_delete=models.CASCADE)"], "mission_steps": ["What relationship is this?"], "options": [{"text": "A. Many-to-Many", "correct": false}, {"text": "B. One-to-One", "correct": false}, {"text": "C. Many-to-One", "correct": true}, {"text": "D. No relationship", "correct": false}], "correct_output": "ForeignKey = Many-to-One!", "error_output": "ForeignKey creates a many-to-one link."},
			{"title": "On Delete", "type": "predict_output", "topic": "python", "file_name": "models.py", "code_lines": ["# What does on_delete=models.CASCADE do?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Deletes the parent too", "correct": false}, {"text": "B. Deletes related objects when parent is deleted", "correct": true}, {"text": "C. Prevents deletion", "correct": false}, {"text": "D. Sets field to NULL", "correct": false}], "correct_output": "CASCADE deletes related objects!", "error_output": "CASCADE = delete children when parent goes."},
			{"title": "BooleanField", "type": "predict_output", "topic": "python", "file_name": "models.py", "code_lines": ["is_active = models.BooleanField(default=True)"], "mission_steps": ["What values can this store?"], "options": [{"text": "A. True or False", "correct": true}, {"text": "B. 0 to 100", "correct": false}, {"text": "C. Any text", "correct": false}, {"text": "D. Dates", "correct": false}], "correct_output": "BooleanField = True/False!", "error_output": "BooleanField stores True or False."},
		]},
		{"student_index": 1, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "Makemigrations", "type": "predict_output", "topic": "python", "file_name": "terminal", "timed": true, "time_limit": 45, "code_lines": ["# What does 'makemigrations' do?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Applies changes to the database", "correct": false}, {"text": "B. Creates migration files from model changes", "correct": true}, {"text": "C. Deletes the database", "correct": false}, {"text": "D. Creates a new app", "correct": false}], "correct_output": "makemigrations creates migration files!", "error_output": "makemigrations detects model changes."},
			{"title": "Migrate", "type": "predict_output", "topic": "python", "file_name": "terminal", "timed": true, "time_limit": 45, "code_lines": ["# What does 'migrate' do?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Creates migration files", "correct": false}, {"text": "B. Applies migrations to the database", "correct": true}, {"text": "C. Starts the server", "correct": false}, {"text": "D. Installs Django", "correct": false}], "correct_output": "migrate applies changes!", "error_output": "migrate runs the SQL on the database."},
			{"title": "Migration Order", "type": "predict_output", "topic": "python", "file_name": "terminal", "timed": true, "time_limit": 45, "code_lines": ["# Which command runs FIRST?"], "mission_steps": ["Select the correct order."], "options": [{"text": "A. migrate then makemigrations", "correct": false}, {"text": "B. makemigrations then migrate", "correct": true}, {"text": "C. Only migrate is needed", "correct": false}, {"text": "D. Only makemigrations is needed", "correct": false}], "correct_output": "makemigrations THEN migrate!", "error_output": "Always makemigrations first."},
			{"title": "Show Migrations", "type": "predict_output", "topic": "python", "file_name": "terminal", "timed": true, "time_limit": 45, "code_lines": ["# How do you check which migrations have been applied?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. python manage.py showmigrations", "correct": true}, {"text": "B. python manage.py checkmigrations", "correct": false}, {"text": "C. python manage.py migrate --list", "correct": false}, {"text": "D. django showmigrations", "correct": false}], "correct_output": "showmigrations lists them!", "error_output": "Use showmigrations to see status."},
			{"title": "Squash Migrations", "type": "predict_output", "topic": "python", "file_name": "terminal", "timed": true, "time_limit": 45, "code_lines": ["# What happens if you delete a migration file?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Nothing", "correct": false}, {"text": "B. Database resets", "correct": false}, {"text": "C. Future migrations may fail", "correct": true}, {"text": "D. Django auto-regenerates it", "correct": false}], "correct_output": "Migrations can break!", "error_output": "Deleting migrations can cause dependency errors."},
		]},
		{"student_index": 2, "timed": false, "is_miniboss": false, "questions": [
			{"title": "Admin Registration", "type": "predict_output", "topic": "python", "file_name": "admin.py", "code_lines": ["# How do you register a model in the admin?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. admin.site.register(Post)", "correct": true}, {"text": "B. admin.add(Post)", "correct": false}, {"text": "C. Post.register()", "correct": false}, {"text": "D. models.register(Post)", "correct": false}], "correct_output": "admin.site.register()!", "error_output": "Use admin.site.register(Model)."},
			{"title": "Superuser", "type": "predict_output", "topic": "python", "file_name": "terminal", "code_lines": ["# How do you create an admin superuser?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. python manage.py createsuperuser", "correct": true}, {"text": "B. django-admin createuser", "correct": false}, {"text": "C. python manage.py addadmin", "correct": false}, {"text": "D. pip install superuser", "correct": false}], "correct_output": "createsuperuser!", "error_output": "Use manage.py createsuperuser."},
			{"title": "Admin URL", "type": "predict_output", "topic": "python", "file_name": "urls.py", "code_lines": ["# What URL loads the Django admin panel?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. /admin/", "correct": true}, {"text": "B. /dashboard/", "correct": false}, {"text": "C. /panel/", "correct": false}, {"text": "D. /manage/", "correct": false}], "correct_output": "/admin/ is the default!", "error_output": "Django admin lives at /admin/."},
			{"title": "List Display", "type": "predict_output", "topic": "python", "file_name": "admin.py", "code_lines": ["class PostAdmin(admin.ModelAdmin):", "    list_display = ['title', 'author']"], "mission_steps": ["What does list_display do?"], "options": [{"text": "A. Shows these fields in the admin list view", "correct": true}, {"text": "B. Creates new fields", "correct": false}, {"text": "C. Deletes fields", "correct": false}, {"text": "D. Hides fields from forms", "correct": false}], "correct_output": "list_display customizes the list!", "error_output": "list_display controls which columns show."},
			{"title": "Admin Auto", "type": "predict_output", "topic": "python", "file_name": "admin.py", "code_lines": ["# Does Django admin give you CRUD operations automatically?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Yes, once the model is registered", "correct": true}, {"text": "B. No, you must write each view", "correct": false}, {"text": "C. Only Read operations", "correct": false}, {"text": "D. Only after running a command", "correct": false}], "correct_output": "Admin provides full CRUD!", "error_output": "Registration gives you Create, Read, Update, Delete."},
		]},
		{"student_index": 3, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "All Objects", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["posts = Post.objects.all()"], "mission_steps": ["What does .all() return?"], "options": [{"text": "A. The first post", "correct": false}, {"text": "B. All Post objects", "correct": true}, {"text": "C. A count", "correct": false}, {"text": "D. An error", "correct": false}], "correct_output": ".all() returns everything!", "error_output": ".all() returns a QuerySet of all objects."},
			{"title": "Filter Objects", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["posts = Post.objects.filter(author='admin')"], "mission_steps": ["What does .filter() do?"], "options": [{"text": "A. Returns posts matching the condition", "correct": true}, {"text": "B. Deletes matching posts", "correct": false}, {"text": "C. Returns one post", "correct": false}, {"text": "D. Creates a new post", "correct": false}], "correct_output": ".filter() returns matching objects!", "error_output": ".filter() returns a filtered QuerySet."},
			{"title": "Get Object", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["post = Post.objects.get(id=1)"], "mission_steps": ["What does .get() return?"], "options": [{"text": "A. A QuerySet", "correct": false}, {"text": "B. Exactly one object", "correct": true}, {"text": "C. A list", "correct": false}, {"text": "D. None", "correct": false}], "correct_output": ".get() returns exactly one!", "error_output": ".get() returns a single object or raises an error."},
			{"title": "Create Object", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["Post.objects.create(title='New', author=user)"], "mission_steps": ["What does .create() do?"], "options": [{"text": "A. Makes and saves a new object", "correct": true}, {"text": "B. Just makes it in memory", "correct": false}, {"text": "C. Updates an existing object", "correct": false}, {"text": "D. Deletes an object", "correct": false}], "correct_output": ".create() makes AND saves!", "error_output": ".create() instantiates and saves in one step."},
			{"title": "Delete Object", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["post.delete()"], "mission_steps": ["What does .delete() do?"], "options": [{"text": "A. Removes from database", "correct": true}, {"text": "B. Hides it temporarily", "correct": false}, {"text": "C. Archives it", "correct": false}, {"text": "D. Sets it to None", "correct": false}], "correct_output": ".delete() removes from DB!", "error_output": ".delete() permanently removes the object."},
		]},
		{"student_index": 4, "timed": false, "is_miniboss": true, "questions": [
			{"title": "Write the QuerySet", "id": "query_miniboss_filter", "type": "free_type", "topic": "python", "file_name": "views.py", "code_lines": ["from django.contrib.auth.models import User", "", "# The intern needs to find the user named 'admin'", "# Write the QuerySet to get that user:"], "starter_code": "", "mission_steps": ["Write a QuerySet that retrieves the user with username='admin'."], "correct_answer": "User.objects.get(username='admin')", "accept_patterns": ["User.objects.get", "username", "admin"], "correct_output": "User found!", "error_output": "Use User.objects.get(username='admin')."},
		]},
	]

# ═══════════════════════════════════════════════════════════════════════════════
# PROFESSOR TOKEN (Y3S1) — Forms & CSRF
# ═══════════════════════════════════════════════════════════════════════════════
static func _token_challenges() -> Array:
	return [
		{"student_index": 0, "timed": false, "is_miniboss": false, "questions": [
			{"title": "CSRF Token", "type": "predict_output", "topic": "django", "file_name": "form.html", "code_lines": ["<form method='POST'>", "  {% csrf_token %}", "  <input name='data'>", "</form>"], "mission_steps": ["What does csrf_token protect against?"], "options": [{"text": "A. SQL Injection", "correct": false}, {"text": "B. Cross-Site Request Forgery", "correct": true}, {"text": "C. XSS", "correct": false}, {"text": "D. Brute Force", "correct": false}], "correct_output": "CSRF protection!", "error_output": "csrf_token prevents cross-site request forgery."},
			{"title": "Form Method", "type": "predict_output", "topic": "django", "file_name": "form.html", "code_lines": ["# Why use method='POST' for forms that change data?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. POST is faster", "correct": false}, {"text": "B. POST sends data in the body, not URL", "correct": true}, {"text": "C. GET doesn't work with forms", "correct": false}, {"text": "D. POST caches better", "correct": false}], "correct_output": "POST hides data from the URL!", "error_output": "POST puts data in the request body."},
			{"title": "ModelForm", "type": "predict_output", "topic": "python", "file_name": "forms.py", "code_lines": ["class PostForm(forms.ModelForm):", "    class Meta:", "        model = Post", "        fields = ['title', 'body']"], "mission_steps": ["What does ModelForm do?"], "options": [{"text": "A. Auto-generates a form from a model", "correct": true}, {"text": "B. Creates a new model", "correct": false}, {"text": "C. Deletes form data", "correct": false}, {"text": "D. Validates URLs", "correct": false}], "correct_output": "ModelForm auto-generates from the model!", "error_output": "ModelForm creates forms from models."},
			{"title": "is_valid()", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["if form.is_valid():", "    form.save()"], "mission_steps": ["What does is_valid() check?"], "options": [{"text": "A. If user is logged in", "correct": false}, {"text": "B. If all form fields pass validation", "correct": true}, {"text": "C. If the database is connected", "correct": false}, {"text": "D. If the template exists", "correct": false}], "correct_output": "is_valid() validates form data!", "error_output": "is_valid() checks all field constraints."},
			{"title": "POST Data", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["# How do you access submitted form data in a view?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. request.POST['field']", "correct": true}, {"text": "B. request.GET['field']", "correct": false}, {"text": "C. request.data['field']", "correct": false}, {"text": "D. form.data['field']", "correct": false}], "correct_output": "request.POST accesses form data!", "error_output": "POST data is in request.POST."},
		]},
		{"student_index": 1, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "Form Action", "type": "predict_output", "topic": "django", "file_name": "form.html", "timed": true, "time_limit": 45, "code_lines": ["<form action='{% url \"submit\" %}' method='POST'>"], "mission_steps": ["What does action='{% url ... %}' do?"], "options": [{"text": "A. Links to a named URL", "correct": true}, {"text": "B. Creates a new URL", "correct": false}, {"text": "C. Deletes the form", "correct": false}, {"text": "D. Refreshes the page", "correct": false}], "correct_output": "{% url %} resolves named URLs!", "error_output": "action points the form to a named route."},
			{"title": "Input Types", "type": "predict_output", "topic": "django", "file_name": "form.html", "timed": true, "time_limit": 45, "code_lines": ["<input type='email' name='user_email'>"], "mission_steps": ["What validation does type='email' add?"], "options": [{"text": "A. Checks for @ symbol", "correct": true}, {"text": "B. No validation", "correct": false}, {"text": "C. Password masking", "correct": false}, {"text": "D. File upload", "correct": false}], "correct_output": "type=email validates format!", "error_output": "email input checks for valid email format."},
			{"title": "Required Attr", "type": "predict_output", "topic": "django", "file_name": "form.html", "timed": true, "time_limit": 45, "code_lines": ["<input type='text' name='name' required>"], "mission_steps": ["What does 'required' do?"], "options": [{"text": "A. Makes the field optional", "correct": false}, {"text": "B. Prevents submission if empty", "correct": true}, {"text": "C. Hides the field", "correct": false}, {"text": "D. Auto-fills the field", "correct": false}], "correct_output": "required blocks empty submissions!", "error_output": "required prevents empty form submissions."},
			{"title": "Textarea", "type": "predict_output", "topic": "django", "file_name": "form.html", "timed": true, "time_limit": 45, "code_lines": ["# Which HTML element creates a multi-line text input?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. <input type='text'>", "correct": false}, {"text": "B. <textarea>", "correct": true}, {"text": "C. <p>", "correct": false}, {"text": "D. <div contenteditable>", "correct": false}], "correct_output": "<textarea> for multi-line!", "error_output": "Use <textarea> for multi-line input."},
			{"title": "Form Errors", "type": "predict_output", "topic": "django", "file_name": "form.html", "timed": true, "time_limit": 45, "code_lines": ["{{ form.errors }}"], "mission_steps": ["What does form.errors show?"], "options": [{"text": "A. Validation error messages", "correct": true}, {"text": "B. Server logs", "correct": false}, {"text": "C. Nothing", "correct": false}, {"text": "D. The form HTML", "correct": false}], "correct_output": "form.errors shows validation messages!", "error_output": "form.errors contains field validation errors."},
		]},
		{"student_index": 2, "timed": false, "is_miniboss": false, "questions": [
			{"title": "Secret Key", "type": "predict_output", "topic": "python", "file_name": "settings.py", "code_lines": ["SECRET_KEY = 'django-insecure-...'"], "mission_steps": ["Should this be shared publicly?"], "options": [{"text": "A. Yes, it's just a name", "correct": false}, {"text": "B. No, it must stay secret", "correct": true}, {"text": "C. It doesn't matter", "correct": false}, {"text": "D. Only share with teammates", "correct": false}], "correct_output": "SECRET_KEY must stay private!", "error_output": "Never commit SECRET_KEY to public repos."},
			{"title": "DEBUG Mode", "type": "predict_output", "topic": "python", "file_name": "settings.py", "code_lines": ["DEBUG = True"], "mission_steps": ["Should DEBUG be True in production?"], "options": [{"text": "A. Yes, for better logs", "correct": false}, {"text": "B. It doesn't matter", "correct": false}, {"text": "C. No, it exposes sensitive info", "correct": true}, {"text": "D. Always True", "correct": false}], "correct_output": "DEBUG = False in production!", "error_output": "DEBUG True exposes stack traces to attackers."},
			{"title": "Allowed Hosts", "type": "predict_output", "topic": "python", "file_name": "settings.py", "code_lines": ["ALLOWED_HOSTS = []"], "mission_steps": ["What must you add for production?"], "options": [{"text": "A. Your domain name", "correct": true}, {"text": "B. Nothing", "correct": false}, {"text": "C. 'localhost' only", "correct": false}, {"text": "D. '*' is safest", "correct": false}], "correct_output": "Add your domain to ALLOWED_HOSTS!", "error_output": "Specify your actual domain for security."},
			{"title": "HTTPS", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "code_lines": ["# Why is HTTPS important?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. It encrypts data in transit", "correct": true}, {"text": "B. It makes the site faster", "correct": false}, {"text": "C. It improves CSS rendering", "correct": false}, {"text": "D. It's only needed for APIs", "correct": false}], "correct_output": "HTTPS encrypts communication!", "error_output": "HTTPS prevents eavesdropping on data."},
			{"title": "SQL Injection", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "code_lines": ["# How does Django ORM prevent SQL injection?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. By parameterizing queries automatically", "correct": true}, {"text": "B. By blocking all SQL", "correct": false}, {"text": "C. By encrypting queries", "correct": false}, {"text": "D. It doesn't prevent it", "correct": false}], "correct_output": "ORM parameterizes queries!", "error_output": "Django ORM uses parameterized queries."},
		]},
		{"student_index": 3, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "Redirect", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["from django.shortcuts import redirect", "return redirect('home')"], "mission_steps": ["What does redirect() do?"], "options": [{"text": "A. Sends user to another URL", "correct": true}, {"text": "B. Renders a template", "correct": false}, {"text": "C. Deletes the session", "correct": false}, {"text": "D. Returns JSON", "correct": false}], "correct_output": "redirect() sends to another URL!", "error_output": "redirect() issues an HTTP redirect."},
			{"title": "Messages", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["from django.contrib import messages", "messages.success(request, 'Saved!')"], "mission_steps": ["What does messages framework do?"], "options": [{"text": "A. Shows flash messages to the user", "correct": true}, {"text": "B. Sends emails", "correct": false}, {"text": "C. Logs to a file", "correct": false}, {"text": "D. Creates database records", "correct": false}], "correct_output": "Messages shows flash notifications!", "error_output": "Messages framework displays one-time alerts."},
			{"title": "GET vs POST", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["if request.method == 'POST':"], "mission_steps": ["Why check request.method?"], "options": [{"text": "A. To handle form submissions vs page loads", "correct": true}, {"text": "B. To check if user is admin", "correct": false}, {"text": "C. To validate CSRF", "correct": false}, {"text": "D. To check the browser", "correct": false}], "correct_output": "Separate GET (show) from POST (submit)!", "error_output": "GET renders, POST processes."},
			{"title": "Sanitization", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "timed": true, "time_limit": 45, "code_lines": ["# Why sanitize user input?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. To prevent malicious code injection", "correct": true}, {"text": "B. To speed up the database", "correct": false}, {"text": "C. To reduce file size", "correct": false}, {"text": "D. It's not important", "correct": false}], "correct_output": "Sanitization prevents attacks!", "error_output": "Always sanitize to prevent XSS and injection."},
			{"title": "CSRF Exempt", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["@csrf_exempt", "def api_view(request):"], "mission_steps": ["What does @csrf_exempt do?"], "options": [{"text": "A. Disables CSRF checks for this view", "correct": true}, {"text": "B. Adds extra CSRF protection", "correct": false}, {"text": "C. Creates a new token", "correct": false}, {"text": "D. Blocks all POST requests", "correct": false}], "correct_output": "csrf_exempt skips CSRF check!", "error_output": "Use carefully — only for API endpoints."},
		]},
		{"student_index": 4, "timed": false, "is_miniboss": true, "questions": [
			{"title": "Add CSRF to the Form", "id": "token_miniboss_csrf", "type": "free_type", "topic": "django", "file_name": "form.html", "code_lines": ["<form method='POST'>", "  <!-- This form is missing CSRF protection! -->", "  <input type='text' name='title'>", "  <button type='submit'>Save</button>", "</form>"], "starter_code": "", "mission_steps": ["This form will be rejected by Django.", "Add the CSRF token tag in the right place."], "correct_answer": "{% csrf_token %}", "accept_patterns": ["csrf_token"], "correct_output": "Form is now protected!", "error_output": "Add {% csrf_token %} inside the form."},
		]},
	]

# ═══════════════════════════════════════════════════════════════════════════════
# PROFESSOR AUTH (Y3S2) — Authentication & CRUD
# ═══════════════════════════════════════════════════════════════════════════════
static func _auth_challenges() -> Array:
	return [
		{"student_index": 0, "timed": false, "is_miniboss": false, "questions": [
			{"title": "Login View", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["from django.contrib.auth import authenticate, login"], "mission_steps": ["What does authenticate() do?"], "options": [{"text": "A. Checks username and password", "correct": true}, {"text": "B. Creates a new user", "correct": false}, {"text": "C. Logs the user out", "correct": false}, {"text": "D. Resets the password", "correct": false}], "correct_output": "authenticate() verifies credentials!", "error_output": "authenticate() checks username/password."},
			{"title": "Login Required", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["@login_required", "def dashboard(request):"], "mission_steps": ["What does @login_required do?"], "options": [{"text": "A. Redirects to login if not authenticated", "correct": true}, {"text": "B. Creates a user account", "correct": false}, {"text": "C. Logs the user out", "correct": false}, {"text": "D. Shows an error page", "correct": false}], "correct_output": "login_required blocks anonymous users!", "error_output": "It redirects unauthenticated users to login."},
			{"title": "User Model", "type": "predict_output", "topic": "python", "file_name": "models.py", "code_lines": ["from django.contrib.auth.models import User"], "mission_steps": ["What does Django's User model provide?"], "options": [{"text": "A. Username, password, email built-in", "correct": true}, {"text": "B. Only username", "correct": false}, {"text": "C. Nothing, you build from scratch", "correct": false}, {"text": "D. Only email", "correct": false}], "correct_output": "User has username, password, email!", "error_output": "Django's User model is feature-complete."},
			{"title": "Logout", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["from django.contrib.auth import logout", "logout(request)"], "mission_steps": ["What does logout() do?"], "options": [{"text": "A. Clears the session and logs user out", "correct": true}, {"text": "B. Deletes the user account", "correct": false}, {"text": "C. Redirects to homepage", "correct": false}, {"text": "D. Nothing", "correct": false}], "correct_output": "logout() ends the session!", "error_output": "logout() clears the user's session."},
			{"title": "Session Auth", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "code_lines": ["# How does Django track logged-in users?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Session cookies", "correct": true}, {"text": "B. URL parameters", "correct": false}, {"text": "C. HTTP headers only", "correct": false}, {"text": "D. Local storage", "correct": false}], "correct_output": "Sessions use cookies!", "error_output": "Django uses session cookies for auth."},
		]},
		{"student_index": 1, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "Create View", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["# In CRUD, what does Create do?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Adds a new record", "correct": true}, {"text": "B. Reads a record", "correct": false}, {"text": "C. Removes a record", "correct": false}, {"text": "D. Modifies a record", "correct": false}], "correct_output": "Create = new record!", "error_output": "C in CRUD = Create."},
			{"title": "Read View", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["# In CRUD, what does Read do?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Adds data", "correct": false}, {"text": "B. Retrieves and displays data", "correct": true}, {"text": "C. Deletes data", "correct": false}, {"text": "D. Updates data", "correct": false}], "correct_output": "Read = retrieve data!", "error_output": "R in CRUD = Read."},
			{"title": "Update View", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["# In CRUD, what does Update do?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Creates new data", "correct": false}, {"text": "B. Deletes data", "correct": false}, {"text": "C. Modifies existing data", "correct": true}, {"text": "D. Reads data", "correct": false}], "correct_output": "Update = modify existing!", "error_output": "U in CRUD = Update."},
			{"title": "Delete Confirm", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["# Why show a confirmation page before DELETE?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. To prevent accidental deletion", "correct": true}, {"text": "B. It's required by Django", "correct": false}, {"text": "C. To log the action", "correct": false}, {"text": "D. It's just a convention", "correct": false}], "correct_output": "Confirmation prevents accidents!", "error_output": "Always confirm destructive actions."},
			{"title": "pk Parameter", "type": "predict_output", "topic": "python", "file_name": "urls.py", "timed": true, "time_limit": 45, "code_lines": ["path('post/<int:pk>/', views.post_detail)"], "mission_steps": ["What does <int:pk> capture?"], "options": [{"text": "A. The post's primary key as an integer", "correct": true}, {"text": "B. A string URL slug", "correct": false}, {"text": "C. The page number", "correct": false}, {"text": "D. The user ID", "correct": false}], "correct_output": "pk = primary key!", "error_output": "<int:pk> captures the object's ID."},
		]},
		{"student_index": 2, "timed": false, "is_miniboss": false, "questions": [
			{"title": "Permission Denied", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["# What status code is 'Forbidden'?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. 401", "correct": false}, {"text": "B. 403", "correct": true}, {"text": "C. 404", "correct": false}, {"text": "D. 500", "correct": false}], "correct_output": "403 = Forbidden!", "error_output": "403 means the server understood but refuses."},
			{"title": "Object Ownership", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["if post.author != request.user:", "    return HttpResponseForbidden()"], "mission_steps": ["What does this check?"], "options": [{"text": "A. That only the author can edit", "correct": true}, {"text": "B. That the post exists", "correct": false}, {"text": "C. That the user is admin", "correct": false}, {"text": "D. That the user is logged in", "correct": false}], "correct_output": "Only the author can modify!", "error_output": "This enforces object-level ownership."},
			{"title": "get_object_or_404", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["post = get_object_or_404(Post, pk=pk)"], "mission_steps": ["What happens if the post doesn't exist?"], "options": [{"text": "A. Returns None", "correct": false}, {"text": "B. Raises a 404 error", "correct": true}, {"text": "C. Creates a new post", "correct": false}, {"text": "D. Redirects to home", "correct": false}], "correct_output": "404 if not found!", "error_output": "get_object_or_404 raises Http404 if missing."},
			{"title": "UserCreationForm", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["from django.contrib.auth.forms import UserCreationForm"], "mission_steps": ["What does UserCreationForm provide?"], "options": [{"text": "A. A registration form with password validation", "correct": true}, {"text": "B. A login form", "correct": false}, {"text": "C. A password reset form", "correct": false}, {"text": "D. An admin form", "correct": false}], "correct_output": "Built-in registration form!", "error_output": "UserCreationForm handles signup with validation."},
			{"title": "Password Hashing", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "code_lines": ["# Does Django store passwords as plain text?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Yes", "correct": false}, {"text": "B. No, it hashes them", "correct": true}, {"text": "C. It encrypts them", "correct": false}, {"text": "D. It stores them in cookies", "correct": false}], "correct_output": "Django hashes passwords!", "error_output": "Passwords are hashed, never stored as plain text."},
		]},
		{"student_index": 3, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "Class-Based Views", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["class PostListView(ListView):", "    model = Post"], "mission_steps": ["What does ListView do?"], "options": [{"text": "A. Displays a list of objects", "correct": true}, {"text": "B. Creates objects", "correct": false}, {"text": "C. Deletes objects", "correct": false}, {"text": "D. Updates objects", "correct": false}], "correct_output": "ListView lists objects!", "error_output": "ListView renders a queryset as a template."},
			{"title": "DetailView", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["class PostDetailView(DetailView):", "    model = Post"], "mission_steps": ["What does DetailView do?"], "options": [{"text": "A. Shows a single object", "correct": true}, {"text": "B. Lists all objects", "correct": false}, {"text": "C. Edits an object", "correct": false}, {"text": "D. Deletes an object", "correct": false}], "correct_output": "DetailView shows one object!", "error_output": "DetailView renders a single object detail page."},
			{"title": "CreateView", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["class PostCreateView(CreateView):", "    model = Post", "    fields = ['title', 'body']"], "mission_steps": ["What does CreateView do?"], "options": [{"text": "A. Provides a form to create objects", "correct": true}, {"text": "B. Lists objects", "correct": false}, {"text": "C. Deletes objects", "correct": false}, {"text": "D. Updates objects", "correct": false}], "correct_output": "CreateView provides a creation form!", "error_output": "CreateView handles object creation."},
			{"title": "DeleteView", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["class PostDeleteView(DeleteView):", "    model = Post", "    success_url = '/'"], "mission_steps": ["What does success_url do?"], "options": [{"text": "A. Where to go after successful deletion", "correct": true}, {"text": "B. The URL of the delete form", "correct": false}, {"text": "C. The URL to cancel", "correct": false}, {"text": "D. The API endpoint", "correct": false}], "correct_output": "success_url redirects after delete!", "error_output": "success_url is the post-action redirect."},
			{"title": "Mixin", "type": "predict_output", "topic": "python", "file_name": "views.py", "timed": true, "time_limit": 45, "code_lines": ["class PostCreateView(LoginRequiredMixin, CreateView):"], "mission_steps": ["What does LoginRequiredMixin do?"], "options": [{"text": "A. Requires login for CBVs", "correct": true}, {"text": "B. Creates a login form", "correct": false}, {"text": "C. Logs the user out", "correct": false}, {"text": "D. Adds admin permissions", "correct": false}], "correct_output": "LoginRequiredMixin guards class-based views!", "error_output": "It's the CBV equivalent of @login_required."},
		]},
		{"student_index": 4, "timed": false, "is_miniboss": true, "questions": [
			{"title": "Fix the Login Check", "id": "auth_miniboss_login", "type": "free_type", "topic": "python", "file_name": "views.py", "code_lines": ["from django.contrib.auth import authenticate, login", "", "def login_view(request):", "    if request.method == 'POST':", "        username = request.POST['username']", "        password = request.POST['password']", "        # Authenticate the user below:"], "starter_code": "", "mission_steps": ["This login view doesn't authenticate anyone.", "Call authenticate() with the username and password."], "correct_answer": "user = authenticate(request, username=username, password=password)", "accept_patterns": ["authenticate", "username=username", "password=password"], "correct_output": "Authentication works!", "error_output": "Use authenticate(request, username=..., password=...)."},
		]},
	]

# ═══════════════════════════════════════════════════════════════════════════════
# PROFESSOR REST (Y3MID) — REST APIs
# ═══════════════════════════════════════════════════════════════════════════════
static func _rest_challenges() -> Array:
	return [
		{"student_index": 0, "timed": false, "is_miniboss": false, "questions": [
			{"title": "REST Meaning", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "code_lines": ["# What does REST stand for?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Representational State Transfer", "correct": true}, {"text": "B. Remote Server Technology", "correct": false}, {"text": "C. Request-Send-Transfer", "correct": false}, {"text": "D. Resource State Tracking", "correct": false}], "correct_output": "Representational State Transfer!", "error_output": "REST = Representational State Transfer."},
			{"title": "JSON Format", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "code_lines": ["# What data format do REST APIs typically use?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. XML", "correct": false}, {"text": "B. HTML", "correct": false}, {"text": "C. JSON", "correct": true}, {"text": "D. CSV", "correct": false}], "correct_output": "JSON is standard for APIs!", "error_output": "REST APIs typically use JSON."},
			{"title": "Serializer", "type": "predict_output", "topic": "python", "file_name": "serializers.py", "code_lines": ["class PostSerializer(serializers.ModelSerializer):", "    class Meta:", "        model = Post", "        fields = '__all__'"], "mission_steps": ["What does a serializer do?"], "options": [{"text": "A. Converts model data to JSON", "correct": true}, {"text": "B. Validates passwords", "correct": false}, {"text": "C. Creates database tables", "correct": false}, {"text": "D. Renders HTML templates", "correct": false}], "correct_output": "Serializers convert to JSON!", "error_output": "Serializers transform models to/from JSON."},
			{"title": "API Endpoint", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "code_lines": ["# What is an API endpoint?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. A URL that returns data", "correct": true}, {"text": "B. A database table", "correct": false}, {"text": "C. A frontend component", "correct": false}, {"text": "D. A CSS class", "correct": false}], "correct_output": "Endpoints are data URLs!", "error_output": "API endpoints are URLs that serve data."},
			{"title": "Status 201", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "code_lines": ["# What does HTTP status 201 mean?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. OK", "correct": false}, {"text": "B. Created", "correct": true}, {"text": "C. Not Found", "correct": false}, {"text": "D. Unauthorized", "correct": false}], "correct_output": "201 = Created!", "error_output": "201 means a new resource was created."},
		]},
		{"student_index": 1, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "GET /api/posts/", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "timed": true, "time_limit": 45, "code_lines": ["GET /api/posts/"], "mission_steps": ["What does this return?"], "options": [{"text": "A. All posts as JSON", "correct": true}, {"text": "B. A single post", "correct": false}, {"text": "C. Creates a post", "correct": false}, {"text": "D. Deletes all posts", "correct": false}], "correct_output": "GET /api/posts/ = list all!", "error_output": "GET on a collection returns all items."},
			{"title": "POST /api/posts/", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "timed": true, "time_limit": 45, "code_lines": ["POST /api/posts/"], "mission_steps": ["What does this do?"], "options": [{"text": "A. Lists posts", "correct": false}, {"text": "B. Creates a new post", "correct": true}, {"text": "C. Deletes a post", "correct": false}, {"text": "D. Updates a post", "correct": false}], "correct_output": "POST = create new!", "error_output": "POST on a collection creates a new item."},
			{"title": "PUT /api/posts/1/", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "timed": true, "time_limit": 45, "code_lines": ["PUT /api/posts/1/"], "mission_steps": ["What does this do?"], "options": [{"text": "A. Replaces post 1 entirely", "correct": true}, {"text": "B. Gets post 1", "correct": false}, {"text": "C. Deletes post 1", "correct": false}, {"text": "D. Creates post 1", "correct": false}], "correct_output": "PUT = full replacement!", "error_output": "PUT replaces the entire resource."},
			{"title": "DELETE /api/posts/1/", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "timed": true, "time_limit": 45, "code_lines": ["DELETE /api/posts/1/"], "mission_steps": ["What does this do?"], "options": [{"text": "A. Gets post 1", "correct": false}, {"text": "B. Updates post 1", "correct": false}, {"text": "C. Creates post 1", "correct": false}, {"text": "D. Removes post 1", "correct": true}], "correct_output": "DELETE = remove!", "error_output": "DELETE removes the specified resource."},
			{"title": "PATCH vs PUT", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "timed": true, "time_limit": 45, "code_lines": ["# What is the difference between PUT and PATCH?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. PUT replaces all, PATCH updates part", "correct": true}, {"text": "B. They are the same", "correct": false}, {"text": "C. PATCH replaces all, PUT updates part", "correct": false}, {"text": "D. Neither modifies data", "correct": false}], "correct_output": "PUT = full, PATCH = partial!", "error_output": "PUT is full replacement, PATCH is partial update."},
		]},
		{"student_index": 2, "timed": false, "is_miniboss": false, "questions": [
			{"title": "ViewSet", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["class PostViewSet(viewsets.ModelViewSet):", "    queryset = Post.objects.all()", "    serializer_class = PostSerializer"], "mission_steps": ["What does ModelViewSet provide?"], "options": [{"text": "A. Full CRUD API automatically", "correct": true}, {"text": "B. Only list view", "correct": false}, {"text": "C. Only create view", "correct": false}, {"text": "D. A login form", "correct": false}], "correct_output": "ModelViewSet = full CRUD API!", "error_output": "ModelViewSet provides list, create, update, delete."},
			{"title": "Router", "type": "predict_output", "topic": "python", "file_name": "urls.py", "code_lines": ["router = DefaultRouter()", "router.register('posts', PostViewSet)"], "mission_steps": ["What does the router do?"], "options": [{"text": "A. Auto-generates API URLs", "correct": true}, {"text": "B. Creates database tables", "correct": false}, {"text": "C. Validates data", "correct": false}, {"text": "D. Authenticates users", "correct": false}], "correct_output": "Router auto-generates URLs!", "error_output": "Routers map ViewSets to URL patterns."},
			{"title": "Authentication", "type": "predict_output", "topic": "python", "file_name": "settings.py", "code_lines": ["REST_FRAMEWORK = {", "    'DEFAULT_AUTHENTICATION_CLASSES': [", "        'rest_framework.authentication.TokenAuthentication',", "    ]", "}"], "mission_steps": ["What does TokenAuthentication do?"], "options": [{"text": "A. Uses API tokens to identify users", "correct": true}, {"text": "B. Uses cookies", "correct": false}, {"text": "C. Uses CSRF tokens", "correct": false}, {"text": "D. Uses passwords directly", "correct": false}], "correct_output": "API tokens authenticate requests!", "error_output": "TokenAuthentication uses bearer tokens."},
			{"title": "Permissions", "type": "predict_output", "topic": "python", "file_name": "views.py", "code_lines": ["permission_classes = [IsAuthenticated]"], "mission_steps": ["What does IsAuthenticated do?"], "options": [{"text": "A. Blocks anonymous API access", "correct": true}, {"text": "B. Allows anyone", "correct": false}, {"text": "C. Requires admin", "correct": false}, {"text": "D. Checks CORS", "correct": false}], "correct_output": "IsAuthenticated blocks anonymous!", "error_output": "Only authenticated users can access."},
			{"title": "CORS", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "code_lines": ["# What is CORS?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Cross-Origin Resource Sharing", "correct": true}, {"text": "B. Client-Origin Request System", "correct": false}, {"text": "C. A Python library", "correct": false}, {"text": "D. A database feature", "correct": false}], "correct_output": "Cross-Origin Resource Sharing!", "error_output": "CORS controls cross-domain access."},
		]},
		{"student_index": 3, "timed": true, "time_limit": 45, "is_miniboss": false, "questions": [
			{"title": "Pagination", "type": "predict_output", "topic": "python", "file_name": "settings.py", "timed": true, "time_limit": 45, "code_lines": ["'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination'"], "mission_steps": ["What does pagination do?"], "options": [{"text": "A. Limits results per page", "correct": true}, {"text": "B. Sorts results", "correct": false}, {"text": "C. Filters results", "correct": false}, {"text": "D. Caches results", "correct": false}], "correct_output": "Pagination limits per page!", "error_output": "Pagination splits large result sets."},
			{"title": "Throttling", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "timed": true, "time_limit": 45, "code_lines": ["# What is API throttling?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. Limiting request rate per user", "correct": true}, {"text": "B. Speeding up responses", "correct": false}, {"text": "C. Compressing data", "correct": false}, {"text": "D. Encrypting requests", "correct": false}], "correct_output": "Throttling limits request rate!", "error_output": "Throttling prevents API abuse."},
			{"title": "Content Type", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "timed": true, "time_limit": 45, "code_lines": ["# What Content-Type header is used for JSON?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. text/html", "correct": false}, {"text": "B. application/json", "correct": true}, {"text": "C. text/json", "correct": false}, {"text": "D. application/xml", "correct": false}], "correct_output": "application/json!", "error_output": "JSON uses application/json Content-Type."},
			{"title": "Browsable API", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "timed": true, "time_limit": 45, "code_lines": ["# What is DRF's browsable API?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. A web interface to test your API", "correct": true}, {"text": "B. A mobile app", "correct": false}, {"text": "C. A command-line tool", "correct": false}, {"text": "D. A database viewer", "correct": false}], "correct_output": "A web UI for testing APIs!", "error_output": "The browsable API lets you test endpoints in a browser."},
			{"title": "Versioning", "type": "predict_output", "topic": "python", "file_name": "concepts.txt", "timed": true, "time_limit": 45, "code_lines": ["# Why version your API (e.g., /api/v1/posts/)?"], "mission_steps": ["Select the correct answer."], "options": [{"text": "A. To maintain backward compatibility", "correct": true}, {"text": "B. To make URLs shorter", "correct": false}, {"text": "C. For SEO", "correct": false}, {"text": "D. It's not important", "correct": false}], "correct_output": "Versioning maintains compatibility!", "error_output": "API versioning prevents breaking old clients."},
		]},
		{"student_index": 4, "timed": false, "is_miniboss": true, "questions": [
			{"title": "Write the Serializer", "id": "rest_miniboss_serializer", "type": "free_type", "topic": "python", "file_name": "serializers.py", "code_lines": ["from rest_framework import serializers", "from .models import Post", "", "# Write a serializer for the Post model", "# It should include all fields"], "starter_code": "", "mission_steps": ["Create a PostSerializer using ModelSerializer.", "Include all fields from the Post model."], "correct_answer": "class PostSerializer(serializers.ModelSerializer):\n    class Meta:\n        model = Post\n        fields = '__all__'", "accept_patterns": ["PostSerializer", "ModelSerializer", "model = Post", "fields"], "correct_output": "Serializer is ready!", "error_output": "Use ModelSerializer with Meta class."},
		]},
	]
