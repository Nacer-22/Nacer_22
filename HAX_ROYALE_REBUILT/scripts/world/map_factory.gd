class_name MapFactory
extends Node3D

var obstacles: Array[Dictionary] = []
var spawn_points: Array[Vector3] = []
var _materials: Dictionary = {}
var map_id := "red_harbor"
var map_half_extent := 70

func build_map(id: String) -> void:
    map_id = id
    map_half_extent = 100 if map_id == "island" else 70
    for child in get_children():
        child.queue_free()
    obstacles.clear()
    spawn_points.clear()
    _create_materials()
    _add_box(Vector3(0,-0.65,0),Vector3(map_half_extent*2,1.2,map_half_extent*2),_materials.floor,true,false)
    _add_perimeter()
    match map_id:
        "island": _build_island()
        "dust_front": _build_dust()
        "night_city": _build_city()
        "frostline": _build_frost()
        _: _build_harbor()
    _make_spawns()
    _add_lighting()

func _create_materials() -> void:
    _materials.clear()
    _materials.concrete = _texture_material("concrete",Color("#555a61"),0.9,0.0)
    _materials.metal = _texture_material("armor-metal",Color("#303b47"),0.42,0.68)
    _materials.floor = _texture_material("floor",Color("#353941"),0.92,0.0)
    _materials.fabric = _texture_material("tactical-fabric",Color("#252a35"),0.8,0.0)
    _materials.dark = _mat(Color("#131821"),0.72,0.2)
    _materials.red = _mat(Color("#a60d25"),0.48,0.45)
    _materials.glass = _mat(Color("#315c75"),0.16,0.34)
    _materials.sand = _texture_material("concrete",Color("#9b805b"),0.96,0.0)
    _materials.road = _mat(Color("#252a32"),0.98,0.02)
    _materials.rock = _mat(Color("#555d65"),0.98,0.0)
    _materials.foliage = _mat(Color("#294b36"),0.96,0.0)
    _materials.foliage_dark = _mat(Color("#172d25"),0.98,0.0)
    _materials.water = _mat(Color(0.035,0.18,0.27,0.78),0.18,0.22)
    _materials.water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _texture_material(stem: String, tint: Color, rough: float, metal: float) -> StandardMaterial3D:
    var mat := _mat(tint,rough,metal)
    var base := "res://assets/textures/hires/%s_albedo_2k.jpg" % stem
    if ResourceLoader.exists(base):
        mat.albedo_texture = load(base)
    else:
        var fallback := "res://assets/textures/%s.jpg" % stem
        if ResourceLoader.exists(fallback):
            mat.albedo_texture = load(fallback)
    var normal := "res://assets/textures/hires/%s_normal.png" % stem
    var rough_path := "res://assets/textures/hires/%s_roughness.png" % stem
    var ao := "res://assets/textures/hires/%s_ao.png" % stem
    if ResourceLoader.exists(normal):
        mat.normal_enabled = true
        mat.normal_texture = load(normal)
        mat.normal_scale = 0.45
    if ResourceLoader.exists(rough_path):
        mat.roughness_texture = load(rough_path)
    if ResourceLoader.exists(ao):
        mat.ao_enabled = true
        mat.ao_texture = load(ao)
    return mat

func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    return m

func _add_perimeter() -> void:
    var edge := float(map_half_extent)
    var span := edge * 2.0
    _add_box(Vector3(0,1.8,-edge),Vector3(span,3.6,1.2),_materials.concrete)
    _add_box(Vector3(0,1.8,edge),Vector3(span,3.6,1.2),_materials.concrete)
    _add_box(Vector3(-edge,1.8,0),Vector3(1.2,3.6,span),_materials.concrete)
    _add_box(Vector3(edge,1.8,0),Vector3(1.2,3.6,span),_materials.concrete)
    for x in range(-map_half_extent+10,map_half_extent-10,20):
        _add_box(Vector3(x,3.72,-edge+0.9),Vector3(2,0.18,0.14),_materials.red,false)

func _build_harbor() -> void:
    for z in [-34,-18,18,34]:
        _container(Vector3(-28,2.2,z),Vector3(18,4.4,7),Color("#172b3a"))
        _container(Vector3(28,2.2,z),Vector3(18,4.4,7),Color("#561322"))
    for x in [-12,12]:
        _container(Vector3(x,2.2,-1),Vector3(7,4.4,18),Color("#263340"))
    for p in [Vector3(-40,0,-5),Vector3(40,0,5),Vector3(0,0,-45),Vector3(0,0,45)]:
        _cover(p)
    _add_box(Vector3(0,0.8,0),Vector3(12,1.6,5),_materials.metal)

func _build_dust() -> void:
    _add_box(Vector3(0,2,-30),Vector3(52,4,2.5),_materials.concrete)
    _add_box(Vector3(-26,2,0),Vector3(2.5,4,52),_materials.concrete)
    _add_box(Vector3(26,2,5),Vector3(2.5,4,42),_materials.concrete)
    for x in [-38,-20,0,20,38]:
        for z in [-18,8,34]:
            _cover(Vector3(x,0,z),_materials.concrete)
    _building(Vector3(0,0,28),Vector3(22,6,18),_materials.sand)

func _build_city() -> void:
    for x in [-38,-12,14,40]:
        _building(Vector3(x,0,-34),Vector3(14,16,14),_materials.concrete)
        _building(Vector3(x,0,34),Vector3(14,12,14),_materials.concrete)
    for x in [-28,0,28]:
        _cover(Vector3(x,0,-4))
        _cover(Vector3(x,0,12))

func _build_frost() -> void:
    for x in [-34,0,34]:
        _building(Vector3(x,0,-28),Vector3(18,10,12),_materials.glass)
        _building(Vector3(x,0,28),Vector3(18,10,12),_materials.glass)
    for x in [-24,-8,8,24]:
        _cover(Vector3(x,0,0),_materials.glass)


func _build_island() -> void:
    # Open coastal BR island: waterways, a bridge, a village, a military base, and several POIs.
    _add_box(Vector3(8,0.02,-4),Vector3(16,0.05,184),_materials.water,false)
    _add_box(Vector3(8,0.03,-4),Vector3(18,0.06,184),_materials.water,false)
    _add_box(Vector3(8,0.48,-5),Vector3(24,0.85,15),_materials.road)
    for z in [-78,-42,0,42,78]:
        _add_box(Vector3(8,1.3,z),Vector3(1.0,2.6,1.0),_materials.metal)
    _add_box(Vector3(-30,0.01,0),Vector3(7,0.04,188),_materials.road,false)
    _add_box(Vector3(45,0.01,0),Vector3(7,0.04,188),_materials.road,false)
    _add_box(Vector3(-30,0.04,0),Vector3(0.16,0.03,182),_materials.red,false)
    _add_box(Vector3(45,0.04,0),Vector3(0.16,0.03,182),_materials.red,false)

    # Village blocks.
    for p in [Vector3(-75,0,-66),Vector3(-53,0,-66),Vector3(-75,0,-44),Vector3(-53,0,-44)]:
        _building(p,Vector3(12,7,10),_materials.sand)
    for p in [Vector3(60,0,-66),Vector3(82,0,-66),Vector3(60,0,-44),Vector3(82,0,-44)]:
        _building(p,Vector3(11,9,10),_materials.concrete)
    # Military compound and landing strip.
    for p in [Vector3(-78,0,34),Vector3(-54,0,34),Vector3(-78,0,58)]:
        _building(p,Vector3(16,8,13),_materials.metal)
    _add_box(Vector3(-65,0.03,53),Vector3(3,0.06,40),_materials.road,false)
    _add_box(Vector3(-65,0.04,34),Vector3(2.0,0.06,0.2),_materials.red,false)
    _add_box(Vector3(-65,0.04,72),Vector3(2.0,0.06,0.2),_materials.red,false)
    # Coastal cliffs, towers, vehicles and cover.
    for p in [Vector3(-86,0,-14),Vector3(86,0,18),Vector3(8,0,78)]:
        _add_watch_tower(p)
    _add_vehicle(Vector3(-18,0,24),0.45)
    _add_vehicle(Vector3(76,0,4),-1.2)
    _add_vehicle(Vector3(-62,0,-74),0.1)
    for p in [
        Vector3(-82,0,-28),Vector3(-72,0,-8),Vector3(-53,0,-18),Vector3(-38,0,-52),
        Vector3(-12,0,-76),Vector3(12,0,-62),Vector3(75,0,-20),Vector3(82,0,38),
        Vector3(67,0,62),Vector3(45,0,72),Vector3(14,0,42),Vector3(-15,0,62),
        Vector3(-40,0,75),Vector3(-86,0,70),Vector3(4,0,-24),Vector3(18,0,15)
    ]:
        _cover(p)
    # Natural cover perimeter and wooded ridges.
    for p in [
        Vector3(-92,0,-20),Vector3(-88,0,36),Vector3(-58,0,-28),Vector3(-42,0,8),
        Vector3(-18,0,-88),Vector3(8,0,-88),Vector3(28,0,-74),Vector3(60,0,-20),
        Vector3(86,0,2),Vector3(82,0,44),Vector3(58,0,80),Vector3(26,0,64),
        Vector3(-8,0,82),Vector3(-36,0,70),Vector3(-88,0,86),Vector3(-94,0,58),
        Vector3(-92,0,-54),Vector3(93,0,-54),Vector3(94,0,-88)
    ]:
        _add_tree(p,0.88 + float(abs(roundi(p.x + p.z))) * 0.002)
    for p in [
        Vector3(-88,0,-86),Vector3(-75,0,-80),Vector3(-90,0,-50),Vector3(-86,0,8),
        Vector3(-80,0,88),Vector3(-55,0,86),Vector3(-25,0,86),Vector3(5,0,88),
        Vector3(30,0,88),Vector3(60,0,86),Vector3(88,0,80),Vector3(91,0,48),
        Vector3(90,0,-8),Vector3(89,0,-80),Vector3(58,0,-88),Vector3(20,0,-88)
    ]:
        _add_rock(p,0.75 + float(abs(roundi(p.x * 0.5 + p.z))) * 0.004)
    _add_banner(Vector3(0,0,-92),Vector3(15,8,0.5))
    _add_box(Vector3(0,0.35,-12),Vector3(18,0.7,3),_materials.metal)
    _add_box(Vector3(0,0.35,16),Vector3(18,0.7,3),_materials.metal)

func _add_banner(pos: Vector3, size: Vector3) -> void:
    var pole_height := maxf(3.0,size.y)
    _add_box(pos + Vector3(-size.x*0.5,pole_height*0.5,0),Vector3(0.22,pole_height,0.22),_materials.metal)
    _add_box(pos + Vector3(size.x*0.5,pole_height*0.5,0),Vector3(0.22,pole_height,0.22),_materials.metal)
    _add_box(pos + Vector3(0,pole_height*0.34,0),Vector3(size.x,0.16,0.18),_materials.metal)
    var banner_material := _mat(Color("#a70f2d"),0.72,0.18)
    _add_box(pos + Vector3(0,pole_height*0.66,0.04),Vector3(size.x*0.92,pole_height*0.48,0.10),banner_material,false)
    var trim := _mat(Color("#ee3154"),0.45,0.25)
    trim.emission_enabled = true
    trim.emission = Color("#8e102c")
    trim.emission_energy_multiplier = 1.4
    _add_box(pos + Vector3(0,pole_height*0.42,0.10),Vector3(size.x*0.92,0.12,0.06),trim,false)

func _add_tree(pos: Vector3, scale_value: float) -> void:
    var tree := Node3D.new()
    tree.position = pos
    tree.scale = Vector3.ONE * scale_value
    add_child(tree)
    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.18
    trunk_mesh.bottom_radius = 0.30
    trunk_mesh.height = 3.2
    trunk.mesh = trunk_mesh
    trunk.material_override = _materials.sand
    trunk.position.y = 1.6
    tree.add_child(trunk)
    var trunk_body := StaticBody3D.new()
    var trunk_shape := CollisionShape3D.new()
    var trunk_collision := CylinderShape3D.new()
    trunk_collision.radius = 0.28
    trunk_collision.height = 3.2
    trunk_shape.shape = trunk_collision
    trunk_shape.position.y = 1.6
    trunk_body.add_child(trunk_shape)
    tree.add_child(trunk_body)
    obstacles.append({"center":pos+Vector3(0,1.6,0),"size":Vector3(0.65,3.2,0.65)})
    for i in range(3):
        var leaves := MeshInstance3D.new()
        var cone := CylinderMesh.new()
        cone.top_radius = 0.0
        cone.bottom_radius = 1.55 - float(i) * 0.24
        cone.height = 3.3 - float(i) * 0.2
        leaves.mesh = cone
        leaves.material_override = _materials.foliage if i % 2 == 0 else _materials.foliage_dark
        leaves.position.y = 3.1 + float(i) * 0.9
        tree.add_child(leaves)

func _add_rock(pos: Vector3, size: float) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    body.collision_layer = 1
    body.collision_mask = 0
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = size * 1.45
    sphere.height = size * 1.8
    mesh.mesh = sphere
    mesh.material_override = _materials.rock
    mesh.scale = Vector3(1.25,0.76,0.94)
    mesh.position.y = size * 0.55
    body.add_child(mesh)
    var shape := CollisionShape3D.new()
    var collider := SphereShape3D.new()
    collider.radius = size
    shape.shape = collider
    shape.position.y = size * 0.55
    body.add_child(shape)
    obstacles.append({"center":pos + Vector3(0,size*0.55,0),"size":Vector3(size*2.0,size*1.1,size*2.0)})
    add_child(body)

func _add_watch_tower(pos: Vector3) -> void:
    _add_box(pos+Vector3(0,4,0),Vector3(0.55,8,0.55),_materials.metal)
    _add_box(pos+Vector3(0,7.6,0),Vector3(5.4,0.35,5.4),_materials.red,false)
    _add_box(pos+Vector3(0,9.0,0),Vector3(4.1,2.4,4.1),_materials.dark)
    _add_box(pos+Vector3(0,10.4,0),Vector3(5.8,0.22,5.8),_materials.metal,false)
    var beacon := OmniLight3D.new()
    beacon.position = pos + Vector3(0,11.0,0)
    beacon.light_color = Color("#ff304d")
    beacon.light_energy = 1.4
    beacon.omni_range = 16.0
    add_child(beacon)

func _add_vehicle(pos: Vector3, yaw: float) -> void:
    var vehicle := Node3D.new()
    vehicle.position = pos
    vehicle.rotation.y = yaw
    add_child(vehicle)
    var hull := MeshInstance3D.new()
    var hull_mesh := BoxMesh.new()
    hull_mesh.size = Vector3(2.1,0.85,4.2)
    hull.mesh = hull_mesh
    hull.material_override = _materials.dark
    hull.position.y = 0.92
    vehicle.add_child(hull)
    var cabin := MeshInstance3D.new()
    var cabin_mesh := BoxMesh.new()
    cabin_mesh.size = Vector3(1.85,0.9,2.0)
    cabin.mesh = cabin_mesh
    cabin.material_override = _materials.metal
    cabin.position = Vector3(0,1.72,-0.25)
    vehicle.add_child(cabin)
    for x in [-1.0,1.0]:
        for z in [-1.35,1.35]:
            var wheel := MeshInstance3D.new()
            var tire := CylinderMesh.new()
            tire.top_radius = 0.48
            tire.bottom_radius = 0.48
            tire.height = 0.22
            wheel.mesh = tire
            wheel.material_override = _materials.dark
            wheel.rotation.z = PI * 0.5
            wheel.position = Vector3(x,0.48,z)
            vehicle.add_child(wheel)
    _add_box(pos+Vector3(0,0.9,0),Vector3(2.2,1.0,4.4),_materials.dark)

func _container(pos: Vector3, size: Vector3, color: Color) -> void:
    _add_box(pos,size,_mat(color,0.48,0.6))
    for z_offset in range(-int(size.x/2)+2,int(size.x/2),3):
        _add_box(pos+Vector3(z_offset,0,size.z/2+0.04),Vector3(0.1,size.y*0.92,0.07),_materials.dark,false)
    _add_box(pos+Vector3(0,size.y/2+0.08,0),Vector3(size.x*0.9,0.12,size.z*0.9),_materials.red,false)

func _building(pos: Vector3,size: Vector3,material: Material) -> void:
    _add_box(pos+Vector3(0,size.y/2,0),size,material)
    for floor_y in range(2,int(size.y),3):
        _add_box(pos+Vector3(0,float(floor_y),size.z/2+0.06),Vector3(size.x*0.84,0.12,0.1),_materials.red,false)

func _cover(pos: Vector3,material: Material = null) -> void:
    var use_mat: Material = material if material != null else _materials.metal
    _add_box(pos+Vector3(0,0.9,0),Vector3(5.5,1.8,2.2),use_mat)
    _add_box(pos+Vector3(0,1.88,0),Vector3(5.8,0.14,2.45),_materials.dark,false)

func _make_spawns() -> void:
    if map_id == "island":
        spawn_points = [
            Vector3(-78,0.1,-74),Vector3(78,0.1,74),Vector3(-78,0.1,74),Vector3(78,0.1,-74),
            Vector3(0,0.1,-82),Vector3(0,0.1,82),Vector3(-84,0.1,0),Vector3(84,0.1,0),
            Vector3(-48,0.1,-32),Vector3(48,0.1,32),Vector3(-32,0.1,48),Vector3(32,0.1,-48),
            Vector3(-62,0.1,24),Vector3(62,0.1,-24),Vector3(-18,0.1,-72),Vector3(18,0.1,72)
        ]
    else:
        spawn_points = [
            Vector3(-48,0.1,-45),Vector3(48,0.1,45),Vector3(-48,0.1,45),Vector3(48,0.1,-45),
            Vector3(0,0.1,-52),Vector3(0,0.1,52),Vector3(-54,0.1,0),Vector3(54,0.1,0),
            Vector3(-28,0.1,-12),Vector3(28,0.1,12),Vector3(-12,0.1,28),Vector3(12,0.1,-28),
            Vector3(-38,0.1,18),Vector3(38,0.1,-18),Vector3(-18,0.1,-45),Vector3(18,0.1,45)
        ]

func _add_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-32,0)
    sun.light_energy = 0.38 if map_id == "night_city" else 1.1
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 170.0
    add_child(sun)
    for point in [Vector3(-28,10,-28),Vector3(28,10,28),Vector3(0,11,0)]:
        var light := OmniLight3D.new()
        light.position = point
        light.light_color = Color("#ff2744") if map_id == "night_city" else Color("#ffd7ae")
        light.light_energy = 1.4
        light.omni_range = 18.0
        add_child(light)

func make_navigation_grid() -> AStarGrid2D:
    var grid := AStarGrid2D.new()
    grid.region = Rect2i(-map_half_extent+2,-map_half_extent+2,map_half_extent*2-4,map_half_extent*2-4)
    grid.cell_size = Vector2.ONE
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
    grid.update()
    for obstacle in obstacles:
        var center: Vector3 = obstacle.center
        var half: Vector3 = obstacle.size * 0.5
        for x in range(floori(center.x-half.x-0.45),ceili(center.x+half.x+0.45)+1):
            for z in range(floori(center.z-half.z-0.45),ceili(center.z+half.z+0.45)+1):
                var cell := Vector2i(x,z)
                if grid.is_in_boundsv(cell):
                    grid.set_point_solid(cell,true)
    return grid

func _add_box(pos: Vector3,size: Vector3,material: Material,solid := true,nav_block := true) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    body.collision_layer = 1
    body.collision_mask = 0
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.material_override = material
    body.add_child(mesh)
    if solid:
        var collision := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        collision.shape = box
        body.add_child(collision)
        if nav_block:
            obstacles.append({"center":pos,"size":size})
    add_child(body)
