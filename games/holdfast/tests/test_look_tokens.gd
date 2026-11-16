extends KitTestCase
## HF-M2-72: the look is one set of tokens in one theme. No screen sets a colour, a font or a type
## size of its own: it asks the theme (a type variation, or UiTokens for a drawn colour).

const SCREEN_DIRS := ["res://scripts/ui/", "res://scenes/ui/"]
## What a screen may not write: a colour of its own, or a font or type size override.
const FORBIDDEN := [
	"Color(", "Color.", "Color8(", "add_theme_color_override", "add_theme_font_override",
	"add_theme_font_size_override", "theme_override_colors", "theme_override_fonts", "theme_override_font_sizes",
]
## The one place that turns a token or a pack's colour text into a colour.
const ALLOWED_FILES := ["tokens.gd"]
const THEME := "res://assets/ui/theme.tres"


func _files() -> Array:
	var out := []
	for dir in SCREEN_DIRS:
		for file in DirAccess.get_files_at(dir):
			if (file.ends_with(".gd") or file.ends_with(".tscn")) and not file in ALLOWED_FILES:
				out.append(dir + file)
	return out


func test_no_screen_sets_a_colour_a_font_or_a_size_of_its_own() -> void:
	expect_true(_files().size() > 20, "the screens were found (%d files)" % _files().size())
	for path in _files():
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line := lines[i].strip_edges()
			if line.begins_with("#") or line.begins_with("##"):
				continue
			for word in FORBIDDEN:
				expect_false(line.contains(word), "%s:%d writes '%s' (use the theme)" % [path, i + 1, word])


func test_every_token_a_screen_asks_for_is_in_the_theme() -> void:
	var theme: Theme = load(THEME)
	var asked := {}
	var re := RegEx.create_from_string("UiTokens\\.colour\\(&\"(\\w+)\"")
	for path in _files():
		if path.ends_with(".gd"):
			for m in re.search_all(FileAccess.get_file_as_string(path)):
				asked[m.get_string(1)] = path
	expect_true(asked.size() >= 8, "tokens are in use (%d)" % asked.size())
	for token in asked:
		expect_true(theme.has_color(token, UiTokens.TYPE), "token '%s' (asked for in %s) is in the theme" % [token, asked[token]])


func test_every_type_variation_a_screen_names_is_in_the_theme() -> void:
	var theme: Theme = load(THEME)
	var asked := {}
	var re := RegEx.create_from_string("(?:theme_type_variation = |variation[^=]*= ?)&\"(\\w+)\"")
	var re_code := RegEx.create_from_string("&\"([A-Z]\\w+)\"")
	for path in _files():
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			asked[m.get_string(1)] = path
		if path.ends_with(".gd"):
			for m in re_code.search_all(text):
				asked[m.get_string(1)] = path
	for variation in asked:
		if variation in ["Tokens"]:
			continue
		expect_true(theme.get_type_list().has(variation), "type '%s' (named in %s) is in the theme" % [variation, asked[variation]])


func test_the_tokens_have_the_looks_names() -> void:
	var theme: Theme = load(THEME)
	for token in ["night", "bone", "lamp", "good", "warning", "focus"]:
		expect_true(theme.has_color(token, UiTokens.TYPE), "the look has '%s'" % token)
	expect_true(theme.has_stylebox("normal", "MainButton") and theme.has_stylebox("normal", "QuietButton"), "main, second and quiet buttons")
	expect_true(theme.has_stylebox("focus", "Button"), "the focus ring is kept")
	expect_true(theme.has_font("font", "Heading"), "titles are in a serif")


const Main := preload("res://scenes/main.tscn")


## HF-M2-72: gold and stars sit in the same top-right corner, and the back chevron top-left, on every
## hub screen; every button is at least 44 px.
func test_gold_and_stars_share_one_corner_and_back_is_top_left_on_every_hub_screen() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	var corner := Vector2.ZERO
	var back_at := Vector2.ZERO
	for screen in [main.journey, main.keep_screen, main.hero_page, main.recruits_page]:
		screen.visible = true
		await tree.process_frame
		await tree.process_frame
		var gold: Control = screen.find_child("GoldChip", true, false)
		var stars: Control = screen.find_child("StarsChip", true, false)
		var back: Control = screen.find_child("BackButton", true, false)
		expect_true(gold != null and stars != null and back != null, "%s has gold, stars and a back button" % screen.name)
		expect_true(gold.get_node("Row/GoldIcon").texture != null and stars.get_node("Row/StarsIcon").texture != null, "%s: both have their icon" % screen.name)
		expect_true(back.size.x >= 44.0 and back.size.y >= 44.0, "%s: back is at least 44 px (%s)" % [screen.name, back.size])
		expect_true(back.get_global_rect().position.x < 40.0 and back.get_global_rect().position.y < 40.0, "%s: back is top-left" % screen.name)
		expect_true(stars.get_global_rect().end.x > 1230.0 and stars.get_global_rect().position.y < 40.0, "%s: stars are top-right" % screen.name)
		if corner == Vector2.ZERO:
			corner = Vector2(stars.get_global_rect().end.x, stars.get_global_rect().position.y)
			back_at = back.get_global_rect().position
		else:
			expect_eq(Vector2(stars.get_global_rect().end.x, stars.get_global_rect().position.y), corner, "%s: stars in the same place as on the others" % screen.name)
			expect_eq(back.get_global_rect().position, back_at, "%s: back in the same place as on the others" % screen.name)
			expect_true(gold.get_global_rect().end.x < stars.get_global_rect().position.x, "%s: gold is beside the stars" % screen.name)
		screen.visible = false
	main.free()
