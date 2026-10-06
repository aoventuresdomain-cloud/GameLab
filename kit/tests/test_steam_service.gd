extends KitTestCase
## KIT-04: without Steam (CI, web, headless) the service is a no-op that logs once.


func test_without_steam_every_call_is_a_safe_no_op() -> void:
	var steam := SteamService.new()
	expect_false(steam.init(480), "init reports unavailable")
	expect_false(steam.is_available())
	expect_false(steam.unlock_achievement("ACH_WIN_ONE_GAME"))
	expect_false(steam.store_stats())
	steam.poll()
	expect_ne(steam.unavailable_reason(), "", "says why")


func test_logs_the_reason_once() -> void:
	var steam := SteamService.new()
	steam.init(480)
	steam.init(480)
	steam.unlock_achievement("ACH_WIN_ONE_GAME")
	expect_eq(steam.log_lines.size(), 1, "one log line, however often it is called")
	expect_true(steam.log_lines[0].begins_with("[steam] unavailable"))


func test_no_app_id_is_refused() -> void:
	var steam := SteamService.new()
	expect_false(steam.init(0))
	expect_eq(steam.unavailable_reason(), "no app ID")


func test_no_credentials_in_the_service() -> void:
	var source := FileAccess.get_file_as_string("res://addons/gamelab_kit/services/steam/steam_service.gd")
	for banned in ["password", "steam_api_key", "STEAM_CONFIG", "webapi"]:
		expect_false(source.to_lower().contains(banned.to_lower()), "mentions " + banned)


func test_unavailable_message_says_whether_godotsteam_is_loaded() -> void:
	var steam := SteamService.new()
	steam.init(480)
	expect_false(SteamService.has_godotsteam(), "no GodotSteam in the test host")
	expect_true(steam.log_lines[0].contains("GodotSteam loaded: no"), steam.log_lines[0])
