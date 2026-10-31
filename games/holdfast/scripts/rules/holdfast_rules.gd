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
## Where a Recruit stands beside the post they staff.
const POST_OFFSET := Vector2(12.0, -12.0)
## A tower or Recruit with nothing in range looks again after this long.
const SCAN_SECONDS := 0.1
## How long a Recruit's level-up flash and bark show, and how far above the flee line they must heal to come back.
const FLASH_SECONDS := 1.0
const BARK_SECONDS := 2.0
const FLEE_RECOVERY := 0.25
## The most damage armour can turn away, and the shortest a get-up wait can become (a share of base).
const HERO_ARMOUR_CAP := 0.7
const HERO_GETUP_MIN := 0.5
## Enemies within the barrage's reach that set off Keeper's Habit, and how long they must have been
## there: the player's own press gets that long to come first, and fires at full power.
const HABIT_ENEMIES := 3
const HABIT_DELAY := 0.3
## Crossfire: a second shot from another post counts when it lands this soon after the first.
const CROSSFIRE_SECONDS := 1.0
## Last Light flares when a post is down to this share of its health.
const LAST_LIGHT_AT := 0.25
## How long the Hero cannot be hurt after getting up, when the Hero path does not say.
const DEFAULT_UNTOUCHABLE_SECONDS := 2.0
## A time within this of a deadline counts as having reached it.
const TIME_EPSILON := 0.000001
## The arena's width and height when the level does not give them.
const DEFAULT_ARENA := Vector2(1920.0, 858.0)
## The post a layout builds when the level names none of its own.
const DEFAULT_TOWER := "archer_post"


class Enemy:
	extends RefCounted
	var uid: int
	## The post that last shot this enemy and when (Crossfire).
	var shot_by := ""
	var shot_at := -100.0
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
	## Burning from a fire arrow: damage a second, and seconds left.
	var burn_dps := 0.0
	var burn_left := 0.0
	## "normal", "elite" or "boss" (pack: tier). An elite or boss kill may drop gear.
	var tier := "normal"
	## A boss's shroud: every hit is turned away unless the Hero cast its ability within
	## `exposed_seconds` (pack: required_ability, exposed_seconds). "" is no shroud.
	var required_ability := ""
	var exposed_seconds := 0.0
	var exposed_left := 0.0
	## Stays at the keep and keeps hitting it, instead of spending itself on one blow (pack: besieges).
	var besieges := false


## An arrow of the Hero's attack or ability, in flight until it hits or runs out of range.
class Projectile:
	extends RefCounted
	var position: Vector2
	var velocity: Vector2
	var damage: float
	var radius: float
	var distance_left: float
	## Enemies it can still hurt before it is spent (1 = stops at the first), the ones it has
	## hurt already, the burn it leaves on each, and the colour it is drawn in ("" = the default).
	var pierce_left := 1
	var hit: Array = []
	var burn_dps := 0.0
	var burn_seconds := 0.0
	var colour := ""


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
	## Recruits: the effect their post gets (their class's, as their traits and skills left it), the
	## share of damage they shrug off, the health fraction below which they flee to the keep (0: never)
	## and whether they are fleeing now, their level, the XP that level counts and what it grows
	## by, how much XP this run gave them, and the level-up flash and bark still showing.
	var fx: Dictionary = {}
	var armour := 0.0
	var flee_below := 0.0
	var fleeing := false
	var refuge := Vector2.ZERO
	var level := 1
	var xp_total := 0
	var xp_per_level := 1
	var xp_gain := 1.0
	var run_xp := 0
	var flash_left := 0.0
	var bark := ""
	var bark_left := 0.0
	var position: Vector2
	var damage: float
	var attack_range: float
	var cooldown: float
	var ready_in := 0.0
	## Last target, for drawing shots; -1 when none.
	var last_target := -1
	## A tower's upgrade-driven extras (all zero for a plain tower): extra targets
	## shot each attack, the bonus on a lone target, enemies pierced behind the
	## target, a heavier shot every `burst_every` attacks, a volley on everything in
	## range every `storm_every` seconds, and repairs between waves.
	var tower_id := ""
	var extra_targets := 0
	var lone_bonus := 0.0
	var pierce := 0
	var burst_every := 0
	var burst_extra := 0.0
	var storm_every := 0.0
	var storm_share := 0.0
	var repair := 0.0
	var shots := 0
	var storm_in := 0.0
	## The links (tree stars), all zero without them. Lit Post: shoots faster by `hero_haste`
	## with the Hero within `hero_radius`. Crossfire: `crossfire` more damage on an enemy another
	## post hit in the last second. Pillar Echo: arrows burn. Rally: the Hero standing still
	## within `rally_radius` repairs it and shields it (damage cut by `rally_shield`, kept for
	## `rally_seconds`). Last Light: once in danger with the Hero within `last_light_radius`, a
	## volley of `last_light` times its damage on everything in range. Watchtower: the Hero
	## within `watch_radius` shoots `watch_range` further. Posted Hand: shoots `posted_haste`
	## faster again while its `staffer` (a Recruit set on it from the Plan page) is up and the
	## Hero is within `hero_radius`.
	var hero_haste := 0.0
	var posted_haste := 0.0
	var staffer: Attacker = null
	var hero_radius := 0.0
	var crossfire := 0.0
	var burn_dps := 0.0
	var burn_seconds := 0.0
	var rally_repair := 0.0
	var rally_shield := 0.0
	var rally_radius := 0.0
	var rally_seconds := 0.0
	var last_light := 0.0
	var last_light_radius := 0.0
	var watch_range := 0.0
	var watch_radius := 0.0
	var shield_left := 0.0
	var last_light_spent := false
	var last_light_due := false
	## True when any link above is on, which is when the tower's hash carries their state.
	var links := false
	var pierce_width := 0.0
	## A Mage Post's blast: every enemy within `splash_radius` of the target takes the shot, and
	## `unlit_bonus` more outside the posts' light. Dusk Eclipse: a Hero's Eclipse centred within
	## `eclipse_radius` of this post is `eclipse_widen` wider. `colour` is for drawing.
	var splash_radius := 0.0
	var unlit_bonus := 0.0
	var eclipse_widen := 0.0
	var eclipse_radius := 0.0
	var colour := ""


# Level, after upgrades.
var level_id := ""
var keep_health_max := 0
var keep_radius := 0.0
var spawn_radius := 0.0
## Where enemies come from: [centre, width] in degrees; empty means all round.
var spawn_arcs: Array = []
var aura_radius := 0.0
var aura_dps := 0.0
var cursor_speed := DEFAULT_CURSOR_SPEED
var gold_multiplier := 1.0
## A blessing's changes to the run: monsters' speed (a multiplier) and the share of its health
## that the Keep and every tower repair each second while no enemy is on the field.
var enemy_speed := 1.0
var repair_share := 0.0
## A Hard replay's changes to every monster (multipliers on its health and damage), from the level's modifiers.
var enemy_health_scale := 1.0
var enemy_damage_scale := 1.0
## This is a Hard replay: the level's modifiers apply.
var hard := false
## Tower health restored per second while no enemy is on the field (between waves).
var total_waves := 0

# State.
var ticks := 0
var time := 0.0
var keep_health := 0
## What the Keep has lost in all, the Keep's size without a blessing (stars are judged on those two)
## and the part-point of repair not yet added.
var _keep_damage := 0
var _keep_star_max := 0.0
var _keep_mend := 0.0
var _blessed := false
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
## The share (0 to 1) of damage the Hero turns away (gear), at most HERO_ARMOUR_CAP.
var hero_armour := 0.0
## HeroKnockdown state: health, whether they are down and for how much longer.
var hero_state: Dictionary = {}
var hero_delays: Array = []
## Seconds the Hero cannot be hurt after getting up, and how many are left.
var hero_untouchable_seconds := DEFAULT_UNTOUCHABLE_SECONDS
var hero_grace_left := 0.0
## True while the Hero is up and standing still (Rally).
var hero_holding := false
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
## How much of the barrage's power the cast in progress has: 1 for a press, the Habit's `auto_power` when it fired itself.
var hero_rapid_power := 1.0
## Seconds the barrage has been ready with enough enemies in reach, for Keeper's Habit.
var hero_habit_for := 0.0
## An Eclipse zone: seconds left, and where. Enemies in it are pulled in and slowed; it collapses at the end.
var zone_left := 0.0
var zone_position := Vector2.ZERO
## How much wider than its pack size the zone is (a Mage Post's Dusk Eclipse), fixed at the cast.
var zone_scale := 1.0
## A chain of dashes: seconds left in all of it and in the current dash, its direction, and who it has hit.
var hero_dash_left := 0.0
var hero_dash_in := 0.0
var hero_dash_dir := Vector2.ZERO
var hero_dash_hit: Array = []
## The Hero stays inside the spawn ring.
## Half the arena's width and height: the keep is at its centre, and nothing
## (the Hero, a spawn) is outside it.
var arena_half := DEFAULT_ARENA * 0.5
var projectiles: Array[Projectile] = []
var enemies: Array[Enemy] = []
var tower: Attacker
## Every Archer Post of the run (`tower` is the first); the level's layout picks them.
var towers: Array[Attacker] = []
## The site or castle spot ids the towers stand on (empty when the level's own tower stands alone).
var layout_ids: Array = []
## A tutorial level: its Keep cannot fall and it builds no tower of its own (the Hero fights alone).
var tutorial := false
## The short fight that follows the two guided buys: the tutorial's own Keep, its `stand` waves,
## and the posts the player's castle holds, not the level's placed one.
var stand := false
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
## Gear dropped this run by an elite or the boss: item ids, none twice.
var gear_found: Array = []
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
var _gear_items: Dictionary = {}
var _gear_rules: Dictionary = {}
var _gear_owned: Array = []
var _level_number := 0
## The item a first win of this level gives ("" for none).
var _first_clear_gear := ""
var _levels_data: Dictionary = {}
## Spawn schedule, sorted by time: [time, wave index, enemy id].
var _schedule: Array = []
var _next_spawn := 0
var _wave_starts: PackedFloat64Array = []
var _wave_health_scale: PackedFloat64Array = []
var _wave_damage_scale: PackedFloat64Array = []
var _wave_remaining: PackedInt32Array = []
var _wave_leaked: PackedByteArray = []
var _next_uid := 1
## The castle's spots by id, for a layout that names them.
var _castle_spots := {}


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
	# Only the tree can change a Recruit's stats for the whole squad, so the squad is built from the tree's sum.
	var tree_nodes: Dictionary = content.get("upgrade_nodes", {})
	var known: Array = config.get("upgrades", []).filter(func(id: Variant) -> bool: return tree_nodes.has(id))
	var placements: Variant = _placements(config, level, content, StatModel.sum(tree_nodes, known))
	if placements == null:
		return
	for at in placements:
		var data: Dictionary = at.get("data", content["staff"].get(at["id"], {}))
		roles.append(str(data["class"]))
		problems.append_array(RecruitRules.validate_revive_time(data["revive_seconds"]))
		problems.append_array(RecruitLeash.validate(data["leash"], data["move_speed"], data["range"], data["retreat_below"]))
	_role_effects = content.get("role_effects", {})
	problems.append_array(RecruitRules.validate_effects(_role_effects, roles))
	if not problems.is_empty():
		_fail(", ".join(problems))
		return
	_enemy_types = content.get("enemies", {})

	_gear_items = content.get("gear_items", {})
	for rules in content.get("gear_rules", {}).values():
		_gear_rules = rules
		break
	_gear_owned = config.get("gear_owned", [])
	_level_number = int(level.get("number", 0))
	_first_clear_gear = str(level.get("first_clear_gear", ""))
	_levels_data = content.get("levels", {})
	tutorial = bool(level.get("tutorial", false))
	stand = tutorial and bool(config.get("stand", false)) and level.has("stand")
	for castle in content.get("castle_rules", {}).values():
		for spot in castle["spots"]:
			_castle_spots[str(spot["id"])] = spot
	for enemy_data in _enemy_types.values():
		if str(enemy_data.get("tier", "normal")) == "boss":
			problems.append_array(BossRules.validate(float(enemy_data["health"]), enemy_data.get("required_ability")))
			if not float(enemy_data.get("exposed_seconds", 0.0)) > 0.0:
				problems.append("a boss needs exposed_seconds above zero")
	if not problems.is_empty():
		_fail(", ".join(problems))
		return
	var nodes: Dictionary = content.get("upgrade_nodes", {}).duplicate()
	var purchased: Array = config.get("upgrades", []).duplicate()
	var equipped: Dictionary = config.get("gear", {})
	for slot in equipped:
		var item: Dictionary = _gear_items.get(equipped[slot], {})
		# Gear is the Hero's: its stats apply to the Hero path being played.
		if not item.is_empty() and str(item["slot"]) == str(slot):
			nodes["gear:" + str(equipped[slot])] = {"hero": hero_path, "effects": item["effects"]}
			purchased.append("gear:" + str(equipped[slot]))
	var stats := HoldfastRules.upgrade_stats(nodes, purchased)
	# Stars are judged on the Keep as the tree builds it, so a blessing never changes them.
	_keep_star_max = _apply(stats, "keep_health", float(level["keep_health"]))
	var blessing_id := str(config.get("blessing", ""))
	if blessing_id != "":
		if not content.get("blessings", {}).has(blessing_id):
			_fail("unknown blessing %s" % blessing_id)
			return
		var blessed := blessing_nodes(content["blessings"][blessing_id], hero_path, content.get("towers", {}).keys())
		_blessed = true
		nodes.merge(blessed)
		purchased.append_array(blessed.keys())
		stats = HoldfastRules.upgrade_stats(nodes, purchased)
	# A Hard replay takes the level's modifiers on top of the tree, the gear and the blessing.
	hard = bool(config.get("hard", false)) and not tutorial
	if hard:
		var changes := []
		for modifier_id in level.get("modifiers", []):
			if not content.get("modifiers", {}).has(modifier_id):
				_fail("unknown modifier %s" % modifier_id)
				return
			changes.append_array(content["modifiers"][modifier_id]["effects"])
		if not changes.is_empty():
			nodes["modifiers"] = {"effects": changes}
			purchased.append("modifiers")
			stats = HoldfastRules.upgrade_stats(nodes, purchased)
	keep_health_max = roundi(_apply(stats, "keep_health", float(level["keep_health"])))
	keep_health = keep_health_max
	enemy_speed = _apply(stats, "enemy_speed", 1.0)
	enemy_health_scale = _apply(stats, "enemy_health", 1.0)
	enemy_damage_scale = _apply(stats, "enemy_damage", 1.0)
	repair_share = _add(stats, "repair_share")
	keep_radius = float(level["keep_radius"])
	# The fog edge is where the keep's beam reaches, and enemies spawn at it.
	spawn_radius = _apply(stats, "beam_reach", float(level["spawn_radius"]))
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
	var hero_key := "hero.%s." % hero_path
	hero_speed = _apply(stats, hero_key + "move_speed", float(hero_data["move_speed"]))
	hero_radius = float(hero_data["radius"])
	hero_colour = str(hero_data.get("colour", hero_colour))
	hero_pickup_radius = _apply(stats, hero_key + "pickup_radius", float(hero_data["pickup_radius"]))
	hero_armour = clampf(_add(stats, hero_key + "armour") / 100.0, 0.0, HERO_ARMOUR_CAP)
	hero_attack = _tuned(hero_data["attack"], hero_key + "attack.", stats)
	hero_ability = _tuned(hero_data["ability"], hero_key + "ability.", stats)
	hero_delays = hero_data["knockdown_delays"]
	var getup := maxf(_apply(stats, hero_key + "getup_time", 1.0), HERO_GETUP_MIN)
	if getup != 1.0:
		hero_delays = hero_delays.map(func(wait: Variant) -> float: return float(wait) * getup)
	hero_untouchable_seconds = float(hero_data.get("untouchable_seconds", DEFAULT_UNTOUCHABLE_SECONDS))
	hero_state = HeroKnockdown.new_state(_apply(stats, hero_key + "health", float(hero_data["health"])))
	var arena: Dictionary = level.get("arena", {})
	arena_half = Vector2(float(arena.get("width", DEFAULT_ARENA.x)), float(arena.get("height", DEFAULT_ARENA.y))) * 0.5
	hero_position = _in_arena(hero_position)
	_tie_order.append("hero")

	spawn_arcs = level.get("spawn_arcs", [])
	var chosen := _chosen_sites(level, layout_spots(config.get("layout", null)), layout_towers(config.get("layout", null)))
	if chosen.is_empty() and not _builds_no_tower(level):
		_fail("layout %s is not a valid set of sites for %s" % [config.get("layout"), level_id])
		return
	for i in chosen.size():
		var at: Dictionary = chosen[i].duplicate()
		var tower_id := str(at.get("tower", level.get("tower", {}).get("id", DEFAULT_TOWER)))
		# The first post keeps the tower's own id as its key, the others add their site.
		at["id"] = tower_id if i == 0 else "%s@%s" % [tower_id, at["id"]]
		var built := _build_tower(at, tower_id, content["towers"][tower_id], stats)
		towers.append(built)
		_defenders.append(built)
	tower = towers[0] if not towers.is_empty() else null
	if _uses_layout(level, layout_spots(config.get("layout", null))):
		for at in chosen:
			layout_ids.append(str(at["id"]))
	# Posted Recruits stand at the tower they were set on, if this run built one there.
	var tower_at := {}
	for i in chosen.size():
		tower_at[str(chosen[i]["id"])] = towers[i]
	for at in placements:
		var data: Dictionary = at["data"] if at.has("data") else content["staff"][at["id"]]
		var site: Variant = at.get("site", "")
		var host: Attacker = tower_at.get(site) if site != "" else null
		if host != null and host.staffer == null:
			at["x"] = host.position.x + POST_OFFSET.x
			at["y"] = host.position.y + POST_OFFSET.y
			at["post"] = "tower:" + str(site)
			_post_at[at["post"]] = host.position
		else:
			host = null
		var recruit := _attacker("recruit", at, data, _apply(stats, "staff_damage", float(data["damage"])))
		recruit.damage_per_level = float(data["damage_per_level"])
		recruit.home = recruit.position
		recruit.leash = float(data["leash"])
		recruit.rest_heal = float(data["rest_heal"])
		recruit.role = data
		recruit.post = str(at.get("post", ""))
		if host != null:
			host.staffer = recruit
		recruit.fx = data.get("fx", _role_effects.get(str(data["class"]), {}))
		recruit.armour = float(data.get("armour", 0.0))
		recruit.flee_below = float(data.get("flee_below", 0.0))
		recruit.xp_gain = float(data.get("xp_gain", 1.0))
		recruit.level = int(data.get("level", 1))
		recruit.xp_per_level = int(data["xp_per_level"])
		recruit.xp_total = int(at.get("xp", 0))
		var away := recruit.home
		recruit.refuge = (away.normalized() if away != Vector2.ZERO else Vector2.RIGHT) * (keep_radius + recruit.radius + 6.0)
		recruit.walker = {
			"role": str(data["class"]), "home": recruit.home, "pos": recruit.position, "leash": recruit.leash,
			"speed": float(data["move_speed"]), "range": recruit.attack_range, "health": 0.0, "max_health": 0.0,
			"retreat_below": float(data["retreat_below"]), "downed": false, "staffing": recruit.post != "",
		}
		if recruit.post != "" and not _post_at.has(recruit.post):
			_fail("recruit %s staffs unknown post %s" % [recruit.id, recruit.post])
			return
		recruits.append(recruit)
	if not recruits.is_empty():
		staff = recruits[0]
		staff_xp_per_level = staff.xp_per_level
	_defenders.append_array(recruits)
	for unit in recruits:
		_tie_order.append(unit.key)
	for built in towers:
		_tie_order.append(built.key)

	_build_schedule(level)


## Where the Recruits stand: the level's own pair when the config names no squad, else the
## squad's Recruits (RecruitRoster data), one to each light post in turn and the rest round the
## keep. [{id, x, y, post, data, xp}]; null (and the run refused) when the squad is not usable.
func _placements(config: Dictionary, level: Dictionary, content: Dictionary, stats: Dictionary) -> Variant:
	if not config.has("squad"):
		var legacy: Array = [level["staff"]]
		legacy.append_array(level.get("recruits", []))
		return legacy
	var squad: Variant = config["squad"]
	if not squad is Array or squad.size() > RecruitRoster.SQUAD_MAX:
		_fail("a squad is a list of at most %d Recruits" % RecruitRoster.SQUAD_MAX)
		return null
	var out := []
	var seen := []
	var ring := Vector2(float(level["staff"]["x"]), float(level["staff"]["y"]))
	var spots: Array = level["posts"]
	# Tower sites the player set Recruits on, {site: Recruit id}; a Recruit with none takes a light post.
	var posted: Dictionary = config["posted"] if config.get("posted") is Dictionary else {}
	for i in squad.size():
		var recruit: Dictionary = squad[i]
		var data := RecruitRoster.build(recruit, content, stats)
		if data.is_empty() or str(recruit["id"]) in seen:
			_fail("Recruit %s cannot join the squad" % str(recruit.get("id", "?")))
			return null
		seen.append(str(recruit["id"]))
		var at := {"id": str(recruit["id"]), "data": data, "xp": int(recruit["xp"])}
		var site: Variant = posted.find_key(str(recruit["id"]))
		if site != null:
			at["site"] = str(site)
		if i < spots.size():
			at["x"] = float(spots[i]["x"]) + POST_OFFSET.x
			at["y"] = float(spots[i]["y"]) + POST_OFFSET.y
			at["post"] = str(spots[i]["id"])
		else:
			var spot := ring.rotated(PI * 0.5 * float(i - spots.size() + 1))
			at["x"] = spot.x
			at["y"] = spot.y
		out.append(at)
	return out


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


## True for a tutorial that names no tower of its own: the Hero fights alone, no post stands.
func _builds_no_tower(level: Dictionary) -> bool:
	return tutorial and not stand and not level.has("tower")


## True when the run builds on a layout: castle spots the layout names, or a level's own `sites`.
func _uses_layout(level: Dictionary, layout: Variant) -> bool:
	return (not tutorial or stand) and (_names_castle_spots(layout) or level.has("sites"))


## A layout entry is a spot id ("spot_3", an Archer Post) or a tower kind and a spot id
## ("mage:spot_3", a Mage Post). These give a layout's spot ids, and the tower id of each
## spot that is not an Archer's.
const LAYOUT_TOWERS := {"mage": "mage_post"}


static func layout_spots(layout: Variant) -> Variant:
	if not layout is Array:
		return layout
	return layout.map(func(entry: Variant) -> Variant: return layout_spot(entry))


static func layout_spot(entry: Variant) -> Variant:
	if not entry is String or not ":" in entry:
		return entry
	return entry.get_slice(":", 1)


static func layout_towers(layout: Variant) -> Dictionary:
	var kinds := {}
	if layout is Array:
		for entry in layout:
			if entry is String and ":" in entry and LAYOUT_TOWERS.has(entry.get_slice(":", 0)):
				kinds[entry.get_slice(":", 1)] = LAYOUT_TOWERS[entry.get_slice(":", 0)]
	return kinds


## The layout entry for a post of `tower_id` on `spot`.
static func layout_entry(spot: String, tower_id: String) -> String:
	var prefix: Variant = LAYOUT_TOWERS.find_key(tower_id)
	return spot if prefix == null else "%s:%s" % [prefix, spot]


func _names_castle_spots(layout: Variant) -> bool:
	return layout is Array and not layout.is_empty() and _castle_spots.has(str(layout[0]))


## The sites the run builds an Archer Post on. A tutorial keeps its one placed tower (its stand
## builds on the castle's spots like any level). A
## layout that names castle spots takes them (no repeats, any of the castle's). Otherwise a
## level with `sites` takes the layout (site ids, at most `max_posts`, no repeats; the first
## site when none is given) and a level without keeps its one placed tower. Empty when the
## layout is bad.
func _chosen_sites(level: Dictionary, layout: Variant, kinds := {}) -> Array:
	if tutorial and not stand:
		return [level["tower"]] if level.has("tower") else []
	if _names_castle_spots(layout):
		# Archers first, so the first post (the tower's own key) is an Archer when there is one.
		var picked := _pick(layout, _castle_spots, _castle_spots.size())
		var archers := []
		var mages := []
		for at in picked:
			var tower_id: String = kinds.get(str(at["id"]), "")
			if tower_id == "":
				archers.append(at)
			else:
				var mage: Dictionary = at.duplicate()
				mage["tower"] = tower_id
				mages.append(mage)
		return archers + mages
	if not level.has("sites"):
		return [level["tower"]]
	var by_id := {}
	for site in level["sites"]:
		by_id[str(site["id"])] = site
	if layout != null and not layout is Array:
		return []
	var ids: Array = [str(level["sites"][0]["id"])] if layout == null else layout
	return _pick(ids, by_id, int(level.get("max_posts", 1)))


## The entries of `by_id` that `ids` name, in order; [] when there are none, more than
## `limit`, an unknown id or a repeat.
func _pick(ids: Array, by_id: Dictionary, limit: int) -> Array:
	if ids.is_empty() or ids.size() > limit:
		return []
	var chosen := []
	var seen := {}
	for id in ids:
		if not by_id.has(str(id)) or seen.has(str(id)):
			return []
		seen[str(id)] = true
		chosen.append(by_id[str(id)])
	return chosen


## The sites nearest where the enemies come from: each spawn arc in turn takes the
## unchosen site closest in direction to its centre, until `max_posts` are chosen.
## Ids only; [] for a level with no sites.
static func best_layout(level: Dictionary) -> Array:
	return best_sites(level.get("sites", []), level.get("spawn_arcs", []), int(level.get("max_posts", 1)))


## The same for any list of sites (or castle spots) and arcs: up to `wanted` ids.
static func best_sites(sites: Array, arcs: Array, wanted: int) -> Array:
	wanted = mini(wanted, sites.size())
	var chosen := []
	if arcs.is_empty():
		for i in wanted:
			chosen.append(str(sites[i]["id"]))
		return chosen
	var turn := 0
	while chosen.size() < wanted:
		var centre := deg_to_rad(float(arcs[turn % arcs.size()]["centre"]))
		turn += 1
		var best := ""
		var best_gap := INF
		for site in sites:
			if str(site["id"]) in chosen:
				continue
			var gap := absf(angle_difference(centre, atan2(float(site["y"]), float(site["x"]))))
			if gap < best_gap:
				best = str(site["id"])
				best_gap = gap
		chosen.append(best)
	return chosen


## A tower with the upgrade stats `tower.<id>.<field>` applied.
func _build_tower(at: Dictionary, tower_id: String, data: Dictionary, stats: Dictionary) -> Attacker:
	var key := "tower.%s." % tower_id
	var a := _attacker("tower", at, data, _apply(stats, key + "damage", float(data["damage"])), _add(stats, key + "health"))
	a.tower_id = tower_id
	a.pierce_width = float(data.get("pierce_width", 0.0))
	a.splash_radius = float(data.get("splash_radius", 0.0))
	a.unlit_bonus = float(data.get("unlit_bonus", 0.0))
	a.colour = str(data.get("colour", ""))
	a.attack_range = _apply(stats, key + "range", a.attack_range)
	a.cooldown = _apply(stats, key + "cooldown", a.cooldown)
	a.extra_targets = int(_add(stats, key + "extra_targets"))
	a.lone_bonus = _add(stats, key + "lone_bonus")
	a.pierce = int(_add(stats, key + "pierce"))
	a.burst_every = int(_add(stats, key + "burst_every"))
	a.burst_extra = _add(stats, key + "burst_extra")
	a.storm_every = _add(stats, key + "storm_every")
	a.storm_share = _add(stats, key + "storm_share")
	a.storm_in = a.storm_every
	a.repair = _add(stats, key + "repair")
	for field in ["hero_haste", "posted_haste", "hero_radius", "crossfire", "burn_dps", "burn_seconds", "rally_repair", "rally_shield", "rally_radius", "rally_seconds", "last_light", "last_light_radius", "watch_range", "watch_radius", "eclipse_widen", "eclipse_radius"]:
		a.set(field, _add(stats, key + field))
	a.links = a.hero_haste > 0.0 or a.posted_haste > 0.0 or a.crossfire > 0.0 or a.burn_dps > 0.0 or a.rally_radius > 0.0 or a.last_light > 0.0 or a.watch_range > 0.0
	return a


## A copy of a Hero attack or ability with its upgraded fields: every stat
## `<prefix><field>` changes that field of the action.
static func _tuned(action: Dictionary, prefix: String, stats: Dictionary) -> Dictionary:
	var tuned := action.duplicate()
	for stat in stats:
		if str(stat).begins_with(prefix):
			var field := str(stat).substr(prefix.length())
			tuned[field] = _apply(stats, str(stat), float(action.get(field, 0.0)))
	return tuned


## Wave i starts `delay` seconds after wave i-1 has spawned its last enemy.
## Spawn groups within a wave run side by side.
func _build_schedule(level: Dictionary) -> void:
	var waves: Array = level["stand"]["waves"] if stand else level["waves"]
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


## Sums upgrade effects: {stat: {add, multiply}} (the stat model's sum).
static func upgrade_stats(nodes: Dictionary, purchased: Array) -> Dictionary:
	return StatModel.sum(nodes, purchased)


static func _scoped_stat(node: Dictionary, stat: String) -> String:
	return StatModel.scoped(node, stat)


## A blessing's effects as upgrade nodes, so they take the same path as gear: Hero stats scoped
## to the Hero played, tower stats to each kind of tower, the rest as they are. Returns {id: node}.
static func blessing_nodes(blessing: Dictionary, hero_path: String, tower_ids: Array) -> Dictionary:
	var hero := []
	var tower := []
	var other := []
	for effect in blessing["effects"]:
		var stat := str(effect["stat"])
		(hero if stat.begins_with("hero.") else tower if stat.begins_with("tower.") else other).append(effect)
	var out := {}
	if not hero.is_empty():
		out["blessing:hero"] = {"hero": hero_path, "effects": hero}
	if not tower.is_empty():
		for id in tower_ids:
			out["blessing:tower:" + str(id)] = {"tower": id, "effects": tower}
	if not other.is_empty():
		out["blessing"] = {"effects": other}
	return out


static func _add(stats: Dictionary, stat: String) -> float:
	return StatModel.add(stats, stat)


static func _apply(stats: Dictionary, stat: String, base: float) -> float:
	return StatModel.apply(stats, stat, base)


func step(dt: float, input: Dictionary) -> void:
	if outcome != OUTCOME_RUNNING:
		return
	ticks += 1
	time = ticks * dt
	_spawn_due()
	hero_grace_left = HeroGetUp.tick_grace(hero_grace_left, dt)
	if hero_grace_left < TIME_EPSILON:
		hero_grace_left = 0.0
	_step_zone(dt)
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
	for built in towers:
		_storm(built, dt)
		_rally(built, dt)
		_last_light_volley(built)
		_attack(built, built.damage, dt)
		if enemies.is_empty():
			var repair := built.repair + repair_share * float(built.health["max_health"])
			if repair > 0.0:
				built.health = UnitHealth.repair(built.health, repair * dt)
	for recruit in recruits:
		if recruit.fleeing:
			recruit.last_target = -1
		else:
			_attack(recruit, recruit.damage, dt)
	_repair_keep(dt)
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
	_wound(enemy, amount * (1.0 + enemy.mark_bonus))


## Takes `amount` off an enemy's health. A boss's shroud turns it away unless the Hero has
## cast its ability lately (BossRules), so every kind of damage goes through here.
func _wound(enemy: Enemy, amount: float) -> void:
	if enemy.required_ability == "":
		enemy.health -= amount
	else:
		var abilities := [enemy.required_ability] if enemy.exposed_left > 0.0 else []
		var boss := {"max_health": enemy.max_health, "health": enemy.health, "required_ability": enemy.required_ability, "defeated": enemy.health <= 0.0}
		enemy.health = float(BossRules.take_hit(boss, amount, abilities)["health"])
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
		if unit.kind != "recruit" or unit.post == "" or unit.fleeing or unit.fx.is_empty():
			continue
		var fx: Dictionary = unit.fx
		var centre: Vector2 = _post_at[unit.post]
		var reach := float(fx.get("effect_radius", 0.0))
		unit.candidate["taunt_radius"] = float(fx.get("taunt_radius", 0.0))
		if fx.has("slow") or fx.has("mark_bonus"):
			_lookouts.append([centre, reach, float(fx.get("slow", 0.0)), float(fx.get("mark_bonus", 0.0))])
		if fx.has("field_dps") or fx.has("repair_per_second") or fx.has("heal_per_second"):
			_ticking.append([centre, reach, float(fx.get("field_dps", 0.0)), float(fx.get("repair_per_second", 0.0)), float(fx.get("heal_per_second", 0.0))])


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
		if enemy.burn_left > 0.0 and enemy.health > 0.0:
			enemy.burn_left = maxf(enemy.burn_left - dt, 0.0)
			_wound(enemy, enemy.burn_dps * dt)
			if enemy.health <= 0.0:
				# Burnt down: it neither moves nor hits this tick, and is collected after it.
				_any_dead = true
				enemies[kept] = enemy
				kept += 1
				continue
		enemy.exposed_left = maxf(enemy.exposed_left - dt, 0.0)
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
			if enemy.target == "" and not enemy.besieges:
				_hurt_keep(enemy.damage)
				_wave_gone(enemy.wave, false)
				continue
			if dist > contact:
				enemy.position += to_goal / dist * (dist - contact)
			enemy.hit_in -= dt
			if enemy.hit_in <= 0.0:
				enemy.hit_in = enemy.hit_interval
				if enemy.target == "":
					_hurt_keep(enemy.damage)
				else:
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
		hero_state = HeroGetUp.take_damage(hero_state, amount * (1.0 - hero_armour), hero_delays, hero_grace_left)
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
		if unit.shield_left > 0.0:
			amount *= 1.0 - unit.rally_shield
		unit.health = UnitHealth.damage(unit.health, amount)
		unit.up = unit.health["alive"]
		if unit.up:
			_last_light(unit)
	else:
		unit.health = RecruitRules.damage(unit.health, amount * (1.0 - unit.armour))
		unit.up = not unit.health["downed"]
	if unit.up:
		return
	_targets_dirty = true
	if unit.kind == "tower":
		towers_lost += 1
	else:
		recruits_downed += 1
		_bark(unit, "down")


# --- Recruits: revive, and the effect of staffing a post -------------------

func _step_recruits(dt: float) -> void:
	var enemy_points: Array = []
	var points_built := false
	for recruit in recruits:
		recruit.bark_left = maxf(recruit.bark_left - dt, 0.0)
		recruit.flash_left = maxf(recruit.flash_left - dt, 0.0)
		if not recruit.up:
			_revive(recruit, dt)
			continue
		if _flee(recruit, dt):
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
		if fx[4] > 0.0:
			for recruit in recruits:
				if recruit.up and recruit.position.distance_to(fx[0]) <= fx[1]:
					recruit.health = RecruitRules.rest(recruit.health, fx[4] * dt)
		if fx[2] > 0.0:
			for enemy in enemies:
				if enemy.health > 0.0 and enemy.position.distance_to(fx[0]) <= fx[1] + enemy.radius:
					_hurt(enemy, fx[2] * dt, 0.0)
		if fx[3] > 0.0:
			for built in towers:
				if built.up and built.position.distance_to(fx[0]) <= fx[1]:
					built.health = UnitHealth.repair(built.health, fx[3] * dt)


## A Recruit with a `flee_below` (a Coward) who is below it leaves the fight for the keep, holds
## their fire and rests there until back to that share plus FLEE_RECOVERY, then returns to their
## post or home. True while they are fleeing, and they take no other step.
func _flee(recruit: Attacker, dt: float) -> bool:
	if recruit.flee_below <= 0.0:
		return false
	var share := float(recruit.health["health"]) / float(recruit.health["max_health"])
	if not recruit.fleeing and share < recruit.flee_below:
		recruit.fleeing = true
		_targets_dirty = true
	elif recruit.fleeing and share >= minf(recruit.flee_below + FLEE_RECOVERY, 1.0):
		recruit.fleeing = false
		_targets_dirty = true
	if not recruit.fleeing:
		return false
	recruit.position = recruit.position.move_toward(recruit.refuge, float(recruit.role["move_speed"]) * dt)
	recruit.candidate["pos"] = recruit.position
	if recruit.position == recruit.refuge and recruit.rest_heal > 0.0:
		recruit.health = RecruitRules.rest(recruit.health, recruit.rest_heal * dt)
	return true


## A short line over a Recruit's head for BARK_SECONDS: their class's line for the event
## ("wave", "down", "up", "level"), picked by the tick so every run says the same.
func _bark(unit: Attacker, event: String) -> void:
	var lines: Array = unit.role.get("barks", {}).get(event, [])
	if lines.is_empty():
		return
	unit.bark = str(lines[(ticks + wave) % lines.size()])
	unit.bark_left = BARK_SECONDS


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
	_bark(recruit, "up")


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
	hero_holding = false
	if hero_state["downed"]:
		hero_rapid_left = 0.0
		hero_habit_for = 0.0
		hero_state = HeroKnockdown.tick(hero_state, dt)
		if not hero_state["downed"]:
			# The square round the keep (with the Hero's own width) is ground they cannot stand on.
			var keep_square := keep_radius + hero_radius
			var up := HeroGetUp.rise(hero_fell_at, Rect2(-arena_half, arena_half * 2.0), [Rect2(-keep_square, -keep_square, 2.0 * keep_square, 2.0 * keep_square)], hero_untouchable_seconds)
			hero_position = up["pos"]
			hero_grace_left = up["grace_left"]
			_targets_dirty = true
		return
	if hero_dash_left > TIME_EPSILON:
		_step_dash(dt)
		return
	var move := _input_vector(input.get("move"))
	hero_holding = move == Vector2.ZERO
	if move != Vector2.ZERO:
		hero_position = _in_arena(hero_position + move * hero_speed * dt)
	var target := _nearest_enemy(hero_position)
	var to_target := Vector2.ZERO if target == null else target.position - hero_position
	if to_target.length_squared() > 0.0001:
		hero_facing = to_target.normalized()
	elif target == null and move != Vector2.ZERO:
		hero_facing = move.normalized()
	if hero_attack_ready_in <= 0.0 and target != null and to_target.length() <= float(hero_attack["range"]) + _watch_bonus() + target.radius:
		hero_attack_ready_in = float(hero_attack["cooldown"])
		_use(hero_attack, target)
	var ability: Variant = input.get("ability")
	if ability is bool and ability and hero_ability_ready_in <= 0.0:
		_cast_ability(target, 1.0)
	elif _habit_waited(dt):
		_cast_ability(target, float(hero_ability["auto_power"]))
	if hero_rapid_left > 0.0 and hero_rapid_ready_in <= 0.0:
		hero_rapid_ready_in = float(hero_ability.get("rapid_interval", hero_attack["cooldown"]))
		_fire(hero_ability, hero_rapid_power)


## Keeper's Habit: a barrage the Hero has the stat for (`auto_power` above 0) fires on its own, at
## that share of its power, once HABIT_ENEMIES or more enemies have been within its reach for
## HABIT_DELAY seconds with it ready. True on the tick it should.
func _habit_waited(dt: float) -> bool:
	if hero_ability_ready_in > 0.0 or float(hero_ability.get("auto_power", 0.0)) <= 0.0 or float(hero_ability.get("rapid_seconds", 0.0)) <= 0.0:
		hero_habit_for = 0.0
		return false
	var close := 0
	for enemy in enemies:
		if enemy.health > 0.0 and enemy.position.distance_to(hero_position) <= float(hero_ability["range"]) + enemy.radius:
			close += 1
	hero_habit_for = hero_habit_for + dt if close >= HABIT_ENEMIES else 0.0
	return hero_habit_for >= HABIT_DELAY - TIME_EPSILON


## Casts the ability: the cooldown starts, and the kind says what happens. `power` scales a barrage's arrows.
func _cast_ability(target: Enemy, power: float) -> void:
	hero_ability_ready_in = float(hero_ability["cooldown"])
	_expose_bosses()
	if float(hero_ability.get("rapid_seconds", 0.0)) > 0.0:
		hero_rapid_left = float(hero_ability["rapid_seconds"])
		hero_rapid_power = power
	elif float(hero_ability.get("dash_seconds", 0.0)) > 0.0:
		hero_dash_left = float(hero_ability["dash_seconds"])
		hero_grace_left = maxf(hero_grace_left, hero_dash_left)
		_start_dash(target)
	elif float(hero_ability.get("zone_seconds", 0.0)) > 0.0:
		zone_left = float(hero_ability["zone_seconds"])
		zone_position = hero_position if target == null else target.position
		zone_scale = _eclipse_scale(zone_position)
	else:
		_use(hero_ability, target)


## The Hero's ability lifts every boss's shroud for the seconds its pack names.
func _expose_bosses() -> void:
	for enemy in enemies:
		if enemy.required_ability != "":
			enemy.exposed_left = enemy.exposed_seconds


## Starts the next dash of a chain, aimed at the nearest enemy (or along the facing when none is left).
func _start_dash(target: Enemy) -> void:
	if target != null and target.position != hero_position:
		hero_facing = (target.position - hero_position).normalized()
	hero_dash_dir = hero_facing
	hero_dash_in = float(hero_ability["dash_seconds"]) / int(hero_ability.get("dash_count", 1))
	hero_dash_hit.clear()


## One tick of a dash chain: the Hero runs `dash_distance` along the dash's direction over its
## share of `dash_seconds`, hurting each enemy within `range` of the run once, and cannot be hurt
## meanwhile. The Hero does nothing else until the chain is over.
func _step_dash(dt: float) -> void:
	hero_grace_left = maxf(hero_grace_left, hero_dash_left)
	var step := minf(dt, hero_dash_in)
	var from := hero_position
	var per := float(hero_ability["dash_seconds"]) / int(hero_ability.get("dash_count", 1))
	hero_position = _in_arena(from + hero_dash_dir * (float(hero_ability["dash_distance"]) * step / per))
	var reach := float(hero_ability["range"])
	for enemy in enemies:
		if enemy.health <= 0.0 or enemy in hero_dash_hit:
			continue
		if Geometry2D.get_closest_point_to_segment(enemy.position, from, hero_position).distance_to(enemy.position) <= reach + enemy.radius:
			hero_dash_hit.append(enemy)
			_hurt(enemy, float(hero_ability["damage"]), float(hero_ability.get("unlit_bonus", 0.0)))
	_add_effect("dash", from, reach, hero_position - from)
	hero_dash_left -= dt
	hero_dash_in -= dt
	if hero_dash_left < TIME_EPSILON:
		hero_dash_left = 0.0
	if hero_dash_in <= TIME_EPSILON and hero_dash_left > TIME_EPSILON:
		_start_dash(_nearest_enemy(hero_position))


## An Eclipse zone for one tick: enemies inside `zone_radius` are slowed by `slow` and drawn
## toward the middle at `pull` px/s. When it runs out it collapses: every enemy within `radius`
## of the middle is hurt for `damage`.
func _step_zone(dt: float) -> void:
	if zone_left <= 0.0:
		return
	zone_left = maxf(zone_left - dt, 0.0)
	var reach := float(hero_ability["zone_radius"]) * zone_scale
	for enemy in enemies:
		if enemy.health <= 0.0 or enemy.position.distance_to(zone_position) > reach + enemy.radius:
			continue
		enemy.slow_amount = maxf(enemy.slow_amount, float(hero_ability["slow"]))
		enemy.slowed_for = maxf(enemy.slowed_for, 2.0 * dt)
		enemy.position = enemy.position.move_toward(zone_position, float(hero_ability["pull"]) * dt)
	if zone_left < TIME_EPSILON:
		zone_left = 0.0
		var radius := float(hero_ability["radius"]) * zone_scale
		for enemy in enemies:
			if enemy.health > 0.0 and enemy.position.distance_to(zone_position) <= radius + enemy.radius:
				_hurt(enemy, float(hero_ability["damage"]), float(hero_ability.get("unlit_bonus", 0.0)))
		_add_effect("burst", zone_position, radius, Vector2.ZERO)


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
func _fire(action: Dictionary, power := 1.0) -> void:
	var count := int(action.get("count", 1))
	var spread := deg_to_rad(float(action.get("spread_degrees", 0.0)))
	for i in count:
		var offset := 0.0 if count == 1 else (float(i) / (count - 1) - 0.5) * spread
		var arrow := Projectile.new()
		arrow.position = hero_position
		arrow.velocity = hero_facing.rotated(offset) * float(action["speed"])
		arrow.damage = float(action["damage"]) * power
		arrow.radius = float(action["radius"])
		arrow.distance_left = float(action["range"]) + _watch_bonus()
		arrow.pierce_left = int(action.get("pierce", 1))
		arrow.burn_dps = float(action.get("burn_dps", 0.0)) * power
		arrow.burn_seconds = float(action.get("burn_seconds", 0.0))
		arrow.colour = str(action.get("colour", ""))
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


## Flies every arrow for one tick. An arrow hits the first living enemy its path
## touches that it has not hit yet (checked along the whole step, so a fast arrow
## can't skip one), and is spent once it has hit `pierce` of them. A hit may leave a burn.
func _move_projectiles(dt: float) -> void:
	var flying: Array[Projectile] = []
	for arrow in projectiles:
		var travel := minf(arrow.velocity.length() * dt, arrow.distance_left)
		var from := arrow.position
		var to := from + arrow.velocity.normalized() * travel
		var hit := _first_enemy_on_path(from, to, arrow.radius, arrow.hit)
		if hit != null:
			_hurt(hit, arrow.damage, 0.0)
			if arrow.burn_seconds > 0.0:
				hit.burn_dps = maxf(hit.burn_dps, arrow.burn_dps)
				hit.burn_left = arrow.burn_seconds
			arrow.hit.append(hit)
			arrow.pierce_left -= 1
			if arrow.pierce_left <= 0:
				continue
		arrow.position = to
		arrow.distance_left -= travel
		if arrow.distance_left > 0.0:
			flying.append(arrow)
	projectiles = flying


func _first_enemy_on_path(from: Vector2, to: Vector2, radius: float, skip: Array = []) -> Enemy:
	var best: Enemy = null
	var best_along := INF
	var mid := (from + to) / 2.0
	var half := from.distance_to(to) / 2.0 + radius
	for enemy in enemies:
		if enemy.health <= 0.0 or enemy in skip:
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
			_wound(enemy, aura_dps * dt)
			_any_dead = _any_dead or enemy.health <= 0.0


## One Recruit, in turn, calls out as a wave begins.
func _bark_a_wave(w: int) -> void:
	if not recruits.is_empty():
		var caller: Attacker = recruits[w % recruits.size()]
		if caller.up:
			_bark(caller, "wave")


func _spawn_due() -> void:
	while _next_spawn < _schedule.size() and _schedule[_next_spawn][0] <= time + 0.000001:
		var entry: Array = _schedule[_next_spawn]
		_next_spawn += 1
		var w: int = entry[1]
		if w + 1 > wave:
			_bank_xp()
			_bark_a_wave(w)
		wave = maxi(wave, w + 1)
		var data: Dictionary = _enemy_types[entry[2]]
		var enemy := Enemy.new()
		enemy.uid = _next_uid
		_next_uid += 1
		enemy.type = entry[2]
		enemy.wave = w
		var angle := _spawn_angle()
		enemy.position = _in_arena(Vector2(cos(angle), sin(angle)) * spawn_radius)
		enemy.max_health = float(data["health"]) * _wave_health_scale[w] * enemy_health_scale
		enemy.health = enemy.max_health
		enemy.speed = float(data["speed"]) * enemy_speed
		enemy.radius = float(data["radius"])
		enemy.damage = roundi(float(data["damage"]) * _wave_damage_scale[w] * enemy_damage_scale)
		enemy.gold = int(data["gold"])
		enemy.engage_distance = float(data["engage_distance"])
		enemy.xp_chance = float(data.get("xp_chance", 0.0))
		enemy.xp_value = int(data.get("xp_value", 0))
		enemy.hit_interval = float(data.get("hit_interval", 1.0))
		enemy.tier = str(data.get("tier", "normal"))
		enemy.required_ability = str(data.get("required_ability", ""))
		enemy.exposed_seconds = float(data.get("exposed_seconds", 0.0))
		enemy.besieges = bool(data.get("besieges", false))
		enemies.append(enemy)


## Where the next enemy comes from: anywhere round the keep, or inside one of the
## level's arcs (the second draw picks the point in the arc).
func _spawn_angle() -> float:
	var first := _rng.next_float()
	if spawn_arcs.is_empty():
		return first * TAU
	var arc: Dictionary = spawn_arcs[mini(int(first * spawn_arcs.size()), spawn_arcs.size() - 1)]
	return deg_to_rad(float(arc["centre"]) + (_rng.next_float() - 0.5) * float(arc["width"]))


func _attack(attacker: Attacker, damage: float, dt: float) -> void:
	attacker.ready_in = maxf(attacker.ready_in - dt, 0.0)
	attacker.last_target = -1
	if attacker.ready_in > 0.0 or not attacker.up:
		return
	var best: Enemy = null
	var best_dist := INF
	var in_range := 0
	for enemy in enemies:
		if enemy.health <= 0.0:
			continue
		var reach := attacker.attack_range + enemy.radius
		if enemy.position.distance_squared_to(attacker.position) > reach * reach:
			continue
		in_range += 1
		var to_keep := enemy.position.length()
		if to_keep < best_dist:
			best = enemy
			best_dist = to_keep
	if best == null:
		attacker.ready_in = SCAN_SECONDS
		return
	var dealt := damage
	if in_range == 1:
		dealt *= 1.0 + attacker.lone_bonus
	attacker.shots += 1
	if attacker.burst_every > 0 and attacker.shots % attacker.burst_every == 0:
		dealt *= 1.0 + attacker.burst_extra
	if attacker.crossfire > 0.0:
		if best.shot_by != "" and best.shot_by != attacker.key and time - best.shot_at <= CROSSFIRE_SECONDS:
			dealt *= 1.0 + attacker.crossfire
		best.shot_by = attacker.key
		best.shot_at = time
	if attacker.splash_radius > 0.0:
		_splash(attacker, best, dealt)
	else:
		_hurt(best, dealt, 0.0)
	if attacker.burn_dps > 0.0:
		best.burn_dps = maxf(best.burn_dps, attacker.burn_dps)
		best.burn_left = maxf(best.burn_left, attacker.burn_seconds)
	if attacker.extra_targets > 0 or attacker.pierce > 0:
		_hit_more(attacker, best, dealt)
	attacker.ready_in = attacker.cooldown
	if attacker.hero_haste > 0.0 and _hero_within(attacker.position, attacker.hero_radius):
		attacker.ready_in /= 1.0 + attacker.hero_haste
	if attacker.posted_haste > 0.0 and _staffed(attacker) and _hero_within(attacker.position, attacker.hero_radius):
		attacker.ready_in /= 1.0 + attacker.posted_haste
	attacker.last_target = best.uid


## A Mage Post's blast: the target and every enemy within `splash_radius` of it take the shot,
## hardest outside the posts' light.
func _splash(attacker: Attacker, target: Enemy, damage: float) -> void:
	for enemy in enemies:
		if enemy.health > 0.0 and enemy.position.distance_to(target.position) <= attacker.splash_radius + enemy.radius:
			_hurt(enemy, damage, attacker.unlit_bonus)
	_add_effect("burst", target.position, attacker.splash_radius, Vector2.ZERO)


## Dusk Eclipse: the widest bonus any standing post gives an Eclipse centred within its reach.
func _eclipse_scale(centre: Vector2) -> float:
	var widen := 0.0
	for built in towers:
		if built.up and built.eclipse_widen > widen and built.position.distance_to(centre) <= built.eclipse_radius:
			widen = built.eclipse_widen
	return 1.0 + widen


## True while a post's Recruit is up and has not fled the fight.
func _staffed(built: Attacker) -> bool:
	return built.staffer != null and built.staffer.up and not built.staffer.fleeing


## True while the Hero is up and within `reach` of `point`.
func _hero_within(point: Vector2, reach: float) -> bool:
	return not hero_state["downed"] and hero_position.distance_to(point) <= reach


## Watchtower: the furthest bonus range any standing post gives a Hero within its reach.
func _watch_bonus() -> float:
	var bonus := 0.0
	for built in towers:
		if built.up and built.watch_range > bonus and _hero_within(built.position, built.watch_radius):
			bonus = built.watch_range
	return bonus


## Rally: a Hero standing still beside a post repairs it and keeps its shield up; the shield then
## runs out `rally_seconds` after they leave.
func _rally(attacker: Attacker, dt: float) -> void:
	if attacker.rally_radius <= 0.0:
		return
	attacker.shield_left = maxf(attacker.shield_left - dt, 0.0)
	if attacker.up and hero_holding and _hero_within(attacker.position, attacker.rally_radius):
		attacker.shield_left = attacker.rally_seconds
		attacker.health = UnitHealth.repair(attacker.health, attacker.rally_repair * dt)


## Last Light: a post hurt down to a quarter of its health with the Hero close flares once and
## shoots `last_light` times its damage at everything in range (on the towers' turn). It can flare
## again once it has been mended past half health.
func _last_light(attacker: Attacker) -> void:
	if attacker.last_light <= 0.0:
		return
	var health := float(attacker.health["health"])
	var full := float(attacker.health["max_health"])
	if health > full * 0.5:
		attacker.last_light_spent = false
	if attacker.last_light_spent or health > full * LAST_LIGHT_AT or not _hero_within(attacker.position, attacker.last_light_radius):
		return
	attacker.last_light_spent = true
	attacker.last_light_due = true


## The volley itself, a moment after the blow that set it off: it is fired from the towers' turn so
## that nothing is hurt while the enemies are still being walked.
func _last_light_volley(attacker: Attacker) -> void:
	if not attacker.last_light_due:
		return
	attacker.last_light_due = false
	if not attacker.up:
		return
	var reach := attacker.attack_range
	for enemy in enemies:
		if enemy.health > 0.0 and enemy.position.distance_to(attacker.position) <= reach + enemy.radius:
			_hurt(enemy, attacker.damage * attacker.last_light, 0.0)
	_add_effect("burst", attacker.position, reach, Vector2.ZERO)


## A tower's twin and piercing shots: the next enemies nearest the keep within
## range take the same hit, then the ones in line behind the target.
func _hit_more(attacker: Attacker, first: Enemy, damage: float) -> void:
	var others: Array[Enemy] = []
	for enemy in enemies:
		var reach := attacker.attack_range + enemy.radius
		if enemy != first and enemy.health > 0.0 and enemy.position.distance_squared_to(attacker.position) <= reach * reach:
			others.append(enemy)
	others.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		var da := a.position.length_squared()
		var db := b.position.length_squared()
		return da < db or (da == db and a.uid < b.uid))
	var twins := others.slice(0, attacker.extra_targets)
	for enemy in twins:
		_hurt(enemy, damage, 0.0)
	if attacker.pierce <= 0:
		return
	var line := first.position - attacker.position
	if line.length_squared() < 0.0001:
		return
	line = line.normalized()
	var first_along := (first.position - attacker.position).dot(line)
	var behind: Array[Enemy] = []
	for enemy in others:
		var rel := enemy.position - attacker.position
		if twins.has(enemy) or rel.dot(line) <= first_along:
			continue
		if absf(rel.cross(line)) <= enemy.radius + attacker.pierce_width:
			behind.append(enemy)
	behind.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		var da := (a.position - attacker.position).dot(line)
		var db := (b.position - attacker.position).dot(line)
		return da < db or (da == db and a.uid < b.uid))
	for enemy in behind.slice(0, attacker.pierce):
		_hurt(enemy, damage, 0.0)


## A storm post: every `storm_every` seconds, once something is in range, it
## hits everything in range for `storm_share` of its damage.
func _storm(attacker: Attacker, dt: float) -> void:
	if attacker.storm_every <= 0.0 or not attacker.up:
		return
	attacker.storm_in = maxf(attacker.storm_in - dt, 0.0)
	if attacker.storm_in > TIME_EPSILON:
		return
	var hit := false
	for enemy in enemies:
		var reach := attacker.attack_range + enemy.radius
		if enemy.health > 0.0 and enemy.position.distance_squared_to(attacker.position) <= reach * reach:
			_hurt(enemy, attacker.damage * attacker.storm_share, 0.0)
			hit = true
	if hit:
		attacker.storm_in = attacker.storm_every


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
		if enemy.tier != "normal":
			_drop_gear(enemy)
		_wave_gone(enemy.wave, true)
	enemies = alive


## An elite or boss kill may drop a Hero item the player does not own yet (HeroGear). Both
## rolls are drawn for every such kill, so the sequence stays deterministic.
func _drop_gear(enemy: Enemy) -> void:
	var roll := _rng.next_float()
	var pick := _rng.next_float()
	if _gear_rules.is_empty() or not HeroGear.drops_gear(_level_number, enemy.tier, roll, _gear_rules):
		return
	var pool := []
	for id in _gear_items:
		if not id in _gear_owned and not id in gear_found and not _is_first_clear_gear(id):
			pool.append(id)
	var item := HeroGear.pick_item(pool, pick)
	if item != "":
		gear_found.append(item)


## True when some level hands this item out for a first win, so a drop never takes it.
func _is_first_clear_gear(id: String) -> bool:
	for level in _levels_data.values():
		if str(level.get("first_clear_gear", "")) == id:
			return true
	return false


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
	for recruit in recruits:
		var gained := maxi(roundi(float(amount) * recruit.xp_gain), 1) if amount > 0 else 0
		recruit.run_xp += gained
		recruit.xp_total += gained
		var reached := RecruitRoster.level_for(recruit.xp_total, recruit.xp_per_level)
		if reached > recruit.level:
			recruit.damage += recruit.damage_per_level * float(reached - recruit.level)
			recruit.level = reached
			recruit.flash_left = FLASH_SECONDS
			_bark(recruit, "level")


## The Keep takes a blow; a tutorial's Keep takes none.
func _hurt_keep(amount: int) -> void:
	if not tutorial:
		_keep_damage += mini(amount, keep_health)
		keep_health = maxi(keep_health - amount, 0)


## A blessing's repair: the Keep mends a share of its health a second while no enemy is on the field.
func _repair_keep(dt: float) -> void:
	if repair_share <= 0.0 or not enemies.is_empty() or keep_health >= keep_health_max:
		return
	_keep_mend += repair_share * keep_health_max * dt
	var whole := int(_keep_mend)
	_keep_mend -= whole
	keep_health = mini(keep_health + whole, keep_health_max)


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
	# The level's own piece of gear, once: a win while the player does not own it yet.
	if outcome == OUTCOME_WON and _first_clear_gear != "" and _gear_items.has(_first_clear_gear):
		if not _first_clear_gear in _gear_owned and not _first_clear_gear in gear_found:
			gear_found.append(_first_clear_gear)


func is_finished() -> bool:
	return outcome != OUTCOME_RUNNING


func result() -> Dictionary:
	var out := {
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
		"gear_found": gear_found.duplicate(),
		"recruit_xp": _recruit_xp(),
	}
	if hard:
		out["hard"] = true
	if _blessed or hard:
		# The Keep's health as the tree builds it, whatever a blessing or a modifier did to it, for the stars.
		out["keep_left"] = 1.0 - float(_keep_damage) / _keep_star_max if _keep_star_max > 0.0 else 0.0
	return out


func snapshot() -> Dictionary:
	var list := []
	for e in enemies:
		list.append([e.uid, e.type, e.wave, e.position.x, e.position.y, e.health, e.target, e.retarget_in, e.hit_in, e.slowed_for, e.mark_bonus, e.burn_left, e.exposed_left])
	return {
		"result": result(),
		"staff_xp": staff_xp,
		"aura": [aura_active, aura_position.x, aura_position.y],
		"hero": [hero_position.x, hero_position.y, hero_facing.x, hero_facing.y, hero_attack_ready_in, hero_ability_ready_in, hero_rapid_left, hero_rapid_ready_in, zone_left, zone_position.x, zone_position.y, hero_dash_left, hero_dash_in],
		"hero_state": hero_state,
		"hero_grace_left": hero_grace_left,
		"carried_xp": carried_xp,
		"xp_tokens": _token_states(),
		"recruits": _recruit_states(),
		"projectiles": _projectile_states(),
		"tower": _attacker_state(tower),
		"towers": _tower_states(),
		"staff": _attacker_state(staff),
		"next_spawn": _next_spawn,
		"next_uid": _next_uid,
		"wave_remaining": Array(_wave_remaining),
		"wave_leaked": Array(_wave_leaked),
		"enemies": list,
	}


func _recruit_xp() -> Dictionary:
	var out := {}
	for recruit in recruits:
		out[recruit.id] = recruit.run_xp
	return out


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


func _tower_states() -> Array:
	var list := []
	for built in towers:
		var state := [built.ready_in, built.last_target, built.damage, built.health["health"], built.up, built.shots, built.storm_in]
		if built.links:
			state.append_array([built.shield_left, built.last_light_spent, built.last_light_due])
		list.append(state)
	return list


static func _attacker_state(a: Attacker) -> Array:
	return [] if a == null else [a.ready_in, a.last_target, a.damage]
