extends Node2D

enum GameMode { GARAGE, BATTLE, RESULTS }
enum BattleOutcome { LOSS, WIN, DRAW }

const BattleBotScript = preload("res://scripts/battle_bot.gd")
const SAVE_PATH := "user://scrap_sprites.save"
const INK := Color("17332e")
const CREAM := Color("fff4d6")
const MINT := Color("b8e0c2")
const CORAL := Color("ff7f66")
const GOLD := Color("f2c14e")
const PLAYER_SPEED_MULTIPLIER := 1.2

const CHASSIS := [
	{"name": "Moss Bug", "tag": "Balanced", "hp": 135, "power": 7, "speed_mod": 1.0, "width": 150, "height": 72, "color": "68b684", "cost": 0},
	{"name": "Tin Kite", "tag": "Quick + roomy", "hp": 105, "power": 9, "speed_mod": 1.16, "width": 176, "height": 54, "color": "62b6cb", "cost": 90},
	{"name": "Brick Beetle", "tag": "Heavy armor", "hp": 195, "power": 6, "speed_mod": 0.76, "width": 132, "height": 96, "color": "d4775a", "cost": 145},
]
const WHEELS := [
	{"name": "Button Boots", "tag": "Steady", "speed": 78, "armor": 0, "power": 1, "radius": 25, "color": "f2c14e", "cost": 0},
	{"name": "Comet Rollers", "tag": "Very fast", "speed": 112, "armor": 0, "power": 2, "radius": 21, "color": "ff8c61", "cost": 70},
	{"name": "Tumble Treads", "tag": "+35 armor", "speed": 61, "armor": 35, "power": 2, "radius": 31, "color": "7c9eb2", "cost": 115},
]
const WEAPONS := [
	{"name": "Spark Fork", "tag": "Flips rivals", "damage": 15, "range": 126, "cooldown": 0.72, "power": 3, "kind": "lifter", "color": "ef476f", "cost": 0},
	{"name": "Buzz Bloom", "tag": "Fast melee", "damage": 10, "range": 116, "cooldown": 0.34, "power": 4, "kind": "melee", "color": "ff9f1c", "cost": 85},
	{"name": "Acorn Mortar", "tag": "Long range", "damage": 27, "range": 405, "cooldown": 1.55, "power": 5, "kind": "ranged", "color": "8a5cf6", "cost": 135},
]
const OPPONENTS := [
	{"name": "Moxie", "chassis": 0, "wheels": 0, "weapon": 0, "color": "e76f51", "rank": "Dandelion III"},
	{"name": "Pogo", "chassis": 1, "wheels": 1, "weapon": 1, "color": "577590", "rank": "Dandelion II"},
	{"name": "Juniper", "chassis": 2, "wheels": 0, "weapon": 2, "color": "9b5de5", "rank": "Dandelion I"},
]

var mode := GameMode.GARAGE
var scrap := 120
var trophies := 0
var win_streak := 0
var selected := {"chassis": 0, "wheels": 0, "weapons": 0}
var unlocked := {"chassis": [0], "wheels": [0], "weapons": [0]}
var ui: CanvasLayer
var preview_bot: Node2D
var player_bot: Node2D
var enemy_bot: Node2D
var battle_time := 0.0
var battle_started := false
var battle_finished := false
var collision_cooldown := 0.0
var opponent_index := 0
var opponent_level := 1
var pending_attacks: Array[Dictionary] = []
var resolving_attacks := false
var last_outcome := BattleOutcome.DRAW
var toast_label: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("153f3b"))
	_load_game()
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	show_garage()


func _process(delta: float) -> void:
	if mode != GameMode.BATTLE or battle_finished or not is_instance_valid(player_bot) or not is_instance_valid(enemy_bot):
		return
	_resolve_pending_attacks()
	if battle_finished:
		return
	if not battle_started:
		_update_battle_hud()
		return
	battle_time -= delta
	collision_cooldown = maxf(collision_cooldown - delta, 0.0)
	if battle_time <= 0.0:
		var health_gap: float = player_bot.health_ratio() - enemy_bot.health_ratio()
		if is_zero_approx(health_gap):
			_finish_battle(BattleOutcome.DRAW)
		else:
			_finish_battle(BattleOutcome.WIN if health_gap > 0.0 else BattleOutcome.LOSS)
		return
	if absf(player_bot.position.x - enemy_bot.position.x) < (player_bot.body_width + enemy_bot.body_width) * 0.43 and collision_cooldown <= 0.0:
		collision_cooldown = 0.22
		player_bot.bump(Vector2(-42.0, -70.0), -0.4)
		enemy_bot.bump(Vector2(42.0, -70.0), 0.4)
		player_bot.position.x -= 8.0
		enemy_bot.position.x += 8.0
	_update_battle_hud()
	queue_redraw()


func _draw() -> void:
	if mode == GameMode.GARAGE:
		_draw_garage_background()
	else:
		_draw_arena_background()


func show_garage() -> void:
	mode = GameMode.GARAGE
	_clear_world()
	_clear_ui()
	queue_redraw()

	var title := _label("SCRAP SPRITES", 36, INK)
	title.position = Vector2(34, 24)
	ui.add_child(title)
	var subtitle := _label("WORKSHOP RUMBLE", 16, Color("47756a"))
	subtitle.position = Vector2(38, 68)
	ui.add_child(subtitle)

	var currency := _pill("%d SCRAP" % scrap, GOLD, Vector2(500, 32), Vector2(188, 50), 20)
	ui.add_child(currency)
	var league := _pill("%d TROPHIES" % trophies, Color("d8eef2"), Vector2(516, 90), Vector2(154, 42), 17)
	ui.add_child(league)

	preview_bot = BattleBotScript.new()
	preview_bot.preview = true
	preview_bot.position = Vector2(370, 385)
	preview_bot.scale = Vector2(1.35, 1.35)
	preview_bot.configure("Pip", CHASSIS[selected.chassis], WHEELS[selected.wheels], WEAPONS[selected.weapons], Color("e05d8b"))
	add_child(preview_bot)

	var speech := _panel(Vector2(36, 160), Vector2(260, 122), Color("ffffff"), 24, Color("86b99f"), 4)
	ui.add_child(speech)
	var speech_text := _label("Pip says:\nBuild clever.\nBump louder!", 20, INK)
	speech_text.position = Vector2(22, 14)
	speech.add_child(speech_text)

	var power_used := int(WHEELS[selected.wheels].power) + int(WEAPONS[selected.weapons].power)
	var power_max := int(CHASSIS[selected.chassis].power)
	var stats_panel := _panel(Vector2(34, 510), Vector2(652, 58), Color("fff8e8"), 18, Color("86b99f"), 3)
	ui.add_child(stats_panel)
	var speed_bonus := roundi((PLAYER_SPEED_MULTIPLIER - 1.0) * 100.0)
	var stats := _label("%d HP  •  %d/%d POWER  •  %d HIT  •  +%d%% DRIVE" % [_selected_hp(), power_used, power_max, int(WEAPONS[selected.weapons].damage), speed_bonus], 18, INK)
	stats.position = Vector2(24, 13)
	stats_panel.add_child(stats)

	_build_part_row("CHASSIS", "chassis", CHASSIS, 594)
	_build_part_row("BUTTON BOOTS", "wheels", WHEELS, 776)
	_build_part_row("TOOLS", "weapons", WEAPONS, 958)

	var fight := _button("RUMBLE!", Vector2(210, 1160), Vector2(300, 72), CORAL, CREAM, 30)
	fight.pressed.connect(_on_rumble_pressed)
	ui.add_child(fight)
	toast_label = _label("", 16, INK)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.position = Vector2(100, 1124)
	toast_label.size = Vector2(520, 30)
	ui.add_child(toast_label)


func _build_part_row(heading: String, category: String, parts: Array, top: float) -> void:
	var heading_label := _label(heading, 17, Color("47756a"))
	heading_label.position = Vector2(36, top)
	ui.add_child(heading_label)
	for index in parts.size():
		var part: Dictionary = parts[index]
		var is_selected: bool = selected[category] == index
		var is_unlocked: bool = index in unlocked[category]
		var fits: bool = _selection_fits(category, index)
		var card_color := Color("dff4e4") if is_selected else (Color("fffaf0") if fits else Color("e4e5dc"))
		var card := _button("", Vector2(32 + index * 222, top + 30), Vector2(208, 128), card_color, INK, 18)
		card.add_theme_stylebox_override("normal", _box(card_color, 20, MINT if not is_selected else Color("3f8f69"), 4 if is_selected else 2))
		card.tooltip_text = "%s — %s — %s" % [part.name, part.tag, _part_stats(category, part)]
		card.pressed.connect(_on_part_pressed.bind(category, index))
		ui.add_child(card)
		var name_label := _label(str(part.name), 20, INK)
		name_label.position = Vector2(14, 12)
		card.add_child(name_label)
		var tag_label := _label(str(part.tag), 15, Color("47756a"))
		tag_label.position = Vector2(14, 39)
		card.add_child(tag_label)
		var stat_label := _label(_part_stats(category, part), 15, Color("405f57"))
		stat_label.position = Vector2(14, 65)
		card.add_child(stat_label)
		var status_text := "NEEDS %d POWER" % _candidate_power(category, index) if not fits else ("EQUIPPED" if is_selected else ("OWNED" if is_unlocked else "%d SCRAP" % int(part.cost)))
		var status_color := Color("8b4d45") if not fits else (Color("2b7a55") if is_unlocked else Color("b35f24"))
		var status := _label(status_text, 14, status_color)
		status.position = Vector2(14, 94)
		card.add_child(status)


func _on_part_pressed(category: String, index: int) -> void:
	var list: Array = _parts_for(category)
	var part: Dictionary = list[index]
	if not _selection_fits(category, index):
		_show_toast("Needs %d power; this chassis holds %d." % [_candidate_power(category, index), int(CHASSIS[selected.chassis].power)])
		return
	if index not in unlocked[category]:
		var cost := int(part.cost)
		if scrap < cost:
			_show_toast("Need %d more scrap." % (cost - scrap))
			return
		scrap -= cost
		unlocked[category].append(index)
	selected[category] = index
	_save_game()
	show_garage()


func _on_rumble_pressed() -> void:
	if not _loadout_has_power():
		_show_toast("Too much power. Swap a part first!")
		return
	start_battle()


func start_battle() -> void:
	mode = GameMode.BATTLE
	battle_started = false
	battle_finished = false
	battle_time = 24.0
	pending_attacks.clear()
	opponent_level = 1 + floori(float(trophies) / 3.0)
	opponent_index = (opponent_level - 1) % OPPONENTS.size()
	_clear_world()
	_clear_ui()
	queue_redraw()

	var opponent: Dictionary = OPPONENTS[opponent_index]
	if not _loadout_fits(int(opponent.chassis), int(opponent.wheels), int(opponent.weapon)):
		push_error("Opponent loadout exceeds its chassis power capacity")
		show_garage()
		return
	var opponent_chassis: Dictionary = CHASSIS[opponent.chassis].duplicate(true)
	var opponent_wheels: Dictionary = WHEELS[opponent.wheels].duplicate(true)
	var opponent_weapon: Dictionary = WEAPONS[opponent.weapon].duplicate(true)
	player_bot = BattleBotScript.new()
	player_bot.position = Vector2(140, 885)
	player_bot.floor_y = 885.0
	player_bot.configure("Pip", CHASSIS[selected.chassis], WHEELS[selected.wheels], WEAPONS[selected.weapons], Color("e05d8b"), 1.0, PLAYER_SPEED_MULTIPLIER)
	add_child(player_bot)
	enemy_bot = BattleBotScript.new()
	enemy_bot.position = Vector2(580, 885)
	enemy_bot.floor_y = 885.0
	enemy_bot.configure(str(opponent.name), opponent_chassis, opponent_wheels, opponent_weapon, Color(opponent.color), -1.0)
	add_child(enemy_bot)
	player_bot.target = enemy_bot
	enemy_bot.target = player_bot
	player_bot.defeated.connect(_on_bot_defeated)
	enemy_bot.defeated.connect(_on_bot_defeated)
	player_bot.attack_requested.connect(_queue_attack)
	enemy_bot.attack_requested.connect(_queue_attack)

	_build_battle_hud(str(opponent.name), "LEVEL %d • %s" % [opponent_level, opponent.rank])
	_start_countdown()


func _start_countdown() -> void:
	var countdown := _label("3", 92, CREAM)
	countdown.name = "Countdown"
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.position = Vector2(260, 385)
	countdown.size = Vector2(200, 120)
	ui.add_child(countdown)
	for number in [3, 2, 1]:
		if not is_instance_valid(countdown) or mode != GameMode.BATTLE:
			return
		countdown.text = str(number)
		countdown.scale = Vector2(1.25, 1.25)
		var tween := create_tween()
		tween.tween_property(countdown, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(0.72).timeout
	if not is_instance_valid(countdown) or mode != GameMode.BATTLE:
		return
	countdown.text = "RUMBLE!"
	countdown.add_theme_font_size_override("font_size", 48)
	battle_time = 24.0
	battle_started = true
	player_bot.active = true
	enemy_bot.active = true
	await get_tree().create_timer(0.65).timeout
	if is_instance_valid(countdown):
		countdown.queue_free()


func _build_battle_hud(opponent_name: String, rank: String) -> void:
	var banner := _panel(Vector2(22, 24), Vector2(676, 170), Color("fffaf0"), 28, Color("315c4a"), 4)
	banner.name = "BattleHud"
	ui.add_child(banner)
	var versus := _label("VS", 20, CORAL)
	versus.position = Vector2(323, 16)
	banner.add_child(versus)
	var left_name := _label("PIP", 24, INK)
	left_name.position = Vector2(24, 18)
	banner.add_child(left_name)
	var right_name := _label(opponent_name.to_upper(), 24, INK)
	right_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_name.position = Vector2(430, 18)
	right_name.size = Vector2(220, 35)
	banner.add_child(right_name)
	var rank_label := _label(rank, 14, Color("47756a"))
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.position = Vector2(430, 50)
	rank_label.size = Vector2(220, 24)
	banner.add_child(rank_label)
	for data in [{"name": "PlayerHealth", "x": 24}, {"name": "EnemyHealth", "x": 366}]:
		var bar := ProgressBar.new()
		bar.name = data.name
		bar.position = Vector2(data.x, 88)
		bar.size = Vector2(286, 34)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", _box(Color("d6e3dc"), 12))
		bar.add_theme_stylebox_override("fill", _box(CORAL if data.name == "EnemyHealth" else Color("3fa66a"), 12))
		banner.add_child(bar)
	var player_hp := _label("135 / 135 HP", 14, Color("315c4a"))
	player_hp.name = "PlayerHealthText"
	player_hp.position = Vector2(24, 126)
	banner.add_child(player_hp)
	var enemy_hp := _label("135 / 135 HP", 14, Color("315c4a"))
	enemy_hp.name = "EnemyHealthText"
	enemy_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_hp.position = Vector2(366, 126)
	enemy_hp.size = Vector2(286, 24)
	banner.add_child(enemy_hp)
	var timer_label := _pill("24", INK, Vector2(314, 206), Vector2(92, 48), 20)
	timer_label.name = "Timer"
	ui.add_child(timer_label)
	var leave := _button("‹ WORKSHOP", Vector2(26, 1180), Vector2(190, 54), Color("fffaf0"), INK, 17)
	leave.pressed.connect(show_garage)
	ui.add_child(leave)


func _update_battle_hud() -> void:
	var hud := ui.get_node_or_null("BattleHud")
	if hud == null:
		return
	hud.get_node("PlayerHealth").value = player_bot.health_ratio() * 100.0
	hud.get_node("EnemyHealth").value = enemy_bot.health_ratio() * 100.0
	hud.get_node("PlayerHealthText").text = "%d / %d HP" % [ceili(player_bot.hp), ceili(player_bot.max_hp)]
	hud.get_node("EnemyHealthText").text = "%d / %d HP" % [ceili(enemy_bot.hp), ceili(enemy_bot.max_hp)]
	var timer := ui.get_node_or_null("Timer")
	if timer != null:
		timer.text = str(ceili(battle_time))


func _queue_attack(attacker: Node2D, victim: Node2D, damage: float, force: Vector2, spin: float) -> void:
	if battle_finished:
		return
	pending_attacks.append({"attacker": attacker, "victim": victim, "damage": damage, "force": force, "spin": spin})


func _resolve_pending_attacks() -> void:
	if pending_attacks.is_empty():
		return
	var attacks := pending_attacks.duplicate()
	pending_attacks.clear()
	resolving_attacks = true
	for attack in attacks:
		var victim: Node2D = attack.victim
		if is_instance_valid(victim) and victim.hp > 0.0:
			victim.take_damage(float(attack.damage))
			victim.bump(attack.force, float(attack.spin))
	resolving_attacks = false
	_evaluate_battle_end()


func _on_bot_defeated(_bot: Node2D) -> void:
	if not resolving_attacks:
		call_deferred("_evaluate_battle_end")


func _evaluate_battle_end() -> void:
	if battle_finished or not is_instance_valid(player_bot) or not is_instance_valid(enemy_bot):
		return
	var player_defeated: bool = player_bot.hp <= 0.0
	var enemy_defeated: bool = enemy_bot.hp <= 0.0
	if player_defeated and enemy_defeated:
		_finish_battle(BattleOutcome.DRAW)
	elif enemy_defeated:
		_finish_battle(BattleOutcome.WIN)
	elif player_defeated:
		_finish_battle(BattleOutcome.LOSS)


func _finish_battle(outcome: int) -> void:
	if battle_finished:
		return
	battle_finished = true
	battle_started = false
	last_outcome = outcome
	if is_instance_valid(player_bot):
		player_bot.active = false
	if is_instance_valid(enemy_bot):
		enemy_bot.active = false
	var reward: int = _reward_for_outcome(outcome)
	scrap += reward
	if outcome == BattleOutcome.WIN:
		trophies += 1
		win_streak += 1
	elif outcome == BattleOutcome.LOSS:
		win_streak = 0
	_save_game()
	await get_tree().create_timer(0.8).timeout
	if mode == GameMode.BATTLE:
		show_results(outcome)


func show_results(outcome: int) -> void:
	mode = GameMode.RESULTS
	_clear_ui()
	queue_redraw()
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.09, 0.08, 0.72)
	shade.size = Vector2(720, 1280)
	ui.add_child(shade)
	var card := _panel(Vector2(74, 252), Vector2(572, 690), Color("fff8e8"), 36, Color("315c4a"), 6)
	ui.add_child(card)
	var result_text := "RUMBLE WON!" if outcome == BattleOutcome.WIN else ("HONORABLE DRAW!" if outcome == BattleOutcome.DRAW else "BACK TO THE BENCH")
	var result_color := Color("2b7a55") if outcome == BattleOutcome.WIN else (Color("8a641c") if outcome == BattleOutcome.DRAW else Color("ad5846"))
	var result := _label(result_text, 38, result_color)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.position = Vector2(30, 52)
	result.size = Vector2(512, 60)
	card.add_child(result)
	var flavor_text := "Pip's invention held together!" if outcome == BattleOutcome.WIN else ("Both builds gave it everything." if outcome == BattleOutcome.DRAW else "A few bolts loose. Try a new build!")
	var flavor := _label(flavor_text, 19, INK)
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.position = Vector2(30, 122)
	flavor.size = Vector2(512, 36)
	card.add_child(flavor)
	var loot := _panel(Vector2(94, 205), Vector2(384, 146), Color("ffedb7"), 24)
	card.add_child(loot)
	var loot_title := _label("WORKSHOP HAUL", 16, Color("8a641c"))
	loot_title.position = Vector2(110, 20)
	loot.add_child(loot_title)
	var reward: int = _reward_for_outcome(outcome)
	var loot_value := _label("+%d SCRAP" % reward, 30, INK)
	loot_value.position = Vector2(82, 62)
	loot.add_child(loot_value)
	var standing := _label("%d trophies   •   %d win streak" % [trophies, win_streak], 19, Color("47756a"))
	standing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	standing.position = Vector2(30, 390)
	standing.size = Vector2(512, 36)
	card.add_child(standing)
	var rematch := _button("RUMBLE AGAIN", Vector2(86, 468), Vector2(400, 72), CORAL, CREAM, 24)
	rematch.pressed.connect(start_battle)
	card.add_child(rematch)
	var garage := _button("CHANGE MY BUILD", Vector2(86, 560), Vector2(400, 66), Color("dff4e4"), INK, 20)
	garage.pressed.connect(show_garage)
	card.add_child(garage)


func _draw_garage_background() -> void:
	draw_rect(Rect2(0, 0, 720, 1280), Color("f4efd9"))
	# Workshop wall and bench.
	for y in range(110, 560, 64):
		draw_line(Vector2(0, y), Vector2(720, y), Color("d8ddc3"), 3.0)
	draw_rect(Rect2(0, 484, 720, 62), Color("9c6b4e"))
	draw_rect(Rect2(0, 538, 720, 28), Color("6c4938"))
	# Pip's leafy workshop helper portrait.
	draw_circle(Vector2(118, 354), 58, Color("e05d8b"))
	draw_circle(Vector2(98, 345), 7, INK)
	draw_circle(Vector2(137, 345), 7, INK)
	draw_arc(Vector2(118, 358), 20, 0.2, 2.9, 18, INK, 5)
	draw_colored_polygon(PackedVector2Array([Vector2(82, 309), Vector2(97, 272), Vector2(113, 315)]), Color("65a765"))
	draw_colored_polygon(PackedVector2Array([Vector2(126, 315), Vector2(150, 279), Vector2(154, 322)]), Color("65a765"))
	# Tiny tools make the space feel used without external art assets.
	draw_line(Vector2(610, 215), Vector2(610, 346), Color("486d64"), 10)
	draw_circle(Vector2(610, 204), 20, Color("f2c14e"))
	draw_line(Vector2(650, 255), Vector2(650, 357), Color("486d64"), 8)
	draw_arc(Vector2(650, 240), 20, 0.5, 2.6, 16, Color("ff7f66"), 9)


func _draw_arena_background() -> void:
	draw_rect(Rect2(0, 0, 720, 1280), Color("153f3b"))
	# Moonlit greenhouse arena, deliberately distinct from the reference game's streets.
	draw_circle(Vector2(602, 310), 94, Color("fff1b8"))
	for index in 7:
		var x := float(index * 130 - 80)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 760), Vector2(x + 95, 440 + (index % 2) * 80), Vector2(x + 190, 760)]), Color("275c51"))
	for index in 26:
		var x := fmod(float(index * 113), 720.0)
		var y := 225.0 + fmod(float(index * 79), 430.0)
		draw_circle(Vector2(x, y), 3.0 + float(index % 3), Color("d6f2c2"))
	draw_rect(Rect2(0, 908, 720, 372), Color("a6774e"))
	draw_rect(Rect2(0, 884, 720, 30), Color("e2c078"))
	for x in range(0, 720, 72):
		draw_line(Vector2(x, 915), Vector2(x + 36, 1280), Color(0.33, 0.21, 0.15, 0.22), 3)
	if mode == GameMode.BATTLE:
		var hint := "NO CONTROLS — YOUR BUILD DOES THE BATTLING"
		draw_string(ThemeDB.fallback_font, Vector2(148, 1120), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f3e9c3"))


func _selected_hp() -> int:
	return int(CHASSIS[selected.chassis].hp) + int(WHEELS[selected.wheels].armor)


func _loadout_has_power() -> bool:
	return _loadout_fits(int(selected.chassis), int(selected.wheels), int(selected.weapons))


func _candidate_power(category: String, index: int) -> int:
	var wheels_index: int = index if category == "wheels" else int(selected.wheels)
	var weapon_index: int = index if category == "weapons" else int(selected.weapons)
	return _loadout_power(wheels_index, weapon_index)


func _selection_fits(category: String, index: int) -> bool:
	var chassis_index: int = index if category == "chassis" else int(selected.chassis)
	var wheels_index: int = index if category == "wheels" else int(selected.wheels)
	var weapon_index: int = index if category == "weapons" else int(selected.weapons)
	return _loadout_fits(chassis_index, wheels_index, weapon_index)


func _loadout_power(wheels_index: int, weapon_index: int) -> int:
	return int(WHEELS[wheels_index].power) + int(WEAPONS[weapon_index].power)


func _loadout_fits(chassis_index: int, wheels_index: int, weapon_index: int) -> bool:
	return _loadout_power(wheels_index, weapon_index) <= int(CHASSIS[chassis_index].power)


func _part_stats(category: String, part: Dictionary) -> String:
	match category:
		"chassis":
			return "HP %d • CAP %d" % [int(part.hp), int(part.power)]
		"wheels":
			return "SPD %d • ARM %d • PWR %d" % [int(part.speed), int(part.armor), int(part.power)]
		_:
			return "HIT %d • RNG %d • PWR %d" % [int(part.damage), int(part.range), int(part.power)]


func _reward_for_outcome(outcome: int) -> int:
	match outcome:
		BattleOutcome.WIN:
			return 42 + (opponent_level - 1) * 8
		BattleOutcome.DRAW:
			return 20
		_:
			return 12


func _parts_for(category: String) -> Array:
	match category:
		"chassis": return CHASSIS
		"wheels": return WHEELS
		_: return WEAPONS


func _show_toast(message: String) -> void:
	if is_instance_valid(toast_label):
		toast_label.text = message
		var tween := create_tween()
		tween.tween_interval(2.0)
		tween.tween_callback(func():
			if is_instance_valid(toast_label):
				toast_label.text = ""
		)


func _clear_world() -> void:
	for bot in [preview_bot, player_bot, enemy_bot]:
		if is_instance_valid(bot):
			bot.queue_free()
	preview_bot = null
	player_bot = null
	enemy_bot = null


func _clear_ui() -> void:
	if ui == null:
		return
	for child in ui.get_children():
		child.queue_free()


func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	scrap = maxi(int(data.get("scrap", scrap)), 0)
	trophies = maxi(int(data.get("trophies", trophies)), 0)
	win_streak = maxi(int(data.get("win_streak", win_streak)), 0)
	var saved_selected: Dictionary = data.get("selected", {})
	var saved_unlocked: Dictionary = data.get("unlocked", {})
	for category in ["chassis", "wheels", "weapons"]:
		selected[category] = clampi(int(saved_selected.get(category, 0)), 0, 2)
		var items: Array = saved_unlocked.get(category, [0])
		unlocked[category] = items if not items.is_empty() else [0]


func _save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scrap": scrap, "trophies": trophies, "win_streak": win_streak, "selected": selected, "unlocked": unlocked}))


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel(position_value: Vector2, size_value: Vector2, color: Color, radius: int, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> Panel:
	var panel := Panel.new()
	panel.position = position_value
	panel.size = size_value
	panel.add_theme_stylebox_override("panel", _box(color, radius, border_color, border_width))
	return panel


func _pill(text_value: String, color: Color, position_value: Vector2, size_value: Vector2, font_size: int) -> Label:
	var label := _label(text_value, font_size, CREAM if color == INK else INK)
	label.position = position_value
	label.size = size_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _box(color, int(size_value.y / 2.0)))
	return label


func _button(text_value: String, position_value: Vector2, size_value: Vector2, color: Color, text_color: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = position_value
	button.size = size_value
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_stylebox_override("normal", _box(color, 22, Color("315c4a"), 3))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.08), 22, Color("315c4a"), 4))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.08), 22, Color("315c4a"), 4))
	return button


func _box(color: Color, radius: int, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_color = border_color
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	return box
