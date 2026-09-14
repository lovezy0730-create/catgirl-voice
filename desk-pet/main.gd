extends Node2D

## 猫娘桌宠：左键拖动窗口，双击让猫娘说话，右键退出。
##
## 立绘来自 res://character/catgirl_default/mascot.svg，换角色只要替换该文件，
## 或修改 main.tscn 里 Body 节点的 texture 指向自己的立绘。

const SPEECH_LINES: PackedStringArray = [
	"今天也要好好写代码哦喵～",
	"编译不过的时候，先摸摸猫耳朵喵～",
	"这个配色是不是粉粉的很可爱喵～",
	"困了就去睡觉喵～",
	"提交之前记得跑测试喵～",
	"忘了带分号也没关系，我原谅你了喵～",
]

const BUBBLE_HOLD_SECONDS := 3.5

@onready var drag_collision: CollisionShape2D = $CharacterRoot/DragArea/CollisionShape2D
@onready var bubble: PanelContainer = $Bubble
@onready var bubble_label: Label = $Bubble/Label
@onready var bubble_timer: Timer = $BubbleTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _speaking := false


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
