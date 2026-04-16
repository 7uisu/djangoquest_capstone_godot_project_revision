# glossary_data.gd — Global autoload holding all Django / web dev glossary terms
# Add this to Project Settings → Autoloads as "GlossaryData"
extends Node

const TERMS: Dictionary = {
	# ── Python ──────────────────────────────────────────────────────────────
	"python": "A high-level, general-purpose programming language known for its simple, readable syntax. Django is built with Python.",
	"variable": "A named container that stores a value. In Python: `name = 'Django'`.",
	"function": "A reusable block of code defined with `def`. Example: `def greet(): print('Hello')`.",
	"loop": "A control structure that repeats code. Python has `for` and `while` loops.",
	"list": "An ordered, mutable collection in Python. Example: `[1, 2, 3]`.",
	"dictionary": "A collection of key-value pairs in Python. Example: `{'name': 'Django', 'version': 5}`.",
	"class": "A blueprint for creating objects. Defines attributes (data) and methods (behavior).",
	"import": "A statement that loads a module or library into your script. Example: `import os`.",

	# ── Django Core ──────────────────────────────────────────────────────────
	"django": "A high-level Python web framework that encourages rapid development and clean, pragmatic design. Created in 2003.",
	"framework": "A pre-built collection of code and conventions for building applications, so you don't write everything from scratch.",
	"mvt": "Model-View-Template — Django's architecture. Models handle data, Views handle logic, Templates handle presentation.",
	"model": "A Python class that defines the structure of a database table. Django creates the SQL for you automatically.",
	"view": "A Python function or class that receives a web request and returns a web response (usually an HTML page).",
	"template": "An HTML file with special Django tags (`{{ }}` and `{% %}`) to display dynamic data.",
	"url": "Uniform Resource Locator — the address of a web page. In Django, `urls.py` maps URLs to views.",
	"orm": "Object-Relational Mapper — Django's tool that lets you query the database using Python instead of raw SQL.",
	"migration": "A file that applies changes to the database schema. Run `python manage.py migrate` to apply them.",
	"admin": "Django's built-in web interface for managing your app's data without writing custom code.",
	"manage.py": "Django's command-line utility. Used to run the server, apply migrations, create apps, and more.",
	"settings.py": "The main configuration file for a Django project (database, installed apps, etc.).",
	"wsgi": "Web Server Gateway Interface — the standard interface between a Python web app and a web server.",
	"asgi": "Asynchronous Server Gateway Interface — like WSGI but supports async (real-time) features.",

	# ── Template Language ────────────────────────────────────────────────────
	"block": "A named section in a Django template that child templates can override. `{% block content %}{% endblock %}`.",
	"extends": "A Django tag that inherits from a parent template. `{% extends 'base.html' %}`.",
	"include": "A Django tag that inserts another template inside the current one. `{% include 'nav.html' %}`.",
	"static": "Files that don't change (CSS, JS, images). Load them with `{% load static %}` and `{% static 'file' %}`.",
	"context": "A dictionary of variables passed from a Django view to a template. `render(request, 'page.html', context)`.",
	"filter": "A Django template tool that modifies a variable's display. Example: `{{ name|upper }}` shows text in uppercase.",

	# ── Generic Views ────────────────────────────────────────────────────────
	"listview": "A Django Generic View that automatically fetches all objects from a model and passes them to a template.",
	"detailview": "A Django Generic View that fetches a single object by its primary key (pk) or slug.",
	"createview": "A Django Generic View that displays and processes a form to create a new model object.",
	"updateview": "A Django Generic View for editing an existing model object with a form.",
	"deleteview": "A Django Generic View for deleting a model object with a confirmation page.",

	# ── Web Basics ───────────────────────────────────────────────────────────
	"html": "HyperText Markup Language — the standard language for creating web pages.",
	"css": "Cascading Style Sheets — the language used to style HTML elements (colors, fonts, layouts).",
	"javascript": "A scripting language that makes web pages interactive (click events, animations, etc.).",
	"http": "HyperText Transfer Protocol — the communication protocol used to transfer data on the web.",
	"get": "An HTTP method used to request data from a server. Used when loading a page.",
	"post": "An HTTP method used to send data to a server. Used when submitting a form.",
	"api": "Application Programming Interface — a set of rules that lets two applications communicate.",
	"rest": "Representational State Transfer — an architecture style for building web APIs using HTTP methods.",
	"json": "JavaScript Object Notation — a lightweight text format for sending data between a server and a client.",
	"crud": "Create, Read, Update, Delete — the four basic operations of persistent storage. Django's ORM handles all four.",

	# ── Databases ────────────────────────────────────────────────────────────
	"database": "An organized collection of structured data, typically stored electronically in a computer system.",
	"sql": "Structured Query Language — the standard language for managing relational databases.",
	"sqlite": "A lightweight file-based database included with Python. Django uses it by default for development.",
	"postgresql": "A powerful, open-source relational database system. Recommended for Django in production.",
	"primary key": "A unique identifier for each row in a database table. In Django models, this is usually `id`.",
	"foreign key": "A field that links one model/table to another, creating a relationship. Example: a Post has a ForeignKey to Author.",

	# ── Virtual Environments ─────────────────────────────────────────────────
	"venv": "Virtual Environment — an isolated Python environment for a project, keeping its packages separate from global installs.",
	"pip": "Package Installer for Python — the command-line tool used to install Python libraries. Example: `pip install django`.",
}

func get_definition(term: String) -> String:
	var key = term.to_lower().strip_edges()
	return TERMS.get(key, "No definition found for '%s'." % term)

func has_term(term: String) -> bool:
	return TERMS.has(term.to_lower().strip_edges())

# ── Auto-link: wrap glossary terms in clickable [url] BBCode ─────────────────
# Handles BOTH plain text matches AND [b]bold[/b] terms on slides.
# Multiple terms per bullet are supported.
func auto_link(text: String) -> String:
	# Sort terms longer-first so "generic views" matches before "views"
	var term_list = TERMS.keys()
	term_list.sort_custom(func(a, b): return a.length() > b.length())

	for term in term_list:
		# Skip very short terms (3 chars or fewer) to avoid over-matching
		if term.length() < 4:
			continue

		# ── Pass 1: Replace [b]Term[/b] → [url=term][b][color=#e0c675]Term[/color][/b][/url]
		# This catches the bold keywords professors use on slides
		var lower_text = text.to_lower()
		var bold_open = "[b]"
		var bold_close = "[/b]"
		var search_start = 0
		while true:
			var bo = lower_text.find(bold_open, search_start)
			if bo < 0:
				break
			var bc = lower_text.find(bold_close, bo + bold_open.length())
			if bc < 0:
				break
			var inner_start = bo + bold_open.length()
			var inner = text.substr(inner_start, bc - inner_start)
			if inner.to_lower().strip_edges() == term:
				# Check not already wrapped in [url]
				var before_chunk = text.substr(0, bo)
				if before_chunk.ends_with("[url=" + term + "]") or "[url=" in text.substr(maxi(0, bo - 40), 40):
					search_start = bc + bold_close.length()
					lower_text = text.to_lower()
					continue
				var replacement = "[url=" + term + "][b][color=#e0c675]" + inner + "[/color][/b][/url]"
				text = text.substr(0, bo) + replacement + text.substr(bc + bold_close.length())
				lower_text = text.to_lower()
				search_start = bo + replacement.length()
				continue
			search_start = bc + bold_close.length()

		# ── Pass 2: Plain text matches (not inside any BBCode tag)
		lower_text = text.to_lower()
		var idx = lower_text.find(term)
		if idx >= 0:
			var before = text.substr(0, idx)
			# Skip if already inside a tag or already [url]-linked
			var open_brackets = before.count("[") - before.count("]")
			if open_brackets <= 0 and not "[url=" + term + "]" in before.substr(maxi(0, before.length() - 60)):
				var original = text.substr(idx, term.length())
				var link = "[url=%s][color=#e0c675]%s[/color][/url]" % [term, original]
				text = text.substr(0, idx) + link + text.substr(idx + term.length())

	return text

