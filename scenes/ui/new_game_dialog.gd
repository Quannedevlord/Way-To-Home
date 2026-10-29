extends ConfirmationDialog
## Hộp xác nhận dùng màu và font của game, giữ thao tác chuẩn của ConfirmationDialog.

const PIXEL_FONT := preload("res://assets/backgrounds/fonts/dearpix-1-94.otf")
const BODY_FONT := preload("res://assets/backgrounds/fonts/Roboto-Light.ttf")
const CLOCK := preload("res://assets/backgrounds/ui/clock.svg")
const GOLD := Color("edcd8b")
const INK := Color("101b2b")


func _ready() -> void:
	borderless = true
	unresizable = true
	get_label().hide()
	var dialog_theme := Theme.new()
	dialog_theme.default_font = BODY_FONT
	dialog_theme.default_font_size = 18
	dialog_theme.set_constant("buttons_separation", "AcceptDialog", 20)
	var frame := _style(INK, Color("a88b55"), 32, 28)
	frame.set_border_width_all(2)
	dialog_theme.set_stylebox("panel", "AcceptDialog", frame)
	theme = dialog_theme

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(540, 238)
	content.add_theme_constant_override("separation", 20)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	content.add_child(header)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _style(Color("1e2b3c"), Color("695b42"), 14, 14))
	header.add_child(badge)
	var icon := TextureRect.new()
	icon.texture = CLOCK
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.add_child(icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 4)
	header.add_child(titles)
	var caption := _label("WAY TO HOME", 14, Color("9cabbc"), true)
	titles.add_child(caption)
	titles.add_child(_label("Bắt đầu lượt chơi mới?", 28, GOLD, true))

	var description := _label("Tiến trình hiện tại và các mốc lưu sẽ được đặt lại.\nBạn sẽ bắt đầu hành trình từ Chương 1.", 18, Color("d4dce5"))
	description.add_theme_constant_override("line_spacing", 6)
	content.add_child(description)
	var collection := PanelContainer.new()
	collection.add_theme_stylebox_override("panel", _style(Color("172e35"), Color("35565a"), 16, 12))
	content.add_child(collection)
	var collection_text := VBoxContainer.new()
	collection_text.add_theme_constant_override("separation", 4)
	collection.add_child(collection_text)
	collection_text.add_child(_label("VẪN ĐƯỢC GIỮ", 14, Color("9bc7b7"), true))
	collection_text.add_child(_label("Những kết thúc bạn đã sưu tập", 18, Color("d1e4dd")))
	# Dựng đủ nội dung trước khi dialog tính kích thước tối thiểu.
	add_child(content)

	_style_button(get_ok_button(), true)
	_style_button(get_cancel_button(), false)
	var button_bar := get_ok_button().get_parent() as HBoxContainer
	button_bar.add_theme_constant_override("separation", 16)
	# Spacer không giãn, để hai nút chia đều chiều ngang khung.
	for child in button_bar.get_children(true):
		if child is Control and not child is BaseButton:
			child.size_flags_horizontal = Control.SIZE_FILL
	get_cancel_button().tooltip_text = "Giữ tiến trình hiện tại (Esc)"
	get_ok_button().tooltip_text = "Đặt lại tiến trình và chơi từ Chương 1"


func _label(value: String, font_size: int, color: Color, pixel: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", PIXEL_FONT if pixel else BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style(fill: Color, border: Color, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.anti_aliasing = false
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


func _style_button(button: Button, primary: bool) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK if primary else Color("e0e7ed"))
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else Color("1c2c40"), GOLD if primary else Color("4a6076"), 20, 14))
	button.add_theme_stylebox_override("hover", _style(Color("ffe1a4") if primary else Color("293e54"), GOLD, 20, 14))
	button.add_theme_stylebox_override("pressed", _style(Color("c4a66e") if primary else Color("132134"), GOLD, 20, 14))
	var focus := _style(Color.TRANSPARENT, Color("fff0ca"), 0, 0)
	focus.set_border_width_all(2)
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	button.add_theme_stylebox_override("focus", focus)
