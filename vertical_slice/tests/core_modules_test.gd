extends SceneTree

const DataRepositoryScript := preload("res://game/scripts/core/slice_data_repository.gd")
const MetricsRecorderScript := preload("res://game/scripts/core/run_metrics_recorder.gd")
const RewardServiceScript := preload("res://game/scripts/core/reward_service.gd")
const CombatRulesScript := preload("res://game/scripts/core/combat_rules.gd")
const EntityFactoryScript := preload("res://game/scripts/core/entity_factory.gd")
const ProgressionServiceScript := preload("res://game/scripts/core/progression_service.gd")
const TargetingServiceScript := preload("res://game/scripts/core/targeting_service.gd")
const CombatEventHubScript := preload("res://game/scripts/core/combat_event_hub.gd")
const CombatFeedbackScript := preload("res://game/scripts/core/combat_feedback.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var repository: SliceDataRepository = DataRepositoryScript.new()
	assert(repository.load_all())
	assert(repository.weapons.size() == 4)
	assert(repository.enemies.size() == 7)
	assert(int(repository.manifest.schema_version) == 1)

	var recorder: RunMetricsRecorder = MetricsRecorderScript.new()
	var metrics: Dictionary = recorder.create_run(42, true)
	assert(int(metrics.schema_version) == 1)
	assert(metrics.mode == "risk")
	assert(metrics.exit_context == "")
	recorder.record_reaction(metrics, "shatter")
	assert(int(metrics.reactions.shatter) == 1)

	var combat: CombatRules = CombatRulesScript.new()
	var damage: Dictionary = combat.resolve_damage(100.0, 100.0, 20.0)
	assert(is_equal_approx(float(damage.armored_damage), 50.0))
	assert(is_equal_approx(float(damage.shield_damage), 20.0))
	assert(is_equal_approx(float(damage.hp_damage), 30.0))
	var enemy: Dictionary = {"statuses": {}}
	combat.apply_status(enemy, "burn", 3.0, 1.0, 1.0, repository.statuses)
	combat.apply_status(enemy, "burn", 3.0, 1.0, 1.0, repository.statuses)
	assert(int(enemy.statuses.burn.stacks) == 2)

	var factory: EntityFactory = EntityFactoryScript.new()
	var player: Dictionary = factory.create_player(Vector2(1280.0, 720.0))
	assert(player.position == Vector2(640.0, 360.0))
	assert(factory.has_capacity(149, 150))
	assert(not factory.has_capacity(150, 150))

	var service: RewardService = RewardServiceScript.new()
	var excluded: Array[String] = []
	var active_debuffs: Array[String] = []
	var pool: Array[Dictionary] = service.build_pool(
		repository.rewards,
		false,
		player.weapons,
		active_debuffs,
		5,
		excluded
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 43
	var choices: Array[Dictionary] = service.roll_choices(pool, 2, false, rng)
	assert(choices.size() == 3)
	assert(str(choices[0].type) == "weapon_unlock")

	var progression: ProgressionService = ProgressionServiceScript.new()
	var gained_levels: Array[int] = progression.grant_xp(player, 40.0)
	assert(gained_levels == [2, 3])

	var targeting: TargetingService = TargetingServiceScript.new()
	var target_enemies: Array[Dictionary] = [
		{"uid": 1, "position": Vector2(20.0, 0.0), "hp": 10.0, "statuses": {}, "type": "normal", "dead": false},
		{"uid": 2, "position": Vector2(10.0, 0.0), "hp": 5.0, "statuses": {"mark": {}}, "type": "elite", "dead": false},
	]
	assert(targeting.nearest_enemy(target_enemies, Vector2.ZERO) == 1)
	assert(targeting.precision_target(target_enemies) == 1)
	assert(targeting.has_enemy_type(target_enemies, "elite"))

	var event_hub: CombatEventHub = CombatEventHubScript.new()
	var received_damage: Array[Dictionary] = []
	event_hub.damage_resolved.connect(func(event: Dictionary) -> void: received_damage.append(event))
	event_hub.publish_damage({"target": "enemy", "hp_damage": 5.0})
	assert(received_damage.size() == 1)
	assert(float(received_damage[0].hp_damage) == 5.0)

	var feedback: CombatFeedback = CombatFeedbackScript.new()
	feedback.trigger_hit_stop(0.2)
	assert(is_equal_approx(feedback.hit_stop_remaining, 0.05))
	for i in 100:
		feedback.trigger_impact(Vector2(i, 0.0), Color.WHITE)
	assert(feedback.effects.size() == feedback.MAX_EFFECTS)
	feedback.update(0.2)
	assert(feedback.effects.is_empty())
	feedback.set_reduced_motion(true)
	feedback.trigger_hit_stop(0.04)
	feedback.trigger_shake(8.0, 0.2)
	assert(feedback.hit_stop_remaining == 0.0)
	assert(feedback.shake_remaining == 0.0)

	print("OK: core module tests passed")
	quit(0)
