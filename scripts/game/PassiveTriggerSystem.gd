class_name PassiveTriggerSystem
extends RefCounted

const VALID_HOOKS: Array = ["on_fire", "on_hit", "on_kill", "on_explosion"]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _state_by_key: Dictionary = {}

func _init() -> void:
	_rng.randomize()

func clear_state() -> void:
	_state_by_key.clear()

func collect_actions(hook: String, context: Dictionary) -> Array:
	if not VALID_HOOKS.has(hook):
		return []
	var trigger_passives: Variant = context.get("trigger_passives", [])
	if not (trigger_passives is Array):
		return []

	var owner: Variant = context.get("owner", null)
	var owner_id: String = str(owner.get_instance_id()) if owner != null and is_instance_valid(owner) else "global"
	var now: float = Time.get_ticks_msec() / 1000.0
	var actions: Array = []

	for trigger_entry in trigger_passives:
		if not (trigger_entry is Dictionary):
			continue
		var trigger_data: Dictionary = trigger_entry as Dictionary
		if str(trigger_data.get("hook", "")) != hook:
			continue

		var trigger_id: String = str(trigger_data.get("trigger_id", trigger_data.get("passive_id", "trigger")))
		var state_key: String = "%s:%s:%s" % [owner_id, hook, trigger_id]
		var state: Dictionary = (_state_by_key.get(state_key, {
			"event_count": 0,
			"last_proc_at": -999999.0,
		}) as Dictionary).duplicate(true)
		state["event_count"] = int(state.get("event_count", 0)) + 1

		var trigger_every_n_events: int = max(int(trigger_data.get("trigger_every_n_events", 1)), 1)
		if int(state["event_count"]) % trigger_every_n_events != 0:
			_state_by_key[state_key] = state
			continue

		var internal_cooldown_seconds: float = max(float(trigger_data.get("internal_cooldown_seconds", 0.0)), 0.0)
		if now < float(state.get("last_proc_at", -999999.0)) + internal_cooldown_seconds:
			_state_by_key[state_key] = state
			continue

		var proc_chance: float = clampf(float(trigger_data.get("proc_chance", 1.0)), 0.0, 1.0)
		if proc_chance < 1.0 and _rng.randf() > proc_chance:
			_state_by_key[state_key] = state
			continue

		state["last_proc_at"] = now
		_state_by_key[state_key] = state

		var action: Dictionary = (trigger_data.get("action", {}) as Dictionary).duplicate(true)
		action["passive_id"] = str(trigger_data.get("passive_id", ""))
		action["passive_name"] = str(trigger_data.get("passive_name", "Passive"))
		action["max_targets"] = max(int(trigger_data.get("max_targets", action.get("max_targets", 1))), 1)
		actions.append(action)

	return actions
