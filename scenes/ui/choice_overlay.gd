extends Control
## Giữ bảng lựa chọn ở giữa màn hình, co theo cửa sổ và cuộn khi nội dung dài.

const MAX_PANEL_WIDTH := 780.0

@onready var center: CenterContainer = $Center
@onready var panel: PanelContainer = $Center/Panel
@onready var scroll: ScrollContainer = $Center/Panel/Content/Scroll
@onready var choices: VBoxContainer = $Center/Panel/Content/Scroll/ChoiceContainer

var _layout_queued := false
var _entrance_tween: Tween


func _ready() -> void:
	resized.connect(_queue_layout)
	choices.minimum_size_changed.connect(_queue_layout)
	visibility_changed.connect(_on_visibility_changed)
	_queue_layout()


## Đợi container cập nhật kích thước chữ trước khi tính chiều cao vùng cuộn.
func _queue_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	call_deferred("_update_layout")


func _update_layout() -> void:
	_layout_queued = false
	# Dùng vùng neo theo cửa sổ: kích thước tối thiểu cũ của panel không cản việc thu nhỏ.
	var available_size := size + Vector2(center.offset_right - center.offset_left, center.offset_bottom - center.offset_top)
	panel.custom_minimum_size.x = minf(MAX_PANEL_WIDTH, maxf(0.0, available_size.x))
	var surrounding_height := panel.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
	var available_height := maxf(0.0, available_size.y - surrounding_height)
	scroll.custom_minimum_size.y = minf(choices.get_combined_minimum_size().y, available_height)


func _on_visibility_changed() -> void:
	if not is_node_ready():
		return
	if is_instance_valid(_entrance_tween):
		_entrance_tween.kill()
	if not visible:
		modulate.a = 1.0
		return
	scroll.scroll_vertical = 0
	_queue_layout()
	modulate.a = 0.0
	_entrance_tween = create_tween()
	_entrance_tween.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
