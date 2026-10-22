extends Node
## Plays one full run with the bot Hero and reports it, for CI smoke tests of the
## exported builds. Off unless asked for:
##   desktop:  Holdfast.exe --headless -- --autoplay [--seed=N] [--hero=<path id>]
##   (windowed, the game waits a few seconds after the run before quitting)
##   web:      index.html?autoplay=1[&seed=N][&hero=<path id>]
## Prints "AUTOPLAY DONE {result json}" when the run ends; the desktop build then quits.

const SPEED := 8.0
## Seconds a windowed desktop run stays open after the run ends, so Steam can
## record the achievement and show its overlay before the game quits.
const WINDOWED_QUIT_DELAY := 4.0

@export var flow_path: NodePath
@export var source_path: NodePath


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
	# Start through the run flow, as the Play button does. Deferred, so the start
	# screen has built its pillar buttons before one is picked.
	call_deferred("_begin", str(options.get("hero", "")))


func _begin(hero: String) -> void:
	var flow := get_node(flow_path)
	if hero != "":
		flow.start_screen.select_pillar(hero)
	flow._start_run()


func _on_run_ended(summary: Dictionary) -> void:
	print("AUTOPLAY DONE " + JSON.stringify(summary.get("result", summary), "", true))
	Engine.time_scale = 1.0
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
