extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_resource: PackedScene = load("res://scenes/main.tscn")
	var game: Node = scene_resource.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if game.mode != game.GameMode.GARAGE or not is_instance_valid(game.preview_bot):
		_fail("Garage did not initialize with a vehicle preview")
		return
	var original_scrap: int = game.scrap
	var original_selected: Dictionary = game.selected.duplicate(true)
	var original_unlocked: Dictionary = game.unlocked.duplicate(true)
	game.scrap = 200
	game.selected = {"chassis": 2, "wheels": 2, "weapons": 0}
	game.unlocked = {"chassis": [0, 2], "wheels": [0, 2], "weapons": [0]}
	game._on_part_pressed("weapons", 2)
	if game.scrap != 200 or 2 in game.unlocked.weapons:
		_fail("Rejected over-capacity purchase changed currency or ownership")
		return
	game.scrap = original_scrap
	game.selected = {"chassis": 0, "wheels": 0, "weapons": 0}
	game.unlocked = original_unlocked
	for opponent in game.OPPONENTS:
		if not game._loadout_fits(int(opponent.chassis), int(opponent.wheels), int(opponent.weapon)):
			_fail("CPU loadout exceeds the same power capacity enforced for the player")
			return

	game.trophies = 27
	game.start_battle()
	await process_frame
	if game.mode != game.GameMode.BATTLE or not is_instance_valid(game.player_bot) or not is_instance_valid(game.enemy_bot):
		_fail("Battle did not initialize both autonomous vehicles")
		return
	if game.battle_started or not is_equal_approx(game.battle_time, 24.0):
		_fail("Countdown incorrectly consumed battle time")
		return
	var opponent: Dictionary = game.OPPONENTS[game.opponent_index]
	var expected_hp: float = float(game.CHASSIS[opponent.chassis].hp) + float(game.WHEELS[opponent.wheels].armor)
	if not is_equal_approx(game.enemy_bot.max_hp, expected_hp):
		_fail("CPU chassis or wheel stats differ from the player's equipment stats")
		return
	if not is_equal_approx(float(game.enemy_bot.weapon.damage), float(game.WEAPONS[opponent.weapon].damage)):
		_fail("CPU weapon stats differ from the player's equipment stats")
		return
	game.player_bot.active = true
	game.enemy_bot.active = true
	game.player_bot._attack()
	game.enemy_bot._attack()
	if game.pending_attacks.size() != 2:
		_fail("Attacks were not queued for simultaneous resolution")
		return
	var player_hp_before: float = game.player_bot.hp
	var enemy_hp_before: float = game.enemy_bot.hp
	game._resolve_pending_attacks()
	if not is_equal_approx(player_hp_before - game.player_bot.hp, enemy_hp_before - game.enemy_bot.hp):
		_fail("Mirror-match attacks did not resolve fairly")
		return

	game.show_results(game.BattleOutcome.WIN)
	await process_frame
	if game.mode != game.GameMode.RESULTS:
		_fail("Results screen did not initialize")
		return

	game.show_garage()
	await process_frame
	if game.mode != game.GameMode.GARAGE:
		_fail("Return-to-workshop flow failed")
		return
	game.selected = original_selected

	print("SMOKE PASS: garage -> battle -> results -> garage")
	quit(0)


func _fail(message: String) -> void:
	push_error("SMOKE FAIL: " + message)
	quit(1)
