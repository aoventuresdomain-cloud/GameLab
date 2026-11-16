class_name HubHeader
extends HBoxContainer
## The top row every hub screen shares (back chevron, title, then gold and stars in the top-right
## corner). Its main controls take the screen's unique names, so a screen reaches them as
## %BackButton, %Title, %GoldValue and %StarsValue like any control of its own.


func _ready() -> void:
	if owner == null:
		return
	for path in ["BackButton", "Title", "GoldChip/Row/GoldValue", "StarsChip/Row/StarsValue"]:
		var node := get_node(path)
		node.owner = owner
		node.unique_name_in_owner = true
