extends Node2D
## Draws a Holdfast run: the keep, light posts, tower, Recruits, Hero, their
## attacks and enemies.
##
## Reads the run source's rules for drawing only; it never changes or steps them.
## Placeholder art: shapes drawn in code (see assets/CREDITS.md). The keep sits
## at this node's position, centred in the visible area below the HUD bar. The
## view scales down to fit the whole arena there, but never below MIN_SCALE; the
## keep and the tower and staff ranges always stay clear of the HUD.

@export var source_path: NodePath

const COLOUR_GROUND := Color("#141b14")
const COLOUR_ARENA := Color("#1f2a1f")
const COLOUR_ARENA_EDGE := Color("#4a5d4a")
const COLOUR_KEEP := Color("#c9b88a")
const COLOUR_KEEP_EDGE := Color("#3b3324")
const COLOUR_HERO := Color("#f2b13a")
const COLOUR_HERO_EDGE := Color("#3b2a08")
const COLOUR_ARROW := Color("#ff7a2e")
const COLOUR_HERO_FLASH := Color("#fff2c2")
const COLOUR_ABILITY_READY := Color("#ffe08a")
const COLOUR_ABILITY_CHARGING := Color(1.0, 0.88, 0.54, 0.35)
const COLOUR_TOWER := Color("#7f8fa6")
const COLOUR_STAFF := Color("#e1a95f")
const COLOUR_LIGHT := Color(1.0, 0.9, 0.55)
const COLOUR_DOWN := Color("#4a4a4a")
const COLOUR_TOKEN := Color("#ffd75e")
const COLOUR_REVIVE := Color("#7fe08a")
const COLOUR_TEXT := Color("#f0ead6")
const RECRUIT_COLOURS := {
	"warden": Color("#e1a95f"),
	"lookout": Color("#7fc4a8"),
	"alchemist": Color("#b78be0"),
	"engineer": Color("#8fb3e8"),
}
## How long the flash of an attack takes to fade; matches the rules' effects.
const FONT_SIZE := 12
const COLOUR_SHOT := Color(1.0, 0.95, 0.6, 0.9)
const COLOUR_HEALTH := Color("#d64545")
## Height kept clear for the HUD bar at the 1280x720 base size (scenes/ui/hud.tscn
## draws it from y = 16 to about y = 121).
const HUD_CLEARANCE := 132.0
const BOTTOM_MARGIN := 16.0
## Space kept round the arena's border on screen.
const ARENA_MARGIN := 8.0
const HERO_RADIUS := 12.0
## Smallest view scale: below this, enemies and the aura get too small to read.
const MIN_SCALE := 0.5
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


## Centres the keep in the area below the HUD and scales the view to fit the whole
## arena in that area, clamped to MIN_SCALE..1.
func _fit_below_hud() -> void:
	var view := get_viewport_rect()
	var area := Rect2(view.position.x, view.position.y + HUD_CLEARANCE,
			view.size.x, maxf(view.size.y - HUD_CLEARANCE - BOTTOM_MARGIN, 1.0))
	var arena := HoldfastRules.DEFAULT_ARENA
	if source is HoldfastRunSource and source.get_rules() != null:
		arena = source.get_rules().arena_size()
	var span := arena + Vector2.ONE * ARENA_MARGIN * 2.0
	var fit := clampf(minf(area.size.x / span.x, area.size.y / span.y), MIN_SCALE, 1.0)
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
	var arena := Rect2(-rules.arena_half, rules.arena_size())
	draw_rect(arena, COLOUR_ARENA)
	draw_rect(arena, COLOUR_ARENA_EDGE, false, 3.0)
	# Where the keep's beam reaches: the fog edge, and where enemies come from.
	draw_arc(Vector2.ZERO, rules.spawn_radius, 0.0, TAU, 96, Color(COLOUR_LIGHT, 0.18), 2.0)
	for post in rules.posts:
		draw_circle(post.position, rules.light_radius, Color(COLOUR_LIGHT, 0.10))
		draw_arc(post.position, rules.light_radius, 0.0, TAU, 64, Color(COLOUR_LIGHT, 0.35), 1.5)
	draw_circle(Vector2.ZERO, rules.keep_radius, COLOUR_KEEP)
	draw_arc(Vector2.ZERO, rules.keep_radius, 0.0, TAU, 48, COLOUR_KEEP_EDGE, 4.0)
	for post in rules.posts:
		draw_colored_polygon(PackedVector2Array([post.position + Vector2(0, -9), post.position + Vector2(7, 0), post.position + Vector2(0, 9), post.position + Vector2(-7, 0)]), COLOUR_LIGHT)
	for built in rules.towers:
		_draw_attacker(rules, built, COLOUR_TOWER, true)
	for recruit in rules.recruits:
		_draw_attacker(rules, recruit, RECRUIT_COLOURS.get(str(recruit.role.get("class", "")), COLOUR_STAFF), false)
	for token in rules.xp_tokens:
		draw_colored_polygon(PackedVector2Array([token.position + Vector2(0, -7), token.position + Vector2(6, 0), token.position + Vector2(0, 7), token.position + Vector2(-6, 0)]), COLOUR_TOKEN)
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
	var at := attacker.position
	var is_up := attacker.up
	var shown := colour if is_up else COLOUR_DOWN
	if square:
		draw_rect(Rect2(at - Vector2(14, 14), Vector2(28, 28)), shown)
	else:
		draw_circle(at, attacker.radius, shown)
		draw_arc(at, attacker.radius, 0.0, TAU, 24, Color.BLACK, 2.0)
	if is_up:
		draw_arc(at, attacker.attack_range, 0.0, TAU, 64, Color(colour, 0.15), 1.0)
	var health := float(attacker.health["health"])
	var health_max := float(attacker.health["max_health"])
	if is_up and health < health_max:
		_draw_bar(at + Vector2(-16, -attacker.radius - 10.0), 32.0, health / health_max, COLOUR_HEALTH)
	if not is_up and attacker.kind == "recruit":
		var held := float(attacker.health["revive_progress"]) / float(attacker.role["revive_seconds"])
		draw_string(ThemeDB.fallback_font, at + Vector2(-40, -attacker.radius - 8.0), "down", HORIZONTAL_ALIGNMENT_CENTER, 80, FONT_SIZE, COLOUR_TEXT)
		if held > 0.0:
			draw_arc(at, attacker.radius + 5.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(held, 0.0, 1.0), 24, COLOUR_REVIVE, 3.0)
	elif attacker.kind == "recruit":
		draw_string(ThemeDB.fallback_font, at + Vector2(-40, attacker.radius + 14.0), str(attacker.role.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, 80, FONT_SIZE, COLOUR_TEXT)
	if attacker.last_target < 0:
		return
	for enemy in rules.enemies:
		if enemy.uid == attacker.last_target:
			draw_line(at, enemy.position, COLOUR_SHOT, 3.0)
			return


func _draw_bar(at: Vector2, width: float, fraction: float, colour: Color) -> void:
	draw_rect(Rect2(at, Vector2(width, 4.0)), Color.BLACK)
	draw_rect(Rect2(at, Vector2(width * clampf(fraction, 0.0, 1.0), 4.0)), colour)


## The Hero (in their path's colour), their attack range, the flash of what they
## just did, a ring that fills while the ability charges and lights up when it is
## ready (Space), and the arrows in flight. A knocked-down Hero is a grey ghost
## with the seconds left before they are back at the start.
func _draw_hero(rules: HoldfastRules) -> void:
	for effect in rules.effects:
		_draw_effect(effect)
	if rules.zone_left > 0.0:
		draw_arc(rules.zone_position, float(rules.hero_ability["zone_radius"]), 0.0, TAU, 64, Color(rules.hero_colour, 0.7), 3.0)
	for arrow in rules.projectiles:
		var tail: Vector2 = arrow.position - arrow.velocity.normalized() * 14.0
		var tint := Color(arrow.colour) if arrow.colour != "" else COLOUR_ARROW
		draw_line(tail, arrow.position, tint, 3.0)
		draw_circle(arrow.position, arrow.radius * 0.6, tint)
	var at := rules.hero_position
	var colour := Color(rules.hero_colour)
	var radius := rules.hero_radius
	if rules.hero_state["downed"]:
		draw_circle(at, radius, Color(COLOUR_DOWN, 0.7))
		draw_arc(at, radius, 0.0, TAU, 24, Color(colour, 0.5), 2.0)
		draw_string(ThemeDB.fallback_font, at + Vector2(-50, -radius - 8.0), "Down: %d" % ceili(float(rules.hero_state["get_up_in"])), HORIZONTAL_ALIGNMENT_CENTER, 100, FONT_SIZE + 2, COLOUR_TEXT)
		return
	draw_arc(at, float(rules.hero_attack["range"]), 0.0, TAU, 64, Color(colour, 0.12), 1.0)
	draw_circle(at, radius, colour)
	draw_arc(at, radius, 0.0, TAU, 24, COLOUR_HERO_EDGE, 2.0)
	draw_line(at, at + rules.hero_facing * (radius + 8.0), COLOUR_HERO_EDGE, 3.0)
	var health := float(rules.hero_state["health"])
	var health_max := float(rules.hero_state["max_health"])
	if health < health_max:
		_draw_bar(at + Vector2(-16, -radius - 16.0), 32.0, health / health_max, COLOUR_HEALTH)
	var ready := rules.hero_ability_ready_in <= 0.0
	var charged := 1.0 - rules.hero_ability_ready_in / float(rules.hero_ability["cooldown"])
	draw_arc(at, radius + 6.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(charged, 0.0, 1.0), 32,
			COLOUR_ABILITY_READY if ready else COLOUR_ABILITY_CHARGING, 3.0)


## The flash of one Hero attack: a burst's circle, an arc's wedge or a dash's trail.
func _draw_effect(effect: HoldfastRules.Effect) -> void:
	var fade := clampf(effect.ttl / HoldfastRules.EFFECT_SECONDS, 0.0, 1.0)
	match effect.kind:
		"burst":
			draw_circle(effect.position, effect.radius, Color(COLOUR_HERO_FLASH, 0.25 * fade))
			draw_arc(effect.position, effect.radius, 0.0, TAU, 48, Color(COLOUR_HERO_FLASH, 0.8 * fade), 2.0)
		"arc":
			var facing := effect.vector.angle()
			var half := effect.vector.length() / 2.0
			var points := PackedVector2Array([effect.position])
			for i in 13:
				points.append(effect.position + Vector2.RIGHT.rotated(facing - half + 2.0 * half * i / 12.0) * effect.radius)
			draw_colored_polygon(points, Color(COLOUR_HERO_FLASH, 0.4 * fade))
		"dash":
			draw_line(effect.position, effect.position + effect.vector, Color(COLOUR_HERO_FLASH, 0.8 * fade), effect.radius * 1.2)
