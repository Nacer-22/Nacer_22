class_name CombatBot
extends CharacterBody3D

signal eliminated(bot: Node, killer_zone: String)

var max_health := 100.0
var health := 100.0
var move_speed := 4.4
var damage := 8.0
var fire_interval := 1.25
var accuracy := 0.68
var target: Node3D
var player_owner: FPSPlayer
var team_id := 0
var battle_royale := false
var _target_refresh_timer := 0.0
var navigation_grid: AStarGrid2D
var path_points: Array[Vector2i] = []
var path_index := 0
var path_timer := 0.0
var attack_timer := 0.8
var stuck_timer := 0.0
var previous_position := Vector3.ZERO
var strafe_sign := 1.0
var is_dead := false
var _head_area: Area3D
var _body_area: Area3D
var _team_color := Color("#d31b39")
var _rng := RandomNumberGenerator.new()

func configure(player: FPSPlayer, grid: AStarGrid2D, difficulty := "normal", team_color := Color("#d31b39"), new_team_id := 0, use_battle_royale := false) -> void:
    player_owner = player
    target = player
    navigation_grid = grid
    _team_color = team_color
    team_id = new_team_id
    battle_royale = use_battle_royale
    match difficulty:
        "easy":
            move_speed = 3.4
            damage = 5.0
            fire_interval = 1.7
            accuracy = 0.38
        "hard":
            move_speed = 5.3
            damage = 12.0
            fire_interval = 0.92
            accuracy = 0.82
        "elite":
            move_speed = 6.0
            damage = 15.0
            fire_interval = 0.74
            accuracy = 0.9
    _build_collision()
    _build_visual()
    add_to_group("bots")
    previous_position = global_position

func _ready() -> void:
    _rng.randomize()
    collision_layer = 2
    collision_mask = 1
    strafe_sign = -1.0 if _rng.randf() < 0.5 else 1.0

func _build_collision() -> void:
    var shape := CapsuleShape3D.new()
    shape.radius = 0.36
    shape.height = 1.82
    var body_collision := CollisionShape3D.new()
    body_collision.shape = shape
    body_collision.position.y = 0.91
    add_child(body_collision)
    _head_area = Area3D.new()
    _head_area.collision_layer = 4
    _head_area.collision_mask = 0
    _head_area.set_meta("hit_zone", "head")
    var head_shape := CollisionShape3D.new()
    var head_sphere := SphereShape3D.new()
    head_sphere.radius = 0.23
    head_shape.shape = head_sphere
    head_shape.position = Vector3(0, 1.72, 0)
    _head_area.add_child(head_shape)
    add_child(_head_area)
    _body_area = Area3D.new()
    _body_area.collision_layer = 4
    _body_area.collision_mask = 0
    _body_area.set_meta("hit_zone", "body")
    var body_shape := CollisionShape3D.new()
    var body_box := BoxShape3D.new()
    body_box.size = Vector3(0.78, 0.88, 0.48)
    body_shape.shape = body_box
    body_shape.position = Vector3(0, 1.02, 0)
    _body_area.add_child(body_shape)
    add_child(_body_area)

func _build_visual() -> void:
    var model_path := "res://assets/models/operators/operator_nacar.glb"
    if _team_color.b > _team_color.r * 1.4:
        model_path = "res://assets/models/operators/operator_arctic.glb"
    elif _team_color.g > _team_color.r * 0.9:
        model_path = "res://assets/models/operators/operator_toxic.glb"
    if ResourceLoader.exists(model_path):
        var packed := load(model_path) as PackedScene
        if packed != null:
            var actor := packed.instantiate() as Node3D
            if actor != null:
                actor.scale = Vector3.ONE * 0.82
                actor.position.y = -0.015
                add_child(actor)
                return
    var material := StandardMaterial3D.new()
    material.albedo_color = _team_color
    var mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.34
    capsule.height = 1.85
    mesh.mesh = capsule
    mesh.material_override = material
    mesh.position.y = 0.92
    add_child(mesh)

func _physics_process(delta: float) -> void:
    if is_dead:
        return
    if battle_royale:
        _target_refresh_timer -= delta
        if not is_instance_valid(target) or _target_is_dead() or _target_refresh_timer <= 0.0:
            _choose_battle_target()
    if not is_instance_valid(target) or _target_is_dead():
        velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
        return
    if not is_on_floor():
        velocity.y -= 24.0 * delta
    path_timer -= delta
    attack_timer -= delta
    var to_target := target.global_position - global_position
    to_target.y = 0
    var distance := to_target.length()
    if distance > 11.0:
        if path_timer <= 0.0:
            _repath()
        _follow_path(delta)
    else:
        _combat_move(delta, to_target, distance)
        if attack_timer <= 0.0:
            _attack_target(distance)
            attack_timer = fire_interval * _rng.randf_range(0.85, 1.2)
    if global_position.distance_to(previous_position) < 0.025 and distance > 3.0:
        stuck_timer += delta
    else:
        stuck_timer = 0.0
    previous_position = global_position
    if stuck_timer > 0.55:
        path_timer = 0.0
        stuck_timer = 0.0
        strafe_sign *= -1.0
    move_and_slide()

func _repath() -> void:
    path_timer = 0.65
    path_points.clear()
    path_index = 0
    if navigation_grid == null:
        return
    var start := _nearest_walkable(Vector2i(roundi(global_position.x), roundi(global_position.z)))
    var finish := _nearest_walkable(Vector2i(roundi(target.global_position.x), roundi(target.global_position.z)))
    if start == finish:
        return
    path_points = navigation_grid.get_id_path(start, finish)
    if path_points.size() > 1:
        path_index = 1

func _nearest_walkable(point: Vector2i) -> Vector2i:
    var region := navigation_grid.region
    var min_cell := region.position
    var max_cell := region.position + region.size - Vector2i.ONE
    var clamped := Vector2i(clampi(point.x, min_cell.x, max_cell.x), clampi(point.y, min_cell.y, max_cell.y))
    if navigation_grid.is_in_boundsv(clamped) and not navigation_grid.is_point_solid(clamped):
        return clamped
    for radius in range(1, 8):
        for x in range(-radius, radius + 1):
            for y in range(-radius, radius + 1):
                if abs(x) != radius and abs(y) != radius:
                    continue
                var candidate := clamped + Vector2i(x, y)
                if navigation_grid.is_in_boundsv(candidate) and not navigation_grid.is_point_solid(candidate):
                    return candidate
    return clamped

func _follow_path(delta: float) -> void:
    if path_points.is_empty() or path_index >= path_points.size():
        velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
        _repath()
        return
    var point := path_points[path_index]
    var direction := Vector3(float(point.x), global_position.y, float(point.y)) - global_position
    direction.y = 0
    if direction.length() < 0.72:
        path_index += 1
        return
    direction = direction.normalized()
    _face(direction, delta)
    velocity.x = move_toward(velocity.x, direction.x * move_speed, 15.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * move_speed, 15.0 * delta)

func _combat_move(delta: float, to_target: Vector3, distance: float) -> void:
    var direction := to_target.normalized()
    _face(direction, delta)
    var movement := Vector3.ZERO
    if distance > 8.5:
        movement += direction
    elif distance < 5.0:
        movement -= direction * 0.75
    movement += Vector3(-direction.z, 0, direction.x) * strafe_sign * 0.55
    movement = movement.normalized()
    velocity.x = move_toward(velocity.x, movement.x * move_speed * 0.65, 12.0 * delta)
    velocity.z = move_toward(velocity.z, movement.z * move_speed * 0.65, 12.0 * delta)

func _face(direction: Vector3, delta: float) -> void:
    if direction.length_squared() > 0.001:
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 8.0)

func _attack_target(distance: float) -> void:
    if distance > 31.0 or not is_instance_valid(target):
        return
    var origin := global_position + Vector3.UP * 1.45
    var aim_point := target.global_position + Vector3.UP * 1.45
    if _rng.randf() > accuracy:
        aim_point += Vector3(_rng.randf_range(-1.7,1.7), _rng.randf_range(-0.85,0.85), _rng.randf_range(-1.7,1.7))
    var query := PhysicsRayQueryParameters3D.create(origin, aim_point, 1 | 2)
    query.exclude = [get_rid()]
    query.collide_with_areas = false
    var result := get_world_3d().direct_space_state.intersect_ray(query)
    if not result.is_empty() and result.collider == target:
        if target == player_owner:
            player_owner.take_damage(damage, "HAX ENFORCER")
        elif target.has_method("apply_damage"):
            target.apply_damage(damage,"bot")


func _target_is_dead() -> bool:
    if not is_instance_valid(target):
        return true
    return bool(target.get("is_dead"))

func _choose_battle_target() -> void:
    _target_refresh_timer = _rng.randf_range(1.1,2.1)
    if not is_instance_valid(player_owner) or player_owner.is_dead:
        target = null
        return
    var best: Node3D = player_owner
    var best_distance := global_position.distance_to(player_owner.global_position)
    for other_node in get_tree().get_nodes_in_group("bots"):
        var other := other_node as CombatBot
        if other == null or other == self or other.is_dead:
            continue
        if other.team_id == team_id:
            continue
        var distance := global_position.distance_to(other.global_position)
        if distance < best_distance and distance < 52.0:
            best = other
            best_distance = distance
    target = best

func get_head_position() -> Vector3:
    return global_position + Vector3.UP * 1.72

func apply_damage(amount: float, zone := "body") -> void:
    if is_dead:
        return
    health = maxf(0.0, health - amount)
    if health <= 0.0:
        is_dead = true
        collision_layer = 0
        _head_area.collision_layer = 0
        _body_area.collision_layer = 0
        eliminated.emit(self, zone)
        queue_free()
