extends Control

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/MarginContainer/Layout/Title
@onready var detail_label: Label = $Panel/MarginContainer/Layout/Detail
@onready var status_label: Label = $Panel/MarginContainer/Layout/Status
@onready var slot_1_label: Label = $Panel/MarginContainer/Layout/SlotRow1
@onready var slot_2_label: Label = $Panel/MarginContainer/Layout/SlotRow2
@onready var hint_label: Label = $Panel/MarginContainer/Layout/Hint

func setup_for_replacement(player_index: int, entry: Dictionary, slot_type: String, slot_rows: Array) -> void:
	title_label.text = "P%d Replace %s" % [player_index + 1, "Secondary" if slot_type == "secondary" else "Primary"]
	detail_label.text = "New weapon: %s\n%s" % [str(entry.get("name", "Weapon")), str(entry.get("description", ""))]
	status_label.text = "Choose which slot to replace."
	_set_slot_label(slot_1_label, slot_rows, 0, true)
	_set_slot_label(slot_2_label, slot_rows, 1, false)
	hint_label.text = "Move left/right to choose. Confirm with Take / Interact. Cancel with Scrap."

func set_selected_slot(slot_rows: Array, selected_index: int) -> void:
	_set_slot_label(slot_1_label, slot_rows, 0, selected_index == 0)
	_set_slot_label(slot_2_label, slot_rows, 1, selected_index == 1)

func set_status_text(text: String) -> void:
	status_label.text = text

func _set_slot_label(target: Label, slot_rows: Array, slot_index: int, selected: bool) -> void:
	if target == null:
		return
	var row: Dictionary = slot_rows[slot_index] if slot_index < slot_rows.size() and slot_rows[slot_index] is Dictionary else {}
	var prefix: String = "> " if selected else "  "
	var name_text: String = str(row.get("name", "---"))
	var level_value: int = int(row.get("level", 0))
	var level_text: String = "" if level_value <= 0 else " Lv%d" % level_value
	target.text = "%sSlot %d: %s%s" % [prefix, slot_index + 1, name_text, level_text]
