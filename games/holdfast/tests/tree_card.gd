class_name TreeCard
extends RefCounted
## Test set-up for the skill tree's detail card: a node is bought the way a player buys it, by
## pressing it to open its card and then pressing Buy there.


## Opens the card of `id` on the Skill tree `page` and presses Buy.
static func buy(page: Control, id: String) -> void:
	page._node_buttons[id].pressed.emit()
	page._card_buy.pressed.emit()


## True when the rules let the player buy `id`: its card, opened, has a Buy that can be pressed.
static func can_buy(page: Control, id: String) -> bool:
	page.open_card(id)
	return page._card_buy.visible and not page._card_buy.disabled


## All the text on the open card, one string.
static func text(page: Control) -> String:
	return " | ".join(_texts(page._card_panel))


static func _texts(node: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for child in node.get_children():
		if (child is Label or child is Button) and child.visible:
			out.append(child.text)
		out.append_array(_texts(child))
	return out
