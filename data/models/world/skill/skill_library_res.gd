class_name SkillLibraryResource
extends Resource

@export var skills: Array[Resource] = []

func get_skill_by_id(skill_id: String):
	for skill: Resource in skills:
		if skill and skill.get("skill_id") == skill_id:
			return skill
	return null
