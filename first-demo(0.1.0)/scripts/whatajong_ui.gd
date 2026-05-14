extends RefCounted
class_name WhatajongUI

const PRIMARY_FONT: Font = preload("res://whatajong-main/src/renderer/assets/BraveGates.otf")

const COLOR_BONE := Color(0.95, 0.91, 0.82, 0.88)
const COLOR_DOT := Color(0.22, 0.43, 0.40, 1.0)
const COLOR_CRACK := Color(0.65, 0.46, 0.25, 1.0)
const COLOR_BAM := Color(0.34, 0.49, 0.29, 1.0)
const COLOR_TEXT := Color(0.17, 0.12, 0.08, 1.0)
const COLOR_TEXT_SOFT := Color(0.26, 0.20, 0.14, 0.92)
const COLOR_LIGHT_TEXT := Color(0.97, 0.95, 0.90, 1.0)
const COLOR_SHADOW := Color(0.03, 0.03, 0.03, 0.22)
const FONT_SIZE_TITLE := 44
const FONT_SIZE_SUBTITLE := 30
const FONT_SIZE_BODY := 24
const FONT_SIZE_SMALL := 20
const FONT_SIZE_BUTTON := 24


static func apply_panel(panel, accent: Color = COLOR_DOT, fill: Color = COLOR_BONE, radius: int = 26, shadow_size: int = 24) -> void:
	panel.add_theme_stylebox_override("panel", _make_panel_style(fill, accent, radius, shadow_size))


static func apply_button(button: BaseButton, accent: Color, fill_alpha: float = 0.92, font_size: int = FONT_SIZE_BUTTON) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", PRIMARY_FONT)
	if font_size > 0:
		button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", COLOR_LIGHT_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_LIGHT_TEXT)
	button.add_theme_color_override("font_hover_pressed_color", COLOR_LIGHT_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_LIGHT_TEXT)
	button.add_theme_color_override("font_focus_color", COLOR_LIGHT_TEXT)
	button.add_theme_constant_override("h_separation", 10)
	button.add_theme_stylebox_override("normal", _make_button_style(accent.darkened(0.08), accent.darkened(0.36), fill_alpha))
	button.add_theme_stylebox_override("hover", _make_button_style(accent.lightened(0.08), accent.darkened(0.24), fill_alpha))
	button.add_theme_stylebox_override("pressed", _make_button_style(accent.darkened(0.18), accent.darkened(0.42), fill_alpha))
	button.add_theme_stylebox_override("focus", _make_button_style(accent.lightened(0.02), accent.darkened(0.26), fill_alpha))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.32, 0.34, 0.36, 0.72), Color(0.17, 0.18, 0.20, 0.82), 0.72))


static func apply_display_font(control: Control, font_size: int = 0) -> void:
	control.add_theme_font_override("font", PRIMARY_FONT)
	if font_size > 0:
		control.add_theme_font_size_override("font_size", font_size)


static func tint_label(label: Label, color: Color = COLOR_TEXT) -> void:
	label.add_theme_color_override("font_color", color)


static func tint_body_text(label: Label, color: Color = COLOR_TEXT_SOFT, font_size: int = 0) -> void:
	label.add_theme_color_override("font_color", color)
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)


static func tint_rich_text(label: RichTextLabel, color: Color = COLOR_TEXT_SOFT) -> void:
	label.add_theme_color_override("default_color", color)


static func tint_toggle(toggle: BaseButton, color: Color = COLOR_TEXT_SOFT) -> void:
	toggle.add_theme_color_override("font_color", color)
	toggle.add_theme_color_override("font_hover_color", color)
	toggle.add_theme_color_override("font_pressed_color", color)
	toggle.add_theme_color_override("font_focus_color", color)


static func _make_panel_style(fill: Color, accent: Color, radius: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent.darkened(0.25)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func _make_button_style(fill: Color, border: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill.r, fill.g, fill.b, alpha)
	style.border_color = border
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 9
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.shadow_color = Color(0.03, 0.03, 0.03, 0.18)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
