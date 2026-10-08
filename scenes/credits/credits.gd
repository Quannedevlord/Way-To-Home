extends Control

@onready var credits_text: Label = $CreditsText
@onready var fade_overlay: ColorRect = $FadeOverlay

var scroll_speed: float = 50.0
var fade_started: bool = false


func _process(delta: float) -> void:
	credits_text.position.y -= scroll_speed * delta

	var text_bottom := credits_text.position.y + credits_text.size.y
	var fade_start := get_viewport_rect().size.y * 0.35
	if not fade_started and text_bottom <= fade_start:
		fade_started = true
		var fade_tween := create_tween()
		fade_tween.tween_property(fade_overlay, "color:a", 1.0, 3.0)

