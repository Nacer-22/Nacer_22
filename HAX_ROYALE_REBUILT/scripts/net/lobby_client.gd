class_name HAXLobbyClient
extends Node

signal connection_changed(connected: bool, message: String)
signal room_created(code: String)
signal room_joined(payload: Dictionary)
signal packet_received(payload: Dictionary)
signal network_error(message: String)

var server_url := ""
var peer := WebSocketPeer.new()
var player_name := "NACAR_22"
var room_code := ""
var client_id := ""
var is_connected := false
var _pending_action: Dictionary = {}
var _last_state: Dictionary = {}
var _send_timer := 0.0

func _ready() -> void:
    server_url = OS.get_environment("HAX_SERVER_URL").strip_edges()
    if server_url == "":
        server_url = str(ProjectSettings.get_setting("hax/online_server_url","")).strip_edges()

func connect_server(url_override := "") -> void:
    if url_override.strip_edges() != "":
        server_url = url_override.strip_edges()
    if server_url == "":
        network_error.emit("ONLINE SERVER NOT CONFIGURED")
        return
    peer = WebSocketPeer.new()
    var error_code := peer.connect_to_url(server_url)
    if error_code != OK:
        network_error.emit("CONNECTION FAILED: %s" % error_string(error_code))
        return
    connection_changed.emit(false,"CONNECTING TO HAX NETWORK...")

func create_room(room_name: String,mode_id: String,map_id: String) -> void:
    _pending_action = {"type":"create_room","name":player_name,"roomName":room_name,"mode":mode_id,"map":map_id,"maxPlayers":16}
    if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
        _send(_pending_action)
    else:
        connect_server()

func join_room(code: String) -> void:
    _pending_action = {"type":"join_room","name":player_name,"code":code}
    if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
        _send(_pending_action)
    else:
        connect_server()

func leave_room() -> void:
    if room_code != "" and peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
        _send({"type":"leave_room"})
    room_code = ""

func send_player_state(position: Vector3,yaw: float,pitch: float,health: float,weapon_id: String) -> void:
    _last_state = {"type":"state","position":{"x":position.x,"y":position.y,"z":position.z},"yaw":yaw,"pitch":pitch,"health":health,"weapon":weapon_id}

func send_shot() -> void:
    if room_code != "":
        _send({"type":"shoot"})

func send_reload() -> void:
    if room_code != "":
        _send({"type":"reload"})

func send_chat(message: String) -> void:
    if room_code != "":
        _send({"type":"chat","message":message})

func _process(delta: float) -> void:
    if peer.get_ready_state() == WebSocketPeer.STATE_CLOSED:
        if is_connected:
            is_connected = false
            connection_changed.emit(false,"DISCONNECTED FROM HAX NETWORK")
        return
    peer.poll()
    var state := peer.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN and not is_connected:
        is_connected = true
        connection_changed.emit(true,"CONNECTED TO HAX NETWORK")
        _send({"type":"hello","name":player_name,"version":GameData.VERSION})
        if not _pending_action.is_empty():
            _send(_pending_action)
            _pending_action.clear()
    while peer.get_available_packet_count() > 0:
        var text := peer.get_packet().get_string_from_utf8()
        var parsed: Variant = JSON.parse_string(text)
        if parsed is Dictionary:
            _handle_message(parsed)
    if room_code != "" and state == WebSocketPeer.STATE_OPEN:
        _send_timer -= delta
        if _send_timer <= 0.0 and not _last_state.is_empty():
            _send(_last_state)
            _send_timer = 0.075

func _send(payload: Dictionary) -> void:
    if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
        peer.send_text(JSON.stringify(payload))

func _handle_message(payload: Dictionary) -> void:
    var kind := str(payload.get("type",""))
    match kind:
        "room_created":
            room_code = str(payload.get("code",""))
            room_created.emit(room_code)
        "room_joined":
            room_code = str(payload.get("code",""))
            room_joined.emit(payload)
        "error":
            network_error.emit(str(payload.get("message","ONLINE SERVICE ERROR")))
        "server_ready":
            client_id = str(payload.get("id",""))
            packet_received.emit(payload)
        _:
            packet_received.emit(payload)
