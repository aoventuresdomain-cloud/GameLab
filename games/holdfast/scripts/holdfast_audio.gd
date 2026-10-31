class_name HoldfastAudio
extends Node
## Sound effects for a run: the keep taking a hit, gold from a defeated enemy, a level-up and a
## boss arriving. It watches the run's rules (it never changes them) and plays on the master
## bus, whose loudness is the player's volume setting; at zero volume nothing plays.
## Sources are listed in assets/CREDITS.md.

## A sound played, by name ("hit", "gold", "level" or "boss").
signal played(sound: String)

@export var source_path: NodePath
@export var settings_path: NodePath

const SOUNDS := {
	"hit": "res://assets/audio/hit.wav",
	"gold": "res://assets/audio/gold.wav",
	"level": "res://assets/audio/level.wav",
	"boss": "res://assets/audio/boss.wav",
}
## Gold comes with every defeated enemy, so it sits quieter under the rest.
const VOLUME_DB := {"gold": -8.0}
## The shortest run time between two plays of the same sound, so a crowd does not turn to noise.
const GAP_SECONDS := 0.08

var _players := {}
var _last_at := {}
var _seen := {}
var _source: Node
var _settings: Node


func _ready() -> void:
	_source = get_node_or_null(source_path)
	_settings = get_node_or_null(settings_path)
	for sound in SOUNDS:
		var path: String = SOUNDS[sound]
		if not ResourceLoader.exists(path):
			continue
		var player := AudioStreamPlayer.new()
		player.stream = load(path)
		player.volume_db = float(VOLUME_DB.get(sound, 0.0))
		add_child(player)
		_players[sound] = player
	if _source is HoldfastRunSource:
		_source.run_started.connect(forget_run)


func _process(_delta: float) -> void:
	if _source is HoldfastRunSource and _source.is_running() and _source.get_rules() != null:
		poll(_source.get_rules())


## A new run starts counting from nothing.
func forget_run() -> void:
	_seen.clear()
	_last_at.clear()


## Plays what changed in the run since the last look, and returns the names played. The first look
## of a run only takes the starting figures.
func poll(rules: HoldfastRules) -> Array[String]:
	var now := {
		"kills": rules.kills,
		"keep": rules.keep_health,
		"levels": _levels(rules),
		"bosses": rules.enemies.filter(func(enemy: HoldfastRules.Enemy) -> bool: return enemy.tier == "boss").size(),
	}
	var out: Array[String] = []
	if not _seen.is_empty():
		if now["keep"] < _seen["keep"]:
			out.append("hit")
		if now["kills"] > _seen["kills"]:
			out.append("gold")
		if now["levels"] > _seen["levels"]:
			out.append("level")
		if now["bosses"] > _seen["bosses"]:
			out.append("boss")
	_seen = now
	var played_now: Array[String] = []
	for sound in out:
		if rules.time - float(_last_at.get(sound, -GAP_SECONDS)) >= GAP_SECONDS and play(sound):
			_last_at[sound] = rules.time
			played_now.append(sound)
	return played_now


## Plays one sound unless the volume is off. False when nothing played.
func play(sound: String) -> bool:
	if _settings != null and _settings.get_volume() <= 0.0:
		return false
	if not _players.has(sound):
		return false
	_players[sound].play()
	played.emit(sound)
	return true


## The Hero's staff level and every Recruit's level added up: it only rises, and each rise is a level-up.
func _levels(rules: HoldfastRules) -> int:
	var total := rules.staff_level
	for recruit in rules.recruits:
		total += recruit.level
	return total
