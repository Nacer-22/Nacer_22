extends Node3D

const MapFactoryScript = preload("res://scripts/world/map_factory.gd")
const PlayerScript = preload("res://scripts/player/player_controller.gd")
const BotScript = preload("res://scripts/ai/bot_controller.gd")
const UIScript = preload("res://scripts/ui/game_ui.gd")
const LobbyScript = preload("res://scripts/net/lobby_client.gd")
const LanScript = preload("res://scripts/net/lan_session.gd")

var map_factory: MapFactory
var player: FPSPlayer
var ui: HAXGameUI
var lobby: HAXLobbyClient
var lan: HAXLanSession
var nav_grid: AStarGrid2D
var current_mode := "tdm"
var current_map := "red_harbor"
var round_number := 1
var kills := 0
var deaths := 0
var is_match_active := false
var is_paused := false
var _bots: Array[CombatBot] = []
var _round_transition := false
var _respawn_pending := false
var _remote_operators: Dictionary = {}
var _state_send_timer := 0.0

func _ready() -> void:
    _setup_input_map()
    _create_environment()
    map_factory = MapFactoryScript.new()
    map_factory.name = "WorldMap"
    add_child(map_factory)
    map_factory.build_map(current_map)
    player = PlayerScript.new()
    player.name = "NACAR_PLAYER"
    add_child(player)
    player.global_position = Vector3(0,0.1,43)
    player.health_changed.connect(_on_health_changed)
    player.ammo_changed.connect(_on_ammo_changed)
    player.player_killed.connect(_on_player_killed)
    player.shot_fired.connect(_on_shot_fired)
    ui = UIScript.new()
    add_child(ui)
    ui.start_requested.connect(_on_start_requested)
    ui.pause_requested.connect(_on_pause_requested)
    ui.setting_changed.connect(_on_setting_changed)
    ui.room_create_requested.connect(_on_room_create_requested)
    ui.room_join_requested.connect(_on_room_join_requested)
    ui.lan_host_requested.connect(_on_lan_host_requested)
    ui.lan_join_requested.connect(_on_lan_join_requested)
    ui.mobile_move_changed.connect(player.set_mobile_move)
    ui.mobile_look_changed.connect(player.set_mobile_look)
    ui.mobile_fire_changed.connect(player.set_mobile_fire)
    ui.mobile_aim_changed.connect(player.set_mobile_aim)
    lobby = LobbyScript.new()
    add_child(lobby)
    lan = LanScript.new()
    add_child(lan)
    lan.remote_snapshot.connect(_on_lan_snapshot)
    lan.peer_disconnected.connect(_on_lan_peer_disconnected)
    lan.session_state.connect(ui.set_room_status)
    lobby.connection_changed.connect(_on_network_connection)
    lobby.room_created.connect(_on_room_created)
    lobby.room_joined.connect(_on_room_joined)
    lobby.network_error.connect(_on_network_error)
    lobby.packet_received.connect(_on_network_packet)
    player.mouse_sensitivity = 0.0011 + float(ui._settings.sensitivity) * 0.0032
    player.aim_assist_enabled = bool(ui._settings.aim_assist)
    player.aim_assist_strength = float(ui._settings.aim_strength)
    player.aim_assist_cone = float(ui._settings.aim_cone)
    ui.show_main_menu()

func _process(delta: float) -> void:
    if not is_match_active or is_paused or not is_instance_valid(player):
        return
    var ammo: Dictionary = player.ammo_by_weapon.get(str(player.weapon_data.get("id","hax_ar")),{"mag":0,"reserve":0})
    ui.update_hud(player.health,player.armor,int(ammo.get("mag",0)),int(ammo.get("reserve",0)),round_number,kills,deaths,str(GameData.get_mode(current_mode).name))
    _state_send_timer -= delta
    if _state_send_timer <= 0.0:
        if lobby.room_code != "":
            lobby.send_player_state(player.global_position,player.rotation.y,player._pitch,player.health,str(player.weapon_data.id))
        if lan.active:
            lan.send_snapshot(player.global_position,player.rotation.y,player._pitch)
        _state_send_timer = 0.075

func _setup_input_map() -> void:
    _add_key_action("move_forward",KEY_W)
    _add_key_action("move_back",KEY_S)
    _add_key_action("move_left",KEY_A)
    _add_key_action("move_right",KEY_D)
    _add_key_action("sprint",KEY_SHIFT)
    _add_key_action("jump",KEY_SPACE)
    _add_key_action("fire",KEY_F)
    _add_key_action("aim",KEY_Q)

func _add_key_action(action: String,key: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
        var event := InputEventKey.new()
        event.keycode = key
        InputMap.action_add_event(action,event)

func _create_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("#14243f")
    sky_mat.sky_horizon_color = Color("#d67b67")
    sky_mat.ground_bottom_color = Color("#171923")
    sky_mat.ground_horizon_color = Color("#5e303a")
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#9aa9c8")
    env.ambient_light_energy = 0.48
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.glow_enabled = true
    env.glow_intensity = 0.34
    env.fog_enabled = true
    env.fog_light_color = Color("#7c4b57")
    env.fog_density = 0.003
    world.environment = env
    add_child(world)

func _on_start_requested(mode_id: String,map_id: String) -> void:
    if mode_id == "__leave__":
        _stop_match()
    else:
        _start_match(mode_id,map_id)

func _start_match(mode_id: String,map_id: String) -> void:
    current_mode = mode_id
    current_map = map_id
    round_number = 1
    kills = 0
    deaths = 0
    is_paused = false
    is_match_active = true
    _round_transition = false
    _respawn_pending = false
    map_factory.build_map(current_map)
    nav_grid = map_factory.make_navigation_grid()
    player.respawn_at(Vector3(0,0.1,43))
    player.configure_for_match()
    player.set_controls_enabled(true)
    ui.show_game_hud(OS.has_feature("mobile"))
    _spawn_round_bots()
    if not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _spawn_round_bots() -> void:
    _clear_bots()
    var mode := GameData.get_mode(current_mode)
    var count := int(mode.get("bots",8))
    if current_mode == "zombies":
        count = mini(5 + round_number * 2,22)
    elif current_mode == "battle_royale":
        count = mini(10 + round_number,18)
    elif current_mode == "training":
        count = 4
    var difficulty := "normal"
    if round_number >= 5:
        difficulty = "hard"
    if round_number >= 10:
        difficulty = "elite"
    for i in range(count):
        var bot := BotScript.new()
        bot.name = "HAX_BOT_%02d" % (i+1)
        var spawn: Vector3 = map_factory.spawn_points[(i+1) % map_factory.spawn_points.size()]
        bot.global_position = spawn + Vector3(randf_range(-2.0,2.0),0,randf_range(-2.0,2.0))
        bot.configure(player,nav_grid,difficulty,Color("#d71939") if i % 2 == 0 else Color("#e8792d"))
        bot.eliminated.connect(_on_bot_eliminated)
        add_child(bot)
        _bots.append(bot)

func _clear_bots() -> void:
    for bot in _bots:
        if is_instance_valid(bot):
            bot.queue_free()
    _bots.clear()

func _on_bot_eliminated(bot: Node,zone: String) -> void:
    kills += 1
    _bots.erase(bot)
    ui.add_kill_feed("%s  ✦  %s" % [bot.name,"HEADSHOT" if zone == "head" else "ELIMINATED"])
    if _bots.is_empty() and is_match_active and not _round_transition:
        _round_transition = true
        ui.add_kill_feed("ROUND CLEARED — NEXT WAVE INCOMING")
        get_tree().create_timer(2.5).timeout.connect(_next_round)

func _next_round() -> void:
    if not is_match_active:
        return
    round_number += 1
    _round_transition = false
    player.respawn_at(Vector3(0,0.1,43))
    _spawn_round_bots()

func _on_player_killed() -> void:
    if _respawn_pending or not is_match_active:
        return
    deaths += 1
    _respawn_pending = true
    ui.add_kill_feed("YOU WERE ELIMINATED — REDEPLOYING")
    player.set_controls_enabled(false)
    get_tree().create_timer(3.0).timeout.connect(func():
        if is_match_active:
            player.respawn_at(Vector3(0,0.1,43))
            player.set_controls_enabled(true)
        _respawn_pending = false
    )

func _on_health_changed(_health: float,_armor: float) -> void:
    pass

func _on_ammo_changed(_current: int,_reserve: int) -> void:
    pass

func _on_shot_fired(_weapon_id: String,hit: bool,headshot: bool) -> void:
    if lobby.room_code != "":
        lobby.send_shot()
    if hit:
        ui.show_hitmarker(headshot)

func _on_pause_requested(paused: bool) -> void:
    is_paused = paused
    player.set_controls_enabled(is_match_active and not paused)
    get_tree().paused = paused
    if not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_match_active and not paused else Input.MOUSE_MODE_VISIBLE

func _stop_match() -> void:
    is_match_active = false
    is_paused = false
    get_tree().paused = false
    player.set_controls_enabled(false)
    _clear_bots()
    lobby.leave_room()
    lan.close_session()
    ui.show_main_menu()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_setting_changed(key: String,value: Variant) -> void:
    match key:
        "sensitivity": player.mouse_sensitivity = 0.0011 + float(value) * 0.0032
        "aim_assist": player.aim_assist_enabled = bool(value)
        "aim_strength": player.aim_assist_strength = float(value)
        "aim_cone": player.aim_assist_cone = float(value)
        "weapon":
            for index in range(GameData.WEAPONS.size()):
                if str(GameData.WEAPONS[index].id) == str(value):
                    player.equip_weapon(index)
                    break
        "reload":
            player.begin_reload()
            if lobby.room_code != "":
                lobby.send_reload()
        "operator_skin": player.apply_operator_skin(str(value))
        "weapon_skin": player.apply_weapon_skin(str(value))
        "graphics": _set_graphics_quality(str(value))
        "volume": AudioServer.set_bus_volume_linear(0,float(value))

func _set_graphics_quality(level: String) -> void:
    match level:
        "low": get_viewport().msaa_3d = Viewport.MSAA_DISABLED
        "medium": get_viewport().msaa_3d = Viewport.MSAA_2X
        "high": get_viewport().msaa_3d = Viewport.MSAA_4X

func _on_room_create_requested(room_name: String,mode_id: String,map_id: String) -> void:
    current_mode = mode_id
    current_map = map_id
    lobby.player_name = "NACAR_22"
    lobby.create_room(room_name,mode_id,map_id)

func _on_room_join_requested(code: String) -> void:
    if code.length() < 4:
        ui.set_room_status("ENTER A VALID ROOM CODE")
        return
    lobby.player_name = "NACAR_22"
    lobby.join_room(code)

func _on_network_connection(_connected: bool,message: String) -> void:
    ui.set_room_status(message)

func _on_lan_host_requested(port: int) -> void:
    if lan.host(port) == OK:
        _start_match(current_mode,current_map)

func _on_lan_join_requested(address: String,port: int) -> void:
    if lan.join(address,port) == OK:
        _start_match(current_mode,current_map)

func _on_room_created(code: String) -> void:
    ui.set_room_status("ROOM CREATED: %s" % code)
    _start_match(current_mode,current_map)

func _on_room_joined(payload: Dictionary) -> void:
    var room: Dictionary = payload.get("room",{})
    current_mode = str(room.get("mode",current_mode))
    current_map = str(room.get("map",current_map))
    ui.set_room_status("JOINED ROOM %s" % str(payload.get("code","")))
    _start_match(current_mode,current_map)

func _on_network_error(message: String) -> void:
    ui.set_room_status(message)

func _on_network_packet(payload: Dictionary) -> void:
    var kind := str(payload.get("type",""))
    if kind == "snapshot":
        _apply_network_snapshot(payload)
    elif kind == "chat":
        ui.add_kill_feed("[SQUAD] %s: %s" % [payload.get("name","PLAYER"),payload.get("message","")])
    elif kind == "match_event":
        var state: Dictionary = payload.get("state",{})
        if str(payload.get("targetId","")) == lobby.client_id:
            player.apply_server_vitals(float(state.get("health",player.health)),float(state.get("armor",player.armor)))
        if str(payload.get("shooterId","")) == lobby.client_id:
            ui.add_kill_feed("HEADSHOT CONFIRMED" if bool(payload.get("headshot",false)) else "HIT CONFIRMED")
    elif kind == "shot_result" and bool(payload.get("hit",false)):
        ui.show_hitmarker(bool(payload.get("headshot",false)))

func _apply_network_snapshot(payload: Dictionary) -> void:
    var players: Array = payload.get("players",[])
    var seen: Dictionary = {}
    for remote in players:
        var rid := str(remote.get("id",""))
        if rid == "" or rid == lobby.client_id:
            continue
        seen[rid] = true
        if not _remote_operators.has(rid):
            _remote_operators[rid] = _make_remote_operator()
            add_child(_remote_operators[rid])
        var p: Dictionary = remote.get("position",{})
        var node: Node3D = _remote_operators[rid]
        node.global_position = node.global_position.lerp(Vector3(float(p.get("x",0)),float(p.get("y",0)),float(p.get("z",0))),0.45)
        node.rotation.y = lerp_angle(node.rotation.y,float(remote.get("yaw",0)),0.45)
    for rid in _remote_operators.keys():
        if not seen.has(str(rid)) and not str(rid).begins_with("lan_"):
            _remote_operators[rid].queue_free()
            _remote_operators.erase(rid)

func _make_remote_operator() -> Node3D:
    var actor := Node3D.new()
    var path := "res://assets/models/operators/operator_nacar.glb"
    if ResourceLoader.exists(path):
        var packed := load(path) as PackedScene
        if packed != null:
            var model := packed.instantiate() as Node3D
            if model != null:
                model.scale = Vector3.ONE * 0.82
                actor.add_child(model)
                return actor
    var capsule := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.34
    mesh.height = 1.85
    capsule.mesh = mesh
    capsule.position.y = 0.92
    actor.add_child(capsule)
    return actor

func _on_lan_snapshot(peer_id: int,position: Vector3,yaw: float,_pitch: float) -> void:
    if peer_id == multiplayer.get_unique_id():
        return
    var key := "lan_%d" % peer_id
    if not _remote_operators.has(key):
        _remote_operators[key] = _make_remote_operator()
        add_child(_remote_operators[key])
    var actor: Node3D = _remote_operators[key]
    actor.global_position = actor.global_position.lerp(position,0.42)
    actor.rotation.y = lerp_angle(actor.rotation.y,yaw,0.42)

func _on_lan_peer_disconnected(peer_id: int) -> void:
    var key := "lan_%d" % peer_id
    if _remote_operators.has(key):
        _remote_operators[key].queue_free()
        _remote_operators.erase(key)
