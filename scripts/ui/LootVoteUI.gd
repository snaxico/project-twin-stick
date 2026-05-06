extends Control

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/MarginContainer/Layout/Title
@onready var detail_label: Label = $Panel/MarginContainer/Layout/Detail
@onready var timer_label: Label = $Panel/MarginContainer/Layout/TimerLabel
@onready var timer_bar: ProgressBar = $Panel/MarginContainer/Layout/TimerBar
@onready var vote_rows: VBoxContainer = $Panel/MarginContainer/Layout/VoteRows
@onready var result_label: Label = $Panel/MarginContainer/Layout/ResultLabel

func setup_for_item(item: Dictionary, player_count: int) -> void:
	title_label.text = "Loot Vote: %s" % str(item.get("name", "Loot"))
	detail_label.text = "%s\nTake: Interact button | Scrap: Scrap button" % str(item.get("description", "Choose to take or scrap the drop."))
	result_label.text = ""
	result_label.visible = false
	_rebuild_vote_rows(player_count)

func update_vote_state(votes: Dictionary, player_count: int, time_remaining: float, duration: float) -> void:
	if timer_label != null:
		timer_label.text = "Time Remaining: %.1fs" % max(time_remaining, 0.0)
	if timer_bar != null:
		timer_bar.max_value = max(duration, 0.01)
		timer_bar.value = clamp(time_remaining, 0.0, duration)
	for index in range(min(player_count, vote_rows.get_child_count())):
		var row_label := vote_rows.get_child(index) as Label
		if row_label == null:
			continue
		var vote_value := str(votes.get(index, "waiting"))
		var vote_text := "Waiting..."
		if vote_value == "take":
			vote_text = "Take"
		elif vote_value == "scrap":
			vote_text = "Scrap"
		row_label.text = "P%d: %s" % [index + 1, vote_text]

func show_result(summary_text: String) -> void:
	if result_label == null:
		return
	result_label.visible = true
	result_label.text = summary_text

func _rebuild_vote_rows(player_count: int) -> void:
	for child in vote_rows.get_children():
		vote_rows.remove_child(child)
		child.queue_free()
	for index in range(player_count):
		var row_label := Label.new()
		row_label.text = "P%d: Waiting..." % (index + 1)
		vote_rows.add_child(row_label)
