import os
import re

professors = {
    "markup": "Professor Markup",
    "syntax": "Professor Syntax",
    "view": "Professor View",
    "query": "Professor Query",
    "auth": "Professor Auth",
    "token": "Professor Token",
    "rest": "Professor REST"
}

base_dir = "/Users/hansu/Documents/Capstone/djangoquest_capstone_godot_project_revision/Scripts/Ch2"

for prof_key, prof_name in professors.items():
    filepath = os.path.join(base_dir, f"ch2_professor_{prof_key}_controller.gd")
    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Strip the "not is_learning_mode and" from the caller so it calls the grader
    content = content.replace("if not is_learning_mode and not DEBUG_SKIP_IDE:", "if not DEBUG_SKIP_IDE:")

    # 2. Inject the learning mode grade return into _evaluate_and_finalize_grade
    # Find the function definition
    func_pattern = r"(func _evaluate_and_finalize_grade\(\) -> String:[\s\S]*?var raw = GradeCalculator\.compute_grade[^\n]*\n)"
    
    # We want to replace it by appending our block, IF IT DOESN'T ALREADY EXIST.
    # We should also strip out the old `if is_learning_mode: return "learning"` lower down to avoid duplicates.
    
    # First, let's remove any existing old simple return:
    content = re.sub(r"\t+if is_learning_mode:\n\t+return \"learning\"\n", "", content)
    
    injection = f"""\t
\tif is_learning_mode:
\t\tcharacter_data.update_learning_mode_grade("{prof_key}", raw)
\t\tawait _autosave_progress()
\t\tif dialogue_box:
\t\t\tdialogue_box.start([
\t\t\t\t{{ "name": "{prof_name}", "text": "Learning mode session complete. Grade is %s." % GradeCalculator.grade_to_label(raw) }}
\t\t\t])
\t\t\tawait dialogue_box.dialogue_finished
\t\treturn "learning"
"""
    
    # Do we already have an update_learning_mode_grade for this prof?
    if f'update_learning_mode_grade("{prof_key}"' not in content:
        content = re.sub(func_pattern, r"\1" + injection, content, count=1)

    with open(filepath, 'w') as f:
        f.write(content)
        
    print(f"Patched {prof_key}")

