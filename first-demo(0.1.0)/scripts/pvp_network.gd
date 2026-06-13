extends Node

## PvPNetwork — 联机对战网络管理器（Autoload）
##
## 提供两种连接方式：
##   1. 在线模式（MODE_ONLINE）：通过 Noray 中继服务器做 NAT 打洞 / 中继，
##      不同网络、无需端口映射即可“主机 + 房间码加入”，是默认推荐方式。
##   2. 局域网模式（MODE_DIRECT）：同一网络下用 IP 直连，适合本地联机与调试。
##
## 底层始终是 Godot ENetMultiplayerPeer，房主即权威端，
## 对外信号保持稳定，供 pvp_lobby / pvp_board 使用。

const DEFAULT_PORT := 7777
const DEFAULT_NORAY_PORT := 8890
const MAX_CLIENTS := 1
const CONFIG_PATH := "user://pvp_net.cfg"
const HANDSHAKE_TIMEOUT := 8.0

enum Mode { NONE, DIRECT, ONLINE }

# 通用连接信号（保持向后兼容）
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal server_disconnected
signal connection_failed
signal connection_succeeded

# 在线模式专用信号
signal online_status(message: String)
signal online_room_ready(room_code: String)
signal online_failed(message: String)

var _mode: int = Mode.NONE
var _is_host := false
var _is_connected := false
var _local_peer_id := 0

# 在线模式状态
var _noray_host := ""
var _noray_port := DEFAULT_NORAY_PORT
var _online_role_host := false
var _online_target_oid := ""
var _online_busy := false
var _signals_bound := false


func _ready() -> void:
	_load_config()
	Noray.on_connect_nat.connect(_on_noray_connect_nat)
	Noray.on_connect_relay.connect(_on_noray_connect_relay)


## ── 基础查询 ────────────────────────────────────────────────
func is_host() -> bool:
	return _is_host


func is_connected_to_server() -> bool:
	return _is_connected


func get_local_peer_id() -> int:
	return _local_peer_id


func get_mode() -> int:
	return _mode


func get_remote_peer_id() -> int:
	if _is_host:
		for id in multiplayer.get_peers():
			return id
		return 0
	return 1


## ── Noray 服务器配置 ────────────────────────────────────────
func get_noray_host() -> String:
	return _noray_host


func get_noray_port() -> int:
	return _noray_port


func has_noray_config() -> bool:
	return _noray_host.strip_edges() != ""


func set_noray_server(address: String, port: int = DEFAULT_NORAY_PORT) -> void:
	_noray_host = address.strip_edges()
	_noray_port = port if is_valid_port(port) else DEFAULT_NORAY_PORT
	_save_config()


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	_noray_host = String(cfg.get_value("noray", "host", ""))
	_noray_port = int(cfg.get_value("noray", "port", DEFAULT_NORAY_PORT))


func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("noray", "host", _noray_host)
	cfg.set_value("noray", "port", _noray_port)
	cfg.save(CONFIG_PATH)


## ── 局域网直连 ──────────────────────────────────────────────
func create_direct_host(port: int = DEFAULT_PORT) -> Error:
	disconnect_from_network()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		push_error("PvPNetwork: 创建局域网房间失败，错误码 %d" % error)
		return error

	multiplayer.multiplayer_peer = peer
	_mode = Mode.DIRECT
	_is_host = true
	_is_connected = true
	_local_peer_id = multiplayer.get_unique_id()
	_bind_multiplayer_signals()
	return OK


func join_direct(address: String, port: int = DEFAULT_PORT) -> Error:
	disconnect_from_network()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		push_error("PvPNetwork: 连接局域网房间失败，错误码 %d" % error)
		return error

	multiplayer.multiplayer_peer = peer
	_mode = Mode.DIRECT
	_is_host = false
	_is_connected = false
	_local_peer_id = multiplayer.get_unique_id()
	_bind_multiplayer_signals()
	return OK


## ── 在线模式（Noray）──────────────────────────────────────────
## 房主：连接中继 → 注册 → 监听，成功后通过 online_room_ready 返回房间码。
func host_online() -> void:
	if _online_busy:
		return
	if not has_noray_config():
		online_failed.emit("未配置联机服务器地址，请先在设置中填写。")
		return

	_online_busy = true
	disconnect_from_network()
	_mode = Mode.ONLINE
	_online_role_host = true

	if not await _ensure_noray_registered():
		_online_busy = false
		online_failed.emit("无法连接联机服务器，请检查服务器地址或网络。")
		return

	online_status.emit("正在创建在线房间...")
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(Noray.local_port, MAX_CLIENTS)
	if error != OK:
		_online_busy = false
		online_failed.emit("创建在线房间失败，错误码 %d" % error)
		return

	multiplayer.multiplayer_peer = peer
	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		await get_tree().process_frame

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		multiplayer.multiplayer_peer = null
		_online_busy = false
		online_failed.emit("在线房间启动失败。")
		return

	multiplayer.server_relay = true
	_is_host = true
	_is_connected = true
	_local_peer_id = multiplayer.get_unique_id()
	_bind_multiplayer_signals()

	_online_busy = false
	online_room_ready.emit(Noray.oid)


## 加入：连接中继 → 注册 → 用房间码请求打洞（失败回退中继）。
func join_online(room_code: String) -> void:
	if _online_busy:
		return
	var code := room_code.strip_edges()
	if code == "":
		online_failed.emit("请输入房间码。")
		return
	if not has_noray_config():
		online_failed.emit("未配置联机服务器地址，请先在设置中填写。")
		return

	_online_busy = true
	disconnect_from_network()
	_mode = Mode.ONLINE
	_online_role_host = false
	_online_target_oid = code

	if not await _ensure_noray_registered():
		_online_busy = false
		online_failed.emit("无法连接联机服务器，请检查服务器地址或网络。")
		return

	online_status.emit("正在连接房间 %s ..." % code)
	_online_busy = false
	Noray.connect_nat(code)


func _ensure_noray_registered() -> bool:
	online_status.emit("正在连接联机服务器...")
	var err := await Noray.connect_to_host(_noray_host, _noray_port)
	if err != OK:
		return false

	Noray.register_host()
	await Noray.on_pid

	online_status.emit("正在注册公网地址...")
	err = await Noray.register_remote()
	if err != OK:
		return false
	return Noray.local_port > 0


func _on_noray_connect_nat(address: String, port: int) -> void:
	if _mode != Mode.ONLINE:
		return
	var err := await _online_establish(address, port)
	# 客户端打洞失败时回退中继
	if err != OK and not _online_role_host and _online_target_oid != "":
		online_status.emit("打洞失败，正在尝试中继连接...")
		Noray.connect_relay(_online_target_oid)


func _on_noray_connect_relay(address: String, port: int) -> void:
	if _mode != Mode.ONLINE:
		return
	await _online_establish(address, port)


func _online_establish(address: String, port: int) -> Error:
	if Noray.local_port <= 0:
		return ERR_UNCONFIGURED

	if _online_role_host:
		var host_peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if host_peer == null:
			return ERR_UNAVAILABLE
		return await PacketHandshake.over_enet_peer(host_peer, address, port, HANDSHAKE_TIMEOUT)

	# 客户端：先打洞握手，再建立 ENet 连接
	var udp := PacketPeerUDP.new()
	udp.bind(Noray.local_port)
	udp.set_dest_address(address, port)
	var hs := await PacketHandshake.over_packet_peer(udp, HANDSHAKE_TIMEOUT)
	udp.close()
	if hs != OK and hs != ERR_BUSY:
		return hs

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port, 0, 0, 0, Noray.local_port)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = peer
	_is_host = false
	_local_peer_id = multiplayer.get_unique_id()
	_bind_multiplayer_signals()

	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		await get_tree().process_frame

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		multiplayer.multiplayer_peer = null
		_unbind_multiplayer_signals()
		return ERR_CANT_CONNECT

	return OK


## ── 断开 ────────────────────────────────────────────────────
func disconnect_from_network() -> void:
	_unbind_multiplayer_signals()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	if Noray.is_connected_to_host():
		Noray.disconnect_from_host()

	_mode = Mode.NONE
	_is_host = false
	_is_connected = false
	_local_peer_id = 0
	_online_role_host = false
	_online_target_oid = ""


## ── 多人信号绑定 ────────────────────────────────────────────
func _bind_multiplayer_signals() -> void:
	if _signals_bound:
		return
	_signals_bound = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)


func _unbind_multiplayer_signals() -> void:
	if not _signals_bound:
		return
	_signals_bound = false
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)


func _on_peer_connected(peer_id: int) -> void:
	_is_connected = true
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id == 1:
		_is_connected = false
		server_disconnected.emit()
	else:
		if _is_host and multiplayer.get_peers().is_empty():
			_is_connected = false
		peer_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	_is_connected = true
	_local_peer_id = multiplayer.get_unique_id()
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	_is_connected = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	connection_failed.emit()


## ── 工具方法 ────────────────────────────────────────────────
func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip != "127.0.0.1" and ip.find(":") == -1:
			return ip
	return "127.0.0.1"


func is_valid_port(port: int) -> bool:
	return port >= 1 and port <= 65535


func looks_like_ipv4(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not String(part).is_valid_int():
			return false
		var n := int(part)
		if n < 0 or n > 255:
			return false
	return true


func is_private_ipv4(address: String) -> bool:
	if not looks_like_ipv4(address):
		return false
	var parts := address.split(".")
	var a := int(parts[0])
	var b := int(parts[1])
	if a == 10:
		return true
	if a == 172 and b >= 16 and b <= 31:
		return true
	if a == 192 and b == 168:
		return true
	if a == 127:
		return true
	return false


func looks_like_domain(address: String) -> bool:
	var host := address.strip_edges()
	if host.length() < 3 or host.find(" ") != -1 or host.find(".") == -1:
		return false
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9.-]+$")
	return regex.search(host) != null
