extends Node2D

## 猫娘桌宠：左键拖动窗口、左键双击说话、右键打开菜单。
##
## 立绘默认用工程自带的 res://character/catgirl_default/mascot.svg。
## 只要把下面的文件放进 CHARACTER_DIR 指向的角色目录，就会自动改用它们：
##
## - base.png：主立绘，睁眼状态。
## - eyes_half.png：半睁眼叠图。
## - eyes_closed.png：闭眼叠图。
##
## 三张齐全时开启眨眼；只有 base.png 时只做呼吸浮动。叠图必须与主立绘同画布、
## 同构图，只在眼睛区域不同，否则眨眼会错位。

const SPEECH_LINES: PackedStringArray = [
	"今天也要好好写代码哦喵～",
	"编译不过的时候，先摸摸猫耳朵喵～",
	"这个配色是不是粉粉的很可爱喵～",
	"困了就去睡觉喵～",
	"提交之前记得跑测试喵～",
	"忘了带分号也没关系，我原谅你了喵～",
]

## 换角色只改这一行：把角色目录名换成 character/ 下的目录名。
const CHARACTER_DIR := "res://character/elaina_catgirl"

const BASE_FILE := "base.png"
const EYES_HALF_FILE := "eyes_half.png"
const EYES_CLOSED_FILE := "eyes_closed.png"
## 可选：只改耳朵的叠图，放进角色目录就会开启耳朵抖动。
const EARS_FILE := "ears.png"

## 立绘缩放到的像素高度，按 760x950 的窗口留出气泡空间。
const TARGET_SPRITE_HEIGHT := 680.0

const BUBBLE_HOLD_SECONDS := 3.5
const BLINK_HALF_SECONDS := 0.06
const BLINK_CLOSED_SECONDS := 0.09
## 耳朵抖动的节奏库：短促一下、连抖两下、慢抬一下、快速抖三下。
const EAR_PATTERNS := [
	[{"hold": 0.07, "gap": 0.05}],
	[{"hold": 0.11, "gap": 0.09}, {"hold": 0.11, "gap": 0.0}],
	[{"hold": 0.34, "gap": 0.0}],
	[{"hold": 0.06, "gap": 0.05}, {"hold": 0.06, "gap": 0.05}, {"hold": 0.06, "gap": 0.0}],
]

## DeepSeek 余额：优先读环境变量，其次读 Codex 的 config.toml，避免把 Key 写进工程。
const DEEPSEEK_BALANCE_URL := "https://api.deepseek.com/user/balance"
const DEEPSEEK_KEY_ENV := "DEEPSEEK_API_KEY"
const CODEX_CONFIG_RELATIVE := "/.codex/config.toml"
const BALANCE_REFRESH_SECONDS := 600.0

## 待办备忘录文件，放在 userdata/ 里，不参与版本控制。
const MEMO_PATH := "res://userdata/todo.md"
const MEMO_TEMPLATE := "# 待办备忘录\n\n- [ ] 今天要做的事\n"

## 任务栏图标：从立绘里裁一块头部特写，比例按角色画布量出来的。
const HEAD_CENTER_X_RATIO := 0.434
const ICON_SIDE_RATIO := 0.52

const TODO_PANEL_SCRIPT := preload("res://todo_panel.gd")
const POMODORO_PANEL_SCRIPT := preload("res://pomodoro_panel.gd")

const PINK := Color("f472b6")
const PINK_SOFT := Color("f9a8d4")
const PINK_PALE := Color("fff3f8")
const INK := Color("4a3b4f")

@onready var drag_collision: CollisionShape2D = $CharacterRoot/DragArea/CollisionShape2D
@onready var body: Sprite2D = $CharacterRoot/VisualRoot/Body
@onready var bubble: PanelContainer = $Bubble
@onready var bubble_label: Label = $Bubble/Label
@onready var bubble_timer: Timer = $BubbleTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var menu_panel: PanelContainer = $MenuPanel
@onready var balance_button: Button = $MenuPanel/VBox/BalanceButton

var _speaking := false
var _blinking := false
var _eyes: Sprite2D
var _eyes_half: Texture2D
var _eyes_closed: Texture2D
var _blink_timer: Timer
var _ears: Sprite2D
var _ears_texture: Texture2D
var _ears_timer: Timer
var _ears_twitching := false
var _balance_request: HTTPRequest
var _balance_timer: Timer
var _balance_text := ""
var _balance_updated_at := 0.0
var _drag_rect := Rect2()
var _todo_panel: PanelContainer
var _pomodoro_panel: PanelContainer
var _dragging := false
var _drag_offset := Vector2i.ZERO


func _ready() -> void:
	var rectangle := drag_collision.shape as RectangleShape2D
	if rectangle == null:
		push_error("DragArea/CollisionShape2D 必须使用 RectangleShape2D")
		return
	var centre := drag_collision.global_position
	var half_size := rectangle.size / 2.0
	_drag_rect = Rect2(centre - half_size, rectangle.size)
	_update_passthrough()
	bubble.visible = false
	menu_panel.visible = false
	_style_menu()
	if animation_player.has_animation("idle_breathe"):
		animation_player.play("idle_breathe")
	apply_character_art()
	_schedule_next_speech()
	_start_balance_watch()


## 鼠标穿透区域：平时只放开桌宠本体，菜单或待办面板打开时一起放开，
## 否则点到面板边缘会被系统当成点桌面。
func _update_passthrough() -> void:
	var area := _drag_rect
	if menu_panel != null and menu_panel.visible:
		area = area.merge(menu_panel.get_global_rect())
	if _todo_panel != null and _todo_panel.visible:
		area = area.merge(_todo_panel.get_global_rect())
	if _pomodoro_panel != null and _pomodoro_panel.visible:
		area = area.merge(_pomodoro_panel.get_global_rect())
	var position := area.position
	var size := area.size
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([
		position,
		position + Vector2(size.x, 0.0),
		position + size,
		position + Vector2(0.0, size.y),
	]))


## 右键菜单统一成桌宠的粉色圆角风，字号和文字也一起对齐。
func _style_menu() -> void:
	menu_panel.z_index = 10
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = PINK_PALE
	panel_box.set_border_width_all(3)
	panel_box.border_color = PINK
	panel_box.set_corner_radius_all(18)
	panel_box.set_content_margin_all(10.0)
	menu_panel.add_theme_stylebox_override("panel", panel_box)
	balance_button.text = "看看余额喵～"
	$MenuPanel/VBox/MemoButton.text = "待办清单喵～"
	$MenuPanel/VBox/PomodoroButton.text = "番茄钟喵～"
	$MenuPanel/VBox/QuitButton.text = "退出桌宠喵～"
	for button in menu_panel.get_node("VBox").get_children():
		if button is not Button:
			continue
		_style_menu_button(button as Button)


func _style_menu_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_box(Color("ffffff"), PINK_SOFT))
	button.add_theme_stylebox_override("hover", _button_box(PINK_SOFT, PINK))
	button.add_theme_stylebox_override("pressed", _button_box(PINK, PINK))
	button.add_theme_stylebox_override("focus", _button_box(Color("ffffff"), PINK))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	button.add_theme_font_size_override("font_size", 18)
	button.custom_minimum_size = Vector2(230.0, 44.0)


func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(2)
	box.border_color = border
	box.set_corner_radius_all(12)
	box.set_content_margin_all(8.0)
	return box


func _on_drag_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is not InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_toggle_menu()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point := get_viewport().get_mouse_position()
	if _point_in_menu(point):
		# 点在菜单上：交给按钮处理，这里什么都不做。
		return
	if menu_panel.visible:
		_hide_menu()
		return
	if event.double_click:
		speak()
		twitch_ears()
	elif event.pressed:
		_begin_drag()


## 无边框透明窗口上系统的 window_start_drag 不一定生效，所以自己按鼠标位置移动窗口。
func _begin_drag() -> void:
	_dragging = true
	_drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()


func _end_drag() -> void:
	_dragging = false


## 拖动时窗口该待的位置：鼠标屏幕坐标减去按下时的偏移。
func drag_target_position() -> Vector2i:
	return DisplayServer.mouse_get_position() - _drag_offset


func _process(_delta: float) -> void:
	if _dragging:
		DisplayServer.window_set_position(drag_target_position())


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	# 松开左键就结束拖动，鼠标移到窗口外也能收到。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()


# ---------------------------------------------------------------- 台词与气泡

func _schedule_next_speech() -> void:
	bubble_timer.wait_time = randf_range(7.0, 15.0)
	bubble_timer.start()


func _on_bubble_timer_timeout() -> void:
	speak()
	_schedule_next_speech()


## 显示一句随机台词，并在一段时间后淡出。
func speak() -> void:
	say(SPEECH_LINES[randi() % SPEECH_LINES.size()])


## 显示指定台词，并在一段时间后淡出。
func say(line: String) -> void:
	if _speaking:
		bubble_label.text = line
		return
	_speaking = true
	bubble_label.text = line
	bubble.modulate.a = 0.0
	bubble.visible = true

	var fade_in := create_tween()
	fade_in.tween_property(bubble, "modulate:a", 1.0, 0.25)
	await fade_in.finished
	await get_tree().create_timer(BUBBLE_HOLD_SECONDS).timeout

	var fade_out := create_tween()
	fade_out.tween_property(bubble, "modulate:a", 0.0, 0.4)
	await fade_out.finished
	bubble.visible = false
	bubble.modulate.a = 1.0
	_speaking = false


# ---------------------------------------------------------------- 右键菜单

func _toggle_menu() -> void:
	if menu_panel.visible:
		_hide_menu()
	else:
		_show_menu()


func _show_menu() -> void:
	menu_panel.reset_size()
	var size := menu_panel.get_combined_minimum_size()
	var window_size := Vector2(get_window().size)
	var mouse := get_viewport().get_mouse_position()
	menu_panel.position = Vector2(
		clampf(mouse.x, 8.0, maxf(8.0, window_size.x - size.x - 8.0)),
		clampf(mouse.y, 8.0, maxf(8.0, window_size.y - size.y - 8.0))
	)
	menu_panel.visible = true
	_update_passthrough()


func _hide_menu() -> void:
	menu_panel.visible = false
	_update_passthrough()


func _point_in_menu(point: Vector2) -> bool:
	return menu_panel.visible and menu_panel.get_global_rect().has_point(point)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


# ---------------------------------------------------------------- DeepSeek 余额

func _on_balance_button_pressed() -> void:
	_hide_menu()
	refresh_balance(false)


## 启动时先静默查一次，之后每 10 分钟刷新一次，菜单项会带上当前余额。
func _start_balance_watch() -> void:
	if _deepseek_token() == "":
		print("[猫娘桌宠] 没有找到 DeepSeek API Key，余额功能待命中")
		return
	refresh_balance(true)
	_balance_timer = Timer.new()
	_balance_timer.name = "BalanceTimer"
	_balance_timer.wait_time = BALANCE_REFRESH_SECONDS
	_balance_timer.timeout.connect(func() -> void: refresh_balance(true))
	add_child(_balance_timer)
	_balance_timer.start()


func refresh_balance(silent: bool) -> void:
	var token := _deepseek_token()
	if token == "":
		if not silent:
			say("没有找到 DeepSeek API Key，先设好环境变量再试喵～")
		return
	if _balance_request == null:
		_balance_request = HTTPRequest.new()
		_balance_request.name = "BalanceRequest"
		_balance_request.timeout = 15.0
		_balance_request.request_completed.connect(_on_balance_completed)
		add_child(_balance_request)
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % token,
		"Accept: application/json",
	])
	var error := _balance_request.request(DEEPSEEK_BALANCE_URL, headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_warning("余额请求发起失败：%d" % error)
		if not silent:
			say("余额查询没能发出去喵～")


func _on_balance_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		say("余额查询失败（网络错误 %d）喵～" % result)
		return
	if response_code != 200:
		say("余额查询失败（HTTP %d），检查一下 Key 喵～" % response_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		say("余额返回的内容看不懂喵～")
		return
	var infos: Variant = (parsed as Dictionary).get("balance_infos")
	if typeof(infos) != TYPE_ARRAY or (infos as Array).is_empty():
		say("账户里没有余额信息喵～")
		return
	var info: Dictionary = (infos as Array)[0]
	var currency := str(info.get("currency", "CNY"))
	var amount := str(info.get("total_balance", "?"))
	if currency == "CNY":
		_balance_text = "¥%s" % amount
	else:
		_balance_text = "%s %s" % [currency, amount]
	_balance_updated_at = Time.get_ticks_msec() / 1000.0
	balance_button.text = "看看余额喵～（%s）" % _balance_text
	print("[猫娘桌宠] DeepSeek 余额：%s" % _balance_text)
	say("DeepSeek 余额：%s 喵～" % _balance_text)


## 找 Key：环境变量优先，其次从 Codex 的 config.toml 里读，避免把密钥复制进工程。
func _deepseek_token() -> String:
	var from_env := OS.get_environment(DEEPSEEK_KEY_ENV)
	if from_env != "":
		return from_env
	var home := OS.get_environment("USERPROFILE")
	if home == "":
		home = OS.get_environment("HOME")
	if home == "":
		return ""
	var config_path := home + CODEX_CONFIG_RELATIVE
	if not FileAccess.file_exists(config_path):
		return ""
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return ""
	var in_deepseek_section := false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("["):
			in_deepseek_section = line.contains("deepseek")
			continue
		if not in_deepseek_section or not line.begins_with("experimental_bearer_token"):
			continue
		var parts := line.split("=", true, 1)
		if parts.size() < 2:
			continue
		var token := parts[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
		if token != "":
			file.close()
			return token
	file.close()
	return ""


# ---------------------------------------------------------------- 待办备忘录

func _on_memo_button_pressed() -> void:
	_hide_menu()
	_open_todo_panel()


## 打开带日历的待办面板：点小方块就能把待办划掉。
func _open_todo_panel() -> void:
	_hide_menu()
	if _todo_panel == null:
		_todo_panel = TODO_PANEL_SCRIPT.new()
		_todo_panel.name = "TodoPanel"
		_todo_panel.closed.connect(_update_passthrough)
		add_child(_todo_panel)
	if not _todo_panel.visible:
		_todo_panel.open()
	# 面板在窗口里居中，窗口多大都摆得正。
	var viewport_size := get_viewport_rect().size
	var panel_size := _todo_panel.get_combined_minimum_size()
	var panel_position := ((viewport_size - panel_size) / 2.0).floor()
	panel_position.x = clampf(panel_position.x, 8.0, maxf(8.0, viewport_size.x - panel_size.x - 8.0))
	panel_position.y = clampf(panel_position.y, 8.0, maxf(8.0, viewport_size.y - panel_size.y - 8.0))
	_todo_panel.position = panel_position
	_update_passthrough()
	say("待办清单打开啦，点小方块就能划掉喵～")


func _on_pomodoro_button_pressed() -> void:
	_hide_menu()
	_open_pomodoro_panel()


## 打开番茄钟面板：专注 / 短休息 / 长休息与轮数都能自由设置。
func _open_pomodoro_panel() -> void:
	_hide_menu()
	if _pomodoro_panel == null:
		_pomodoro_panel = POMODORO_PANEL_SCRIPT.new()
		_pomodoro_panel.name = "PomodoroPanel"
		_pomodoro_panel.closed.connect(_update_passthrough)
		_pomodoro_panel.phase_finished.connect(_on_pomodoro_phase_finished)
		add_child(_pomodoro_panel)
	if not _pomodoro_panel.visible:
		_pomodoro_panel.open()
	var viewport_size := get_viewport_rect().size
	var panel_size := _pomodoro_panel.get_combined_minimum_size()
	var panel_position := ((viewport_size - panel_size) / 2.0).floor()
	panel_position.x = clampf(panel_position.x, 8.0, maxf(8.0, viewport_size.x - panel_size.x - 8.0))
	panel_position.y = clampf(panel_position.y, 8.0, maxf(8.0, viewport_size.y - panel_size.y - 8.0))
	_pomodoro_panel.position = panel_position
	_update_passthrough()
	if not _pomodoro_panel.is_running():
		say("番茄钟打开啦，时长可以自己调喵～")


## 换段时用气泡提醒，再响一声系统提示音。
func _on_pomodoro_phase_finished(finished_mode: String, next_mode: String) -> void:
	var message := "这一段结束啦喵～"
	match finished_mode:
		"focus":
			message = "专注结束，长休息一下喵～" if next_mode == "long" else "专注结束，短休息一下喵～"
		"short":
			message = "短休息结束，继续下一个番茄喵～"
		"long":
			message = "长休息结束，回来继续喵～"
	say(message)
	if DisplayServer.has_method("beep"):
		DisplayServer.beep()


## 确保 userdata/todo.md 存在并返回绝对路径，不存在就写入一份模板。
func ensure_memo_file() -> String:
	var absolute := ProjectSettings.globalize_path(MEMO_PATH)
	var directory := absolute.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var make_error := DirAccess.make_dir_recursive_absolute(directory)
		if make_error != OK:
			push_warning("创建 userdata 目录失败：%d" % make_error)
			return ""
	if not FileAccess.file_exists(absolute):
		var file := FileAccess.open(absolute, FileAccess.WRITE)
		if file == null:
			push_warning("写入备忘录失败：%s" % absolute)
			return ""
		file.store_string(MEMO_TEMPLATE)
		file.close()
	return absolute


# ---------------------------------------------------------------- 立绘与眨眼

## 角色目录里有 base.png 时换成它，并按高度自适应缩放；没有就保留场景自带的立绘。
func apply_character_art() -> void:
	var base_path := "%s/%s" % [CHARACTER_DIR, BASE_FILE]
	var texture := _load_texture(base_path)
	if texture == null:
		print("[猫娘桌宠] 未找到角色立绘 %s，继续使用自带的原创立绘" % base_path)
		return
	body.texture = texture
	var height := float(texture.get_height())
	if height > 0.0:
		body.scale = Vector2.ONE * (TARGET_SPRITE_HEIGHT / height)
	print("[猫娘桌宠] 使用角色立绘 %s（%dx%d，缩放 %.3f）" % [base_path, texture.get_width(), texture.get_height(), body.scale.x])
	_apply_window_icon(texture)
	_setup_eyes()
	_setup_ears()


## 任务栏图标换成角色头部特写，让桌宠图标也是这位角色。
func _apply_window_icon(texture: Texture2D) -> void:
	var image := texture.get_image()
	if image == null or image.get_width() <= 0:
		return
	var side := int(minf(float(image.get_width()), float(image.get_height())) * ICON_SIDE_RATIO)
	if side <= 0:
		return
	var x := clampi(int(float(image.get_width()) * HEAD_CENTER_X_RATIO) - side / 2, 0, image.get_width() - side)
	var region := image.get_region(Rect2i(x, 0, side, side))
	# Window 上没有 set_icon，任务栏图标走 DisplayServer。
	if DisplayServer.has_method("set_icon"):
		DisplayServer.set_icon(region)
	else:
		push_warning("当前引擎不支持设置窗口图标，保留默认图标")
	print("[猫娘桌宠] 任务栏图标已换成角色头部特写（%dx%d）" % [side, side])


## 读取立绘：先走 Godot 资源系统；没有导入缓存时直接用 Image 读文件，
## 这样即使没在编辑器里导入过、或者直接用 --path 跑工程，也能显示立绘。
func _load_texture(resource_path: String) -> Texture2D:
	if ResourceLoader.exists(resource_path):
		var imported := load(resource_path) as Texture2D
		if imported != null:
			return imported
	var absolute := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(absolute):
		return null
	var image := Image.load_from_file(absolute)
	if image == null:
		push_warning("立绘无法解码：%s" % absolute)
		return null
	print("[猫娘桌宠] %s 还没导入，改为直接从文件读取" % resource_path)
	return ImageTexture.create_from_image(image)


func _setup_eyes() -> void:
	var half_path := "%s/%s" % [CHARACTER_DIR, EYES_HALF_FILE]
	var closed_path := "%s/%s" % [CHARACTER_DIR, EYES_CLOSED_FILE]
	_eyes_half = _load_texture(half_path)
	_eyes_closed = _load_texture(closed_path)
	if _eyes_half == null or _eyes_closed == null:
		_eyes_half = null
		_eyes_closed = null
		print("[猫娘桌宠] 没有找到成对的眨眼叠图，跳过眨眼")
		return
	print("[猫娘桌宠] 眨眼叠图已加载：%s / %s" % [half_path, closed_path])
	_eyes = Sprite2D.new()
	_eyes.name = "Eyes"
	_eyes.texture = _eyes_half
	_eyes.scale = body.scale
	_eyes.z_index = 1
	_eyes.visible = false
	body.get_parent().add_child(_eyes)
	_schedule_next_blink()


func _schedule_next_blink() -> void:
	if _eyes == null:
		return
	if _blink_timer == null:
		_blink_timer = Timer.new()
		_blink_timer.name = "BlinkTimer"
		_blink_timer.one_shot = true
		add_child(_blink_timer)
		_blink_timer.timeout.connect(_on_blink_timer_timeout)
	_blink_timer.wait_time = randf_range(3.0, 8.0)
	_blink_timer.start()


## 耳朵叠图可选：有 ears.png 就隔几秒抖一下耳朵。
func _setup_ears() -> void:
	var ears_path := "%s/%s" % [CHARACTER_DIR, EARS_FILE]
	_ears_texture = _load_texture(ears_path)
	if _ears_texture == null:
		print("[猫娘桌宠] 没有 %s，跳过耳朵抖动" % ears_path)
		return
	if _ears_texture.get_size() != body.texture.get_size():
		push_warning("耳朵叠图尺寸与主图不一致，跳过耳朵抖动：%s" % ears_path)
		_ears_texture = null
		return
	print("[猫娘桌宠] 耳朵叠图已加载：%s" % ears_path)
	_ears = Sprite2D.new()
	_ears.name = "Ears"
	_ears.texture = _ears_texture
	_ears.scale = body.scale
	_ears.z_index = 1
	_ears.visible = false
	body.get_parent().add_child(_ears)
	_schedule_next_ear_twitch()


func _schedule_next_ear_twitch() -> void:
	if _ears == null:
		return
	if _ears_timer == null:
		_ears_timer = Timer.new()
		_ears_timer.name = "EarsTimer"
		_ears_timer.one_shot = true
		add_child(_ears_timer)
		_ears_timer.timeout.connect(_on_ears_timer_timeout)
	_ears_timer.wait_time = randf_range(2.5, 6.5)
	_ears_timer.start()


func _on_ears_timer_timeout() -> void:
	await twitch_ears()
	_schedule_next_ear_twitch()


## 耳朵抖动：从四种节奏里随机挑一种，抬起时淡入并轻轻张开，放下时淡出。
func twitch_ears() -> void:
	if _ears == null or _ears_twitching:
		return
	_ears_twitching = true
	var pattern: Array = EAR_PATTERNS[randi() % EAR_PATTERNS.size()]
	for pulse in pattern:
		await _ear_pulse(float((pulse as Dictionary)["hold"]))
		var gap := float((pulse as Dictionary)["gap"])
		if gap > 0.0:
			await get_tree().create_timer(gap).timeout
	_ears_twitching = false


func _ear_pulse(hold: float) -> void:
	if _ears == null:
		return
	var base_scale := body.scale
	_ears.visible = true
	_ears.modulate.a = 0.0
	_ears.scale = base_scale * Vector2(0.985, 0.975)
	_ears.rotation = -0.01
	var rise := create_tween().set_parallel(true)
	rise.tween_property(_ears, "modulate:a", 1.0, 0.07)
	rise.tween_property(_ears, "scale", base_scale * Vector2(1.006, 1.0), 0.09)
	rise.tween_property(_ears, "rotation", 0.008, 0.09)
	await get_tree().create_timer(hold).timeout
	var fall := create_tween().set_parallel(true)
	fall.tween_property(_ears, "modulate:a", 0.0, 0.1)
	fall.tween_property(_ears, "scale", base_scale * Vector2(0.99, 0.98), 0.12)
	fall.tween_property(_ears, "rotation", -0.008, 0.12)
	await fall.finished
	_ears.visible = false
	_ears.modulate.a = 1.0
	_ears.scale = base_scale
	_ears.rotation = 0.0


func _on_blink_timer_timeout() -> void:
	await blink()
	_schedule_next_blink()


## 眨眼：半睁 -> 闭 -> 半睁 -> 睁，顺序与叠图节奏保持一致。
func blink() -> void:
	if _eyes == null or _blinking:
		return
	_blinking = true
	_eyes.texture = _eyes_half
	_eyes.visible = true
	await get_tree().create_timer(BLINK_HALF_SECONDS).timeout
	_eyes.texture = _eyes_closed
	await get_tree().create_timer(BLINK_CLOSED_SECONDS).timeout
	_eyes.texture = _eyes_half
	await get_tree().create_timer(BLINK_HALF_SECONDS).timeout
	_eyes.visible = false
	_blinking = false
