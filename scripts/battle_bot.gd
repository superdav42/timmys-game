class_name BattleBot
extends Node2D

signal defeated(bot: BattleBot)
signal attack_requested(attacker: BattleBot, victim: BattleBot, damage: float, force: Vector2, spin: float)

var display_name := "Bot"
var chassis: Dictionary = {}
var wheels: Dictionary = {}
var weapon: Dictionary = {}
var pilot_color := Color.WHITE
var facing := 1.0
var active := false
var preview := false
var max_hp := 100.0
var hp := 100.0
var move_speed := 80.0
var attack_timer := 0.0
var hit_flash := 0.0
var shot_flash := 0.0
var target: BattleBot
var floor_y := 900.0
var vertical_velocity := 0.0
var spin_velocity := 0.0
var body_width := 145.0


func configure(bot_name: String, chassis_data: Dictionary, wheel_data: Dictionary, weapon_data: Dictionary, color: Color, direction: float = 1.0, speed_multiplier: float = 1.0) -> void:
	display_name = bot_name
	chassis = chassis_data
	wheels = wheel_data
	weapon = weapon_data
	pilot_color = color
	facing = direction
	max_hp = float(chassis.get("hp", 100)) + float(wheels.get("armor", 0))
	hp = max_hp
	move_speed = float(wheels.get("speed", 75)) * float(chassis.get("speed_mod", 1.0)) * speed_multiplier
	body_width = float(chassis.get("width", 145))
	queue_redraw()


func _process(delta: float) -> void:
	hit_flash = maxf(hit_flash - delta, 0.0)
	shot_flash = maxf(shot_flash - delta, 0.0)
	if preview or not active or hp <= 0.0 or not is_instance_valid(target):
		queue_redraw()
		return

	attack_timer -= delta
	var distance := absf(target.position.x - position.x)
	var desired_range := float(weapon.get("range", 120))
	if distance > desired_range * 0.82:
		position.x += facing * move_speed * delta
	else:
		position.x -= facing * move_speed * 0.13 * delta
	position.x = clampf(position.x, 70.0, 650.0)

	vertical_velocity += 980.0 * delta
	position.y += vertical_velocity * delta
	rotation += spin_velocity * delta
	spin_velocity = move_toward(spin_velocity, 0.0, delta * 1.8)
	if position.y >= floor_y:
		position.y = floor_y
		vertical_velocity = minf(vertical_velocity, 0.0)
		rotation = lerp_angle(rotation, 0.0, minf(delta * 4.5, 1.0))

	if distance <= desired_range and attack_timer <= 0.0:
		_attack()
	queue_redraw()


func _attack() -> void:
	if not is_instance_valid(target) or target.hp <= 0.0:
		return
	attack_timer = float(weapon.get("cooldown", 1.0))
	shot_flash = 0.16
	var dealt := float(weapon.get("damage", 10))
	var force := Vector2.ZERO
	var spin := 0.0
	if weapon.get("kind", "melee") == "lifter":
		force = Vector2(facing * 65.0, -240.0)
		spin = facing * 2.0
	elif weapon.get("kind", "melee") == "melee":
		force = Vector2(facing * 35.0, -95.0)
		spin = facing * 0.7
	attack_requested.emit(self, target, dealt, force, spin)


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	hit_flash = 0.13
	queue_redraw()
	if hp <= 0.0:
		active = false
		vertical_velocity = -180.0
		spin_velocity = -facing * 2.7
		defeated.emit(self)


func bump(force: Vector2, spin: float) -> void:
	position.x += force.x * 0.08
	vertical_velocity = minf(vertical_velocity, force.y)
	spin_velocity += spin


func health_ratio() -> float:
	return hp / maxf(max_hp, 1.0)


func _draw() -> void:
	var tint: Color = chassis.get("color", Color("72c091"))
	if hit_flash > 0.0:
		tint = Color.WHITE
	var width := float(chassis.get("width", 145))
	var height := float(chassis.get("height", 70))
	var wheel_radius := float(wheels.get("radius", 26))

	# Ground shadow.
	_draw_oval(Vector2(0, 24), Vector2(width * 0.58, 13), Color(0.05, 0.07, 0.06, 0.28))

	# Wheels sit behind the chassis and use a bright hub for readability.
	for wheel_x in [-width * 0.32, width * 0.32]:
		draw_circle(Vector2(wheel_x, 13), wheel_radius + 5.0, Color("263a36"))
		draw_circle(Vector2(wheel_x, 13), wheel_radius, Color(wheels.get("color", "e8c547")))
		draw_circle(Vector2(wheel_x, 13), wheel_radius * 0.42, Color("fff1c1"))
		for spoke in 4:
			var angle := rotation * 2.0 + spoke * TAU / 4.0
			draw_line(Vector2(wheel_x, 13), Vector2(wheel_x, 13) + Vector2.from_angle(angle) * wheel_radius * 0.7, Color("6c584c"), 3.0)

	# Original seed-pod chassis silhouette.
	var body_rect := Rect2(-width * 0.5, -height * 0.72, width, height)
	draw_style_box(_rounded_box(tint, 18.0, Color("315c4a"), 5), body_rect)
	draw_circle(Vector2(-facing * width * 0.18, -height * 0.7), 28.0, Color("f6d6a8"))
	draw_circle(Vector2(-facing * width * 0.12, -height * 0.76), 4.5, Color("24332d"))
	draw_arc(Vector2(-facing * width * 0.2, -height * 0.73), 10.0, 0.3, 2.3, 12, pilot_color, 6.0)

	# Chassis emblem and bolts.
	draw_circle(Vector2(0, -height * 0.34), 16.0, Color("fff0b8"))
	draw_circle(Vector2(0, -height * 0.34), 7.0, pilot_color)
	for bolt_x in [-width * 0.38, width * 0.38]:
		draw_circle(Vector2(bolt_x, -height * 0.18), 4.0, Color("d7e7cf"))

	_draw_weapon(width, height)


func _draw_weapon(width: float, height: float) -> void:
	var muzzle := Vector2(facing * width * 0.56, -height * 0.43)
	var kind: String = weapon.get("kind", "melee")
	var weapon_color := Color(weapon.get("color", "ff8c61"))
	if kind == "ranged":
		draw_line(Vector2(facing * width * 0.18, -height * 0.45), muzzle, Color("344e5c"), 16.0)
		draw_circle(muzzle, 12.0, weapon_color)
		if shot_flash > 0.0:
			draw_line(muzzle, Vector2(facing * 420.0, -height * 0.43), Color(1.0, 0.86, 0.35, shot_flash * 5.0), 10.0)
			draw_circle(muzzle + Vector2(facing * 18.0, 0), 17.0, Color("fff2a8"))
	elif kind == "lifter":
		var tip := Vector2(facing * (width * 0.72), -height * 0.02)
		draw_line(Vector2(facing * width * 0.27, -height * 0.12), tip, weapon_color, 12.0)
		draw_line(tip, tip + Vector2(facing * 20.0, -35.0), weapon_color, 9.0)
	else:
		var center := Vector2(facing * width * 0.48, -height * 0.38)
		draw_line(Vector2(facing * width * 0.16, -height * 0.42), center, Color("344e5c"), 13.0)
		draw_circle(center, 28.0, weapon_color)
		for tooth in 8:
			var angle := tooth * TAU / 8.0 + Time.get_ticks_msec() * 0.006 * facing
			var inner := center + Vector2.from_angle(angle) * 24.0
			var outer := center + Vector2.from_angle(angle) * 36.0
			draw_line(inner, outer, weapon_color, 8.0)


func _draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 24:
		var angle := index * TAU / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _rounded_box(color: Color, radius: float, border_color: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = int(radius)
	box.corner_radius_top_right = int(radius)
	box.corner_radius_bottom_left = int(radius)
	box.corner_radius_bottom_right = int(radius)
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.border_color = border_color
	return box
