extends Node

@export var click_sound: AudioStream

var click_player: AudioStreamPlayer


func _ready() -> void:
	# Tạo player riêng để âm thanh click chạy qua bus SFX.
	click_player = AudioStreamPlayer.new()
	click_player.stream = click_sound
	click_player.bus = "SFX"
	add_child(click_player)

	# Tự nối tất cả Button trong menu, tránh phải khai báo từng nút.
	for button in get_parent().find_children("*", "Button", true, false):
		if not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	if click_player.stream:
		click_player.play()
