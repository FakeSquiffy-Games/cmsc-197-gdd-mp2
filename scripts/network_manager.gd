extends Node

const PORT = 7777
const MAX_PLAYERS = 2
const BROADCAST_PORT = 7778
const BROADCAST_MSG = "LAN_GAME_HOST"

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal server_disconnected()
signal game_ready()
signal host_found(ip: String)

var udp := PacketPeerUDP.new()
var listener := PacketPeerUDP.new()
var is_broadcasting: bool = false
var is_listening: bool = false
var broadcast_timer: float = 0.0

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	# Host broadcasts every second
	if is_broadcasting:
		broadcast_timer += delta
		if broadcast_timer >= 1.0:
			broadcast_timer = 0.0
			udp.set_dest_address("255.255.255.255", BROADCAST_PORT)
			udp.put_packet(BROADCAST_MSG.to_utf8_buffer())

	# Client listens for host
	if is_listening:
		if listener.get_available_packet_count() > 0:
			var packet = listener.get_packet().get_string_from_utf8()
			if packet == BROADCAST_MSG:
				var host_ip = listener.get_packet_ip()
				stop_listening()
				emit_signal("host_found", host_ip)

func host_game() -> String:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		return ""
	multiplayer.multiplayer_peer = peer
	start_broadcasting()
	return _get_local_ip()

func join_game(ip: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, PORT)
	if err != OK:
		emit_signal("connection_failed")
		return
	multiplayer.multiplayer_peer = peer

# --- BROADCAST (host) ---
func start_broadcasting() -> void:
	udp.set_broadcast_enabled(true)
	udp.bind(BROADCAST_PORT + 1)  # bind to a port to send from
	is_broadcasting = true

func stop_broadcasting() -> void:
	is_broadcasting = false
	udp.close()

# --- LISTEN (client) ---
func start_listening() -> void:
	listener.bind(BROADCAST_PORT)
	is_listening = true

func stop_listening() -> void:
	is_listening = false
	listener.close()

func _on_peer_connected(peer_id: int) -> void:
	emit_signal("player_connected", peer_id)
	if multiplayer.is_server() and multiplayer.get_peers().size() >= 1:
		stop_broadcasting()
		emit_signal("game_ready")

func _on_peer_disconnected(peer_id: int) -> void:
	emit_signal("player_disconnected", peer_id)

func _on_connected_to_server() -> void:
	emit_signal("player_connected", multiplayer.get_unique_id())
	emit_signal("game_ready")

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	emit_signal("connection_failed")

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	emit_signal("server_disconnected")

func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		print("Found address: ", addr)  # debug — shows all IPs in output
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"
