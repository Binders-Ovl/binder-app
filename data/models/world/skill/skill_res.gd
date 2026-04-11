class_name SkillResource
extends Resource

@export var skill_id: String = ""
@export var display_name: String = ""
@export var mp_cost: int = 0
@export var cooldown_sec: float = 0.0
@export var targeting_area: AttackAreaResource
@export var notes: String = "IMPL-003 placeholder"

func validate() -> Array[String]:
	var errors: Array[String] = []
	if skill_id.strip_edges().is_empty():
		errors.append("SkillResource.skill_id should not be empty.")
	if display_name.strip_edges().is_empty():
		errors.append("SkillResource.display_name should not be empty.")
	if mp_cost < 0:
		errors.append("SkillResource.mp_cost cannot be negative.")
	if cooldown_sec < 0.0:
		errors.append("SkillResource.cooldown_sec cannot be negative.")
	if targeting_area == null:
		errors.append("SkillResource.targeting_area must be assigned.")
	elif targeting_area is AttackAreaResource:
		var area_errors: Array[String] = targeting_area.validate()
		for area_error: String in area_errors:
			errors.append("SkillResource.targeting_area -> %s" % area_error)
	return errors
