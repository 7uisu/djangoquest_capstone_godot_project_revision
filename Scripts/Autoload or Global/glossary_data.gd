# glossary_data.gd — Global autoload holding all Django / web dev glossary terms
# Add this to Project Settings → Autoloads as "GlossaryData"
extends Node

# Each entry: { "def": "definition text", "src": "source URL" }
const TERMS: Dictionary = {
	# ── Python ──────────────────────────────────────────────────────────────
	"python": { "def": "A high-level, general-purpose programming language known for its simple, readable syntax. Django is built with Python.", "src": "https://docs.python.org/3/" },
	"variable": { "def": "A named container that stores a value. In Python: `name = 'Django'`.", "src": "https://docs.python.org/3/tutorial/introduction.html" },
	"function": { "def": "A reusable block of code defined with `def`. Example: `def greet(): print('Hello')`.", "src": "https://docs.python.org/3/tutorial/controlflow.html#defining-functions" },
	"loop": { "def": "A control structure that repeats code. Python has `for` and `while` loops.", "src": "https://docs.python.org/3/tutorial/controlflow.html" },
	"list": { "def": "An ordered, mutable collection in Python. Example: `[1, 2, 3]`.", "src": "https://docs.python.org/3/tutorial/datastructures.html" },
	"dictionary": { "def": "A collection of key-value pairs in Python. Example: `{'name': 'Django', 'version': 5}`.", "src": "https://docs.python.org/3/tutorial/datastructures.html#dictionaries" },
	"class": { "def": "A blueprint for creating objects. Defines attributes (data) and methods (behavior).", "src": "https://docs.python.org/3/tutorial/classes.html" },
	"import": { "def": "A statement that loads a module or library into your script. Example: `import os`.", "src": "https://docs.python.org/3/reference/import.html" },

	# ── Django Core ──────────────────────────────────────────────────────────
	"django": { "def": "A high-level Python web framework that encourages rapid development and clean, pragmatic design. Created in 2003.", "src": "https://docs.djangoproject.com/en/stable/" },
	"framework": { "def": "A pre-built collection of code and conventions for building applications, so you don't write everything from scratch.", "src": "https://developer.mozilla.org/en-US/docs/Learn/Server-side/First_steps/Web_frameworks" },
	"mvt": { "def": "Model-View-Template — Django's architecture. Models handle data, Views handle logic, Templates handle presentation.", "src": "https://docs.djangoproject.com/en/stable/faq/general/#django-appears-to-be-a-mvc-framework-but-you-call-the-controller-the-view-what-s-up-with-that" },
	"model": { "def": "A Python class that defines the structure of a database table. Django creates the SQL for you automatically.", "src": "https://docs.djangoproject.com/en/stable/topics/db/models/" },
	"view": { "def": "A Python function or class that receives a web request and returns a web response (usually an HTML page).", "src": "https://docs.djangoproject.com/en/stable/topics/http/views/" },
	"template": { "def": "An HTML file with special Django tags (`{{ }}` and `{% %}`) to display dynamic data.", "src": "https://docs.djangoproject.com/en/stable/topics/templates/" },
	"url": { "def": "Uniform Resource Locator — the address of a web page. In Django, `urls.py` maps URLs to views.", "src": "https://docs.djangoproject.com/en/stable/topics/http/urls/" },
	"orm": { "def": "Object-Relational Mapper — Django's tool that lets you query the database using Python instead of raw SQL.", "src": "https://docs.djangoproject.com/en/stable/topics/db/queries/" },
	"migration": { "def": "A file that applies changes to the database schema. Run `python manage.py migrate` to apply them.", "src": "https://docs.djangoproject.com/en/stable/topics/migrations/" },
	"admin": { "def": "Django's built-in web interface for managing your app's data without writing custom code.", "src": "https://docs.djangoproject.com/en/stable/ref/contrib/admin/" },
	"manage.py": { "def": "Django's command-line utility. Used to run the server, apply migrations, create apps, and more.", "src": "https://docs.djangoproject.com/en/stable/ref/django-admin/" },
	"settings.py": { "def": "The main configuration file for a Django project (database, installed apps, etc.).", "src": "https://docs.djangoproject.com/en/stable/topics/settings/" },
	"wsgi": { "def": "Web Server Gateway Interface — the standard interface between a Python web app and a web server.", "src": "https://docs.djangoproject.com/en/stable/howto/deployment/wsgi/" },
	"asgi": { "def": "Asynchronous Server Gateway Interface — like WSGI but supports async (real-time) features.", "src": "https://docs.djangoproject.com/en/stable/howto/deployment/asgi/" },

	# ── Template Language ────────────────────────────────────────────────────
	"block": { "def": "A named section in a Django template that child templates can override. `{% block content %}{% endblock %}`.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/builtins/#block" },
	"extends": { "def": "A Django tag that inherits from a parent template. `{% extends 'base.html' %}`.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/builtins/#extends" },
	"include": { "def": "A Django tag that inserts another template inside the current one. `{% include 'nav.html' %}`.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/builtins/#include" },
	"static": { "def": "Files that don't change (CSS, JS, images). Load them with `{% load static %}` and `{% static 'file' %}`.", "src": "https://docs.djangoproject.com/en/stable/howto/static-files/" },
	"context": { "def": "A dictionary of variables passed from a Django view to a template. `render(request, 'page.html', context)`.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/api/#playing-with-context" },
	"template filter": { "def": "A Django template tool that modifies a variable's display. Example: `{{ name|upper }}` shows text in uppercase.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/builtins/#built-in-filter-reference" },

	# ── Generic Views ────────────────────────────────────────────────────────
	"listview": { "def": "A Django Generic View that automatically fetches all objects from a model and passes them to a template.", "src": "https://docs.djangoproject.com/en/stable/ref/class-based-views/generic-display/#listview" },
	"detailview": { "def": "A Django Generic View that fetches a single object by its primary key (pk) or slug.", "src": "https://docs.djangoproject.com/en/stable/ref/class-based-views/generic-display/#detailview" },
	"createview": { "def": "A Django Generic View that displays and processes a form to create a new model object.", "src": "https://docs.djangoproject.com/en/stable/ref/class-based-views/generic-editing/#createview" },
	"updateview": { "def": "A Django Generic View for editing an existing model object with a form.", "src": "https://docs.djangoproject.com/en/stable/ref/class-based-views/generic-editing/#updateview" },
	"deleteview": { "def": "A Django Generic View for deleting a model object with a confirmation page.", "src": "https://docs.djangoproject.com/en/stable/ref/class-based-views/generic-editing/#deleteview" },

	# ── Web Basics ───────────────────────────────────────────────────────────
	"html": { "def": "HyperText Markup Language — the standard language for creating web pages.", "src": "https://developer.mozilla.org/en-US/docs/Web/HTML" },
	"css": { "def": "Cascading Style Sheets — the language used to style HTML elements (colors, fonts, layouts).", "src": "https://developer.mozilla.org/en-US/docs/Web/CSS" },
	"javascript": { "def": "A scripting language that makes web pages interactive (click events, animations, etc.).", "src": "https://developer.mozilla.org/en-US/docs/Web/JavaScript" },
	"http": { "def": "HyperText Transfer Protocol — the communication protocol used to transfer data on the web.", "src": "https://developer.mozilla.org/en-US/docs/Web/HTTP" },
	"get": { "def": "An HTTP method used to request data from a server. Used when loading a page.", "src": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/GET" },
	"post": { "def": "An HTTP method used to send data to a server. Used when submitting a form.", "src": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST" },
	"api": { "def": "Application Programming Interface — a set of rules that lets two applications communicate.", "src": "https://developer.mozilla.org/en-US/docs/Learn/JavaScript/Client-side_web_APIs/Introduction" },
	"rest": { "def": "Representational State Transfer — an architecture style for building web APIs using HTTP methods.", "src": "https://developer.mozilla.org/en-US/docs/Glossary/REST" },
	"json": { "def": "JavaScript Object Notation — a lightweight text format for sending data between a server and a client.", "src": "https://developer.mozilla.org/en-US/docs/Learn/JavaScript/Objects/JSON" },
	"crud": { "def": "Create, Read, Update, Delete — the four basic operations of persistent storage. Django's ORM handles all four.", "src": "https://developer.mozilla.org/en-US/docs/Glossary/CRUD" },

	# ── Databases ────────────────────────────────────────────────────────────
	"database": { "def": "An organized collection of structured data, typically stored electronically in a computer system.", "src": "https://docs.djangoproject.com/en/stable/ref/databases/" },
	"sql": { "def": "Structured Query Language — the standard language for managing relational databases.", "src": "https://developer.mozilla.org/en-US/docs/Glossary/SQL" },
	"sqlite": { "def": "A lightweight file-based database included with Python. Django uses it by default for development.", "src": "https://docs.djangoproject.com/en/stable/ref/databases/#sqlite-notes" },
	"postgresql": { "def": "A powerful, open-source relational database system. Recommended for Django in production.", "src": "https://docs.djangoproject.com/en/stable/ref/databases/#postgresql-notes" },
	"primary key": { "def": "A unique identifier for each row in a database table. In Django models, this is usually `id`.", "src": "https://docs.djangoproject.com/en/stable/topics/db/models/#automatic-primary-key-fields" },
	"foreign key": { "def": "A field that links one model/table to another, creating a relationship. Example: a Post has a ForeignKey to Author.", "src": "https://docs.djangoproject.com/en/stable/ref/models/fields/#foreignkey" },

	# ── Virtual Environments ─────────────────────────────────────────────────
	"venv": { "def": "Virtual Environment — an isolated Python environment for a project, keeping its packages separate from global installs.", "src": "https://docs.python.org/3/library/venv.html" },
	"pip": { "def": "Package Installer for Python — the command-line tool used to install Python libraries. Example: `pip install django`.", "src": "https://pip.pypa.io/en/stable/" },

	# ── Authentication (Prof Auth) ───────────────────────────────────────────
	"authentication": { "def": "The process of verifying that someone is who they claim to be — usually by checking a username and password.", "src": "https://docs.djangoproject.com/en/stable/topics/auth/" },
	"authenticate": { "def": "A Django function that checks if a username/password pair is valid. Returns a User object or None.", "src": "https://docs.djangoproject.com/en/stable/topics/auth/default/#authenticating-users" },
	"login": { "def": "A Django function that attaches a user to the current session, keeping them logged in across pages.", "src": "https://docs.djangoproject.com/en/stable/topics/auth/default/#how-to-log-a-user-in" },
	"logout": { "def": "A Django function that removes the current user from their session, requiring them to sign in again.", "src": "https://docs.djangoproject.com/en/stable/topics/auth/default/#how-to-log-a-user-out" },
	"permission": { "def": "A rule that controls what a user can and cannot do (e.g. add, change, or delete specific data).", "src": "https://docs.djangoproject.com/en/stable/topics/auth/default/#permissions-and-authorization" },
	"abstractuser": { "def": "A Django class you can extend to add custom fields (like bio or avatar) to the default User model.", "src": "https://docs.djangoproject.com/en/stable/topics/auth/customizing/#extending-the-existing-user-model" },
	"password hashing": { "def": "The process of converting a plain-text password into an unreadable scrambled string for secure storage.", "src": "https://docs.djangoproject.com/en/stable/topics/auth/passwords/" },
	"decorator": { "def": "A special `@` annotation placed above a function to modify its behavior — for example, `@login_required`.", "src": "https://docs.python.org/3/glossary.html#term-decorator" },
	"login_required": { "def": "A Django decorator that blocks access to a view unless the user is logged in.", "src": "https://docs.djangoproject.com/en/stable/topics/auth/default/#the-login-required-decorator" },
	"middleware": { "def": "Code that runs on every request/response — like a security checkpoint between the browser and your views.", "src": "https://docs.djangoproject.com/en/stable/topics/http/middleware/" },
	"session": { "def": "Server-side storage that remembers information about a user (like their login status) between page loads.", "src": "https://docs.djangoproject.com/en/stable/topics/http/sessions/" },
	"superuser": { "def": "A special Django user with all permissions enabled. Created with `python manage.py createsuperuser`.", "src": "https://docs.djangoproject.com/en/stable/ref/django-admin/#createsuperuser" },

	# ── Python Syntax (Prof Syntax) ──────────────────────────────────────────
	"__init__": { "def": "A special Python method that runs automatically when you create a new object from a class. Also called the constructor.", "src": "https://docs.python.org/3/reference/datamodel.html#object.__init__" },
	"self": { "def": "A Python keyword that refers to the current instance of a class — used to access its attributes and methods.", "src": "https://docs.python.org/3/tutorial/classes.html#class-objects" },
	"conditional": { "def": "A decision-making structure: `if`, `elif`, `else`. Runs different code depending on whether a condition is true.", "src": "https://docs.python.org/3/tutorial/controlflow.html#if-statements" },
	"inheritance": { "def": "When a class is based on another class, it inherits all its attributes and methods. Example: `class Dog(Animal):`.", "src": "https://docs.python.org/3/tutorial/classes.html#inheritance" },
	"constructor": { "def": "A method that initializes a new object. In Python, this is the `__init__` method.", "src": "https://docs.python.org/3/reference/datamodel.html#object.__init__" },
	"object": { "def": "An individual instance created from a class. Example: `my_dog = Dog()` — `my_dog` is an object.", "src": "https://docs.python.org/3/tutorial/classes.html#class-objects" },
	"exception": { "def": "An error that occurs during program execution. Python uses `try/except` blocks to handle them gracefully.", "src": "https://docs.python.org/3/tutorial/errors.html" },
	"try/except": { "def": "A Python structure for handling errors. Code in `try` runs first; if it fails, the `except` block catches the error.", "src": "https://docs.python.org/3/tutorial/errors.html#handling-exceptions" },
	"requests": { "def": "A popular Python library for making HTTP requests to web servers. Example: `requests.get('https://api.example.com')`.", "src": "https://docs.python-requests.org/en/latest/" },
	"parameter": { "def": "A variable listed inside a function definition that receives a value when the function is called.", "src": "https://docs.python.org/3/glossary.html#term-parameter" },
	"return": { "def": "A keyword that sends a value back from a function to the code that called it.", "src": "https://docs.python.org/3/reference/simple_stmts.html#the-return-statement" },
	"boolean": { "def": "A data type with only two values: `True` or `False`. Used in conditions and comparisons.", "src": "https://docs.python.org/3/library/stdtypes.html#boolean-type-bool" },
	"string": { "def": "A sequence of characters (text) in Python, enclosed in quotes. Example: `'Hello, World!'`.", "src": "https://docs.python.org/3/library/stdtypes.html#text-sequence-type-str" },
	"integer": { "def": "A whole number without decimals. Example: `42`, `-7`, `0`.", "src": "https://docs.python.org/3/library/stdtypes.html#numeric-types-int-float-complex" },

	# ── Forms & CSRF (Prof Token) ────────────────────────────────────────────
	"form": { "def": "A Django class that generates HTML form fields and handles user input validation automatically.", "src": "https://docs.djangoproject.com/en/stable/topics/forms/" },
	"modelform": { "def": "A special Django form that is built directly from a Model — it creates form fields matching your database columns.", "src": "https://docs.djangoproject.com/en/stable/topics/forms/modelforms/" },
	"csrf": { "def": "Cross-Site Request Forgery — an attack where a malicious site tricks a user's browser into submitting a form on another site.", "src": "https://docs.djangoproject.com/en/stable/ref/csrf/" },
	"csrf_token": { "def": "A unique secret value Django puts in every form to verify that the submission came from your own site, not an attacker.", "src": "https://docs.djangoproject.com/en/stable/ref/csrf/#how-it-works" },
	"validation": { "def": "The process of checking that form data is correct (e.g. an email field actually contains a valid email address).", "src": "https://docs.djangoproject.com/en/stable/ref/forms/validation/" },
	"widget": { "def": "A Django form component that controls how a field is displayed in HTML (e.g. text input, dropdown, checkbox).", "src": "https://docs.djangoproject.com/en/stable/ref/forms/widgets/" },
	"charfield": { "def": "A Django model/form field that stores short text strings. Requires a `max_length` in models.", "src": "https://docs.djangoproject.com/en/stable/ref/models/fields/#charfield" },
	"cleaned_data": { "def": "A dictionary of validated form data in Django. Accessed after calling `form.is_valid()` to get safe user input.", "src": "https://docs.djangoproject.com/en/stable/ref/forms/api/#django.forms.Form.cleaned_data" },
	"messages": { "def": "Django's Messages Framework — a system for showing one-time notifications (success, error, info) to users after an action.", "src": "https://docs.djangoproject.com/en/stable/ref/contrib/messages/" },

	# ── REST API & DRF (Prof REST) ───────────────────────────────────────────
	"serializer": { "def": "A DRF class that converts complex data (like Django model instances) into JSON format and back again.", "src": "https://www.django-rest-framework.org/api-guide/serializers/" },
	"modelserializer": { "def": "A DRF serializer that automatically generates fields from a Django model — less code than manual serializers.", "src": "https://www.django-rest-framework.org/api-guide/serializers/#modelserializer" },
	"drf": { "def": "Django REST Framework — a powerful toolkit for building Web APIs in Django.", "src": "https://www.django-rest-framework.org/" },
	"viewset": { "def": "A DRF class that combines the logic for listing, creating, updating, and deleting into a single class.", "src": "https://www.django-rest-framework.org/api-guide/viewsets/" },
	"router": { "def": "A DRF tool that automatically generates URL patterns for your ViewSets — no manual `urls.py` wiring needed.", "src": "https://www.django-rest-framework.org/api-guide/routers/" },
	"endpoint": { "def": "A specific URL in an API where you can send requests. Example: `/api/posts/` is an endpoint.", "src": "https://www.django-rest-framework.org/tutorial/quickstart/" },
	"token": { "def": "A unique string that acts like a password for API access. Sent in request headers to prove identity.", "src": "https://www.django-rest-framework.org/api-guide/authentication/#tokenauthentication" },
	"status code": { "def": "A number returned by a server to indicate what happened. 200 = OK, 404 = Not Found, 500 = Server Error.", "src": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status" },
	"pagination": { "def": "Splitting a large set of results into smaller pages. Example: showing 10 posts per page instead of all 1,000.", "src": "https://www.django-rest-framework.org/api-guide/pagination/" },
	"throttling": { "def": "Limiting how many API requests a user can make in a given time period to prevent abuse.", "src": "https://www.django-rest-framework.org/api-guide/throttling/" },

	# ── Views & Project Setup (Prof View) ────────────────────────────────────
	"startproject": { "def": "The Django command that creates a brand new project folder with all the default files. `django-admin startproject mysite`.", "src": "https://docs.djangoproject.com/en/stable/ref/django-admin/#startproject" },
	"startapp": { "def": "A Django command that creates a new app inside your project. `python manage.py startapp blog`.", "src": "https://docs.djangoproject.com/en/stable/ref/django-admin/#startapp" },
	"installed_apps": { "def": "A list in `settings.py` that tells Django which apps are active in your project. You must register new apps here.", "src": "https://docs.djangoproject.com/en/stable/ref/settings/#installed-apps" },
	"render": { "def": "A Django shortcut function that combines a template with context data and returns an HTML response.", "src": "https://docs.djangoproject.com/en/stable/topics/http/shortcuts/#render" },
	"apps.py": { "def": "A configuration file inside each Django app that defines the app's name and settings.", "src": "https://docs.djangoproject.com/en/stable/ref/applications/" },
	"urls.py": { "def": "The file that maps URL patterns to view functions. Each app typically has its own `urls.py`.", "src": "https://docs.djangoproject.com/en/stable/topics/http/urls/" },
	"slug": { "def": "A URL-friendly version of a string. Example: 'My First Post' becomes 'my-first-post'.", "src": "https://docs.djangoproject.com/en/stable/ref/models/fields/#slugfield" },
	"redirect": { "def": "A Django function that sends the browser to a different URL. Often used after form submissions.", "src": "https://docs.djangoproject.com/en/stable/topics/http/shortcuts/#redirect" },
	"httpresponse": { "def": "The most basic Django response object that sends raw text or HTML back to the browser.", "src": "https://docs.djangoproject.com/en/stable/ref/request-response/#httpresponse-objects" },
	"queryset": { "def": "A collection of database objects returned by Django's ORM. You can filter, sort, and chain them.", "src": "https://docs.djangoproject.com/en/stable/ref/models/querysets/" },
	"mixin": { "def": "A small class that adds specific functionality to another class through multiple inheritance.", "src": "https://docs.djangoproject.com/en/stable/ref/class-based-views/mixins/" },

	# ── Templates & Markup (Prof Markup) ─────────────────────────────────────
	"base template": { "def": "A parent HTML file that defines the shared layout (header, footer, nav). Other templates extend it.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/language/#template-inheritance" },
	"template tag": { "def": "A special Django instruction inside `{% %}` that adds logic to templates (loops, conditions, includes).", "src": "https://docs.djangoproject.com/en/stable/ref/templates/builtins/" },
	"template variable": { "def": "A placeholder inside `{{ }}` that gets replaced with actual data when the page renders.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/language/#variables" },
	"csrf_token tag": { "def": "The `{% csrf_token %}` tag placed inside forms to protect against CSRF attacks.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/builtins/#csrf-token" },
	"load tag": { "def": "The `{% load %}` tag that imports template libraries like `{% load static %}` for serving CSS/JS files.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/builtins/#load" },
	"for tag": { "def": "The `{% for item in list %}` tag that loops through items in a template to display repeated content.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/builtins/#for" },
	"if tag": { "def": "The `{% if condition %}` tag that shows or hides content based on a condition in a template.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/builtins/#if" },
	"url tag": { "def": "The `{% url 'name' %}` tag that generates URLs dynamically from your `urls.py` names.", "src": "https://docs.djangoproject.com/en/stable/ref/templates/builtins/#url" },

	# ── Database & Queries (Prof Query) ──────────────────────────────────────
	"queryset api": { "def": "Django's interface for building database queries in Python. Supports `.filter()`, `.exclude()`, `.order_by()`, etc.", "src": "https://docs.djangoproject.com/en/stable/ref/models/querysets/" },
	"filter()": { "def": "A Django ORM method that returns objects matching specific conditions. Example: `Post.objects.filter(author='Ada')`.", "src": "https://docs.djangoproject.com/en/stable/ref/models/querysets/#filter" },
	"exclude": { "def": "A Django ORM method that returns objects NOT matching the given conditions. Opposite of `.filter()`.", "src": "https://docs.djangoproject.com/en/stable/ref/models/querysets/#exclude" },
	"aggregate": { "def": "A Django ORM function that computes a summary value (sum, average, count, etc.) across a set of objects.", "src": "https://docs.djangoproject.com/en/stable/topics/db/aggregation/" },
	"annotate": { "def": "A Django ORM function that adds computed values to each object in a QuerySet (e.g. comment count per post).", "src": "https://docs.djangoproject.com/en/stable/ref/models/querysets/#annotate" },
	"many-to-many": { "def": "A relationship where multiple records in one table relate to multiple records in another (e.g. students and courses).", "src": "https://docs.djangoproject.com/en/stable/topics/db/examples/many_to_many/" },
	"one-to-many": { "def": "A relationship where one record relates to many others. Implemented with ForeignKey in Django.", "src": "https://docs.djangoproject.com/en/stable/topics/db/examples/many_to_one/" },
	"manager": { "def": "The interface through which database queries are made. `objects` is the default manager: `Post.objects.all()`.", "src": "https://docs.djangoproject.com/en/stable/topics/db/managers/" },
	"lookup": { "def": "A keyword used in Django queries to specify conditions. Example: `name__icontains='django'` (case-insensitive search).", "src": "https://docs.djangoproject.com/en/stable/topics/db/queries/#field-lookups" },
}

func get_definition(term: String) -> String:
	var key = term.to_lower().strip_edges()
	var entry = TERMS.get(key, null)
	if entry is Dictionary:
		return entry.get("def", "No definition found for '%s'." % term)
	return "No definition found for '%s'." % term

func get_source(term: String) -> String:
	var key = term.to_lower().strip_edges()
	var entry = TERMS.get(key, null)
	if entry is Dictionary:
		return entry.get("src", "")
	return ""

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
