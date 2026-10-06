class_name SteamService
extends RefCounted
## Small wrapper over GodotSteam: init, unlock achievement, store
## stats, and the per-frame callback pump.
##
## Safe everywhere: when Steam cannot be used (no GodotSteam in the build, a web or
## headless build, Steam not running, init refused) every call is a no-op that
## returns false, and the reason is logged once. The game never needs to check.
##
##   var steam := SteamService.new()
##   steam.init(480)            # the game passes its app ID; 480 is Valve's test app
##   steam.unlock_achievement("ACH_WIN_ONE_GAME")
##   steam.poll()               # once per frame

## Engine singleton name GodotSteam registers.
const SINGLETON := "Steam"

var app_id := 0
var _steam: Object
var _initialised := false
var _reason := ""
var _logged := false
## Messages written by _log; kept so tests can read them.
var log_lines: PackedStringArray = []


## Starts Steam for `p_app_id`. Returns true when Steam is ready.
func init(p_app_id: int) -> bool:
	app_id = p_app_id
	_initialised = false
	if p_app_id <= 0:
		return _unavailable("no app ID")
	if OS.has_feature("web"):
		return _unavailable("web build")
	if DisplayServer.get_name() == "headless":
		return _unavailable("headless run")
	if not Engine.has_singleton(SINGLETON):
		return _unavailable("GodotSteam not in this build")
	_steam = Engine.get_singleton(SINGLETON)
	# Steam reads the app ID from the environment when no steam_appid.txt is present.
	OS.set_environment("SteamAppId", str(p_app_id))
	OS.set_environment("SteamGameId", str(p_app_id))
	var status: Variant = _steam.call("steamInitEx")
	var ok := status is Dictionary and int(status.get("status", -1)) == 0
	if not ok:
		return _unavailable("Steam init failed: %s" % [status])
	_initialised = true
	_log("ready, app %d" % p_app_id)
	return true


func is_available() -> bool:
	return _initialised


## Why Steam is unavailable, or "" when it is ready.
func unavailable_reason() -> String:
	return "" if _initialised else _reason


## Unlocks an achievement and stores it. Returns true when Steam accepted both.
func unlock_achievement(achievement: String) -> bool:
	if not _initialised:
		return false
	var set_ok: bool = _steam.call("setAchievement", achievement)
	var stored := store_stats()
	_log("achievement %s: %s" % [achievement, "unlocked" if set_ok and stored else "refused"])
	return set_ok and stored


## Sends stats and achievements to Steam. Returns true when Steam accepted.
func store_stats() -> bool:
	if not _initialised:
		return false
	return bool(_steam.call("storeStats"))


## Runs Steam callbacks; call once per frame while the game runs.
func poll() -> void:
	if _initialised:
		_steam.call("run_callbacks")


## True when GodotSteam is in this build, whether or not Steam can run here.
## Logged with the unavailable reason so CI can prove a desktop build carries it.
static func has_godotsteam() -> bool:
	return Engine.has_singleton(SINGLETON)


func _unavailable(reason: String) -> bool:
	_reason = reason
	if not _logged:
		_logged = true
		_log("unavailable (%s; GodotSteam loaded: %s); Steam features are off" % [reason, "yes" if has_godotsteam() else "no"])
	return false


func _log(message: String) -> void:
	var line := "[steam] " + message
	log_lines.append(line)
	print(line)
