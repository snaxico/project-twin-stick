extends CanvasLayer
## Dev performance overlay for the real-room go/no-go gate. Autoload, observational only —
## reads Performance monitors + group counts, touches no game logic.
## Toggle with F3. Hidden by default. Safe to leave committed as dev tooling.

const UPDATE_HZ := 10.0
const MIN_WINDOW_SECONDS := 3.0   # rolling window for the min-FPS spike readout

var _label: Label
var _accum := 0.0
var _fps_samples: Array = []      # [ [time, fps], ... ] over the last MIN_WINDOW_SECONDS

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep reading even while the game is paused
	visible = false

	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55)
	panel.position = Vector2(8, 8)
	panel.size = Vector2(340, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_label = Label.new()
	_label.position = Vector2(16, 14)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F3:
		visible = not visible

func _process(delta: float) -> void:
	if not visible:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var fps := Engine.get_frames_per_second()
	_fps_samples.append([now, fps])
	while _fps_samples.size() > 0 and now - float(_fps_samples[0][0]) > MIN_WINDOW_SECONDS:
		_fps_samples.pop_front()

	_accum += delta
	if _accum < 1.0 / UPDATE_HZ:
		return
	_accum = 0.0

	var min_fps := fps
	for sample in _fps_samples:
		min_fps = minf(min_fps, float(sample[1]))

	var tree := get_tree()
	var enemies := tree.get_nodes_in_group("aim_target").size() if tree != null else 0
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var vsync_on := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED

	_label.text = "FPS  %4.0f   (min %.0f / %ds)\nframe %.1f ms  [proc %.1f | phys %.1f]\ndraw calls %d\nenemies (aim_target) %d\nnodes %d\nvsync %s" % [
		fps, min_fps, int(MIN_WINDOW_SECONDS),
		(1000.0 / maxf(fps, 1.0)), proc_ms, phys_ms,
		int(draws), enemies, int(nodes),
		"ON" if vsync_on else "OFF",
	]
