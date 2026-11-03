extends Node2D

const Data = preload("res://scripts/game_data.gd")

signal notice(text: String)
signal dock_requested
signal destruction_requested
signal travelled

var profile: Dictionary = {}
var stats: Dictionary = {}
var system_id := "haven"
var system: Dictionary = {}
var player: Dictionary = {}
var enemies: Array = []
var asteroids: Array = []
var loot: Array = []
var effects: Array = []
var stars: Array = []

var active := false
var input_vector := Vector2.ZERO
var firing := false
var mining := false
var auto_orbit := false
var auto_dock := false
var route_destination := ""
var target_kind := ""
var target_id := -1
var camera_pos := Vector2.ZERO
var visual_time := 0.0
var zoom := 1.0
var view_size := Vector2(1280, 720)
var next_id := 1
var respawn_timer := 20.0
var mine_accumulator := 0.0
var font: Font
var station_position := Vector2.ZERO
var gate_position := Vector2(1600, -650)
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	font = ThemeDB.fallback_font
	rng.seed = 90210
	for i in range(230):
		stars.append({
			"uv": Vector2(rng.randf(), rng.randf()),
			"depth": rng.randf_range(0.08, 0.75),
			"size": rng.randf_range(0.5, 1.9),
			"alpha": rng.randf_range(0.25, 0.9)
		})
	set_process_unhandled_input(true)

func setup(data: Dictionary, restore_position := true) -> void:
	profile = Data.normalize_profile(data)
	player = {}
	load_system(str(profile["current_system"]), false, restore_position)
	active = false

func load_system(id: String, from_gate := false, restore_position := false) -> void:
	if not Data.SYSTEMS.has(id):
		id = "haven"
	var old_condition: Dictionary = player.get("condition", {}).duplicate(true)
	system_id = id
	system = Data.SYSTEMS[id]
	profile["current_system"] = id
	stats = Data.ship_stats(profile)
	target_kind = ""
	target_id = -1
	firing = false
	mining = false
	auto_orbit = false
	auto_dock = false
	route_destination = ""
	enemies.clear()
	asteroids.clear()
	loot.clear()
	effects.clear()
	rng.seed = int(system["seed"])
	_generate_asteroids()
	_generate_enemies()
	respawn_timer = 22.0
	var spawn := Vector2(320, 80)
	if from_gate:
		spawn = gate_position + Vector2(-330, 90)
	elif restore_position and profile.has("player_position"):
		var saved: Array = profile["player_position"]
		if saved.size() == 2:
			spawn = Vector2(float(saved[0]), float(saved[1]))
	var condition: Dictionary = profile.get("player_condition", {})
	if not condition is Dictionary:
		condition = {}
	player = {
		"pos": spawn,
		"vel": Vector2.ZERO,
		"angle": -0.2,
		"shield": float(condition.get("shield", stats["shield"])),
		"armor": float(condition.get("armor", stats["armor"])),
		"hull": float(condition.get("hull", stats["hull"])),
		"energy": float(condition.get("energy", stats["energy"])),
		"fire_cooldown": 0.0,
		"since_damage": 99.0,
		"condition": old_condition
	}
	player["shield"] = clampf(player["shield"], 0.0, stats["shield"])
	player["armor"] = clampf(player["armor"], 0.0, stats["armor"])
	player["hull"] = clampf(player["hull"], 1.0, stats["hull"])
	player["energy"] = clampf(player["energy"], 0.0, stats["energy"])
	camera_pos = spawn
	queue_redraw()

func _generate_asteroids() -> void:
	var count := int(system["asteroids"])
	for i in range(count):
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(180.0, 950.0)
		var pos := Vector2(-480, 600) + Vector2.from_angle(angle) * distance
		if pos.distance_to(station_position) < 420:
			pos += Vector2(-350, 250)
		var resource_id := "ferrite"
		if rng.randf() < (0.24 if system_id != "umbra" else 0.38):
			resource_id = "crystal"
		var amount := rng.randi_range(24, 58)
		var sides := rng.randi_range(7, 11)
		var shape := PackedVector2Array()
		for p in range(sides):
			var a := TAU * float(p) / float(sides)
			var r := rng.randf_range(25.0, 46.0)
			shape.append(Vector2.from_angle(a) * r)
		asteroids.append({
			"id": next_id,
			"pos": pos,
			"resource": resource_id,
			"amount": amount,
			"max_amount": amount,
			"radius": 40.0,
			"shape": shape,
			"rotation": rng.randf_range(0.0, TAU)
		})
		next_id += 1

func _generate_enemies() -> void:
	for i in range(int(system["pirates"])):
		_spawn_enemy(i)

func _spawn_enemy(index := 0) -> void:
	var angle := rng.randf_range(0.0, TAU)
	var pos := Vector2(760, 560) + Vector2.from_angle(angle) * rng.randf_range(180.0, 720.0)
	if index % 3 == 0:
		pos += Vector2(500, -650)
	var danger := 1.0 - float(system["security"])
	var elite := system_id == "umbra" and index == 0
	var shield := (70.0 + danger * 60.0) * (1.7 if elite else 1.0)
	var hull := (45.0 + danger * 35.0) * (1.6 if elite else 1.0)
	enemies.append({
		"id": next_id,
		"name": "Revenant Captain" if elite else ("Corsair %02d" % next_id),
		"pos": pos,
		"vel": Vector2.ZERO,
		"angle": rng.randf_range(-PI, PI),
		"shield": shield,
		"max_shield": shield,
		"hull": hull,
		"max_hull": hull,
		"speed": 150.0 + danger * 55.0,
		"damage": (6.0 + danger * 5.0) * (1.3 if elite else 1.0),
		"cooldown": rng.randf_range(0.0, 1.0),
		"aggro": false,
		"elite": elite,
		"flash": 0.0
	})
	next_id += 1

func set_active(value: bool) -> void:
	active = value
	if not active:
		firing = false
		mining = false
		input_vector = Vector2.ZERO

func update_saved_state() -> void:
	if player.is_empty():
		return
	profile["player_position"] = [player["pos"].x, player["pos"].y]
	profile["player_condition"] = {
		"shield": player["shield"],
		"armor": player["armor"],
		"hull": player["hull"],
		"energy": player["energy"]
	}

func apply_upgrades() -> void:
	var old_stats := stats
	stats = Data.ship_stats(profile)
	if not player.is_empty():
		for key in ["shield", "armor", "hull", "energy"]:
			var old_max := float(old_stats.get(key, stats[key]))
			var gain := maxf(0.0, float(stats[key]) - old_max)
			player[key] = minf(float(stats[key]), float(player[key]) + gain)

func repair_and_recharge() -> void:
	if player.is_empty():
		return
	stats = Data.ship_stats(profile)
	player["shield"] = stats["shield"]
	player["armor"] = stats["armor"]
	player["hull"] = stats["hull"]
	player["energy"] = stats["energy"]
	player["since_damage"] = 99.0

func respawn_at_station() -> void:
	stats = Data.ship_stats(profile)
	player["pos"] = station_position + Vector2(330, 70)
	player["vel"] = Vector2.ZERO
	player["shield"] = stats["shield"]
	player["armor"] = stats["armor"]
	player["hull"] = stats["hull"]
	player["energy"] = stats["energy"]
	player["since_damage"] = 99.0
	camera_pos = player["pos"]
	target_kind = ""
	target_id = -1
	auto_orbit = false
	auto_dock = false
	route_destination = ""

func cargo_free() -> int:
	if stats.is_empty():
		return 0
	return maxi(0, int(stats["cargo"]) - Data.cargo_used(profile))

func add_cargo(resource_id: String, amount: int) -> int:
	var accepted := mini(maxi(0, amount), cargo_free())
	if accepted > 0:
		profile["cargo"][resource_id] = int(profile["cargo"].get(resource_id, 0)) + accepted
	return accepted

func remove_cargo(resource_id: String, amount: int) -> bool:
	if int(profile["cargo"].get(resource_id, 0)) < amount:
		return false
	profile["cargo"][resource_id] -= amount
	return true

func station_distance() -> float:
	return player.get("pos", Vector2.ZERO).distance_to(station_position)

func gate_distance() -> float:
	return player.get("pos", Vector2.ZERO).distance_to(gate_position)

func target_distance() -> float:
	var target := get_target()
	if target.is_empty() or player.is_empty():
		return -1.0
	return float(player["pos"].distance_to(target["pos"]))

func get_target() -> Dictionary:
	if target_id < 0:
		return {}
	var source: Array = enemies if target_kind == "enemy" else asteroids
	for entity in source:
		if int(entity["id"]) == target_id:
			return entity
	return {}

func cycle_target() -> void:
	var candidates: Array = []
	for enemy in enemies:
		candidates.append({"kind": "enemy", "id": enemy["id"], "distance": player["pos"].distance_to(enemy["pos"])})
	for asteroid in asteroids:
		candidates.append({"kind": "asteroid", "id": asteroid["id"], "distance": player["pos"].distance_to(asteroid["pos"])})
	candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])
	if candidates.is_empty():
		target_kind = ""
		target_id = -1
		return
	var current := -1
	for i in range(candidates.size()):
		if int(candidates[i]["id"]) == target_id and candidates[i]["kind"] == target_kind:
			current = i
			break
	var next: Dictionary = candidates[(current + 1) % candidates.size()]
	target_kind = next["kind"]
	target_id = next["id"]
	announce_target()

func announce_target() -> void:
	var target := get_target()
	if target.is_empty():
		return
	if target_kind == "enemy":
		notice.emit("Target locked · " + str(target["name"]))
	else:
		notice.emit("Asteroid selected · " + str(Data.RESOURCES[target["resource"]]["name"]))

func toggle_fire() -> void:
	firing = not firing
	if firing:
		if target_kind != "enemy" or get_target().is_empty():
			var nearest := _nearest_enemy()
			if not nearest.is_empty():
				target_kind = "enemy"
				target_id = nearest["id"]
		if get_target().is_empty():
			firing = false
			notice.emit("No pirate target available")
		else:
			notice.emit("Pulse laser engaged")

func toggle_mine() -> void:
	mining = not mining
	if mining:
		if target_kind != "asteroid" or get_target().is_empty():
			var nearest := _nearest_asteroid()
			if not nearest.is_empty():
				target_kind = "asteroid"
				target_id = nearest["id"]
		if get_target().is_empty():
			mining = false
			notice.emit("No asteroid available")
			return
		auto_orbit = true
		auto_dock = false
		route_destination = ""
		notice.emit("Mining laser engaged")
	else:
		mine_accumulator = 0.0

func toggle_orbit() -> void:
	auto_orbit = not auto_orbit
	if auto_orbit:
		auto_dock = false
		route_destination = ""
		if get_target().is_empty():
			auto_orbit = false
			notice.emit("Select a ship or asteroid first")
		else:
			notice.emit("Automatic orbit engaged")
	else:
		notice.emit("Manual flight control")

func request_dock() -> void:
	if station_distance() <= 285.0:
		_complete_docking()
	else:
		auto_dock = true
		auto_orbit = false
		route_destination = ""
		mining = false
		firing = false
		notice.emit("Approach vector plotted · " + str(system["station"]))

func _complete_docking() -> void:
	auto_dock = false
	player["vel"] = Vector2.ZERO
	repair_and_recharge()
	update_saved_state()
	dock_requested.emit()

func plot_course(destination: String) -> bool:
	if not system["connections"].has(destination):
		notice.emit("No direct gate route to that system")
		return false
	route_destination = destination
	auto_dock = false
	auto_orbit = false
	mining = false
	firing = false
	notice.emit("Gate course plotted · " + str(Data.SYSTEMS[destination]["name"]))
	return true

func clear_course() -> void:
	route_destination = ""
	auto_dock = false
	auto_orbit = false

func _nearest_enemy() -> Dictionary:
	var result: Dictionary = {}
	var best := INF
	for enemy in enemies:
		var d: float = player["pos"].distance_to(enemy["pos"])
		if d < best:
			best = d
			result = enemy
	return result

func _nearest_asteroid() -> Dictionary:
	var result: Dictionary = {}
	var best := INF
	for asteroid in asteroids:
		if int(asteroid["amount"]) <= 0:
			continue
		var d: float = player["pos"].distance_to(asteroid["pos"])
		if d < best:
			best = d
			result = asteroid
	return result

func _unhandled_input(event: InputEvent) -> void:
	if not active or player.is_empty():
		return
	if event is InputEventScreenTouch and event.pressed:
		_select_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_at(event.position)

func _select_at(screen_position: Vector2) -> void:
	var world_position := screen_to_world(screen_position)
	var best := 90.0
	var found_kind := ""
	var found_id := -1
	for enemy in enemies:
		var d: float = world_position.distance_to(enemy["pos"])
		if d < best:
			best = d
			found_kind = "enemy"
			found_id = enemy["id"]
	for asteroid in asteroids:
		var d: float = world_position.distance_to(asteroid["pos"])
		if d < best:
			best = d
			found_kind = "asteroid"
			found_id = asteroid["id"]
	if world_position.distance_to(station_position) < 150.0 and station_distance() < 1200.0:
		request_dock()
		return
	if world_position.distance_to(gate_position) < 150.0:
		notice.emit("Jump gate · use the galaxy map to plot a route")
		return
	if found_id >= 0:
		target_kind = found_kind
		target_id = found_id
		auto_dock = false
		route_destination = ""
		announce_target()

func screen_to_world(screen_position: Vector2) -> Vector2:
	view_size = get_viewport_rect().size
	return (screen_position - view_size * 0.5) / zoom + camera_pos

func world_to_screen(world_position: Vector2) -> Vector2:
	return (world_position - camera_pos) * zoom + view_size * 0.5

func _process(delta: float) -> void:
	visual_time += delta
	view_size = get_viewport_rect().size
	queue_redraw()

func _physics_process(delta: float) -> void:
	if active and not player.is_empty():
		simulate(delta)

func simulate(delta: float) -> void:
	if player.is_empty():
		return
	profile["play_seconds"] = float(profile.get("play_seconds", 0.0)) + delta
	player["fire_cooldown"] = maxf(0.0, float(player["fire_cooldown"]) - delta)
	player["since_damage"] = float(player["since_damage"]) + delta
	player["energy"] = minf(float(stats["energy"]), float(player["energy"]) + 15.0 * delta)
	if player["since_damage"] > 4.5:
		player["shield"] = minf(float(stats["shield"]), float(player["shield"]) + 8.0 * delta)
	var movement := input_vector
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keyboard.length() > 0.05:
		movement = keyboard
		clear_course()
	var desired_direction := Vector2.ZERO
	var desired_speed := 0.0
	if route_destination != "":
		var route := _navigation_direction(gate_position, 165.0, false)
		desired_direction = route
		desired_speed = float(stats["speed"]) * 0.90
		if gate_distance() < 215.0:
			var destination := route_destination
			load_system(destination, true, false)
			notice.emit("Jump complete · " + str(system["name"]))
			travelled.emit()
			return
	elif auto_dock:
		desired_direction = _navigation_direction(station_position, 205.0, false)
		desired_speed = float(stats["speed"]) * 0.80
		if station_distance() < 250.0:
			_complete_docking()
			return
	elif auto_orbit and not get_target().is_empty():
		var target := get_target()
		var optimal := 330.0 if target_kind == "enemy" else 185.0
		desired_direction = _navigation_direction(target["pos"], optimal, true)
		desired_speed = float(stats["speed"]) * 0.72
	elif movement.length() > 0.05:
		desired_direction = movement.normalized()
		desired_speed = float(stats["speed"]) * minf(1.0, movement.length())
	var desired_velocity := desired_direction * desired_speed
	var acceleration := float(stats["acceleration"])
	player["vel"] = player["vel"].move_toward(desired_velocity, acceleration * delta)
	if desired_speed == 0.0:
		player["vel"] = player["vel"].move_toward(Vector2.ZERO, 55.0 * delta)
	player["pos"] += player["vel"] * delta
	player["pos"].x = clampf(player["pos"].x, -2300.0, 2300.0)
	player["pos"].y = clampf(player["pos"].y, -1800.0, 1800.0)
	if player["vel"].length() > 12.0:
		player["angle"] = lerp_angle(float(player["angle"]), player["vel"].angle(), minf(1.0, delta * 7.0))
	_resolve_asteroid_collisions()
	_update_weapons(delta)
	_update_mining(delta)
	_update_enemies(delta)
	_update_loot(delta)
	_update_effects(delta)
	respawn_timer -= delta
	if respawn_timer <= 0.0:
		respawn_timer = 24.0
		if enemies.size() < int(system["pirates"]):
			_spawn_enemy(rng.randi_range(0, 5))
	camera_pos = camera_pos.lerp(player["pos"], 1.0 - exp(-delta * 5.5))
	if get_target().is_empty() and target_id >= 0:
		target_kind = ""
		target_id = -1
		firing = false
		mining = false

func _navigation_direction(destination: Vector2, optimal: float, orbit: bool) -> Vector2:
	var offset: Vector2 = destination - player["pos"]
	var distance := offset.length()
	if distance < 1.0:
		return Vector2.ZERO
	var direction := offset / distance
	if not orbit:
		if distance <= optimal:
			return Vector2.ZERO
		return direction
	if distance > optimal + 55.0:
		return direction
	if distance < optimal - 45.0:
		return -direction
	var tangent := Vector2(-direction.y, direction.x)
	return (tangent + direction * 0.08).normalized()

func _resolve_asteroid_collisions() -> void:
	for asteroid in asteroids:
		var offset: Vector2 = player["pos"] - asteroid["pos"]
		var minimum := float(asteroid["radius"]) + 19.0
		var distance := offset.length()
		if distance < minimum and distance > 0.1:
			var normal := offset / distance
			player["pos"] = asteroid["pos"] + normal * minimum
			player["vel"] = player["vel"].bounce(normal) * 0.25

func _update_weapons(_delta: float) -> void:
	var should_fire := firing or Input.is_action_pressed("fire")
	if not should_fire or target_kind != "enemy":
		return
	var target := get_target()
	if target.is_empty():
		return
	var distance: float = player["pos"].distance_to(target["pos"])
	if distance > float(stats["range"]) or float(player["fire_cooldown"]) > 0.0:
		return
	if float(player["energy"]) < 8.0:
		return
	player["energy"] -= 8.0
	player["fire_cooldown"] = stats["fire_interval"]
	target["flash"] = 0.16
	effects.append({"from": player["pos"], "to": target["pos"], "ttl": 0.12, "max_ttl": 0.12, "color": Color("62efff"), "width": 3.0})
	_damage_enemy(target, float(stats["damage"]))

func _damage_enemy(enemy: Dictionary, amount: float) -> void:
	var remaining := amount
	if float(enemy["shield"]) > 0.0:
		var absorbed := minf(float(enemy["shield"]), remaining)
		enemy["shield"] -= absorbed
		remaining -= absorbed
	if remaining > 0.0:
		enemy["hull"] -= remaining
	enemy["aggro"] = true
	if float(enemy["hull"]) <= 0.0:
		_destroy_enemy(enemy)

func _destroy_enemy(enemy: Dictionary) -> void:
	var enemy_id := int(enemy["id"])
	var death_pos: Vector2 = enemy["pos"]
	for i in range(enemies.size() - 1, -1, -1):
		if int(enemies[i]["id"]) == enemy_id:
			enemies.remove_at(i)
			break
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		effects.append({"from": death_pos, "to": death_pos + Vector2.from_angle(angle) * 85.0, "ttl": 0.55, "max_ttl": 0.55, "color": Color("ff9b69"), "width": 2.0})
	var salvage := 3 + (3 if enemy["elite"] else 0)
	loot.append({"id": next_id, "pos": death_pos, "resource": "salvage", "amount": salvage, "rotation": 0.0})
	next_id += 1
	profile["total_kills"] = int(profile["total_kills"]) + 1
	var bounty: Dictionary = profile["contracts"]["bounty"]
	if bounty["accepted"] and not bounty["completed"]:
		bounty["progress"] = mini(int(Data.CONTRACTS["bounty"]["target"]), int(bounty["progress"]) + 1)
		notice.emit("Pirate destroyed · contract %d/%d" % [bounty["progress"], int(Data.CONTRACTS["bounty"]["target"])])
	else:
		notice.emit("Pirate destroyed · salvage ejected")
	if target_id == enemy_id:
		target_id = -1
		target_kind = ""
		firing = false
		auto_orbit = false

func _update_mining(delta: float) -> void:
	if not mining or target_kind != "asteroid":
		return
	var target := get_target()
	if target.is_empty():
		mining = false
		return
	if player["pos"].distance_to(target["pos"]) > 265.0 or float(player["energy"]) <= 1.0 or cargo_free() <= 0:
		if cargo_free() <= 0:
			mining = false
			notice.emit("Cargo hold full · return to a station")
		return
	player["energy"] = maxf(0.0, float(player["energy"]) - 3.5 * delta)
	mine_accumulator += float(stats["mining_rate"]) * delta
	while mine_accumulator >= 1.0 and int(target["amount"]) > 0 and cargo_free() > 0:
		mine_accumulator -= 1.0
		target["amount"] -= 1
		add_cargo(str(target["resource"]), 1)
		profile["total_mined"] = int(profile["total_mined"]) + 1
	if int(target["amount"]) <= 0:
		notice.emit("Asteroid depleted")
		target_id = -1
		target_kind = ""
		mining = false
		auto_orbit = false

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		enemy["cooldown"] = maxf(0.0, float(enemy["cooldown"]) - delta)
		enemy["flash"] = maxf(0.0, float(enemy["flash"]) - delta)
		var offset: Vector2 = player["pos"] - enemy["pos"]
		var distance := offset.length()
		if distance < 900.0:
			enemy["aggro"] = true
		var desired := Vector2.ZERO
		if enemy["aggro"] and distance > 1.0:
			var direction := offset / distance
			if distance > 440.0:
				desired = direction * float(enemy["speed"])
			elif distance < 250.0:
				desired = -direction * float(enemy["speed"]) * 0.7
			else:
				desired = Vector2(-direction.y, direction.x) * float(enemy["speed"]) * 0.55
			if distance < 540.0 and float(enemy["cooldown"]) <= 0.0:
				enemy["cooldown"] = 1.15 if not enemy["elite"] else 0.85
				effects.append({"from": enemy["pos"], "to": player["pos"], "ttl": 0.16, "max_ttl": 0.16, "color": Color("ff8b65"), "width": 2.5})
				_damage_player(float(enemy["damage"]))
				if not active:
					return
		enemy["vel"] = enemy["vel"].move_toward(desired, 160.0 * delta)
		enemy["pos"] += enemy["vel"] * delta
		if enemy["vel"].length() > 8.0:
			enemy["angle"] = lerp_angle(float(enemy["angle"]), enemy["vel"].angle(), minf(1.0, delta * 4.0))

func _damage_player(amount: float) -> void:
	player["since_damage"] = 0.0
	var remaining := amount
	if float(player["shield"]) > 0.0:
		var absorbed := minf(float(player["shield"]), remaining)
		player["shield"] -= absorbed
		remaining -= absorbed
	if remaining > 0.0 and float(player["armor"]) > 0.0:
		var absorbed := minf(float(player["armor"]), remaining)
		player["armor"] -= absorbed
		remaining -= absorbed
	if remaining > 0.0:
		player["hull"] -= remaining
	if float(player["hull"]) <= 0.0:
		player["hull"] = 0.0
		active = false
		firing = false
		mining = false
		destruction_requested.emit()

func _update_loot(delta: float) -> void:
	for i in range(loot.size() - 1, -1, -1):
		var item: Dictionary = loot[i]
		item["rotation"] = float(item["rotation"]) + delta
		if player["pos"].distance_to(item["pos"]) < 55.0:
			var accepted := add_cargo(str(item["resource"]), int(item["amount"]))
			if accepted > 0:
				notice.emit("Recovered %d %s" % [accepted, str(Data.RESOURCES[item["resource"]]["name"])])
			if accepted >= int(item["amount"]):
				loot.remove_at(i)
			else:
				item["amount"] = int(item["amount"]) - accepted

func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["ttl"] = float(effects[i]["ttl"]) - delta
		if float(effects[i]["ttl"]) <= 0.0:
			effects.remove_at(i)

func _draw() -> void:
	view_size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view_size), Color("030811"))
	_draw_background()
	if system.is_empty() or player.is_empty():
		return
	var origin := view_size * 0.5 - camera_pos * zoom
	draw_set_transform(origin, 0.0, Vector2(zoom, zoom))
	_draw_nebula()
	_draw_planet()
	_draw_station()
	_draw_gate()
	for asteroid in asteroids:
		_draw_asteroid(asteroid)
	for item in loot:
		_draw_loot(item)
	for enemy in enemies:
		_draw_enemy(enemy)
	_draw_player()
	_draw_effects()
	_draw_targeting()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_background() -> void:
	for star in stars:
		var uv: Vector2 = star["uv"]
		var depth: float = star["depth"]
		var drift := camera_pos * depth * 0.035
		var p := Vector2(
			fposmod(uv.x * view_size.x - drift.x, view_size.x),
			fposmod(uv.y * view_size.y - drift.y, view_size.y)
		)
		var color := Color(0.65, 0.86, 1.0, float(star["alpha"]))
		draw_circle(p, float(star["size"]), color)
		if float(star["size"]) > 1.6:
			draw_line(p - Vector2(4, 0), p + Vector2(4, 0), Color(color, 0.25), 1.0)

func _draw_nebula() -> void:
	var base := Color(str(system["nebula"]))
	for i in range(5, 0, -1):
		var c := Color(base, 0.018 * float(6 - i))
		draw_circle(Vector2(-850, -250), 350.0 + i * 150.0, c)
	var accent := Color(str(system["accent"]))
	draw_arc(Vector2(-850, -250), 690.0, -1.0, 1.7, 90, Color(accent, 0.035), 110.0, true)

func _draw_planet() -> void:
	var center := Vector2(-1180, -1030)
	var accent := Color(str(system["accent"]))
	draw_circle(center + Vector2(18, 25), 192, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(center, 180, Color("101d31"))
	draw_circle(center + Vector2(-25, -25), 155, Color(accent, 0.16))
	draw_arc(center, 182, 0.0, TAU, 100, Color(accent, 0.32), 3.0, true)
	draw_arc(center, 245, -2.8, 0.5, 90, Color(accent, 0.20), 9.0, true)
	draw_arc(center, 267, -2.7, 0.3, 90, Color(accent, 0.08), 3.0, true)

func _draw_station() -> void:
	var accent := Color(str(system["accent"]))
	var rotation := visual_time * 0.08
	draw_circle(station_position, 115, Color(accent, 0.025))
	draw_arc(station_position, 96, rotation, rotation + 4.8, 64, Color(accent, 0.32), 5.0, true)
	draw_arc(station_position, 73, -rotation * 1.7, -rotation * 1.7 + 4.2, 56, Color(accent, 0.50), 3.0, true)
	var points := PackedVector2Array()
	for i in range(6):
		points.append(station_position + Vector2.from_angle(TAU * i / 6.0 + rotation) * 48.0)
	draw_colored_polygon(points, Color("102b3a"))
	points.append(points[0])
	draw_polyline(points, Color(accent, 0.75), 2.0, true)
	draw_circle(station_position, 15, Color(accent, 0.55))
	draw_circle(station_position, 7, Color("d4fcff"))
	_draw_world_label(station_position + Vector2(-100, 135), str(system["station"]), accent)

func _draw_gate() -> void:
	var accent := Color(str(system["accent"]))
	var pulse := 0.5 + sin(visual_time * 2.0) * 0.15
	draw_circle(gate_position, 68, Color(accent, 0.04))
	for i in range(3):
		var start := visual_time * (0.35 + i * 0.12) + i * 1.7
		draw_arc(gate_position, 46.0 + i * 15.0, start, start + 4.3, 42, Color(accent, 0.24 + i * 0.12), 3.0, true)
	draw_circle(gate_position, 18, Color(accent, pulse * 0.35))
	_draw_world_label(gate_position + Vector2(-62, 112), "JUMP GATE", accent)

func _draw_asteroid(asteroid: Dictionary) -> void:
	var resource_color := Color(str(Data.RESOURCES[asteroid["resource"]]["color"]))
	var points := PackedVector2Array()
	var rotation := float(asteroid["rotation"]) + visual_time * 0.015
	for point in asteroid["shape"]:
		points.append(asteroid["pos"] + point.rotated(rotation))
	draw_colored_polygon(points, Color("172532"))
	points.append(points[0])
	draw_polyline(points, Color(resource_color, 0.48), 1.6, true)
	var amount_ratio := float(asteroid["amount"]) / float(asteroid["max_amount"])
	if amount_ratio < 0.98:
		draw_arc(asteroid["pos"], 52, -PI * 0.5, -PI * 0.5 + TAU * amount_ratio, 36, Color(resource_color, 0.65), 2.0, true)
	if mining and target_id == int(asteroid["id"]) and target_kind == "asteroid" and player["pos"].distance_to(asteroid["pos"]) <= 265.0:
		var beam_color := Color(resource_color, 0.65 + sin(visual_time * 20.0) * 0.2)
		draw_line(player["pos"], asteroid["pos"], Color(beam_color, 0.15), 9.0, true)
		draw_line(player["pos"], asteroid["pos"], beam_color, 2.0, true)
		draw_circle(asteroid["pos"], 8.0 + sin(visual_time * 14.0) * 2.0, beam_color)

func _draw_loot(item: Dictionary) -> void:
	var color := Color(str(Data.RESOURCES[item["resource"]]["color"]))
	var pos: Vector2 = item["pos"]
	var r := 13.0 + sin(visual_time * 3.0 + float(item["id"])) * 2.0
	var points := PackedVector2Array()
	for i in range(4):
		points.append(pos + Vector2.from_angle(float(item["rotation"]) + PI * 0.25 + i * PI * 0.5) * r)
	draw_colored_polygon(points, Color(color, 0.32))
	points.append(points[0])
	draw_polyline(points, color, 1.5, true)

func _draw_enemy(enemy: Dictionary) -> void:
	var color := Color("ff8066") if not enemy["elite"] else Color("ffc061")
	if float(enemy["flash"]) > 0.0:
		color = Color("ffffff")
	_draw_ship_shape(enemy["pos"], float(enemy["angle"]), 0.90 if not enemy["elite"] else 1.3, color, true)
	if enemy["aggro"]:
		var ratio := float(enemy["shield"]) / float(enemy["max_shield"])
		draw_arc(enemy["pos"], 29, PI, TAU, 24, Color("ff9a72"), 2.0, true)
		draw_arc(enemy["pos"], 29, PI, PI + PI * clampf(ratio, 0.0, 1.0), 24, Color("ffe0a3"), 2.5, true)

func _draw_player() -> void:
	var color := Color("72f2ff")
	var scale_factor := 1.15 if str(profile["ship"]) == "kestrel" else 0.95
	_draw_ship_shape(player["pos"], float(player["angle"]), scale_factor, color, false)
	if player["since_damage"] < 0.35:
		draw_arc(player["pos"], 34, 0, TAU, 48, Color("8df5ff"), 3.0, true)

func _draw_ship_shape(pos: Vector2, angle: float, scale_factor: float, color: Color, hostile: bool) -> void:
	var velocity: Vector2 = player.get("vel", Vector2.ZERO) if not hostile else Vector2.ZERO
	if not hostile and velocity.length() > 20.0:
		var rear := pos - Vector2.from_angle(angle) * 28.0 * scale_factor
		var trail := rear - velocity.normalized() * minf(60.0, velocity.length() * 0.25)
		draw_line(rear, trail, Color(color, 0.12), 13.0 * scale_factor, true)
		draw_line(rear, trail, Color(color, 0.58), 3.0 * scale_factor, true)
	var local_points := PackedVector2Array([
		Vector2(30, 0), Vector2(4, -9), Vector2(-13, -24),
		Vector2(-9, -7), Vector2(-27, -5), Vector2(-18, 0),
		Vector2(-27, 5), Vector2(-9, 7), Vector2(-13, 24), Vector2(4, 9)
	])
	var points := PackedVector2Array()
	for point in local_points:
		points.append(pos + point.rotated(angle) * scale_factor)
	draw_colored_polygon(points, Color("0b1d2a") if not hostile else Color("2a171b"))
	points.append(points[0])
	draw_polyline(points, color, 2.0, true)
	var nose := pos + Vector2(17, 0).rotated(angle) * scale_factor
	var core := pos + Vector2(-5, 0).rotated(angle) * scale_factor
	draw_line(core, nose, Color(color, 0.70), 2.0, true)
	draw_circle(core, 4.0 * scale_factor, color)

func _draw_effects() -> void:
	for effect in effects:
		var ratio := float(effect["ttl"]) / float(effect["max_ttl"])
		var color: Color = effect["color"]
		color.a *= ratio
		draw_line(effect["from"], effect["to"], Color(color, color.a * 0.20), float(effect["width"]) * 4.0, true)
		draw_line(effect["from"], effect["to"], color, float(effect["width"]), true)

func _draw_targeting() -> void:
	var target := get_target()
	if not target.is_empty():
		var pos: Vector2 = target["pos"]
		var color := Color("ffab7a") if target_kind == "enemy" else Color("80f2ff")
		var radius := 46.0 if target_kind == "enemy" else 58.0
		for i in range(4):
			var a := i * PI * 0.5 + visual_time * 0.25
			draw_arc(pos, radius, a, a + 0.55, 12, color, 2.2, true)
		if auto_orbit:
			var orbit_radius := 330.0 if target_kind == "enemy" else 185.0
			draw_arc(pos, orbit_radius, 0, TAU, 90, Color(color, 0.15), 1.2, true)
		var label := str(target["name"]) if target_kind == "enemy" else str(Data.RESOURCES[target["resource"]]["name"])
		_draw_world_label(pos + Vector2(-55, -radius - 24), label.to_upper(), color)
	if route_destination != "":
		var color := Color(str(system["accent"]))
		draw_dashed_line(player["pos"], gate_position, Color(color, 0.32), 1.4, 12.0, true)
	elif auto_dock:
		draw_dashed_line(player["pos"], station_position, Color("65e8f4"), 1.4, 12.0, true)

func _draw_world_label(pos: Vector2, text: String, color: Color) -> void:
	if font != null:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(color, 0.78))
