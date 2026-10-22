extends Node
## Run flow: home -> keep -> run (HUD) -> summary -> keep. The game layer: the
## only place that starts a run or changes the profile. Screens ask through their
## signals and the flow acts, so a screen never writes progress itself.

enum Screen { HOME, KEEP, PLAN, RUN, SUMMARY }

@export var source_path: NodePath
@export var profile_path: NodePath
@export var home_path: NodePath
@export var keep_screen_path: NodePath
@export var hud_path: NodePath
@export var summary_path: NodePath
@export var planning_path: NodePath

@onready var source: Node = get_node(source_path)
@onready var profile: HoldfastProfile = get_node(profile_path)
@onready var home: Control = get_node(home_path)
@onready var keep_screen: Control = get_node(keep_screen_path)
@onready var hud: Control = get_node(hud_path)
@onready var summary: Control = get_node(summary_path)
@onready var planning: Control = get_node(planning_path)

var screen := Screen.HOME


func _ready() -> void:
	hud.bind(source)
	home.bind(profile)
	keep_screen.bind(profile)
	home.continue_requested.connect(_show.bind(Screen.KEEP))
	home.new_game_requested.connect(_new_game)
	home.quit_requested.connect(get_tree().quit)
	keep_screen.play_requested.connect(_plan_run)
	keep_screen.home_requested.connect(_show.bind(Screen.HOME))
	keep_screen.buy_requested.connect(profile.buy)
	keep_screen.level_requested.connect(profile.select_level)
	keep_screen.pillar_requested.connect(profile.select_pillar)
	keep_screen.respec_requested.connect(profile.respec)
	summary.play_again_requested.connect(_plan_run)
	planning.start_requested.connect(_planned)
	planning.back_requested.connect(_show.bind(Screen.KEEP))
	summary.next_level_requested.connect(_next_level)
	summary.keep_requested.connect(_show.bind(Screen.KEEP))
	source.run_ended.connect(_on_run_ended)
	_show(Screen.HOME)


func _new_game() -> void:
	profile.new_game()
	_show(Screen.KEEP)


## Asks for the Archer Post sites first when the level has any, else starts the run.
func _plan_run() -> void:
	if source.is_running():
		return
	var layout := profile.get_layout(profile.get_level())
	if layout.is_empty():
		_start_run()
		return
	planning.open(profile.get_level(), layout)
	_show(Screen.PLAN)


## The player's sites are saved with the profile, then the run starts on them.
func _planned(layout: Array) -> void:
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
		profile.bank_run(result["result"])
		if result["result"].get("outcome") == HoldfastRules.OUTCOME_WON:
			next = profile.get_next_level(str(result["result"].get("level", "")))
	summary.show_summary(result, next)
	_show(Screen.SUMMARY)


func _show(next: Screen) -> void:
	screen = next
	home.visible = next == Screen.HOME
	keep_screen.visible = next == Screen.KEEP
	planning.visible = next == Screen.PLAN
	hud.visible = next == Screen.RUN
	summary.visible = next == Screen.SUMMARY
