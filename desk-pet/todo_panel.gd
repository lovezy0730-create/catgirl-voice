extends PanelContainer

## 带日历的待办清单面板。UI 全部在代码里搭，样式跟桌宠统一成粉色圆角风。
## 数据存在 userdata/todos.json，本地文件，不进版本控制。

signal closed

const TODO_PATH := "res://userdata/todos.json"
const MEMO_PATH := "res://userdata/todo.md"
const WEEKDAYS: PackedStringArray = ["一", "二", "三", "四", "五", "六", "日"]

const PINK := Color("f472b6")
const PINK_SOFT := Color("f9a8d4")
const PINK_PALE := Color("fff3f8")
const PINK_BORDER := Color("f472b6")
const INK := Color("4a3b4f")
const MUTED := Color("9c8fa6")

var _todos: Dictionary = {}
var _year: int
var _month: int
var _selected: String

var _month_label: Label
var _calendar: GridContainer
var _selected_label: Label
var _list_box: VBoxContainer
var _input: LineEdit


func _ready() -> void:
	z_index = 10
	custom_minimum_size = Vector2(620.0, 780.0)
	add_theme_stylebox_override("panel", _panel_box())
	_build()
	_load()
	_go_today()
	hide()


# ---------------------------------------------------------------- 对外接口

func open() -> void:
	_load()
	_go_today()
	show()


func close() -> void:
	hide()
	closed.emit()


func todo_count(date: String) -> int:
	return (_todos.get(date, []) as Array).size()


func pending_count(date: String) -> int:
	var pending := 0
	for item in _todos.get(date, []) as Array:
		if not bool((item as Dictionary).get("done", false)):
			pending += 1
	return pending


## 给自检脚本用：直接加一条待办。
func add_todo(date: String, text: String) -> void:
	var list: Array = _todos.get(date, [])
	list.append({"text": text, "done": false})
	_todos[date] = list
	_save()
	_render_calendar()
	_render_list()


## 给自检脚本用：切换第 index 条的完成状态。
func toggle_todo(date: String, index: int) -> void:
	var list: Array = _todos.get(date, [])
	if index < 0 or index >= list.size():
		return
	var item: Dictionary = list[index]
	item["done"] = not bool(item.get("done", false))
	_save()
	_render_calendar()
	_render_list()


func remove_todo(date: String, index: int) -> void:
	var list: Array = _todos.get(date, [])
	if index < 0 or index >= list.size():
		return
	list.remove_at(index)
	_todos[date] = list
	_save()
	_render_calendar()
	_render_list()


# ---------------------------------------------------------------- 样式

func _box(bg: Color, border: Color, radius: int, border_width: int = 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(border_width)
	box.border_color = border
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(10.0)
	return box


func _panel_box() -> StyleBoxFlat:
	var box := _box(PINK_PALE, PINK_BORDER, 20)
	box.set_content_margin_all(12.0)
	return box


func _style_button(button: Button, compact: bool = false) -> void:
	var radius := 12 if not compact else 10
	button.add_theme_stylebox_override("normal", _box(Color("ffffff"), PINK_BORDER, radius, 2))
	button.add_theme_stylebox_override("hover", _box(PINK_SOFT, PINK_BORDER, radius, 2))
	button.add_theme_stylebox_override("pressed", _box(PINK, PINK_BORDER, radius, 2))
	button.add_theme_stylebox_override("focus", _box(Color("ffffff"), PINK, radius, 2))
	var normal := _box(Color("ffffff"), PINK_BORDER, radius, 2)
	normal.set_content_margin_all(6.0 if compact else 10.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	button.add_theme_font_size_override("font_size", 16 if compact else 18)


func _day_style(button: Button, selected: bool, today: bool, has_todo: bool) -> void:
	var bg := Color("ffffff")
	var border := PINK_SOFT
	if has_todo:
		bg = Color("ffe6f2")
	if today:
		border = PINK
	if selected:
		bg = PINK
		border = PINK
	button.add_theme_stylebox_override("normal", _box(bg, border, 10, 2))
	button.add_theme_stylebox_override("hover", _box(PINK_SOFT, PINK, 10, 2))
	button.add_theme_stylebox_override("pressed", _box(PINK, PINK, 10, 2))
	button.add_theme_stylebox_override("focus", _box(bg, PINK, 10, 2))
	button.add_theme_color_override("font_color", Color("ffffff") if selected else INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	button.add_theme_font_size_override("font_size", 16)


# ---------------------------------------------------------------- 搭界面

func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	root.add_child(header)

	var prev := Button.new()
	prev.text = "‹"
	_style_button(prev, true)
	prev.pressed.connect(func() -> void: _shift_month(-1))
	header.add_child(prev)

	_month_label = Label.new()
	_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month_label.add_theme_color_override("font_color", PINK)
	_month_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_month_label)

	var next := Button.new()
	next.text = "›"
	_style_button(next, true)
	next.pressed.connect(func() -> void: _shift_month(1))
	header.add_child(next)

	var today_button := Button.new()
	today_button.text = "今天"
	_style_button(today_button, true)
	today_button.pressed.connect(_go_today)
	header.add_child(today_button)

	var close_button := Button.new()
	close_button.text = "✕"
	_style_button(close_button, true)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var weekdays := GridContainer.new()
	weekdays.columns = 7
	weekdays.add_theme_constant_override("h_separation", 5)
	weekdays.add_theme_constant_override("v_separation", 4)
	root.add_child(weekdays)
	for name in WEEKDAYS:
		var label := Label.new()
		label.text = name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(66.0, 0.0)
		label.add_theme_color_override("font_color", MUTED)
		label.add_theme_font_size_override("font_size", 15)
		weekdays.add_child(label)

	_calendar = GridContainer.new()
	_calendar.columns = 7
	_calendar.add_theme_constant_override("h_separation", 5)
	_calendar.add_theme_constant_override("v_separation", 6)
	root.add_child(_calendar)

	_selected_label = Label.new()
	_selected_label.add_theme_color_override("font_color", PINK)
	_selected_label.add_theme_font_size_override("font_size", 17)
	root.add_child(_selected_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 240.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 4)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 6)
	root.add_child(add_row)

	_input = LineEdit.new()
	_input.placeholder_text = "记一条待办…"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_stylebox_override("normal", _box(Color("ffffff"), PINK_SOFT, 10, 2))
	_input.add_theme_stylebox_override("focus", _box(Color("ffffff"), PINK, 10, 2))
	_input.add_theme_color_override("font_color", INK)
	_input.add_theme_color_override("font_placeholder_color", MUTED)
	_input.add_theme_font_size_override("font_size", 17)
	_input.text_submitted.connect(func(_text: String) -> void: _submit_input())
	add_row.add_child(_input)

	var add_button := Button.new()
	add_button.text = "添加"
	_style_button(add_button)
	add_button.pressed.connect(_submit_input)
	add_row.add_child(add_button)


# ---------------------------------------------------------------- 数据

func _load() -> void:
	_todos = {}
	var absolute := ProjectSettings.globalize_path(TODO_PATH)
	if FileAccess.file_exists(absolute):
		var file := FileAccess.open(absolute, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				_todos = parsed as Dictionary
	_migrate_from_memo()


## 第一次使用时，把老的 todo.md 里的「- [ ] 文本」搬进今天的清单。
func _migrate_from_memo() -> void:
	if not _todos.is_empty():
		return
	var memo := ProjectSettings.globalize_path(MEMO_PATH)
	if not FileAccess.file_exists(memo):
		return
	var file := FileAccess.open(memo, FileAccess.READ)
	if file == null:
		return
	var today := Time.get_date_string_from_system()
	var list: Array = []
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("- [ ]"):
			var text := line.substr(5).strip_edges()
			if text != "":
				list.append({"text": text, "done": false})
	file.close()
	if list.is_empty():
		return
	_todos[today] = list
	_save()


func _save() -> void:
	var absolute := ProjectSettings.globalize_path(TODO_PATH)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_warning("待办保存失败：%s" % absolute)
		return
	file.store_string(JSON.stringify(_todos, "  "))
	file.close()


# ---------------------------------------------------------------- 日历与列表

func _go_today() -> void:
	var today := Time.get_date_string_from_system()
	_year = int(today.substr(0, 4))
	_month = int(today.substr(5, 2))
	_selected = today
	_render_calendar()
	_render_list()


func _shift_month(delta: int) -> void:
	_month += delta
	while _month < 1:
		_month += 12
		_year -= 1
	while _month > 12:
		_month -= 12
		_year += 1
	_render_calendar()


func _date_string(day: int) -> String:
	return "%04d-%02d-%02d" % [_year, _month, day]


func _weekday_of_first() -> int:
	# Sakamoto 算法：0=周日 … 6=周六，这里换成周一开头的偏移。
	return (_weekday(_year, _month, 1) + 6) % 7


func _weekday(year: int, month: int, day: int) -> int:
	var offsets := [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
	var y := year
	if month < 3:
		y -= 1
	var value := y + int(y / 4) - int(y / 100) + int(y / 400) + int(offsets[month - 1]) + day
	return ((value % 7) + 7) % 7


## 自己算每月天数，避免依赖引擎里不一定存在的 Time 取天数接口。
func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		_:
			var leap := (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
			return 29 if leap else 28


func _render_calendar() -> void:
	if _calendar == null:
		return
	_month_label.text = "%d 年 %d 月" % [_year, _month]
	for child in _calendar.get_children():
		_calendar.remove_child(child)
		child.queue_free()
	var offset := _weekday_of_first()
	var days := _days_in_month(_year, _month)
	var today := Time.get_date_string_from_system()
	for index in 42:
		var day := index - offset + 1
		if day < 1 or day > days:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(66.0, 46.0)
			_calendar.add_child(spacer)
			continue
		var date := _date_string(day)
		var button := Button.new()
		button.custom_minimum_size = Vector2(66.0, 46.0)
		var pending := pending_count(date)
		button.text = "%d" % day if pending == 0 else "%d ·" % day
		button.tooltip_text = "待办 %d 条，未完成 %d 条" % [todo_count(date), pending]
		_day_style(button, date == _selected, date == today, pending > 0)
		button.pressed.connect(_select_date.bind(date))
		_calendar.add_child(button)


func _select_date(date: String) -> void:
	_selected = date
	_render_calendar()
	_render_list()


func _render_list() -> void:
	if _list_box == null:
		return
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	var parts := _selected.split("-")
	_selected_label.text = "%d 月 %d 日 · 未完成 %d 条" % [int(parts[1]), int(parts[2]), pending_count(_selected)]
	var list: Array = _todos.get(_selected, [])
	if list.is_empty():
		var empty := Label.new()
		empty.text = "这一天还没有待办，下面加一条喵～"
		empty.add_theme_color_override("font_color", MUTED)
		empty.add_theme_font_size_override("font_size", 16)
		_list_box.add_child(empty)
		return
	for index in list.size():
		var item: Dictionary = list[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_list_box.add_child(row)

		var check := CheckBox.new()
		check.text = str(item.get("text", ""))
		check.button_pressed = bool(item.get("done", false))
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.add_theme_font_size_override("font_size", 17)
		check.add_theme_color_override("font_color", MUTED if check.button_pressed else INK)
		check.add_theme_color_override("font_hover_color", PINK)
		check.toggled.connect(func(_pressed: bool) -> void: toggle_todo(_selected, index))
		row.add_child(check)

		var remove := Button.new()
		remove.text = "✕"
		remove.tooltip_text = "删掉这条"
		_style_button(remove, true)
		remove.pressed.connect(func() -> void: remove_todo(_selected, index))
		row.add_child(remove)


func _submit_input() -> void:
	var text := _input.text.strip_edges()
	if text == "":
		return
	add_todo(_selected, text)
	_input.text = ""
