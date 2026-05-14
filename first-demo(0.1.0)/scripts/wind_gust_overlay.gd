extends Control

const STREAK_COUNT := 34
const RIBBON_COUNT := 5
const PARTICLE_COUNT := 74
const CURVE_SEGMENTS := 18
const GUST_DURATION := 0.78

var _direction := Vector2.RIGHT
var _streaks: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _tween: Tween

var _progress: float = 1.0:
	set(value):
		_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

var _strength: float = 0.0:
	set(value):
		_strength = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func play(direction: Vector2) -> void:
	if direction.length_squared() <= 0.01:
		direction = Vector2.RIGHT

	_direction = direction.normalized()
	_build_streaks()
	_build_particles()
	visible = true
	_progress = 0.0
	_strength = 1.0

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "_progress", 1.0, GUST_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_strength", 0.0, GUST_DURATION).set_delay(0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.finished.connect(_finish)


func _draw() -> void:
	if not visible or _strength <= 0.01:
		return
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var axis := _direction.normalized()
	var normal := Vector2(-axis.y, axis.x)
	var center := size * 0.5
	var axis_extent := absf(axis.x) * size.x * 0.5 + absf(axis.y) * size.y * 0.5 + 220.0
	var normal_extent := absf(normal.x) * size.x * 0.5 + absf(normal.y) * size.y * 0.5 + 120.0
	var peak := sin(_progress * PI)
	var wash_alpha := 0.09 * _strength * peak

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.68, 0.86, 1.0, wash_alpha), true)
	_draw_ribbons(axis, normal, center, axis_extent, normal_extent, peak)
	_draw_streaks(axis, normal, center, axis_extent, normal_extent)
	_draw_particles(axis, normal, center, axis_extent, normal_extent)


func _draw_ribbons(axis: Vector2, normal: Vector2, center: Vector2, axis_extent: float, normal_extent: float, peak: float) -> void:
	for i in range(RIBBON_COUNT):
		var lane := lerpf(-0.72, 0.72, (float(i) + 0.5) / float(RIBBON_COUNT))
		var shifted_progress := clampf(_progress + (float(i) - 1.5) * 0.045, 0.0, 1.0)
		var travel := lerpf(-axis_extent, axis_extent, shifted_progress)
		var color := Color(0.86, 0.98, 1.0, 0.12 * _strength * peak)
		var points := _make_wind_curve(
			center,
			axis,
			normal,
			travel - 330.0,
			560.0,
			lane * normal_extent,
			46.0 + float(i % 2) * 18.0,
			1.18 + float(i) * 0.15,
			_progress * 5.0 + float(i) * 0.9
		)
		draw_polyline(points, color, 22.0 + float(i % 2) * 8.0, true)


func _draw_streaks(axis: Vector2, normal: Vector2, center: Vector2, axis_extent: float, normal_extent: float) -> void:
	for streak in _streaks:
		var local_progress := clampf(_progress + float(streak["phase"]), 0.0, 1.0)
		var streak_peak := sin(local_progress * PI)
		if streak_peak <= 0.01:
			continue

		var lane := float(streak["lane"])
		var travel := lerpf(-axis_extent, axis_extent, local_progress)
		var length := float(streak["length"])
		var width := float(streak["width"])
		var alpha := float(streak["alpha"]) * _strength * streak_peak
		var amplitude := float(streak["amplitude"])
		var frequency := float(streak["frequency"])
		var curl := float(streak["curl"])
		var color := Color(0.93, 1.0, 0.97, alpha)
		var points := _make_wind_curve(
			center,
			axis,
			normal,
			travel - length * 0.5,
			length,
			lane * normal_extent,
			amplitude,
			frequency,
			curl + local_progress * 7.0
		)
		draw_polyline(points, color, width, true)


func _draw_particles(axis: Vector2, normal: Vector2, center: Vector2, axis_extent: float, normal_extent: float) -> void:
	for particle in _particles:
		var local_progress := clampf(_progress + float(particle["phase"]), 0.0, 1.0)
		var particle_peak := sin(local_progress * PI)
		if particle_peak <= 0.01:
			continue

		var lane := float(particle["lane"])
		var z := float(particle["z"])
		var travel := lerpf(-axis_extent, axis_extent, local_progress)
		var drift := sin(local_progress * TAU * float(particle["frequency"]) + float(particle["curl"])) * float(particle["amplitude"])
		var position := center + axis * travel + normal * (lane * normal_extent + drift)
		var radius := float(particle["radius"]) * lerpf(0.65, 1.25, z)
		var alpha := float(particle["alpha"]) * _strength * particle_peak

		draw_circle(position, radius * 1.9, Color(0.72, 0.88, 1.0, alpha * 0.16))
		draw_circle(position, radius, Color(0.95, 1.0, 0.96, alpha))


func _make_wind_curve(
	center: Vector2,
	axis: Vector2,
	normal: Vector2,
	start_axis: float,
	length: float,
	lane_offset: float,
	amplitude: float,
	frequency: float,
	phase: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for segment in range(CURVE_SEGMENTS + 1):
		var t := float(segment) / float(CURVE_SEGMENTS)
		var taper := sin(t * PI)
		var wave := sin(t * TAU * frequency + phase) * amplitude * taper
		var secondary_wave := sin(t * TAU * (frequency * 0.52) + phase * 0.7) * amplitude * 0.34 * taper
		var point := center + axis * (start_axis + length * t) + normal * (lane_offset + wave + secondary_wave)
		points.append(point)
	return points


func _build_streaks() -> void:
	_streaks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec()

	for _i in range(STREAK_COUNT):
		_streaks.append({
			"lane": rng.randf_range(-0.95, 0.95),
			"phase": rng.randf_range(-0.16, 0.16),
			"length": rng.randf_range(130.0, 300.0),
			"width": rng.randf_range(2.0, 5.5),
			"alpha": rng.randf_range(0.24, 0.62),
			"amplitude": rng.randf_range(18.0, 54.0),
			"frequency": rng.randf_range(0.82, 1.75),
			"curl": rng.randf_range(0.0, TAU),
		})


func _build_particles() -> void:
	_particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec() + 177

	for _i in range(PARTICLE_COUNT):
		var z := rng.randf()
		_particles.append({
			"lane": rng.randf_range(-1.06, 1.06),
			"phase": rng.randf_range(-0.18, 0.18),
			"z": z,
			"radius": rng.randf_range(1.6, 4.7),
			"alpha": rng.randf_range(0.18, 0.62),
			"amplitude": rng.randf_range(12.0, 62.0),
			"frequency": rng.randf_range(0.9, 2.1),
			"curl": rng.randf_range(0.0, TAU),
		})


func _finish() -> void:
	visible = false
	_strength = 0.0
	_progress = 1.0
