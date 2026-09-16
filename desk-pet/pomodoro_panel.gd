extends PanelContainer

## 番茄钟面板：专注 / 短休息 / 长休息三段循环，时长和轮数都能自由设置。
## 设置与统计存在 userdata/pomodoro.json，本地文件，不进版本控制。

signal closed
signal phase_finished(finished_mode: String, next_mode: String)

const SETTINGS_PATH := "res://userdata/pomodoro.json"
const MODE_FOCUS := "focus"
const MODE_SHORT := "short"
const MODE_LONG := "long"
const MODE_LABELS := {
	MODE_FOCUS: "专注中",
	MODE_SHORT: "短休息",
	MODE_LONG: "长休息",
}

const PINK := Color("f472b6")
const PINK_SOFT := Color("f9a8d4")
const PINK_PALE := Color("fff3f8")
const INK := Color("4a3b4f")
const MUTED := Color("9c8fa6")

const DEFAULT_SETTINGS := {
	"focus_minutes": 25,
	"short_break_minutes": 5,
	"long_break_minutes": 15,
	"rounds_before_long": 4,
	"auto_start_next": true,
}

var _settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var _stats: Dictionary = {}
var _mode := MODE_FOCUS
var _remaining := 0.0
var _running := false
var _round_index := 0

var _time_label: Label
var _mode_label: Label
var _progress: ProgressBar
var _start_button: Button
var _stats_label: Label
var _auto_check: CheckBox
var _spins: Dictionary = {}


func _ready() -> void:
	z_index = 10
	custom_minimum_size = Vector2(560.0, 620.0)
	add_theme_stylebox_override("panel", _panel_box())
	_build()
	_load()
	_reset_phase(MODE_FOCUS)
	hide()


# ---------------------------------------------------------------- 对外接口

func open() -> void:
	_load()
	_refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func is_running() -> bool:
	return _running


func current_mode() -> String:
	return _mode


func remaining_seconds() -> float:
	return _remaining


func completed_today() -> int:
	return int(_stats.get(_today(), 0))


## 自检与外部调用都走这里：开始 / 暂停。
func start_pause() -> void:
	_running = not _running
	_refresh()


## 时间推进：正式运行时由 _process 调用，自检时可以直接手动喂秒数。
func advance(seconds: float) -> void:
	if not _running:
		return
	_remaining -= seconds
	if _remaining <= 0.0:
		_finish_phase()
	else:
		_refresh()


func _process(delta: float) -> void:
	advance(delta)


func reset_phase() -> void:
	_reset_phase(_mode)
	_running = false
	_refresh()


func skip_phase() -> void:
	_finish_phase()


# ---------------------------------------------------------------- 相位与统计

func _phase_seconds(mode: String) -> float:
	match mode:
		MODE_SHORT:
			return maxf(1.0, float(_settings["short_break_minutes"]) * 60.0)
		MODE_LONG:
			return maxf(1.0, float(_settings["long_break_minutes"]) * 60.0)
		_:
			return maxf(1.0, float(_settings["focus_minutes"]) * 60.0)


func _reset_phase(mode: String) -> void:
	_mode = mode
	_remaining = _phase_seconds(mode)
	_progress.max_value = _remaining


func _finish_phase() -> void:
	var finished := _mode
	var next := MODE_FOCUS
	if finished == MODE_FOCUS:
		_round_index += 1
		var rounds := maxi(1, int(_settings["rounds_before_long"]))
		next = MODE_LONG if _round_index % rounds == 0 else MODE_SHORT
		var today := _today()
		_stats[today] = int(_stats.get(today, 0)) + 1
		_save()
	_refresh()
	phase_finished.emit(finished, next)
	_reset_phase(next)
	_running = bool(_settings["auto_start_next"])
	_refresh()


func _today() -> String:
	return Time.get_date_string_from_system()


# ---------------------------------------------------------------- 样式

func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PINK_PALE
	box.set_border_width_all(3)
	box.border_color = PINK
	box.set_corner_radius_all(20)
	box.set_content_margin_all(14.0)
	return box


func _box(bg: Color, border: Color, radius: int, border_width: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(border_width)
	box.border_color = border
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(10.0)
	return box


func _style_button(button: Button, compact: bool = false) -> void:
	var radius := 12 if not compact else 10
	var padding := 6.0 if compact else 10.0
	var normal := _box(Color("ffffff"), PINK_SOFT, radius)
	normal.set_content_margin_all(padding)
	button.add_theme_stylebox_override("normal", normal)
	var hover := _box(PINK_SOFT, PINK, radius)
	hover.set_content_margin_all(padding)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := _box(PINK, PINK, radius)
	pressed.set_content_margin_all(padding)
	button.add_theme_stylebox_override("pressed", pressed)
	var focus := _box(Color("ffffff"), PINK, radius)
	focus.set_content_margin_all(padding)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	button.add_theme_font_size_override("font_size", 16 if compact else 18)


# ---------------------------------------------------------------- 搭界面

func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	root.add_child(header)

	var title := Label.new()
	title.text = "番茄钟"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", PINK)
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "✕"
	_style_button(close_button, true)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_mode_label = Label.new()
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.add_theme_color_override("font_color", MUTED)
	_mode_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_mode_label)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_color_override("font_color", PINK)
	_time_label.add_theme_font_size_override("font_size", 56)
	root.add_child(_time_label)

	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0.0, 16.0)
	_progress.add_theme_stylebox_override("background", _box(Color("ffffff"), PINK_SOFT, 8))
	_progress.add_theme_stylebox_override("fill", _box(PINK, PINK, 8))
	root.add_child(_progress)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)

	_start_button = Button.new()
	_start_button.text = "开始"
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_start_button)
	_start_button.pressed.connect(start_pause)
	buttons.add_child(_start_button)

	var reset_button := Button.new()
	reset_button.text = "重置"
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(reset_button)
	reset_button.pressed.connect(reset_phase)
	buttons.add_child(reset_button)

	var skip_button := Button.new()
	skip_button.text = "跳过"
	skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(skip_button)
	skip_button.pressed.connect(skip_phase)
	buttons.add_child(skip_button)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_color_override("font_color", INK)
	_stats_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_stats_label)

	root.add_child(HSeparator.new())

	var settings_title := Label.new()
	settings_title.text = "时长设置（分钟）"
	settings_title.add_theme_color_override("font_color", PINK)
	settings_title.add_theme_font_size_override("font_size", 18)
	root.add_child(settings_title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	_add_spin(grid, "focus_minutes", "专注")
	_add_spin(grid, "short_break_minutes", "短休息")
	_add_spin(grid, "long_break_minutes", "长休息")
	_add_spin(grid, "rounds_before_long", "长休息前的轮数", 1, 12, 1)

	_auto_check = CheckBox.new()
	_auto_check.text = "自动开始下一段"
	_auto_check.add_theme_color_override("font_color", INK)
	_auto_check.add_theme_color_override("font_hover_color", PINK)
	_auto_check.add_theme_font_size_override("font_size", 16)
	_auto_check.toggled.connect(_on_auto_toggled)
	root.add_child(_auto_check)


func _add_spin(grid: GridContainer, key: String, label_text: String, minimum: int = 1, maximum: int = 180, step: int = 1) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", 16)
	grid.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = int(_settings.get(key, minimum))
	spin.custom_minimum_size = Vector2(140.0, 40.0)
	spin.add_theme_font_size_override("font_size", 16)
	spin.value_changed.connect(func(value: float) -> void: _on_setting_changed(key, int(value)))
	grid.add_child(spin)
	_spins[key] = spin


# ---------------------------------------------------------------- 设置读写

func _on_setting_changed(key: String, value: int) -> void:
	_settings[key] = value
	_save()
	if not _running:
		_reset_phase(_mode)
	_refresh()


func _on_auto_toggled(pressed: bool) -> void:
	_settings["auto_start_next"] = pressed
	_save()


func _load() -> void:
	var absolute := ProjectSettings.globalize_path(SETTINGS_PATH)
	if FileAccess.file_exists(absolute):
		var file := FileAccess.open(absolute, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				var data := parsed as Dictionary
				var saved: Variant = data.get("settings")
				if typeof(saved) == TYPE_DICTIONARY:
					for key in (saved as Dictionary):
						_settings[key] = (saved as Dictionary)[key]
				var stats: Variant = data.get("stats")
				if typeof(stats) == TYPE_DICTIONARY:
					_stats = stats as Dictionary
	for key in DEFAULT_SETTINGS:
		if not _settings.has(key):
			_settings[key] = DEFAULT_SETTINGS[key]
	for key in _spins:
		(_spins[key] as SpinBox).set_value_no_signal(float(_settings[key]))
	if _auto_check != null:
		_auto_check.set_pressed_no_signal(bool(_settings["auto_start_next"]))


func _save() -> void:
	var absolute := ProjectSettings.globalize_path(SETTINGS_PATH)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_warning("番茄钟设置保存失败：%s" % absolute)
		return
	file.store_string(JSON.stringify({"settings": _settings, "stats": _stats}, "  "))
	file.close()


# ---------------------------------------------------------------- 刷新显示

func _refresh() -> void:
	if _time_label == null:
		return
	var total := _phase_seconds(_mode)
	var remaining := maxf(0.0, _remaining)
	var minutes := int(remaining) / 60
	var seconds := int(remaining) % 60
	_time_label.text = "%02d:%02d" % [minutes, seconds]
	_mode_label.text = "%s · 第 %d 个番茄后长休息" % [MODE_LABELS.get(_mode, _mode), int(_settings["rounds_before_long"])]
	_progress.max_value = total
	_progress.value = total - remaining
	_start_button.text = "暂停" if _running else "继续" if remaining < total else "开始"
	_stats_label.text = "今天完成 %d 个番茄" % completed_today()
