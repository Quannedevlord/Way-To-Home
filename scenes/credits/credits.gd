extends Control

@onready var credits_text: Label = $CreditsText
@onready var fade_overlay: ColorRect = $FadeOverlay

var scroll_speed: float = 50.0
var transition_started: bool = false


func _process(delta: float) -> void:
	credits_text.position.y -= scroll_speed * delta

	var text_bottom := credits_text.position.y + credits_text.size.y
	if not transition_started and text_bottom <= 0.0:
		transition_started = true
		_fade_out_and_return_to_main_menu()


func _fade_out_and_return_to_main_menu() -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 1.0, 3.0)
	await fade_tween.finished
	GameManager.change_scene(GameManager.MAIN_MENU_PATH)
