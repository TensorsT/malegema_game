extends Control

@onready var main_panel: Panel = $MainPanel
@onready var title_label: Label = $MainPanel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $MainPanel/VBoxContainer/SubtitleLabel
@onready var start_button: Button = $MainPanel/VBoxContainer/StartButton
@onready var help_button: Button = $MainPanel/VBoxContainer/HelpButton
@onready var settings_button: Button = $MainPanel/VBoxContainer/SettingsButton
@onready var help_popup: PopupPanel = $HelpPopup
@onready var settings_popup: PopupPanel = $SettingsPopup
@onready var status_label: Label = $MainPanel/VBoxContainer/StatusLabel
@onready var help_title: Label = $HelpPopup/MarginContainer/VBoxContainer/HelpTitle
@onready var help_text: RichTextLabel = $HelpPopup/MarginContainer/VBoxContainer/HelpText
@onready var close_help_button: Button = $HelpPopup/MarginContainer/VBoxContainer/CloseHelpButton
@onready var settings_title: Label = $SettingsPopup/MarginContainer/VBoxContainer/SettingsTitle
@onready var music_label: Label = $SettingsPopup/MarginContainer/VBoxContainer/MusicRow/MusicLabel
@onready var music_slider: HSlider = $SettingsPopup/MarginContainer/VBoxContainer/MusicRow/MusicSlider
@onready var fullscreen_checkbox: CheckBox = $SettingsPopup/MarginContainer/VBoxContainer/FullscreenCheck
@onready var close_settings_button: Button = $SettingsPopup/MarginContainer/VBoxContainer/CloseSettingsButton

func _ready() -> void:
	_apply_whatajong_ui()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	music_slider.value = 70.0
	fullscreen_checkbox.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func _on_start_button_pressed() -> void:
	status_label.text = "进入最小可玩局..."
	RunManager.start_new_run()
	RunManager.enter_stage(RunManager.STAGE_GAME)

func _on_help_button_pressed() -> void:
	help_popup.popup_centered()

func _on_settings_button_pressed() -> void:
	settings_popup.popup_centered()

func _on_close_help_pressed() -> void:
	help_popup.hide()

func _on_close_settings_pressed() -> void:
	settings_popup.hide()

func _on_music_slider_value_changed(value: float) -> void:
	# 占位音量逻辑，可替换为 AudioServer 总线音量。
	print("Music volume:", value)

func _on_fullscreen_check_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_whatajong_ui() -> void:
	WhatajongUI.apply_panel(main_panel, WhatajongUI.COLOR_CRACK, Color(0.95, 0.92, 0.84, 0.82), 30, 28)
	WhatajongUI.apply_panel(help_popup, WhatajongUI.COLOR_DOT, Color(0.96, 0.93, 0.86, 0.92), 24, 20)
	WhatajongUI.apply_panel(settings_popup, WhatajongUI.COLOR_BAM, Color(0.96, 0.93, 0.86, 0.92), 24, 20)

	WhatajongUI.apply_display_font(title_label)
	WhatajongUI.apply_display_font(start_button)
	WhatajongUI.apply_display_font(help_button)
	WhatajongUI.apply_display_font(settings_button)
	WhatajongUI.apply_display_font(help_title)
	WhatajongUI.apply_display_font(settings_title)
	WhatajongUI.apply_display_font(close_help_button)
	WhatajongUI.apply_display_font(close_settings_button)

	WhatajongUI.apply_button(start_button, WhatajongUI.COLOR_CRACK)
	WhatajongUI.apply_button(help_button, WhatajongUI.COLOR_DOT)
	WhatajongUI.apply_button(settings_button, WhatajongUI.COLOR_BAM)
	WhatajongUI.apply_button(close_help_button, WhatajongUI.COLOR_DOT, 0.88)
	WhatajongUI.apply_button(close_settings_button, WhatajongUI.COLOR_BAM, 0.88)

	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_CRACK.darkened(0.35))
	WhatajongUI.tint_body_text(subtitle_label)
	WhatajongUI.tint_body_text(status_label)
	WhatajongUI.tint_label(help_title, WhatajongUI.COLOR_DOT.darkened(0.35))
	WhatajongUI.tint_label(settings_title, WhatajongUI.COLOR_BAM.darkened(0.35))
	WhatajongUI.tint_body_text(music_label)
	WhatajongUI.tint_toggle(fullscreen_checkbox)
	WhatajongUI.tint_rich_text(help_text)
