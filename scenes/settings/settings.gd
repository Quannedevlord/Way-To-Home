
extends Control
## Lớp phủ cài đặt âm lượng nhạc/SFX và toàn màn hình, hoạt động cả khi game pause.
## Các hàm static cũng áp dụng cài đặt lúc vào menu/chapter mà không cần mở giao diện.

## Lưu tùy chọn riêng với save cốt truyện để chơi mới vẫn giữ cài đặt của người chơi.
const SETTINGS_PATH := "user://settings.cfg"

const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_FULLSCREEN := false

@export var close_button: TextureButton
@export var music_slider: HSlider
@export var sfx_slider: HSlider
@export var fullscreen_toggle: CheckButton
@export var returnMainMenu_button: Button

# Giữ nút đang dùng trước khi mở để đóng cài đặt xong có thể tiếp tục bằng bàn phím.
var _previous_focus: Control


## Khởi tạo cài đặt, nối các nút giao diện và nạp giá trị đã lưu.
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _previous_focus = get_viewport().gui_get_focus_owner()

    if close_button:
        close_button.process_mode = Node.PROCESS_MODE_ALWAYS
        close_button.pressed.connect(_on_close_pressed)

    if returnMainMenu_button:
        returnMainMenu_button.process_mode = Node.PROCESS_MODE_ALWAYS
        returnMainMenu_button.pressed.connect(_on_return_to_main_menu_pressed)

    if music_slider:
        music_slider.value_changed.connect(_on_music_volume_changed)

    if sfx_slider:
        sfx_slider.value_changed.connect(_on_sfx_volume_changed)

    if fullscreen_toggle:
        fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)

    _load_settings()
    if close_button:
        close_button.tooltip_text = "Đóng cài đặt (Esc)"
        close_button.grab_focus()


## Esc đóng lớp phủ, kể cả khi minigame đang tạm dừng ở phía dưới.
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo \
            and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
        get_viewport().set_input_as_handled()
        _on_close_pressed()


## Bỏ tạm dừng trò chơi và đóng cửa sổ cài đặt.
func _on_close_pressed() -> void:
    GameManager.set_paused(false)
    if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
        _previous_focus.grab_focus()
    queue_free()


## Bỏ tạm dừng, đóng cài đặt và chuyển về menu chính.
func _on_return_to_main_menu_pressed() -> void:
    GameManager.set_paused(false)
    queue_free()
    GameManager.change_scene("res://scenes/main_menu/main_menu.tscn")


## Cập nhật âm lượng nhạc theo thanh trượt rồi lưu cài đặt.
func _on_music_volume_changed(value: float) -> void:
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index("Music"),
        linear_to_db(value)
    )
    _save_settings()


## Cập nhật âm lượng hiệu ứng âm thanh theo thanh trượt rồi lưu cài đặt.
func _on_sfx_volume_changed(value: float) -> void:
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index("SFX"),
        linear_to_db(value)
    )
    _save_settings()


## Áp dụng trạng thái toàn màn hình đã chọn rồi lưu cài đặt.
func _on_fullscreen_toggled(toggled_on: bool) -> void:
    _apply_fullscreen_setting(toggled_on)
    _save_settings()


## Ghi các giá trị hiện tại của thanh trượt và tùy chọn hiển thị vào tệp.
func _save_settings() -> void:
    var config := ConfigFile.new()

    if music_slider:
        config.set_value("audio", "music", music_slider.value)

    if sfx_slider:
        config.set_value("audio", "sfx", sfx_slider.value)

    if fullscreen_toggle:
        config.set_value(
            "display",
            "fullscreen",
            fullscreen_toggle.button_pressed
        )

    var error := config.save(SETTINGS_PATH)

    if error != OK:
        push_warning("Không thể lưu Settings: " + str(error))


## Đọc cài đặt từ tệp, cập nhật giao diện và áp dụng chúng vào trò chơi.
func _load_settings() -> void:
    var config := ConfigFile.new()
    config.load(SETTINGS_PATH)

    var music_volume: float = config.get_value(
        "audio", "music", DEFAULT_MUSIC_VOLUME
    )

    var sfx_volume: float = config.get_value(
        "audio", "sfx", DEFAULT_SFX_VOLUME
    )

    var fullscreen_enabled: bool = config.get_value(
        "display", "fullscreen", DEFAULT_FULLSCREEN
    )

    # Nạp UI không phát signal, tránh ghi đè file cài đặt trong lúc mới đọc được một phần.
    if music_slider:
        music_slider.set_value_no_signal(music_volume)

    if sfx_slider:
        sfx_slider.set_value_no_signal(sfx_volume)

    if fullscreen_toggle:
        fullscreen_toggle.set_pressed_no_signal(fullscreen_enabled)

    _apply_fullscreen_setting(fullscreen_enabled)
    _apply_audio_settings(music_volume, sfx_volume)


## Chuyển cửa sổ giữa chế độ toàn màn hình và cửa sổ thường.
static func _apply_fullscreen_setting(fullscreen_enabled: bool) -> void:
    var window_mode := (
        DisplayServer.WINDOW_MODE_FULLSCREEN
        if fullscreen_enabled
        else DisplayServer.WINDOW_MODE_WINDOWED
    )

    DisplayServer.window_set_mode(window_mode)


## Đọc và áp dụng cài đặt đã lưu; có thể gọi từ màn hình khác lúc khởi động.
static func apply_saved_audio_settings() -> void:
    var config := ConfigFile.new()
    config.load(SETTINGS_PATH)

    var music_volume: float = config.get_value(
        "audio", "music", DEFAULT_MUSIC_VOLUME
    )

    var sfx_volume: float = config.get_value(
        "audio", "sfx", DEFAULT_SFX_VOLUME
    )

    var fullscreen_enabled: bool = config.get_value(
        "display", "fullscreen", DEFAULT_FULLSCREEN
    )

    _apply_fullscreen_setting(fullscreen_enabled)
    _apply_audio_settings(music_volume, sfx_volume)


## Chuyển âm lượng tuyến tính sang decibel và áp dụng cho các bus âm thanh.
static func _apply_audio_settings(
    music_volume: float,
    sfx_volume: float
) -> void:
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index("Music"),
        linear_to_db(music_volume)
    )

    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index("SFX"),
        linear_to_db(sfx_volume)
    )
