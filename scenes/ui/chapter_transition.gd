extends CanvasLayer
## Màn giới thiệu chương: nền đen, số chương và tên hiện dần rồi mở nội dung.
## GameManager giữ game tạm dừng trong suốt hiệu ứng, lớp này vẫn nhận input và chạy tween.

const TITLE_FONT := preload("res://assets/backgrounds/fonts/dearpix-1-94.otf")
const BLACK_HOLD := 0.25
const TEXT_FADE_IN := 0.8
const TEXT_HOLD := 1.8
const TEXT_FADE_OUT := 0.5
const SCENE_FADE_IN := 0.6

var _overlay: ColorRect
var _titles: VBoxContainer
var _number_label: Label
var _title_label: Label


func _ready() -> void:
	name = "ChapterTransition"
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.name = "BlackBackground"
	_overlay.color = Color.BLACK
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_titles = VBoxContainer.new()
	_titles.name = "Titles"
	_titles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_titles.anchor_left = 0.08
	_titles.anchor_right = 0.92
	_titles.alignment = BoxContainer.ALIGNMENT_CENTER
	_titles.add_theme_constant_override("separation", 22)
	_titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titles.modulate.a = 0.0
	_overlay.add_child(_titles)
	_number_label = _create_label("ChapterNumber", 28)
	_title_label = _create_label("ChapterTitle", 48)


func _create_label(node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titles.add_child(label)
	return label


## chapter_name lấy trực tiếp từ Inspector, dạng "Chương 1 · Người lạ trong giấc mơ".
func play(chapter_name: String) -> void:
	var parts := chapter_name.split("·", true, 1)
	_number_label.text = parts[0].strip_edges().to_upper() if parts.size() > 1 else ""
	_number_label.visible = not _number_label.text.is_empty()
	_title_label.text = parts[1].strip_edges() if parts.size() > 1 else chapter_name
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(BLACK_HOLD)
	tween.tween_property(_titles, "modulate:a", 1.0, TEXT_FADE_IN)
	tween.tween_interval(TEXT_HOLD)
	tween.tween_property(_titles, "modulate:a", 0.0, TEXT_FADE_OUT)
	tween.tween_property(_overlay, "modulate:a", 0.0, SCENE_FADE_IN)
	await tween.finished


## Nuốt cả chuột, bàn phím và chạm để không mở menu hoặc đọc thoại dưới lớp phủ.
func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
