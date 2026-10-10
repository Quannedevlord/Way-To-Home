extends Node

@export_category("UI Sounds")
@export var hover_sound: AudioStream
@export var click_sound: AudioStream

var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer


func _ready() -> void:
	# ==============================
	# Tạo AudioStreamPlayer cho Hover
	# ==============================
	hover_player = AudioStreamPlayer.new()
	hover_player.stream = hover_sound
	hover_player.bus = "SFX"
	add_child(hover_player)

	# ==============================
	# Tạo AudioStreamPlayer cho Click
	# ==============================
	click_player = AudioStreamPlayer.new()
	click_player.stream = click_sound
	click_player.bus = "SFX"
	add_child(click_player)

	# ==============================
	# Tìm tất cả Button / TextureButton
	# ==============================
	for button in get_parent().find_children("*", "BaseButton", true, false):

		# Hover
		if not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)

		# Click
		if not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed)


# ==============================
# Khi rê chuột vào Button
# ==============================
func _on_button_hover() -> void:
	if hover_player.stream:
		hover_player.play()


# ==============================
# Khi click Button
# ==============================
func _on_button_pressed() -> void:
	if click_player.stream:
		click_player.play()

