extends Node
## Plays one full run with the bot aura and reports it, for CI smoke tests of the
## exported builds. Off unless asked for:
##   desktop:  Holdfast.exe --headless -- --autoplay [--seed=N]
##   (windowed, the game waits a few seconds after the run before quitting)
##   web:      index.html?autoplay=1[&seed=N]
## Prints "AUTOPLAY DONE {result json}" when the run ends; the desktop build then quits.
##   --screenshot-dir=DIR  (windowed desktop only) also saves 1-start.png, 2-run.png
##   (halfway through the waves) and 3-summary.png, at the window's size, for KIT-08.

const SPEED := 8.0
## Seconds a windowed desktop run stays open after the run ends, so Steam can
## record the achievement and show its overlay before the game quits.
const WINDOWED_QUIT_DELAY := 4.0

@export var flow_path: NodePath
@export var source_path: NodePath

var _shot_dir := ""
var _run_shot_taken := false


func _ready() -> void:
	var options := _options()
	if not options.has("autoplay"):
		return
	var source: HoldfastRunSource = get_node(source_path)
	source.use_bot = true
	source.rng_seed = int(options.get("seed", "1"))
	source.run_ended.connect(_on_run_ended)
	Engine.time_scale = SPEED
	print("AUTOPLAY START seed=%d" % source.rng_seed)
	if DisplayServer.get_name() != "headless":
		_shot_dir = str(options.get("screenshot-dir", ""))
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		source.wave_changed.connect(_on_wave_changed)
		await _screenshot("1-start")
	# Start through the run flow, as the Play button does.
	get_node(flow_path).call_deferred("_start_run")


## The wave to photograph "mid-run": halfway, and at least wave 1.
static func screenshot_wave(total_waves: int) -> int:
	return maxi(1, ceili(total_waves / 2.0))


func _on_wave_changed(wave: int, total: int) -> void:
	if _run_shot_taken or wave < screenshot_wave(total):
		return
	_run_shot_taken = true
	_screenshot("2-run")


## Saves the window's picture as DIR/NAME.png once the screen has drawn. Real
## time, so the 8x run speed doesn't shorten the wait.
func _screenshot(shot_name: String) -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_shot_dir, shot_name]
	if image.save_png(path) != OK:
		push_error("could not save " + path)
		return
	print("SCREENSHOT %s %dx%d" % [path, image.get_width(), image.get_height()])


func _on_run_ended(summary: Dictionary) -> void:
	print("AUTOPLAY DONE " + JSON.stringify(summary.get("result", summary), "", true))
	Engine.time_scale = 1.0
	if _shot_dir != "":
		await _screenshot("3-summary")
	if OS.has_feature("web"):
		return
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(WINDOWED_QUIT_DELAY).timeout
	get_tree().quit(0)


## Command-line user args (--key or --key=value) or, on the web, the page's query string.
func _options() -> Dictionary:
	var out := {}
	var pairs: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		pairs.append(arg.trim_prefix("--"))
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search", true)
		if query is String:
			pairs.append_array(str(query).trim_prefix("?").split("&", false))
	for pair in pairs:
		var parts := pair.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else ""
	return out
