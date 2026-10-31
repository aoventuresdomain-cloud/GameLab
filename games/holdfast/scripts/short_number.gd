class_name ShortNumber
extends RefCounted
## Short number text for the screens: 999, 1.2K, 3.4M, 5B, 6T. One decimal, cut rather
## than rounded, so a figure never reads higher than it is (999,999 is 999.9K, never
## 1000K) and ".0" is dropped (1,000 is 1K).

const UNITS := ["", "K", "M", "B", "T"]


static func of(value: int) -> String:
	var size := absi(value)
	var unit := 0
	var divisor := 1
	while size / divisor >= 1000 and unit < UNITS.size() - 1:
		divisor *= 1000
		unit += 1
	var sign_text := "-" if value < 0 else ""
	if unit == 0:
		return sign_text + str(size)
	# Tenths of the unit, in whole numbers, so nothing passes through a float.
	var tenths := size / (divisor / 10)
	var tenth := tenths % 10
	return "%s%d%s%s" % [sign_text, tenths / 10, "" if tenth == 0 else ".%d" % tenth, UNITS[unit]]


## The whole figure with thousands commas, for a price the player pays exactly: 1234567 -> "1,234,567".
static func exact(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
