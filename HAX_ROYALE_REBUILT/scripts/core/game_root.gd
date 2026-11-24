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
var current_map := "island"
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
var _zone_center := Vector3.ZERO
var _zone_radius := 116.0
var _zone_elapsed := 0.0
var _zone_tick := 0.0
var _zone_visual: MeshInstance3D
var _match_time := 0.0
var _loot_nodes: Array[Node3D] = []
var _loot_check_timer := 0.0
var _supply_drop_spawned := false
var _lobby_stage: Node3D
var _player_spawn_index := -1
var _squad_team_size := 1

func _ready() -> void:
    _setup_input_map()
    _create_environment()
    map_factory = MapFactoryScript.new()
    map_factory.name = "WorldMap"
    add_child(map_factory)
    map_factory.build_map(current_map)
    _create_lobby_stage()
    player = PlayerScript.new()
    player.name = "NACAR_PLAYER"
    add_child(player)
    player.global_position = Vector3(6,0.08,9)
    player.set_lobby_showcase(true)
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
    _squad_team_size = 1 if ui._squad_size == "SOLO" else (2 if ui._squad_size == "DUO" else 4)
    player.team_id = 0
    ui.show_main_menu()

func _process(delta: float) -> void:
    if not is_match_active or is_paused or not is_instance_valid(player):
        return
    _match_time += delta
    if current_mode == "battle_royale":
        _update_battle_royale(delta)
        _check_loot_pickups(delta)
    var ammo: Dictionary = player.ammo_by_weapon.get(str(player.weapon_data.get("id","hax_ar")),{"mag":0,"reserve":0})
    ui.update_hud(player.health,player.armor,int(ammo.get("mag",0)),int(ammo.get("reserve",0)),round_number,kills,deaths,str(GameData.get_mode(current_mode).name))
    if current_mode == "battle_royale":
        ui.update_battle_royale(_zone_radius,_zone_elapsed,kills,_bots.size())
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

func _create_lobby_stage() -> void:
    if is_instance_valid(_lobby_stage):
        _lobby_stage.queue_free()
    _lobby_stage = Node3D.new()
    _lobby_stage.name = "HAX_3D_LOBBY_SHOWCASE"
    add_child(_lobby_stage)
    _lobby_stage.position = Vector3(6.0,0.0,9.0)
    var platform_material := StandardMaterial3D.new()
    platform_material.albedo_color = Color("#111722")
    platform_material.metallic = 0.72
    platform_material.roughness = 0.32
    var platform := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 3.2
    disc.bottom_radius = 3.35
    disc.height = 0.26
    disc.radial_segments = 64
    platform.mesh = disc
    platform.material_override = platform_material
    platform.position.y = -0.12
    _lobby_stage.add_child(platform)
    var ring := MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 2.86
    ring_mesh.outer_radius = 3.0
    ring_mesh.rings = 72
    ring_mesh.ring_segments = 12
    ring.mesh = ring_mesh
    var ring_material := StandardMaterial3D.new()
    ring_material.albedo_color = Color("#ef234a")
    ring_material.emission_enabled = true
    ring_material.emission = Color("#e51b43")
    ring_material.emission_energy_multiplier = 1.9
    ring.material_override = ring_material
    ring.position.y = 0.025
    _lobby_stage.add_child(ring)
    var back_wall := MeshInstance3D.new()
    var wall_mesh := BoxMesh.new()
    wall_mesh.size = Vector3(11.0,6.0,0.5)
    back_wall.mesh = wall_mesh
    back_wall.position = Vector3(0.0,3.0,-4.2)
    back_wall.material_override = platform_material
    _lobby_stage.add_child(back_wall)
    for side in [-1.0,1.0]:
        var pylon := MeshInstance3D.new()
        var pylon_mesh := BoxMesh.new()
        pylon_mesh.size = Vector3(0.32,5.4,0.42)
        pylon.mesh = pylon_mesh
        var pylon_material := StandardMaterial3D.new()
        pylon_material.albedo_color = Color("#303b4b")
        pylon_material.metallic = 0.65
        pylon_material.roughness = 0.3
        pylon.material_override = pylon_material
        pylon.position = Vector3(side*4.3,2.7,-3.8)
        _lobby_stage.add_child(pylon)
        var blade := MeshInstance3D.new()
        var blade_mesh := BoxMesh.new()
        blade_mesh.size = Vector3(0.12,3.5,0.12)
        blade.mesh = blade_mesh
        blade.material_override = ring_material
        blade.position = Vector3(side*4.3,2.9,-3.5)
        _lobby_stage.add_child(blade)
        var spotlight := SpotLight3D.new()
        spotlight.light_color = Color("#ff3659") if side < 0.0 else Color("#4c91ff")
        spotlight.light_energy = 3.2
        spotlight.spot_range = 16.0
        spotlight.spot_angle = 38.0
        spotlight.position = Vector3(side*3.7,5.5,1.0)
        spotlight.rotation_degrees = Vector3(-48,0,0)
        _lobby_stage.add_child(spotlight)
    var logo_label := Label3D.new()
    logo_label.text = "HAX  /  NACAR_22"
    logo_label.position = Vector3(0,4.8,-3.88)
    logo_label.font_size = 64
    logo_label.pixel_size = 0.004
    logo_label.modulate = Color("#ff647c")
    logo_label.outline_size = 12
    logo_label.outline_modulate = Color("#070b13")
    _lobby_stage.add_child(logo_label)
    var subtitle := Label3D.new()
    subtitle.text = "ROYALE DIVISION   •   SEASON 01"
    subtitle.position = Vector3(0,4.25,-3.86)
    subtitle.font_size = 25
    subtitle.pixel_size = 0.004
    subtitle.modulate = Color("#e2e7ef")
    _lobby_stage.add_child(subtitle)

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
    _match_time = 0.0
    _loot_check_timer = 0.0
    if is_instance_valid(_lobby_stage):
        _lobby_stage.visible = false
    _supply_drop_spawned = false
    _clear_loot()
    _zone_elapsed = 0.0
    _zone_tick = 0.0
    _zone_center = Vector3(randf_range(-8.0,8.0),0.0,randf_range(-8.0,8.0))
    _zone_radius = 116.0
    if current_mode == "battle_royale":
        _create_safe_zone()
    else:
        _remove_safe_zone()
    var player_spawn := Vector3(0,0.1,43)
    _player_spawn_index = -1
    if current_mode == "battle_royale" and not map_factory.spawn_points.is_empty():
        _player_spawn_index = randi_range(0,map_factory.spawn_points.size()-1)
        player_spawn = map_factory.spawn_points[_player_spawn_index]
    player.respawn_at(player_spawn)
    player.configure_for_match()
    player.set_controls_enabled(true)
    ui.show_game_hud(OS.has_feature("mobile"))
    _spawn_round_bots()
    if current_mode == "battle_royale":
        _spawn_loot()
    if not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _spawn_round_bots() -> void:
    _clear_bots()
    var mode := GameData.get_mode(current_mode)
    var count := int(mode.get("bots",8))
    if lobby.room_code != "":
        count = 0
    if current_mode == "zombies" and lobby.room_code == "":
        count = mini(5 + round_number * 2,22)
    elif current_mode == "battle_royale" and lobby.room_code == "":
        count = 15
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
        var spawn_index := i % map_factory.spawn_points.size()
        if current_mode == "battle_royale" and _player_spawn_index >= 0 and spawn_index >= _player_spawn_index:
            spawn_index += 1
        var spawn: Vector3 = map_factory.spawn_points[spawn_index]
        bot.global_position = spawn + Vector3(randf_range(-2.0,2.0),0,randf_range(-2.0,2.0))
        var bot_team_id := i % 2
        if current_mode == "battle_royale":
            bot_team_id = int((i+1) / float(_squad_team_size))
        bot.configure(player,nav_grid,difficulty,Color("#d71939") if bot_team_id % 2 == 0 else Color("#e8792d"),bot_team_id,current_mode == "battle_royale")
        bot.eliminated.connect(_on_bot_eliminated)
        add_child(bot)
        _bots.append(bot)

func _clear_bots() -> void:
    for bot in _bots:
        if is_instance_valid(bot):
            bot.queue_free()
    _bots.clear()

func _on_bot_eliminated(bot: Node,zone: String) -> void:
    _bots.erase(bot)
    if zone != "zone" and zone != "bot":
        kills += 1
        ui.add_rank_points(18 if current_mode == "ranked" else 8)
        ui.add_kill_feed("%s  ✦  %s" % [bot.name,"HEADSHOT" if zone == "head" else "ELIMINATED"])
    var match_cleared := _bots.is_empty()
    if current_mode == "battle_royale":
        match_cleared = true
        for remaining in _bots:
            if is_instance_valid(remaining) and remaining.team_id != player.team_id:
                match_cleared = false
                break
    if match_cleared and is_match_active and not _round_transition:
        _round_transition = true
        if current_mode == "battle_royale":
            is_match_active = false
            player.set_controls_enabled(false)
            ui.add_rank_points(260)
            ui.show_match_result("VICTORY ROYALE","LAST OPERATOR STANDING",kills,"1 / 16",260)
            _remove_safe_zone()
            _clear_loot()
        else:
            ui.add_rank_points(35)
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
    player.set_controls_enabled(false)
    if current_mode == "battle_royale":
        is_match_active = false
        ui.add_rank_points(-35)
        ui.show_match_result("ELIMINATED","YOUR RUN HAS ENDED",kills,"TOP 16",-35)
        _remove_safe_zone()
        _clear_loot()
        _clear_bots()
        _respawn_pending = false
        return
    ui.add_kill_feed("YOU WERE ELIMINATED — REDEPLOYING")
    get_tree().create_timer(3.0).timeout.connect(func():
        if is_match_active:
            player.respawn_at(Vector3(0,0.1,43))
            player.set_controls_enabled(true)
        _respawn_pending = false
    )



func _spawn_loot() -> void:
    var points: Array[Vector3] = [
        Vector3(-62,0.1,-52),Vector3(-48,0.1,-72),Vector3(-72,0.1,-34),
        Vector3(62,0.1,-52),Vector3(82,0.1,-70),Vector3(70,0.1,-28),
        Vector3(-72,0.1,28),Vector3(-54,0.1,66),Vector3(-28,0.1,48),
        Vector3(62,0.1,28),Vector3(78,0.1,60),Vector3(28,0.1,68),
        Vector3(-18,0.1,-76),Vector3(16,0.1,-58),Vector3(18,0.1,24),
        Vector3(-18,0.1,16),Vector3(44,0.1,2),Vector3(-42,0.1,-4)
    ]
    var kinds := ["ammo","medkit","armor","ammo","weapon","medkit","armor","ammo","weapon","ammo","medkit","armor","ammo","weapon","ammo","medkit","armor","ammo"]
    for i in range(points.size()):
        var kind: String = kinds[i]
        var weapon_index := randi_range(0,GameData.WEAPONS.size()-1)
        var amount := 55
        if kind == "ammo":
            amount = 65
        elif kind == "medkit":
            amount = 35
        elif kind == "armor":
            amount = 35
        _create_loot_drop(points[i],kind,amount,weapon_index)

func _create_loot_drop(pos: Vector3,kind: String,amount: int,weapon_index := 0) -> void:
    var drop := Node3D.new()
    drop.name = "HAX_LOOT_" + kind.to_upper()
    drop.position = pos + Vector3(0,0.05,0)
    drop.set_meta("loot_type",kind)
    drop.set_meta("loot_amount",amount)
    drop.set_meta("weapon_index",weapon_index)
    var color := Color("#f0b63d")
    var label_text := "AMMO"
    match kind:
        "medkit":
            color = Color("#5fe08b")
            label_text = "MEDKIT"
        "armor":
            color = Color("#54b7ff")
            label_text = "ARMOR"
        "weapon":
            color = Color("#ff4d68")
            label_text = "WEAPON"
        "supply":
            color = Color("#ff3155")
            label_text = "SUPPLY DROP"
    var crate := MeshInstance3D.new()
    var crate_mesh := BoxMesh.new()
    crate_mesh.size = Vector3(0.82,0.62,0.82)
    crate.mesh = crate_mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#171f2c")
    material.metallic = 0.55
    material.roughness = 0.38
    crate.material_override = material
    crate.position.y = 0.36
    drop.add_child(crate)
    var stripe := MeshInstance3D.new()
    var stripe_mesh := BoxMesh.new()
    stripe_mesh.size = Vector3(0.86,0.09,0.86)
    stripe.mesh = stripe_mesh
    var stripe_material := StandardMaterial3D.new()
    stripe_material.albedo_color = color
    stripe_material.emission_enabled = true
    stripe_material.emission = color
    stripe_material.emission_energy_multiplier = 1.2
    stripe.material_override = stripe_material
    stripe.position.y = 0.55
    drop.add_child(stripe)
    var light := OmniLight3D.new()
    light.position.y = 1.15
    light.light_color = color
    light.light_energy = 0.8 if kind != "supply" else 1.8
    light.omni_range = 5.5 if kind != "supply" else 12.0
    drop.add_child(light)
    var label := Label3D.new()
    label.text = label_text
    label.position.y = 1.55
    label.pixel_size = 0.008
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.modulate = color
    drop.add_child(label)
    if kind == "supply":
        var beacon := MeshInstance3D.new()
        var beam := CylinderMesh.new()
        beam.top_radius = 0.18
        beam.bottom_radius = 0.18
        beam.height = 15.0
        beacon.mesh = beam
        var beam_mat := StandardMaterial3D.new()
        beam_mat.albedo_color = Color(1.0,0.08,0.2,0.16)
        beam_mat.emission_enabled = true
        beam_mat.emission = Color("#ff163f")
        beam_mat.emission_energy_multiplier = 0.55
        beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        beacon.material_override = beam_mat
        beacon.position.y = 8.0
        drop.add_child(beacon)
    add_child(drop)
    _loot_nodes.append(drop)

func _check_loot_pickups(delta: float) -> void:
    _loot_check_timer += delta
    if _loot_check_timer < 0.18:
        return
    _loot_check_timer = 0.0
    for drop in _loot_nodes.duplicate():
        if not is_instance_valid(drop):
            _loot_nodes.erase(drop)
            continue
        if player.global_position.distance_to(drop.global_position) > 2.35:
            continue
        var kind := str(drop.get_meta("loot_type","ammo"))
        var amount := int(drop.get_meta("loot_amount",50))
        match kind:
            "ammo":
                player.add_ammo(amount)
                ui.add_kill_feed("LOOT PICKED  •  AMMO +%d" % amount)
            "medkit":
                player.heal(float(amount))
                ui.add_kill_feed("LOOT PICKED  •  MEDKIT +%d HP" % amount)
            "armor":
                player.add_armor(float(amount))
                ui.add_kill_feed("LOOT PICKED  •  ARMOR +%d" % amount)
            "weapon":
                var weapon_idx := int(drop.get_meta("weapon_index",0))
                player.add_weapon_pickup(weapon_idx)
                ui.add_kill_feed("LOOT PICKED  •  %s" % GameData.WEAPONS[weapon_idx].name)
            "supply":
                player.heal(45.0)
                player.add_armor(55.0)
                var supply_weapon_idx := int(drop.get_meta("weapon_index",3))
                player.add_weapon_pickup(supply_weapon_idx)
                player.add_ammo(120)
                ui.add_kill_feed("SUPPLY DROP SECURED  •  RARE LOADOUT")
        _loot_nodes.erase(drop)
        drop.queue_free()

func _spawn_supply_drop() -> void:
    var angle := randf_range(0.0,TAU)
    var distance := randf_range(10.0,maxf(12.0,_zone_radius*0.45))
    var point := _zone_center + Vector3(cos(angle)*distance,0.1,sin(angle)*distance)
    var weapon_index := randi_range(0,GameData.WEAPONS.size()-1)
    _create_loot_drop(point,"supply",120,weapon_index)
    ui.add_kill_feed("SUPPLY DROP INBOUND  •  CHECK THE RED BEACON")

func _clear_loot() -> void:
    for drop in _loot_nodes:
        if is_instance_valid(drop):
            drop.queue_free()
    _loot_nodes.clear()

func _create_safe_zone() -> void:
    _remove_safe_zone()
    var zone := Node3D.new()
    zone.name = "HAX_SAFE_ZONE"
    zone.position = _zone_center + Vector3(0,0.18,0)
    add_child(zone)
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.985
    torus.outer_radius = 1.0
    torus.rings = 72
    torus.ring_segments = 10
    ring.mesh = torus
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(1.0,0.12,0.23,0.78)
    material.emission_enabled = true
    material.emission = Color("#ff234b")
    material.emission_energy_multiplier = 2.0
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring.material_override = material
    zone.add_child(ring)
    _zone_visual = ring
    _update_zone_visual()

func _remove_safe_zone() -> void:
    var zone := get_node_or_null("HAX_SAFE_ZONE")
    if zone:
        zone.queue_free()
    _zone_visual = null

func _update_zone_visual() -> void:
    if is_instance_valid(_zone_visual):
        _zone_visual.scale = Vector3(_zone_radius,1.0,_zone_radius)

func _update_battle_royale(delta: float) -> void:
    _zone_elapsed += delta
    _zone_tick += delta
    if _zone_elapsed >= 65.0 and not _supply_drop_spawned:
        _supply_drop_spawned = true
        _spawn_supply_drop()
    if _zone_elapsed > 24.0 and _zone_radius > 18.0:
        var phase: float = floor((_zone_elapsed - 24.0) / 22.0)
        var target_radius := maxf(18.0, 116.0 - phase * 14.0)
        if target_radius < _zone_radius:
            _zone_radius = target_radius
            _update_zone_visual()
            ui.add_kill_feed("SAFE ZONE SHRINKING — MOVE TO THE RED RING")
    if _zone_tick >= 1.0:
        _zone_tick = 0.0
        if player.global_position.distance_to(_zone_center) > _zone_radius:
            player.take_damage(6.0,"STORM")
        for bot in _bots:
            if is_instance_valid(bot) and bot.global_position.distance_to(_zone_center) > _zone_radius:
                bot.apply_damage(7.0,"zone")

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
    _clear_loot()
    _remove_safe_zone()
    lobby.leave_room()
    lan.close_session()
    if is_instance_valid(_lobby_stage):
        _lobby_stage.visible = true
    player.global_position = Vector3(6,0.08,9)
    player.set_lobby_showcase(true)
    if is_instance_valid(_lobby_stage):
        _lobby_stage.visible = true
    player.global_position = Vector3(6,0.08,9)
    player.set_lobby_showcase(true)
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
        "weapon_next": player.equip_weapon(posmod(player.current_weapon_index + 1,GameData.WEAPONS.size()))
        "crouch": player.set_crouch(not player.crouching)
        "squad_size":
            _squad_team_size = 1 if str(value) == "SOLO" else (2 if str(value) == "DUO" else 4)
            player.team_id = 0
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
