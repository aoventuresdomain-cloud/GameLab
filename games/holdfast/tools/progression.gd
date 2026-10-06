extends SceneTree
## HF-M1-02: ten simulated hours of Holdfast progression, headless, in CI.
##
##   godot --headless --path games/holdfast -s res://tools/progression.gd -- \
##     --hours=10 --seed=1 --budget=60 --out=<folder>
##
## Writes progression.json and progression.md to --out. Exits 1 when the first
## run takes longer than --budget wall-clock seconds, or when a second run with
## the same seed gives a different report hash.


func _initialize() -> void:
	var args := _args()
	var hours := float(args.get("hours", "10"))
	var run_seed := int(args.get("seed", "1"))
	var budget := float(args.get("budget", "60"))
	var out_dir := str(args.get("out", "user://reports"))

	if HoldfastContent.base().is_empty():
		printerr("progression: content pack is invalid")
		quit(1)
		return

	var started := Time.get_ticks_usec()
	var report := HoldfastProgression.play(run_seed, hours)
	var wall := (Time.get_ticks_usec() - started) / 1_000_000.0
	var again := HoldfastProgression.play(run_seed, hours)
	var deterministic: bool = again["hash"] == report["hash"]

	var failures: PackedStringArray = []
	if wall > budget:
		failures.append("took %.2f s of wall-clock time, budget %.0f s" % [wall, budget])
	if not deterministic:
		failures.append("determinism: same seed gave report hashes %s and %s" % [report["hash"], again["hash"]])

	var summary := _summary(report, wall, budget, deterministic)
	print(summary)
	var full := report.duplicate()
	full["wall_seconds"] = wall
	full["budget_seconds"] = budget
	full["deterministic"] = deterministic
	_write(out_dir, "progression.json", JSON.stringify(full, "  ", false))
	_write(out_dir, "progression.md", summary)

	for failure in failures:
		printerr("progression FAILED: " + failure)
	quit(1 if not failures.is_empty() else 0)


func _summary(report: Dictionary, wall: float, budget: float, deterministic: bool) -> String:
	var lines: PackedStringArray = []
	lines.append("# Holdfast progression: %s simulated hours" % report["sim_hours"])
	lines.append("")
	lines.append("- Wall-clock time: **%.2f s** (budget %.0f s)" % [wall, budget])
	lines.append("- Determinism (second run, same seed): **%s** (`%s`)" % ["pass" if deterministic else "FAIL", str(report["hash"]).left(16)])
	lines.append("- Runs played: %d (%s)" % [report["runs_played"], JSON.stringify(report["outcomes"])])
	lines.append("- Upgrades owned: %d of %d; gold in bank: %d" % [report["upgrades_owned"], report["upgrades_total"], report["bank"]])
	var gold: Array = report["gold_per_run"]
	if not gold.is_empty():
		lines.append("- Gold per run: first %d, last %d, best %d" % [gold[0], gold[-1], gold.max()])
	lines.append("")
	lines.append("| Unlock | Cost | At (sim time) | After run |")
	lines.append("|---|---:|---:|---:|")
	for unlock in report["unlocks"]:
		var at := float(unlock["at_seconds"])
		lines.append("| %s | %d | %dm %02ds | %d |" % [unlock["id"], unlock["cost"], int(at) / 60, int(at) % 60, unlock["after_run"]])
	return "\n".join(lines) + "\n"


func _write(dir: String, file: String, text: String) -> void:
	var abs_dir := dir if dir.begins_with("user://") or dir.begins_with("res://") else ProjectSettings.globalize_path("res://").path_join(dir).simplify_path()
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var handle := FileAccess.open(abs_dir.path_join(file), FileAccess.WRITE)
	if handle == null:
		printerr("progression: cannot write %s (%s)" % [abs_dir.path_join(file), error_string(FileAccess.get_open_error())])
		return
	handle.store_string(text)
	print("wrote " + abs_dir.path_join(file))


func _args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return out
