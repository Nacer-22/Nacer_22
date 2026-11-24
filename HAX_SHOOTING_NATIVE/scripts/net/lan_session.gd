class_name HAXLanSession
extends Node

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal session_state(message: String)
signal remote_snapshot(peer_id: int,position: Vector3,yaw: float,pitch: float)

const DEFAULT_PORT := 24500
const MAX_CLIENTS := 8
var peer := ENetMultiplayerPeer.new()
var active := false

func _ready() -> void:
    multiplayer.peer_connected.connect(func(id: int): peer_connected.emit(id); session_state.emit("OPERATOR CONNECTED · %d" % id))
    multiplayer.peer_disconnected.connect(func(id: int): peer_disconnected.emit(id); session_state.emit("OPERATOR DISCONNECTED · %d" % id))
    multiplayer.connected_to_server.connect(func(): session_state.emit("LAN LINK ESTABLISHED"))
    multiplayer.connection_failed.connect(func(): session_state.emit("LAN CONNECTION FAILED"))
    multiplayer.server_disconnected.connect(func(): active = false; session_state.emit("HOST DISCONNECTED"))

func host(port: int = DEFAULT_PORT) -> Error:
    close_session()
    var result := peer.create_server(port,MAX_CLIENTS)
    if result != OK:
        session_state.emit("COULD NOT OPEN UDP PORT %d" % port)
        return result
    multiplayer.multiplayer_peer = peer
    active = true
    session_state.emit("LAN ROOM OPEN · PORT %d" % port)
    return OK

func join(address: String,port: int = DEFAULT_PORT) -> Error:
    close_session()
    if address.strip_edges().is_empty():
        return ERR_INVALID_PARAMETER
    var result := peer.create_client(address.strip_edges(),port)
    if result != OK:
        session_state.emit("COULD NOT CONNECT TO HOST")
        return result
    multiplayer.multiplayer_peer = peer
    active = true
    session_state.emit("CONNECTING TO LAN HOST...")
    return OK

func close_session() -> void:
    active = false
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func send_snapshot(position: Vector3,yaw: float,pitch: float) -> void:
    if not active:
        return
    var payload := {"x":position.x,"y":position.y,"z":position.z,"yaw":yaw,"pitch":pitch}
    if multiplayer.is_server():
        _broadcast_snapshot(1,payload)
    else:
        submit_snapshot.rpc_id(1,payload)

@rpc("any_peer","call_remote","unreliable_ordered")
func submit_snapshot(payload: Dictionary) -> void:
    if not multiplayer.is_server() or not _valid_snapshot(payload):
        return
    _broadcast_snapshot(multiplayer.get_remote_sender_id(),payload)

func _broadcast_snapshot(peer_id: int,payload: Dictionary) -> void:
    if multiplayer.is_server():
        remote_snapshot.emit(peer_id,Vector3(float(payload.x),float(payload.y),float(payload.z)),float(payload.yaw),float(payload.pitch))
    apply_snapshot.rpc(peer_id,payload)

@rpc("authority","call_remote","unreliable_ordered")
func apply_snapshot(peer_id: int,payload: Dictionary) -> void:
    if _valid_snapshot(payload):
        remote_snapshot.emit(peer_id,Vector3(float(payload.x),float(payload.y),float(payload.z)),float(payload.yaw),float(payload.pitch))

func _valid_snapshot(payload: Dictionary) -> bool:
    for key in ["x","y","z","yaw","pitch"]:
        if not payload.has(key) or not is_finite(float(payload[key])):
            return false
    return absf(float(payload.x)) <= 60.0 and absf(float(payload.z)) <= 60.0 and float(payload.y) >= -2.0 and float(payload.y) <= 8.0
