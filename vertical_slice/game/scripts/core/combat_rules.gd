class_name CombatRules
extends RefCounted


func resolve_damage(raw_damage: float, armor: float, shield: float) -> Dictionary:
	var armored_damage: float = raw_damage * 100.0 / (100.0 + armor)
	var shield_damage: float = minf(maxf(0.0, shield), armored_damage)
	return {
		"armored_damage": armored_damage,
		"shield_damage": shield_damage,
		"hp_damage": armored_damage - shield_damage,
	}


func apply_status(
	enemy: Dictionary,
	status: String,
	base_duration: float,
	status_multiplier: float,
	freeze_duration_multiplier: float,
	statuses_data: Dictionary
) -> void:
	if status.is_empty():
		return
	var duration: float = base_duration
	if status == "freeze":
		duration *= freeze_duration_multiplier
	var status_data: Dictionary = statuses_data.get(status, {})
	var max_stacks: int = int(status_data.get("max_stacks", 1))
	var statuses: Dictionary = enemy.get("statuses", {})
	var current: Dictionary = statuses.get(status, {"stacks": 0, "time": 0.0, "tick": 1.0})
	current.stacks = mini(max_stacks, int(current.get("stacks", 0)) + 1)
	current.time = maxf(float(current.get("time", 0.0)), duration * status_multiplier)
	statuses[status] = current
	enemy.statuses = statuses


func has_status(enemy: Dictionary, status: String) -> bool:
	var statuses: Dictionary = enemy.get("statuses", {})
	return statuses.has(status)


func remove_status(enemy: Dictionary, status: String) -> void:
	var statuses: Dictionary = enemy.get("statuses", {})
	statuses.erase(status)
	enemy.statuses = statuses


func reaction(reactions_data: Dictionary, reaction_id: String) -> Dictionary:
	return reactions_data.get(reaction_id, {})
