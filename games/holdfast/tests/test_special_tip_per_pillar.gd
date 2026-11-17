extends KitTestCase
## Quick fix 16b (HF-M2-83, F-191): the first-run special tip names each Hero pillar's own special, and fits its panel.

const Hud := preload("res://scenes/ui/hud.tscn")
const OWN_WORD := {"flare_archer": "fire", "dusk_mage": "pulls", "tideblade": "dash"}
const KEYS := "Press Space, A or click to use it."


func _note_for(pillar: String) -> String:
	var source := HoldfastRunSource.new()
	source.auto_step = false
	source.rng_seed = 3
	source.level_id = "outpost"
	source.hero_path = pillar
	source.teach_special = true
	tree.root.add_child(source)
	source.start_run()
	source.step(240.0)
	var note := ""
	if source.is_teaching_special():
		note = source.get_special_note()
	source.free()
	return note


func test_every_pillar_is_stopped_at_its_own_tip() -> void:
	for pillar in HoldfastContent.base()["hero_paths"]:
		expect_true(_note_for(pillar) != "", "%s reaches the prompt" % pillar)


func test_the_flare_archer_tip_is_the_burst_of_fire() -> void:
	var note := _note_for("flare_archer")
	expect_true(note.contains("a burst of fire, far stronger than your arrows"), note)
	expect_true(note.ends_with(KEYS), note)


func test_the_dusk_mage_tip_names_the_pull_and_slow_not_fire() -> void:
	var note := _note_for("dusk_mage")
	expect_true(note.contains("pulls enemies in and slows them"), note)
	expect_false(note.contains("fire") or note.contains("arrows"), "nothing of the Archer's special: " + note)


func test_the_tideblade_tip_names_the_dash_not_fire() -> void:
	var note := _note_for("tideblade")
	expect_true(note.contains("dashes"), note)
	expect_false(note.contains("fire") or note.contains("arrows"), "nothing of the Archer's special: " + note)
	expect_false(note.contains("burst"), note)


func test_every_tip_fits_its_panel_without_overlap() -> void:
	var hud: Control = Hud.instantiate()
	tree.root.add_child(hud)
	var label: Label = hud.get_node("%PostsNote")
	var width := label.offset_right - label.offset_left
	var height := label.offset_bottom - label.offset_top
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	expect_true(size >= 20, "the tip is in the 20 px UI font or larger")
	for pillar in HoldfastContent.base()["hero_paths"]:
		var note := _note_for(pillar)
		var box := font.get_multiline_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, width, size)
		expect_true(box.y <= height, "%s: %.0f px of text in a %.0f px panel" % [pillar, box.y, height])
		expect_true(note.get_slice("\n", 0).length() <= 80, "%s: the first line stays short" % pillar)
	hud.free()
