class_name ProgressionService
extends RefCounted


func grant_xp(player: Dictionary, amount: float) -> Array[int]:
	var gained_levels: Array[int] = []
	player.xp += amount
	while player.xp >= player.xp_next:
		player.xp -= player.xp_next
		player.level += 1
		player.xp_next = floorf(float(player.xp_next) * 1.22 + 5.0)
		gained_levels.append(int(player.level))
	return gained_levels


func recalculate_stats(
	player: Dictionary,
	base_stats: Dictionary,
	active_debuffs: Array[String],
	debuffs_data: Dictionary,
	heal_amount: float = 0.0
) -> void:
	var bonuses: Dictionary = player.get("stat_bonuses", {})
	for key in base_stats.keys():
		var value: float = float(base_stats[key]) + float(bonuses.get(key, 0.0))
		for debuff_id in active_debuffs:
			var debuff: Dictionary = debuffs_data.get(debuff_id, {})
			var modifiers: Dictionary = debuff.get("modifiers", {})
			if modifiers.has(key):
				value *= float(modifiers[key])
		player[key] = value
	player.hp = minf(float(player.max_hp), float(player.hp) + heal_amount)
