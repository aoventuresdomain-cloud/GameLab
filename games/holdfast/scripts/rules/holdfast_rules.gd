class_name HoldfastRules
extends SimRules
## Holdfast combat rules for one run, on the Studio Kit's simulation engine.
##
## Enemies come in waves from the edge of the map and walk to the keep at the
## origin. The aura (where the input says the cursor is), one tower and one
## staff member damage them. Kills drop gold and sometimes staff XP. The run
## ends when the keep falls or the last wave is cleared.
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
## input per tick: {aura: [x, y]} (optional; no aura that tick when missing)

## Ticks per simulated second, for the headless run and the playable build alike.
const TICK_RATE := 10

const OUTCOME_RUNNING := "running"
const OUTCOME_WON := "won"
const OUTCOME_LOST := "lost"
## Setup failed (unknown level); the run is over before it starts.
const OUTCOME_INVALID := "invalid"

const DEFAULT_WAVE_DELAY := 5.0
const DEFAULT_INTERVAL := 1.0
const DEFAULT_CURSOR_SPEED := 1800.0


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
	var xp_value: int


## A tower or staff member: attacks the enemy nearest the keep within range.
class Attacker:
	extends RefCounted
	var id: String
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
var staff_damage_per_level := 0.0
var aura_position := Vector2.ZERO
var aura_active := false
var enemies: Array[Enemy] = []
var tower: Attacker
var staff: Attacker
var outcome := OUTCOME_RUNNING
## 1-based number of the latest wave that has started; 0 before the first.
var wave := 0
## Waves whose every enemy was killed. A wave with an enemy that reached the
## keep is never cleared.
var waves_cleared := 0

## Why setup failed, or "" when it did not.
var setup_error := ""
## Log setup errors with push_error. Tests that provoke one on purpose turn it off.
var report_errors := true

var _rng: SimRng
var _enemy_types: Dictionary = {}
## Spawn schedule, sorted by time: [time, wave index, enemy id].
var _schedule: Array = []
var _next_spawn := 0
var _wave_starts: PackedFloat64Array = []
var _wave_remaining: PackedInt32Array = []
var _wave_leaked: PackedByteArray = []
var _next_uid := 1


func setup(config: Dictionary, rng: SimRng) -> void:
	_rng = rng
	var content: Dictionary = config.get("content", {})
	level_id = str(config.get("level", ""))
	var level: Dictionary = content.get("levels", {}).get(level_id, {})
	if level.is_empty():
		# Not assert: asserts are stripped from release builds.
		setup_error = "unknown level %s" % level_id
		if report_errors:
			push_error("HoldfastRules: " + setup_error)
		outcome = OUTCOME_INVALID
		return
	_enemy_types = content.get("enemies", {})

	var stats := HoldfastRules.upgrade_stats(content.get("upgrade_nodes", {}), config.get("upgrades", []))
	keep_health_max = int(level["keep_health"]) + int(_add(stats, "keep_health"))
	keep_health = keep_health_max
	keep_radius = float(level["keep_radius"])
	spawn_radius = float(level["spawn_radius"])
	var aura: Dictionary = level["aura"]
	aura_radius = _apply(stats, "aura_radius", float(aura["radius"]))
	aura_dps = _apply(stats, "aura_dps", float(aura["dps"]))
	cursor_speed = float(aura.get("cursor_speed", DEFAULT_CURSOR_SPEED))
	gold_multiplier = _apply(stats, "gold_multiplier", 1.0)

	var tower_at: Dictionary = level["tower"]
	var tower_data: Dictionary = content["towers"][tower_at["id"]]
	tower = _attacker(tower_at, tower_data, _apply(stats, "tower_damage", float(tower_data["damage"])))
	var staff_at: Dictionary = level["staff"]
	var staff_data: Dictionary = content["staff"][staff_at["id"]]
	staff = _attacker(staff_at, staff_data, _apply(stats, "staff_damage", float(staff_data["damage"])))
	staff_xp_per_level = int(staff_data["xp_per_level"])
	staff_damage_per_level = float(staff_data["damage_per_level"])

	_build_schedule(level)


func _attacker(at: Dictionary, data: Dictionary, damage: float) -> Attacker:
	var a := Attacker.new()
	a.id = str(at["id"])
	a.position = Vector2(float(at["x"]), float(at["y"]))
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
	for w in waves.size():
		var data: Dictionary = waves[w]
		if w > 0:
			start += float(data.get("delay", DEFAULT_WAVE_DELAY))
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
	_move_enemies(dt)
	if keep_health <= 0:
		_finish(OUTCOME_LOST)
		return
	var aura: Variant = input.get("aura")
	aura_active = aura is Array and aura.size() == 2
	if aura_active:
		aura_position = Vector2(float(aura[0]), float(aura[1]))
		apply_aura(aura_position, dt)
	_attack(tower, tower.damage, dt)
	_attack(staff, staff.damage + (staff_level - 1) * staff_damage_per_level, dt)
	_collect_dead()
	if _next_spawn >= _schedule.size() and enemies.is_empty():
		_finish(OUTCOME_WON)


## The aura's damage for one tick at `at`. The player's mouse and the bot both
## reach it only through the tick input, so they share this one function.
func apply_aura(at: Vector2, dt: float) -> void:
	var reach := aura_radius
	for enemy in enemies:
		if enemy.health > 0.0 and enemy.position.distance_to(at) <= reach + enemy.radius:
			enemy.health -= aura_dps * dt


func _spawn_due() -> void:
	while _next_spawn < _schedule.size() and _schedule[_next_spawn][0] <= time + 0.000001:
		var entry: Array = _schedule[_next_spawn]
		_next_spawn += 1
		var w: int = entry[1]
		wave = maxi(wave, w + 1)
		var data: Dictionary = _enemy_types[entry[2]]
		var enemy := Enemy.new()
		enemy.uid = _next_uid
		_next_uid += 1
		enemy.type = entry[2]
		enemy.wave = w
		var angle := _rng.next_float() * TAU
		enemy.position = Vector2(cos(angle), sin(angle)) * spawn_radius
		enemy.max_health = float(data["health"])
		enemy.health = enemy.max_health
		enemy.speed = float(data["speed"])
		enemy.radius = float(data["radius"])
		enemy.damage = int(data["damage"])
		enemy.gold = int(data["gold"])
		enemy.xp_chance = float(data.get("xp_chance", 0.0))
		enemy.xp_value = int(data.get("xp_value", 0))
		enemies.append(enemy)


func _move_enemies(dt: float) -> void:
	var still: Array[Enemy] = []
	for enemy in enemies:
		var dist := enemy.position.length()
		var reach := keep_radius + enemy.radius
		var travel := enemy.speed * dt
		if dist - travel <= reach:
			keep_health = maxi(keep_health - enemy.damage, 0)
			_wave_gone(enemy.wave, false)
			continue
		enemy.position -= enemy.position / dist * travel
		still.append(enemy)
	enemies = still


func _attack(attacker: Attacker, damage: float, dt: float) -> void:
	attacker.ready_in = maxf(attacker.ready_in - dt, 0.0)
	attacker.last_target = -1
	if attacker.ready_in > 0.0:
		return
	var best: Enemy = null
	var best_dist := INF
	for enemy in enemies:
		if enemy.health <= 0.0:
			continue
		if enemy.position.distance_to(attacker.position) > attacker.attack_range + enemy.radius:
			continue
		var to_keep := enemy.position.length()
		if to_keep < best_dist:
			best = enemy
			best_dist = to_keep
	if best == null:
		return
	best.health -= damage
	attacker.ready_in = attacker.cooldown
	attacker.last_target = best.uid


func _collect_dead() -> void:
	var alive: Array[Enemy] = []
	for enemy in enemies:
		if enemy.health > 0.0:
			alive.append(enemy)
			continue
		kills += 1
		gold += roundi(enemy.gold * gold_multiplier)
		# Drawn for every kill, in a fixed order, so the sequence stays deterministic.
		if _rng.chance(enemy.xp_chance) and enemy.xp_value > 0:
			_gain_xp(enemy.xp_value)
		_wave_gone(enemy.wave, true)
	enemies = alive


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


func _finish(result_outcome: String) -> void:
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
	}


func snapshot() -> Dictionary:
	var list := []
	for e in enemies:
		list.append([e.uid, e.type, e.wave, e.position.x, e.position.y, e.health])
	return {
		"result": result(),
		"staff_xp": staff_xp,
		"aura": [aura_active, aura_position.x, aura_position.y],
		"tower": _attacker_state(tower),
		"staff": _attacker_state(staff),
		"next_spawn": _next_spawn,
		"next_uid": _next_uid,
		"wave_remaining": Array(_wave_remaining),
		"wave_leaked": Array(_wave_leaked),
		"enemies": list,
	}


static func _attacker_state(a: Attacker) -> Array:
	return [] if a == null else [a.ready_in, a.last_target, a.damage]
