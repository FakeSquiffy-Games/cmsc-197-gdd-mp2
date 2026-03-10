extends Node2D

@onready var network_manager = $NetworkManager
@onready var lobby_ui = $LobbyUI
@onready var hud = $HUD
@onready var host_btn = $LobbyUI/Panel/VBox/HostBtn
@onready var join_btn = $LobbyUI/Panel/VBox/JoinBtn
@onready var status_label = $LobbyUI/Panel/VBox/StatusLabel
@onready var my_ip_label = $LobbyUI/Panel/VBox/MyIPLabel
@onready var server_list: ItemList = $LobbyUI/Panel/VBox/ServerList

const PlayerScene = preload("res://scenes/Player.tscn")
var spawn_positions = [Vector2(-200, 0), Vector2(200, 0)]
var found_hosts: Array = []

func _ready() -> void:
	network_manager.game_ready.connect(_on_game_ready)
	network_manager.connection_failed.connect(_on_connection_failed)
	network_manager.server_disconnected.connect(_on_server_disconnected)
	network_manager.host_found.connect(_on_host_found)
	
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	network_manager.start_listening()
	# Test Server for Debugging
	if OS.is_debug_build():
		found_hosts.append("127.0.0.1")
		server_list.add_item("Local Test (127.0.0.1)")

func _on_game_ready() -> void:
	if multiplayer.is_server():
		_spawn_all_players()
	lobby_ui.visible = false
	hud.visible = true

func _on_server_disconnected() -> void:
	status_label.text = "Host disconnected."
	lobby_ui.visible = true
	hud.visible = false

func _on_host_pressed() -> void:
	network_manager.stop_listening()
	var ip = network_manager.host_game()
	print("Hosting on IP: ", ip)
	if ip == "":
		status_label.text = "Failed to host!"
		host_btn.disabled = false
		return
	my_ip_label.text = "Your IP: " + ip
	status_label.text = "Waiting for player 2..."
	host_btn.disabled = true
	join_btn.disabled = true

func _on_join_pressed() -> void:
	var selected = server_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "No server selected!"
		return
	var ip = found_hosts[selected[0]]
	status_label.text = "Connecting to " + ip + "..."
	host_btn.disabled = true
	join_btn.disabled = true
	network_manager.stop_listening()
	network_manager.join_game(ip)

func _on_host_found(ip: String) -> void:
	if ip not in found_hosts:
		found_hosts.append(ip)
		server_list.add_item("Game at " + ip)
	status_label.text = str(found_hosts.size()) + " server(s) found"

func _on_connection_failed() -> void:
	status_label.text = "Failed. Try again."
	host_btn.disabled = false
	join_btn.disabled = false
	network_manager.start_listening()

func _spawn_all_players() -> void:
	var all_ids = [1] + Array(multiplayer.get_peers())
	for i in range(min(all_ids.size(), spawn_positions.size())):
		spawn_player.rpc(all_ids[i], spawn_positions[i])

@rpc("authority", "call_local", "reliable")
func spawn_player(id: int, pos: Vector2) -> void:
	var player = PlayerScene.instantiate()
	player.name = "Player_" + str(id)
	player.position = pos
	$Players.add_child(player)
	player.setup(id)
	print("Spawned player id: ", id, " | my id: ", multiplayer.get_unique_id())
