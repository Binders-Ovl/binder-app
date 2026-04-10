class_name Expertise
extends Node

@export var starting_stats: StatsResource
@export var starting_skills: Array[String] = []

@onready var stats: Stats = $Stats
@onready var skills_root: Node = $Skills

func _ready() -> void:
	if not starting_stats:
		push_error("Expertise needs a StatsResource from /data/models/world/stats/")
		return
	stats.import_stats(starting_stats)
	_sync_skill_placeholders()


func _sync_skill_placeholders() -> void:
	for child: Node in skills_root.get_children():
		child.queue_free()
	for skill_id: String in starting_skills:
		var node: Node = Node.new()
		node.name = skill_id if skill_id != "" else "Skill"
		skills_root.add_child(node)
