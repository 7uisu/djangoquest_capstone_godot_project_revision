# thesis_challenge_data.gd — Question bank for the 3-panelist Thesis Defense
# Panelist 1 (Cruz): 5 free-type challenges (HTML/CSS + Python)
# Panelist 2 (Santos): 10 rapid-fire MCQs (Models, ORM, Forms) — 20s timer
# Panelist 3 (Reyes): 10 debug/multi-tab challenges (ALL professors) — FINAL BOSS
extends RefCounted
class_name ThesisChallengeData

static func get_challenges(panelist_index: int) -> Array:
	match panelist_index:
		1: return _panelist_1_challenges()
		2: return _panelist_2_challenges()
		3: return _panelist_3_challenges()
		_: return []

# ═══════════════════════════════════════════════════════════════════════════════
# PANELIST 1 — Cruz (The Setup Specialist): 5 Free-Type (Django Project Setup)
# ═══════════════════════════════════════════════════════════════════════════════

static func _panelist_1_challenges() -> Array:
	return [
		{
			"id": "thesis_p1_ch1",
			"title": "Create Virtual Environment",
			"type": "free_type", "topic": "python",
			"file_name": "terminal",
			"code_lines": [
				"$ # Step 1: Create a Python virtual environment",
				"$ # The virtual environment should be named 'venv'",
				"$ # Use the venv module:",
			],
			"mission_steps": [
				"Type the command to create a virtual environment named 'venv'.",
			],
			"placeholder": "$ ",
			"expected_answers": [
				"python -m venv venv",
				"python3 -m venv venv",
			],
			"correct_output": "✅ Virtual environment 'venv' created!",
			"error_output": "❌ Incorrect. Review the Python venv module command.",
			"show_output": true,
			"output_type": "terminal",
			"timed": true, "time_limit": 30,
		},
		{
			"id": "thesis_p1_ch2",
			"title": "Install Django",
			"type": "free_type", "topic": "python",
			"file_name": "terminal",
			"code_lines": [
				"$ # Step 2: Install Django using pip",
				"$ # Your virtual environment is already activated",
				"$ (venv) $ ",
			],
			"mission_steps": [
				"Type the pip command to install Django.",
			],
			"placeholder": "$ ",
			"expected_answers": [
				"pip install django",
				"pip3 install django",
				"pip install Django",
				"pip3 install Django",
			],
			"correct_output": "✅ Successfully installed Django!",
			"error_output": "❌ Incorrect. Review the pip install command.",
			"show_output": true,
			"output_type": "terminal",
			"timed": true, "time_limit": 30,
		},
		{
			"id": "thesis_p1_ch3",
			"title": "Create Django Project",
			"type": "free_type", "topic": "python",
			"file_name": "terminal",
			"code_lines": [
				"$ # Step 3: Create a new Django project",
				"$ # The project should be called 'mysite'",
				"$ (venv) $ ",
			],
			"mission_steps": [
				"Type the django-admin command to create a project named 'mysite'.",
			],
			"placeholder": "$ ",
			"expected_answers": [
				"django-admin startproject mysite",
			],
			"correct_output": "✅ Project 'mysite' created!",
			"error_output": "❌ Incorrect. Review the django-admin startproject command.",
			"show_output": true,
			"output_type": "terminal",
			"timed": true, "time_limit": 30,
		},
		{
			"id": "thesis_p1_ch4",
			"title": "Create Django App",
			"type": "free_type", "topic": "python",
			"file_name": "terminal",
			"code_lines": [
				"$ # Step 4: Create a new Django app inside the project",
				"$ # The app should be called 'blog'",
				"$ (venv) mysite/ $ ",
			],
			"mission_steps": [
				"Type the manage.py command to create an app named 'blog'.",
			],
			"placeholder": "$ ",
			"expected_answers": [
				"python manage.py startapp blog",
				"python3 manage.py startapp blog",
			],
			"correct_output": "✅ App 'blog' created!",
			"error_output": "❌ Incorrect. Review the manage.py startapp command.",
			"show_output": true,
			"output_type": "terminal",
			"timed": true, "time_limit": 30,
		},
		{
			"id": "thesis_p1_ch5",
			"title": "Run Development Server",
			"type": "free_type", "topic": "python",
			"file_name": "terminal",
			"code_lines": [
				"$ # Step 5: Start the Django development server",
				"$ # Run the built-in server to see your project",
				"$ (venv) mysite/ $ ",
			],
			"mission_steps": [
				"Type the manage.py command to start the development server.",
			],
			"placeholder": "$ ",
			"expected_answers": [
				"python manage.py runserver",
				"python3 manage.py runserver",
			],
			"correct_output": "✅ Server running at http://127.0.0.1:8000/",
			"error_output": "❌ Incorrect. Review the manage.py runserver command.",
			"show_output": true,
			"output_type": "terminal",
			"timed": true, "time_limit": 30,
		},
	]

# ═══════════════════════════════════════════════════════════════════════════════
# PANELIST 2 — Santos (The Data Tester): 10 Rapid-Fire MCQs (20s timer)
# ═══════════════════════════════════════════════════════════════════════════════

static func _panelist_2_challenges() -> Array:
	return [
		{
			"id": "thesis_p2_ch1",
			"title": "Django Model Field",
			"type": "predict_output", "topic": "python",
			"file_name": "models.py",
			"code_lines": ["# Which field stores text with a max_length?"],
			"mission_steps": ["Select the correct Django model field."],
			"options": [
				{"text": "A. CharField", "correct": true},
				{"text": "B. TextField", "correct": false},
				{"text": "C. IntegerField", "correct": false},
				{"text": "D. BooleanField", "correct": false},
			],
			"correct_output": "CharField stores text with max_length!",
			"error_output": "❌ Incorrect. Think about which field type requires max_length.",
			"timed": true, "time_limit": 20,
		},
		{
			"id": "thesis_p2_ch2",
			"title": "ORM Query",
			"type": "predict_output", "topic": "python",
			"file_name": "views.py",
			"code_lines": ["# How do you get ALL objects from a model?"],
			"mission_steps": ["Select the correct ORM call."],
			"options": [
				{"text": "A. Model.objects.filter()", "correct": false},
				{"text": "B. Model.objects.all()", "correct": true},
				{"text": "C. Model.objects.get()", "correct": false},
				{"text": "D. Model.objects.values()", "correct": false},
			],
			"correct_output": ".all() returns a QuerySet of all rows!",
			"error_output": "❌ Incorrect. Think about QuerySet methods for retrieving records.",
			"timed": true, "time_limit": 20,
		},
		{
			"id": "thesis_p2_ch3",
			"title": "Django Migration",
			"type": "predict_output", "topic": "python",
			"file_name": "manage.py",
			"code_lines": ["# Which command creates migration files?"],
			"mission_steps": ["Select the correct manage.py command."],
			"options": [
				{"text": "A. python manage.py migrate", "correct": false},
				{"text": "B. python manage.py makemigrations", "correct": true},
				{"text": "C. python manage.py runserver", "correct": false},
				{"text": "D. python manage.py createsuperuser", "correct": false},
			],
			"correct_output": "makemigrations creates the migration files!",
			"error_output": "❌ Incorrect. Remember the difference between creating and applying migrations.",
			"timed": true, "time_limit": 20,
		},
		{
			"id": "thesis_p2_ch4",
			"title": "Foreign Key",
			"type": "predict_output", "topic": "python",
			"file_name": "models.py",
			"code_lines": ["# What does ForeignKey create?"],
			"mission_steps": ["Select the relationship type."],
			"options": [
				{"text": "A. Many-to-Many", "correct": false},
				{"text": "B. One-to-One", "correct": false},
				{"text": "C. Many-to-One", "correct": true},
				{"text": "D. No relationship", "correct": false},
			],
			"correct_output": "ForeignKey = Many-to-One relationship!",
			"error_output": "❌ Incorrect. Think about how ForeignKey links two models.",
			"timed": true, "time_limit": 20,
		},
		{
			"id": "thesis_p2_ch5",
			"title": "QuerySet Filter",
			"type": "predict_output", "topic": "python",
			"file_name": "views.py",
			"code_lines": ["# Filter posts where title contains 'Django'?"],
			"mission_steps": ["Select the correct filter syntax."],
			"options": [
				{"text": "A. Post.objects.filter(title__contains='Django')", "correct": true},
				{"text": "B. Post.objects.get(title='Django')", "correct": false},
				{"text": "C. Post.objects.filter(title='Django')", "correct": false},
				{"text": "D. Post.objects.all(title__contains='Django')", "correct": false},
			],
			"correct_output": "title__contains is the correct lookup!",
			"error_output": "❌ Incorrect. Think about Django's lookup syntax with double underscores.",
			"timed": true, "time_limit": 20,
		},
		{
			"id": "thesis_p2_ch6",
			"title": "Model Meta",
			"type": "predict_output", "topic": "python",
			"file_name": "models.py",
			"code_lines": ["# What does class Meta: ordering = ['-created'] do?"],
			"mission_steps": ["Select the correct behavior."],
			"options": [
				{"text": "A. Orders by created ascending", "correct": false},
				{"text": "B. Orders by created descending", "correct": true},
				{"text": "C. Filters by created date", "correct": false},
				{"text": "D. Groups by created date", "correct": false},
			],
			"correct_output": "The '-' prefix means descending order!",
			"error_output": "❌ Incorrect. Think about what the dash prefix means in ordering.",
			"timed": true, "time_limit": 20,
		},
		{
			"id": "thesis_p2_ch7",
			"title": "Django Forms",
			"type": "predict_output", "topic": "python",
			"file_name": "forms.py",
			"code_lines": ["# Which class creates a form from a model?"],
			"mission_steps": ["Select the correct form base class."],
			"options": [
				{"text": "A. forms.Form", "correct": false},
				{"text": "B. forms.ModelForm", "correct": true},
				{"text": "C. forms.BaseForm", "correct": false},
				{"text": "D. models.Form", "correct": false},
			],
			"correct_output": "ModelForm auto-generates fields from a model!",
			"error_output": "❌ Incorrect. Think about which form class auto-generates from a model.",
			"timed": true, "time_limit": 20,
		},
		{
			"id": "thesis_p2_ch8",
			"title": "ORM Delete",
			"type": "predict_output", "topic": "python",
			"file_name": "views.py",
			"code_lines": ["# How do you delete a single object?"],
			"mission_steps": ["Select the correct way to delete."],
			"options": [
				{"text": "A. obj.remove()", "correct": false},
				{"text": "B. obj.destroy()", "correct": false},
				{"text": "C. obj.delete()", "correct": true},
				{"text": "D. Model.objects.remove(obj)", "correct": false},
			],
			"correct_output": ".delete() removes the object from the DB!",
			"error_output": "❌ Incorrect. Think about the ORM method for removing objects.",
			"timed": true, "time_limit": 20,
		},
		{
			"id": "thesis_p2_ch9",
			"title": "ManyToManyField",
			"type": "predict_output", "topic": "python",
			"file_name": "models.py",
			"code_lines": ["# How do you add an item to a ManyToMany field?"],
			"mission_steps": ["Select the correct M2M operation."],
			"options": [
				{"text": "A. obj.tags.append(tag)", "correct": false},
				{"text": "B. obj.tags.add(tag)", "correct": true},
				{"text": "C. obj.tags.push(tag)", "correct": false},
				{"text": "D. obj.tags = tag", "correct": false},
			],
			"correct_output": ".add() is the M2M method!",
			"error_output": "❌ Incorrect. Think about M2M relationship methods.",
			"timed": true, "time_limit": 20,
		},
		{
			"id": "thesis_p2_ch10",
			"title": "Django Admin",
			"type": "predict_output", "topic": "python",
			"file_name": "admin.py",
			"code_lines": ["# How do you register a model in Django admin?"],
			"mission_steps": ["Select the correct registration call."],
			"options": [
				{"text": "A. admin.register(MyModel)", "correct": false},
				{"text": "B. admin.site.register(MyModel)", "correct": true},
				{"text": "C. MyModel.register(admin)", "correct": false},
				{"text": "D. admin.add(MyModel)", "correct": false},
			],
			"correct_output": "admin.site.register() is correct!",
			"error_output": "❌ Incorrect. Think about the Django admin registration pattern.",
			"timed": true, "time_limit": 20,
		},
	]

# ═══════════════════════════════════════════════════════════════════════════════
# PANELIST 3 — Reyes (The System Debugger): 10 Debug + Multi-Tab (FINAL BOSS)
# ═══════════════════════════════════════════════════════════════════════════════

static func _panelist_3_challenges() -> Array:
	return [
		# ── CH1: Django Template For Loop ──
		{
			"id": "thesis_p3_ch1",
			"title": "Template For Loop",
			"type": "free_type", "topic": "html",
			"file_name": "blog_list.html",
			"code_lines": [
				"<ul>",
				"  <!-- Loop through the 'posts' list and display each post title -->",
			],
			"mission_steps": [
				"Write the Django template for loop tag.",
				"Use: {% for post in posts %}",
			],
			"placeholder": "Type the template tag...",
			"expected_answers": [
				"{% for post in posts %}",
			],
			"correct_output": "✅ Template loop rendered!",
			"error_output": "❌ Incorrect. Review Django template for loop syntax.",
			"show_output": true,
			"output_type": "browser",
			"timed": false,
		},
		# ── CH2: Django Migrations ──
		{
			"id": "thesis_p3_ch2",
			"title": "Run Migrations",
			"type": "free_type", "topic": "python",
			"file_name": "terminal",
			"code_lines": [
				"$ # Your models have changed. Apply the changes to the database.",
				"$ # First, generate the migration files:",
				"$ (venv) mysite/ $",
			],
			"mission_steps": [
				"Type the manage.py command to generate migration files.",
			],
			"placeholder": "$ ",
			"expected_answers": [
				"python manage.py makemigrations",
				"python3 manage.py makemigrations",
			],
			"correct_output": "✅ Migrations created!",
			"error_output": "❌ Incorrect. Review the manage.py makemigrations command.",
			"show_output": true,
			"output_type": "terminal",
			"timed": false,
		},
		# ── CH3: runserver + INSTALLED_APPS debug (Prof View) ──
		{
			"id": "thesis_p3_ch3",
			"title": "INSTALLED_APPS Fix",
			"type": "free_type", "topic": "python",
			"file_name": "settings.py",
			"code_lines": [
				"INSTALLED_APPS = [",
				"    'django.contrib.admin',",
				"    'django.contrib.auth',",
				"    'django.contrib.contenttypes',",
				"    'django.contrib.sessions',",
				"    # BUG: the app 'blog' is missing from INSTALLED_APPS",
				"]",
			],
			"mission_steps": [
				"Add 'blog' to the INSTALLED_APPS list.",
				"Type only the missing line: 'blog',",
			],
			"placeholder": "Type the missing line...",
			"expected_answers": [
				"'blog',",
				"\"blog\",",
				"'blog'",
				"\"blog\"",
			],
			"correct_output": "✅ App registered in INSTALLED_APPS!",
			"error_output": "❌ Incorrect. Check the format for registering apps.",
			"show_output": true,
			"output_type": "terminal",
			"timed": false,
		},
		# ── CH4: URL routing debug (Prof View) ──
		{
			"id": "thesis_p3_ch4",
			"title": "Fix URL Pattern",
			"type": "free_type", "topic": "python",
			"file_name": "urls.py",
			"code_lines": [
				"from django.urls import path",
				"from . import views",
				"",
				"urlpatterns = [",
				"    # BUG: This path is missing the view function",
				"    path('home/', ),",
				"]",
			],
			"mission_steps": [
				"Fix the path by adding the correct view function.",
				"The view function is views.home",
				"Type the full corrected line.",
			],
			"placeholder": "Type the corrected path()...",
			"expected_answers": [
				"path('home/', views.home),",
				"path(\"home/\", views.home),",
				"path('home/', views.home, name='home'),",
				"path(\"home/\", views.home, name=\"home\"),",
			],
			"correct_output": "✅ URL pattern fixed!",
			"error_output": "❌ Incorrect. Review URL pattern syntax with path().",
			"show_output": true,
			"output_type": "terminal",
			"timed": false,
		},
		# ── CH5: Model definition (Prof Query) ──
		{
			"id": "thesis_p3_ch5",
			"title": "Define a Model",
			"type": "free_type", "topic": "python",
			"file_name": "models.py",
			"code_lines": [
				"from django.db import models",
				"",
				"# Create a model called 'Post' with a CharField 'title' (max 200)",
			],
			"mission_steps": [
				"Define a Django model class Post(models.Model).",
				"Add a field: title = models.CharField(max_length=200)",
			],
			"placeholder": "Type your model...",
			"expected_answers": [
				"class Post(models.Model):\n    title = models.CharField(max_length=200)",
				"class Post(models.Model):\n\ttitle = models.CharField(max_length=200)",
			],
			"correct_output": "✅ Model defined correctly!",
			"error_output": "❌ Incorrect. Review model class definition syntax.",
			"show_output": true,
			"output_type": "terminal",
			"timed": false,
		},
		# ── CH6: ORM queryset debug (Prof Query) ──
		{
			"id": "thesis_p3_ch6",
			"title": "Fix the QuerySet",
			"type": "free_type", "topic": "python",
			"file_name": "views.py",
			"code_lines": [
				"# BUG: This query should get posts where is_published=True",
				"# but the lookup is wrong",
				"posts = Post.objects.filter(is_published='True')",
			],
			"mission_steps": [
				"Fix the filter so is_published uses a boolean True, not a string.",
				"Type only the corrected line.",
			],
			"placeholder": "Type the corrected filter...",
			"expected_answers": [
				"posts = Post.objects.filter(is_published=True)",
			],
			"correct_output": "✅ QuerySet fixed! Boolean, not string.",
			"error_output": "❌ Incorrect. Check the data type for boolean parameters.",
			"show_output": true,
			"output_type": "terminal",
			"timed": false,
		},
		# ── CH7: Multi-tab: models.py + views.py (Prof Query + View) ──
		{
			"id": "thesis_p3_ch7",
			"title": "Wire Model to View",
			"type": "free_type", "topic": "python",
			"files": {
				"models.py": "from django.db import models\n\nclass Article(models.Model):\n    title = models.CharField(max_length=200)\n    body = models.TextField()\n",
				"views.py": "from django.shortcuts import render\n# Import the Article model and create a view that gets all articles\n# BUG: The import is missing and the view is incomplete\n\ndef article_list(request):\n    pass\n",
			},
			"mission_steps": [
				"In views.py:",
				"1. Add the import: from .models import Article",
				"2. Replace 'pass' with: articles = Article.objects.all()",
				"3. Add: return render(request, 'articles.html', {'articles': articles})",
			],
			"expected_answers": {
				"views.py": [
					"from django.shortcuts import render\nfrom .models import Article\n\ndef article_list(request):\n    articles = Article.objects.all()\n    return render(request, 'articles.html', {'articles': articles})",
				],
			},
			"correct_output": "✅ Model wired to view!",
			"error_output": "❌ Incorrect. Review how views import models and query data.",
			"show_output": true,
			"output_type": "terminal",
			"timed": false,
		},
		# ── CH8: Permission decorator debug (Prof Auth) ──
		{
			"id": "thesis_p3_ch8",
			"title": "Fix Permission Decorator",
			"type": "free_type", "topic": "python",
			"file_name": "views.py",
			"code_lines": [
				"from django.contrib.auth.decorators import login_required",
				"",
				"# BUG: This view should require login but the decorator is missing",
				"def dashboard(request):",
				"    return render(request, 'dashboard.html')",
			],
			"mission_steps": [
				"Add the @login_required decorator above the function.",
				"Type the decorator line only.",
			],
			"placeholder": "Type the decorator...",
			"expected_answers": [
				"@login_required",
			],
			"correct_output": "✅ View is now protected!",
			"error_output": "❌ Incorrect. Review the decorator for protecting views.",
			"show_output": true,
			"output_type": "terminal",
			"timed": false,
		},
		# ── CH9: Multi-tab: views.py + urls.py + serializers.py (Prof REST) ──
		{
			"id": "thesis_p3_ch9",
			"title": "Fix REST Endpoint",
			"type": "free_type", "topic": "python",
			"files": {
				"serializers.py": "from rest_framework import serializers\nfrom .models import Post\n\nclass PostSerializer(serializers.ModelSerializer):\n    class Meta:\n        model = Post\n        fields = '__all__'\n",
				"views.py": "from rest_framework.decorators import api_view\nfrom rest_framework.response import Response\n# BUG: Missing serializer import and incomplete view\n\n@api_view(['GET'])\ndef post_list(request):\n    pass\n",
				"urls.py": "from django.urls import path\nfrom . import views\n\nurlpatterns = [\n    path('api/posts/', views.post_list),\n]\n",
			},
			"mission_steps": [
				"In views.py:",
				"1. Import: from .serializers import PostSerializer",
				"2. Import: from .models import Post",
				"3. Replace 'pass' with the correct DRF logic:",
				"   posts = Post.objects.all()",
				"   serializer = PostSerializer(posts, many=True)",
				"   return Response(serializer.data)",
			],
			"expected_answers": {
				"views.py": [
					"from rest_framework.decorators import api_view\nfrom rest_framework.response import Response\nfrom .serializers import PostSerializer\nfrom .models import Post\n\n@api_view(['GET'])\ndef post_list(request):\n    posts = Post.objects.all()\n    serializer = PostSerializer(posts, many=True)\n    return Response(serializer.data)",
				],
			},
			"correct_output": "✅ REST API endpoint working!",
			"error_output": "❌ Incorrect. Review the DRF pattern for serializing querysets.",
			"show_output": true,
			"output_type": "terminal",
			"timed": false,
		},
		# ── CH10: Token auth flow debug (Prof Token) ──
		{
			"id": "thesis_p3_ch10",
			"title": "Token Authentication Setup",
			"type": "free_type", "topic": "python",
			"file_name": "settings.py",
			"code_lines": [
				"REST_FRAMEWORK = {",
				"    'DEFAULT_AUTHENTICATION_CLASSES': [",
				"        # BUG: Token authentication class is missing",
				"    ]",
				"}",
			],
			"mission_steps": [
				"Add the TokenAuthentication class to the list.",
				"Type the full class path as a string.",
			],
			"placeholder": "Type the class path...",
			"expected_answers": [
				"'rest_framework.authentication.TokenAuthentication',",
				"\"rest_framework.authentication.TokenAuthentication\",",
				"'rest_framework.authentication.TokenAuthentication'",
				"\"rest_framework.authentication.TokenAuthentication\"",
			],
			"correct_output": "✅ Token Authentication configured!",
			"error_output": "❌ Incorrect. Review DRF authentication class paths.",
			"show_output": true,
			"output_type": "terminal",
			"timed": false,
		},
	]
