extends SceneTree
## HF-M2-05: the simulator's gate on the pacing bands (HF-M2-01), headless, in CI.
##
##   godot --headless --path games/holdfast -s res://tools/bands.gd -- --budget=480 --out=<folder>
##
## Plays the first-time climbs of levels 1 to 5 for every pillar with both bots, checks every
## figure against content/pacing-bands.json and writes bands.md and bands.json to --out.
## Exits 1 when a band is missed (and not a pinned known miss), when a known miss gets
## worse or comes back inside its band, or when the sweep takes longer than --budget seconds.
## With --pins it prints the figures that miss, ready to paste into `known_misses`.


func _initialize() -> void:
	var args := _args()
	var budget := float(args.get("budget", "480"))
	var out_dir := str(args.get("out", "user://reports"))
	var bands := HoldfastBands.load_bands()
	if bands.is_empty() or HoldfastContent.base().is_empty():
		printerr("bands: pacing-bands.json or the content pack is invalid")
		quit(1)
		return

	var failures := HoldfastBands.scope_problems(bands)
	if not failures.is_empty():
		for failure in failures:
			printerr("bands FAILED: " + failure)
		quit(1)
		return
	var started := Time.get_ticks_usec()
	var cells := HoldfastBands.measure(bands)
	var wall := (Time.get_ticks_usec() - started) / 1_000_000.0
	var judged := HoldfastBands.evaluate(HoldfastBands.figures(bands, cells), bands["known_misses"])
	failures = HoldfastBands.failures(judged)
	if wall > budget:
		failures.append("took %.0f s of wall-clock time, budget %.0f s" % [wall, budget])

	var text := HoldfastBands.report(bands, judged, cells) + "\nSweep time: %.0f s (budget %.0f s)\n" % [wall, budget]
	print(text)
	_write(out_dir, "bands.json", JSON.stringify(judged, "  ", false))
	_write(out_dir, "bands.md", text)
	if args.has("pins"):
		for key in judged:
			if judged[key]["state"] == "MISSED":
				print("\"%s\": %s," % [key, snappedf(float(judged[key]["value"]), 0.0001)])
	for failure in failures:
		printerr("bands FAILED: " + failure)
	quit(1 if not failures.is_empty() else 0)


func _write(dir: String, file: String, text: String) -> void:
	var abs_dir := dir
	if dir.is_relative_path() and not dir.contains("://"):
		# Relative paths are relative to the project folder, as on the command line.
		abs_dir = ProjectSettings.globalize_path("res://").path_join(dir).simplify_path()
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var handle := FileAccess.open(abs_dir.path_join(file), FileAccess.WRITE)
	if handle == null:
		printerr("bands: cannot write %s (%s)" % [abs_dir.path_join(file), error_string(FileAccess.get_open_error())])
		return
	handle.store_string(text)
	print("wrote " + abs_dir.path_join(file))


func _args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var eq := arg.find("=")
			out[arg.substr(2, eq - 2) if eq > 0 else arg.substr(2)] = arg.substr(eq + 1) if eq > 0 else ""
	return out
