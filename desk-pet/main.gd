extends Node2D

## 猫娘桌宠：左键拖动窗口，双击让猫娘说话，右键退出。
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

## 立绘缩放到的像素高度，按 360x400 的窗口留出气泡空间。
const TARGET_SPRITE_HEIGHT := 236.0

const BUBBLE_HOLD_SECONDS := 3.5
const BLINK_HALF_SECONDS := 0.06
const BLINK_CLOSED_SECONDS := 0.09

@onready var drag_collision: CollisionShape2D = $CharacterRoot/DragArea/CollisionShape2D
@onready var body: Sprite2D = $CharacterRoot/VisualRoot/Body
@onready var bubble: PanelContainer = $Bubble
@onready var bubble_label: Label = $Bubble/Label
@onready var bubble_timer: Timer = $BubbleTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _speaking := false
var _blinking := false
var _eyes: Sprite2D
var _eyes_half: Texture2D
var _eyes_closed: Texture2D
var _blink_timer: Timer


func _ready() -> void:
	var rectangle := drag_collision.shape as RectangleShape2D
	if rectangle == null:
		push_error("DragArea/CollisionShape2D 必须使用 RectangleShape2D")
		return
	var centre := drag_collision.global_position
	var half_size := rectangle.size / 2.0
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([
		centre + Vector2(-half_size.x, -half_size.y),
		centre + Vector2(half_size.x, -half_size.y),
		centre + Vector2(half_size.x, half_size.y),
		centre + Vector2(-half_size.x, half_size.y),
	]))
	bubble.visible = false
	if animation_player.has_animation("idle_breathe"):
		animation_player.play("idle_breathe")
	apply_character_art()
	_schedule_next_speech()


func _on_drag_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is not InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		get_tree().quit()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			speak()
		elif event.pressed:
			DisplayServer.window_start_drag()


func _schedule_next_speech() -> void:
	bubble_timer.wait_time = randf_range(7.0, 15.0)
	bubble_timer.start()


func _on_bubble_timer_timeout() -> void:
	speak()
	_schedule_next_speech()


## 显示一句随机台词，并在一段时间后淡出。
func speak() -> void:
	if _speaking:
		return
	_speaking = true
	bubble_label.text = SPEECH_LINES[randi() % SPEECH_LINES.size()]
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


## 角色目录里有 base.png 时换成它，并按高度自适应缩放；没有就保留场景自带的立绘。
func apply_character_art() -> void:
	var base_path := "%s/%s" % [CHARACTER_DIR, BASE_FILE]
	if not ResourceLoader.exists(base_path):
		return
	var texture := load(base_path) as Texture2D
	if texture == null:
		push_warning("角色立绘加载失败：%s" % base_path)
		return
	body.texture = texture
	var height := float(texture.get_height())
	if height > 0.0:
		body.scale = Vector2.ONE * (TARGET_SPRITE_HEIGHT / height)
	_setup_eyes()


func _setup_eyes() -> void:
	var half_path := "%s/%s" % [CHARACTER_DIR, EYES_HALF_FILE]
	var closed_path := "%s/%s" % [CHARACTER_DIR, EYES_CLOSED_FILE]
	if not ResourceLoader.exists(half_path) or not ResourceLoader.exists(closed_path):
		return
	_eyes_half = load(half_path) as Texture2D
	_eyes_closed = load(closed_path) as Texture2D
	if _eyes_half == null or _eyes_closed == null:
		push_warning("睁眼叠图加载失败，跳过眨眼：%s / %s" % [half_path, closed_path])
		return
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
