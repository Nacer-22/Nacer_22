class_name FPSPlayer
extends CharacterBody3D

signal health_changed(health: float, armor: float)
signal ammo_changed(current: int, reserve: int)
signal player_killed
signal shot_fired(weapon_id: String, hit: bool, headshot: bool)

@export var move_speed := 7.2
@export var sprint_speed := 10.2
@export var mouse_sensitivity := 0.0018
@export var aim_assist_enabled := true
@export_range(0.0, 1.0, 0.01) var aim_assist_strength := 0.32
@export_range(2.0, 18.0, 0.5) var aim_assist_cone := 8.0

var max_health := 100.0
var health := 100.0
var armor := 75.0
var is_dead := false
var controls_enabled := false
var current_weapon_index := 0
var current_operator_skin := "nacar_shadow"
var current_weapon_skin := "blackout"
var weapon_data: Dictionary = {}
var ammo_by_weapon: Dictionary = {}
var reload_left := 0.0
var fire_cooldown := 0.0
var fire_held := false
var aim_held := false
var crouching := false
var mobile_move := Vector2.ZERO
var mobile_look := Vector2.ZERO
var _pitch := 0.0
var _camera: Camera3D
var _weapon_root: Node3D
var _shot_audio: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    collision_layer = 2
    collision_mask = 1
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.9
    var collider := CollisionShape3D.new()
    collider.shape = capsule
    collider.position.y = 0.95
    add_child(collider)
    _camera = Camera3D.new()
    _camera.position = Vector3(0, 1.62, 0)
    _camera.fov = 82.0
    _camera.current = true
    add_child(_camera)
    _shot_audio = AudioStreamPlayer.new()
    _shot_audio.name = "WeaponAudio"
    add_child(_shot_audio)
    _weapon_root = Node3D.new()
    _weapon_root.position = Vector3(0.32, -0.27, -0.5)
    _camera.add_child(_weapon_root)
    add_to_group("player")
    for weapon in GameData.WEAPONS:
        ammo_by_weapon[str(weapon.id)] = {"mag":int(weapon.mag), "reserve":int(weapon.reserve)}
    equip_weapon(0)

func _physics_process(delta: float) -> void:
    if is_dead:
        return
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    if reload_left > 0.0:
        reload_left = maxf(0.0, reload_left - delta)
        if reload_left == 0.0:
            _finish_reload()
    if not controls_enabled:
        return
    if not is_on_floor():
        velocity.y -= 24.0 * delta
    elif Input.is_action_just_pressed("jump") and not crouching:
        velocity.y = 8.2
    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if mobile_move.length() > 0.08:
        input_vector = mobile_move
    var direction := (global_transform.basis.x * input_vector.x - global_transform.basis.z * input_vector.y).normalized()
    var speed := sprint_speed if Input.is_action_pressed("sprint") else move_speed
    if crouching:
        speed *= 0.55
    velocity.x = move_toward(velocity.x, direction.x * speed, 28.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, 28.0 * delta)
    move_and_slide()
    if mobile_look.length() > 0.0:
        rotate_y(-mobile_look.x * mouse_sensitivity * 2.0)
        _pitch = clampf(_pitch - mobile_look.y * mouse_sensitivity * 2.0, deg_to_rad(-83), deg_to_rad(83))
        _camera.rotation.x = _pitch
        mobile_look = Vector2.ZERO
    if aim_held or Input.is_action_pressed("aim"):
        _apply_soft_aim(delta)
    if fire_held or Input.is_action_pressed("fire"):
        try_fire()
    _weapon_root.position.y = lerpf(_weapon_root.position.y, -0.27 + sin(Time.get_ticks_msec() * 0.012) * 0.012 * input_vector.length(), delta * 8.0)

func _unhandled_input(event: InputEvent) -> void:
    if not controls_enabled or is_dead:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        _pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-83), deg_to_rad(83))
        _camera.rotation.x = _pitch
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            fire_held = event.pressed
            if event.pressed:
                try_fire()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            aim_held = event.pressed
        elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            equip_weapon(posmod(current_weapon_index - 1, GameData.WEAPONS.size()))
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            equip_weapon(posmod(current_weapon_index + 1, GameData.WEAPONS.size()))
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_R: begin_reload()
            KEY_1, KEY_KP_1: equip_weapon(0)
            KEY_2, KEY_KP_2: equip_weapon(1)
            KEY_3, KEY_KP_3: equip_weapon(2)
            KEY_4, KEY_KP_4: equip_weapon(3)
            KEY_5, KEY_KP_5: equip_weapon(4)
            KEY_6, KEY_KP_6: equip_weapon(5)
            KEY_C: crouching = not crouching

func configure_for_match() -> void:
    health = max_health
    armor = 75.0
    is_dead = false
    velocity = Vector3.ZERO
    reload_left = 0.0
    fire_cooldown = 0.0
    _pitch = 0.0
    rotation = Vector3.ZERO
    _camera.rotation = Vector3.ZERO
    _emit_vitals()
    _emit_ammo()

func respawn_at(point: Vector3) -> void:
    is_dead = false
    health = max_health
    armor = 75.0
    velocity = Vector3.ZERO
    global_position = point
    global_rotation = Vector3.ZERO
    _pitch = 0.0
    _camera.rotation = Vector3.ZERO
    fire_cooldown = 0.0
    reload_left = 0.0
    _emit_vitals()
    _emit_ammo()

func set_controls_enabled(value: bool) -> void:
    controls_enabled = value
    if not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE

func set_mobile_move(value: Vector2) -> void:
    mobile_move = value.limit_length(1.0)

func set_mobile_look(value: Vector2) -> void:
    mobile_look += value

func set_mobile_fire(value: bool) -> void:
    fire_held = value
    if value:
        try_fire()

func set_mobile_aim(value: bool) -> void:
    aim_held = value

func equip_weapon(index: int) -> void:
    current_weapon_index = clampi(index, 0, GameData.WEAPONS.size() - 1)
    weapon_data = GameData.WEAPONS[current_weapon_index].duplicate(true)
    _build_weapon_visual()
    _emit_ammo()

func _build_weapon_visual() -> void:
    for child in _weapon_root.get_children():
        child.queue_free()
    var weapon_model_path := "res://assets/models/weapons/%s.glb" % str(weapon_data.id)
    if ResourceLoader.exists(weapon_model_path):
        var scene := load(weapon_model_path) as PackedScene
        if scene != null:
            var instance := scene.instantiate() as Node3D
            if instance != null:
                instance.scale = Vector3.ONE * 0.48
                instance.position = Vector3(0, -0.035, -0.27)
                _tint_model(instance, _skin_color())
                _weapon_root.add_child(instance)
                return
    var body := StandardMaterial3D.new()
    body.albedo_color = Color("#20242d")
    body.metallic = 0.72
    body.roughness = 0.35
    var accent := StandardMaterial3D.new()
    accent.albedo_color = _skin_color()
    accent.metallic = 0.48
    var receiver := _box(Vector3(0, 0, 0), Vector3(0.16, 0.16, 0.52), body)
    _weapon_root.add_child(receiver)
    _weapon_root.add_child(_box(Vector3(0, 0.015, -0.36), Vector3(0.065, 0.065, 0.42), accent))
    _weapon_root.add_child(_box(Vector3(0, -0.14, 0.05), Vector3(0.13, 0.26, 0.17), body))

func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.material_override = mat
    mesh.position = pos
    return mesh

func _tint_model(node: Node, tint: Color) -> void:
    if node is MeshInstance3D and node.mesh != null:
        for surface in range(node.mesh.get_surface_count()):
            var material := StandardMaterial3D.new()
            material.albedo_color = tint
            material.metallic = 0.55
            material.roughness = 0.38
            node.set_surface_override_material(surface, material)
    for child in node.get_children():
        _tint_model(child, tint)

func _skin_color() -> Color:
    for skin in GameData.WEAPON_SKINS:
        if str(skin.id) == current_weapon_skin:
            return skin.color
    return weapon_data.get("color", Color("#b70e28"))

func apply_operator_skin(skin_id: String) -> void:
    current_operator_skin = skin_id

func apply_weapon_skin(skin_id: String) -> void:
    current_weapon_skin = skin_id
    _build_weapon_visual()

func try_fire() -> void:
    if not controls_enabled or is_dead or reload_left > 0.0 or fire_cooldown > 0.0:
        return
    var ammo: Dictionary = ammo_by_weapon.get(str(weapon_data.id), {})
    if int(ammo.get("mag", 0)) <= 0:
        if int(ammo.get("reserve", 0)) > 0:
            begin_reload()
        return
    ammo.mag = int(ammo.mag) - 1
    ammo_by_weapon[str(weapon_data.id)] = ammo
    fire_cooldown = 60.0 / maxf(1.0, float(weapon_data.rpm))
    _play_weapon_sound()
    var direction := _get_assisted_direction()
    var pellets := int(weapon_data.get("pellets", 1))
    var did_hit := false
    var did_headshot := false
    for index in range(pellets):
        var spread := direction
        if float(weapon_data.spread) > 0.0:
            spread = (direction + _camera.global_transform.basis.x * _rng.randf_range(-float(weapon_data.spread), float(weapon_data.spread)) + _camera.global_transform.basis.y * _rng.randf_range(-float(weapon_data.spread), float(weapon_data.spread))).normalized()
        var from := _camera.global_position
        var to := from + spread * float(weapon_data.range)
        var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
        query.exclude = [get_rid()]
        query.collide_with_areas = true
        query.collide_with_bodies = false
        var hit := get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty() and hit.collider is Area3D:
            var victim: Node = hit.collider.get_parent()
            if victim.has_method("apply_damage"):
                var head := str(hit.collider.get_meta("hit_zone", "body")) == "head"
                victim.apply_damage(float(weapon_data.damage) * (float(weapon_data.head) if head else 1.0), "head" if head else "body")
                did_hit = true
                did_headshot = did_headshot or head
    _emit_ammo()
    shot_fired.emit(str(weapon_data.id), did_hit, did_headshot)
    _weapon_root.position.y = -0.23 + float(weapon_data.recoil) * 0.015
    _pitch = clampf(_pitch + float(weapon_data.recoil) * 0.004, deg_to_rad(-83), deg_to_rad(83))
    _camera.rotation.x = _pitch

func _get_assisted_direction() -> Vector3:
    var forward := -_camera.global_transform.basis.z
    if not aim_assist_enabled:
        return forward
    var best_dot := cos(deg_to_rad(aim_assist_cone))
    var best_point := Vector3.ZERO
    for bot in get_tree().get_nodes_in_group("bots"):
        if not is_instance_valid(bot) or bool(bot.get("is_dead")):
            continue
        var point: Vector3 = bot.get_head_position()
        var to_target := point - _camera.global_position
        if to_target.length() <= float(weapon_data.range) and forward.dot(to_target.normalized()) > best_dot:
            best_dot = forward.dot(to_target.normalized())
            best_point = point
    if best_point != Vector3.ZERO:
        return forward.slerp((best_point - _camera.global_position).normalized(), aim_assist_strength).normalized()
    return forward

func _apply_soft_aim(delta: float) -> void:
    if not aim_assist_enabled:
        return
    var forward := -_camera.global_transform.basis.z
    var desired := Vector3.ZERO
    var best_dot := cos(deg_to_rad(aim_assist_cone))
    for bot in get_tree().get_nodes_in_group("bots"):
        if not is_instance_valid(bot) or bool(bot.get("is_dead")):
            continue
        var point: Vector3 = bot.get_head_position()
        var to_point := point - _camera.global_position
        var dot := forward.dot(to_point.normalized())
        if to_point.length() < float(weapon_data.range) and dot > best_dot:
            best_dot = dot
            desired = point
    if desired != Vector3.ZERO:
        var target_local := global_transform.basis.inverse() * (desired - _camera.global_position).normalized()
        rotate_y(lerp_angle(0.0, atan2(-target_local.x, -target_local.z), aim_assist_strength * delta * 2.5))
        _pitch = lerp_angle(_pitch, asin(clampf(target_local.y, -1.0, 1.0)), aim_assist_strength * delta * 2.5)
        _camera.rotation.x = _pitch

func begin_reload() -> void:
    if reload_left > 0.0:
        return
    var ammo: Dictionary = ammo_by_weapon.get(str(weapon_data.id), {})
    if int(ammo.get("mag", 0)) >= int(weapon_data.mag) or int(ammo.get("reserve", 0)) <= 0:
        return
    reload_left = float(weapon_data.reload)
    var stream := load("res://assets/audio/reload_click.wav") if ResourceLoader.exists("res://assets/audio/reload_click.wav") else null
    if stream != null:
        _shot_audio.stream = stream
        _shot_audio.play()

func _finish_reload() -> void:
    var ammo: Dictionary = ammo_by_weapon[str(weapon_data.id)]
    var moved := mini(int(weapon_data.mag) - int(ammo.mag), int(ammo.reserve))
    ammo.mag = int(ammo.mag) + moved
    ammo.reserve = int(ammo.reserve) - moved
    ammo_by_weapon[str(weapon_data.id)] = ammo
    _emit_ammo()

func _play_weapon_sound() -> void:
    var key := str(weapon_data.id)
    var sound := "rifle_shot" if key in ["hax_ar", "reaper_dmr"] else "smg_shot"
    if key == "kraken_12": sound = "shotgun_shot"
    if key == "phantom_aw": sound = "sniper_shot"
    if key == "sentinel_p": sound = "pistol_shot"
    var path := "res://assets/audio/%s.wav" % sound
    if ResourceLoader.exists(path):
        _shot_audio.stream = load(path)
        _shot_audio.play()

func take_damage(amount: float, _source := "enemy") -> void:
    if is_dead:
        return
    var absorbed := minf(armor, amount * 0.62)
    armor -= absorbed
    health = maxf(0.0, health - (amount - absorbed))
    _emit_vitals()
    if health <= 0.0:
        is_dead = true
        controls_enabled = false
        player_killed.emit()

func heal(amount: float) -> void:
    health = minf(max_health, health + amount)
    _emit_vitals()

func _emit_vitals() -> void:
    health_changed.emit(health, armor)

func _emit_ammo() -> void:
    var ammo: Dictionary = ammo_by_weapon.get(str(weapon_data.get("id", "hax_ar")), {"mag":30,"reserve":180})
    ammo_changed.emit(int(ammo.get("mag", 0)), int(ammo.get("reserve", 0)))

func apply_server_vitals(server_health: float, server_armor: float) -> void:
    health = clampf(server_health, 0, max_health)
    armor = clampf(server_armor, 0, 100)
    _emit_vitals()
    if health <= 0 and not is_dead:
        is_dead = true
        controls_enabled = false
        player_killed.emit()
    elif health > 0:
        is_dead = false
