extends KitTestCase
## KIT-08: the screenshot run photographs the middle of the level.

const Autoplay := preload("res://scripts/autoplay.gd")


func test_the_run_screenshot_is_taken_halfway_and_never_before_wave_one() -> void:
	# Worked by hand: half of the waves, rounded up, and at least wave 1.
	expect_eq(Autoplay.screenshot_wave(0), 1, "no waves still gives wave 1")
	expect_eq(Autoplay.screenshot_wave(1), 1)
	expect_eq(Autoplay.screenshot_wave(2), 1)
	expect_eq(Autoplay.screenshot_wave(3), 2)
	expect_eq(Autoplay.screenshot_wave(10), 5)
	expect_eq(Autoplay.screenshot_wave(11), 6)
