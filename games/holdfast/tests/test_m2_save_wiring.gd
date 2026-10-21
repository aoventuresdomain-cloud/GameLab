extends KitTestCase
## KIT-07 wiring pin (Head of QA, M2): the kit's SaveService tests prove the service;
## this proves the game really saves through it rather than writing its own file.
##
## Pending until a script under res://scripts mentions SaveService; from then on the
## id must come out of qa_pending.json and this test is strict.

const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")


func test_the_game_saves_through_the_kit_save_service() -> void:
	var hits := QaSeam.mentions_outside("res://scripts", "", PackedStringArray(["SaveService"]))
	var qa := QaSeam.new(self, "res://tests/qa_pending.json")
	if not qa.check("save_wiring", hits.size() >= 1, "a script under res://scripts that uses SaveService"):
		return
	# Strict once wired: nothing under res://scripts may open its own save file for writing.
	var own_writers := QaSeam.mentions_outside("res://scripts", "", PackedStringArray(["FileAccess.WRITE"]))
	var allowed := PackedStringArray()
	for path in own_writers:
		if not FileAccess.get_file_as_string(path).contains("SaveService"):
			allowed.append(path)
	expect_eq(allowed, PackedStringArray(), "these scripts write files without going through SaveService")
