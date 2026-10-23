extends Node
## Run flow: main menu -> journey map -> plan -> run (HUD) -> summary -> journey map. The
## Hero page and the skill tree open from the map and close back to it. The game layer: the
## only place that starts a run or changes the profile. Screens ask through their
## signals and the flow acts, so a screen never writes progress itself.

enum Screen { HOME, MAP, TREE, HERO, PLAN, RUN, SUMMARY }

@export var source_path: NodePath
@export var profile_path: NodePath
@export var home_path: NodePath
@export var journey_path: NodePath
@export var hero_page_path: NodePath
@export var keep_screen_path: NodePath
@export var hud_path: NodePath
@export var summary_path: NodePath
@export var planning_path: NodePath

@onready var source: Node = get_node(source_path)
@onready var profile: HoldfastProfile = get_node(profile_path)
@onready var home: Control = get_node(home_path)
@onready var journey: Control = get_node(journey_path)
@onready var hero_page: Control = get_node(hero_page_path)
## The skill tree page.
@onready var keep_screen: Control = get_node(keep_screen_path)
@onready var hud: Control = get_node(hud_path)
@onready var summary: Control = get_node(summary_path)
@onready var planning: Control = get_node(planning_path)

var screen := Screen.HOME


func _ready() -> void:
	hud.bind(source)
	home.bind(profile)
	journey.bind(profile)
	hero_page.bind(profile)
	keep_screen.bind(profile)
	home.continue_requested.connect(_show.bind(Screen.MAP))
	home.new_game_requested.connect(_new_game)
	home.quit_requested.connect(get_tree().quit)
	journey.home_requested.connect(_show.bind(Screen.HOME))
	journey.tree_requested.connect(_show.bind(Screen.TREE))
	journey.hero_requested.connect(_show.bind(Screen.HERO))
	journey.level_requested.connect(_level_picked)
	journey.buy_requested.connect(profile.buy)
	hero_page.back_requested.connect(_show.bind(Screen.MAP))
	hero_page.tree_requested.connect(_open_tree_at.bind("Hero"))
	hero_page.pillar_requested.connect(profile.select_pillar)
	hero_page.gear_requested.connect(profile.toggle_gear)
	keep_screen.back_requested.connect(_show.bind(Screen.MAP))
	keep_screen.buy_requested.connect(profile.buy)
	keep_screen.respec_requested.connect(_respec_requested)
	summary.play_again_requested.connect(_plan_run)
	planning.start_requested.connect(_planned)
	planning.back_requested.connect(_show.bind(Screen.MAP))
	summary.next_level_requested.connect(_next_level)
	summary.map_requested.connect(_show.bind(Screen.MAP))
	summary.tree_requested.connect(_show.bind(Screen.TREE))
	source.run_ended.connect(_on_run_ended)
	_show(Screen.HOME)


func _new_game() -> void:
	profile.new_game()
	_show(Screen.MAP)


## Opens the skill tree with the view on one of its tabs.
func _open_tree_at(tab: String) -> void:
	keep_screen.show_tab(tab)
	_show(Screen.TREE)


## A tap on an open level of the journey map plans a run on it; a locked level does nothing.
func _level_picked(id: String) -> void:
	if not id in profile.get_unlocked_levels():
		return
	profile.select_level(id)
	_plan_run()


## Opens the Plan page first, else starts the run when the level is a tutorial (its post is
## fixed). A castle with no Archer Post yet plans nothing: the map asks for the first buys.
## Slots start empty on a first visit; after a run they hold the layout last used.
func _plan_run() -> void:
	if source.is_running():
		return
	var level := profile.get_level()
	if profile.is_tutorial(level):
		_start_run()
		return
	if not profile.has_a_tower():
		_show(Screen.MAP)
		return
	var saved := profile.has_saved_layout(level)
	planning.open(level, profile.get_layout(level) if saved else [], saved, profile.get_owned_spots(), profile.get_castle_cards())
	_show(Screen.PLAN)


## A respec changes what the next run is built on, so it waits until the run is over.
func _respec_requested() -> void:
	if source.is_running():
		profile.notice.emit("A respec waits until the run is over.")
		return
	profile.respec()


## The player's sites are saved with the profile, then the run starts on them.
func _planned(layout: Array) -> void:
	if layout.is_empty():
		return
	profile.set_layout(profile.get_level(), layout)
	_start_run()


## Starts a run on the profile's level, upgrades and Hero pillar.
func _start_run() -> void:
	if source.is_running():
		return
	if "hero_path" in source:
		source.hero_path = profile.get_pillar()
		source.level_id = profile.get_level()
		source.upgrades = profile.get_upgrades().duplicate()
		source.layout = profile.get_layout(profile.get_level())
		source.gear = profile.get_gear_worn()
		source.gear_owned = profile.get_gear_owned().duplicate()
	_show(Screen.RUN)
	source.start_run()


## Plays the level the summary offered after a win.
func _next_level(id: String) -> void:
	profile.select_level(id)
	_plan_run()


## The run is banked (gold, wins, unlocks, saved) before the summary shows.
func _on_run_ended(result: Dictionary) -> void:
	var next := ""
	if result.has("result"):
		var level := str(result["result"].get("level", ""))
		var stars_before := profile.get_stars_earned()
		var first_win: bool = result["result"].get("outcome") == HoldfastRules.OUTCOME_WON and not profile.is_level_won(level)
		profile.bank_run(result["result"])
		result["stars_paid"] = profile.get_stars_earned() - stars_before
		result["reward_gold"] = profile.get_reward_gold(level) if first_win else 0
		if result["result"].get("outcome") == HoldfastRules.OUTCOME_WON:
			next = profile.get_next_level(level)
	summary.show_summary(result, next)
	_show(Screen.SUMMARY)


func _show(next: Screen) -> void:
	screen = next
	home.visible = next == Screen.HOME
	journey.visible = next == Screen.MAP
	hero_page.visible = next == Screen.HERO
	keep_screen.visible = next == Screen.TREE
	planning.visible = next == Screen.PLAN
	hud.visible = next == Screen.RUN
	summary.visible = next == Screen.SUMMARY
