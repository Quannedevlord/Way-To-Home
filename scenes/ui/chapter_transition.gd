extends CanvasLayer
## Hộp thoại chuyển cảnh giữa các chương: hỏi người chơi muốn tiếp tục hay về menu chính.
## GameManager tạo và hiển thị lớp này khi chapter hoàn thành; kết quả quyết định scene kế tiếp.

signal choice_made(continue_next: bool)

const CHAT_FONT := preload("res://assets/backgrounds/fonts/Roboto-Light.ttf")

var _overlay: ColorRect
var _panel: PanelContainer
var _label: Label
var _button_container: HBoxContainer
var _yes_button: Button
var _no_button: Button
var _fade_tween: Tween


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Nền mờ phủ toàn màn hình
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, 0.75)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	# Bảng chứa nội dung
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -280
	_panel.offset_top = -100
	_panel.offset_right = 280
	_panel.offset_bottom = 100
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.066667, 0.105882, 0.188235, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.588235, 0.454902, 0.278431, 1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 30
	panel_style.content_margin_top = 24
	panel_style.content_margin_right = 30
	panel_style.content_margin_bottom = 24
	panel_style.shadow_color = Color(0.01, 0.03, 0.07, 0.6)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_overlay.add_child(_panel)

	# Bố cục dọc
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# Nhãn câu hỏi
	_label = Label.new()
	_label.text = "Bạn có muốn tiếp tục?"
	_label.add_theme_font_override("font", CHAT_FONT)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.968627, 0.858824, 0.580392, 1))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_label)

	# Hàng nút
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 32)
	vbox.add_child(_button_container)

	# Nút "Có"
	_yes_button = _create_button("Có", Color(0.29, 0.47, 0.50, 1), Color(0.35, 0.55, 0.58, 1))
	_yes_button.pressed.connect(_on_yes_pressed)
	_button_container.add_child(_yes_button)

	# Nút "Không"
	_no_button = _create_button("Không", Color(0.45, 0.22, 0.22, 1), Color(0.55, 0.28, 0.28, 1))
	_no_button.pressed.connect(_on_no_pressed)
	_button_container.add_child(_no_button)

	# Hiệu ứng xuất hiện
	_overlay.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_overlay, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Focus nút "Có" để người chơi có thể chọn bằng bàn phím
	_yes_button.grab_focus()


## Tạo nút với phong cách nhất quán với giao diện game.
func _create_button(text: String, normal_color: Color, hover_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 48)
	btn.add_theme_font_override("font", CHAT_FONT)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var style := StyleBoxFlat.new()
	style.bg_color = normal_color
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_top = 10
	style.content_margin_right = 20
	style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = hover_color
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)
	return btn


## Người chơi chọn tiếp tục chapter mới.
func _on_yes_pressed() -> void:
	_close_with_result(true)


## Người chơi chọn quay về menu chính.
func _on_no_pressed() -> void:
	_close_with_result(false)


## Fade ra rồi phát signal kết quả và xóa hộp thoại.
func _close_with_result(continue_next: bool) -> void:
	_yes_button.disabled = true
	_no_button.disabled = true
	if is_instance_valid(_fade_tween) and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_overlay, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _fade_tween.finished
	choice_made.emit(continue_next)
	queue_free()
