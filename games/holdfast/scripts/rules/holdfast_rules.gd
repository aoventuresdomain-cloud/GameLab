class_name HoldfastRules
extends SimRules
## Holdfast combat rules for one run, on the Studio Kit's simulation engine.
##
## Enemies come in waves from the edge of the map. Each walks to the nearest
## tower, Recruit or Hero (a staffed Warden's taunt pulls them in), and to the
## keep at the origin when none is left. The Hero (moved by the input, attacking
## on their own at the nearest enemy), the tower and the Recruits damage them;
## enemies inside a light post's lit area take extra damage. Units that are hit
## fall: a tower is destroyed, a Recruit is downed until the Hero stands on them,
## the Hero is knocked down and gets back up at the start. Kills drop gold and
## sometimes XP, which the Hero carries until the next wave. The run ends when
## the keep falls or the last wave is cleared.
##
## Pure data and maths: no nodes, rendering, input devices or clock, and every
## random number comes from the engine's SimRng. All numbers come from the
## content pack (config.content) plus purchased upgrades (config.upgrades).
##
## config: {
##   content: PackLoader.Pack content ({type: {id: entry}}),
##   level: level id,
##   upgrades: [upgrade node ids] (optional),
## }
## input per tick, every key optional:
##   move: [x, y]   Hero direction, each from -1 to 1 (longer than 1 is shortened)
##   ability: true  press the Hero's ability; ignored while it is on cooldown
##   aura: [x, y]   M1's mouse aura; nothing sends it now (see apply_aura)

## Ticks per simulated second, for the headless run and the playable build alike.
## 30 keeps the Hero's movement and arrows smooth on screen.
const TICK_RATE := 30

const OUTCOME_RUNNING := "running"
const OUTCOME_WON := "won"
const OUTCOME_LOST := "lost"
## Setup failed (unknown level); the run is over before it starts.
const OUTCOME_INVALID := "invalid"

const DEFAULT_WAVE_DELAY := 5.0
const DEFAULT_INTERVAL := 1.0
## The pause added before every wave after the first, when the level does not say.
const DEFAULT_WAVE_PAUSE := 1.0
const DEFAULT_CURSOR_SPEED := 1800.0
## An enemy looks for a new target this often (and at once when its target falls).
const RETARGET_TICKS := 10
## How long a Hero attack's flash stays in `effects`, for drawing.
const EFFECT_SECONDS := 0.25
## A tower or Recruit with nothing in range looks again after this long.
const SCAN_SECONDS := 0.1
## How long the Hero cannot be hurt after getting up, when the Hero path does not say.
const DEFAULT_UNTOUCHABLE_SECONDS := 2.0
## A time within this of a deadline counts as having reached it.
const TIME_EPSILON := 0.000001
## The arena's width and height when the level does not give them.
const DEFAULT_ARENA := Vector2(1920.0, 858.0)


class Enemy:
	extends RefCounted
	var uid: int
	var type: String
	var wave: int
	var position: Vector2
	var health: float
	var max_health: float
	var speed: float
	var radius: float
	var damage: int
	var gold: int
	var xp_chance: float
	## How close the Hero or a Recruit must be for this enemy to go for them (pack:
	## engage_distance, set at spawn). An Enemy made by hand, without a pack, goes for anyone.
	var engage_distance := INF
	var xp_value: int
	## "" is the keep; else "hero", "recruit:<id>" or "tower:<id>".
	var target := ""
	## The tower or Recruit behind `target`; null for the Hero and the keep.
	var target_unit: Attacker
	var retarget_in := 0
	var hit_interval := 1.0
	var hit_in := 0.0
	## Seconds left of a slow from an ability, and how much it slows (0 to 1).
	var slowed_for := 0.0
	var slow_amount := 0.0
	## Slow from a staffed Lookout's zone, set when the enemy picks its target.
	var zone_slow := 0.0
	## Extra damage taken while a staffed Lookout has the enemy marked (0 = unmarked);
	## set when the enemy picks its target.
	var mark_bonus := 0.0


## An arrow of the Hero's attack or ability, in flight until it hits or runs out of range.
class Projectile:
	extends RefCounted
	var position: Vector2
	var velocity: Vector2
	var damage: float
	var radius: float
	var distance_left: float


## A light post: lights a small area, and a Recruit can staff it.
class Post:
	extends RefCounted
	var id: String
	var position: Vector2


## XP the Hero dropped where they fell, for them to pick up again.
class XpToken:
	extends RefCounted
	var position: Vector2
	var amount: int


## A flash of a Hero attack, for drawing: "burst" (position, radius), "arc"
## (position, radius, vector = facing) or "dash" (position to position + vector).
class Effect:
	extends RefCounted
	var kind: String
	var position: Vector2
	var radius: float
	var vector: Vector2
	var ttl: float


## A tower or Recruit: attacks the enemy nearest the keep within range, can be
## hit by enemies, and is destroyed (tower) or downed (Recruit) at zero health.
class Attacker:
	extends RefCounted
	var id: String
	## "tower" or "recruit"; key is "<kind>:<id>".
	var kind := "tower"
	var key := ""
	## {"id": key, "pos": position}, shared with the targeting.
	var candidate: Dictionary = {}
	## A tower: UnitHealth. A Recruit: RecruitRules.
	var health: Dictionary = {}
	## False once a tower is destroyed or a Recruit is downed.
	var up := true
	var radius := 14.0
	var damage_per_level := 0.0
	## Recruits: where they were placed, how far from there they may roam, how
	## fast they walk and how much they heal at home; `walker` is their RecruitLeash
	## input, with the fields that change every tick filled in before each step.
	var home := Vector2.ZERO
	var leash := 0.0
	var rest_heal := 0.0
	var walker: Dictionary = {}
	## Recruits: their pack entry (revive numbers) and the post they staff ("" for none).
	var role: Dictionary = {}
	var post := ""
	var position: Vector2
	var damage: float
	var attack_range: float
	var cooldown: float
	var ready_in := 0.0
	## Last target, for drawing shots; -1 when none.
	var last_target := -1


# Level, after upgrades.
var level_id := ""
var keep_health_max := 0
var keep_radius := 0.0
var spawn_radius := 0.0
var aura_radius := 0.0
var aura_dps := 0.0
var cursor_speed := DEFAULT_CURSOR_SPEED
var gold_multiplier := 1.0
## Tower health restored per second while no enemy is on the field (between waves).
var tower_repair := 0.0
var total_waves := 0

# State.
var ticks := 0
var time := 0.0
var keep_health := 0
var gold := 0
var xp := 0
var kills := 0
var staff_level := 1
var staff_xp := 0
var staff_xp_per_level := 1
var light_radius := 0.0
var light_bonus := 0.0
var aura_position := Vector2.ZERO
var aura_active := false
var hero_path_id := ""
var hero_position := Vector2.ZERO
var hero_start := Vector2.ZERO
var hero_radius := 0.0
var hero_pickup_radius := 0.0
## HeroKnockdown state: health, whether they are down and for how much longer.
var hero_state: Dictionary = {}
var hero_delays: Array = []
## Seconds the Hero cannot be hurt after getting up, and how many are left.
var hero_untouchable_seconds := DEFAULT_UNTOUCHABLE_SECONDS
var hero_grace_left := 0.0
## Where the Hero last fell, for drawing.
var hero_fell_at := Vector2.ZERO
## The path's colour ("#rrggbb") for drawing.
var hero_colour := "#f2b13a"
## Unit vector the Hero faces: at the nearest enemy when there is one, else the
## way they last moved.
var hero_facing := Vector2.UP
var hero_speed := 0.0
var hero_attack: Dictionary = {}
var hero_ability: Dictionary = {}
var hero_attack_ready_in := 0.0
var hero_ability_ready_in := 0.0
## Seconds left of a rapid-fire ability, and the wait until its next arrow.
var hero_rapid_left := 0.0
var hero_rapid_ready_in := 0.0
## The Hero stays inside the spawn ring.
## Half the arena's width and height: the keep is at its centre, and nothing
## (the Hero, a spawn) is outside it.
var arena_half := DEFAULT_ARENA * 0.5
var projectiles: Array[Projectile] = []
var enemies: Array[Enemy] = []
var tower: Attacker
## The first Recruit (M1's staff member); `recruits` holds all of them.
var staff: Attacker
var recruits: Array[Attacker] = []
var posts: Array[Post] = []
var xp_tokens: Array[XpToken] = []
var effects: Array[Effect] = []
## XP the Hero holds until the next wave starts; a knock-down drops it.
var carried_xp := 0
var towers_lost := 0
var recruits_downed := 0
var recruits_revived := 0
var outcome := OUTCOME_RUNNING
## 1-based number of the latest wave that has started; 0 before the first.
var wave := 0
## Waves whose every enemy was killed. A wave with an enemy that reached the
## keep is never cleared.
var waves_cleared := 0
## Seconds (level `wave_pause`) added before every wave after the first, on top of its
## `delay`; waves still start on the clock, whether or not the one before is gone. A
## level with 0 has the old timing exactly.
var wave_pause := DEFAULT_WAVE_PAUSE

## Why setup failed, or "" when it did not.
var setup_error := ""
## Log setup errors with push_error. Tests that provoke one on purpose turn it off.
var report_errors := true

var _rng: SimRng
var _defenders: Array[Attacker] = []
var _by_key: Dictionary = {}
var _post_points: Array = []
var _post_at: Dictionary = {}
var _tie_order: Array = []
var _candidates: Array = []
var _hero_candidate := {"id": "hero", "pos": Vector2.ZERO, "taunt_radius": 0.0, "downed": false}
var _role_effects: Dictionary = {}
## What staffed posts do, rebuilt when a unit goes down or gets up: zones that
## slow and mark enemies, as [centre, radius, slow, mark bonus], and effects that
## run every tick, as [centre, radius, damage per second, repair per second].
var _lookouts: Array = []
var _ticking: Array = []
## Set when a unit goes down or gets up: the target lists are rebuilt and every
## enemy picks its target again.
var _targets_dirty := true
## Whether enemies may pick the Hero (up and not untouchable); a change retargets them.
var _hero_targetable := true
## Set when something may have been killed, so _collect_dead looks only then.
var _any_dead := false
var _enemy_types: Dictionary = {}
## Spawn schedule, sorted by time: [time, wave index, enemy id].
var _schedule: Array = []
var _next_spawn := 0
var _wave_starts: PackedFloat64Array = []
var _wave_health_scale: PackedFloat64Array = []
var _wave_damage_scale: PackedFloat64Array = []
var _wave_remaining: PackedInt32Array = []
var _wave_leaked: PackedByteArray = []
var _next_uid := 1


func setup(config: Dictionary, rng: SimRng) -> void:
	_rng = rng
	var content: Dictionary = config.get("content", {})
	level_id = str(config.get("level", ""))
	var level: Dictionary = content.get("levels", {}).get(level_id, {})
	if level.is_empty():
		_fail("unknown level %s" % level_id)
		return
	var hero_path := str(config.get("hero", level["hero"]["path"]))
	if not content.get("hero_paths", {}).has(hero_path):
		_fail("unknown Hero path %s" % hero_path)
		return
	var light: Dictionary = level["light"]
	var problems := LitArea.validate(light["radius"], light["bonus"])
	problems.append_array(HeroKnockdown.validate(content["hero_paths"][hero_path]["knockdown_delays"]))
	problems.append_array(HeroGetUp.validate_grace(content["hero_paths"][hero_path].get("untouchable_seconds", DEFAULT_UNTOUCHABLE_SECONDS)))
	var roles := []
	var placements: Array = [level["staff"]]
	placements.append_array(level.get("recruits", []))
	for at in placements:
		var data: Dictionary = content["staff"][at["id"]]
		roles.append(str(data["class"]))
		problems.append_array(RecruitRules.validate_revive_time(data["revive_seconds"]))
		problems.append_array(RecruitLeash.validate(data["leash"], data["move_speed"], data["range"], data["retreat_below"]))
	_role_effects = content.get("role_effects", {})
	problems.append_array(RecruitRules.validate_effects(_role_effects, roles))
	if not problems.is_empty():
		_fail(", ".join(problems))
		return
	_enemy_types = content.get("enemies", {})

	var stats := HoldfastRules.upgrade_stats(content.get("upgrade_nodes", {}), config.get("upgrades", []))
	keep_health_max = int(level["keep_health"]) + int(_add(stats, "keep_health"))
	keep_health = keep_health_max
	keep_radius = float(level["keep_radius"])
	# The fog edge is where the keep's beam reaches, and enemies spawn at it.
	spawn_radius = _apply(stats, "beam_reach", float(level["spawn_radius"]))
	tower_repair = _add(stats, "tower_repair")
	var aura: Dictionary = level["aura"]
	aura_radius = _apply(stats, "aura_radius", float(aura["radius"]))
	aura_dps = _apply(stats, "aura_dps", float(aura["dps"]))
	cursor_speed = float(aura.get("cursor_speed", DEFAULT_CURSOR_SPEED))
	gold_multiplier = _apply(stats, "gold_multiplier", 1.0)

	light_radius = float(light["radius"])
	light_bonus = float(light["bonus"])
	for at in level["posts"]:
		var post := Post.new()
		post.id = str(at["id"])
		post.position = Vector2(float(at["x"]), float(at["y"]))
		posts.append(post)
		_post_points.append(post.position)
		_post_at[post.id] = post.position

	var hero_at: Dictionary = level["hero"]
	var hero_data: Dictionary = content["hero_paths"][hero_path]
	hero_path_id = hero_path
	hero_start = Vector2(float(hero_at["x"]), float(hero_at["y"]))
	hero_position = hero_start
	hero_speed = float(hero_data["move_speed"])
	hero_radius = float(hero_data["radius"])
	hero_colour = str(hero_data.get("colour", hero_colour))
	hero_pickup_radius = float(hero_data["pickup_radius"])
	hero_attack = hero_data["attack"]
	hero_ability = hero_data["ability"]
	hero_delays = hero_data["knockdown_delays"]
	hero_untouchable_seconds = float(hero_data.get("untouchable_seconds", DEFAULT_UNTOUCHABLE_SECONDS))
	hero_state = HeroKnockdown.new_state(float(hero_data["health"]))
	var arena: Dictionary = level.get("arena", {})
	arena_half = Vector2(float(arena.get("width", DEFAULT_ARENA.x)), float(arena.get("height", DEFAULT_ARENA.y))) * 0.5
	hero_position = _in_arena(hero_position)
	_tie_order.append("hero")

	var tower_at: Dictionary = level["tower"]
	var tower_data: Dictionary = content["towers"][tower_at["id"]]
	tower = _attacker("tower", tower_at, tower_data, _apply(stats, "tower_damage", float(tower_data["damage"])), _add(stats, "tower_health"))
	for at in placements:
		var data: Dictionary = content["staff"][at["id"]]
		var recruit := _attacker("recruit", at, data, _apply(stats, "staff_damage", float(data["damage"])))
		recruit.damage_per_level = float(data["damage_per_level"])
		recruit.home = recruit.position
		recruit.leash = float(data["leash"])
		recruit.rest_heal = float(data["rest_heal"])
		recruit.role = data
		recruit.post = str(at.get("post", ""))
		recruit.walker = {
			"role": str(data["class"]), "home": recruit.home, "pos": recruit.position, "leash": recruit.leash,
			"speed": float(data["move_speed"]), "range": recruit.attack_range, "health": 0.0, "max_health": 0.0,
			"retreat_below": float(data["retreat_below"]), "downed": false, "staffing": recruit.post != "",
		}
		if recruit.post != "" and not _post_at.has(recruit.post):
			_fail("recruit %s staffs unknown post %s" % [recruit.id, recruit.post])
			return
		recruits.append(recruit)
	staff = recruits[0]
	staff_xp_per_level = int(content["staff"][staff.id]["xp_per_level"])
	_defenders.append(tower)
	_defenders.append_array(recruits)
	for unit in recruits:
		_tie_order.append(unit.key)
	_tie_order.append(tower.key)

	_build_schedule(level)


## Setup failed: the run is over before it starts. Not assert: asserts are
## stripped from release builds.
func _fail(message: String) -> void:
	setup_error = message
	if report_errors:
		push_error("HoldfastRules: " + message)
	outcome = OUTCOME_INVALID


func _attacker(kind: String, at: Dictionary, data: Dictionary, damage: float, extra_health := 0.0) -> Attacker:
	var a := Attacker.new()
	a.id = str(at["id"])
	a.kind = kind
	a.key = "%s:%s" % [kind, a.id]
	a.radius = float(data["radius"])
	a.health = UnitHealth.new_unit(float(data["health"]) + extra_health) if kind == "tower" else RecruitRules.new_recruit(str(data["class"]), float(data["health"]))
	_by_key[a.key] = a
	a.position = Vector2(float(at["x"]), float(at["y"]))
	a.candidate = {"id": a.key, "pos": a.position, "taunt_radius": 0.0, "downed": false, "always": kind == "tower"}
	a.damage = damage
	a.attack_range = float(data["range"])
	a.cooldown = float(data["cooldown"])
	return a


## Wave i starts `delay` seconds after wave i-1 has spawned its last enemy.
## Spawn groups within a wave run side by side.
func _build_schedule(level: Dictionary) -> void:
	var waves: Array = level["waves"]
	total_waves = waves.size()
	var start := float(level.get("first_wave_delay", DEFAULT_WAVE_DELAY))
	wave_pause = float(level.get("wave_pause", DEFAULT_WAVE_PAUSE))
	for w in waves.size():
		var data: Dictionary = waves[w]
		if w > 0:
			start += float(data.get("delay", DEFAULT_WAVE_DELAY)) + wave_pause
		_wave_starts.append(start)
		var last := start
		var count_in_wave := 0
		for spawn in data["spawns"]:
			var interval := float(spawn.get("interval", DEFAULT_INTERVAL))
			for n in int(spawn["count"]):
				var at := start + n * interval
				_schedule.append([at, w, str(spawn["enemy"])])
				last = maxf(last, at)
				count_in_wave += 1
		_wave_health_scale.append(float(data.get("health_scale", 1.0)))
		_wave_damage_scale.append(float(data.get("damage_scale", 1.0)))
		_wave_remaining.append(count_in_wave)
		_wave_leaked.append(0)
		start = last
	# Stable order: by time, then wave, then file order (sort_custom is not stable).
	for i in _schedule.size():
		_schedule[i].append(i)
	_schedule.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[3] < b[3]))


## Sums upgrade effects: {stat: {add, multiply}}.
static func upgrade_stats(nodes: Dictionary, purchased: Array) -> Dictionary:
	var stats := {}
	for id in purchased:
		var node: Dictionary = nodes.get(id, {})
		if node.is_empty():
			push_error("HoldfastRules: unknown upgrade %s, ignored" % id)
			continue
		for effect in node.get("effects", []):
			var stat := str(effect["stat"])
			var entry: Dictionary = stats.get(stat, {"add": 0.0, "multiply": 1.0})
			entry["add"] += float(effect.get("add", 0.0))
			entry["multiply"] *= float(effect.get("multiply", 1.0))
			stats[stat] = entry
	return stats


static func _add(stats: Dictionary, stat: String) -> float:
	return float(stats.get(stat, {}).get("add", 0.0))


static func _apply(stats: Dictionary, stat: String, base: float) -> float:
	var entry: Dictionary = stats.get(stat, {"add": 0.0, "multiply": 1.0})
	return (base + float(entry["add"])) * float(entry["multiply"])


func step(dt: float, input: Dictionary) -> void:
	if outcome != OUTCOME_RUNNING:
		return
	ticks += 1
	time = ticks * dt
	_spawn_due()
	hero_grace_left = HeroGetUp.tick_grace(hero_grace_left, dt)
	if hero_grace_left < TIME_EPSILON:
		hero_grace_left = 0.0
	_step_enemies(dt)
	if keep_health <= 0:
		_finish(OUTCOME_LOST)
		return
	var aura: Variant = input.get("aura")
	aura_active = aura is Array and aura.size() == 2
	if aura_active:
		aura_position = Vector2(float(aura[0]), float(aura[1]))
		apply_aura(aura_position, dt)
	_step_hero(dt, input)
	_move_projectiles(dt)
	_step_recruits(dt)
	_attack(tower, tower.damage, dt)
	if tower_repair > 0.0 and enemies.is_empty():
		tower.health = UnitHealth.repair(tower.health, tower_repair * dt)
	for recruit in recruits:
		_attack(recruit, recruit.damage + (staff_level - 1) * recruit.damage_per_level, dt)
	_collect_dead()
	_age_effects(dt)
	_pick_up_tokens()
	if _next_spawn >= _schedule.size() and enemies.is_empty():
		_finish(OUTCOME_WON)


## Damage to an enemy from anything but the legacy aura: extra inside a lit area,
## extra again for an attack that likes the dark (`unlit_bonus`) outside one, and
## extra while a Lookout has the enemy marked.
func _hurt(enemy: Enemy, base: float, unlit_bonus: float) -> void:
	var amount := LitArea.damage_for(base, enemy.position, _post_points, light_radius, light_bonus)
	if unlit_bonus > 0.0 and not LitArea.is_lit(enemy.position, _post_points, light_radius):
		amount *= 1.0 + unlit_bonus
	enemy.health -= amount * (1.0 + enemy.mark_bonus)
	if enemy.health <= 0.0:
		_any_dead = true


# --- Enemies: pick a target, walk to it, hit it ---------------------------

## Rebuilds, when a unit has gone down or got up, what enemies may walk to and
## what the staffed posts do (RecruitRules.post_effects gives each staffing
## Recruit's effect: a taunt radius, a slowing and marking zone, a field or repairs).
func _refresh_targets() -> void:
	if not hero_state["downed"]:
		_hero_candidate["pos"] = hero_position
	if not _targets_dirty:
		return
	_candidates.clear()
	_lookouts.clear()
	_ticking.clear()
	if _hero_targetable:
		_candidates.append(_hero_candidate)
	for unit in _defenders:
		unit.candidate["taunt_radius"] = 0.0
		if not unit.up:
			continue
		_candidates.append(unit.candidate)
		if unit.kind != "recruit" or unit.post == "":
			continue
		var given := RecruitRules.post_effects([unit.health], _role_effects)
		if given.is_empty():
			continue
		var fx: Dictionary = given[0]["effect"]
		var centre: Vector2 = _post_at[unit.post]
		var reach := float(fx.get("effect_radius", 0.0))
		unit.candidate["taunt_radius"] = float(fx.get("taunt_radius", 0.0))
		if fx.has("slow") or fx.has("mark_bonus"):
			_lookouts.append([centre, reach, float(fx.get("slow", 0.0)), float(fx.get("mark_bonus", 0.0))])
		if fx.has("field_dps") or fx.has("repair_per_second"):
			_ticking.append([centre, reach, float(fx.get("field_dps", 0.0)), float(fx.get("repair_per_second", 0.0))])


func _step_enemies(dt: float) -> void:
	var targetable: bool = not hero_state["downed"] and not hero_untouchable()
	if targetable != _hero_targetable:
		_hero_targetable = targetable
		_targets_dirty = true
	var retarget_all := _targets_dirty
	_refresh_targets()
	if retarget_all:
		_targets_dirty = false
		for enemy in enemies:
			enemy.retarget_in = 0
	var kept := 0
	for enemy in enemies:
		var slow := enemy.zone_slow
		if enemy.slowed_for > 0.0:
			enemy.slowed_for = maxf(enemy.slowed_for - dt, 0.0)
			slow = maxf(slow, enemy.slow_amount)
		enemy.retarget_in -= 1
		if enemy.retarget_in <= 0:
			_pick_target(enemy)
		var goal := Vector2.ZERO
		var contact := keep_radius + enemy.radius
		var unit := enemy.target_unit
		if unit != null:
			goal = unit.position
			contact = unit.radius + enemy.radius
		elif enemy.target != "":
			goal = hero_position
			contact = hero_radius + enemy.radius
		var to_goal := goal - enemy.position
		var dist := to_goal.length()
		var travel := enemy.speed * (1.0 - slow) * dt
		if dist - travel <= contact:
			if enemy.target == "":
				keep_health = maxi(keep_health - enemy.damage, 0)
				_wave_gone(enemy.wave, false)
				continue
			if dist > contact:
				enemy.position += to_goal / dist * (dist - contact)
			enemy.hit_in -= dt
			if enemy.hit_in <= 0.0:
				enemy.hit_in = enemy.hit_interval
				_hit_unit(unit, enemy.damage)
		else:
			enemy.position += to_goal / dist * travel
		enemies[kept] = enemy
		kept += 1
	enemies.resize(kept)


## Sets the enemy's target: the tower, unless the Hero or a Recruit is within
## the enemy's engage distance and nearer; a staffed Warden within its taunt radius
## pulls the enemy in ahead of the rest. The keep ("") when the tower is down and
## nobody is that close.
func _pick_target(enemy: Enemy) -> void:
	var open := EnemyTargeting.within_reach(enemy.position, _candidates, enemy.engage_distance)
	enemy.target = RecruitRules.pick_target(enemy.position, open, _tie_order)
	enemy.target_unit = _by_key.get(enemy.target)
	enemy.retarget_in = RETARGET_TICKS
	# A staffed Lookout's mark and slow are checked at the same pace.
	enemy.zone_slow = 0.0
	enemy.mark_bonus = 0.0
	for fx in _lookouts:
		if enemy.position.distance_to(fx[0]) <= fx[1] + enemy.radius:
			enemy.zone_slow = maxf(enemy.zone_slow, fx[2])
			enemy.mark_bonus = maxf(enemy.mark_bonus, fx[3])


## `unit` is the tower or Recruit that was hit, or null for the Hero.
func _hit_unit(unit: Attacker, amount: float) -> void:
	if unit == null:
		if hero_untouchable():
			return
		var before := int(hero_state["knockdowns"])
		hero_state = HeroGetUp.take_damage(hero_state, amount, hero_delays, hero_grace_left)
		if int(hero_state["knockdowns"]) > before:
			_targets_dirty = true
			var fall := HeroGetUp.start_fall(hero_position, carried_xp)
			hero_fell_at = fall["fell_at"]
			if fall["drop_amount"] > 0:
				var token := XpToken.new()
				token.position = fall["drop_pos"]
				token.amount = fall["drop_amount"]
				xp_tokens.append(token)
				carried_xp = 0
		return
	if unit.kind == "tower":
		unit.health = UnitHealth.damage(unit.health, amount)
		unit.up = unit.health["alive"]
	else:
		unit.health = RecruitRules.damage(unit.health, amount)
		unit.up = not unit.health["downed"]
	if unit.up:
		return
	_targets_dirty = true
	if unit.kind == "tower":
		towers_lost += 1
	else:
		recruits_downed += 1


# --- Recruits: revive, and the effect of staffing a post -------------------

func _step_recruits(dt: float) -> void:
	var enemy_points: Array = []
	var points_built := false
	for recruit in recruits:
		if not recruit.up:
			_revive(recruit, dt)
			continue
		var at_home := recruit.position == recruit.home
		if not (at_home and (recruit.post != "" or recruit.leash <= 0.0)):
			if not points_built:
				points_built = true
				for enemy in enemies:
					if enemy.health > 0.0:
						enemy_points.append(enemy.position)
			_walk(recruit, enemy_points, dt)
			at_home = recruit.position == recruit.home
		if at_home and recruit.rest_heal > 0.0:
			recruit.health = RecruitRules.rest(recruit.health, recruit.rest_heal * dt)
	for fx in _ticking:
		if fx[2] > 0.0:
			for enemy in enemies:
				if enemy.health > 0.0 and enemy.position.distance_to(fx[0]) <= fx[1] + enemy.radius:
					_hurt(enemy, fx[2] * dt, 0.0)
		if fx[3] > 0.0 and tower.up and tower.position.distance_to(fx[0]) <= fx[1]:
			tower.health = UnitHealth.repair(tower.health, fx[3] * dt)


## One step of a Recruit's walk (RecruitLeash): out to an enemy within their leash
## of home, back home when hurt or when none is in reach, and to their post if they
## staff one.
func _walk(recruit: Attacker, enemy_points: Array, dt: float) -> void:
	recruit.walker["pos"] = recruit.position
	recruit.walker["health"] = recruit.health["health"]
	recruit.walker["max_health"] = recruit.health["max_health"]
	recruit.position = RecruitLeash.step(recruit.walker, enemy_points, dt)["pos"]
	recruit.candidate["pos"] = recruit.position


## A downed Recruit gets back up once the Hero has stood on them for their
## `revive_seconds` (RecruitRules); stepping off starts the count again.
func _revive(recruit: Attacker, dt: float) -> void:
	var on: bool = not hero_state["downed"] and RecruitRules.standing(hero_position, recruit.position, recruit.radius + hero_radius)
	recruit.health = RecruitRules.tick_revive(recruit.health, on, dt, float(recruit.role["revive_seconds"]), float(recruit.role["revive_health"]))
	if recruit.health["downed"]:
		return
	recruit.up = true
	recruits_revived += 1
	_targets_dirty = true


# --- The Hero -------------------------------------------------------------

## The Hero for one tick: move, face the nearest enemy, attack on the cooldown
## when that enemy is in range, and use the ability when asked. A knocked-down
## Hero only waits, then gets back up where they fell, untouchable for a short
## while. The keyboard and the bot reach this only through the tick input.
func _step_hero(dt: float, input: Dictionary) -> void:
	hero_attack_ready_in = maxf(hero_attack_ready_in - dt, 0.0)
	hero_ability_ready_in = maxf(hero_ability_ready_in - dt, 0.0)
	hero_rapid_left = maxf(hero_rapid_left - dt, 0.0)
	hero_rapid_ready_in = maxf(hero_rapid_ready_in - dt, 0.0)
	if hero_state["downed"]:
		hero_rapid_left = 0.0
		hero_state = HeroKnockdown.tick(hero_state, dt)
		if not hero_state["downed"]:
			# The square round the keep (with the Hero's own width) is ground they cannot stand on.
			var keep_square := keep_radius + hero_radius
			var up := HeroGetUp.rise(hero_fell_at, Rect2(-arena_half, arena_half * 2.0), [Rect2(-keep_square, -keep_square, 2.0 * keep_square, 2.0 * keep_square)], hero_untouchable_seconds)
			hero_position = up["pos"]
			hero_grace_left = up["grace_left"]
			_targets_dirty = true
		return
	var move := _input_vector(input.get("move"))
	if move != Vector2.ZERO:
		hero_position = _in_arena(hero_position + move * hero_speed * dt)
	var target := _nearest_enemy(hero_position)
	var to_target := Vector2.ZERO if target == null else target.position - hero_position
	if to_target.length_squared() > 0.0001:
		hero_facing = to_target.normalized()
	elif target == null and move != Vector2.ZERO:
		hero_facing = move.normalized()
	if hero_attack_ready_in <= 0.0 and target != null and to_target.length() <= float(hero_attack["range"]) + target.radius:
		hero_attack_ready_in = float(hero_attack["cooldown"])
		_use(hero_attack, target)
	var ability: Variant = input.get("ability")
	if ability is bool and ability and hero_ability_ready_in <= 0.0:
		hero_ability_ready_in = float(hero_ability["cooldown"])
		if float(hero_ability.get("rapid_seconds", 0.0)) > 0.0:
			hero_rapid_left = float(hero_ability["rapid_seconds"])
			hero_rapid_ready_in = 0.0
		else:
			_use(hero_ability, target)
	if hero_rapid_left > 0.0 and hero_rapid_ready_in <= 0.0:
		hero_rapid_ready_in = float(hero_ability.get("rapid_interval", hero_attack["cooldown"]))
		_fire(hero_ability)


## `at` held inside the arena, edges included.
func _in_arena(at: Vector2) -> Vector2:
	return Vector2(clampf(at.x, -arena_half.x, arena_half.x), clampf(at.y, -arena_half.y, arena_half.y))


## The arena's width and height, for drawing.
func arena_size() -> Vector2:
	return arena_half * 2.0


## True while the Hero cannot be hurt or picked as a target after getting up.
func hero_untouchable() -> bool:
	return hero_grace_left > 0.0


## A move input as a vector of at most length 1. Anything that is not a pair of
## finite numbers is no movement.
static func _input_vector(value: Variant) -> Vector2:
	if not value is Array or value.size() != 2:
		return Vector2.ZERO
	for part in value:
		if not (part is float or part is int) or not is_finite(part):
			return Vector2.ZERO
	return Vector2(clampf(float(value[0]), -1.0, 1.0), clampf(float(value[1]), -1.0, 1.0)).limit_length(1.0)


## The living enemy nearest `from`; the first one in spawn order on a tie.
func _nearest_enemy(from: Vector2) -> Enemy:
	var best: Enemy = null
	var best_dist := INF
	for enemy in enemies:
		if enemy.health <= 0.0:
			continue
		var dist := enemy.position.distance_squared_to(from)
		if dist < best_dist:
			best = enemy
			best_dist = dist
	return best


## The three attack behaviours a pack can ask for: "projectile" (arrows along the
## facing), "area" (a burst at the nearest enemy, or round the Hero) and "arc" (a
## sweep in front of the Hero, or a dash through the enemies).
func _use(action: Dictionary, target: Enemy) -> void:
	match str(action["kind"]):
		"projectile":
			_fire(action)
		"area":
			_burst(action, target)
		"arc":
			_sweep(action)


## Launches the arrows of an attack or ability from the Hero along their facing:
## `count` of them (default 1), spread evenly across `spread_degrees`.
func _fire(action: Dictionary) -> void:
	var count := int(action.get("count", 1))
	var spread := deg_to_rad(float(action.get("spread_degrees", 0.0)))
	for i in count:
		var offset := 0.0 if count == 1 else (float(i) / (count - 1) - 0.5) * spread
		var arrow := Projectile.new()
		arrow.position = hero_position
		arrow.velocity = hero_facing.rotated(offset) * float(action["speed"])
		arrow.damage = float(action["damage"])
		arrow.radius = float(action["radius"])
		arrow.distance_left = float(action["range"])
		projectiles.append(arrow)


## Damages every enemy within `radius` of the burst's centre: the target, or the
## Hero when the action says `centre: hero`. May slow them (`slow`, `slow_seconds`).
func _burst(action: Dictionary, target: Enemy) -> void:
	var centre := hero_position if target == null or str(action.get("centre", "")) == "hero" else target.position
	var radius := float(action["radius"])
	for enemy in enemies:
		if enemy.health > 0.0 and enemy.position.distance_to(centre) <= radius + enemy.radius:
			_hurt(enemy, float(action["damage"]), float(action.get("unlit_bonus", 0.0)))
			if action.has("slow"):
				enemy.slow_amount = float(action["slow"])
				enemy.slowed_for = float(action.get("slow_seconds", 0.0))
	_add_effect("burst", centre, radius, Vector2.ZERO)


## Strikes enemies within `range` in front of the Hero, across `arc_degrees`. With
## `dash_distance` the Hero first dashes along their facing and strikes everything
## within `range` of the path instead. `refund_on_kill` resets the ability's
## cooldown when the strike kills.
func _sweep(action: Dictionary) -> void:
	var reach := float(action["range"])
	var dash := float(action.get("dash_distance", 0.0))
	var from := hero_position
	if dash > 0.0:
		hero_position = _in_arena(from + hero_facing * dash)
	var half_arc := deg_to_rad(float(action.get("arc_degrees", 360.0))) / 2.0
	var killed := false
	for enemy in enemies:
		if enemy.health <= 0.0:
			continue
		var offset := enemy.position - from
		var hit: bool
		if dash > 0.0:
			hit = Geometry2D.get_closest_point_to_segment(enemy.position, from, hero_position).distance_to(enemy.position) <= reach + enemy.radius
		else:
			hit = offset.length() <= reach + enemy.radius and (offset.length_squared() < 0.0001 or absf(hero_facing.angle_to(offset)) <= half_arc + 0.0001)
		if hit:
			_hurt(enemy, float(action["damage"]), float(action.get("unlit_bonus", 0.0)))
			killed = killed or enemy.health <= 0.0
	if killed and bool(action.get("refund_on_kill", false)):
		hero_ability_ready_in = 0.0
	if dash > 0.0:
		_add_effect("dash", from, reach, hero_position - from)
	else:
		_add_effect("arc", from, reach, hero_facing * deg_to_rad(float(action.get("arc_degrees", 360.0))))


func _add_effect(kind: String, at: Vector2, radius: float, vector: Vector2) -> void:
	var effect := Effect.new()
	effect.kind = kind
	effect.position = at
	effect.radius = radius
	effect.vector = vector
	effect.ttl = EFFECT_SECONDS
	effects.append(effect)


func _age_effects(dt: float) -> void:
	if effects.is_empty():
		return
	var kept: Array[Effect] = []
	for effect in effects:
		effect.ttl -= dt
		if effect.ttl > 0.0:
			kept.append(effect)
	effects = kept


func _pick_up_tokens() -> void:
	if hero_state["downed"] or xp_tokens.is_empty():
		return
	var left: Array[XpToken] = []
	for token in xp_tokens:
		if token.position.distance_to(hero_position) <= hero_pickup_radius:
			carried_xp += token.amount
		else:
			left.append(token)
	xp_tokens = left


## Flies every arrow for one tick. An arrow stops at the first living enemy its
## path touches (checked along the whole step, so a fast arrow can't skip one).
func _move_projectiles(dt: float) -> void:
	var flying: Array[Projectile] = []
	for arrow in projectiles:
		var travel := minf(arrow.velocity.length() * dt, arrow.distance_left)
		var from := arrow.position
		var to := from + arrow.velocity.normalized() * travel
		var hit := _first_enemy_on_path(from, to, arrow.radius)
		if hit != null:
			_hurt(hit, arrow.damage, 0.0)
			continue
		arrow.position = to
		arrow.distance_left -= travel
		if arrow.distance_left > 0.0:
			flying.append(arrow)
	projectiles = flying


func _first_enemy_on_path(from: Vector2, to: Vector2, radius: float) -> Enemy:
	var best: Enemy = null
	var best_along := INF
	var mid := (from + to) / 2.0
	var half := from.distance_to(to) / 2.0 + radius
	for enemy in enemies:
		if enemy.health <= 0.0:
			continue
		var near := half + enemy.radius
		if enemy.position.distance_squared_to(mid) > near * near:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.position, from, to)
		if closest.distance_to(enemy.position) > enemy.radius + radius:
			continue
		var along := from.distance_squared_to(closest)
		if along < best_along:
			best = enemy
			best_along = along
	return best


## M1's aura damage for one tick at `at`. Nothing sends an aura input now that
## the Hero replaces the mouse (HF-M2-14); kept until the tests that pin it go.
func apply_aura(at: Vector2, dt: float) -> void:
	var reach := aura_radius
	for enemy in enemies:
		if enemy.health > 0.0 and enemy.position.distance_to(at) <= reach + enemy.radius:
			enemy.health -= aura_dps * dt
			_any_dead = _any_dead or enemy.health <= 0.0


func _spawn_due() -> void:
	while _next_spawn < _schedule.size() and _schedule[_next_spawn][0] <= time + 0.000001:
		var entry: Array = _schedule[_next_spawn]
		_next_spawn += 1
		var w: int = entry[1]
		if w + 1 > wave:
			_bank_xp()
		wave = maxi(wave, w + 1)
		var data: Dictionary = _enemy_types[entry[2]]
		var enemy := Enemy.new()
		enemy.uid = _next_uid
		_next_uid += 1
		enemy.type = entry[2]
		enemy.wave = w
		var angle := _rng.next_float() * TAU
		enemy.position = _in_arena(Vector2(cos(angle), sin(angle)) * spawn_radius)
		enemy.max_health = float(data["health"]) * _wave_health_scale[w]
		enemy.health = enemy.max_health
		enemy.speed = float(data["speed"])
		enemy.radius = float(data["radius"])
		enemy.damage = roundi(float(data["damage"]) * _wave_damage_scale[w])
		enemy.gold = int(data["gold"])
		enemy.engage_distance = float(data["engage_distance"])
		enemy.xp_chance = float(data.get("xp_chance", 0.0))
		enemy.xp_value = int(data.get("xp_value", 0))
		enemy.hit_interval = float(data.get("hit_interval", 1.0))
		enemies.append(enemy)


func _attack(attacker: Attacker, damage: float, dt: float) -> void:
	attacker.ready_in = maxf(attacker.ready_in - dt, 0.0)
	attacker.last_target = -1
	if attacker.ready_in > 0.0 or not attacker.up:
		return
	var best: Enemy = null
	var best_dist := INF
	for enemy in enemies:
		if enemy.health <= 0.0:
			continue
		var reach := attacker.attack_range + enemy.radius
		if enemy.position.distance_squared_to(attacker.position) > reach * reach:
			continue
		var to_keep := enemy.position.length()
		if to_keep < best_dist:
			best = enemy
			best_dist = to_keep
	if best == null:
		attacker.ready_in = SCAN_SECONDS
		return
	_hurt(best, damage, 0.0)
	attacker.ready_in = attacker.cooldown
	attacker.last_target = best.uid


func _collect_dead() -> void:
	if not _any_dead:
		return
	_any_dead = false
	var alive: Array[Enemy] = []
	for enemy in enemies:
		if enemy.health > 0.0:
			alive.append(enemy)
			continue
		kills += 1
		gold += roundi(enemy.gold * gold_multiplier)
		# Drawn for every kill, in a fixed order, so the sequence stays deterministic.
		if _rng.chance(enemy.xp_chance) and enemy.xp_value > 0:
			carried_xp += enemy.xp_value
		_wave_gone(enemy.wave, true)
	enemies = alive


## The Hero's carried XP counts (and levels the Recruits) once banked: when the
## next wave starts and when the run ends.
func _bank_xp() -> void:
	if carried_xp > 0:
		_gain_xp(carried_xp)
		carried_xp = 0


func _gain_xp(amount: int) -> void:
	xp += amount
	staff_xp += amount
	while staff_xp >= staff_xp_per_level * staff_level:
		staff_xp -= staff_xp_per_level * staff_level
		staff_level += 1


func _wave_gone(w: int, killed: bool) -> void:
	_wave_remaining[w] -= 1
	if not killed:
		_wave_leaked[w] = 1
	if _wave_remaining[w] == 0 and _wave_leaked[w] == 0:
		waves_cleared += 1


## What the banner says: "Wave N" for the last `wave_pause` seconds before wave N starts
## (so it is up as the wave arrives); "" at any other time, and always with no pause.
func wave_banner() -> String:
	if wave_pause <= 0.0 or wave >= total_waves:
		return ""
	var until := _wave_starts[wave] - time
	if until > TIME_EPSILON and until <= wave_pause + TIME_EPSILON:
		return "Wave %d" % (wave + 1)
	return ""


func _finish(result_outcome: String) -> void:
	_bank_xp()
	outcome = result_outcome


func is_finished() -> bool:
	return outcome != OUTCOME_RUNNING


func result() -> Dictionary:
	return {
		"outcome": outcome,
		"level": level_id,
		"gold": gold,
		"xp": xp,
		"staff_level": staff_level,
		"kills": kills,
		"wave": wave,
		"waves_cleared": waves_cleared,
		"total_waves": total_waves,
		"keep_health": keep_health,
		"keep_health_max": keep_health_max,
		"ticks": ticks,
		"seconds": time,
		"towers_lost": towers_lost,
		"recruits_downed": recruits_downed,
		"recruits_revived": recruits_revived,
		"hero_knockdowns": int(hero_state["knockdowns"]) if not hero_state.is_empty() else 0,
	}


func snapshot() -> Dictionary:
	var list := []
	for e in enemies:
		list.append([e.uid, e.type, e.wave, e.position.x, e.position.y, e.health, e.target, e.retarget_in, e.hit_in, e.slowed_for, e.mark_bonus])
	return {
		"result": result(),
		"staff_xp": staff_xp,
		"aura": [aura_active, aura_position.x, aura_position.y],
		"hero": [hero_position.x, hero_position.y, hero_facing.x, hero_facing.y, hero_attack_ready_in, hero_ability_ready_in, hero_rapid_left, hero_rapid_ready_in],
		"hero_state": hero_state,
		"hero_grace_left": hero_grace_left,
		"carried_xp": carried_xp,
		"xp_tokens": _token_states(),
		"recruits": _recruit_states(),
		"projectiles": _projectile_states(),
		"tower": _attacker_state(tower),
		"staff": _attacker_state(staff),
		"next_spawn": _next_spawn,
		"next_uid": _next_uid,
		"wave_remaining": Array(_wave_remaining),
		"wave_leaked": Array(_wave_leaked),
		"enemies": list,
	}


func _token_states() -> Array:
	var list := []
	for token in xp_tokens:
		list.append([token.position.x, token.position.y, token.amount])
	return list


func _recruit_states() -> Array:
	var list := []
	for unit in _defenders:
		list.append([unit.key, unit.health["health"], unit.up, unit.health.get("revive_progress", 0.0), unit.position.x, unit.position.y])
	return list


func _projectile_states() -> Array:
	var list := []
	for p in projectiles:
		list.append([p.position.x, p.position.y, p.velocity.x, p.velocity.y, p.damage, p.distance_left])
	return list


static func _attacker_state(a: Attacker) -> Array:
	return [] if a == null else [a.ready_in, a.last_target, a.damage]
