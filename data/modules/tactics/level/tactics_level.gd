class_name TacticsLevel
extends Node3D
## Tactics system initialization and continuous active timeline management.

const COMBAT_CONFIG = preload("res://data/models/world/combat/config/combat_config.gd")
const COMBAT_FORMULA = preload("res://data/models/world/combat/formula/combat_formula.gd")

#region: --- Props ---
@export var camera: TacticsCameraResource = load("res://data/models/view/camera/tactics/camera.tres")
@export var camera_boundary_radius: float = 10.0
@export var ui_control: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")

var participant: TacticsParticipant
var player: TacticsPlayer = null
var opponent: TacticsOpponent
var arena: TacticsArena
var turn_stage: int = 0
var enemy_ai_poll_timer: float = 0.0
var battle_over: bool = false
var result_label: Label
var result_replay_button: Button
#endregion

#region: --- Processing ---
func _ready() -> void:
	randomize()
	if not ui_control:
		push_error("TacticsControls needs a ControlResource from /data/models/view/control/tactics/")
	if not camera:
		push_error("TacticsCamera needs a CameraResource from /data/models/view/camera/tactics/")

	participant = $TacticsParticipant
	player = $TacticsParticipant/TacticsPlayer
	opponent = $TacticsParticipant/TacticsOpponent
	arena = $TacticsArena

	arena.configure_tiles()
	participant.configure(camera, ui_control)

	if camera.boundary_radius != camera_boundary_radius:
		camera.boundary_radius = camera_boundary_radius

func _physics_process(delta: float) -> void:
	if battle_over:
		return

	_cleanup_defeated_units()
	if _try_resolve_battle():
		return

	match turn_stage:
		0:
			_init_turn()
		1:
			_handle_turn(delta)
#endregion

#region: --- Methods ---
func _init_turn() -> void:
	if participant.is_configured(player) and participant.is_configured(opponent):
		turn_stage = 1

func _handle_turn(delta: float) -> void:
	_tick_all_pawn_energy(delta)

	if not participant.is_configured(player):
		participant.configure(camera, ui_control)
	participant.act(delta, true, player)

	enemy_ai_poll_timer -= delta
	if enemy_ai_poll_timer <= 0.0:
		enemy_ai_poll_timer = 0.2
		_process_enemy_timeline_actions()

func _tick_all_pawn_energy(delta: float) -> void:
	for pawn: TacticsPawn in player.get_children():
		pawn.tick_act(delta)
		pawn.refresh_action_state()
	for pawn: TacticsPawn in opponent.get_children():
		pawn.tick_act(delta)
		pawn.refresh_action_state()

func _process_enemy_timeline_actions() -> void:
	var enemy_pawns: Array = opponent.get_children()
	var player_pawns: Array = player.get_children()
	var nav_state: Dictionary = arena.capture_navigation_state()
	var consumed_action: bool = false

	for enemy_pawn: TacticsPawn in enemy_pawns:
		if not is_instance_valid(enemy_pawn) or not enemy_pawn.is_alive() or enemy_pawn.res.is_moving or enemy_pawn.res.is_attacking:
			continue

		enemy_pawn.refresh_action_state()
		var attack_profile = enemy_pawn.stats.get_primary_attack()
		var attack_target: TacticsPawn = _nearest_attackable_target(enemy_pawn, player_pawns)
		if attack_profile and attack_target:
			var attack_cost: float = attack_profile.get_effective_act_cost(float(TacticsConfig.action_cost.attack))
			if enemy_pawn.spend_act(attack_cost):
				_apply_ai_attack(enemy_pawn, attack_target, attack_profile)
				enemy_pawn.refresh_action_state()
				consumed_action = true
				break

		if enemy_pawn.can_pawn_move():
			var enemy_tile: TacticsTile = enemy_pawn.get_tile()
			if not enemy_tile:
				continue
			arena.reset_all_tile_markers()
			arena.process_surrounding_tiles(enemy_tile, float(enemy_pawn.stats.movement), float(enemy_pawn.stats.jump), enemy_pawns, enemy_pawn.stats.can_fly)
			arena.mark_reachable_tiles(enemy_tile, enemy_pawn.stats.movement)
			var move_target: TacticsTile = arena.get_nearest_target_adjacent_tile(enemy_pawn, player_pawns)
			if move_target == enemy_tile:
				move_target = _get_aggressive_fallback_move_tile(enemy_pawn, player_pawns)
			if move_target:
				var path: Array = arena.get_pathfinding_tilestack(move_target)
				if not path.is_empty() and enemy_pawn.spend_act(float(TacticsConfig.action_cost.move)):
					enemy_pawn.res.mark_move_transaction(enemy_pawn.global_position)
					enemy_pawn.res.pathfinding_tilestack = path
					enemy_pawn.refresh_action_state()
					consumed_action = true
					break

	arena.restore_navigation_state(nav_state)
	if consumed_action:
		return

func _apply_ai_attack(attacker: TacticsPawn, target: TacticsPawn, attack_profile) -> void:
	var hit_roll: int = randi_range(1, 100)
	if not COMBAT_FORMULA.roll_hit(attacker.stats.agi, target.stats.dex, hit_roll):
		return

	var damage: int = _resolve_attack_damage(attacker, target, attack_profile)
	if damage <= 0:
		return
	target.stats.apply_to_curr_health(-damage)

func _resolve_attack_damage(attacker: TacticsPawn, target: TacticsPawn, attack_profile) -> int:
	var attacker_class = attacker.stats.class_combat
	var target_class = target.stats.class_combat
	var type_mod: float = COMBAT_FORMULA.get_type_mod(attack_profile.attack_type, target.stats.get_armor_type())
	var damage: int
	if attack_profile.is_magic:
		damage = COMBAT_FORMULA.calc_magic_damage(
			attack_profile.base_attack,
			float(attacker.stats.intt),
			float(attacker_class.get("int_scale")) if attacker_class else COMBAT_CONFIG.DEFAULT_INT_SCALE,
			type_mod,
			attack_profile.elevation_modifier,
			attack_profile.damage_modifier,
			float(target_class.get("base_mdef")) if target_class else 0.0,
			float(target.stats.wis),
			float(target_class.get("wis_scale")) if target_class else COMBAT_CONFIG.DEFAULT_WIS_SCALE,
			float(target_class.get("mdef_mod")) if target_class else 1.0
		)
	else:
		damage = COMBAT_FORMULA.calc_physical_damage(
			attack_profile.base_attack,
			float(attacker.stats.str),
			float(attacker_class.get("str_scale")) if attacker_class else COMBAT_CONFIG.DEFAULT_STR_SCALE,
			type_mod,
			attack_profile.elevation_modifier,
			attack_profile.damage_modifier,
			float(target_class.get("base_pdef")) if target_class else 0.0,
			float(target.stats.vit),
			float(target_class.get("vit_scale")) if target_class else COMBAT_CONFIG.DEFAULT_VIT_SCALE,
			float(target_class.get("pdef_mod")) if target_class else 1.0
		)

	var crit_chance: float = COMBAT_FORMULA.calc_crit_chance(
		attacker.stats.agi,
		float(attacker_class.get("crit_baseline")) if attacker_class else COMBAT_CONFIG.DEFAULT_CRIT_BASELINE,
		float(attacker_class.get("crit_per_agi")) if attacker_class else COMBAT_CONFIG.DEFAULT_CRIT_PER_AGI
	)
	if randf_range(0.0, 100.0) <= crit_chance:
		var crit_mult: float = float(attacker_class.get("crit_damage_mult")) if attacker_class else COMBAT_CONFIG.DEFAULT_CRIT_DAMAGE_MULT
		damage = maxi(1, int(round(float(damage) * crit_mult)))
	return damage

func _nearest_attackable_target(attacker: TacticsPawn, targets: Array) -> TacticsPawn:
	var attack_footprint: Dictionary = arena.get_attack_footprint(attacker)
	if attack_footprint.is_empty():
		return null

	var nearest: TacticsPawn = null
	var nearest_distance: float = INF
	for target: TacticsPawn in targets:
		if not is_instance_valid(target) or not target.is_alive():
			continue
		var target_tile: TacticsTile = target.get_tile()
		if not target_tile or not attack_footprint.has(target_tile.get_instance_id()):
			continue
		var horizontal_dist: float = Vector2(attacker.global_position.x, attacker.global_position.z).distance_to(
			Vector2(target.global_position.x, target.global_position.z)
		)
		if horizontal_dist < nearest_distance:
			nearest = target
			nearest_distance = horizontal_dist
	return nearest


func _get_aggressive_fallback_move_tile(enemy_pawn: TacticsPawn, targets: Array) -> TacticsTile:
	var enemy_tile: TacticsTile = enemy_pawn.get_tile()
	if not enemy_tile:
		return null
	var best_tile: TacticsTile = null
	var best_score: float = INF
	for tile: TacticsTile in arena.get_node("Tiles").get_children():
		if tile == enemy_tile:
			continue
		if not tile.reachable or tile.is_taken():
			continue
		var nearest_target_dist: float = INF
		for target: TacticsPawn in targets:
			if not is_instance_valid(target) or not target.is_alive():
				continue
			var score: float = Vector2(tile.global_position.x, tile.global_position.z).distance_to(
				Vector2(target.global_position.x, target.global_position.z)
			)
			if score < nearest_target_dist:
				nearest_target_dist = score
		if nearest_target_dist < best_score:
			best_score = nearest_target_dist
			best_tile = tile
	return best_tile

func _cleanup_defeated_units() -> void:
	_remove_dead_units_for(player)
	_remove_dead_units_for(opponent)

	if participant and participant.res:
		var reset_to_select_pawn: bool = false
		if participant.res.curr_pawn and (not is_instance_valid(participant.res.curr_pawn) or not participant.res.curr_pawn.is_alive()):
			participant.res.curr_pawn = null
			reset_to_select_pawn = true
		if participant.res.attackable_pawn and (not is_instance_valid(participant.res.attackable_pawn) or not participant.res.attackable_pawn.is_alive()):
			participant.res.attackable_pawn = null
			participant.res.selected_attack_datum = null
		if reset_to_select_pawn:
			_reset_player_selection_state()

func _remove_dead_units_for(team: Node3D) -> void:
	for child: Node in team.get_children():
		if not (child is TacticsPawn):
			continue
		var pawn: TacticsPawn = child as TacticsPawn
		if pawn.is_alive():
			continue
		_prepare_dead_pawn_for_removal(pawn)
		if camera.target == pawn:
			camera.target = null
		pawn.visible = false
		pawn.set_physics_process(false)
		pawn.set_process(false)
		pawn.call_deferred("queue_free")


func _reset_player_selection_state() -> void:
	if not participant or not participant.res:
		return
	participant.res.clear_attack_selection()
	participant.res.attackable_pawn = null
	participant.res.selected_attack_datum = null
	participant.res.stage = participant.res.STAGE_SELECT_PAWN
	if ui_control:
		ui_control.set_actions_menu_visibility(false, null)
		ui_control.set_attack_types_menu_visibility(false, null)
	if arena:
		arena.reset_all_tile_markers()


func _prepare_dead_pawn_for_removal(pawn: TacticsPawn) -> void:
	if not pawn:
		return
	if arena and arena.res:
		arena.res.release_all_move_tiles_for_pawn(pawn)
		arena.res.release_all_bump_tiles_for_pawn(pawn)
	if pawn.res:
		pawn.res.pathfinding_tilestack.clear()
		pawn.res.clear_move_transaction()
		pawn.res.set_moving(false)
		pawn.res.set_attacking(false)
		pawn.res.move_direction = Vector3.ZERO
	if pawn is CollisionObject3D:
		var pawn_collision: CollisionObject3D = pawn as CollisionObject3D
		pawn_collision.collision_layer = 0
		pawn_collision.collision_mask = 0
	for node: Node in pawn.find_children("*", "CollisionObject3D", true, false):
		var body: CollisionObject3D = node as CollisionObject3D
		if not body:
			continue
		body.collision_layer = 0
		body.collision_mask = 0
	for node: Node in pawn.find_children("*", "CollisionShape3D", true, false):
		var shape: CollisionShape3D = node as CollisionShape3D
		if not shape:
			continue
		shape.disabled = true

func _try_resolve_battle() -> bool:
	var alive_player_units: int = _count_alive_units(player)
	var alive_opponent_units: int = _count_alive_units(opponent)
	if alive_player_units > 0 and alive_opponent_units > 0:
		return false

	battle_over = true
	turn_stage = 0
	ui_control.set_actions_menu_visibility(false, null)

	var outcome: String = "Draw"
	if alive_player_units > alive_opponent_units:
		outcome = "Player Wins"
	elif alive_opponent_units > alive_player_units:
		outcome = "Opponent Wins"

	_show_result_message("%s (%d vs %d)" % [outcome, alive_player_units, alive_opponent_units])
	return true

func _count_alive_units(team: Node3D) -> int:
	var count: int = 0
	for child: Node in team.get_children():
		if not (child is TacticsPawn):
			continue
		var pawn: TacticsPawn = child as TacticsPawn
		if pawn.is_queued_for_deletion():
			continue
		if pawn.is_alive():
			count += 1
	return count

func _show_result_message(text: String) -> void:
	if not result_label:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "BattleResult"
		add_child(layer)

		var label: Label = Label.new()
		label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		label.offset_top = 24.0
		label.offset_left = -260.0
		label.offset_right = 260.0
		label.offset_bottom = 72.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 30)
		label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
		layer.add_child(label)
		result_label = label

		var replay_button: Button = Button.new()
		replay_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
		replay_button.offset_top = 88.0
		replay_button.offset_left = -80.0
		replay_button.offset_right = 80.0
		replay_button.offset_bottom = 128.0
		replay_button.text = "Replay"
		replay_button.pressed.connect(_on_replay_pressed)
		layer.add_child(replay_button)
		result_replay_button = replay_button

	result_label.text = text
	print("Battle resolved: ", text)


func _on_replay_pressed() -> void:
	if result_replay_button:
		result_replay_button.disabled = true
	get_tree().reload_current_scene()
#endregion
