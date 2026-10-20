extends Node
## Gắn dưới một màn hình UI để phát âm thanh hover/click cho các BaseButton con.
## Chỉ quét nút khi _ready(); nút tạo động về sau cần được nối sự kiện riêng.

@export_category("UI Sounds")
## Âm thanh khi con trỏ đi vào nút; để trống sẽ không phát tiếng hover.
@export var hover_sound: AudioStream
## Âm thanh khi nhấn nút; cả hai player đều đi qua bus SFX.
@export var click_sound: AudioStream

var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer


## Tạo hai player để hover và click phát độc lập, rồi nối các nút đang có dưới node cha.
func _ready() -> void:
	# Tạo AudioStreamPlayer cho Hover
	hover_player = AudioStreamPlayer.new()
	hover_player.stream = hover_sound
	hover_player.bus = "SFX"
	add_child(hover_player)

	# Tạo AudioStreamPlayer cho Click
	click_player = AudioStreamPlayer.new()
	click_player.stream = click_sound
	click_player.bus = "SFX"
	add_child(click_player)

	# Tìm tất cả Button / TextureButton
	for button in get_parent().find_children("*", "BaseButton", true, false):

		# Hover
		if not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)

		# Click
		if not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed)

## Phát tiếng hover nếu đã gán stream, dùng chung cho Button và TextureButton.
func _on_button_hover() -> void:
	if hover_player.stream:
		hover_player.play()


## Phát tiếng nhấn nút nếu đã gán stream, kể cả thao tác kích hoạt bằng bàn phím.
func _on_button_pressed() -> void:
	if click_player.stream:
		click_player.play()

