class_name FPSPlayer
extends CharacterBody3D

signal health_changed(health: float, armor: float)
signal ammo_changed(current: int, reserve: int)
signal player_killed
signal shot_fired(weapon_id: String, hit: bool, headshot: bool)

@export var move_speed := 6.6
@export var sprint_speed := 9.6
@export var mouse_sensitivity := 0.0018
@export var aim_assist_enabled := true
@export_range(0.0, 1.0, 0.01) var aim_assist_strength := 0.62
@export_range(2.0, 22.0, 0.5) var aim_assist_cone := 13.0

const GRAVITY := 24.0
const HIP_CAMERA_DISTANCE := 4.8
const AIM_CAMERA_DISTANCE := 2.65
const HIP_FOV := 74.0
const AIM_FOV := 57.0

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
var _camera_yaw := 0.0
var _pitch := deg_to_rad(-7.0)
var _camera_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _operator_root: Node3D
var _model: Node3D
var _weapon_mount: Node3D
var _weapon_visual: Node3D
var _muzzle: Marker3D
var _shot_audio: AudioStreamPlayer
var _reload_audio: AudioStreamPlayer
var _left_thigh: Node3D
var _right_thigh: Node3D
var _left_calf: Node3D
var _right_calf: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_forearm: Node3D
var _right_forearm: Node3D
var _anim_time := 0.0
var _last_move := Vector2.ZERO
var _sticky_target: Node3D
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

    _operator_root = Node3D.new()
    _operator_root.name = "ThirdPersonOperator"
    add_child(_operator_root)
    _build_operator_model()

    _camera_pivot = Node3D.new()
    _camera_pivot.name = "ShoulderCameraPivot"
    _camera_pivot.position = Vector3(0.0, 1.57, 0.0)
    add_child(_camera_pivot)
    _spring_arm = SpringArm3D.new()
    _spring_arm.name = "ShoulderSpringArm"
    _spring_arm.spring_length = HIP_CAMERA_DISTANCE
    # Orbit the boom behind the operator while keeping the camera aimed forward.
    _spring_arm.rotation.y = PI
    _spring_arm.margin = 0.22
    _spring_arm.collision_mask = 1
    _camera_pivot.add_child(_spring_arm)
    _camera = Camera3D.new()
    _camera.name = "ThirdPersonCamera"
    _camera.position = Vector3(0.48, 0.10, 0.0)
    _camera.rotation.y = PI
    _camera.current = true
    _camera.fov = HIP_FOV
    _spring_arm.add_child(_camera)

    _shot_audio = AudioStreamPlayer.new()
    _shot_audio.name = "WeaponAudio"
    add_child(_shot_audio)
    _reload_audio = AudioStreamPlayer.new()
    _reload_audio.name = "ReloadAudio"
    add_child(_reload_audio)

    add_to_group("player")
    for weapon in GameData.WEAPONS:
        ammo_by_weapon[weapon.id] = {"mag":weapon.mag, "reserve":weapon.reserve}
    equip_weapon(0)

func _build_operator_model() -> void:
    for child in _operator_root.get_children():
        child.queue_free()
    var model_path := "res://assets/models/operators/operator_nacar.glb"
    if current_operator_skin == "arctic_ghost":
        model_path = "res://assets/models/operators/operator_arctic.glb"
    elif current_operator_skin == "toxic_reign":
        model_path = "res://assets/models/operators/operator_toxic.glb"
    if ResourceLoader.exists(model_path):
        var packed := load(model_path) as PackedScene
        if packed != null:
            _model = packed.instantiate() as Node3D
            if _model != null:
                _model.name = "OperatorMesh"
                _model.scale = Vector3.ONE * 0.82
                _operator_root.add_child(_model)
                _apply_operator_model_tint(_model)
                _setup_procedural_rig()
                return
    _model = Node3D.new()
    _operator_root.add_child(_model)
    _build_fallback_operator()

func _setup_procedural_rig() -> void:
    _left_thigh = _make_joint_pivot(["thigh_L", "thigh_armor_L", "knee_pad_L", "cargo_pouch_L"], Vector3(-0.16, 1.08, 0.0), "LeftThighPivot")
    _right_thigh = _make_joint_pivot(["thigh_R", "thigh_armor_R", "knee_pad_R", "cargo_pouch_R"], Vector3(0.16, 1.08, 0.0), "RightThighPivot")
    _left_calf = _make_joint_pivot(["calf_L", "shin_guard_L", "boot_L", "boot_toe_L"], Vector3(-0.16, 0.51, 0.0), "LeftCalfPivot")
    _right_calf = _make_joint_pivot(["calf_R", "shin_guard_R", "boot_R", "boot_toe_R"], Vector3(0.16, 0.51, 0.0), "RightCalfPivot")
    _left_arm = _make_joint_pivot(["shoulder_L", "shoulder_badge_L", "upper_arm_L", "elbow_L"], Vector3(-0.40, 1.68, 0.0), "LeftArmPivot")
    _right_arm = _make_joint_pivot(["shoulder_R", "shoulder_badge_R", "upper_arm_R", "elbow_R"], Vector3(0.40, 1.68, 0.0), "RightArmPivot")
    _left_forearm = _make_joint_pivot(["forearm_L", "wrist_guard_L", "glove_L"], Vector3(-0.48, 1.19, -0.02), "LeftForearmPivot")
    _right_forearm = _make_joint_pivot(["forearm_R", "wrist_guard_R", "glove_R"], Vector3(0.48, 1.19, -0.02), "RightForearmPivot")
    if _left_arm:
        _left_arm.rotation.x = 0.78
        _left_arm.rotation.z = -0.10
    if _right_arm:
        _right_arm.rotation.x = 0.88
        _right_arm.rotation.z = 0.12
    if _left_forearm:
        _left_forearm.rotation.x = -0.18
    if _right_forearm:
        _right_forearm.rotation.x = -0.26

func _make_joint_pivot(mesh_names: Array, joint: Vector3, pivot_name: String) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = pivot_name
    pivot.position = joint
    _model.add_child(pivot)
    for mesh_name in mesh_names:
        var part := _find_operator_mesh(str(mesh_name))
        if part == null:
            continue
        var old_global := part.global_transform
        var old_parent := part.get_parent()
        old_parent.remove_child(part)
        pivot.add_child(part)
        part.transform = pivot.global_transform.affine_inverse() * old_global
    return pivot


func _find_operator_mesh(part_name: String) -> MeshInstance3D:
    var exact := _model.find_child(part_name, true, false) as MeshInstance3D
    if exact != null:
        return exact
    for node in _model.find_children("*", "MeshInstance3D", true, false):
        if node.name == part_name or str(node.name).contains(part_name):
            return node as MeshInstance3D
    return null

func _build_fallback_operator() -> void:
    var colors := _operator_colors()
    var dark := _material(colors[0], 0.72, 0.3)
    var trim := _material(colors[1], 0.35, 0.55, colors[1] * 0.45)
    var skin := _material(Color("#343b45"), 0.85, 0.05)
    _add_capsule(_model, Vector3(0, 1.03, 0), 0.34, 0.82, dark)
    _add_box(_model, Vector3(0, 1.38, -0.03), Vector3(0.72, 0.60, 0.38), skin)
    _add_box(_model, Vector3(0, 1.40, -0.24), Vector3(0.42, 0.25, 0.05), trim)
    _add_sphere(_model, Vector3(0, 1.82, 0), 0.24, dark)
    _add_box(_model, Vector3(0, 1.80, -0.22), Vector3(0.34, 0.10, 0.045), trim)
    _add_capsule(_model, Vector3(-0.43, 1.02, 0), 0.13, 0.70, dark)
    _add_capsule(_model, Vector3(0.43, 1.02, 0), 0.13, 0.70, dark)
    _add_box(_model, Vector3(-0.18, 0.43, 0), Vector3(0.23, 0.80, 0.27), dark)
    _add_box(_model, Vector3(0.18, 0.43, 0), Vector3(0.23, 0.80, 0.27), dark)

func _material(color: Color, roughness := 0.8, metallic := 0.0, emission := Color.BLACK) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    if emission != Color.BLACK:
        material.emission_enabled = true
        material.emission = emission
        material.emission_energy_multiplier = 1.6
    return material

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.material_override = material
    mesh.position = pos
    parent.add_child(mesh)

func _add_sphere(parent: Node3D, pos: Vector3, radius: float, material: Material) -> void:
    var mesh := MeshInstance3D.new()
    var shape := SphereMesh.new()
    shape.radius = radius
    shape.height = radius * 2.0
    mesh.mesh = shape
    mesh.material_override = material
    mesh.position = pos
    parent.add_child(mesh)

func _add_capsule(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> void:
    var mesh := MeshInstance3D.new()
    var shape := CapsuleMesh.new()
    shape.radius = radius
    shape.height = height
    mesh.mesh = shape
    mesh.material_override = material
    mesh.position = pos
    parent.add_child(mesh)

func _physics_process(delta: float) -> void:
    if is_dead:
        return
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    if reload_left > 0.0:
        reload_left = maxf(0.0, reload_left - delta)
        if reload_left == 0.0:
            _finish_reload()
    if not controls_enabled:
        _update_camera_pose(delta, false)
        return
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_action_just_pressed("jump") and not crouching:
        velocity.y = 7.6

    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if mobile_move.length() > 0.08:
        input_vector = mobile_move.limit_length(1.0)
    var yaw_basis := Basis(Vector3.UP, _camera_yaw)
    var move_direction := (yaw_basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
    var aiming := aim_held or Input.is_action_pressed("aim")
    var running := Input.is_action_pressed("sprint") and not aiming
    var speed := sprint_speed if running else move_speed
    if crouching:
        speed *= 0.58
    var desired_velocity := move_direction * speed
    velocity.x = move_toward(velocity.x, desired_velocity.x, (25.0 if move_direction.length() > 0.05 else 19.0) * delta)
    velocity.z = move_toward(velocity.z, desired_velocity.z, (25.0 if move_direction.length() > 0.05 else 19.0) * delta)
    move_and_slide()

    if move_direction.length() > 0.08:
        _face_direction(move_direction, delta, 10.0)
    elif aiming:
        var facing := Vector3(-sin(_camera_yaw), 0.0, -cos(_camera_yaw))
        _face_direction(facing, delta, 12.0)

    if mobile_look.length() > 0.0:
        _camera_yaw -= mobile_look.x * mouse_sensitivity * 2.15
        _pitch = clampf(_pitch - mobile_look.y * mouse_sensitivity * 2.15, deg_to_rad(-35.0), deg_to_rad(52.0))
        mobile_look = Vector2.ZERO

    if aiming:
        _apply_soft_aim(delta)
    _update_camera_pose(delta, aiming)
    if fire_held or Input.is_action_pressed("fire"):
        try_fire()
    _update_character_animation(delta, input_vector.length() > 0.08, running, aiming)

func _unhandled_input(event: InputEvent) -> void:
    if not controls_enabled or is_dead:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _camera_yaw -= event.relative.x * mouse_sensitivity
        _pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-35.0), deg_to_rad(52.0))
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
            KEY_1: equip_weapon(0)
            KEY_2: equip_weapon(1)
            KEY_3: equip_weapon(2)
            KEY_4: equip_weapon(3)
            KEY_5: equip_weapon(4)
            KEY_6: equip_weapon(5)
            KEY_C: set_crouch(not crouching)

func _face_direction(direction: Vector3, delta: float, turn_speed: float) -> void:
    if direction.length_squared() < 0.001:
        return
    var target_yaw := atan2(-direction.x, -direction.z)
    rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * turn_speed))

func _update_camera_pose(delta: float, aiming: bool) -> void:
    if not is_instance_valid(_camera_pivot):
        return
    _camera_pivot.rotation = Vector3(_pitch, _camera_yaw, 0.0)
    _spring_arm.rotation.y = PI
    _camera.rotation.y = PI
    _camera_pivot.position.x = lerpf(_camera_pivot.position.x, 0.58 if aiming else 0.0, delta * 8.0)
    _spring_arm.spring_length = lerpf(_spring_arm.spring_length, AIM_CAMERA_DISTANCE if aiming else HIP_CAMERA_DISTANCE, delta * 7.0)
    _camera.position.x = lerpf(_camera.position.x, 0.54 if aiming else 0.42, delta * 8.0)
    _camera.fov = lerpf(_camera.fov, AIM_FOV if aiming else HIP_FOV, delta * 6.5)

func _update_character_animation(delta: float, moving: bool, running: bool, aiming: bool) -> void:
    var cadence := 11.5 if running else 8.0
    if moving:
        _anim_time += delta * cadence
    var amount := 0.42 if moving else 0.0
    var swing := sin(_anim_time) * amount
    if _left_thigh:
        _left_thigh.rotation.x = lerpf(_left_thigh.rotation.x, swing, delta * 12.0)
    if _right_thigh:
        _right_thigh.rotation.x = lerpf(_right_thigh.rotation.x, -swing, delta * 12.0)
    if _left_calf:
        _left_calf.rotation.x = lerpf(_left_calf.rotation.x, maxf(0.0, -swing) * 0.85, delta * 12.0)
    if _right_calf:
        _right_calf.rotation.x = lerpf(_right_calf.rotation.x, maxf(0.0, swing) * 0.85, delta * 12.0)
    if is_instance_valid(_operator_root):
        var bob := sin(_anim_time * 2.0) * (0.025 if moving else 0.007)
        _operator_root.position.y = lerpf(_operator_root.position.y, bob, delta * 10.0)
        _operator_root.rotation.z = lerpf(_operator_root.rotation.z, (-0.025 if swing > 0.0 else 0.025) if moving else 0.0, delta * 9.0)
    if is_instance_valid(_weapon_mount):
        _weapon_mount.position.y = lerpf(_weapon_mount.position.y, 1.30 + (0.02 if moving else 0.0) + (0.02 if aiming else 0.0), delta * 12.0)

func configure_for_match() -> void:
    health = max_health
    armor = 75.0
    is_dead = false
    velocity = Vector3.ZERO
    _camera_yaw = 0.0
    _pitch = deg_to_rad(-7.0)
    rotation = Vector3.ZERO
    _camera_pivot.rotation = Vector3(_pitch, _camera_yaw, 0.0)
    _spring_arm.rotation.y = PI
    _camera.rotation.y = PI
    health_changed.emit(health, armor)
    _emit_ammo()

func respawn_at(point: Vector3) -> void:
    is_dead = false
    health = max_health
    armor = 75.0
    velocity = Vector3.ZERO
    global_position = point
    rotation = Vector3.ZERO
    _camera_yaw = 0.0
    _pitch = deg_to_rad(-7.0)
    _camera_pivot.rotation = Vector3(_pitch, _camera_yaw, 0.0)
    health_changed.emit(health, armor)

func set_controls_enabled(value: bool) -> void:
    controls_enabled = value
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value and not OS.has_feature("mobile") else Input.MOUSE_MODE_VISIBLE

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
    if is_instance_valid(_weapon_mount):
        _weapon_mount.queue_free()
    _weapon_mount = Node3D.new()
    _weapon_mount.name = "ThirdPersonWeapon"
    _weapon_mount.position = Vector3(0.31, 1.30, -0.34)
    _weapon_mount.rotation = Vector3(-0.07, 0.0, 0.0)
    _operator_root.add_child(_weapon_mount)
    _weapon_visual = Node3D.new()
    _weapon_mount.add_child(_weapon_visual)
    var model_path := "res://assets/models/weapons/%s.glb" % str(weapon_data.id)
    if ResourceLoader.exists(model_path):
        var packed := load(model_path) as PackedScene
        if packed != null:
            var model := packed.instantiate() as Node3D
            if model != null:
                model.scale = Vector3.ONE * 0.48
                model.position = Vector3(0.0, -0.015, -0.18)
                _apply_weapon_model_tint(model, _weapon_skin_color(current_weapon_skin, weapon_data.get("color", Color("#b70e28"))))
                _weapon_visual.add_child(model)
    _muzzle = Marker3D.new()
    _muzzle.position = Vector3(0.0, 0.01, -0.56)
    _weapon_mount.add_child(_muzzle)

func _apply_weapon_model_tint(node: Node, tint: Color) -> void:
    if node is MeshInstance3D and node.mesh != null:
        for surface in range(node.mesh.get_surface_count()):
            var source := node.get_active_material(surface)
            var material := StandardMaterial3D.new()
            if source is StandardMaterial3D:
                material = source.duplicate() as StandardMaterial3D
            material.albedo_color = material.albedo_color.lerp(tint, 0.18)
            node.set_surface_override_material(surface, material)
    for child in node.get_children():
        _apply_weapon_model_tint(child, tint)

func apply_operator_skin(skin_id: String) -> void:
    current_operator_skin = skin_id
    if is_instance_valid(_operator_root):
        _build_operator_model()
        _build_weapon_visual()

func apply_weapon_skin(skin_id: String) -> void:
    current_weapon_skin = skin_id
    if is_instance_valid(_weapon_mount):
        _build_weapon_visual()

func _weapon_skin_color(skin_id: String, fallback: Color) -> Color:
    for skin in GameData.WEAPON_SKINS:
        if str(skin.id) == skin_id:
            return skin.color
    return fallback

func _operator_colors() -> Array[Color]:
    for skin in GameData.OPERATOR_SKINS:
        if str(skin.id) == current_operator_skin:
            return [skin.color, skin.accent]
    return [Color("#15171d"), Color("#d71936")]

func _apply_operator_model_tint(node: Node) -> void:
    var palette := _operator_colors()
    for child in node.get_children():
        if child is MeshInstance3D and child.mesh != null:
            var mesh_node := child as MeshInstance3D
            var part_name := str(mesh_node.name).to_lower()
            var is_accent := part_name.contains("visor") or part_name.contains("knee") or part_name.contains("latch") or part_name.contains("pack_top") or part_name.contains("eye")
            for surface in range(mesh_node.mesh.get_surface_count()):
                var source := mesh_node.get_active_material(surface)
                var material := StandardMaterial3D.new()
                if source is StandardMaterial3D:
                    material = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
                var target_color: Color = palette[1] if is_accent else palette[0]
                material.albedo_color = material.albedo_color.lerp(target_color, 0.28 if is_accent else 0.18)
                mesh_node.set_surface_override_material(surface,material)
        _apply_operator_model_tint(child)

func try_fire() -> void:
    if not controls_enabled or is_dead or reload_left > 0.0 or fire_cooldown > 0.0:
        return
    var ammo: Dictionary = ammo_by_weapon[weapon_data.id]
    if int(ammo.mag) <= 0:
        if int(ammo.reserve) > 0:
            begin_reload()
        return
    ammo.mag = int(ammo.mag) - 1
    ammo_by_weapon[weapon_data.id] = ammo
    _play_weapon_sound()
    fire_cooldown = 60.0 / maxf(1.0, float(weapon_data.rpm))
    var shot_dir := _get_assisted_direction()
    var pellet_count := int(weapon_data.get("pellets", 1))
    var did_hit := false
    var did_headshot := false
    for _pellet in range(pellet_count):
        var direction := _add_spread(shot_dir, float(weapon_data.spread))
        var from := _camera.global_position + direction * 0.35
        var to := from + direction * float(weapon_data.range)
        var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
        query.exclude = [get_rid()]
        query.collide_with_areas = true
        query.collide_with_bodies = true
        var result := get_world_3d().direct_space_state.intersect_ray(query)
        if not result.is_empty():
            var collider: Object = result.collider
            if collider is Area3D:
                var victim := collider.get_parent() as Node
                if victim != null and victim.has_method("apply_damage"):
                    var is_head := str(collider.get_meta("hit_zone", "body")) == "head"
                    var damage := float(weapon_data.damage)
                    if is_head:
                        damage *= float(weapon_data.head)
                        did_headshot = true
                    victim.apply_damage(damage, "head" if is_head else "body")
                    did_hit = true
    _emit_ammo()
    shot_fired.emit(str(weapon_data.id), did_hit, did_headshot)
    if is_instance_valid(_weapon_mount):
        _weapon_mount.position.y = 1.34
        _weapon_mount.position.z = -0.39
    _pitch = clampf(_pitch + deg_to_rad(float(weapon_data.recoil) * 0.42), deg_to_rad(-35.0), deg_to_rad(52.0))
    _update_camera_pose(0.06, aim_held or Input.is_action_pressed("aim"))

func _play_weapon_sound() -> void:
    var sound := "rifle_shot"
    match str(weapon_data.id):
        "viper_smg": sound = "smg_shot"
        "kraken_12": sound = "shotgun_shot"
        "phantom_aw": sound = "sniper_shot"
        "sentinel_p": sound = "pistol_shot"
    _play_audio("res://assets/audio/%s.wav" % sound)

func _play_audio(path: String) -> void:
    if ResourceLoader.exists(path):
        _shot_audio.stream = load(path)
        _shot_audio.play()

func _get_assisted_direction() -> Vector3:
    var forward := -_camera.global_transform.basis.z
    if not aim_assist_enabled:
        return forward
    var strength := aim_assist_strength if (aim_held or Input.is_action_pressed("aim")) else aim_assist_strength * 0.18
    var cone_degrees := aim_assist_cone if strength > 0.3 else aim_assist_cone * 0.45
    var best_dot := cos(deg_to_rad(cone_degrees))
    var best_point := Vector3.ZERO
    for bot in get_tree().get_nodes_in_group("bots"):
        if not is_instance_valid(bot) or bot.is_dead:
            continue
        var point: Vector3 = bot.get_head_position() if bot.has_method("get_head_position") else bot.global_position + Vector3.UP * 1.45
        var to_target := point - _camera.global_position
        if to_target.length() > float(weapon_data.range):
            continue
        var dot := forward.dot(to_target.normalized())
        if dot > best_dot:
            best_dot = dot
            best_point = point
    if best_point != Vector3.ZERO:
        return forward.slerp((best_point - _camera.global_position).normalized(), strength).normalized()
    return forward

func _apply_soft_aim(delta: float) -> void:
    if not aim_assist_enabled:
        return
    var screen_center := get_viewport().get_visible_rect().size * 0.5
    var assist_radius := minf(screen_center.x, screen_center.y) * (aim_assist_cone / 45.0)
    var best_score := INF
    var desired := Vector3.ZERO
    var selected: Node3D = null
    for bot in get_tree().get_nodes_in_group("bots"):
        if not is_instance_valid(bot) or bot.is_dead:
            continue
        var point: Vector3 = bot.get_head_position() if bot.has_method("get_head_position") else bot.global_position + Vector3.UP * 1.45
        if not _camera.is_position_behind(point):
            var screen_point := _camera.unproject_position(point)
            var offset := screen_point.distance_to(screen_center)
            if offset <= assist_radius:
                var score := offset + _camera.global_position.distance_to(point) * 0.012
                if bot == _sticky_target:
                    score *= 0.72
                if score < best_score:
                    best_score = score
                    desired = point
                    selected = bot
    _sticky_target = selected
    if desired == Vector3.ZERO:
        return
    var direction := (desired - _camera.global_position).normalized()
    var wanted_yaw := atan2(-direction.x, -direction.z)
    var wanted_pitch := atan2(direction.y, Vector2(direction.x, direction.z).length())
    var pull := aim_assist_strength * delta * 10.0
    _camera_yaw = lerp_angle(_camera_yaw, wanted_yaw, minf(0.88, pull))
    _pitch = lerp_angle(_pitch, wanted_pitch, minf(0.82, pull * 0.86))
    if is_instance_valid(selected):
        _face_direction(Vector3(direction.x, 0.0, direction.z).normalized(), delta, 7.5)

func _add_spread(direction: Vector3, amount: float) -> Vector3:
    if amount <= 0.0:
        return direction
    var right := _camera.global_transform.basis.x
    var up := _camera.global_transform.basis.y
    var multiplier := 0.54 if (aim_held or Input.is_action_pressed("aim")) else 1.0
    return (direction + right * _rng.randf_range(-amount, amount) * multiplier + up * _rng.randf_range(-amount, amount) * multiplier).normalized()

func begin_reload() -> void:
    if reload_left > 0.0:
        return
    var ammo: Dictionary = ammo_by_weapon[weapon_data.id]
    var capacity := int(weapon_data.mag)
    if int(ammo.mag) >= capacity or int(ammo.reserve) <= 0:
        return
    reload_left = float(weapon_data.reload)
    _play_audio("res://assets/audio/reload_click.wav")

func _finish_reload() -> void:
    var ammo: Dictionary = ammo_by_weapon[weapon_data.id]
    var needed := int(weapon_data.mag) - int(ammo.mag)
    var transfer := mini(needed, int(ammo.reserve))
    ammo.mag = int(ammo.mag) + transfer
    ammo.reserve = int(ammo.reserve) - transfer
    ammo_by_weapon[weapon_data.id] = ammo
    _emit_ammo()

func take_damage(amount: float, source := "enemy") -> void:
    if is_dead:
        return
    var absorbed := minf(armor, amount * 0.62)
    armor -= absorbed
    health = maxf(0.0, health - (amount - absorbed))
    health_changed.emit(health, armor)
    if health <= 0.0:
        is_dead = true
        controls_enabled = false
        player_killed.emit()

func apply_server_vitals(authoritative_health: float, authoritative_armor: float) -> void:
    health = clampf(authoritative_health, 0.0, max_health)
    armor = clampf(authoritative_armor, 0.0, 100.0)
    health_changed.emit(health, armor)
    if health <= 0.0 and not is_dead:
        is_dead = true
        controls_enabled = false
        player_killed.emit()
    elif health > 0.0 and is_dead:
        is_dead = false

func heal(amount: float) -> void:
    health = minf(max_health, health + amount)
    health_changed.emit(health, armor)

func add_ammo(amount: int) -> void:
    if weapon_data.is_empty():
        return
    var ammo: Dictionary = ammo_by_weapon.get(str(weapon_data.id),{"mag":0,"reserve":0})
    ammo.reserve = int(ammo.reserve) + maxi(0,amount)
    ammo_by_weapon[str(weapon_data.id)] = ammo
    _emit_ammo()

func add_armor(amount: float) -> void:
    armor = minf(100.0,armor + maxf(0.0,amount))
    health_changed.emit(health,armor)

func add_weapon_pickup(index: int) -> void:
    equip_weapon(clampi(index,0,GameData.WEAPONS.size()-1))
    var ammo: Dictionary = ammo_by_weapon.get(str(weapon_data.id),{"mag":0,"reserve":0})
    ammo.reserve = maxi(int(ammo.reserve),int(weapon_data.reserve))
    ammo_by_weapon[str(weapon_data.id)] = ammo
    _emit_ammo()

func set_crouch(value: bool) -> void:
    crouching = value

func _emit_ammo() -> void:
    var ammo: Dictionary = ammo_by_weapon.get(weapon_data.get("id", "hax_ar"), {"mag":30,"reserve":180})
    ammo_changed.emit(int(ammo.mag), int(ammo.reserve))

func _weapon_bob(_delta: float, _moving: bool) -> void:
    pass
