extends Control
## Sổ tay tạo hoàn toàn bằng code, dùng trong chapter và menu chính.
## Hiển thị manh mối, việc chuẩn bị, kết thúc đã xem và các mốc có thể tải lại.

const FONT := preload("res://assets/backgrounds/fonts/dearpix-1-94.otf")
const FLAGS := {
	"memory_verified": "Hỏi gia đình để hiểu rõ lời nhắn cuối của Vy",
	"farewell_ready": "Để Vy tự viết lời chào gia đình",
	"anchor_ready": "Giúp Kiên thử cách tỉnh lại",
}
const ENDINGS := {"E1": "Nhà vẫn chờ", "E2": "Lời chào bên cửa sổ", "E3": "Người trở về một mình", "E4": "Buổi chiều không tắt"}
# Diễn giải cả ghi chú trong save cũ để người chơi hiểu thông tin đến từ đâu.
const SOURCES := {
	"Quan sát ngoài đời": "Kiên tìm thấy ngoài đời.",
	"Kể lại trong mơ": "Vy kể trong mơ. Kiên chưa kiểm tra ngoài đời.",
	"Ký ức chưa kiểm chứng": "Vy nhớ lại trong mơ. Kiên chưa kiểm tra ngoài đời.",
	"Gợi ý chưa thử": "Thầy bói gợi ý. Kiên chưa thử cách này.",
	"Ảnh Thư gửi": "Thư gửi ảnh cho Kiên.",
	"Cô giáo và gia đình xác nhận": "Cô giáo và gia đình Vy đã xác nhận.",
	"Gia đình xác nhận": "Gia đình Vy đã xác nhận.",
	"Gia đình xác nhận trực tiếp": "Kiên đã nghe gia đình Vy xác nhận.",
	"Gặp trong mơ, chép từ trí nhớ": "Kiên nhớ và chép lại lời Vy nói trong mơ.",
	"Đã thử trong truyện": "Kiên đã thử cách này và tỉnh lại được.",
}
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
	open_button.text = "Sổ tay của Kiên"
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
	restore_dialog.title = "Chơi lại từ đoạn đã lưu?"
	restore_dialog.ok_button_text = "Quay lại đoạn này"
	restore_dialog.cancel_button_text = "Hủy"
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
	add_text("Sổ tay ghi lại những điều Kiên tìm hiểu được. Mỗi ghi chú đều cho biết thông tin đến từ đâu.")
	if GameManager.story_checkpoints.has("preparation"):
		add_text("Việc cần làm trước lần gặp Vy cuối cùng", Color(0.97, 0.81, 0.48))
		for key in FLAGS:
			add_text("%s: %s" % ["Đã làm xong" if state.get(key, false) else "Chưa làm xong", FLAGS[key]])
		add_text("Để làm các việc còn thiếu, bạn có thể chọn chơi lại phần chuẩn bị ở cuối sổ tay.")
	add_text("Những điều Kiên đã ghi lại", Color(0.97, 0.81, 0.48))
	var clues: Dictionary = state.get("clues", {})
	if clues.is_empty():
		add_text("Sổ tay chưa có ghi chú nào. Khi Kiên tìm được đồ vật hoặc biết thêm chuyện mới, nội dung sẽ tự được ghi vào đây.")
	for clue in clues.values():
		var source := str(clue["source"])
		add_text(str(clue["title"]), Color(0.97, 0.81, 0.48))
		add_text(str(clue["text"]) + "\nThông tin từ: " + str(SOURCES.get(source, source)))
	var current_ending := str(state.get("ending_id", ""))
	if not current_ending.is_empty():
		add_text("Kết thúc bạn vừa chọn: " + str(ENDINGS.get(current_ending, current_ending)))
	if not GameManager.seen_endings.is_empty():
		add_text("Những kết thúc bạn đã xem", Color(0.97, 0.81, 0.48))
		for ending in GameManager.seen_endings:
			add_text(str(ENDINGS.get(ending, ending)))
	var focus_buttons: Array[Button] = [close_button]
	if GameManager.story_checkpoints.has("preparation") or GameManager.story_checkpoints.has("final_choice"):
		add_text("Chơi lại từ đoạn đã lưu", Color(0.97, 0.81, 0.48))
		add_text("Chọn một đoạn bên dưới để chơi lại từ đó. Phần đã chơi sau đoạn đó sẽ cần làm lại.")
	for checkpoint in ["preparation", "final_choice"]:
		if not GameManager.story_checkpoints.has(checkpoint):
			continue
		var button := Button.new()
		button.text = "Quay lại phần chuẩn bị ở Chương 4" if checkpoint == "preparation" else "Chọn lại kết thúc ở Chương 5"
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
	var destination := "phần chuẩn bị ở Chương 4" if id == "preparation" else "đoạn chọn kết thúc ở Chương 5"
	restore_dialog.dialog_text = "Bạn sẽ quay lại %s.\nLựa chọn, ghi chú và câu đố sẽ trở về như lúc đó.\nPhần đã chơi sau đoạn này sẽ cần làm lại." % destination
	for connection in restore_dialog.confirmed.get_connections():
		restore_dialog.confirmed.disconnect(connection["callable"])
	restore_dialog.confirmed.connect(func() -> void: GameManager.restore_checkpoint(id))
	restore_dialog.popup_centered(Vector2i(640, 180))
