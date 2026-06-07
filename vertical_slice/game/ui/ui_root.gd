class_name GameUIRoot
extends CanvasLayer

const Tokens := preload("res://game/ui/theme/ui_tokens.gd")
const DeviceManager := preload("res://game/ui/input_device_manager.gd")
const INPUT_SETTINGS_PATH := "user://input_bindings.cfg"
const CONFIGURABLE_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"active_skill",
	&"ui_pause",
]

signal start_requested(risk_mode: bool)
signal reward_selected(index: int)
signal reroll_requested
signal correction_selected(index: int)
signal tutorial_closed
signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal reduced_motion_changed(enabled: bool)
signal setting_changed(key: StringName, value: Variant)

var game: Node
var device_manager: InputDeviceManager
var hud: Control
var screens: Control
var modal_layer: Control
var toast_layer: Control
var debug_layer: Control
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var hp_label: Label
var level_label: Label
var timer_label: Label
var mode_label: Label
var skill_button: PanelContainer
var skill_label: Label
var weapon_row: HBoxContainer
var debuff_row: HBoxContainer
var combat_dock: PanelContainer
var boss_panel: PanelContainer
var boss_label: Label
var menu_screen: Control
var reward_screen: Control
var reward_cards: HBoxContainer
var reroll_button: Button
var reward_confirm_button: Button
var reward_detail_label: Label
var selected_reward_index := 0
var correction_screen: Control
var correction_detail: Label
var results_screen: Control
var results_title: Label
var results_summary: Label
var tutorial_screen: Control
var tutorial_title: Label
var tutorial_body: Label
var tutorial_next: Button
var pause_screen: Control
var settings_screen: Control
var confirm_screen: Control
var confirm_title: Label
var confirm_body: Label
var confirm_action: Callable
var toast_panel: PanelContainer
var toast_label: Label
var debug_label: Label
var prompt_label: Label
var reduced_motion := false
var ui_scale := 1.0
var tutorial_step := 0
var manual_tutorial_context := ""
var last_state := -1
var last_view := ""
var last_weapons_signature := ""
var last_debuff_signature := ""
var scaled_icon_cache: Dictionary = {}
var focus_return: Control
var rebind_buttons: Dictionary = {}
var awaiting_rebind: StringName = &""


func _ready() -> void:
	layer = 10
	device_manager = DeviceManager.new()
	add_child(device_manager)
	device_manager.device_changed.connect(_on_device_changed)
	_ensure_input_actions()
	_load_input_bindings()
	_build_layers()
	_build_hud()
	_build_menu()
	_build_reward()
	_build_correction()
	_build_tutorial()
	_build_pause()
	_build_settings()
	_build_results()
	_build_confirm()
	_build_toast()
	_build_debug()
	_on_device_changed(device_manager.current_device)


func bind_game(value: Node) -> void:
	game = value
	refresh()


func refresh() -> void:
	if game == null or not is_instance_valid(game):
		return
	var state: int = int(game.state)
	hud.visible = state != game.GameState.MENU
	menu_screen.visible = state == game.GameState.MENU and not settings_screen.visible and manual_tutorial_context.is_empty()
	reward_screen.visible = state == game.GameState.REWARD
	correction_screen.visible = state == game.GameState.CORRECTION
	results_screen.visible = state == game.GameState.GAME_OVER or state == game.GameState.VICTORY
	tutorial_screen.visible = (state == game.GameState.PLAYING and bool(game.tutorial_visible)) or not manual_tutorial_context.is_empty()
	pause_screen.visible = state == game.GameState.PLAYING and bool(game.paused) and not settings_screen.visible and not confirm_screen.visible and manual_tutorial_context.is_empty()
	if state == game.GameState.PLAYING:
		_refresh_hud()
	if reward_screen.visible:
		_refresh_rewards()
	if correction_screen.visible:
		_refresh_correction()
	if results_screen.visible:
		_refresh_results()
	var current_view := _visible_view_name()
	if state != last_state or current_view != last_view:
		last_state = state
		last_view = current_view
		_focus_current_screen()
	_refresh_toast()
	_refresh_debug()


func _process(_delta: float) -> void:
	refresh()


func _input(event: InputEvent) -> void:
	if game == null or not event.is_pressed():
		return
	if not awaiting_rebind.is_empty():
		_capture_rebind(event)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_pause") and int(game.state) == game.GameState.PLAYING:
		if settings_screen.visible:
			_close_settings()
		elif confirm_screen.visible:
			_close_confirm()
		elif not manual_tutorial_context.is_empty():
			_close_manual_tutorial()
		elif bool(game.tutorial_visible):
			tutorial_closed.emit()
		elif bool(game.paused):
			resume_requested.emit()
		else:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if confirm_screen.visible:
			_close_confirm()
		elif settings_screen.visible:
			_close_settings()
		elif not manual_tutorial_context.is_empty():
			_close_manual_tutorial()
		elif bool(game.paused):
			resume_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_reroll") and reward_screen.visible:
		reroll_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and reward_screen.visible:
		var owner := get_viewport().gui_get_focus_owner()
		if owner is Button and owner.has_meta("reward_index"):
			_select_reward(int(owner.get_meta("reward_index")))
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if int(game.state) == game.GameState.MENU and event.keycode in [KEY_1, KEY_2]:
			start_requested.emit(event.keycode == KEY_2)
			get_viewport().set_input_as_handled()
		elif reward_screen.visible and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			_select_reward(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		elif correction_screen.visible and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			correction_selected.emit(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()


func _ensure_input_actions() -> void:
	_add_key_action("ui_reroll", KEY_R)
	_add_key_action("ui_details", KEY_TAB)
	_add_key_action("ui_pause", KEY_P)
	_add_key_action("ui_pause", KEY_ESCAPE)
	_add_joy_action("ui_reroll", JOY_BUTTON_X)
	_add_joy_action("ui_details", JOY_BUTTON_Y)
	_add_joy_action("ui_pause", JOY_BUTTON_START)
	_add_joy_axis_action("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_action("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis_action("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis_action("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis_action("active_skill", JOY_AXIS_TRIGGER_RIGHT, 1.0)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for current in InputMap.action_get_events(action):
		if current is InputEventKey and current.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _add_joy_action(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for current in InputMap.action_get_events(action):
		if current is InputEventJoypadButton and current.button_index == button:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _add_joy_axis_action(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for current in InputMap.action_get_events(action):
		if current is InputEventJoypadMotion and current.axis == axis and is_equal_approx(current.axis_value, axis_value):
			return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action, event)


func _build_layers() -> void:
	hud = _full_control("HUD")
	screens = _full_control("ScreenStack")
	modal_layer = _full_control("ModalStack")
	toast_layer = _full_control("ToastLayer")
	debug_layer = _full_control("DebugLayer")
	debug_layer.visible = OS.is_debug_build()


func _full_control(node_name: String) -> Control:
	var result := Control.new()
	result.name = node_name
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.theme = Tokens.build_theme()
	add_child(result)
	return result


func _build_hud() -> void:
	var top_left := _margin_anchor(hud, 20, 18, 292, 88)
	var vitals := _panel_vbox(top_left, 3)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	vitals.add_child(hp_row)
	hp_label = _label(hp_row, "", 15)
	hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label = _label(hp_row, "", 14, Tokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_RIGHT)
	hp_bar = _progress(vitals, Tokens.HEALTH)
	hp_bar.custom_minimum_size = Vector2(250, 14)
	xp_bar = _progress(vitals, Tokens.XP)
	xp_bar.custom_minimum_size = Vector2(250, 7)

	var top_center := _center_anchor(hud, 500, 14, 280, 54)
	var run_info := _panel_vbox(top_center, 0)
	timer_label = _label(run_info, "00:00", 24, Tokens.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	mode_label = _label(run_info, "", 13, Tokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)

	combat_dock = _center_bottom_anchor(hud, 720, 88)
	var dock_box := HBoxContainer.new()
	dock_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	dock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_box.add_theme_constant_override("separation", 6)
	combat_dock.add_child(dock_box)
	weapon_row = HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 6)
	dock_box.add_child(weapon_row)
	skill_button = _hud_item(dock_box, "active_skill", "0.0", "星辉回路")
	skill_label = skill_button.find_child("ItemLabel", true, false) as Label
	var divider := VSeparator.new()
	divider.custom_minimum_size.x = 8
	dock_box.add_child(divider)
	debuff_row = HBoxContainer.new()
	debuff_row.add_theme_constant_override("separation", 6)
	dock_box.add_child(debuff_row)

	boss_panel = _center_anchor(hud, 390, 76, 500, 58)
	var boss_box := _panel_vbox(boss_panel, 4)
	boss_label = _label(boss_box, "", 18, Tokens.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	boss_panel.visible = false


func _build_menu() -> void:
	menu_screen = _screen_root(screens)
	var center := _center_anchor(menu_screen, 390, 104, 500, 512)
	var box := _panel_vbox(center, 16)
	_label(box, "星链回响", 48, Tokens.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label(box, "元素构筑生存动作游戏", 20, Tokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	var standard := _button(box, "开始标准挑战", func(): start_requested.emit(false))
	standard.name = "DefaultFocus"
	_button(box, "开始风险挑战", func(): start_requested.emit(true), Tokens.WARNING)
	_button(box, "战斗说明", _open_tutorial_from_menu)
	_button(box, "设置", _open_settings)
	prompt_label = _label(box, "", 15, Tokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label(box, "build p4-ui-stage7", 13, Tokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)


func _build_reward() -> void:
	reward_screen = _modal_root(modal_layer)
	var center := _center_anchor(reward_screen, 80, 34, 1120, 652)
	var box := _panel_vbox(center, 10)
	_label(box, "升级选择", 28, Tokens.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label(box, "卡片显示核心效果，悬停或聚焦查看完整说明", 14, Tokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	reward_cards = HBoxContainer.new()
	reward_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reward_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_cards.add_theme_constant_override("separation", 12)
	box.add_child(reward_cards)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(0, 84)
	box.add_child(detail_panel)
	reward_detail_label = _label(detail_panel, "", 15, Tokens.TEXT_SECONDARY)
	reward_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	reroll_button = _button(footer, "重抽", func(): reroll_requested.emit())
	reward_confirm_button = _button(footer, "确认选择", _confirm_selected_reward, Tokens.SUCCESS)
	_label(footer, "选择卡片后确认", 14, Tokens.TEXT_MUTED)


func _build_correction() -> void:
	correction_screen = _modal_root(modal_layer)
	var center := _center_anchor(correction_screen, 260, 128, 760, 464)
	var box := _panel_vbox(center, 14)
	_label(box, "负面状态修正", 32, Tokens.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label(box, "每 5 级可修正一次风险。默认焦点为安全选项。", 16, Tokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	correction_detail = _label(box, "", 16, Tokens.TEXT_SECONDARY)
	correction_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var remove := _button(box, "移除最早获得的负面状态", func(): correction_selected.emit(0), Tokens.SUCCESS)
	remove.name = "DefaultFocus"
	_button(box, "保留风险，恢复 25 生命", func(): correction_selected.emit(1), Tokens.WARNING)
	_button(box, "保留风险，获得 8 经验", func(): correction_selected.emit(2), Tokens.WARNING)


func _build_tutorial() -> void:
	tutorial_screen = _modal_root(modal_layer)
	var center := _center_anchor(tutorial_screen, 250, 120, 780, 480)
	var box := _panel_vbox(center, 20)
	tutorial_title = _label(box, "", 30, Tokens.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var icon := TextureRect.new()
	icon.name = "TutorialIcon"
	icon.custom_minimum_size = Vector2(128, 128)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	tutorial_body = _label(box, "", 20, Tokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tutorial_actions := HBoxContainer.new()
	tutorial_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	tutorial_actions.add_theme_constant_override("separation", 16)
	box.add_child(tutorial_actions)
	_button(tutorial_actions, "跳过教学", _skip_tutorial)
	tutorial_next = _button(box, "下一步", _advance_tutorial)
	tutorial_next.reparent(tutorial_actions)
	tutorial_next.name = "DefaultFocus"
	_show_tutorial_step(0)


func _build_pause() -> void:
	pause_screen = _modal_root(modal_layer)
	var center := _center_anchor(pause_screen, 150, 80, 980, 560)
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	columns.add_theme_constant_override("separation", 24)
	center.add_child(columns)
	var menu_box := _panel_vbox(columns, 12)
	menu_box.custom_minimum_size.x = 300
	_label(menu_box, "已暂停", 36, Tokens.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var resume := _button(menu_box, "继续", func(): resume_requested.emit())
	resume.name = "DefaultFocus"
	_button(menu_box, "战斗说明", _open_tutorial_from_pause)
	_button(menu_box, "设置", _open_settings)
	_button(menu_box, "重新开始", func(): _open_confirm("重新开始？", "当前进度不会保留。", func(): restart_requested.emit()), Tokens.DANGER)
	_button(menu_box, "返回主菜单", func(): _open_confirm("返回主菜单？", "当前挑战将立即结束。", func(): menu_requested.emit()), Tokens.DANGER)
	var build_box := _panel_vbox(columns, 10)
	build_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(build_box, "当前构筑", 26, Tokens.TEXT)
	var pause_info := _label(build_box, "武器、状态与反应摘要会随当前挑战更新。", 18, Tokens.TEXT_SECONDARY)
	pause_info.name = "PauseBuildInfo"
	pause_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_settings() -> void:
	settings_screen = _modal_root(modal_layer)
	settings_screen.visible = false
	var center := _center_anchor(settings_screen, 220, 76, 840, 568)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	center.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	_label(box, "设置与可访问性", 32, Tokens.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label(box, "显示", 20, Tokens.PRIMARY)
	var fullscreen_button := _button(box, "显示模式：窗口", _toggle_fullscreen)
	fullscreen_button.name = "FullscreenButton"
	var scale_button := _button(box, "UI 缩放：100%", func(): _cycle_ui_scale())
	scale_button.name = "UIScaleButton"
	_label(box, "音频", 20, Tokens.PRIMARY)
	var volume_button := _button(box, "总音量：100%", _cycle_master_volume)
	volume_button.name = "VolumeButton"
	_label(box, "操作", 20, Tokens.PRIMARY)
	_label(box, "按键设置", 16, Tokens.TEXT_SECONDARY)
	_add_rebind_button(box, &"move_up", "向上移动")
	_add_rebind_button(box, &"move_down", "向下移动")
	_add_rebind_button(box, &"move_left", "向左移动")
	_add_rebind_button(box, &"move_right", "向右移动")
	_add_rebind_button(box, &"active_skill", "主动技能")
	_add_rebind_button(box, &"ui_pause", "暂停")
	_button(box, "恢复默认按键", _reset_input_bindings, Tokens.WARNING)
	_label(box, "可访问性", 20, Tokens.PRIMARY)
	var motion_button := _button(box, "低动态模式：关", func(): _toggle_reduced_motion())
	motion_button.name = "MotionButton"
	var shake_button := _button(box, "屏幕震动：开", _toggle_screen_shake)
	shake_button.name = "ShakeButton"
	var hit_stop_button := _button(box, "命中停顿：开", _toggle_hit_stop)
	hit_stop_button.name = "HitStopButton"
	var flash_button := _button(box, "闪屏强度：100%", _cycle_flash_intensity)
	flash_button.name = "FlashButton"
	var close := _button(box, "返回", _close_settings)
	close.name = "DefaultFocus"


func _build_results() -> void:
	results_screen = _screen_root(screens)
	var center := _center_anchor(results_screen, 210, 72, 860, 576)
	var box := _panel_vbox(center, 16)
	results_title = _label(box, "", 40, Tokens.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	results_summary = _label(box, "", 19, Tokens.TEXT_SECONDARY)
	results_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var retry := _button(box, "再次挑战", func(): restart_requested.emit(), Tokens.SUCCESS)
	retry.name = "DefaultFocus"
	_button(box, "返回主菜单", func(): menu_requested.emit())


func _build_confirm() -> void:
	confirm_screen = _modal_root(modal_layer)
	confirm_screen.visible = false
	var center := _center_anchor(confirm_screen, 360, 190, 560, 340)
	var box := _panel_vbox(center, 16)
	confirm_title = _label(box, "", 30, Tokens.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	confirm_body = _label(box, "", 18, Tokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var cancel := _button(row, "取消", _close_confirm)
	cancel.name = "DefaultFocus"
	_button(row, "确认", _confirm_dangerous_action, Tokens.DANGER)


func _build_toast() -> void:
	toast_panel = _center_anchor(toast_layer, 440, 18, 400, 52)
	toast_panel.visible = false
	toast_label = _label(toast_panel, "", 16, Tokens.SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_debug() -> void:
	var anchor := _margin_anchor(debug_layer, -344, 24, 320, 156)
	debug_label = _label(anchor, "", 14, Tokens.TEXT_SECONDARY)
	debug_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _refresh_hud() -> void:
	if game.player.is_empty():
		return
	var hp_max := maxf(1.0, float(game.player.max_hp))
	hp_bar.max_value = hp_max
	hp_bar.value = float(game.player.hp)
	hp_label.text = "生命 %d / %d" % [int(game.player.hp), int(hp_max)]
	xp_bar.max_value = maxf(1.0, float(game.player.xp_next))
	xp_bar.value = float(game.player.xp)
	level_label.text = "Lv.%d" % int(game.player.level)
	timer_label.text = "%02d:%02d" % [int(game.total_time) / 60, int(game.total_time) % 60]
	mode_label.text = "第 %d/%d 层 · %s" % [
		int(game.layer),
		int(game.run_config.get("layer_count", 6)),
		"风险" if bool(game.risk_mode) else "标准",
	]
	skill_label.text = "%.1f" % float(game.player.skill_cooldown)
	skill_button.tooltip_text = "星辉回路\n冷却 %.1f 秒\n释放跟随角色移动的灼烧区域。" % float(game.player.skill_cooldown)
	var weapon_signature := str(game.player.weapons)
	if weapon_signature != last_weapons_signature:
		last_weapons_signature = weapon_signature
		_rebuild_weapons()
	var debuff_signature := str(game.active_debuffs)
	if debuff_signature != last_debuff_signature:
		last_debuff_signature = debuff_signature
		_rebuild_debuffs()
	_refresh_boss()
	var pause_info := pause_screen.find_child("PauseBuildInfo", true, false) as Label
	if pause_info:
		pause_info.text = _build_summary()


func _rebuild_weapons() -> void:
	_clear_children(weapon_row)
	for weapon_id in game.player.weapons.keys():
		var data: Dictionary = game._find_by_id(game.weapons, str(weapon_id))
		var panel := _hud_item(
			weapon_row,
			str(weapon_id),
			"Lv.%d" % int(game.player.weapons[weapon_id]),
			str(data.get("name", weapon_id))
		)
		panel.tooltip_text = "%s\n等级 %d\n%s" % [
			str(data.get("name", weapon_id)),
			int(game.player.weapons[weapon_id]),
			_weapon_kind_label(str(data.get("kind", ""))),
		]


func _rebuild_debuffs() -> void:
	_clear_children(debuff_row)
	if game.active_debuffs.is_empty():
		debuff_row.visible = false
		return
	debuff_row.visible = true
	for debuff_id in game.active_debuffs:
		_hud_item(
			debuff_row,
			str(debuff_id),
			_severity_label(str(game.debuffs_data[debuff_id].get("severity", "light"))).left(1),
			str(game.debuffs_data[debuff_id].name) + "\n" + str(game.debuffs_data[debuff_id].description)
		)


func _refresh_boss() -> void:
	var boss: Dictionary = {}
	for enemy in game.enemies:
		if str(enemy.get("id", "")) == "star_bone_colossus":
			boss = enemy
			break
	boss_panel.visible = not boss.is_empty()
	if boss.is_empty():
		return
	var total_max := float(boss.max_hp) + maxf(0.0, float(boss.get("shield_max", 0.0)))
	var ratio := 100.0 * (float(boss.hp) + float(boss.shield)) / maxf(1.0, total_max)
	boss_label.text = "星骸巨像  阶段 %d  |  %d%%" % [int(boss.boss_phase), int(ratio)]


func _refresh_rewards() -> void:
	var signature := str(game.reward_choices) + ":" + str(game.rerolls_remaining)
	if reward_cards.get_meta("signature", "") == signature:
		return
	reward_cards.set_meta("signature", signature)
	_clear_children(reward_cards)
	selected_reward_index = clampi(selected_reward_index, 0, maxi(0, game.reward_choices.size() - 1))
	for i in game.reward_choices.size():
		var reward: Dictionary = game.reward_choices[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(330, 310)
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.toggle_mode = true
		card.button_pressed = i == selected_reward_index
		card.set_meta("reward_index", i)
		var risk_id := str(reward.get("debuff_id", ""))
		var risk_text := ""
		if not risk_id.is_empty():
			var severity := _severity_label(str(game.debuffs_data[risk_id].get("severity", "light")))
			risk_text = "\n\n风险 %s / 可在修正窗口移除\n代价：%s\n构筑适配：需用对应反应抵消收益压力" % [
				severity,
				str(game.debuffs_data[risk_id].description),
			]
		var card_content := VBoxContainer.new()
		card_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
		card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.alignment = BoxContainer.ALIGNMENT_CENTER
		card_content.add_theme_constant_override("separation", 8)
		card.add_child(card_content)
		var image := TextureRect.new()
		image.custom_minimum_size = Vector2(132, 150)
		image.texture = _reward_icon(reward)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.add_child(image)
		_label(card_content, str(reward.name), 20, Tokens.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		_label(card_content, _reward_type_label(str(reward.type)), 13, Tokens.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
		var summary := _reward_summary(reward)
		var summary_label := _label(card_content, summary, 15, Tokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not risk_id.is_empty():
			_label(card_content, "附带%s风险" % _severity_label(str(game.debuffs_data[risk_id].get("severity", "light"))), 14, Tokens.WARNING, HORIZONTAL_ALIGNMENT_CENTER)
		var detail := "%s\n%s%s" % [str(reward.description), _reward_detail(reward), risk_text]
		card.tooltip_text = detail
		card.set_meta("detail_text", detail)
		card.focus_entered.connect(func(index: int = i): _select_reward(index))
		card.mouse_entered.connect(func(index: int = i): _select_reward(index))
		card.gui_input.connect(func(event: InputEvent, index: int = i): _on_reward_card_gui_input(event, index))
		reward_cards.add_child(card)
	reroll_button.disabled = not bool(game._can_reroll_rewards())
	reroll_button.text = "重抽（剩余 %d）" % int(game.rerolls_remaining)
	_focus_first(reward_cards)
	_select_reward(selected_reward_index)


func _refresh_correction() -> void:
	if game.active_debuffs.is_empty():
		correction_detail.text = "当前没有可修正的负面状态。"
	else:
		var id: String = str(game.active_debuffs[0])
		correction_detail.text = "当前状态：%s  %s  可移除\n影响：%s\n来源：风险奖励" % [
			str(game.debuffs_data[id].name),
			_severity_label(str(game.debuffs_data[id].get("severity", "light"))),
			str(game.debuffs_data[id].description),
		]


func _refresh_results() -> void:
	results_title.text = "挑战胜利" if int(game.state) == game.GameState.VICTORY else "挑战失败"
	var reactions: Dictionary = game.metrics.get("reactions", {})
	results_summary.text = "%s  |  第 %d/%d 层  |  等级 %d\n\n击杀：%d\n造成伤害：%d\n受到伤害：%d\n\n雷链：%d    破碎：%d    热冲击：%d" % [
		"风险模式" if bool(game.risk_mode) else "标准模式",
		int(game.layer),
		int(game.run_config.get("layer_count", 6)),
		int(game.player.level),
		int(game.metrics.get("kills", 0)),
		int(game.metrics.get("damage_dealt", 0.0)),
		int(game.metrics.get("damage_taken", 0.0)),
		int(reactions.get("lightning_chain", 0)),
		int(reactions.get("shatter", 0)),
		int(reactions.get("thermal_shock", 0)),
	]


func _refresh_toast() -> void:
	var save_failed := results_screen.visible and not bool(game.metrics_saved)
	toast_panel.visible = float(game.message_time) > 0.0 or save_failed
	toast_label.text = "数据保存失败，请检查用户目录权限。" if save_failed else str(game.message)
	toast_label.add_theme_color_override("font_color", Tokens.DANGER if save_failed else Tokens.SECONDARY)


func _refresh_debug() -> void:
	debug_layer.visible = OS.is_debug_build() and bool(game.debug_overlay_visible)
	if not debug_layer.visible:
		return
	debug_label.text = "P4 Debug\nFPS: %d\nEnemies: %d / %d\nProjectiles: %d / %d\nMotion: %s" % [
		Engine.get_frames_per_second(),
		game.enemies.size(),
		game.MAX_ENEMIES,
		game.projectiles.size(),
		game.MAX_PROJECTILES,
		"LOW" if game.combat_feedback.reduced_motion else "FULL",
	]


func _build_summary() -> String:
	if game.player.is_empty():
		return ""
	var lines: Array[String] = []
	for id in game.player.weapons.keys():
		var data: Dictionary = game._find_by_id(game.weapons, str(id))
		lines.append("%s  Lv.%d  ·  %s" % [
			str(data.get("name", id)),
			int(game.player.weapons[id]),
			_weapon_kind_label(str(data.get("kind", ""))),
		])
	var debuffs := "无"
	if not game.active_debuffs.is_empty():
		var names: Array[String] = []
		for id in game.active_debuffs:
			names.append("%s：%s" % [
				str(game.debuffs_data[id].name),
				str(game.debuffs_data[id].description),
			])
		debuffs = "\n".join(names)
	return "武器\n%s\n\n负面状态\n%s\n\n反应说明\n标记 + 感电 = 雷链\n冻结 + 重击 = 破碎\n冻结 + 灼烧 = 热冲击" % ["\n".join(lines), debuffs]


func _show_tutorial_step(step: int) -> void:
	tutorial_step = clampi(step, 0, 2)
	var titles := ["移动与走位", "自动攻击与主动技能", "状态与元素反应"]
	var bodies := [
		"使用 WASD、方向键或左摇杆移动。\n保持走位，避免被敌群包围。",
		"武器会自动寻找目标攻击。\n按 Space 或右扳机释放星辉回路。",
		"标记 + 感电触发雷链\n冻结 + 重击触发破碎\n冻结 + 灼烧触发热冲击",
	]
	var icons := ["health", "active_skill", "lightning_chain"]
	tutorial_title.text = "战斗说明  %d / 3\n%s" % [tutorial_step + 1, titles[tutorial_step]]
	tutorial_body.text = bodies[tutorial_step]
	var icon := tutorial_screen.find_child("TutorialIcon", true, false) as TextureRect
	icon.texture = _scaled_icon(icons[tutorial_step], 128)
	tutorial_next.text = "开始战斗" if tutorial_step == 2 else "下一步"


func _advance_tutorial() -> void:
	if tutorial_step < 2:
		_show_tutorial_step(tutorial_step + 1)
	elif not manual_tutorial_context.is_empty():
		var context := manual_tutorial_context
		manual_tutorial_context = ""
		tutorial_screen.visible = false
		if context == "menu":
			menu_screen.visible = true
		else:
			pause_screen.visible = true
		_focus_current_screen()
	else:
		tutorial_closed.emit()


func _skip_tutorial() -> void:
	if manual_tutorial_context.is_empty():
		tutorial_closed.emit()
	else:
		_close_manual_tutorial()


func _close_manual_tutorial() -> void:
	var context := manual_tutorial_context
	manual_tutorial_context = ""
	tutorial_screen.visible = false
	if context == "menu":
		menu_screen.visible = true
	else:
		pause_screen.visible = true
	_restore_focus()


func _open_tutorial_from_menu() -> void:
	remember_focus()
	manual_tutorial_context = "menu"
	_show_tutorial_step(0)
	tutorial_screen.visible = true
	_focus_first(tutorial_screen)


func _open_tutorial_from_pause() -> void:
	remember_focus()
	manual_tutorial_context = "pause"
	_show_tutorial_step(0)
	pause_screen.visible = false
	tutorial_screen.visible = true
	_focus_first(tutorial_screen)


func _open_settings() -> void:
	remember_focus()
	menu_screen.visible = false
	pause_screen.visible = false
	settings_screen.visible = true
	_focus_first(settings_screen)


func _close_settings() -> void:
	settings_screen.visible = false
	if int(game.state) == game.GameState.MENU:
		menu_screen.visible = true
	else:
		pause_screen.visible = true
	_restore_focus()


func _cycle_ui_scale() -> void:
	var values := [0.9, 1.0, 1.1, 1.25]
	var index := values.find(ui_scale)
	ui_scale = values[(index + 1) % values.size()]
	get_tree().root.content_scale_factor = ui_scale
	var button := settings_screen.find_child("UIScaleButton", true, false) as Button
	button.text = "UI 缩放：%d%%" % int(ui_scale * 100.0)


func _toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
	setting_changed.emit(&"fullscreen", fullscreen)
	var button := settings_screen.find_child("FullscreenButton", true, false) as Button
	button.text = "显示模式：" + ("全屏" if fullscreen else "窗口")


func _cycle_master_volume() -> void:
	var button := settings_screen.find_child("VolumeButton", true, false) as Button
	var current := int(button.get_meta("volume", 100))
	var values := [100, 75, 50, 25, 0]
	var index := values.find(current)
	var next: int = values[(index + 1) % values.size()]
	button.set_meta("volume", next)
	button.text = "总音量：%d%%" % next
	setting_changed.emit(&"master_volume", next)


func _toggle_boolean_setting(key: StringName, button: Button) -> void:
	var enabled := not bool(button.get_meta("enabled", true))
	button.set_meta("enabled", enabled)
	var labels := {
		&"screen_shake": "屏幕震动",
		&"hit_stop": "命中停顿",
	}
	button.text = "%s：%s" % [str(labels[key]), "开" if enabled else "关"]
	setting_changed.emit(key, enabled)


func _toggle_screen_shake() -> void:
	_toggle_boolean_setting(&"screen_shake", settings_screen.find_child("ShakeButton", true, false) as Button)


func _toggle_hit_stop() -> void:
	_toggle_boolean_setting(&"hit_stop", settings_screen.find_child("HitStopButton", true, false) as Button)


func _cycle_flash_intensity() -> void:
	var button := settings_screen.find_child("FlashButton", true, false) as Button
	var current := int(button.get_meta("intensity", 100))
	var values := [100, 50, 25, 0]
	var index := values.find(current)
	var next: int = values[(index + 1) % values.size()]
	button.set_meta("intensity", next)
	button.text = "闪屏强度：%d%%" % next
	setting_changed.emit(&"flash_intensity", float(next) / 100.0)


func _toggle_reduced_motion() -> void:
	reduced_motion = not reduced_motion
	var button := settings_screen.find_child("MotionButton", true, false) as Button
	button.text = "低动态模式：" + ("开" if reduced_motion else "关")
	reduced_motion_changed.emit(reduced_motion)


func _open_confirm(title: String, body: String, action: Callable) -> void:
	remember_focus()
	confirm_title.text = title
	confirm_body.text = body
	confirm_action = action
	pause_screen.visible = false
	confirm_screen.visible = true
	_focus_first(confirm_screen)


func _close_confirm() -> void:
	confirm_screen.visible = false
	pause_screen.visible = true
	_restore_focus()


func _confirm_dangerous_action() -> void:
	confirm_screen.visible = false
	if confirm_action.is_valid():
		confirm_action.call()


func remember_focus() -> void:
	focus_return = get_viewport().gui_get_focus_owner()


func _restore_focus() -> void:
	await get_tree().process_frame
	if is_instance_valid(focus_return) and focus_return.visible and focus_return.focus_mode != Control.FOCUS_NONE:
		focus_return.grab_focus()
	else:
		_focus_current_screen()


func _select_reward(index: int) -> void:
	selected_reward_index = clampi(index, 0, maxi(0, reward_cards.get_child_count() - 1))
	for child in reward_cards.get_children():
		var card := child as Button
		card.button_pressed = int(card.get_meta("reward_index", -1)) == selected_reward_index
	if reward_detail_label and reward_cards.get_child_count() > selected_reward_index:
		var selected := reward_cards.get_child(selected_reward_index) as Button
		reward_detail_label.text = str(selected.get_meta("detail_text", ""))


func _on_reward_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_reward(index)
		var card := reward_cards.get_child(index) as Button
		card.grab_focus()
		card.accept_event()


func _confirm_selected_reward() -> void:
	reward_selected.emit(selected_reward_index)


func _reward_summary(reward: Dictionary) -> String:
	match str(reward.get("type", "")):
		"stat":
			return str(reward.description)
		"heal":
			return "立即恢复 %d 生命" % int(reward.get("value", 0))
		"weapon_unlock":
			return "获得一把新武器"
		"weapon_level":
			return "武器等级 +1"
	return str(reward.get("description", ""))


func _reward_detail(reward: Dictionary) -> String:
	var weapon_id := str(reward.get("weapon_id", ""))
	if weapon_id.is_empty():
		return ""
	var weapon: Dictionary = game._find_by_id(game.weapons, weapon_id)
	if weapon.is_empty():
		return ""
	return "\n冷却 %.2f 秒 · 基础伤害 %d" % [float(weapon.get("cooldown", 0.0)), int(weapon.get("damage", 0))]


func _add_rebind_button(parent: Node, action: StringName, label_text: String) -> void:
	var button := _button(parent, "", func(): _begin_rebind(action))
	button.set_meta("label", label_text)
	rebind_buttons[action] = button
	_refresh_rebind_button(action)


func _begin_rebind(action: StringName) -> void:
	awaiting_rebind = action
	var button := rebind_buttons[action] as Button
	button.text = "%s：请按新按键（Esc 取消）" % str(button.get_meta("label", ""))


func _capture_rebind(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_refresh_rebind_button(awaiting_rebind)
		awaiting_rebind = &""
		return
	var action := awaiting_rebind
	for other_action in CONFIGURABLE_ACTIONS:
		if other_action == action:
			continue
		for current in InputMap.action_get_events(other_action):
			if current is InputEventKey and current.physical_keycode == event.physical_keycode:
				InputMap.action_erase_event(other_action, current)
				_refresh_rebind_button(other_action)
	for current in InputMap.action_get_events(action):
		if current is InputEventKey:
			InputMap.action_erase_event(action, current)
	var replacement := InputEventKey.new()
	replacement.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	InputMap.action_add_event(action, replacement)
	awaiting_rebind = &""
	_refresh_rebind_button(action)
	_save_input_bindings()


func _refresh_rebind_button(action: StringName) -> void:
	var button := rebind_buttons.get(action) as Button
	if button == null:
		return
	var key_text := "未设置"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			key_text = event.as_text_physical_keycode()
			break
	button.text = "%s：%s" % [str(button.get_meta("label", "")), key_text]


func _save_input_bindings() -> void:
	var config := ConfigFile.new()
	for action in CONFIGURABLE_ACTIONS:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				config.set_value("input", str(action), int(event.physical_keycode))
				break
	config.save(INPUT_SETTINGS_PATH)


func _load_input_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(INPUT_SETTINGS_PATH) != OK:
		return
	for action in CONFIGURABLE_ACTIONS:
		var keycode := int(config.get_value("input", str(action), 0))
		if keycode == 0:
			continue
		for current in InputMap.action_get_events(action):
			if current is InputEventKey:
				InputMap.action_erase_event(action, current)
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


func _reset_input_bindings() -> void:
	var defaults := {
		&"move_up": KEY_W,
		&"move_down": KEY_S,
		&"move_left": KEY_A,
		&"move_right": KEY_D,
		&"active_skill": KEY_SPACE,
		&"ui_pause": KEY_ESCAPE,
	}
	for action in CONFIGURABLE_ACTIONS:
		for current in InputMap.action_get_events(action):
			if current is InputEventKey:
				InputMap.action_erase_event(action, current)
		var event := InputEventKey.new()
		event.physical_keycode = int(defaults[action])
		InputMap.action_add_event(action, event)
		_refresh_rebind_button(action)
	_save_input_bindings()


func _reward_type_label(type_name: String) -> String:
	var labels := {
		"stat": "属性强化",
		"heal": "生存恢复",
		"weapon_unlock": "新武器",
		"weapon_level": "武器升级",
	}
	return str(labels.get(type_name, type_name))


func _weapon_kind_label(kind: String) -> String:
	return {
		"projectile": "远程投射",
		"zone": "范围区域",
		"melee": "近战重击",
	}.get(kind, kind)


func _severity_label(severity: String) -> String:
	return {"light": "轻度", "medium": "中度", "heavy": "重度"}.get(severity, "未知")


func _focus_current_screen() -> void:
	await get_tree().process_frame
	for screen in [confirm_screen, settings_screen, tutorial_screen, pause_screen, reward_screen, correction_screen, results_screen, menu_screen]:
		if screen != null and screen.visible:
			_focus_first(screen)
			return


func _visible_view_name() -> String:
	for entry in [
		["confirm", confirm_screen],
		["settings", settings_screen],
		["tutorial", tutorial_screen],
		["pause", pause_screen],
		["reward", reward_screen],
		["correction", correction_screen],
		["results", results_screen],
		["menu", menu_screen],
	]:
		var control := entry[1] as Control
		if control != null and control.visible:
			return str(entry[0])
	return "hud"


func _focus_first(root: Node) -> void:
	var named := root.find_child("DefaultFocus", true, false) as Control
	if named != null and named.visible and named.focus_mode != Control.FOCUS_NONE:
		named.grab_focus()
		return
	var controls := root.find_children("*", "Button", true, false)
	for control in controls:
		var button := control as Button
		if button.visible and not button.disabled:
			button.grab_focus()
			return


func _on_device_changed(_device: StringName) -> void:
	if prompt_label:
		prompt_label.text = device_manager.prompt("Enter 确认  |  Esc 返回", "A 确认  |  B 返回")


func _screen_root(parent: Control) -> Control:
	var result := _full_child(parent)
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	result.add_child(_color_rect(Tokens.BG))
	return result


func _modal_root(parent: Control) -> Control:
	var result := _full_child(parent)
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	result.add_child(_color_rect(Color("#05070bcc")))
	return result


func _full_child(parent: Control) -> Control:
	var result := Control.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


func _color_rect(color: Color) -> ColorRect:
	var result := ColorRect.new()
	result.color = color
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _margin_anchor(parent: Control, x: float, y: float, width: float, height: float) -> PanelContainer:
	var result := PanelContainer.new()
	var left := x >= 0.0
	var top := y >= 0.0
	result.set_anchor(SIDE_LEFT, 0.0 if left else 1.0)
	result.set_anchor(SIDE_RIGHT, 0.0 if left else 1.0)
	result.set_anchor(SIDE_TOP, 0.0 if top else 1.0)
	result.set_anchor(SIDE_BOTTOM, 0.0 if top else 1.0)
	result.offset_left = x if left else x
	result.offset_right = result.offset_left + width
	result.offset_top = y if top else y
	result.offset_bottom = result.offset_top + height
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


func _center_anchor(parent: Control, x: float, y: float, width: float, height: float) -> PanelContainer:
	var result := PanelContainer.new()
	result.set_anchors_preset(Control.PRESET_CENTER)
	result.offset_left = x - 640.0
	result.offset_right = result.offset_left + width
	result.offset_top = y - 360.0
	result.offset_bottom = result.offset_top + height
	result.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(result)
	return result


func _center_bottom_anchor(parent: Control, width: float, height: float) -> PanelContainer:
	var result := PanelContainer.new()
	result.set_anchor(SIDE_LEFT, 0.5)
	result.set_anchor(SIDE_RIGHT, 0.5)
	result.set_anchor(SIDE_TOP, 1.0)
	result.set_anchor(SIDE_BOTTOM, 1.0)
	result.offset_left = -width * 0.5
	result.offset_right = width * 0.5
	result.offset_top = -height - 18.0
	result.offset_bottom = -18.0
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


func _panel_vbox(parent: Control, separation: int) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	parent.add_child(result)
	return result


func _label(parent: Node, text: String, size: int, color: Color = Tokens.TEXT, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = alignment
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result


func _button(parent: Node, text: String, callback: Callable, accent: Color = Tokens.PRIMARY) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(224, 56)
	result.focus_mode = Control.FOCUS_ALL
	result.add_theme_color_override("font_focus_color", accent)
	result.mouse_entered.connect(func(): result.grab_focus())
	result.pressed.connect(callback)
	parent.add_child(result)
	return result


func _progress(parent: Node, fill_color: Color) -> ProgressBar:
	var result := ProgressBar.new()
	result.custom_minimum_size = Vector2(280, 18)
	result.show_percentage = false
	result.add_theme_stylebox_override("fill", Tokens.panel_style(fill_color, fill_color, 4))
	parent.add_child(result)
	return result


func _hud_item(parent: Node, icon_id: String, label_text: String, tooltip: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(68, 68)
	panel.tooltip_text = tooltip
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(42, 42)
	image.texture = _scaled_icon(icon_id, 48)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(image)
	var label := _label(box, label_text, 13, Tokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	label.name = "ItemLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _icon(id: String) -> Texture2D:
	var path: String = str(Tokens.ICONS.get(id, ""))
	return load(path) as Texture2D if not path.is_empty() else null


func _scaled_icon(id: String, size: int) -> Texture2D:
	var key := "%s:%d" % [id, size]
	if scaled_icon_cache.has(key):
		return scaled_icon_cache[key]
	var source := _icon(id)
	if source == null:
		return null
	var image := source.get_image()
	image.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(image)
	scaled_icon_cache[key] = texture
	return texture


func _reward_icon(reward: Dictionary) -> Texture2D:
	var type_name := str(reward.get("type", ""))
	if type_name == "weapon_unlock" or type_name == "weapon_level":
		return _scaled_icon(str(reward.get("weapon_id", "")), 112)
	if type_name == "heal":
		return _scaled_icon("health", 112)
	var debuff_id := str(reward.get("debuff_id", ""))
	if not debuff_id.is_empty():
		return _scaled_icon(debuff_id, 112)
	return _scaled_icon("experience", 112)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()
