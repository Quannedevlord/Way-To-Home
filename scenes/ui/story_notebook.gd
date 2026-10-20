extends Control
## Sổ tay tạo hoàn toàn bằng code, dùng trong chapter và menu chính.
## Hiển thị manh mối, việc chuẩn bị, kết thúc đã xem và các mốc có thể tải lại.

const FONT := preload("res://assets/backgrounds/fonts/Roboto-Light.ttf")
const FLAGS := {"memory_verified": "Xác minh lời nhắn", "farewell_ready": "Lời chào do Vy chọn", "anchor_ready": "Thử đường về của Kiên"}
const ENDINGS := {"E1": "Nhà vẫn chờ", "E2": "Lời chào bên cửa sổ", "E3": "Người trở về một mình", "E4": "Buổi chiều không tắt"}
var overlay: ColorRect
var entries: VBoxContainer
var restore_dialog: ConfirmationDialog
var close_button: Button
# Trả quyền điều khiển bàn phím về nút trước đó sau khi đóng sổ.
var previous_focus: Control


## Tạo nút mở, lớp phủ, vùng cuộn nội dung và hộp xác nhận tải mốc; ban đầu đóng sổ.
func _ready() -> void:
	name = "StoryNotebook"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", 18)
	var open_button := Button.new()
	open_button.text = "Sổ tay · Mốc truyện"
	open_button.position = Vector2(20, 18)
	open_button.size = Vector2(218, 40)
	open_button.pressed.connect(open)
	add_child(open_button)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.045, 0.08, 1)
	add_child(overlay)
	overlay.hide()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 38)
	overlay.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var heading := Label.new()
	heading.text = "SỔ TAY CỦA KIÊN"
	heading.add_theme_font_size_override("font_size", 28)
	layout.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	entries = VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 18)
	scroll.add_child(entries)
	close_button = Button.new()
	close_button.text = "Đóng sổ tay"
	close_button.custom_minimum_size.y = 48
	close_button.pressed.connect(close)
	layout.add_child(close_button)
	restore_dialog = ConfirmationDialog.new()
	restore_dialog.title = "Quay lại mốc truyện"
	restore_dialog.dialog_text = "Tải mốc này sẽ thay tiến trình hiện tại bằng trạng thái đã lưu tại mốc, gồm cả lựa chọn và manh mối."
	restore_dialog.ok_button_text = "Tải mốc"
	restore_dialog.cancel_button_text = "Ở lại"
	add_child(restore_dialog)


## Cho chapter biết sổ tay đang mở để tạm chặn đọc thoại, chọn nhánh và Auto.
func is_open() -> bool:
	return overlay.visible


## Thêm một đoạn chữ tự xuống dòng vào sổ; color dùng phân biệt tiêu đề và nội dung.
func add_text(value: String, color := Color(0.9, 0.88, 0.81)) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	entries.add_child(label)


## Dựng lại nội dung từ GameManager mỗi lần mở để phản ánh manh mối/cờ vừa thay đổi.
## Giới hạn vòng focus trong các nút sổ tay và nhớ nút trước đó để khôi phục khi đóng.
func open() -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	var state: Dictionary = GameManager.campaign_state
	if GameManager.story_checkpoints.has("preparation"):
		for key in FLAGS:
			add_text("%s — %s" % [FLAGS[key], "Đã có" if state.get(key, false) else "Còn thiếu"])
	var clues: Dictionary = state.get("clues", {})
	if clues.is_empty():
		add_text("Chưa ghi nhận manh mối. Những điều Kiên tìm thấy sẽ được ghi cùng nguồn thông tin.")
	for clue in clues.values():
		add_text(str(clue["title"]) + " · " + str(clue["source"]), Color(0.97, 0.81, 0.48))
		add_text(str(clue["text"]))
	if not str(state.get("ending_id", "")).is_empty():
		add_text("Kết thúc vừa chọn: " + str(state["ending_id"]))
	if not GameManager.seen_endings.is_empty():
		add_text("Kết thúc đã xem", Color(0.97, 0.81, 0.48))
		for ending in GameManager.seen_endings:
			add_text(str(ending) + " · " + str(ENDINGS.get(ending, ending)))
	var focus_buttons: Array[Button] = [close_button]
	for checkpoint in ["preparation", "final_choice"]:
		if not GameManager.story_checkpoints.has(checkpoint):
			continue
		var button := Button.new()
		button.text = "Quay lại đầu Chương 4" if checkpoint == "preparation" else "Quay lại lựa chọn cuối"
		button.custom_minimum_size.y = 46
		button.pressed.connect(_ask_restore.bind(checkpoint))
		entries.add_child(button)
		focus_buttons.append(button)
	for index in range(focus_buttons.size()):
		var button := focus_buttons[index]
		var next_path := button.get_path_to(focus_buttons[(index + 1) % focus_buttons.size()])
		var previous_path := button.get_path_to(focus_buttons[(index - 1 + focus_buttons.size()) % focus_buttons.size()])
		button.focus_next = next_path
		button.focus_previous = previous_path
		button.focus_neighbor_bottom = next_path
		button.focus_neighbor_right = next_path
		button.focus_neighbor_top = previous_path
		button.focus_neighbor_left = previous_path
	overlay.show()
	close_button.grab_focus()


## Ẩn sổ và trả focus về control trước đó nếu control vẫn tồn tại.
func close() -> void:
	overlay.hide()
	if is_instance_valid(previous_focus):
		previous_focus.grab_focus()


## Hỏi xác nhận trước khi thay tiến trình bằng mốc id; chỉ nối callback của mốc vừa chọn.
func _ask_restore(id: String) -> void:
	for connection in restore_dialog.confirmed.get_connections():
		restore_dialog.confirmed.disconnect(connection["callable"])
	restore_dialog.confirmed.connect(func() -> void: GameManager.restore_checkpoint(id))
	restore_dialog.popup_centered(Vector2i(640, 180))
