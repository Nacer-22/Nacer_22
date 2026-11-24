class_name MapFactory
extends Node3D

var obstacles: Array[Dictionary] = []
var spawn_points: Array[Vector3] = []
var _materials: Dictionary = {}
var map_id := "red_harbor"

func build_map(id: String) -> void:
    map_id = id
    for child in get_children():
        child.queue_free()
    obstacles.clear()
    spawn_points.clear()
    _create_materials()
    _add_box(Vector3(0,-0.65,0),Vector3(120,1.2,120),_materials.floor,false)
    _add_perimeter()
    match map_id:
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
    _add_box(Vector3(0,3,-60),Vector3(120,6,1),_materials.concrete)
    _add_box(Vector3(0,3,60),Vector3(120,6,1),_materials.concrete)
    _add_box(Vector3(-60,3,0),Vector3(1,6,120),_materials.concrete)
    _add_box(Vector3(60,3,0),Vector3(1,6,120),_materials.concrete)
    for x in range(-50,51,20):
        _add_box(Vector3(x,6.15,-59.1),Vector3(2,0.25,0.16),_materials.red,false)

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
    spawn_points = [Vector3(-43,0.1,-43),Vector3(43,0.1,43),Vector3(-43,0.1,43),Vector3(43,0.1,-43),Vector3(0,0.1,-49),Vector3(0,0.1,49),Vector3(-49,0.1,0),Vector3(49,0.1,0),Vector3(-20,0.1,0),Vector3(20,0.1,0),Vector3(0,0.1,-20),Vector3(0,0.1,20)]

func _add_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-32,0)
    sun.light_energy = 0.38 if map_id == "night_city" else 1.1
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 90.0
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
    grid.region = Rect2i(-58,-58,116,116)
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

func _add_box(pos: Vector3,size: Vector3,material: Material,solid := true) -> void:
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
        obstacles.append({"center":pos,"size":size})
    add_child(body)
