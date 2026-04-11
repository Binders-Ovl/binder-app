class_name SkillLibraryResource
extends Resource

@export var skills: Array[SkillResource] = []

func get_skill_by_id(skill_id: String) -> SkillResource:
	for skill: SkillResource in skills:
		if skill and skill.skill_id == skill_id:
			return skill
	return null

func validate() -> Array[String]:
	var errors: Array[String] = []
	var visited_ids: Dictionary = {}
	for skill: SkillResource in skills:
		if skill == null:
			errors.append("SkillLibraryResource.skills contains a null entry.")
			continue
		var skill_errors: Array[String] = skill.validate()
		for skill_error: String in skill_errors:
			errors.append("SkillLibraryResource.skills -> %s" % skill_error)
		var key: String = skill.skill_id.strip_edges()
		if key.is_empty():
			continue
		if visited_ids.has(key):
			errors.append("SkillLibraryResource has duplicate skill_id: %s" % key)
			continue
		visited_ids[key] = true
	return errors
