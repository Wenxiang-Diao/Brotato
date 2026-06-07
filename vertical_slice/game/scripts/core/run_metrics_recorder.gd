class_name RunMetricsRecorder
extends RefCounted

const METRICS_PATH := "user://vertical_slice_runs.jsonl"


func create_run(seed: int, risk_mode: bool) -> Dictionary:
	return {
		"schema_version": 1,
		"seed": seed,
		"mode": "risk" if risk_mode else "standard",
		"kills": 0,
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"reactions": {"lightning_chain": 0, "shatter": 0, "thermal_shock": 0},
		"rewards": [],
		"debuffs_accepted": [],
		"corrections": [],
		"reward_offers": [],
		"risk_rewards_offered": 0,
		"risk_rewards_chosen": 0,
		"rerolls_used": 0,
		"debug_used": false,
	}


func increment(metrics: Dictionary, key: String, amount: float = 1.0) -> void:
	metrics[key] = float(metrics.get(key, 0.0)) + amount


func increment_int(metrics: Dictionary, key: String, amount: int = 1) -> void:
	metrics[key] = int(metrics.get(key, 0)) + amount


func record_reaction(metrics: Dictionary, reaction_id: String) -> void:
	var reactions: Dictionary = metrics.get("reactions", {})
	reactions[reaction_id] = int(reactions.get(reaction_id, 0)) + 1
	metrics.reactions = reactions


func finalize_and_save(
	metrics: Dictionary,
	result: String,
	total_time: float,
	layer: int,
	player: Dictionary,
	active_debuffs: Array[String]
) -> bool:
	metrics.result = result
	metrics.duration_seconds = total_time
	metrics.layer_reached = layer
	metrics.level_reached = int(player.get("level", 1))
	metrics.active_debuffs = active_debuffs.duplicate()
	metrics.weapons = Dictionary(player.get("weapons", {})).duplicate()

	var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(METRICS_PATH) else FileAccess.WRITE_READ
	var file: FileAccess = FileAccess.open(METRICS_PATH, mode)
	if file == null:
		return false
	file.seek_end()
	file.store_line(JSON.stringify(metrics))
	file.flush()
	return file.get_error() == OK
