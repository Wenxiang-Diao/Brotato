class_name RewardService
extends RefCounted


func build_pool(
	rewards: Array[Dictionary],
	risk_mode: bool,
	player_weapons: Dictionary,
	active_debuffs: Array[String],
	max_active_debuffs: int,
	excluded_ids: Array[String]
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for reward in rewards:
		var reward_id: String = str(reward.get("id", ""))
		if excluded_ids.has(reward_id):
			continue
		var debuff_id: String = str(reward.get("debuff_id", ""))
		if not risk_mode and not debuff_id.is_empty():
			continue
		var reward_type: String = str(reward.get("type", ""))
		var weapon_id: String = str(reward.get("weapon_id", ""))
		if reward_type == "weapon_unlock" and player_weapons.has(weapon_id):
			continue
		if reward_type == "weapon_level" and not player_weapons.has(weapon_id):
			continue
		if reward_type == "weapon_level" and int(player_weapons.get(weapon_id, 0)) >= 3:
			continue
		if not debuff_id.is_empty() and active_debuffs.size() >= max_active_debuffs:
			continue
		if not debuff_id.is_empty() and active_debuffs.has(debuff_id):
			continue
		pool.append(reward)
	return pool


func roll_choices(
	pool: Array[Dictionary],
	current_reward_level: int,
	risk_mode: bool,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var remaining: Array[Dictionary] = pool.duplicate()
	if current_reward_level <= 4:
		_take_guided_choice(choices, remaining, "weapon_unlock", rng)
	if risk_mode and current_reward_level >= 3:
		_take_guided_choice(choices, remaining, "risk", rng)
	while choices.size() < 3 and not remaining.is_empty():
		var index: int = rng.randi_range(0, remaining.size() - 1)
		if choices_have_risk(choices) and not str(remaining[index].get("debuff_id", "")).is_empty():
			remaining.remove_at(index)
			continue
		choices.append(remaining[index])
		remaining.remove_at(index)
	return choices


func choices_have_risk(choices: Array[Dictionary]) -> bool:
	for reward in choices:
		if not str(reward.get("debuff_id", "")).is_empty():
			return true
	return false


func _take_guided_choice(
	choices: Array[Dictionary],
	pool: Array[Dictionary],
	kind: String,
	rng: RandomNumberGenerator
) -> void:
	if choices.size() >= 3:
		return
	var candidates: Array[int] = []
	for i in pool.size():
		var reward: Dictionary = pool[i]
		if kind == "weapon_unlock" and str(reward.get("type", "")) == "weapon_unlock":
			candidates.append(i)
		elif kind == "risk" and not str(reward.get("debuff_id", "")).is_empty():
			candidates.append(i)
	if candidates.is_empty():
		return
	var candidate_index: int = candidates[rng.randi_range(0, candidates.size() - 1)]
	choices.append(pool[candidate_index])
	pool.remove_at(candidate_index)
