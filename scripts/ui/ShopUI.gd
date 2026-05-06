extends Control

@onready var title_label: Label = $Panel/MarginContainer/Layout/Title
@onready var wallet_label: Label = $Panel/MarginContainer/Layout/Wallet
@onready var status_label: Label = $Panel/MarginContainer/Layout/Status
@onready var offer_1_label: Label = $Panel/MarginContainer/Layout/Offer1
@onready var offer_2_label: Label = $Panel/MarginContainer/Layout/Offer2
@onready var offer_3_label: Label = $Panel/MarginContainer/Layout/Offer3
@onready var ready_label: Label = $Panel/MarginContainer/Layout/ReadyLabel
@onready var hint_label: Label = $Panel/MarginContainer/Layout/Hint

func setup_for_player(player_index: int, offers: Array, gold_value: int, selected_index: int, ready_players: Dictionary, ready_deadline_text: String) -> void:
	title_label.text = "P%d Shop" % (player_index + 1)
	hint_label.text = "Move left/right. Confirm to buy. Select Ready when done. Cancel closes the panel."
	update_state(player_index, offers, gold_value, selected_index, ready_players, ready_deadline_text, "")

func update_state(_player_index: int, offers: Array, gold_value: int, selected_index: int, ready_players: Dictionary, ready_deadline_text: String, status_text: String) -> void:
	wallet_label.text = "Wallet: %d Gold" % gold_value
	status_label.text = status_text
	_set_offer_label(offer_1_label, offers, 0, selected_index == 0)
	_set_offer_label(offer_2_label, offers, 1, selected_index == 1)
	_set_offer_label(offer_3_label, offers, 2, selected_index == 2)
	var ready_prefix: String = "> " if selected_index == 3 else "  "
	var ready_texts: Array = []
	for ready_key in ready_players.keys():
		if bool(ready_players[ready_key]):
			ready_texts.append("P%d Ready" % (int(ready_key) + 1))
	ready_label.text = "%sReady / Leave Shop%s" % [ready_prefix, "" if ready_deadline_text.is_empty() else "  %s" % ready_deadline_text]
	if not ready_texts.is_empty():
		ready_label.text += "\n" + " | ".join(ready_texts)

func _set_offer_label(target: Label, offers: Array, offer_index: int, selected: bool) -> void:
	var prefix: String = "> " if selected else "  "
	if offer_index >= offers.size() or not (offers[offer_index] is Dictionary):
		target.text = "%s---" % prefix
		return
	var offer: Dictionary = offers[offer_index]
	target.text = "%s%s\n%s\nCost: %d Gold" % [
		prefix,
		str(offer.get("name", "Offer")),
		str(offer.get("description", "")),
		int(offer.get("cost", 0)),
	]
