extends Control

## PvP 大厅
##
## 两种联机方式：
##   - 在线房间（推荐）：通过 Noray 中继，跨网络、无需端口映射，房主分享房间码即可。
##   - 局域网：同一网络下 IP 直连，适合本地或调试。

@onready var main_panel: Panel = $MainPanel
@onready var title_label: Label = $MainPanel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $MainPanel/VBoxContainer/SubtitleLabel
@onready var host_button: Button = $MainPanel/VBoxContainer/HostButton
@onready var join_button: Button = $MainPanel/VBoxContainer/JoinButton
@onready var tutorial_button: Button = $MainPanel/VBoxContainer/TutorialButton
@onready var back_button: Button = $MainPanel/VBoxContainer/BackButton
@onready var status_label: Label = $MainPanel/VBoxContainer/StatusLabel

@onready var join_panel: Panel = $JoinPanel
@onready var join_title: Label = $JoinPanel/MarginContainer/VBoxContainer/JoinTitle
@onready var ip_label: Label = $JoinPanel/MarginContainer/VBoxContainer/IPRow/IPLabel
@onready var ip_input: LineEdit = $JoinPanel/MarginContainer/VBoxContainer/IPRow/IPInput
@onready var port_row: HBoxContainer = $JoinPanel/MarginContainer/VBoxContainer/PortRow
@onready var port_input: LineEdit = $JoinPanel/MarginContainer/VBoxContainer/PortRow/PortInput
@onready var connect_button: Button = $JoinPanel/MarginContainer/VBoxContainer/ConnectButton
@onready var cancel_join_button: Button = $JoinPanel/MarginContainer/VBoxContainer/CancelButton
@onready var join_vbox: VBoxContainer = $JoinPanel/MarginContainer/VBoxContainer

@onready var waiting_panel: Panel = $WaitingPanel
@onready var waiting_title: Label = $WaitingPanel/MarginContainer/VBoxContainer/WaitingTitle
@onready var ip_display_label: Label = $WaitingPanel/MarginContainer/VBoxContainer/IPDisplayLabel
@onready var waiting_status: Label = $WaitingPanel/MarginContainer/VBoxContainer/WaitingStatus
@onready var cancel_wait_button: Button = $WaitingPanel/MarginContainer/VBoxContainer/CancelButton
@onready var waiting_vbox: VBoxContainer = $WaitingPanel/MarginContainer/VBoxContainer

var _join_is_online := true
var _current_room_code := ""

# 动态创建的控件
var _lan_host_button: Button
var _lan_join_button: Button
var _settings_button: Button
var _copy_button: Button
var _paste_button: Button
var _settings_dialog: AcceptDialog
var _settings_host_input: LineEdit
var _settings_port_input: LineEdit


func _ready() -> void:
	_apply_whatajong_ui()
	_build_dynamic_controls()
	main_panel.show()
	join_panel.hide()
	waiting_panel.hide()
	status_label.text = ""

	PvPNetwork.peer_connected.connect(_on_peer_connected)
	PvPNetwork.server_disconnected.connect(_on_server_disconnected)
	PvPNetwork.connection_failed.connect(_on_connection_failed)
	PvPNetwork.connection_succeeded.connect(_on_connection_succeeded)
	PvPNetwork.online_status.connect(_on_online_status)
	PvPNetwork.online_room_ready.connect(_on_online_room_ready)
	PvPNetwork.online_failed.connect(_on_online_failed)


func _exit_tree() -> void:
	for sig_pair in [
		[PvPNetwork.peer_connected, _on_peer_connected],
		[PvPNetwork.server_disconnected, _on_server_disconnected],
		[PvPNetwork.connection_failed, _on_connection_failed],
		[PvPNetwork.connection_succeeded, _on_connection_succeeded],
		[PvPNetwork.online_status, _on_online_status],
		[PvPNetwork.online_room_ready, _on_online_room_ready],
		[PvPNetwork.online_failed, _on_online_failed],
	]:
		var s: Signal = sig_pair[0]
		var c: Callable = sig_pair[1]
		if s.is_connected(c):
			s.disconnect(c)


## ── 在线：创建房间 ──────────────────────────────────────────
func _on_host_button_pressed() -> void:
	if not PvPNetwork.has_noray_config():
		status_label.text = "请先在「联机服务器设置」中填写服务器地址。"
		_open_settings_dialog()
		return
	main_panel.hide()
	waiting_panel.show()
	waiting_title.text = "正在创建在线房间"
	ip_display_label.text = "房间码：生成中..."
	waiting_status.text = "正在连接联机服务器..."
	_set_copy_button_visible(false)
	PvPNetwork.host_online()


## ── 在线：加入房间 ──────────────────────────────────────────
func _on_join_button_pressed() -> void:
	if not PvPNetwork.has_noray_config():
		status_label.text = "请先在「联机服务器设置」中填写服务器地址。"
		_open_settings_dialog()
		return
	_join_is_online = true
	_configure_join_panel()
	join_panel.show()
	main_panel.hide()


## ── 局域网：创建 ────────────────────────────────────────────
func _on_lan_host_pressed() -> void:
	var error := PvPNetwork.create_direct_host()
	if error != OK:
		status_label.text = "局域网创建失败，错误码：%d" % error
		return
	main_panel.hide()
	waiting_panel.show()
	waiting_title.text = "局域网房间已创建"
	_current_room_code = "%s:%d" % [PvPNetwork.get_local_ip(), PvPNetwork.DEFAULT_PORT]
	ip_display_label.text = "局域网地址：%s" % _current_room_code
	waiting_status.text = "等待同一网络下的好友加入..."
	_set_copy_button_visible(true)


## ── 局域网：加入 ────────────────────────────────────────────
func _on_lan_join_pressed() -> void:
	_join_is_online = false
	_configure_join_panel()
	join_panel.show()
	main_panel.hide()


func _configure_join_panel() -> void:
	status_label.text = ""
	connect_button.disabled = false
	cancel_join_button.text = "返回"
	if _join_is_online:
		join_title.text = "加入在线房间"
		ip_label.text = "房间码："
		ip_input.text = ""
		ip_input.placeholder_text = "粘贴房主分享的房间码"
		port_row.hide()
	else:
		join_title.text = "局域网加入"
		ip_label.text = "房主 IP："
		ip_input.text = ""
		ip_input.placeholder_text = "例如 192.168.1.100"
		port_input.text = str(PvPNetwork.DEFAULT_PORT)
		port_row.show()


func _on_connect_button_pressed() -> void:
	var value := ip_input.text.strip_edges()
	if value == "":
		status_label.text = "房间码不能为空。" if _join_is_online else "请输入房主 IP。"
		return

	if _join_is_online:
		connect_button.disabled = true
		status_label.text = "正在加入房间..."
		PvPNetwork.join_online(value)
		return

	# 局域网直连
	var port_text := port_input.text.strip_edges()
	var port: int = int(port_text) if port_text.is_valid_int() else -1
	if not PvPNetwork.is_valid_port(port):
		status_label.text = "端口无效，请输入 1-65535。"
		return
	if not (PvPNetwork.looks_like_ipv4(value) or PvPNetwork.looks_like_domain(value)):
		status_label.text = "地址格式不正确。"
		return
	status_label.text = "正在连接 %s:%d ..." % [value, port]
	var error := PvPNetwork.join_direct(value, port)
	if error != OK:
		status_label.text = "连接失败，错误码：%d" % error
		return
	connect_button.disabled = true


func _on_cancel_join_button_pressed() -> void:
	PvPNetwork.disconnect_from_network()
	join_panel.hide()
	main_panel.show()
	connect_button.disabled = false
	status_label.text = ""


func _on_cancel_wait_button_pressed() -> void:
	PvPNetwork.disconnect_from_network()
	waiting_panel.hide()
	main_panel.show()
	status_label.text = ""
	_current_room_code = ""


func _on_tutorial_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/pvp_tutorial.tscn")


func _on_back_button_pressed() -> void:
	PvPNetwork.disconnect_from_network()
	get_tree().change_scene_to_file("res://scene/gameStar.tscn")


## ── 连接事件 ────────────────────────────────────────────────
func _on_peer_connected(_peer_id: int) -> void:
	status_label.text = "对手已连接！正在进入对战..."
	waiting_status.text = "对手已连接！正在进入对战..."
	if PvPNetwork.is_host():
		PvPState.reset_for_new_match()
		var seed_value := randi()
		PvPState.board_seed = seed_value
		_receive_board_seed.rpc(seed_value)
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/pvp_board.tscn")
	else:
		if PvPState.board_seed == 0:
			await get_tree().create_timer(0.2).timeout
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/pvp_board.tscn")


func _on_server_disconnected() -> void:
	status_label.text = "与房间断开连接。"
	join_panel.hide()
	waiting_panel.hide()
	main_panel.show()
	connect_button.disabled = false


func _on_connection_failed() -> void:
	status_label.text = "连接失败，请检查地址/房间码与网络。"
	connect_button.disabled = false


func _on_connection_succeeded() -> void:
	status_label.text = "连接成功！等待房主开始..."


func _on_online_status(message: String) -> void:
	waiting_status.text = message
	status_label.text = message


func _on_online_room_ready(room_code: String) -> void:
	_current_room_code = room_code
	waiting_title.text = "在线房间已创建"
	ip_display_label.text = "房间码：%s" % room_code
	waiting_status.text = "把房间码发给好友，对方选择「加入在线房间」即可。\n（不同网络也能连，无需端口映射）"
	_set_copy_button_visible(true)


func _on_online_failed(message: String) -> void:
	status_label.text = message
	waiting_status.text = message
	connect_button.disabled = false
	# 失败回到主菜单，便于重试或改设置
	await get_tree().create_timer(0.2).timeout
	if waiting_panel.visible:
		waiting_panel.hide()
		main_panel.show()


## ── 复制 / 粘贴 ─────────────────────────────────────────────
func _on_copy_pressed() -> void:
	if _current_room_code == "":
		return
	DisplayServer.clipboard_set(_current_room_code)
	status_label.text = "已复制：%s" % _current_room_code
	waiting_status.text = "已复制：%s\n发送给好友即可加入。" % _current_room_code


func _on_paste_pressed() -> void:
	var text := DisplayServer.clipboard_get().strip_edges()
	if text == "":
		status_label.text = "剪贴板为空。"
		return
	if _join_is_online:
		ip_input.text = text
	else:
		# 支持 ip:port 粘贴
		if text.find(":") != -1:
			var parts := text.split(":")
			ip_input.text = parts[0].strip_edges()
			if parts.size() > 1 and String(parts[1]).strip_edges().is_valid_int():
				port_input.text = String(parts[1]).strip_edges()
		else:
			ip_input.text = text
	status_label.text = "已粘贴，点击连接即可。"


## ── 服务器设置 ──────────────────────────────────────────────
func _on_settings_pressed() -> void:
	_open_settings_dialog()


func _open_settings_dialog() -> void:
	_settings_host_input.text = PvPNetwork.get_noray_host()
	_settings_port_input.text = str(PvPNetwork.get_noray_port())
	_settings_dialog.popup_centered(Vector2i(560, 240))


func _on_settings_confirmed() -> void:
	var host := _settings_host_input.text.strip_edges()
	var port_text := _settings_port_input.text.strip_edges()
	var port: int = int(port_text) if port_text.is_valid_int() else PvPNetwork.DEFAULT_NORAY_PORT
	PvPNetwork.set_noray_server(host, port)
	if host == "":
		status_label.text = "已清空联机服务器地址。"
	else:
		status_label.text = "已保存联机服务器：%s:%d" % [host, port]


## ── 动态控件构建 ────────────────────────────────────────────
func _build_dynamic_controls() -> void:
	host_button.text = "创建在线房间"
	join_button.text = "加入在线房间"
	subtitle_label.text = "在线房间跨网络直连，无需端口映射；也支持局域网。"

	var insert_at := join_button.get_index() + 1

	_lan_host_button = _make_menu_button("局域网 · 创建房间", WhatajongUI.COLOR_BAM, _on_lan_host_pressed)
	main_panel.get_node("VBoxContainer").add_child(_lan_host_button)
	main_panel.get_node("VBoxContainer").move_child(_lan_host_button, insert_at)

	_lan_join_button = _make_menu_button("局域网 · 加入房间", WhatajongUI.COLOR_BAM, _on_lan_join_pressed)
	main_panel.get_node("VBoxContainer").add_child(_lan_join_button)
	main_panel.get_node("VBoxContainer").move_child(_lan_join_button, insert_at + 1)

	_settings_button = _make_menu_button("联机服务器设置", WhatajongUI.COLOR_DOT, _on_settings_pressed, 0.85)
	main_panel.get_node("VBoxContainer").add_child(_settings_button)
	main_panel.get_node("VBoxContainer").move_child(_settings_button, insert_at + 2)

	# 等待面板：复制房间码
	_copy_button = Button.new()
	_copy_button.text = "复制房间码"
	_copy_button.custom_minimum_size = Vector2(0, 42)
	_copy_button.pressed.connect(_on_copy_pressed)
	waiting_vbox.add_child(_copy_button)
	waiting_vbox.move_child(_copy_button, cancel_wait_button.get_index())
	WhatajongUI.apply_display_font(_copy_button, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_button(_copy_button, WhatajongUI.COLOR_DOT, 0.9)

	# 加入面板：粘贴房间码
	_paste_button = Button.new()
	_paste_button.text = "粘贴"
	_paste_button.custom_minimum_size = Vector2(0, 40)
	_paste_button.pressed.connect(_on_paste_pressed)
	join_vbox.add_child(_paste_button)
	join_vbox.move_child(_paste_button, connect_button.get_index())
	WhatajongUI.apply_display_font(_paste_button, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_button(_paste_button, WhatajongUI.COLOR_DOT, 0.9)

	_build_settings_dialog()


func _make_menu_button(text: String, color: Color, callback: Callable, brightness: float = 1.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(callback)
	WhatajongUI.apply_display_font(btn)
	WhatajongUI.apply_button(btn, color, brightness)
	return btn


func _build_settings_dialog() -> void:
	_settings_dialog = AcceptDialog.new()
	_settings_dialog.title = "联机服务器设置"
	_settings_dialog.ok_button_text = "保存"
	_settings_dialog.confirmed.connect(_on_settings_confirmed)
	add_child(_settings_dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_settings_dialog.add_child(vbox)

	var hint := Label.new()
	hint.text = "填写 Noray 联机服务器地址（自建，详见 NORAY_SETUP.md）。\n例如：game.example.com 或 1.2.3.4"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(500, 0)
	vbox.add_child(hint)

	var host_row := HBoxContainer.new()
	vbox.add_child(host_row)
	var host_label := Label.new()
	host_label.text = "服务器："
	host_row.add_child(host_label)
	_settings_host_input = LineEdit.new()
	_settings_host_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_host_input.placeholder_text = "Noray 服务器域名或 IP"
	host_row.add_child(_settings_host_input)

	var port_settings_row := HBoxContainer.new()
	vbox.add_child(port_settings_row)
	var port_label2 := Label.new()
	port_label2.text = "端口："
	port_settings_row.add_child(port_label2)
	_settings_port_input = LineEdit.new()
	_settings_port_input.custom_minimum_size = Vector2(120, 0)
	_settings_port_input.text = str(PvPNetwork.DEFAULT_NORAY_PORT)
	port_settings_row.add_child(_settings_port_input)


func _set_copy_button_visible(value: bool) -> void:
	if _copy_button != null:
		_copy_button.visible = value


## ── RPC：接收棋盘种子 ──────────────────────────────────────
@rpc("authority", "reliable")
func _receive_board_seed(seed_value: int) -> void:
	PvPState.reset_for_new_match()
	PvPState.board_seed = seed_value


## ── UI 样式 ─────────────────────────────────────────────────
func _apply_whatajong_ui() -> void:
	WhatajongUI.apply_panel(main_panel, WhatajongUI.COLOR_CRACK, Color(0.95, 0.92, 0.84, 0.82), 30, 28)
	WhatajongUI.apply_panel(join_panel, WhatajongUI.COLOR_DOT, Color(0.96, 0.93, 0.86, 0.92), 24, 20)
	WhatajongUI.apply_panel(waiting_panel, WhatajongUI.COLOR_BAM, Color(0.96, 0.93, 0.86, 0.92), 24, 20)

	WhatajongUI.apply_display_font(title_label, 48)
	WhatajongUI.apply_display_font(host_button)
	WhatajongUI.apply_display_font(join_button)
	WhatajongUI.apply_display_font(tutorial_button)
	WhatajongUI.apply_display_font(back_button)
	WhatajongUI.apply_display_font(join_title, WhatajongUI.FONT_SIZE_SUBTITLE)
	WhatajongUI.apply_display_font(waiting_title, WhatajongUI.FONT_SIZE_SUBTITLE)
	WhatajongUI.apply_display_font(connect_button)
	WhatajongUI.apply_display_font(cancel_join_button)
	WhatajongUI.apply_display_font(cancel_wait_button)
	WhatajongUI.apply_display_font(ip_label, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_display_font(ip_input, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.apply_display_font(port_input, WhatajongUI.FONT_SIZE_SMALL)

	WhatajongUI.apply_button(host_button, WhatajongUI.COLOR_CRACK)
	WhatajongUI.apply_button(join_button, WhatajongUI.COLOR_DOT)
	WhatajongUI.apply_button(tutorial_button, WhatajongUI.COLOR_BAM)
	WhatajongUI.apply_button(back_button, WhatajongUI.COLOR_DOT, 0.88)
	WhatajongUI.apply_button(connect_button, WhatajongUI.COLOR_DOT)
	WhatajongUI.apply_button(cancel_join_button, WhatajongUI.COLOR_CRACK, 0.88)
	WhatajongUI.apply_button(cancel_wait_button, WhatajongUI.COLOR_CRACK, 0.88)

	WhatajongUI.tint_label(title_label, WhatajongUI.COLOR_CRACK.darkened(0.35))
	WhatajongUI.tint_body_text(subtitle_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(status_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_label(join_title, WhatajongUI.COLOR_DOT.darkened(0.35))
	WhatajongUI.tint_label(waiting_title, WhatajongUI.COLOR_BAM.darkened(0.35))
	WhatajongUI.tint_body_text(ip_label, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_SMALL)
	WhatajongUI.tint_body_text(ip_display_label, WhatajongUI.COLOR_TEXT, WhatajongUI.FONT_SIZE_BODY)
	WhatajongUI.tint_body_text(waiting_status, WhatajongUI.COLOR_TEXT_SOFT, WhatajongUI.FONT_SIZE_BODY)

	for input: LineEdit in [ip_input, port_input]:
		input.add_theme_color_override("font_color", WhatajongUI.COLOR_TEXT)
		input.add_theme_color_override("font_placeholder_color", WhatajongUI.COLOR_TEXT_SOFT)
		input.add_theme_color_override("caret_color", WhatajongUI.COLOR_TEXT)
		input.add_theme_constant_override("margin_left", 8)
		input.add_theme_constant_override("margin_right", 8)
