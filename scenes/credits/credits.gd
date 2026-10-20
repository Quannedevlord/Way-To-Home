extends Control
## Dựng và cuộn danh sách cảm ơn từ CreditEntry; kết thúc bằng fade rồi về menu chính.
## Chỉnh nội dung/thứ tự trong credit_entries của credits.tscn qua Inspector.

@export_group("Credits")
## Mỗi mục gồm Text ở trên và Image ở dưới; các mục cuộn theo đúng thứ tự danh sách.
@export var credit_entries: Array[CreditEntry] = []
## Font của các đoạn chữ; cấu hình tại node Credits, không cần Label mẫu trong scene.
@export var credits_font: Font = preload("res://assets/backgrounds/fonts/dearpix-1-94.otf")
## Cỡ chữ dùng chung cho các mục credits.
@export_range(1, 128, 1) var credits_font_size: int = 30
## Kích thước tối đa của mỗi ảnh (pixel); ảnh luôn giữ nguyên tỉ lệ.
@export var image_max_size := Vector2(640.0, 360.0)
## Tốc độ cuộn của cả chữ và ảnh, tính bằng pixel mỗi giây.
@export_range(1.0, 500.0, 1.0) var scroll_speed: float = 50.0

@onready var credits_content: VBoxContainer = $CreditsContent
@onready var fade_overlay: ColorRect = $FadeOverlay

var transition_started: bool = false


## Tạo các mục chữ–ảnh đã gán trong Inspector rồi chờ cập nhật chiều cao của khung credits.
func _ready() -> void:
	set_process(false)
	_build_credit_entries()
	if credits_content.get_child_count() == 0:
		# Danh sách rỗng vẫn trở về menu, không để người chơi chờ credits trống.
		transition_started = true
		call_deferred("_fade_out_and_return_to_main_menu")
		return
	await get_tree().process_frame
	set_process(true)


## Dựng Text → Image cho từng CreditEntry; bỏ qua mục rỗng và trường chưa được gán.
## Chữ được tạo trực tiếp từ dữ liệu; node CreditsText cũ chỉ dùng nếu scene vẫn còn nó.
func _build_credit_entries() -> void:
	if credit_entries.is_empty():
		return
	var legacy_text := credits_content.get_node_or_null("CreditsText") as Label
	if legacy_text != null:
		legacy_text.hide()
	var has_content := false
	for entry in credit_entries:
		if entry == null:
			continue
		if not entry.text.is_empty():
			_append_credit_text(entry.text)
			has_content = true
		if entry.image != null:
			has_content = _append_credit_image(entry.image) or has_content
	if not has_content and legacy_text != null:
		legacy_text.show()


## Tạo đoạn chữ căn giữa bằng font/cỡ chữ trong Inspector, rồi thêm vào khung cuộn.
## Không phụ thuộc vào node Label mẫu, nên xóa CreditsText cũ vẫn chạy bình thường.
func _append_credit_text(message: String) -> void:
	var text := Label.new()
	text.name = "CreditText"
	text.text = message
	text.custom_minimum_size.x = 335.0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if credits_font != null:
		text.add_theme_font_override("font", credits_font)
	text.add_theme_font_size_override("font_size", credits_font_size)
	credits_content.add_child(text)


## Thêm ảnh dưới chữ của mục hiện tại, giữ tỉ lệ trong image_max_size và căn giữa.
## Trả false nếu ảnh không có kích thước hợp lệ; true khi đã thêm vào khung cuộn.
func _append_credit_image(texture: Texture2D) -> bool:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var available_size := Vector2(maxf(image_max_size.x, 1.0), maxf(image_max_size.y, 1.0))
	var image_scale := minf(available_size.x / texture_size.x, available_size.y / texture_size.y)
	var image := TextureRect.new()
	image.name = "CreditImage"
	image.texture = texture
	image.custom_minimum_size = texture_size * image_scale
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_content.add_child(image)
	return true


## Cuộn cả khung chữ và ảnh; chỉ chuyển cảnh khi phần cuối của khung đã ra khỏi màn hình.
func _process(delta: float) -> void:
	credits_content.position.y -= scroll_speed * delta

	var content_bottom := credits_content.position.y + credits_content.size.y
	if not transition_started and content_bottom <= 0.0:
		transition_started = true
		_fade_out_and_return_to_main_menu()


## Làm tối màn hình rồi chuyển về menu chính sau khi hiệu ứng kết thúc.
func _fade_out_and_return_to_main_menu() -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 1.0, 3.0)
	await fade_tween.finished
	GameManager.change_scene(GameManager.MAIN_MENU_PATH)
