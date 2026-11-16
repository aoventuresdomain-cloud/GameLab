class_name UiTokens
extends RefCounted
## The look's colours. They live in one place, the project theme (assets/ui/theme.tres, type
## "Tokens"); a screen asks for one by name instead of writing a colour of its own. Placeholder look
## on placeholder art: the final style guide (HF-M2-08) decides the art later.

const TYPE := "Tokens"


static func colour(token: StringName, alpha := 1.0) -> Color:
	var theme := ThemeDB.get_project_theme()
	if theme == null or not theme.has_color(token, TYPE):
		push_error("UiTokens: no colour token '%s' in the theme" % token)
		return Color(1, 0, 1)
	var found := theme.get_color(token, TYPE)
	return found if alpha == 1.0 else Color(found, alpha)


## White at a given opacity: what a `modulate` takes to dim or restore a control.
static func fade(alpha: float) -> Color:
	return Color(1, 1, 1, alpha)


## A colour a content pack names as text (packs are data: a Recruit class's colour).
static func pack_colour(text: String) -> Color:
	return Color(text)
