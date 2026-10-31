extends Node
## Run flow: main menu -> journey map -> plan -> run (HUD) -> summary -> journey map. The
## Hero page and the skill tree open from the map and close back to it. The game layer: the
## only place that starts a run or changes the profile. Screens ask through their
## signals and the flow acts, so a screen never writes progress itself.

enum Screen { HOME, MAP, TREE, HERO, PLAN, RUN, SUMMARY, RECRUITS, SETTINGS }

@export var source_path: NodePath
@export var profile_path: NodePath
@export var home_path: NodePath
@export var settings_path: NodePath
@export var settings_screen_path: NodePath
@export var journey_path: NodePath
@export var hero_page_path: NodePath
@export var recruits_path: NodePath
@export var keep_screen_path: NodePath
@export var hud_path: NodePath
@export var summary_path: NodePath
@export var planning_path: NodePath

@onready var source: Node = get_node(source_path)
@onready var profile: HoldfastProfile = get_node(profile_path)
@onready var home: Control = get_node(home_path)
## The player's settings and the screen that changes them.
@onready var settings: HoldfastSettings = get_node(settings_path)
@onready var settings_screen: Control = get_node(settings_screen_path)
@onready var journey: Control = get_node(journey_path)
@onready var hero_page: Control = get_node(hero_page_path)
## The Recruits page: board, roster and squad.
@onready var recruits_page: Control = get_node(recruits_path)
## The skill tree page.
@onready var keep_screen: Control = get_node(keep_screen_path)
@onready var hud: Control = get_node(hud_path)
@onready var summary: Control = get_node(summary_path)
@onready var planning: Control = get_node(planning_path)

const Guidance = preload("res://scripts/ui/guidance.gd")

## Shown once, on the summary that first pays stars.
const STARS_LINE := "Stars buy slots and towers. Gold buys upgrades."

var screen := Screen.HOME


func _ready() -> void:
	hud.bind(source)
	hud.begin_requested.connect(source.release_hold)
	hud.special_requested.connect(_on_special_requested)
	home.bind(profile)
	settings_screen.bind(settings)
	for screen_with_hints in [planning, hero_page]:
		screen_with_hints.bind_hints(settings)
		screen_with_hints.hint_seen.connect(settings.see_hint)
	journey.bind_hints(settings)
	journey.bind(profile)
	hero_page.bind(profile)
	recruits_page.bind(profile)
	keep_screen.bind(profile)
	home.continue_requested.connect(_show.bind(Screen.MAP))
	home.new_game_requested.connect(_new_game)
	home.settings_requested.connect(_show.bind(Screen.SETTINGS))
	settings_screen.volume_requested.connect(settings.set_volume)
	settings_screen.shake_requested.connect(settings.set_shake)
	settings_screen.flashes_requested.connect(settings.set_flashes)
	settings_screen.back_requested.connect(_show.bind(Screen.HOME))
	home.quit_requested.connect(get_tree().quit)
	journey.home_requested.connect(_show.bind(Screen.HOME))
	journey.tree_requested.connect(_show.bind(Screen.TREE))
	journey.hero_requested.connect(_show.bind(Screen.HERO))
	journey.recruits_requested.connect(_open_recruits.bind(Screen.MAP))
	recruits_page.back_requested.connect(_leave_recruits)
	recruits_page.squad_toggled.connect(profile.toggle_squad)
	recruits_page.hire_requested.connect(profile.hire)
	recruits_page.pick_requested.connect(profile.pick_skill)
	recruits_page.rename_requested.connect(profile.rename)
	journey.level_requested.connect(_level_picked)
	journey.buy_requested.connect(profile.buy)
	journey.stand_requested.connect(_begin_stand)
	journey.plan_requested.connect(_plan_from_map)
	hero_page.back_requested.connect(_show.bind(Screen.MAP))
	hero_page.tree_requested.connect(_open_tree_at.bind("Hero"))
	hero_page.pillar_requested.connect(profile.select_pillar)
	hero_page.gear_requested.connect(profile.toggle_gear)
	hero_page.gear_wear_requested.connect(profile.wear_gear)
	hero_page.gear_off_requested.connect(profile.take_off_gear)
	keep_screen.back_requested.connect(_show.bind(Screen.MAP))
	keep_screen.buy_requested.connect(profile.buy)
	keep_screen.respec_requested.connect(_respec_requested)
	keep_screen.refund_requested.connect(_refund_requested)
	keep_screen.stand_requested.connect(_begin_stand)
	summary.play_again_requested.connect(_plan_run)
	planning.start_requested.connect(_planned)
	planning.back_requested.connect(_show.bind(Screen.MAP))
	planning.tower_requested.connect(_tower_requested)
	planning.squad_requested.connect(_open_recruits.bind(Screen.PLAN))
	planning.recruit_posted.connect(_recruit_posted)
	summary.next_level_requested.connect(_next_level)
	summary.pick_requested.connect(profile.pick_skill)
	profile.changed.connect(func() -> void:
		if screen == Screen.SUMMARY:
			summary.set_picks(profile.get_pending_picks()))
	summary.map_requested.connect(_show.bind(Screen.MAP))
	summary.tree_requested.connect(_show.bind(Screen.TREE))
	source.run_ended.connect(_on_run_ended)
	_show(Screen.HOME)


func _new_game() -> void:
	profile.new_game()
	_show(Screen.MAP)


## Opens the Recruits page from the map or the Plan page, and goes back to whichever it came from.
var _recruits_from := Screen.MAP


func _open_recruits(from: Screen) -> void:
	_recruits_from = from
	profile.clear_welcome()
	_show(Screen.RECRUITS)


func _leave_recruits() -> void:
	if _recruits_from == Screen.PLAN:
		_open_plan()
	else:
		_show(_recruits_from)


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
	_open_plan()


## The map's Plan button: opens the Plan page on a level without starting it. Only the map can
## ask (so never during a run), and not at the Start step; the compulsory guide has no tower yet,
## which shuts it too.
func _plan_from_map(id: String) -> void:
	if screen != Screen.MAP or profile.is_stand_due():
		return
	if not id in profile.get_unlocked_levels() or profile.is_tutorial(id) or not profile.has_a_tower():
		return
	profile.select_level(id)
	_open_plan()


## Opens the Plan page for the selected level.
func _open_plan() -> void:
	var level := profile.get_level()
	var saved := profile.has_saved_layout(level)
	planning.open(level, profile.get_layout(level) if saved else [], saved, profile.get_ring_spots(), profile.get_castle_cards(), profile.get_castle_mage_cards(), profile.get_castle_slots())
	var draw := RandomNumberGenerator.new()
	draw.randomize()
	planning.set_blessings(profile.get_blessing_offer(level, draw))
	planning.set_squad(profile.get_squad().map(func(recruit: Dictionary) -> String: return recruit["name"]), profile.get_recruits().size())
	_show_posted()
	_offer_tower()
	_show(Screen.PLAN)


## Tells the Plan page who is on the squad and who is set on which post.
func _show_posted() -> void:
	planning.set_posted(profile.get_squad().map(func(recruit: Dictionary) -> Dictionary: return {"id": recruit["id"], "name": recruit["name"]}), profile.get_posted(), "link_posted_hand" in profile.get_upgrades())


func _recruit_posted(site: String, id: String) -> void:
	profile.post_recruit(site, id)
	_show_posted()


## Sets the Plan page's "+ Tower" button to the next buy that adds a tower, with its price.
func _offer_tower() -> void:
	var id := profile.get_next_tower_node()
	planning.set_tower_offer("" if id == "" else "+ Tower (%s)" % profile.get_cost_text(id), "" if id == "" else profile.why_not_buy(id))


## "+ Tower" on the Plan page buys the next slot or Archer Post at the tree's price; the posts
## already placed stay.
func _tower_requested() -> void:
	var id := profile.get_next_tower_node()
	if id != "" and profile.buy(id):
		planning.set_castle(profile.get_ring_spots(), profile.get_castle_cards(), profile.get_castle_mage_cards(), profile.get_castle_slots())
	_offer_tower()


## Taking one node back changes what the next run is built on too, so it waits as well.
func _refund_requested(id: String) -> void:
	if source.is_running():
		profile.notice.emit("A refund waits until the run is over.")
		return
	profile.refund(id)


## A respec changes what the next run is built on, so it waits until the run is over.
func _respec_requested() -> void:
	if source.is_running():
		profile.notice.emit("A refund waits until the run is over.")
		return
	profile.respec()


## The player's sites are saved with the profile, then the run starts on them.
func _planned(layout: Array) -> void:
	if layout.is_empty():
		return
	profile.set_layout(profile.get_level(), layout)
	_start_run(false, planning.blessing())


## The map's Start button, after the two guided buys: the short fight with the post just bought.
## Nothing starts it but a press, and it is offered once.
func _begin_stand() -> void:
	if source.is_running() or not profile.is_stand_due():
		return
	profile.begin_stand()
	profile.select_level(profile.get_tutorial_level())
	_start_run(true)


## Starts a run on the profile's level, upgrades and Hero pillar; `stand` fights the tutorial's
## stand on the castle's own posts; `blessing` is the one picked on the Plan page ("" for none).
func _start_run(stand := false, blessing := "") -> void:
	if source.is_running():
		return
	if "hero_path" in source:
		source.hero_path = profile.get_pillar()
		source.level_id = profile.get_level()
		source.upgrades = profile.get_upgrades().duplicate()
		source.stand = stand
		source.blessing = blessing
		# The tutorial and its stand are the Hero's alone; every other run takes the squad the player picked.
		source.squad = [] if stand or profile.is_tutorial(profile.get_level()) else profile.get_squad()
		source.posted = profile.get_posted()
		# A bot-driven run (the CI smoke) has nobody to press a key.
		source.wait_for_press = not source.use_bot
		# The first run after the tutorial stops at the special's first fight until the player presses it
		# (a run nobody plays, a bot's or a test's stepped one, has nobody to press).
		source.teach_special = source.auto_step and not source.use_bot and not stand and profile.is_special_due(profile.get_level())
		source.layout = profile.get_stand_layout() if stand else profile.get_layout(profile.get_level())
		source.gear = profile.get_gear_worn()
		source.gear_owned = profile.get_gear_owned().duplicate()
	_show(Screen.RUN)
	source.start_run()


## The player pressed the special at its prompt: the Hero fires and the prompt is not shown again.
func _on_special_requested() -> void:
	source.press_special()
	profile.teach_special()


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
		var before: Dictionary = profile.data.duplicate(true)
		profile.bank_run(result["result"])
		result["recruit_changes"] = RecruitMeta.changes(HoldfastContent.base(), before, profile.data)
		result["stars_paid"] = profile.get_stars_earned() - stars_before
		result["reward_gold"] = profile.get_reward_gold(level) if first_win else 0
		if int(result["stars_paid"]) > 0 and not profile.has_seen_stars_line():
			result["stars_note"] = STARS_LINE
			profile.show_stars_line()
		if result["result"].get("outcome") == HoldfastRules.OUTCOME_WON:
			next = profile.get_next_level(level)
			# While the guided buys are due no level can be planned: the guide comes first.
			if profile.get_guide_node() != "":
				next = ""
		result["notes"] = Guidance.summary_notes(HoldfastContent.base(), profile, result["result"], next)
		if profile.get_guide_node() != "":
			result["notes"]["guide_note"] = Guidance.GUIDE_NOTE
	summary.show_summary(result, next)
	summary.set_picks(profile.get_pending_picks() if result.has("result") else [])
	_show(Screen.SUMMARY)


func _show(next: Screen) -> void:
	var from := screen
	screen = next
	# Looking at the tree (opening or leaving it) or the Hero page clears the dot on its tab.
	if next == Screen.TREE or from == Screen.TREE:
		journey.mark_tree_seen()
	if next == Screen.HERO:
		profile.see_gear()
	home.visible = next == Screen.HOME
	settings_screen.visible = next == Screen.SETTINGS
	journey.visible = next == Screen.MAP
	hero_page.visible = next == Screen.HERO
	recruits_page.visible = next == Screen.RECRUITS
	keep_screen.visible = next == Screen.TREE
	planning.visible = next == Screen.PLAN
	hud.visible = next == Screen.RUN
	summary.visible = next == Screen.SUMMARY
