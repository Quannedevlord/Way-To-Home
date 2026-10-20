extends Control
## Câu đố dùng chung cho chọn chi tiết, xếp thứ tự và nối đường; cấu hình lấy từ event JSON.
## ChapterBase gọi configure() trước khi thêm node, rồi restore_state() nếu đang Continue.

## Phát một lần sau khi người chơi hoàn tất và bấm Tiếp tục; chapter sở hữu việc dọn node.
signal finished(result: Dictionary)

const FONT := preload("res://assets/backgrounds/fonts/Roboto-Light.ttf")
var config: Dictionary = {}
var selected: Array = []
var attempts := 0
var solved := false
# Chặn bấm Tiếp tục nhiều lần trước khi ChapterBase giải phóng instance.
var emitted := false
var assisted := false
var feedback: Label
var progress: Label
var cards: GridContainer
var help_button: Button
var finish_button: Button
var board: Control


## Sao chép cấu hình để không sửa JSON gốc và đổi chỉ số đáp án sang int để so sánh thống nhất.
func configure(value: Dictionary) -> void:
	config = value.duplicate(true)
	var answer: Array = []
	for index in config.get("answer", []):
		answer.append(int(index))
	config["answer"] = answer


## Dựng giao diện từ config, tạo thẻ chọn và thêm bảng nối điểm nếu mode = path.
## Nút trợ giúp chỉ mở sau lần chọn đầu tiên; nút Tiếp tục chờ giải xong câu đố.
func _ready() -> void:
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", 18)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.06, 0.10, 0.99)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 90)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var title := Label.new()
	title.text = str(config.get("title", "Manh mối"))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.56))
	layout.add_child(title)
	var instruction := Label.new()
	instruction.text = str(config.get("instruction", "Chọn các chi tiết phù hợp."))
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(instruction)
	if config.has("image"):
		var illustration := TextureRect.new()
		illustration.texture = load(str(config["image"]))
		illustration.custom_minimum_size.y = 110
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layout.add_child(illustration)
	if config.get("mode", "") == "path":
		board = Control.new()
		board.custom_minimum_size.y = 100
		board.draw.connect(_draw_map)
		board.gui_input.connect(_map_input)
		layout.add_child(board)
	cards = GridContainer.new()
	cards.columns = 2 if config.get("items", []).size() > 3 else 3
	cards.add_theme_constant_override("h_separation", 14)
	cards.add_theme_constant_override("v_separation", 14)
	layout.add_child(cards)
	for index in range(config.get("items", []).size()):
		var button := Button.new()
		button.text = str(config["items"][index])
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(choose.bind(index))
		cards.add_child(button)
	progress = Label.new()
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(progress)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(feedback)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 18)
	layout.add_child(actions)
	help_button = Button.new()
	help_button.text = str(config.get("help_label", "Nhờ giúp hoàn thiện"))
	help_button.custom_minimum_size.y = 48
	help_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_button.pressed.connect(assist)
	actions.add_child(help_button)
	finish_button = Button.new()
	finish_button.text = "Tiếp tục"
	finish_button.custom_minimum_size.y = 48
	finish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finish_button.pressed.connect(finish)
	actions.add_child(finish_button)
	refresh()
	if cards.get_child_count() > 0:
		cards.get_child(0).grab_focus()


## Kiểm tra một thẻ/điểm: mode select chỉ cần thuộc đáp án; order/path phải đúng thứ tự.
## Chọn sai ở chế độ có thứ tự xóa chuỗi đang nối, tăng số lần thử và hiện gợi ý.
func choose(index: int) -> void:
	if solved or emitted or selected.has(index):
		return
	attempts += 1
	var answer: Array = config.get("answer", [])
	var ordered: bool = config.get("mode", "select") in ["order", "path"]
	var correct := answer.has(index)
	if ordered:
		correct = selected.size() < answer.size() and index == int(answer[selected.size()])
	if correct:
		selected.append(index)
		feedback.text = str(config.get("found", "Đã ghi nhận chi tiết này."))
	else:
		feedback.text = str(config.get("hint", "Thử đối chiếu lại các chi tiết nhé."))
		if ordered:
			selected.clear()
	solved = selected.size() == answer.size()
	refresh()


## Sau ít nhất một lần thử, điền đáp án và đánh dấu assisted để người chơi tiếp tục truyện.
## Trợ giúp vẫn trả cùng outcome hoàn thành như tự giải.
func assist() -> void:
	if emitted or attempts == 0:
		return
	selected = config.get("answer", []).duplicate()
	assisted = true
	solved = true
	refresh()


## Đồng bộ thẻ, tiến độ, phản hồi và trạng thái nút từ dữ liệu hiện tại; vẽ lại bản đồ nếu có.
func refresh() -> void:
	if not is_instance_valid(progress):
		return
	var parts: Array[String] = []
	for index in selected:
		parts.append(str(config["items"][int(index)]))
	progress.text = " → ".join(parts) if not parts.is_empty() else "Chưa chọn chi tiết nào. Không có giới hạn thời gian."
	for index in range(cards.get_child_count()):
		var button := cards.get_child(index) as Button
		button.disabled = solved or selected.has(index)
		button.modulate = Color(0.72, 1, 0.83) if selected.has(index) else Color.WHITE
	finish_button.disabled = not solved
	help_button.disabled = solved or attempts == 0
	if solved:
		feedback.text = str(config.get("success", "Đã hoàn tất. Bạn có thể tiếp tục câu chuyện."))
		finish_button.grab_focus()
	elif attempts >= 2:
		feedback.text = str(config.get("hint", "Bạn có thể nhờ giúp hoàn thiện để tiếp tục."))
	if is_instance_valid(board):
		board.queue_redraw()


## Phát kết quả done đúng một lần khi đã giải xong; không tự xóa node đang phát signal.
func finish() -> void:
	if not solved or emitted:
		return
	emitted = true
	finished.emit({"outcome": "done", "assisted": assisted})


## Trả dữ liệu thuần để lưu ván đang dở; sao chép selected để snapshot không bị đổi về sau.
func get_save_state() -> Dictionary:
	return {"selected": selected.duplicate(), "attempts": attempts, "solved": solved, "assisted": assisted}


## Khôi phục lượt chọn, số lần thử và trạng thái giải rồi cập nhật UI; không phát signal hoàn thành.
func restore_state(state: Dictionary) -> void:
	selected = []
	for index in state.get("selected", []):
		selected.append(int(index))
	attempts = int(state.get("attempts", 0))
	solved = bool(state.get("solved", false))
	assisted = bool(state.get("assisted", false))
	refresh()


## Tính tọa độ điểm theo chiều rộng bảng; giãn đều theo chỉ số và đặt cao/thấp xen kẽ.
func _point(index: int) -> Vector2:
	var count: int = config.get("items", []).size()
	return Vector2(75 + index * (board.size.x - 150) / maxf(count - 1, 1), 45 + (16 if index % 2 else -10))


## Vẽ các điểm có số và đường nối theo thứ tự selected; chỉ dùng cho câu đố mode path.
func _draw_map() -> void:
	for index in range(1, selected.size()):
		board.draw_line(_point(int(selected[index - 1])), _point(int(selected[index])), Color(0.94, 0.78, 0.48), 5, true)
	for index in range(config.get("items", []).size()):
		var point := _point(index)
		board.draw_circle(point, 25, Color(0.29, 0.53, 0.54) if not selected.has(index) else Color(0.78, 0.64, 0.35))
		board.draw_string(FONT, point + Vector2(-5, 6), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22)


## Chuyển click, kéo giữ chuột hoặc chạm/kéo cảm ứng gần điểm thành lời gọi choose().
func _map_input(event: InputEvent) -> void:
	var pointer := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = event.position
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		pointer = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pointer = event.position
	elif event is InputEventScreenDrag:
		pointer = event.position
	else:
		return
	for index in range(config.get("items", []).size()):
		if pointer.distance_to(_point(index)) < 34:
			choose(index)
			break
