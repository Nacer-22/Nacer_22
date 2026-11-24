#!/usr/bin/env python3
"""Build-time remaster patcher for HAX SHOOTING."""
from __future__ import annotations
import argparse, pathlib, textwrap

def write(path: pathlib.Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content).lstrip(), encoding="utf-8")

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Expected source fragment not found: {label}")
    return text.replace(old, new, 1)

def patch_project(root: pathlib.Path) -> None:
    p = root / "project.godot"
    text = p.read_text(encoding="utf-8")
    text = replace_once(text, 'config/name="fps-demo"', 'config/name="HAX SHOOTING"', "project name")
    text = text.replace('run/main_scene="uid://4wonuqyiwe3i"', 'run/main_scene="res://main.tscn"')
    text = text.replace('config/features=PackedStringArray("4.6", "Forward Plus")',
                        'config/features=PackedStringArray("4.7", "Mobile")')
    text = replace_once(text, 'config/icon="res://icon.svg"',
        'config/icon="res://hax/icon.svg"\nconfig/description="HAX SHOOTING — Tactical FPS by NACAR_22"\nboot_splash/image="res://hax/boot_splash.svg"\nboot_splash/bg_color=Color(0.012, 0.014, 0.02, 1)\nboot_splash/fullsize=false\nboot_splash/use_filter=true',
        "application icon and boot splash")
    text = text.replace('window/size/viewport_height=1080', 'window/size/viewport_height=1080\\nwindow/handheld/orientation=0')
    text += """

[rendering]
renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
textures/vram_compression/import_etc2_astc=true
textures/default_filters/use_nearest_mipmap_filter=true
environment/defaults/default_clear_color=Color(0.012, 0.014, 0.02, 1)
"""
    write(p, text)

def patch_player(root: pathlib.Path) -> None:
    p = root / "player/player.gd"
    text = p.read_text(encoding="utf-8")
    text = replace_once(text,
        'var sprint_anim:float = 0.0',
        'var sprint_anim:float = 0.0\nvar mobile_move_vector: Vector2 = Vector2.ZERO',
        "mobile move input")
    text = text.replace(
        'var input_dir := Input.get_vector("left", "right", "forward", "backward")',
        'var input_dir := Input.get_vector("left", "right", "forward", "backward")\n\tif mobile_move_vector.length() > 0.04:\n\t\tinput_dir = mobile_move_vector.limit_length(1.0)'
    )
    text = text.replace(
        'velocity.z = lerp(velocity.z, direction.x * speed, delta * inertia_ground)',
        'velocity.z = lerp(velocity.z, direction.z * speed, delta * inertia_ground)'
    )
    text = text.replace(
        'velocity.z = lerp(velocity.z, direction.x * speed, delta * inertia_air)',
        'velocity.z = lerp(velocity.z, direction.z * speed, delta * inertia_air)'
    )
    text += """

func apply_touch_look(relative: Vector2) -> void:
\tif not is_alive:
\t\treturn
\tcamera_pivot.rotate_y(-relative.x * sensitivity * 0.72)
\tcamera_holder.rotate_x(-relative.y * sensitivity * 0.72)
\tcamera_holder.rotation.x = clamp(camera_holder.rotation.x, deg_to_rad(-60), deg_to_rad(60))
"""
    write(p, text)

def patch_weapons(root: pathlib.Path) -> None:
    p = root / "common/managers/weapons_manager.gd"
    text = p.read_text(encoding="utf-8")
    text = replace_once(text, "current_weapon_index = 0", "current_weapon_index = 2", "start with assault rifle")
    text = text.replace("# Start with pistol (index 0)", "# HAX SHOOTING starts with the assault rifle (index 2).")
    p.write_text(text, encoding="utf-8")

    p = root / "common/managers/input_manager.gd"
    text = p.read_text(encoding="utf-8")
    text = replace_once(text, 'Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)',
                        'Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)', "show cursor at startup")
    text = text.replace(
        'if Input.is_action_just_pressed("exit"):\n\t\tmouse_mode_captured = !mouse_mode_captured',
        'if Input.is_action_just_pressed("exit") and not OS.has_feature("mobile") and not get_tree().paused:\n\t\tmouse_mode_captured = !mouse_mode_captured'
    )
    p.write_text(text, encoding="utf-8")

def patch_hud(root: pathlib.Path) -> None:
    p = root / "common/hud/hud.gd"
    text = p.read_text(encoding="utf-8")
    text = text.replace('enemies_label.text = str("ENEMIES KILLED: ", count)',
                        'enemies_label.text = str("ELIMINATIONS  ", count)')
    text = text.replace('bullets_label.text = "AMMO: --/--"', 'bullets_label.text = "AMMO  -- / --"')
    text = text.replace('str("AMMO: ", current_mag, "/∞")', 'str("AMMO  ", current_mag, " / ∞")')
    text = text.replace('bullets_label.text = "AMMO: ∞"', 'bullets_label.text = "AMMO  ∞"')
    text = text.replace('str("AMMO: ", current_mag, "/", current_ammo)', 'str("AMMO  ", current_mag, " / ", current_ammo)')
    text = text.replace('str("AMMO: ", current_ammo)', 'str("AMMO  ", current_ammo)')
    text = text.replace(
        'Global.enemy_count_changed.connect(_on_enemy_count_changed)',
        'Global.enemy_count_changed.connect(_on_enemy_count_changed)\n\tif enemies_label:\n\t\tenemies_label.add_theme_color_override("font_color", Color("#ff536b"))\n\tif bullets_label:\n\t\tbullets_label.add_theme_color_override("font_color", Color("#f3f4f6"))'
    )
    p.write_text(text, encoding="utf-8")

def patch_world(root: pathlib.Path) -> None:
    p = root / "world/test_level.tscn"
    text = p.read_text(encoding="utf-8")
    decorations = """
    [node name="cargo3" parent="fps_demo_props" instance=ExtResource("2_kfa7i")]
    transform = Transform3D(0.9659258, 0, 0.25881904, 0, 1, 0, -0.25881904, 0, 0.9659258, -24, 0, -40)

    [node name="cargo4" parent="fps_demo_props" instance=ExtResource("2_kfa7i")]
    transform = Transform3D(0.8660254, 0, -0.5, 0, 1, 0, 0.5, 0, 0.8660254, 23, 0, -22)

    [node name="cargo5" parent="fps_demo_props" instance=ExtResource("2_kfa7i")]
    transform = Transform3D(0.9396926, 0, 0.34202015, 0, 1, 0, -0.34202015, 0, 0.9396926, -20, 0, -78)

    [node name="wreck2" parent="fps_demo_props" instance=ExtResource("4_mmx4b")]
    transform = Transform3D(0.8660254, 0, -0.5, 0, 1.1, 0, 0.5, 0, 0.8660254, 8, 0, -19)

    [node name="wreck3" parent="fps_demo_props" instance=ExtResource("4_mmx4b")]
    transform = Transform3D(0.76604444, 0, 0.64278764, 0, 1, 0, -0.64278764, 0, 0.76604444, -23, 0, -62)

    [node name="block2" parent="fps_demo_props" instance=ExtResource("3_x27he")]
    transform = Transform3D(0.9659258, 0, 0.25881904, 0, 1, 0, -0.25881904, 0, 0.9659258, 13, 0, -11)

    [node name="block3" parent="fps_demo_props" instance=ExtResource("3_x27he")]
    transform = Transform3D(0.9659258, 0, -0.25881904, 0, 1, 0, 0.25881904, 0, 0.9659258, -8, 0, -52)
    """
    if '[node name="cargo3"' not in text:
        text += "\n" + textwrap.dedent(decorations)
    p.write_text(text, encoding="utf-8")

    p = root / "main.tscn"
    text = p.read_text(encoding="utf-8")
    text = text.replace('glow_enabled = true\n', 'glow_enabled = true\nfog_enabled = true\nfog_light_color = Color(0.12, 0.16, 0.22, 1)\nfog_density = 0.0018\n')
    if '[node name="HAXRedBeacon"' not in text:
        text += """

[node name="HAXRedBeacon" type="OmniLight3D" parent="."]
position = Vector3(-20, 7, -43)
light_color = Color(1, 0.08, 0.18, 1)
light_energy = 2.0
omni_range = 20.0

[node name="HAXBlueBeacon" type="OmniLight3D" parent="."]
position = Vector3(22, 8, -64)
light_color = Color(0.12, 0.38, 1, 1)
light_energy = 2.1
omni_range = 22.0

[node name="HAXWarmBeacon" type="OmniLight3D" parent="."]
position = Vector3(0, 7, -18)
light_color = Color(1, 0.45, 0.18, 1)
light_energy = 1.5
omni_range = 18.0
"""
    p.write_text(text, encoding="utf-8")

def create_hax_ui(root: pathlib.Path) -> None:
    hax = root / "hax"
    hax.mkdir(exist_ok=True)
    write(hax / "icon.svg", r'''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
      <defs>
        <linearGradient id="metal" x2="0" y2="1"><stop stop-color="#f5f7fa"/><stop offset=".48" stop-color="#7e8795"/><stop offset="1" stop-color="#171b25"/></linearGradient>
        <linearGradient id="red" x2="0" y2="1"><stop stop-color="#ff647a"/><stop offset="1" stop-color="#810b27"/></linearGradient>
        <filter id="glow"><feGaussianBlur stdDeviation="8" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
      </defs>
      <rect width="512" height="512" rx="92" fill="#070a11"/>
      <rect x="12" y="12" width="488" height="488" rx="82" fill="none" stroke="#d51a3e" stroke-width="12"/>
      <path d="M86 175 115 70 170 111 211 24 256 93 301 24 342 111 397 70 426 175 369 154 344 208 168 208 143 154Z" fill="url(#metal)" stroke="#bc1636" stroke-width="8"/>
      <path d="M122 150 153 95 182 139 212 60 256 125 300 60 330 139 359 95 390 150 341 138 321 183 191 183 171 138Z" fill="url(#red)"/>
      <path d="M114 250Q120 158 205 143Q256 126 307 143Q392 158 398 250L371 347 326 401 256 433 186 401 141 347Z" fill="url(#metal)" stroke="#b70f32" stroke-width="9"/>
      <path d="m153 244 50-28 48 32-31 42-58-8zm206 0-50-28-48 32 31 42 58-8z" fill="#090c13" stroke="#b8193b" stroke-width="7"/>
      <path d="m172 250 34-10 18 14-40 12zm168 0-34-10-18 14 40 12z" fill="#ff1f48" filter="url(#glow)"/>
      <path d="m256 263-30 50 30 28 30-28z" fill="#0b0e16" stroke="#b9193c" stroke-width="6"/>
      <path d="m178 327 32 22 20-17 26 24 26-24 20 17 32-22-12 43-34 14-32 6-32-6-34-14z" fill="#11151f" stroke="#e4e8ed" stroke-width="5"/>
      <path d="M68 432h376l-28 55H96z" fill="#080b12" stroke="#c61639" stroke-width="7"/>
      <text x="256" y="470" text-anchor="middle" font-family="Arial" font-size="38" font-weight="900" fill="#f9f2f4">HAX SHOOTING</text>
    </svg>
    ''')
    write(hax / "boot_splash.svg", r'''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 720">
      <defs><linearGradient id="bg" x2="0" y2="1"><stop stop-color="#141f33"/><stop offset="1" stop-color="#070a11"/></linearGradient><linearGradient id="red" x2="1"><stop stop-color="#7b0b25"/><stop offset="1" stop-color="#ff4664"/></linearGradient></defs>
      <rect width="1280" height="720" fill="url(#bg)"/>
      <path d="M0 565 130 480 240 540 380 430 490 530 650 415 790 510 930 410 1060 510 1170 430 1280 485V720H0Z" fill="#090e18"/>
      <path d="M0 615H1280" stroke="#dc1f45" stroke-width="6" opacity=".8"/>
      <g transform="translate(460 170)">
        <path d="M40 80 65 8 108 42 142 0 180 50 220 0 254 42 297 8 322 80 275 70 260 112 102 112 86 70Z" fill="url(#red)" stroke="#f0e9eb" stroke-width="5"/>
        <path d="M73 148Q76 80 181 72Q284 80 289 148L263 259 181 300 99 259Z" fill="#b3bac4" stroke="#e9edf0" stroke-width="6"/>
        <path d="M110 150 151 127 180 153 150 185 113 177Zm142 0-41-23-29 26 30 32 37-8Z" fill="#090c13"/>
        <path d="M123 152 153 144 169 154 145 163Zm116 0-30-8-16 10 24 9Z" fill="#ff294f"/>
        <path d="M181 181 160 216 181 234 202 216Z" fill="#111621"/>
      </g>
      <text x="640" y="570" text-anchor="middle" fill="#fff" font-family="Arial" font-size="64" font-weight="900" letter-spacing="5">HAX SHOOTING</text>
      <text x="640" y="622" text-anchor="middle" fill="#ff526e" font-family="Arial" font-size="24" font-weight="700" letter-spacing="7">BY: NACAR_22</text>
    </svg>
    ''')
    write(hax / "menu_art.svg", r'''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080">
      <defs>
        <linearGradient id="sky" x2="0" y2="1"><stop stop-color="#080d18"/><stop offset=".55" stop-color="#1c2637"/><stop offset="1" stop-color="#4a1728"/></linearGradient>
        <linearGradient id="wet" x2="0" y2="1"><stop stop-color="#1c2736"/><stop offset="1" stop-color="#070b12"/></linearGradient>
        <radialGradient id="flare"><stop stop-color="#ff334e" stop-opacity=".85"/><stop offset="1" stop-color="#ff334e" stop-opacity="0"/></radialGradient>
      </defs>
      <rect width="1920" height="1080" fill="url(#sky)"/>
      <circle cx="1480" cy="285" r="320" fill="url(#flare)"/>
      <g fill="#0b111d" stroke="#303c4c" stroke-width="10">
        <path d="M60 330h210v490H60zm240 190h180v300H300zm980-220h240v520h-240zm265 70h300v450h-300z"/>
        <path d="M490 540h260v280H490zm760-150h90v430h-90z"/>
      </g>
      <g stroke="#e52249" stroke-width="9" opacity=".85"><path d="M80 420h170M320 600h145M1320 470h145M1580 550h255"/></g>
      <g stroke="#64778e" stroke-width="10" fill="none"><path d="M260 330V100h120v230M960 500V100h55v400M1130 500V160h42v340"/><path d="M220 100h210M900 160h280"/></g>
      <path d="M0 780h1920v300H0Z" fill="url(#wet)"/>
      <g stroke="#ff2b51" stroke-width="7" opacity=".7"><path d="M0 860h1920M0 930h1920"/></g>
      <g fill="#0a101a" stroke="#778495" stroke-width="12">
        <path d="M1360 365q75-110 190-62l85 95-15 310-100 95-145-58-88-150z"/>
        <path d="M1408 330q92-78 172-8l28 110-220 0z"/>
        <path d="M1390 520q150-65 235 12l68 170-105 120-230-80-62-105z"/>
        <path d="M1400 780 1330 1040h110l110-240zm190 0 85 260h110l-105-280z"/>
      </g>
      <path d="M1410 386h190l-14 45h-178z" fill="#e72146"/>
      <path d="M1405 432h210" stroke="#141b28" stroke-width="24"/>
      <path d="M1330 562 1705 780" stroke="#323c4b" stroke-width="58" stroke-linecap="round"/>
      <path d="M1320 542 1730 785" stroke="#778391" stroke-width="16"/>
      <g stroke="#f02b4d" stroke-width="9" fill="none"><path d="M1380 570 1460 630M1470 630 1540 690M1560 680 1630 730"/></g>
      <g fill="#ff3557"><circle cx="1540" cy="212" r="14"/><circle cx="1810" cy="230" r="11"/><circle cx="1130" cy="280" r="8"/></g>
    </svg>
    ''')
    write(hax / "hax_mobile_controls.gd", r'''
    extends Control

    signal pause_requested
    var player: Node3D
    var stick_id := -1
    var look_id := -1
    var action_touches: Dictionary = {}
    var stick_center := Vector2.ZERO
    var stick_value := Vector2.ZERO
    var _size := Vector2.ZERO
    const STICK_RADIUS := 78.0
    const BUTTONS := {
      "fire": Vector2(0.905, 0.805),
      "aim_mode": Vector2(0.785, 0.835),
      "reload": Vector2(0.895, 0.59),
      "jump": Vector2(0.745, 0.61),
      "sprint": Vector2(0.12, 0.72),
      "weapon_change_next": Vector2(0.91, 0.43)
    }
    const LABELS := {"fire":"FIRE","aim_mode":"AIM","reload":"RELOAD","jump":"JUMP","sprint":"RUN","weapon_change_next":"SWAP"}

    func _ready() -> void:
      set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      mouse_filter = Control.MOUSE_FILTER_IGNORE
      process_mode = Node.PROCESS_MODE_ALWAYS
      _size = get_viewport_rect().size
      stick_center = Vector2(155, _size.y - 160)
      queue_redraw()

    func set_player(value: Node3D) -> void:
      player = value
      _size = get_viewport_rect().size
      stick_center = Vector2(155, _size.y - 160)
      queue_redraw()

    func _process(_delta: float) -> void:
      var current_size := get_viewport_rect().size
      if current_size != _size:
        _size = current_size
        stick_center = Vector2(155, _size.y - 160)
      queue_redraw()

    func _input(event: InputEvent) -> void:
      if player == null:
        return
      if event is InputEventScreenTouch:
        if event.pressed:
          _touch_down(event.index, event.position)
        else:
          _touch_up(event.index)
      elif event is InputEventScreenDrag:
        if event.index == stick_id:
          var delta: Vector2 = event.position - stick_center
          stick_value = (delta / STICK_RADIUS).limit_length(1.0)
          player.mobile_move_vector = stick_value
          queue_redraw()
        elif event.index == look_id:
          player.apply_touch_look(event.relative)

    func _touch_down(index: int, pos: Vector2) -> void:
      if pos.x < _size.x * 0.36 and pos.y > _size.y * 0.48 and stick_id == -1:
        stick_id = index
        var delta := (pos - stick_center) / STICK_RADIUS
        stick_value = delta.limit_length(1.0)
        player.mobile_move_vector = stick_value
        queue_redraw()
        return
      if _inside(pos, Vector2(_size.x - 78, 72), 48):
        pause_requested.emit()
        return
      for action in BUTTONS:
        var center: Vector2 = _size * BUTTONS[action]
        var radius := 56.0 if action == "fire" else 40.0
        if _inside(pos, center, radius):
          action_touches[index] = action
          Input.action_press(action)
          return
      if pos.x > _size.x * 0.39 and look_id == -1:
        look_id = index

    func _touch_up(index: int) -> void:
      if index == stick_id:
        stick_id = -1
        stick_value = Vector2.ZERO
        if player:
          player.mobile_move_vector = Vector2.ZERO
      if index == look_id:
        look_id = -1
      if action_touches.has(index):
        Input.action_release(str(action_touches[index]))
        action_touches.erase(index)
      queue_redraw()

    func _inside(point: Vector2, center: Vector2, radius: float) -> bool:
      return point.distance_to(center) <= radius

    func _draw() -> void:
      if _size == Vector2.ZERO:
        return
      draw_circle(Vector2(_size.x - 78,72),48,Color(0.04,0.06,0.1,0.56))
      draw_arc(Vector2(_size.x - 78,72),48,0,TAU,48,Color("#e5284a"),3.0,true)
      _draw_text(Vector2(_size.x - 78,80),"Ⅱ",26,Color.WHITE)
      draw_circle(stick_center,STICK_RADIUS,Color(0.05,0.07,0.1,0.28))
      draw_arc(stick_center,STICK_RADIUS,0,TAU,64,Color(0.86,0.9,0.96,0.55),3.0,true)
      draw_circle(stick_center + stick_value * 38.0,34,Color(0.78,0.82,0.88,0.46))
      draw_arc(stick_center + stick_value * 38.0,34,0,TAU,40,Color("#f23a58"),2.0,true)
      for action in BUTTONS:
        var center: Vector2 = _size * BUTTONS[action]
        var radius := 56.0 if action == "fire" else 40.0
        var fill := Color(0.45,0.05,0.12,0.55) if action == "fire" else Color(0.04,0.06,0.1,0.5)
        draw_circle(center,radius,fill)
        draw_arc(center,radius,0,TAU,48,Color("#ed3655") if action == "fire" else Color(0.86,0.9,0.96,0.65),3.0,true)
        _draw_text(center + Vector2(0,6),LABELS[action],14,Color.WHITE)

    func _draw_text(center: Vector2, value: String, font_size: int, color: Color) -> void:
      var font := ThemeDB.fallback_font
      var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
      draw_string(font,center + Vector2(-width/2,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
    ''')
    write(hax / "credits.md", """
    Game branding and integration: NACAR_22.

    This Android build is based on the MIT-licensed GodotFPS-Template by bukkbeek.
    The upstream repository credits its 3D assets and FPS arms animations to bukkbeek,
    VFX to EffectBlocks, SFX to Pixabay, and undead animations to Mesh2Motion.
    The upstream README prohibits reselling its included assets as standalone assets.
    Original upstream LICENSE and README are retained. Do not redistribute assets as
    an asset pack. Source: https://github.com/bukkbeek/GodotFPS-Template
    """)

def patch_project_main(root: pathlib.Path) -> None:
    write(root / "common/main.gd", r'''
    extends Node3D

    var player: CharacterBody3D
    var menu_layer: CanvasLayer
    var mobile_layer: CanvasLayer
    var hud_layer: CanvasLayer
    var menu_root: Control
    var pause_open := false
    var kill_count := 0
    var status_label: Label
    var settings_sensitivity := 0.01

    func _ready() -> void:
      process_mode = Node.PROCESS_MODE_ALWAYS
      await get_tree().process_frame
      player = Global.player
      if player == null:
        var candidates := get_tree().get_nodes_in_group("player")
        if not candidates.is_empty():
          player = candidates[0]
      Global.enemy_killed.connect(_on_enemy_killed)
      Global.player_dead.connect(_on_player_dead)
      Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
      get_tree().paused = true
      _build_main_menu()

    func _input(event: InputEvent) -> void:
      if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        if get_tree().paused:
          if pause_open:
            _resume_game()
        else:
          _open_pause_menu()

    func _build_main_menu() -> void:
      _remove_menu()
      menu_layer = CanvasLayer.new()
      menu_layer.layer = 80
      menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
      add_child(menu_layer)
      menu_root = Control.new()
      menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      menu_layer.add_child(menu_root)
      var art := TextureRect.new()
      art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      art.texture = load("res://hax/menu_art.svg")
      art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
      art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
      menu_root.add_child(art)
      var shade := ColorRect.new()
      shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      shade.color = Color(0.015,0.02,0.035,0.45)
      shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
      menu_root.add_child(shade)
      var brand := VBoxContainer.new()
      brand.position = Vector2(62,68)
      brand.custom_minimum_size = Vector2(620,140)
      menu_root.add_child(brand)
      var title := Label.new()
      title.text = "HAX SHOOTING"
      title.add_theme_font_size_override("font_size",56)
      title.add_theme_color_override("font_color",Color.WHITE)
      brand.add_child(title)
      var tagline := Label.new()
      tagline.text = "TACTICAL FPS  /  OPERATION RED HARBOR"
      tagline.add_theme_font_size_override("font_size",21)
      tagline.add_theme_color_override("font_color",Color("#ff5a73"))
      brand.add_child(tagline)
      var by := Label.new()
      by.text = "BY: NACAR_22     •     SEASON 01"
      by.add_theme_font_size_override("font_size",17)
      by.add_theme_color_override("font_color",Color("#d4d9e2"))
      brand.add_child(by)
      var panel := PanelContainer.new()
      panel.position = Vector2(64,300)
      panel.custom_minimum_size = Vector2(420,520)
      panel.add_theme_stylebox_override("panel",_panel_style())
      menu_root.add_child(panel)
      var stack := VBoxContainer.new()
      stack.add_theme_constant_override("separation",14)
      panel.add_child(stack)
      var note := Label.new()
      note.text = "DEPLOYMENT CONTROL"
      note.add_theme_font_size_override("font_size",20)
      note.add_theme_color_override("font_color",Color("#ff6077"))
      stack.add_child(note)
      _add_menu_button(stack,"▶   DEPLOY TO RED HARBOR",_start_survival,true)
      _add_menu_button(stack,"◎   FIRING RANGE",_start_training,false)
      _add_menu_button(stack,"▣   WEAPON LOADOUT",_show_loadout,false)
      _add_menu_button(stack,"⚙   SETTINGS",_show_settings,false)
      var footer := Label.new()
      footer.text = "WASD / TOUCH MOVE     •     ADS     •     RELOAD"
      footer.add_theme_font_size_override("font_size",14)
      footer.add_theme_color_override("font_color",Color("#aab3c2"))
      stack.add_child(footer)
      var build := Label.new()
      build.text = "HAX DIVISION  //  BUILD 1.0.0"
      build.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
      build.position = Vector2(66,-42)
      build.add_theme_color_override("font_color",Color("#d9dce4"))
      menu_root.add_child(build)

    func _panel_style() -> StyleBoxFlat:
      var style := StyleBoxFlat.new()
      style.bg_color = Color(0.035,0.045,0.065,0.92)
      style.border_color = Color("#d91c3e")
      style.set_border_width_all(2)
      style.set_corner_radius_all(8)
      style.content_margin_left = 22
      style.content_margin_right = 22
      style.content_margin_top = 24
      style.content_margin_bottom = 22
      return style

    func _add_menu_button(parent: VBoxContainer,label_text: String,callback: Callable,primary := false) -> void:
      var button := Button.new()
      button.text = label_text
      button.custom_minimum_size = Vector2(360,64)
      button.alignment = HORIZONTAL_ALIGNMENT_LEFT
      button.focus_mode = Control.FOCUS_NONE
      var normal := StyleBoxFlat.new()
      normal.bg_color = Color("#501326") if primary else Color("#0b1420")
      normal.border_color = Color("#f02d50") if primary else Color("#4d6074")
      normal.set_border_width_all(2 if primary else 1)
      normal.set_corner_radius_all(5)
      normal.content_margin_left = 18
      var hover := normal.duplicate()
      hover.bg_color = Color("#8b1736")
      hover.border_color = Color("#ff8295")
      button.add_theme_stylebox_override("normal",normal)
      button.add_theme_stylebox_override("hover",hover)
      button.add_theme_stylebox_override("pressed",hover)
      button.add_theme_color_override("font_color",Color.WHITE)
      button.add_theme_font_size_override("font_size",19)
      button.pressed.connect(callback)
      parent.add_child(button)

    func _show_loadout() -> void:
      _remove_menu()
      menu_layer = CanvasLayer.new()
      menu_layer.layer = 80
      menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
      add_child(menu_layer)
      var root := Control.new()
      root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      menu_layer.add_child(root)
      var bg := ColorRect.new()
      bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      bg.color = Color("#080d16")
      root.add_child(bg)
      var panel := PanelContainer.new()
      panel.set_anchors_preset(Control.PRESET_CENTER)
      panel.position = Vector2(-260,-250)
      panel.custom_minimum_size = Vector2(520,500)
      panel.add_theme_stylebox_override("panel",_panel_style())
      root.add_child(panel)
      var v := VBoxContainer.new()
      v.add_theme_constant_override("separation",12)
      panel.add_child(v)
      _add_heading(v,"ARMORY / PRIMARY LOADOUT")
      _add_menu_button(v,"ASSAULT RIFLE  •  40 ROUNDS",func(): _equip(2),true)
      _add_menu_button(v,"PISTOL  •  SIDEARM",func(): _equip(1))
      _add_menu_button(v,"BURST RIFLE",func(): _equip(3))
      _add_menu_button(v,"LIGHT MACHINE GUN",func(): _equip(4))
      _add_menu_button(v,"KNIFE",func(): _equip(0))
      _add_menu_button(v,"←   BACK",_build_main_menu)

    func _equip(index: int) -> void:
      if player:
        var manager := player.get_node_or_null("WeaponsManager")
        if manager:
          manager.switch_weapon(index)
      _build_main_menu()

    func _show_settings() -> void:
      _remove_menu()
      menu_layer = CanvasLayer.new()
      menu_layer.layer = 80
      menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
      add_child(menu_layer)
      var root := Control.new()
      root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      menu_layer.add_child(root)
      var bg := ColorRect.new()
      bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      bg.color = Color("#080d16")
      root.add_child(bg)
      var panel := PanelContainer.new()
      panel.set_anchors_preset(Control.PRESET_CENTER)
      panel.position = Vector2(-290,-220)
      panel.custom_minimum_size = Vector2(580,440)
      panel.add_theme_stylebox_override("panel",_panel_style())
      root.add_child(panel)
      var v := VBoxContainer.new()
      v.add_theme_constant_override("separation",16)
      panel.add_child(v)
      _add_heading(v,"COMBAT SETTINGS")
      var sensitivity_label := Label.new()
      sensitivity_label.text = "LOOK SENSITIVITY"
      v.add_child(sensitivity_label)
      var sensitivity := HSlider.new()
      sensitivity.min_value = 0.003
      sensitivity.max_value = 0.03
      sensitivity.step = 0.001
      sensitivity.value = settings_sensitivity
      sensitivity.value_changed.connect(func(value: float):
        settings_sensitivity = value
        if player: player.sensitivity = value
      )
      v.add_child(sensitivity)
      var aim_label := Label.new()
      aim_label.text = "AIM DOWN SIGHTS • RIGHT MOUSE / AIM BUTTON"
      v.add_child(aim_label)
      _add_menu_button(v,"←   BACK",_build_main_menu,true)

    func _add_heading(parent: VBoxContainer,text_value: String) -> void:
      var heading := Label.new()
      heading.text = text_value
      heading.add_theme_font_size_override("font_size",26)
      heading.add_theme_color_override("font_color",Color("#ff536d"))
      parent.add_child(heading)

    func _start_survival() -> void:
      _start_game(false)

    func _start_training() -> void:
      _start_game(true)

    func _start_game(training: bool) -> void:
      _remove_menu()
      get_tree().paused = false
      pause_open = false
      if player:
        player.set_physics_process(true)
        player.set_process_unhandled_input(true)
        player.is_alive = true
        player.current_health = player.MAX_HEALTH
        player.global_position = Vector3(0,0,6)
        player.velocity = Vector3.ZERO
        player.camera_pivot.rotation = Vector3.ZERO
        player.camera_holder.rotation = Vector3.ZERO
        player.sensitivity = settings_sensitivity
        if training:
          _set_training_mode()
      if OS.has_feature("mobile"):
        _create_mobile_controls()
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
      else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
      _create_match_hud()

    func _set_training_mode() -> void:
      var enemies := get_node_or_null("Enemies")
      if enemies:
        for child in enemies.get_children():
          if child.has_method("_on_spawn_timer_timeout"):
            child.set("spawn_time",5.0)
            child.set("max_items",1)

    func _create_mobile_controls() -> void:
      if mobile_layer:
        mobile_layer.queue_free()
      mobile_layer = CanvasLayer.new()
      mobile_layer.layer = 50
      mobile_layer.process_mode = Node.PROCESS_MODE_ALWAYS
      add_child(mobile_layer)
      var controls := Control.new()
      controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      controls.set_script(load("res://hax/hax_mobile_controls.gd"))
      mobile_layer.add_child(controls)
      controls.set_player(player)
      controls.pause_requested.connect(_open_pause_menu)

    func _create_match_hud() -> void:
      if hud_layer:
        hud_layer.queue_free()
      hud_layer = CanvasLayer.new()
      hud_layer.layer = 30
      add_child(hud_layer)
      var label := Label.new()
      label.text = "HAX SHOOTING  /  RED HARBOR OPERATIONS"
      label.position = Vector2(26,18)
      label.add_theme_font_size_override("font_size",18)
      label.add_theme_color_override("font_color",Color("#ff536b"))
      hud_layer.add_child(label)
      status_label = Label.new()
      status_label.text = "ELIMS  0"
      status_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
      status_label.position = Vector2(-220,18)
      status_label.add_theme_font_size_override("font_size",20)
      status_label.add_theme_color_override("font_color",Color.WHITE)
      hud_layer.add_child(status_label)

    func _on_enemy_killed() -> void:
      kill_count += 1
      if is_instance_valid(status_label):
        status_label.text = "ELIMS  %02d" % kill_count

    func _on_player_dead() -> void:
      if player == null:
        return
      player.set_physics_process(false)
      var timer := get_tree().create_timer(2.4)
      await timer.timeout
      if not is_instance_valid(player):
        return
      player.current_health = player.MAX_HEALTH
      player.is_alive = true
      player.global_position = Vector3(0,0,6)
      player.velocity = Vector3.ZERO
      player.camera_pivot.rotation = Vector3.ZERO
      player.camera_holder.rotation = Vector3.ZERO
      player.set_physics_process(true)
      Global.player_health_changed.emit(0.0,player.current_health,player.MAX_HEALTH,false)

    func _open_pause_menu() -> void:
      if get_tree().paused:
        return
      get_tree().paused = true
      pause_open = true
      Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
      _remove_menu()
      menu_layer = CanvasLayer.new()
      menu_layer.layer = 80
      menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
      add_child(menu_layer)
      var root := Control.new()
      root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      menu_layer.add_child(root)
      var shade := ColorRect.new()
      shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
      shade.color = Color(0.01,0.015,0.025,0.76)
      root.add_child(shade)
      var panel := PanelContainer.new()
      panel.set_anchors_preset(Control.PRESET_CENTER)
      panel.position = Vector2(-220,-170)
      panel.custom_minimum_size = Vector2(440,340)
      panel.add_theme_stylebox_override("panel",_panel_style())
      root.add_child(panel)
      var v := VBoxContainer.new()
      v.add_theme_constant_override("separation",14)
      panel.add_child(v)
      _add_heading(v,"MISSION PAUSED")
      _add_menu_button(v,"RESUME MISSION",_resume_game,true)
      _add_menu_button(v,"RETURN TO MAIN MENU",_return_to_menu)
      _add_menu_button(v,"SETTINGS",_show_settings)

    func _resume_game() -> void:
      _remove_menu()
      get_tree().paused = false
      pause_open = false
      if OS.has_feature("mobile"):
        _create_mobile_controls()
      else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

    func _return_to_menu() -> void:
      get_tree().paused = true
      if mobile_layer:
        mobile_layer.queue_free()
        mobile_layer = null
      if hud_layer:
        hud_layer.queue_free()
        hud_layer = null
      _build_main_menu()

    func _remove_menu() -> void:
      if menu_layer:
        menu_layer.queue_free()
      menu_layer = null
    ''')

def patch_export(root: pathlib.Path) -> None:
    write(root / "export_presets.cfg", r'''
    [preset.0]
    name="Android APK"
    platform="Android"
    runnable=true
    dedicated_server=false
    custom_features=""
    export_filter="all_resources"
    include_filter=""
    exclude_filter=""
    export_path="build/HAX_SHOOTING.apk"
    patches=PackedStringArray()
    encryption_include_filters=""
    encryption_exclude_filters=""
    encrypt_pck=false
    encrypt_directory=false

    [preset.0.options]
    custom_template/debug=""
    custom_template/release=""
    gradle_build/use_gradle_build=false
    gradle_build/export_format=0
    package/unique_name="com.nacar.haxshooting"
    package/name="HAX SHOOTING"
    package/signed=false
    version/code=2
    version/name="1.0.0"
    screen/immersive_mode=true
    screen/support_small=true
    screen/support_normal=true
    screen/support_large=true
    screen/support_xlarge=true
    architectures/arm64-v8a=true
    architectures/armeabi-v7a=true
    architectures/x86=false
    architectures/x86_64=false
    permissions/internet=true
    permissions/access_network_state=true
    permissions/access_wifi_state=true
    permissions/change_wifi_multicast_state=true
    ''')
    write(root / "README_HAX.md", """
    # HAX SHOOTING — BY: NACAR_22

    Mobile-focused first-person shooter remaster based on the GodotFPS-Template.
    Includes visible animated FPS arms, 3D weapon scenes, ADS, weapon switching,
    firing, reload animations, muzzle flash, bullet decals, damage feedback,
    health/ammo HUD, navmesh-driven enemy AI, survival spawners, explosive barrels,
    a drivable Jeep, a branded main menu, and touch controls.

    Upstream code is MIT-licensed. See LICENSE and hax/credits.md. The upstream
    README prohibits reselling its included assets as standalone assets; do not
    redistribute them as an asset pack.

    Android requirements: Godot 4.7.2 export templates, OpenJDK 17, Android Platform
    35, Build Tools 35.0.1, NDK 28.1.13356709.

    Desktop: WASD, mouse, left click fire, right click ADS, R reload, wheel switch,
    Shift sprint, Space jump, Escape pause.
    Android: left virtual joystick, right-side swipe to look, FIRE/AIM/RELOAD/JUMP/RUN/
    SWAP buttons, and pause control.

    This is a single-player survival/training alpha. Online multiplayer and Bluetooth
    are not implemented in this remaster.
    """)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    args = parser.parse_args()
    root = pathlib.Path(args.project).resolve()
    if not (root / "project.godot").exists():
        raise SystemExit("Godot FPS template project.godot not found")
    patch_project(root)
    patch_player(root)
    patch_weapons(root)
    patch_hud(root)
    patch_world(root)
    create_hax_ui(root)
    patch_project_main(root)
    patch_export(root)
    print("HAX SHOOTING remaster patched:", root)

if __name__ == "__main__":
    main()
