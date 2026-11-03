extends Control

const Data = preload("res://scripts/game_data.gd")

signal opened
signal contact_selected(title: String)

const BACKGROUND := Color(0.018, 0.045, 0.075, 0.96)
const GRID := Color(0.20, 0.55, 0.65, 0.12)
const BORDER := Color(0.30, 0.80, 0.88, 0.48)
const CYAN := Color("72f2ff")
const MUTED := Color("7d9ba9")

var world
var full_map := false
var radar_range := 1600.0
var font: Font
var _scale := 1.0
var _center := Vector2.ZERO
var _targets: Array = []

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true

func configure(world_ref, is_full_map: bool) -> void:
	world = world_ref
	full_map = is_full_map
	tooltip_text = "Tap a contact to target it" if full_map else "Live radar · tap to open the system map"
	queue_redraw()

func _process(_delta: float) -> void:
	if is_visible_in_tree() and world != null:
		queue_redraw()

func _draw() -> void:
	_targets.clear()
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	_draw_grid()
	if world == null or world.player.is_empty() or world.system.is_empty() or size.x < 40.0 or size.y < 40.0:
		_draw_border()
		return
	_calculate_transform()
	_draw_route()
	_draw_planet()
	_draw_station()
	_draw_gate()
	for asteroid in world.asteroids:
		_draw_asteroid(asteroid)
	for item in world.loot:
		_draw_loot(item)
	for enemy in world.enemies:
		_draw_enemy(enemy)
	_draw_player()
	_draw_labels()
	_draw_border()

func _draw_grid() -> void:
	var divisions := 6 if full_map else 4
	for index in range(1, divisions):
		var x := size.x * float(index) / float(divisions)
		var y := size.y * float(index) / float(divisions)
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID, 1.0, true)
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID, 1.0, true)

func _draw_border() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 1.0)

func _calculate_transform() -> void:
	if not full_map:
		_center = world.player["pos"]
		_scale = minf(size.x, size.y) / (radar_range * 2.0)
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var positions: Array = [world.station_position, world.gate_position, world.player["pos"], Vector2(-1180, -1030)]
	for asteroid in world.asteroids:
		positions.append(asteroid["pos"])
	for enemy in world.enemies:
		positions.append(enemy["pos"])
	for item in world.loot:
		positions.append(item["pos"])
	for position in positions:
		minimum = minimum.min(position)
		maximum = maximum.max(position)
	minimum -= Vector2(180, 180)
	maximum += Vector2(180, 180)
	var span := maximum - minimum
	span.x = maxf(span.x, 500.0)
	span.y = maxf(span.y, 500.0)
	var available := size - Vector2(54, 54)
	_scale = minf(available.x / span.x, available.y / span.y)
	_center = (minimum + maximum) * 0.5

func _project(world_position: Vector2) -> Vector2:
	return size * 0.5 + (world_position - _center) * _scale

func _on_screen(point: Vector2) -> bool:
	return Rect2(Vector2(-24, -24), size + Vector2(48, 48)).has_point(point)

func _draw_route() -> void:
	var player_point := _project(world.player["pos"])
	if str(world.route_destination) != "":
		draw_dashed_line(player_point, _project(world.gate_position), Color(CYAN, 0.48), 1.4, 9.0, true)
	elif bool(world.auto_dock):
		draw_dashed_line(player_point, _project(world.station_position), Color(CYAN, 0.48), 1.4, 9.0, true)

func _draw_planet() -> void:
	var point := _project(Vector2(-1180, -1030))
	if not _on_screen(point):
		return
	var accent := Color(str(world.system["accent"]))
	var radius := maxf(5.0, 180.0 * _scale)
	draw_circle(point, radius, Color(accent, 0.08))
	draw_arc(point, radius, 0.0, TAU, 48, Color(accent, 0.38), 1.4, true)

func _draw_station() -> void:
	var point := _project(world.station_position)
	if not _on_screen(point):
		return
	var accent := Color(str(world.system["accent"]))
	var radius := 7.0 if full_map else 5.0
	draw_circle(point, radius + 4.0, Color(accent, 0.12))
	draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), Color(accent, 0.30))
	draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), accent, false, 1.5)

func _draw_gate() -> void:
	var point := _project(world.gate_position)
	if not _on_screen(point):
		return
	var accent := Color(str(world.system["accent"]))
	var radius := 8.0 if full_map else 6.0
	draw_arc(point, radius, 0.0, TAU, 24, accent, 1.8, true)
	draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), Color(accent, 0.65), 1.0, true)

func _draw_asteroid(asteroid: Dictionary) -> void:
	var point := _project(asteroid["pos"])
	if not _on_screen(point):
		return
	var color := Color(str(Data.RESOURCES[asteroid["resource"]]["color"]))
	var radius := 3.5 if full_map else 2.5
	draw_circle(point, radius, Color(color, 0.78))
	_register_target("asteroid", int(asteroid["id"]), point, str(Data.RESOURCES[asteroid["resource"]]["name"]))
	_draw_selected("asteroid", int(asteroid["id"]), point, 9.0)

func _draw_loot(item: Dictionary) -> void:
	var point := _project(item["pos"])
	if not _on_screen(point):
		return
	var color := Color(str(Data.RESOURCES[item["resource"]]["color"]))
	var radius := 4.0 if full_map else 3.0
	var points := PackedVector2Array([
		point + Vector2(0, -radius), point + Vector2(radius, 0),
		point + Vector2(0, radius), point + Vector2(-radius, 0)
	])
	draw_colored_polygon(points, color)

func _draw_enemy(enemy: Dictionary) -> void:
	var point := _project(enemy["pos"])
	if not _on_screen(point):
		return
	var color := Color("ffc061") if bool(enemy["elite"]) else Color("ff8066")
	_draw_triangle(point, float(enemy["angle"]), 6.0 if full_map else 4.5, color)
	_register_target("enemy", int(enemy["id"]), point, str(enemy["name"]))
	_draw_selected("enemy", int(enemy["id"]), point, 11.0)

func _draw_player() -> void:
	var point := _project(world.player["pos"])
	_draw_triangle(point, float(world.player["angle"]), 9.0 if full_map else 7.0, CYAN)
	draw_arc(point, 12.0 if full_map else 9.0, 0.0, TAU, 28, Color(CYAN, 0.35), 1.0, true)

func _draw_triangle(point: Vector2, angle: float, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for local in [Vector2(1.2, 0), Vector2(-0.85, -0.72), Vector2(-0.45, 0), Vector2(-0.85, 0.72)]:
		points.append(point + local.rotated(angle) * radius)
	draw_colored_polygon(points, Color(color, 0.82))

func _draw_selected(kind: String, id: int, point: Vector2, radius: float) -> void:
	if str(world.target_kind) == kind and int(world.target_id) == id:
		draw_arc(point, radius, 0.0, TAU, 28, CYAN, 1.5, true)

func _register_target(kind: String, id: int, point: Vector2, title: String) -> void:
	if full_map:
		_targets.append({"kind": kind, "id": id, "point": point, "title": title})

func _draw_labels() -> void:
	if font == null:
		return
	if full_map:
		var accent := Color(str(world.system["accent"]))
		draw_string(font, _project(world.station_position) + Vector2(12, -10), str(world.system["station"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent)
		draw_string(font, _project(world.gate_position) + Vector2(12, -10), "JUMP GATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
		draw_string(font, Vector2(10, size.y - 10), "%s · %d contacts" % [str(world.system["name"]).to_upper(), world.asteroids.size() + world.enemies.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	else:
		draw_string(font, Vector2(size.x * 0.5 - 4, 15), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
		draw_string(font, Vector2(8, size.y - 8), "%d m RADAR" % int(radar_range), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if not full_map:
		opened.emit()
		accept_event()
		return
	for target in _targets:
		if event.position.distance_to(target["point"]) <= 20.0:
			world.clear_course()
			world.target_kind = str(target["kind"])
			world.target_id = int(target["id"])
			contact_selected.emit(str(target["title"]))
			queue_redraw()
			accept_event()
			return
