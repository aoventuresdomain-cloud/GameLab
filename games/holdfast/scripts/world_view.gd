extends Node2D
## Draws a Holdfast run: the keep, tower, staff, Hero, arrows and enemies.
##
## Reads the run source's rules for drawing only; it never changes or steps them.
## Placeholder art: shapes drawn in code (see assets/CREDITS.md). The keep sits
## at this node's position, centred in the visible area below the HUD bar. The
## view scales down towards fitting the spawn ring there, but never below
## MIN_SCALE: enemies may walk in from off-screen, while the keep and the tower
## and staff ranges always stay clear of the HUD.

@export var source_path: NodePath

const COLOUR_GROUND := Color("#1f2a1f")
const COLOUR_KEEP := Color("#c9b88a")
const COLOUR_KEEP_EDGE := Color("#3b3324")
const COLOUR_HERO := Color("#f2b13a")
const COLOUR_HERO_EDGE := Color("#3b2a08")
const COLOUR_ARROW := Color("#ff7a2e")
const COLOUR_ABILITY_READY := Color("#ffe08a")
const COLOUR_ABILITY_CHARGING := Color(1.0, 0.88, 0.54, 0.35)
const COLOUR_TOWER := Color("#7f8fa6")
const COLOUR_STAFF := Color("#e1a95f")
const COLOUR_SHOT := Color(1.0, 0.95, 0.6, 0.9)
const COLOUR_HEALTH := Color("#d64545")
## Height kept clear for the HUD bar at the 1280x720 base size (scenes/ui/hud.tscn
## draws it from y = 16 to about y = 121).
const HUD_CLEARANCE := 132.0
const BOTTOM_MARGIN := 16.0
## Drawn beyond the spawn ring: the largest enemy's radius plus its health bar.
const RING_EDGE := 32.0
const HERO_RADIUS := 12.0
## Smallest view scale: below this, enemies and the aura get too small to read.
const MIN_SCALE := 0.85
## Spawn ring radius used before a run has rules (start screen, the UI tests' stub).
const DEFAULT_SPAWN_RADIUS := 420.0
const ENEMY_COLOURS := {
	"grunt": Color("#9c5b5b"),
	"runner": Color("#c47e3a"),
	"brute": Color("#6a3d7a"),
}

## Any run_state_source.gd. Only a HoldfastRunSource has rules to draw; with
## another source (the UI tests' stub) the field stays empty.
@onready var source: Node = get_node(source_path)


func _process(_delta: float) -> void:
	_fit_below_hud()
	queue_redraw()


## Centres the keep in the area below the HUD and scales the view down towards
## fitting the spawn ring in that area, clamped to MIN_SCALE..1.
func _fit_below_hud() -> void:
	var view := get_viewport_rect()
	var area := Rect2(view.position.x, view.position.y + HUD_CLEARANCE,
			view.size.x, maxf(view.size.y - HUD_CLEARANCE - BOTTOM_MARGIN, 1.0))
	var ring := DEFAULT_SPAWN_RADIUS
	if source is HoldfastRunSource and source.get_rules() != null:
		ring = source.get_rules().spawn_radius
	var reach := (ring + RING_EDGE) * 2.0
	var fit := clampf(minf(area.size.x / reach, area.size.y / reach), MIN_SCALE, 1.0)
	position = area.get_center()
	scale = Vector2(fit, fit)


func world_to_screen(at: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * at


func _draw() -> void:
	draw_rect(Rect2(-get_viewport_rect().size, get_viewport_rect().size * 2.0), COLOUR_GROUND)
	if not source is HoldfastRunSource:
		return
	var rules: HoldfastRules = source.get_rules()
	if rules == null:
		return
	draw_circle(Vector2.ZERO, rules.keep_radius, COLOUR_KEEP)
	draw_arc(Vector2.ZERO, rules.keep_radius, 0.0, TAU, 48, COLOUR_KEEP_EDGE, 4.0)
	_draw_attacker(rules, rules.tower, COLOUR_TOWER, true)
	_draw_attacker(rules, rules.staff, COLOUR_STAFF, false)
	for enemy in rules.enemies:
		var colour: Color = ENEMY_COLOURS.get(enemy.type, Color.WHITE)
		draw_circle(enemy.position, enemy.radius, colour)
		draw_arc(enemy.position, enemy.radius, 0.0, TAU, 20, Color.BLACK, 2.0)
		if enemy.health < enemy.max_health:
			var width := enemy.radius * 2.0
			var at := enemy.position + Vector2(-enemy.radius, -enemy.radius - 8.0)
			draw_rect(Rect2(at, Vector2(width, 4.0)), Color.BLACK)
			draw_rect(Rect2(at, Vector2(width * maxf(enemy.health, 0.0) / enemy.max_health, 4.0)), COLOUR_HEALTH)
	_draw_hero(rules)


func _draw_attacker(rules: HoldfastRules, attacker: HoldfastRules.Attacker, colour: Color, square: bool) -> void:
	if square:
		draw_rect(Rect2(attacker.position - Vector2(14, 14), Vector2(28, 28)), colour)
	else:
		draw_circle(attacker.position, 13.0, colour)
	draw_arc(attacker.position, attacker.attack_range, 0.0, TAU, 64, Color(colour, 0.15), 1.0)
	if attacker.last_target < 0:
		return
	for enemy in rules.enemies:
		if enemy.uid == attacker.last_target:
			draw_line(attacker.position, enemy.position, COLOUR_SHOT, 3.0)
			return


## The Hero, their attack range, a ring that fills while the ability charges and
## lights up when it is ready (Space), and the arrows in flight.
func _draw_hero(rules: HoldfastRules) -> void:
	for arrow in rules.projectiles:
		var tail: Vector2 = arrow.position - arrow.velocity.normalized() * 14.0
		draw_line(tail, arrow.position, COLOUR_ARROW, 3.0)
		draw_circle(arrow.position, arrow.radius * 0.6, COLOUR_ARROW)
	var at := rules.hero_position
	draw_arc(at, float(rules.hero_attack["range"]), 0.0, TAU, 64, Color(COLOUR_HERO, 0.12), 1.0)
	draw_circle(at, HERO_RADIUS, COLOUR_HERO)
	draw_arc(at, HERO_RADIUS, 0.0, TAU, 24, COLOUR_HERO_EDGE, 2.0)
	draw_line(at, at + rules.hero_facing * (HERO_RADIUS + 8.0), COLOUR_HERO_EDGE, 3.0)
	var ready := rules.hero_ability_ready_in <= 0.0
	var charged := 1.0 - rules.hero_ability_ready_in / float(rules.hero_ability["cooldown"])
	draw_arc(at, HERO_RADIUS + 6.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(charged, 0.0, 1.0), 32,
			COLOUR_ABILITY_READY if ready else COLOUR_ABILITY_CHARGING, 3.0)
