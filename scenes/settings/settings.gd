extends Control

@export var close_button: Button
@export var master_slider: HSlider
@export var music_slider: HSlider
@export var sfx_slider: HSlider
@export var fullscreen_toggle: CheckButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)

	_load_settings()


func _on_close_pressed() -> void:
	queue_free()


func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	_save_settings()


func _on_music_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))
	_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))
	_save_settings()


func _on_fullscreen_toggled(is_on: bool) -> void:
	if is_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_slider.value)
	config.set_value("audio", "music", music_slider.value)
	config.set_value("audio", "sfx", sfx_slider.value)
	config.set_value("display", "fullscreen", fullscreen_toggle.button_pressed)
	config.save("user://settings.cfg")


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return  # Chưa từng lưu trước đó, giữ giá trị mặc định trên slider

	master_slider.set_value_no_signal(config.get_value("audio", "master", 1.0))
	music_slider.set_value_no_signal(config.get_value("audio", "music", 1.0))
	sfx_slider.set_value_no_signal(config.get_value("audio", "sfx", 1.0))
	fullscreen_toggle.set_pressed_no_signal(config.get_value("display", "fullscreen", false))

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_slider.value))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_slider.value))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_slider.value))
