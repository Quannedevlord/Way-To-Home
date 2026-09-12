extends Control

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_FULLSCREEN := false

@export var close_button: TextureButton
@export var music_slider: HSlider
@export var sfx_slider: HSlider
@export var fullscreen_toggle: CheckButton
@export var returnMainMenu_button: Button


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	returnMainMenu_button.pressed.connect(_on_return_to_main_menu_pressed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)

	_load_settings()


func _on_close_pressed() -> void:
	queue_free()


func _on_return_to_main_menu_pressed() -> void:
	queue_free()
	GameManager.change_scene("res://scenes/main_menu/main_menu.tscn")


func _on_music_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))
	_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))
	_save_settings()


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	_apply_fullscreen_setting(toggled_on)
	_save_settings()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_slider.value)
	config.set_value("audio", "sfx", sfx_slider.value)
	config.set_value("display", "fullscreen", fullscreen_toggle.button_pressed)
	config.save("user://settings.cfg")


func _load_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)

	var music_volume: float = config.get_value("audio", "music", DEFAULT_MUSIC_VOLUME)
	var sfx_volume: float = config.get_value("audio", "sfx", DEFAULT_SFX_VOLUME)
	var fullscreen_enabled: bool = config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN)
	music_slider.set_value_no_signal(music_volume)
	sfx_slider.set_value_no_signal(sfx_volume)
	fullscreen_toggle.set_pressed_no_signal(fullscreen_enabled)
	_apply_fullscreen_setting(fullscreen_enabled)
	_apply_audio_settings(music_volume, sfx_volume)


static func _apply_fullscreen_setting(fullscreen_enabled: bool) -> void:
	var window_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(window_mode)


static func apply_saved_audio_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	var music_volume: float = config.get_value("audio", "music", DEFAULT_MUSIC_VOLUME)
	var sfx_volume: float = config.get_value("audio", "sfx", DEFAULT_SFX_VOLUME)
	var fullscreen_enabled: bool = config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN)
	_apply_fullscreen_setting(fullscreen_enabled)
	_apply_audio_settings(music_volume, sfx_volume)


static func _apply_audio_settings(music_volume: float, sfx_volume: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))
