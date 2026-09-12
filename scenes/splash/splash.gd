extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const SPLASH_DURATION := 1.8
const APPEAR_DURATION := 0.7

@onready var nine_patch_rect: NinePatchRect = $Panel/NinePatchRect


func _ready() -> void:
	GlobalMenu.get_node("CanvasLayer").hide()
	nine_patch_rect.pivot_offset = nine_patch_rect.size / 2.0
	nine_patch_rect.modulate.a = 0.0
	nine_patch_rect.scale = Vector2(0.92, 0.92)

	var appear_tween := create_tween().set_parallel()
	appear_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	appear_tween.tween_property(nine_patch_rect, "modulate:a", 1.0, APPEAR_DURATION)
	appear_tween.tween_property(nine_patch_rect, "scale", Vector2.ONE, APPEAR_DURATION)

	await get_tree().create_timer(SPLASH_DURATION).timeout
	var result := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if result != OK:
		push_error("Khong the chuyen den main menu: %s" % error_string(result))
