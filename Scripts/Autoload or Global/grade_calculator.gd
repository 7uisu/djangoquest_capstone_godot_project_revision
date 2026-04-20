# scripts/Autoload or Global/grade_calculator.gd
# All professor controllers call GradeCalculator.compute_grade() — no duplicated logic.
extends Node

# Philippine grading scale — valid steps only
const PH_SCALE: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0]
const GRADE_INC: float = 4.0          # Incomplete — triggers removal exam
const GRADE_FAILED: float = 5.0       # Outright fail
const FAIL_THRESHOLD: float = 4.5     # Raw score ≥ this → 5.0 instead of 4.0


static func compute_grade(
	wrong_attempts: int,
	hints_used: int,
	deduction_wrong: float,
	deduction_hint: float
) -> float:
	"""Convert raw performance into a clamped PH-scale grade.

	Starts at 1.0 (perfect). Each wrong attempt adds deduction_wrong,
	each hint used adds deduction_hint. The raw total is then snapped
	to the nearest valid PH scale step, with INC/fail rules applied.
	"""
	var raw: float = 1.0 + (wrong_attempts * deduction_wrong) + (hints_used * deduction_hint)

	# Outright fail
	if raw >= FAIL_THRESHOLD:
		return GRADE_FAILED

	# INC zone — above passing (3.0) but below outright fail
	if raw > PH_SCALE[-1]:
		return GRADE_INC

	# Clamp to nearest valid PH scale step (round to closest)
	return _snap_to_scale(raw)


static func _snap_to_scale(raw: float) -> float:
	"""Return the PH_SCALE value closest to `raw` (never below 1.0)."""
	var best: float = PH_SCALE[0]
	var best_dist: float = absf(raw - best)
	for step in PH_SCALE:
		var dist: float = absf(raw - step)
		if dist < best_dist:
			best = step
			best_dist = dist
	return best


static func is_inc(grade: float) -> bool:
	"""True if the grade is an INC (4.0) — needs removal exam."""
	return is_equal_approx(grade, GRADE_INC)


static func is_failed(grade: float) -> bool:
	"""True if the grade is a hard fail (5.0)."""
	return is_equal_approx(grade, GRADE_FAILED)


static func is_passing(grade: float) -> bool:
	"""True if grade is on the passing scale (1.0–3.0)."""
	return grade >= 1.0 and grade <= 3.0 and not is_inc(grade) and not is_failed(grade)


static func grade_to_label(grade: float) -> String:
	"""Human-readable label for UI display."""
	if is_inc(grade):
		return "4.0 (INC)"
	if is_failed(grade):
		return "5.0 (FAILED)"
	# Format to 2 decimal places for clean display (e.g. "1.00", "2.75")
	return "%0.2f" % grade
