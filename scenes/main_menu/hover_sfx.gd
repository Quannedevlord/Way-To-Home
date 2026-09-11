extends Node

@export var hover_sound: AudioStream

var hover_player: AudioStreamPlayer


func _ready() -> void:
	# Tạo player riêng để âm thanh hover chạy qua bus SFX.
	hover_player = AudioStreamPlayer.new()
	hover_player.stream = hover_sound
	hover_player.bus = "SFX"
	add_child(hover_player)

	# Tự nối tất cả Button trong menu, đồng bộ với click_sfx.gd.
	for button in get_parent().find_children("*", "Button", true, false):
		if not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)


func _on_button_hover() -> void:
	if hover_player.stream:
		hover_player.play()
	