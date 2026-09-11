extends MarginContainer

const BUBBLE_LEFT := Color(0.30, 0.30, 0.30, 1.0)
const BUBBLE_RIGHT := Color(0.29, 0.47, 0.50, 1.0)
const BUBBLE_NARRATION := Color(0.16, 0.16, 0.18, 0.9)
const NAME_COLOR := Color(0.72, 0.72, 0.74, 1.0)
const AVATAR_SIZE := 56
const BUBBLE_RADIUS := 14
const MAX_BUBBLE_WIDTH := 420

var _font: Font


func _ready() -> void:
	add_theme_constant_override("margin_left", 18)
	add_theme_constant_override("margin_right", 18)
	add_theme_constant_override("margin_top", 4)
	add_theme_constant_override("margin_bottom", 4)


func set_font(font: Font) -> void:
	_font = font


func setup_dialogue(speaker: String, message: String, avatar_tex: Texture2D, align_right: bool, compact: bool = false) -> void:
	if avatar_tex == null:
		avatar_tex = _make_placeholder_avatar()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)

	var bubble_color := BUBBLE_RIGHT if align_right else BUBBLE_LEFT
	var message_col := _build_message_column(speaker, message, bubble_color, align_right, compact)
	var avatar := _build_avatar(avatar_tex)
	if compact:
		avatar.modulate.a = 0.0

	if align_right:
		row.alignment = BoxContainer.ALIGNMENT_END
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		row.add_child(message_col)
		row.add_child(avatar)
	else:
		row.add_child(avatar)
		row.add_child(message_col)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)


func setup_narration(message: String) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_bubble_style(BUBBLE_NARRATION, 8))
	var label := _make_label(message, 15, Color(0.78, 0.78, 0.78, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fit_label(label, MAX_BUBBLE_WIDTH)
	panel.add_child(label)
	center.add_child(panel)


func setup_location_divider(location: String) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(center)
	var label := _make_label("— %s —" % location, 13, Color(0.45, 0.45, 0.48, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(label)


func setup_image(texture: Texture2D, align_right: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)

	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.12, 0.16, 0.20, 1.0)
	frame_style.border_color = Color(0.45, 0.78, 0.82, 0.85)
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(16)
	frame_style.content_margin_left = 6
	frame_style.content_margin_top = 6
	frame_style.content_margin_right = 6
	frame_style.content_margin_bottom = 6
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.custom_minimum_size = Vector2(360, 220)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var tex_rect := TextureRect.new()
	tex_rect.texture = texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.custom_minimum_size = Vector2(348, 208)
	frame.add_child(tex_rect)

	if align_right:
		row.alignment = BoxContainer.ALIGNMENT_END
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		row.add_child(frame)
		row.add_child(_avatar_spacer())
	else:
		row.add_child(_avatar_spacer())
		row.add_child(frame)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)


func _avatar_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	return spacer


func _build_message_column(speaker: String, message: String, bubble_color: Color, align_right: bool, compact: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if not compact:
		var name_label := _make_label(speaker, 13, NAME_COLOR)
		if align_right:
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(name_label)

	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _make_bubble_style(bubble_color, BUBBLE_RADIUS))
	var msg_label := _make_label(message, 17, Color(1, 1, 1, 1.0))
	_fit_label(msg_label, MAX_BUBBLE_WIDTH)
	bubble.add_child(msg_label)
	col.add_child(bubble)
	return col


func _build_avatar(avatar_tex: Texture2D) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.clip_children = Control.CLIP_CHILDREN_ONLY
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = Color(0.18, 0.18, 0.20, 1.0)
	avatar_style.set_corner_radius_all(int(AVATAR_SIZE / 2.0))
	panel.add_theme_stylebox_override("panel", avatar_style)
	wrapper.add_child(panel)

	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.texture = avatar_tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.add_child(tex_rect)
	return wrapper


func _make_bubble_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	return style


func _make_placeholder_avatar() -> Texture2D:
	var img := Image.create(AVATAR_SIZE, AVATAR_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.28, 0.28, 0.30, 1.0))
	var cx := AVATAR_SIZE * 0.5
	var cy := AVATAR_SIZE * 0.38
	for y in range(AVATAR_SIZE):
		for x in range(AVATAR_SIZE):
			var dx := (x - cx) / (AVATAR_SIZE * 0.18)
			var dy := (y - cy) / (AVATAR_SIZE * 0.18)
			if dx * dx + dy * dy <= 1.0 and y < AVATAR_SIZE * 0.55:
				img.set_pixel(x, y, Color(0.42, 0.42, 0.45, 1.0))
			var body_dx := (x - cx) / (AVATAR_SIZE * 0.28)
			var body_dy := (y - AVATAR_SIZE * 0.82) / (AVATAR_SIZE * 0.28)
			if body_dx * body_dx + body_dy * body_dy <= 1.0 and y > AVATAR_SIZE * 0.58:
				img.set_pixel(x, y, Color(0.42, 0.42, 0.45, 1.0))
	return ImageTexture.create_from_image(img)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _font:
		label.add_theme_font_override("font", _font)
	return label


func _fit_label(label: Label, max_w: float) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if label.get_minimum_size().x > max_w:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = max_w
