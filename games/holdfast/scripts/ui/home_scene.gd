extends Control
## The lighthouse and the sea behind the home screen, drawn from the theme's tokens (a placeholder
## look on placeholder art). The beam swings slowly; with reduced motion it stands still.

## How far the beam swings either side of level, in radians, and how long a full swing takes.
const SWING := 0.3
const PERIOD := 10.0
const BEAM_REACH := 900.0
const BEAM_SPREAD := 0.13
const STARS: Array[Vector2] = [Vector2(0.08, 0.1), Vector2(0.3, 0.05), Vector2(0.43, 0.2), Vector2(0.55, 0.08), Vector2(0.66, 0.3), Vector2(0.93, 0.18), Vector2(0.2, 0.32), Vector2(0.97, 0.45)]

var _time := 0.0
var _moving := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	visibility_changed.connect(_sync_process)


## Moves the beam, or holds it still (the player's reduced-motion setting).
func set_moving(on: bool) -> void:
	_moving = on
	_sync_process()
	queue_redraw()


func is_moving() -> bool:
	return _moving


## The beam's angle from level, in radians (always 0 while it stands still).
func beam_angle() -> float:
	return sin(_time * TAU / PERIOD) * SWING if _moving else 0.0


func _sync_process() -> void:
	set_process(_moving and is_visible_in_tree())


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	for star in STARS:
		draw_circle(Vector2(w * star.x, h * star.y), 1.8, UiTokens.colour(&"mute", 0.6))
	# The tower, on its rock, at the right of the page.
	var base := Vector2(w * 0.76, h * 0.86)
	var tower_h := h * 0.52
	var lamp := base + Vector2(0, -tower_h - 24.0)
	_draw_beam(lamp)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-190, 20), base + Vector2(-110, -50), base + Vector2(110, -50), base + Vector2(190, 20)]), UiTokens.colour(&"deep"))
	var top_y := base.y - 50.0 - tower_h
	var bottom_y := base.y - 50.0
	draw_colored_polygon(_tower_slice(base.x, top_y, bottom_y, 0.0, 1.0), UiTokens.colour(&"bone"))
	for band in [[0.22, 0.42], [0.6, 0.8]]:
		draw_colored_polygon(_tower_slice(base.x, top_y, bottom_y, band[0], band[1]), UiTokens.colour(&"boss").darkened(0.15))
	draw_rect(Rect2(base.x - 44, top_y - 14, 88, 14), UiTokens.colour(&"raise"))
	draw_rect(Rect2(base.x - 24, top_y - 58, 48, 44), UiTokens.colour(&"lamp_hot"))
	draw_colored_polygon(PackedVector2Array([Vector2(base.x - 32, top_y - 58), Vector2(base.x, top_y - 90), Vector2(base.x + 32, top_y - 58)]), UiTokens.colour(&"raise"))
	# The sea in front: two bands of wave.
	_draw_sea(h * 0.86, UiTokens.colour(&"raise"), 14.0, 0.0)
	_draw_sea(h * 0.92, UiTokens.colour(&"deep"), 10.0, 1.7)


## The tower narrows toward the top: the part of it between two fractions of its height.
func _tower_slice(centre_x: float, top_y: float, bottom_y: float, from: float, to: float) -> PackedVector2Array:
	var half_top := 30.0
	var half_bottom := 50.0
	var y0 := lerpf(top_y, bottom_y, from)
	var y1 := lerpf(top_y, bottom_y, to)
	var x0 := lerpf(half_top, half_bottom, from)
	var x1 := lerpf(half_top, half_bottom, to)
	return PackedVector2Array([Vector2(centre_x - x0, y0), Vector2(centre_x + x0, y0), Vector2(centre_x + x1, y1), Vector2(centre_x - x1, y1)])


func _draw_beam(lamp: Vector2) -> void:
	var angle := beam_angle()
	var points := PackedVector2Array([lamp, lamp + Vector2.RIGHT.rotated(angle - BEAM_SPREAD) * BEAM_REACH, lamp + Vector2.RIGHT.rotated(angle + BEAM_SPREAD) * BEAM_REACH])
	var near := UiTokens.colour(&"lamp", 0.5)
	var far := UiTokens.colour(&"lamp", 0.0)
	draw_polygon(points, PackedColorArray([near, far, far]))


func _draw_sea(top: float, colour: Color, wave: float, phase: float) -> void:
	var points := PackedVector2Array()
	var steps := 40
	for i in steps + 1:
		var x := size.x * i / steps
		points.append(Vector2(x, top + sin(x * 0.012 + phase) * wave))
	points.append(Vector2(size.x, size.y))
	points.append(Vector2(0, size.y))
	draw_colored_polygon(points, colour)
