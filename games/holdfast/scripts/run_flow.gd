extends Node
## Run flow: home -> journey map -> plan -> run (HUD) -> summary -> journey map. The hub screens
## (Map, Tree, Hero, Squad, Menu) are reached from each other by the left rail, and each one's back
## goes to the map (the map's to the home screen). The game layer: the
## only place that starts a run or changes the profile. Screens ask through their
## signals and the flow acts, so a screen never writes progress itself.

enum Screen { HOME, MAP, TREE, HERO, PLAN, RUN, SUMMARY, RECRUITS, SETTINGS, ACHIEVEMENTS, MENU }

@export var source_path: NodePath
@export var profile_path: NodePath
@export var home_path: NodePath
@export var settings_path: NodePath
@export var settings_screen_path: NodePath
@export var menu_path: NodePath
@export var achievements_screen_path: NodePath
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
## The Menu tab: Settings, Achievements, Reset all upgrades, Back to title.
@onready var menu: Control = get_node(menu_path)
## The achievements list, opened from the Menu or the settings.
@onready var achievements_screen: Control = get_node(achievements_screen_path)
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
## What the window (and the web page tab) is called. The project name stays the old one, which keeps the
## user data folder and so every saved game.
const GAME_TITLE := "Fogwatch"

var screen := Screen.HOME


## The window takes its title once the first frame is up: the engine sets its own from the project name
## before that, which stays the old one so the user data folder and every save keep their place.
func _name_the_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	DisplayServer.window_set_title(GAME_TITLE)


func _ready() -> void:
	_name_the_window.call_deferred()
	hud.bind(source)
	hud.begin_requested.connect(source.release_hold)
	hud.pause_requested.connect(source.set_paused)
	hud.speed_requested.connect(_on_speed_requested)
	hud.call_wave_requested.connect(source.call_wave)
	hud.leave_requested.connect(_leave_run)
	hud.special_requested.connect(_on_special_requested)
	home.bind(profile)
	home.bind_settings(settings)
	settings_screen.bind(settings)
	achievements_screen.bind(profile)
	for screen_with_hints in [planning, hero_page]:
		screen_with_hints.bind_hints(settings)
		screen_with_hints.hint_seen.connect(settings.see_hint)
	journey.bind(profile)
	menu.bind(profile)
	for hub in [journey, keep_screen, hero_page, recruits_page, menu]:
		hub.rail.bind(profile, settings)
		hub.rail.tab_requested.connect(_rail_tab)
	hero_page.bind(profile)
	recruits_page.bind(profile)
	keep_screen.bind(profile)
	home.continue_requested.connect(_show.bind(Screen.MAP))
	home.new_game_requested.connect(_new_game)
	home.settings_requested.connect(_open_from.bind(Screen.SETTINGS, Screen.HOME))
	settings_screen.volume_requested.connect(settings.set_volume)
	settings_screen.shake_requested.connect(settings.set_shake)
	settings_screen.flashes_requested.connect(settings.set_flashes)
	settings_screen.reduced_motion_requested.connect(settings.set_reduced_motion)
	settings_screen.back_requested.connect(_leave.bind(Screen.SETTINGS))
	settings_screen.achievements_requested.connect(_open_from.bind(Screen.ACHIEVEMENTS, Screen.SETTINGS))
	achievements_screen.back_requested.connect(_leave.bind(Screen.ACHIEVEMENTS))
	menu.back_requested.connect(_show.bind(Screen.MAP))
	menu.settings_requested.connect(_open_from.bind(Screen.SETTINGS, Screen.MENU))
	menu.achievements_requested.connect(_open_from.bind(Screen.ACHIEVEMENTS, Screen.MENU))
	menu.reset_requested.connect(_respec_requested)
	menu.title_requested.connect(_show.bind(Screen.HOME))
	home.quit_requested.connect(get_tree().quit)
	journey.home_requested.connect(_show.bind(Screen.HOME))
	journey.hero_requested.connect(_show.bind(Screen.HERO))
	recruits_page.back_requested.connect(_leave_recruits)
	recruits_page.squad_toggled.connect(profile.toggle_squad)
	recruits_page.hire_requested.connect(profile.hire)
	recruits_page.pick_requested.connect(profile.pick_skill)
	recruits_page.rename_requested.connect(profile.rename)
	journey.level_requested.connect(_level_picked)
	journey.buy_requested.connect(profile.buy)
	journey.stand_requested.connect(_begin_stand)
	journey.plan_requested.connect(_plan_from_map)
	journey.tier_requested.connect(profile.select_tier)
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


## B on a pad and Escape on a keyboard press the back button of the screen that is up, so every screen
## can be left without a mouse. Home has none, a result waits for a choice, and a run's Escape pauses.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel", false):
		return
	var page: Control = {
		Screen.MAP: journey, Screen.TREE: keep_screen, Screen.HERO: hero_page, Screen.PLAN: planning,
		Screen.RECRUITS: recruits_page, Screen.SETTINGS: settings_screen, Screen.ACHIEVEMENTS: achievements_screen,
		Screen.MENU: menu,
	}.get(screen)
	var back: Button = page.find_child("BackButton", true, false) if page != null else null
	if back != null and back.is_visible_in_tree() and not back.disabled:
		back.pressed.emit()
		get_viewport().set_input_as_handled()


## A rail tab was pressed: go to that hub screen.
func _rail_tab(tab: String) -> void:
	match tab:
		"Map":
			_show(Screen.MAP)
		"Tree":
			_show(Screen.TREE)
		"Hero":
			_show(Screen.HERO)
		"Squad":
			_open_recruits(Screen.MAP)
		"Menu":
			_show(Screen.MENU)


## Where Settings and the Achievements list were opened from, so their back goes there.
var _opened_from := {}


func _open_from(next: Screen, from: Screen) -> void:
	_opened_from[next] = from
	_show(next)


func _leave(from: Screen) -> void:
	_show(_opened_from.get(from, Screen.MENU))


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
	planning.set_tier(profile.get_run_tier(), profile.get_hard_label(level))
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


## Sets the Plan page's "Add a tower" button to the next buy that adds a tower, with its price.
func _offer_tower() -> void:
	var id := profile.get_next_tower_node()
	planning.set_tower_offer("" if id == "" else "Add a tower (%s)" % profile.get_cost_text(id), "" if id == "" else profile.why_not_buy(id))


## "Add a tower" on the Plan page buys the next slot or Archer Post at the tree's price; the posts
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
		# The tier is the player's pick where the level offers it; the tutorial and its stand have none.
		var tier := profile.get_run_tier()
		source.hard = false if stand or tier == "normal" else (true if tier == "hard" else tier)
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
	source.set_speed(settings.get_speed())
	_show(Screen.RUN)
	source.start_run()
	if source.is_running():
		profile.mark_run_open()


## 1x or 2x from the run screen: the run runs at it and the settings remember it.
func _on_speed_requested(speed: int) -> void:
	source.set_speed(speed)
	settings.set_speed(speed)


## The pause screen's confirmed Leave: the run ends with no result, so nothing is banked or paid,
## and the player is back on the map.
func _leave_run() -> void:
	source.leave_run()
	profile.leave_run()
	_show(Screen.MAP)


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
		result["unlocks"] = profile.get_last_unlocks()
		result["stars_paid"] = profile.get_stars_earned() - stars_before
		result["reward_gold"] = profile.get_reward_gold(level) if first_win else 0
		# A Hard replay opens nothing: after it the player is back on the map.
		if result["result"].get("outcome") == HoldfastRules.OUTCOME_WON and not result["result"].get("hard", false):
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
		profile.see_buyable()
	if next == Screen.HERO:
		profile.see_gear()
	home.visible = next == Screen.HOME
	settings_screen.visible = next == Screen.SETTINGS
	achievements_screen.visible = next == Screen.ACHIEVEMENTS
	menu.visible = next == Screen.MENU
	journey.visible = next == Screen.MAP
	hero_page.visible = next == Screen.HERO
	recruits_page.visible = next == Screen.RECRUITS
	keep_screen.visible = next == Screen.TREE
	planning.visible = next == Screen.PLAN
	hud.visible = next == Screen.RUN
	summary.visible = next == Screen.SUMMARY
