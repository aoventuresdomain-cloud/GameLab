extends KitTestCase
## HF-M2-60: the Settings screen (volume, screen shake, flashes) saved through SaveService, the sound
## effects that obey the volume, and the short number format.

const Main := preload("res://scenes/main.tscn")
const Hud := preload("res://scripts/ui/hud.gd")
const DIR := "user://settings_tests"


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join(name + ".sav")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	return path


## A settings node that reads and writes `path`, like the game's own.
func _settings(path: String) -> HoldfastSettings:
	var settings := HoldfastSettings.new()
	settings.save_path = path
	settings.load_settings()
	return settings


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	return main


func _start(main: Node) -> HoldfastRules:
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.select_level("outpost")
	main.call("_start_run")
	return main.get_node("RunSource").get_rules()


# --- Settings are saved ---

func test_the_defaults_are_a_middling_volume_with_shake_and_flashes_on() -> void:
	var settings := _settings(_path("defaults"))
	expect_eq(settings.get_volume(), HoldfastSettings.DEFAULT_VOLUME)
	expect_true(settings.is_shake_on())
	expect_true(settings.are_flashes_on())
	settings.free()


func test_every_setting_comes_back_from_the_file() -> void:
	var path := _path("round_trip")
	var settings := _settings(path)
	settings.set_volume(0.25)
	settings.set_shake(false)
	settings.set_flashes(false)
	settings.free()
	var again := _settings(path)
	expect_eq(again.get_volume(), 0.25, "volume")
	expect_false(again.is_shake_on(), "shake")
	expect_false(again.are_flashes_on(), "flashes")
	again.free()


func test_each_setting_changes_alone() -> void:
	var path := _path("alone")
	var settings := _settings(path)
	settings.set_shake(false)
	var again := _settings(path)
	expect_false(again.is_shake_on())
	expect_true(again.are_flashes_on(), "flashes untouched")
	expect_eq(again.get_volume(), HoldfastSettings.DEFAULT_VOLUME, "volume untouched")
	settings.free()
	again.free()


func test_seen_hints_are_kept_and_counted_once() -> void:
	var path := _path("hints")
	var settings := _settings(path)
	expect_false(settings.has_seen_hint("blessings"))
	settings.see_hint("blessings")
	settings.see_hint("blessings")
	var again := _settings(path)
	expect_true(again.has_seen_hint("blessings"))
	expect_false(again.has_seen_hint("squad"))
	expect_eq(again._hints_seen.size(), 1)
	settings.free()
	again.free()


func test_volume_is_kept_between_zero_and_one() -> void:
	var settings := _settings(_path("clamp"))
	settings.set_volume(7.0)
	expect_eq(settings.get_volume(), 1.0)
	settings.set_volume(-3.0)
	expect_eq(settings.get_volume(), 0.0)
	settings.free()


func test_a_damaged_file_gives_the_defaults_and_says_so() -> void:
	var path := _path("damaged")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	var settings := _settings(path)
	expect_eq(settings.get_volume(), HoldfastSettings.DEFAULT_VOLUME)
	expect_true(settings.load_message != "", "the player is told")
	settings.free()


func test_a_file_with_odd_values_is_read_safely() -> void:
	var path := _path("odd")
	expect_true(SaveService.new(path, HoldfastSettings.SAVE_VERSION).save({"volume": 9.0, "shake": "yes", "hints_seen": "nope"}))
	var settings := _settings(path)
	expect_eq(settings.get_volume(), 1.0, "volume is clamped")
	expect_eq(settings._hints_seen, [], "a bad hint list is dropped")
	settings.free()


func test_the_volume_setting_sets_the_master_bus() -> void:
	var settings := _settings(_path("bus"))
	settings.set_volume(0.5)
	expect_near(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), 0.01)
	expect_false(AudioServer.is_bus_mute(0))
	settings.set_volume(0.0)
	expect_true(AudioServer.is_bus_mute(0), "zero is silent")
	settings.set_volume(HoldfastSettings.DEFAULT_VOLUME)
	settings.free()


# --- The Settings screen ---

func test_the_home_screens_settings_button_opens_the_screen_and_back_returns() -> void:
	var main := _main()
	var home: Control = main.home
	home.get_node("%SettingsButton").pressed.emit()
	expect_true(main.settings_screen.visible, "Settings is open")
	expect_false(home.visible)
	main.settings_screen.get_node("%BackButton").pressed.emit()
	expect_true(home.visible, "back to the home screen")
	expect_false(main.settings_screen.visible)
	main.free()


func test_the_screen_shows_the_settings_and_changing_them_changes_the_settings() -> void:
	var main := _main()
	var screen: Control = main.settings_screen
	var settings: HoldfastSettings = main.settings
	settings.set_volume(0.4)
	expect_eq(screen.get_node("%VolumeSlider").value, 40.0, "the slider shows the volume")
	expect_eq(screen.get_node("%VolumeValue").text, "40%")
	screen.get_node("%VolumeSlider").value = 80.0
	expect_near(settings.get_volume(), 0.8, 0.001)
	screen.get_node("%ShakeButton").button_pressed = false
	expect_false(settings.is_shake_on(), "shake off")
	screen.get_node("%FlashesButton").button_pressed = false
	expect_false(settings.are_flashes_on(), "flashes off")
	expect_false(screen.get_node("%ShakeButton").button_pressed)
	expect_eq(screen.get_node("%ShakeButton").text, "Screen shake: Off", "the words say it, not just the switch")
	expect_eq(screen.get_node("%FlashesButton").text, "Flashes: Off")
	screen.get_node("%ShakeButton").button_pressed = true
	expect_true(settings.is_shake_on(), "shake back on")
	settings.set_volume(HoldfastSettings.DEFAULT_VOLUME)
	main.free()


func test_a_new_game_keeps_the_settings() -> void:
	var main := _main()
	main.settings.set_shake(false)
	main.call("_new_game")
	expect_false(main.settings.is_shake_on())
	main.free()


# --- Shake and flashes ---

func test_a_hit_on_the_keep_shakes_the_view_unless_shake_is_off() -> void:
	var main := _main()
	var rules := _start(main)
	var world: Node2D = main.get_node("World")
	world._process(0.016)
	expect_eq(world.shake_offset(), Vector2.ZERO, "nothing has hit the keep")
	rules.keep_health -= 5
	world._process(0.016)
	expect_true(world.shake_offset() != Vector2.ZERO, "a hit shakes the view")
	world._shake_left = 0.0
	main.settings.set_shake(false)
	rules.keep_health -= 5
	world._process(0.016)
	expect_eq(world.shake_offset(), Vector2.ZERO, "off: no shake")
	main.settings.set_shake(true)
	main.free()


func test_the_view_settles_when_the_shake_is_over() -> void:
	var main := _main()
	var rules := _start(main)
	var world: Node2D = main.get_node("World")
	world._process(0.016)
	rules.keep_health -= 5
	world._process(0.016)
	world._process(HoldfastRules.EFFECT_SECONDS + world.SHAKE_SECONDS)
	world._process(0.016)
	expect_eq(world.shake_offset(), Vector2.ZERO)
	main.free()


func test_flashes_are_drawn_only_while_the_setting_is_on() -> void:
	var main := _main()
	var world: Node2D = main.get_node("World")
	expect_true(world._flashes_allowed())
	main.settings.set_flashes(false)
	expect_false(world._flashes_allowed(), "off: the burst and level-up flashes are skipped")
	main.settings.set_flashes(true)
	main.free()


# --- Sound ---

func test_nothing_plays_at_zero_volume_and_a_sound_plays_above_it() -> void:
	var main := _main()
	var audio: HoldfastAudio = main.get_node("Audio")
	expect_true(audio._players.has("hit"), "the sounds are loaded")
	main.settings.set_volume(0.0)
	expect_false(audio.play("hit"), "volume zero")
	main.settings.set_volume(0.5)
	expect_true(audio.play("hit"), "volume up")
	expect_false(audio.play("no_such_sound"))
	main.settings.set_volume(HoldfastSettings.DEFAULT_VOLUME)
	main.free()


func test_each_event_plays_its_own_sound() -> void:
	var main := _main()
	var rules := _start(main)
	var audio: HoldfastAudio = main.get_node("Audio")
	audio.forget_run()
	expect_eq(audio.poll(rules), [], "the first look plays nothing")
	rules.time += 1.0
	rules.keep_health -= 1
	expect_eq(audio.poll(rules), ["hit"], "keep hit")
	rules.time += 1.0
	rules.kills += 1
	expect_eq(audio.poll(rules), ["gold"], "an enemy defeated pays gold")
	rules.time += 1.0
	rules.staff_level += 1
	expect_eq(audio.poll(rules), ["level"], "a level-up")
	rules.time += 1.0
	var boss := HoldfastRules.Enemy.new()
	boss.tier = "boss"
	rules.enemies.append(boss)
	expect_eq(audio.poll(rules), ["boss"], "a boss arrives")
	rules.time += 1.0
	expect_eq(audio.poll(rules), [], "no change, no sound")
	main.free()


func test_a_burst_of_the_same_event_plays_once_per_gap() -> void:
	var main := _main()
	var rules := _start(main)
	var audio: HoldfastAudio = main.get_node("Audio")
	audio.forget_run()
	audio.poll(rules)
	rules.time += 1.0
	rules.kills += 1
	expect_eq(audio.poll(rules), ["gold"])
	rules.time += HoldfastAudio.GAP_SECONDS * 0.5
	rules.kills += 1
	expect_eq(audio.poll(rules), [], "too soon after the last")
	rules.time += HoldfastAudio.GAP_SECONDS
	rules.kills += 1
	expect_eq(audio.poll(rules), ["gold"], "after the gap")
	main.free()


func test_a_zero_volume_run_plays_no_sound_at_all() -> void:
	var main := _main()
	var rules := _start(main)
	var audio: HoldfastAudio = main.get_node("Audio")
	main.settings.set_volume(0.0)
	audio.forget_run()
	audio.poll(rules)
	rules.time += 1.0
	rules.keep_health -= 1
	expect_eq(audio.poll(rules), [], "silent")
	main.settings.set_volume(HoldfastSettings.DEFAULT_VOLUME)
	main.free()


func test_a_headless_run_starts_no_playback_so_nothing_is_left_playing_at_quit() -> void:
	var main := _main()
	var audio: HoldfastAudio = main.get_node("Audio")
	var heard := []
	audio.played.connect(func(sound: String) -> void: heard.append(sound))
	expect_true(audio.play("boss"), "the event is still counted")
	expect_eq(heard, ["boss"])
	expect_false(audio._players["boss"].playing, "but no sound is started without a sound device")
	main.free()


func test_every_sound_file_is_listed_in_the_credits() -> void:
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	for sound in HoldfastAudio.SOUNDS:
		var file: String = str(HoldfastAudio.SOUNDS[sound]).get_file()
		expect_true(credits.contains(file), "%s is in assets/CREDITS.md" % file)


# --- Short numbers ---

func test_short_numbers_at_every_boundary() -> void:
	var cases := {
		0: "0", 7: "7", 999: "999",
		1000: "1K", 1049: "1K", 1100: "1.1K", 1234: "1.2K", 9999: "9.9K",
		10000: "10K", 12345: "12.3K", 999999: "999.9K",
		1000000: "1M", 1234567: "1.2M", 3400000: "3.4M", 999999999: "999.9M",
		1000000000: "1B", 2500000000: "2.5B",
		1000000000000: "1T", 7800000000000: "7.8T",
		-1: "-1", -999: "-999", -1000: "-1K", -1234: "-1.2K", -3400000: "-3.4M",
	}
	for value in cases:
		expect_eq(ShortNumber.of(value), cases[value], str(value))


func test_a_price_paid_exactly_keeps_every_digit() -> void:
	expect_eq(ShortNumber.exact(1234567), "1,234,567")
	expect_eq(ShortNumber.exact(999), "999")
	expect_eq(ShortNumber.exact(1000), "1,000")
	expect_eq(ShortNumber.exact(-12345), "-12,345")


func test_the_screens_use_the_short_format() -> void:
	expect_eq(Hud.format_number(1234), "1.2K")
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.bank_run({"gold": 3400000, "outcome": "lost", "level": "outpost"})
	expect_eq(main.journey._gold.text, "3.4M", "the map's gold")
	var id := ""
	for key in profile._content["upgrade_nodes"]:
		if not HoldfastMeta.is_star_node(profile._content["upgrade_nodes"][key]):
			id = key
			break
	profile._content["upgrade_nodes"][id]["cost"] = 1500
	expect_eq(profile.get_cost_text(id), "1.5K gold")
	main.free()
