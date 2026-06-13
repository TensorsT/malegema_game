extends Control

@onready var main_panel: Panel = $MainPanel
@onready var title_label: Label = $MainPanel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $MainPanel/VBoxContainer/SubtitleLabel
@onready var start_button: Button = $MainPanel/VBoxContainer/StartButton
@onready var help_button: Button = $MainPanel/VBoxContainer/HelpButton
@onready var continue_button: Button = $MainPanel/VBoxContainer/ContinueButton
@onready var settings_button: Button = $MainPanel/VBoxContainer/SettingsButton
@onready var pvp_button: Button = $MainPanel/VBoxContainer/PvPButton
@onready var help_popup: PopupPanel = $HelpPopup
@onready var settings_popup: PopupPanel = $SettingsPopup
@onready var start_options_popup: PopupPanel = $StartOptionsPopup
@onready var start_options_title: Label = $StartOptionsPopup/MarginContainer/VBoxContainer/StartOptionsTitle
@onready var seed_label: Label = $StartOptionsPopup/MarginContainer/VBoxContainer/SeedRow/SeedLabel
@onready var seed_input: LineEdit = $StartOptionsPopup/MarginContainer/VBoxContainer/SeedRow/SeedInput
@onready var seed_start_button: Button = $StartOptionsPopup/MarginContainer/VBoxContainer/SeedStartButton
@onready var no_seed_button: Button = $StartOptionsPopup/MarginContainer/VBoxContainer/NoSeedButton
@onready var tutorial_button: Button = $StartOptionsPopup/MarginContainer/VBoxContainer/TutorialButton
@onready var close_start_options_button: Button = $StartOptionsPopup/MarginContainer/VBoxContainer/CloseStartOptionsButton
@onready var status_label: Label = $MainPanel/VBoxContainer/StatusLabel
@onready var help_title: Label = $HelpPopup/MarginContainer/VBoxContainer/HelpTitle
@onready var help_text: RichTextLabel = $HelpPopup/MarginContainer/VBoxContainer/HelpText
@onready var close_help_button: Button = $HelpPopup/MarginContainer/VBoxContainer/CloseHelpButton
@onready var settings_title: Label = $SettingsPopup/MarginContainer/VBoxContainer/SettingsTitle
@onready var music_label: Label = $SettingsPopup/MarginContainer/VBoxContainer/MusicRow/MusicLabel
@onready var music_slider: HSlider = $SettingsPopup/MarginContainer/VBoxContainer/MusicRow/MusicSlider
@onready var music_select_label: Label = $SettingsPopup/MarginContainer/VBoxContainer/MusicSelectRow/MusicSelectLabel
@onready var music_option: OptionButton = $SettingsPopup/MarginContainer/VBoxContainer/MusicSelectRow/MusicOption
@onready var fullscreen_checkbox: CheckBox = $SettingsPopup/MarginContainer/VBoxContainer/FullscreenCheck
@onready var dev_mode_checkbox: CheckBox = $SettingsPopup/MarginContainer/VBoxContainer/DevModeCheck
@onready var save_status_label: Label = $SettingsPopup/MarginContainer/VBoxContainer/SaveStatusLabel
@onready var close_settings_button: Button = $SettingsPopup/MarginContainer/VBoxContainer/CloseSettingsButton

var _pvp_coming_soon_dialog: AcceptDialog


func _ready() -> void:
	_apply_whatajong_ui()
	_setup_pvp_coming_soon_dialog()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_setup_music_options()
	fullscreen_checkbox.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	dev_mode_checkbox.button_pressed = DevMode.enabled
	start_options_popup.hide()

func _on_start_button_pressed() -> void:
	status_label.text = "选择开始方式：直接开始 / 用种子开始 / 教程。"
	seed_input.text = ""
	start_options_popup.popup_centered()


func _on_seed_start_button_pressed() -> void:
	var seed := _get_seed_text()
	if seed == "":
		status_label.text = "请输入种子后再开始。"
		return
	status_label.text = "使用种子开始新流程..."
	RunManager.start_new_run(seed)
	RunManager.enter_stage(RunManager.STAGE_GAME)
	start_options_popup.hide()


func _on_no_seed_button_pressed() -> void:
	status_label.text = "进入新流程..."
	RunManager.start_new_run()
	RunManager.enter_stage(RunManager.STAGE_GAME)
	start_options_popup.hide()


func _on_tutorial_button_pressed() -> void:
	status_label.text = "进入教程..."
	RunManager.start_tutorial()
	RunManager.enter_stage(RunManager.STAGE_INTRO)
	start_options_popup.hide()


func _on_close_start_options_pressed() -> void:
	start_options_popup.hide()


func _on_continue_button_pressed() -> void:
	status_label.text = "继续游戏..."
	var save_data := SaveManager.load_game()
	if save_data.is_empty():
		status_label.text = "没有存档，开始新游戏..."
		RunManager.start_new_run()
		RunManager.enter_stage(RunManager.STAGE_GAME)
		return
	SaveManager.request_restore()
	RunManager.enter_stage(RunManager.STAGE_GAME)

func _on_help_button_pressed() -> void:
	help_popup.popup_centered()

func _on_settings_button_pressed() -> void:
	_update_save_status_label()
	settings_popup.popup_centered()

func _on_close_help_pressed() -> void:
	help_popup.hide()

func _on_close_settings_pressed() -> void:
	settings_popup.hide()

func _on_music_slider_value_changed(value: float) -> void:
	MusicManager.set_volume_percent(value)


func _on_music_option_item_selected(index: int) -> void:
	var name := music_option.get_item_text(index)
	MusicManager.set_track(name)

func _on_fullscreen_check_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_dev_mode_check_toggled(toggled_on: bool) -> void:
	DevMode.enabled = toggled_on


func _apply_whatajong_ui() -> void:
	WhatajongUI.apply_panel(main_panel, WhatajongUI.COLOR_CRACK, Color(0.95, 0.92, 0.84, 0.82), 30, 28)
	WhatajongUI.apply_panel(help_popup, WhatajongUI.COLOR_DOT, Color(0.96, 0.93, 0.86, 0.92), 24, 20)
	WhatajongUI.apply_panel(settings_popup, WhatajongUI.COLOR_BAM, Color(0.96, 0.93, 0.86, 0.92), 24, 20)
	WhatajongUI.apply_panel(start_options_popup, WhatajongUI.COLOR_CRACK, Color(0.96, 0.93, 0.86, 0.96), 24, 20)

	WhatajongUI.apply_display_font(title_label, 58)
	WhatajongUI.apply_display_font(start_button)
	WhatajongUI.apply_display_font(start_options_title, WhatajongUI.FONT_SIZE_SUBTITLE)
	WhatajongUI.apply_display_font(seed_label, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_display_font(seed_input, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_display_font(seed_start_button)
	WhatajongUI.apply_display_font(no_seed_button)
	WhatajongUI.apply_display_font(tutorial_button)
	WhatajongUI.apply_display_font(close_start_options_button)
	WhatajongUI.apply_display_font(continue_button)
	WhatajongUI.apply_display_font(help_button)
	WhatajongUI.apply_display_font(settings_button)
	WhatajongUI.apply_display_font(pvp_button)
	WhatajongUI.apply_display_font(help_title, WhatajongUI.FONT_SIZE_SUBTITLE)
	WhatajongUI.apply_display_font(settings_title, WhatajongUI.FONT_SIZE_SUBTITLE)
	WhatajongUI.apply_display_font(close_help_button)
	WhatajongUI.apply_display_font(close_settings_button)
	WhatajongUI.apply_display_font(music_label, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_display_font(music_select_label, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_display_font(music_option, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_display_font(fullscreen_checkbox, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_display_font(dev_mode_checkbox, WhatajongUI.FONT_SIZE_SMALL)

	WhatajongUI.apply_button(start_button, WhatajongUI.COLOR_CRACK)
	WhatajongUI.apply_button(seed_start_button, WhatajongUI.COLOR_BAM)
	WhatajongUI.apply_button(no_seed_button, WhatajongUI.COLOR_CRACK)
	WhatajongUI.apply_button(tutorial_button, WhatajongUI.COLOR_DOT)
	WhatajongUI.apply_button(close_start_options_button, WhatajongUI.COLOR_DOT)
	WhatajongUI.apply_button(continue_button, WhatajongUI.COLOR_BAM)
	WhatajongUI.apply_button(help_button, WhatajongUI.COLOR_DOT)
	WhatajongUI.apply_button(settings_button, WhatajongUI.COLOR_BAM)
	WhatajongUI.apply_button(pvp_button, WhatajongUI.COLOR_DOT)
	WhatajongUI.apply_button(close_help_button, WhatajongUI.COLOR_DOT, 0.88)
	WhatajongUI.apply_button(close_settings_button, WhatajongUI.COLOR_BAM, 0.88)

	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_CRACK.darkened(0.35))
	WhatajongUI.tint_label(start_options_title, WhatajongUI.COLOR_CRACK.darkened(0.35))
	WhatajongUI.tint_label(seed_label, WhatajongUI.COLOR_TEXT_SOFT)
	WhatajongUI.tint_body_text(subtitle_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(status_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_label(help_title, WhatajongUI.COLOR_DOT.darkened(0.35))
	WhatajongUI.tint_label(settings_title, WhatajongUI.COLOR_BAM.darkened(0.35))
	WhatajongUI.tint_body_text(music_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(music_select_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(save_status_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_toggle(fullscreen_checkbox)
	WhatajongUI.tint_toggle(dev_mode_checkbox)
	WhatajongUI.tint_rich_text(help_text)
	_apply_seed_input_style()


func _setup_music_options() -> void:
	var tracks := MusicManager.get_track_names()
	music_option.clear()
	for name in tracks:
		music_option.add_item(name)
	var current := MusicManager.get_current_track()
	for i in range(music_option.item_count):
		if music_option.get_item_text(i) == current:
			music_option.select(i)
			break
	music_slider.value = MusicManager.get_volume_percent()
	_update_save_status_label()


func _update_save_status_label() -> void:
	save_status_label.text = SaveManager.get_save_status_text()


func _apply_seed_input_style() -> void:
	seed_input.add_theme_color_override("font_color", WhatajongUI.COLOR_TEXT)
	seed_input.add_theme_color_override("font_placeholder_color", WhatajongUI.COLOR_TEXT_SOFT)
	seed_input.add_theme_color_override("caret_color", WhatajongUI.COLOR_TEXT)
	seed_input.add_theme_color_override("selection_color", WhatajongUI.COLOR_CRACK.darkened(0.35))
	seed_input.add_theme_constant_override("margin_left", 8)
	seed_input.add_theme_constant_override("margin_right", 8)
	seed_input.add_theme_constant_override("minimum_character_width", 18)


func _get_seed_text() -> String:
	return seed_input.text.strip_edges()


func _on_pvp_button_pressed() -> void:
	_pvp_coming_soon_dialog.popup_centered(Vector2i(420, 160))


func _setup_pvp_coming_soon_dialog() -> void:
	_pvp_coming_soon_dialog = AcceptDialog.new()
	_pvp_coming_soon_dialog.title = "联机对战"
	_pvp_coming_soon_dialog.dialog_text = "敬请期待"
	_pvp_coming_soon_dialog.ok_button_text = "好的"
	_pvp_coming_soon_dialog.dialog_autowrap = true
	add_child(_pvp_coming_soon_dialog)

