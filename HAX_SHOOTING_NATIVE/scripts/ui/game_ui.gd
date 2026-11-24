class_name HAXGameUI
extends CanvasLayer

signal start_requested(mode_id: String, map_id: String)
signal pause_requested(paused: bool)
signal room_create_requested(room_name: String, mode_id: String, map_id: String)
signal room_join_requested(room_code: String)
signal lan_host_requested(port: int)
signal lan_join_requested(address: String, port: int)
signal setting_changed(key: String, value: Variant)
signal mobile_move_changed(value: Vector2)
signal mobile_look_changed(value: Vector2)
signal mobile_fire_changed(value: bool)
signal mobile_aim_changed(value: bool)

var page := "main"
var selected_mode := "battle_royale"
var selected_map := "island"
var credits := 5800
var diamonds := 420
var player_level := 1
var rank_points := 0
var season_xp := 0
var _zone_label: Label
var _rank_value: Label
var _rank_bar: ProgressBar
var _result_panel: PanelContainer
var _squad_size := "SOLO"
var _root: Control
var _main_menu: Control
var _hud: Control
var _health_label: Label
var _ammo_label: Label
var _round_label: Label
var _score_label: Label
var _feed: Label
var _crosshair: Label
var _pause_panel: PanelContainer
var _room_status: Label
var _room_code_input: LineEdit
var _profile := ConfigFile.new()
var _owned_operator_skins: Array[String] = ["nacar_shadow"]
var _owned_weapon_skins: Array[String] = ["blackout"]
var _selected_operator_skin := "nacar_shadow"
var _selected_weapon_skin := "blackout"
var _settings: Dictionary = {"sensitivity":0.42,"aim_assist":true,"aim_strength":0.62,"aim_cone":13.0,"graphics":"high","volume":0.75}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _profile.load("user://hax_profile.cfg")
    credits = int(_profile.get_value("profile","credits",credits))
    rank_points = int(_profile.get_value("profile","rank_points",rank_points))
    season_xp = int(_profile.get_value("profile","season_xp",season_xp))
    player_level = int(_profile.get_value("profile","level",player_level))
    _owned_operator_skins = _profile.get_value("inventory","operators",_owned_operator_skins)
    _owned_weapon_skins = _profile.get_value("inventory","weapons",_owned_weapon_skins)
    _selected_operator_skin = str(_profile.get_value("inventory","selected_operator",_selected_operator_skin))
    _selected_weapon_skin = str(_profile.get_value("inventory","selected_weapon",_selected_weapon_skin))
    for key in _settings:
        _settings[key] = _profile.get_value("settings",key,_settings[key])
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(_root)
    _build_main_menu()

func save_profile() -> void:
    _profile.set_value("profile","credits",credits)
    _profile.set_value("profile","rank_points",rank_points)
    _profile.set_value("profile","season_xp",season_xp)
    _profile.set_value("profile","level",player_level)
    _profile.set_value("inventory","operators",_owned_operator_skins)
    _profile.set_value("inventory","weapons",_owned_weapon_skins)
    _profile.set_value("inventory","selected_operator",_selected_operator_skin)
    _profile.set_value("inventory","selected_weapon",_selected_weapon_skin)
    for key in _settings:
        _profile.set_value("settings",key,_settings[key])
    _profile.save("user://hax_profile.cfg")

func _clear_page() -> void:
    if is_instance_valid(_main_menu):
        _main_menu.queue_free()
    _main_menu = null


func _rank_name() -> String:
    if rank_points >= 3200:
        return "HEROIC"
    if rank_points >= 2300:
        return "DIAMOND"
    if rank_points >= 1600:
        return "PLATINUM"
    if rank_points >= 1000:
        return "GOLD"
    if rank_points >= 500:
        return "SILVER"
    return "BRONZE"

func add_rank_points(points: int) -> void:
    rank_points = clampi(rank_points + points,0,5000)
    season_xp = maxi(0,season_xp + maxi(0,points) * 3)
    credits = maxi(0,credits + maxi(0,points) * 2)
    player_level = maxi(1,1 + int(season_xp / 500))
    save_profile()
    if is_instance_valid(_rank_value):
        _rank_value.text = "%s  •  LV %02d  •  %d RP" % [_rank_name(),player_level,rank_points]
    if is_instance_valid(_rank_bar):
        _rank_bar.value = posmod(rank_points,500)

func _build_main_menu() -> void:
    page = "main"
    _clear_page()
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.add_child(root)
    _main_menu = root
    var bg := TextureRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.texture = load("res://assets/title_art.svg")
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    root.add_child(bg)
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.005,0.008,0.02,0.25)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(shade)

    var header := HBoxContainer.new()
    header.position = Vector2(38,26)
    header.custom_minimum_size = Vector2(570,84)
    root.add_child(header)
    var logo := TextureRect.new()
    logo.custom_minimum_size = Vector2(72,72)
    logo.texture = load("res://assets/hax_skull_logo.svg")
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    header.add_child(logo)
    var brand := VBoxContainer.new()
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(brand)
    var title := Label.new()
    title.text = "HAX SHOOTING"
    title.add_theme_font_size_override("font_size",35)
    title.add_theme_color_override("font_color",Color.WHITE)
    brand.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "BY: NACAR_22  •  SEASON 01  •  THIRD-PERSON BATTLE"
    subtitle.add_theme_font_size_override("font_size",13)
    subtitle.add_theme_color_override("font_color",Color("#ff7089"))
    brand.add_child(subtitle)

    var rank_panel := PanelContainer.new()
    rank_panel.anchor_left = 0.75
    rank_panel.anchor_right = 0.985
    rank_panel.anchor_top = 0.025
    rank_panel.anchor_bottom = 0.155
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.025,0.035,0.055,0.82)
    panel_style.border_color = Color("#d92347")
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(7)
    panel_style.content_margin_left = 12
    panel_style.content_margin_right = 12
    panel_style.content_margin_top = 7
    panel_style.content_margin_bottom = 7
    rank_panel.add_theme_stylebox_override("panel",panel_style)
    root.add_child(rank_panel)
    var rank_stack := VBoxContainer.new()
    rank_stack.add_theme_constant_override("separation",2)
    rank_panel.add_child(rank_stack)
    _rank_value = Label.new()
    _rank_value.text = "%s  •  LV %02d  •  %d RP" % [_rank_name(),player_level,rank_points]
    _rank_value.add_theme_font_size_override("font_size",16)
    _rank_value.add_theme_color_override("font_color",Color("#ffe2ad"))
    rank_stack.add_child(_rank_value)
    _rank_bar = ProgressBar.new()
    _rank_bar.custom_minimum_size = Vector2(0,10)
    _rank_bar.max_value = 500
    _rank_bar.value = posmod(rank_points,500)
    _rank_bar.show_percentage = false
    rank_stack.add_child(_rank_bar)
    var balance := Label.new()
    balance.text = "CREDITS %d   •   DIAMONDS %d   •   XP %d" % [credits,diamonds,season_xp]
    balance.add_theme_font_size_override("font_size",11)
    balance.add_theme_color_override("font_color",Color("#e2e7ef"))
    rank_stack.add_child(balance)

    var menu_panel := PanelContainer.new()
    menu_panel.position = Vector2(42,145)
    menu_panel.custom_minimum_size = Vector2(380,590)
    var menu_style := StyleBoxFlat.new()
    menu_style.bg_color = Color(0.018,0.025,0.04,0.86)
    menu_style.border_color = Color("#b91d3c")
    menu_style.set_border_width_all(2)
    menu_style.set_corner_radius_all(9)
    menu_style.content_margin_left = 18
    menu_style.content_margin_right = 18
    menu_style.content_margin_top = 17
    menu_style.content_margin_bottom = 17
    menu_panel.add_theme_stylebox_override("panel",menu_style)
    root.add_child(menu_panel)
    var menu_column := VBoxContainer.new()
    menu_column.add_theme_constant_override("separation",8)
    menu_panel.add_child(menu_column)
    var section := Label.new()
    section.text = "COMMAND CENTER  /  DEPLOYMENT"
    section.add_theme_font_size_override("font_size",16)
    section.add_theme_color_override("font_color",Color("#ff657c"))
    menu_column.add_child(section)
    _add_menu_button(menu_column,"▶   PLAY / SELECT MODE","play",true)
    _add_menu_button(menu_column,"⚡   QUICK BATTLE ROYALE","battle_royale")
    _add_menu_button(menu_column,"♟   MULTIPLAYER / SQUAD","rooms")
    _add_menu_button(menu_column,"▣   ARMORY / LOADOUT","armory")
    _add_menu_button(menu_column,"♜   OPERATORS / OUTFITS","operators")
    _add_menu_button(menu_column,"◆   SEASON / REWARDS","store")
    _add_menu_button(menu_column,"⚙   SETTINGS","settings")
    _add_menu_button(menu_column,"⏻   EXIT GAME","exit")

    var feature := PanelContainer.new()
    feature.anchor_left = 0.75
    feature.anchor_right = 0.985
    feature.anchor_top = 0.76
    feature.anchor_bottom = 0.94
    var feature_style := StyleBoxFlat.new()
    feature_style.bg_color = Color(0.02,0.03,0.05,0.82)
    feature_style.border_color = Color("#ff3156")
    feature_style.set_border_width_all(1)
    feature_style.set_corner_radius_all(7)
    feature_style.content_margin_left = 16
    feature_style.content_margin_right = 16
    feature_style.content_margin_top = 10
    feature_style.content_margin_bottom = 10
    feature.add_theme_stylebox_override("panel",feature_style)
    root.add_child(feature)
    var feature_stack := VBoxContainer.new()
    feature.add_child(feature_stack)
    var feature_title := Label.new()
    feature_title.text = "FEATURED PLAYLIST"
    feature_title.add_theme_font_size_override("font_size",13)
    feature_title.add_theme_color_override("font_color",Color("#ff6980"))
    feature_stack.add_child(feature_title)
    var map_name := Label.new()
    map_name.text = "HAX ISLAND  /  16 OPERATORS"
    map_name.add_theme_font_size_override("font_size",19)
    map_name.add_theme_color_override("font_color",Color.WHITE)
    feature_stack.add_child(map_name)
    var description := Label.new()
    description.text = "DROP IN • LOOT UP • SURVIVE THE STORM"
    description.add_theme_font_size_override("font_size",11)
    description.add_theme_color_override("font_color",Color("#d4dbe6"))
    feature_stack.add_child(description)

    var footer := Label.new()
    footer.text = "HAX DIVISION  //  BUILD %s  //  MOBILE THIRD-PERSON SHOOTER" % GameData.VERSION
    footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    footer.offset_left = 24
    footer.offset_top = -32
    footer.offset_right = -24
    footer.offset_bottom = -8
    footer.add_theme_font_size_override("font_size",11)
    footer.add_theme_color_override("font_color",Color("#e0e4ea"))
    root.add_child(footer)


func _add_hotspot(parent: Control, rect: Rect2, action: String, label_text: String) -> void:
    var button := Button.new()
    button.anchor_left = rect.position.x
    button.anchor_top = rect.position.y
    button.anchor_right = rect.position.x + rect.size.x
    button.anchor_bottom = rect.position.y + rect.size.y
    button.offset_left = 0
    button.offset_top = 0
    button.offset_right = 0
    button.offset_bottom = 0
    button.tooltip_text = label_text
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color(1.0,0.12,0.24,0.16)
    hover.border_color = Color("#ff4767")
    hover.set_border_width_all(2)
    hover.set_corner_radius_all(6)
    button.add_theme_stylebox_override("hover",hover)
    button.add_theme_stylebox_override("pressed",hover)
    button.pressed.connect(_on_menu_action.bind(action))
    parent.add_child(button)

func _add_compact_action(parent: HBoxContainer, text_value: String, action: String) -> void:
    var button := Button.new()
    button.text = text_value
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.custom_minimum_size.y = 38
    button.add_theme_font_size_override("font_size",12)
    _style_button(button)
    button.pressed.connect(_on_menu_action.bind(action))
    parent.add_child(button)


func _add_menu_button(parent: VBoxContainer, text: String, action: String, primary := false) -> void:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(300,58)
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _style_button(b,primary)
    b.pressed.connect(_on_menu_action.bind(action))
    parent.add_child(b)

func _style_button(button: Button, primary := false) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#32101b") if primary else Color("#0a101a")
    normal.border_color = Color("#ff294b") if primary else Color("#762039")
    normal.set_border_width_all(2 if primary else 1)
    normal.set_corner_radius_all(5)
    normal.content_margin_left = 16
    normal.content_margin_right = 14
    normal.content_margin_top = 8
    normal.content_margin_bottom = 8
    var hover := normal.duplicate()
    hover.bg_color = Color("#751b31")
    hover.border_color = Color("#ff8295")
    button.add_theme_stylebox_override("normal",normal)
    button.add_theme_stylebox_override("hover",hover)
    button.add_theme_stylebox_override("pressed",hover)
    button.add_theme_color_override("font_color",Color.WHITE)
    button.add_theme_color_override("font_hover_color",Color("#ffdce2"))
    button.add_theme_font_size_override("font_size",17)
    button.focus_mode = Control.FOCUS_NONE

func _on_menu_action(action: String) -> void:
    match action:
        "play": _show_mode_select()
        "rooms": _show_rooms()
        "armory": _show_armory()
        "operators": _show_operators()
        "store": _show_store()
        "settings": _show_settings()
        "battle_royale":
            selected_mode = "battle_royale"
            selected_map = "island"
            start_requested.emit(selected_mode,selected_map)
        "zombies":
            selected_mode = "zombies"
            selected_map = "red_harbor"
            start_requested.emit(selected_mode,selected_map)
        "exit": get_tree().quit()

func _new_page(title: String, subtitle := "") -> VBoxContainer:
    page = title.to_lower().replace(" ","_")
    _clear_page()
    var page_root := Control.new()
    page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.add_child(page_root)
    _main_menu = page_root
    var backdrop := TextureRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var art_path := "res://assets/title_art.png" if ResourceLoader.exists("res://assets/title_art.png") else "res://assets/title_art.svg"
    backdrop.texture = load(art_path)
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    page_root.add_child(backdrop)
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.005,0.008,0.018,0.82)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    page_root.add_child(shade)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    page_root.add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(1000,640)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color("#111720")
    panel_style.border_color = Color("#d51b3d")
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(8)
    panel_style.content_margin_left = 25
    panel_style.content_margin_right = 25
    panel_style.content_margin_top = 22
    panel_style.content_margin_bottom = 22
    panel.add_theme_stylebox_override("panel",panel_style)
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation",10)
    panel.add_child(box)
    var heading := Label.new()
    heading.text = title.to_upper()
    heading.add_theme_font_size_override("font_size",28)
    heading.add_theme_color_override("font_color",Color("#ff405e"))
    box.add_child(heading)
    if subtitle != "":
        var sub := Label.new()
        sub.text = subtitle
        sub.add_theme_color_override("font_color",Color("#c3c9d2"))
        box.add_child(sub)
    return box

func _add_back(parent: VBoxContainer) -> void:
    var b := Button.new()
    b.text = "← BACK TO HAX HQ"
    _style_button(b)
    b.pressed.connect(_build_main_menu)
    parent.add_child(b)

func _show_mode_select() -> void:
    var box := _new_page("SELECT OPERATION","Choose your playlist and combat zone.")
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation",10)
    grid.add_theme_constant_override("v_separation",8)
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(grid)
    for mode in GameData.MODES:
        var button := Button.new()
        button.custom_minimum_size = Vector2(300,66)
        button.text = "%s\n%s   •   %s" % [mode.name,mode.players,mode.description]
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_font_size_override("font_size",14)
        _style_button(button,str(mode.id) == selected_mode)
        button.pressed.connect(func():
            selected_mode = str(mode.id)
            for child in grid.get_children():
                if child is Button:
                    child.disabled = false
            button.disabled = true
        )
        grid.add_child(button)
    var map_row := HBoxContainer.new()
    box.add_child(map_row)
    var map_label := Label.new()
    map_label.text = "BATTLEFIELD"
    map_label.custom_minimum_size.x = 120
    map_label.add_theme_color_override("font_color",Color("#ff647a"))
    map_row.add_child(map_label)
    var map_pick := OptionButton.new()
    map_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for game_map in GameData.MAPS:
        map_pick.add_item("%s  |  %s  |  %s" % [game_map.name,game_map.theme,game_map.size])
    var selected_index := 0
    for index in range(GameData.MAPS.size()):
        if str(GameData.MAPS[index].id) == selected_map:
            selected_index = index
            break
    map_pick.select(selected_index)
    map_pick.item_selected.connect(func(index: int): selected_map = str(GameData.MAPS[index].id))
    map_row.add_child(map_pick)
    var deploy := Button.new()
    deploy.text = "▶  DEPLOY INTO BATTLE"
    deploy.custom_minimum_size.y = 58
    _style_button(deploy,true)
    deploy.pressed.connect(func(): start_requested.emit(selected_mode,selected_map))
    box.add_child(deploy)
    _add_back(box)


func _show_armory() -> void:
    var box := _new_page("Armory","Six weapon classes · choose your loadout.")
    for weapon in GameData.WEAPONS:
        var b := Button.new()
        b.text = "%s   |   DMG %s   RPM %s" % [weapon.name,weapon.damage,weapon.rpm]
        _style_button(b,str(weapon.id) == str(GameData.WEAPONS[0].id))
        b.pressed.connect(func(): setting_changed.emit("weapon",str(weapon.id)))
        box.add_child(b)
    var skin_pick := OptionButton.new()
    for skin in GameData.WEAPON_SKINS:
        skin_pick.add_item(str(skin.name))
    box.add_child(skin_pick)
    var equip := Button.new()
    equip.text = "EQUIP WEAPON SKIN"
    _style_button(equip,true)
    equip.pressed.connect(func():
        var skin: Dictionary = GameData.WEAPON_SKINS[skin_pick.selected]
        if _owned_weapon_skins.has(str(skin.id)):
            _selected_weapon_skin = str(skin.id)
            setting_changed.emit("weapon_skin",_selected_weapon_skin)
            save_profile()
    )
    box.add_child(equip)
    _add_back(box)

func _show_operators() -> void:
    var box := _new_page("Operators & Outfits","Choose your combat identity.")
    for skin in GameData.OPERATOR_SKINS:
        var b := Button.new()
        b.text = "%s   •   %d CREDITS" % [skin.name,int(skin.cost)]
        _style_button(b,_selected_operator_skin == str(skin.id))
        b.pressed.connect(func():
            if _owned_operator_skins.has(str(skin.id)):
                _selected_operator_skin = str(skin.id)
                setting_changed.emit("operator_skin",_selected_operator_skin)
                save_profile()
        )
        box.add_child(b)
    _add_back(box)

func _show_store() -> void:
    var box := _new_page("HAX Store","Earn credits in combat. Purchases are saved locally in this alpha.")
    var balance := Label.new()
    balance.text = "YOUR CREDITS: %d" % credits
    box.add_child(balance)
    for skin in GameData.OPERATOR_SKINS:
        var b := Button.new()
        b.text = "UNLOCK %s  —  %d C" % [skin.name,int(skin.cost)]
        _style_button(b)
        b.pressed.connect(func():
            if _owned_operator_skins.has(str(skin.id)):
                return
            if credits >= int(skin.cost):
                credits -= int(skin.cost)
                _owned_operator_skins.append(str(skin.id))
                save_profile()
                _show_store()
        )
        box.add_child(b)
    _add_back(box)

func _show_settings() -> void:
    var box := _new_page("Combat Settings","Fine tune controls and visual quality.")
    var aim := CheckBox.new()
    aim.text = "AIM ASSIST"
    aim.button_pressed = bool(_settings.aim_assist)
    aim.toggled.connect(func(v: bool): _settings.aim_assist = v; setting_changed.emit("aim_assist",v); save_profile())
    box.add_child(aim)
    _add_slider(box,"AIM ASSIST STRENGTH",0.0,1.0,float(_settings.aim_strength),"aim_strength")
    _add_slider(box,"AIM CONE (DEGREES)",2.0,18.0,float(_settings.aim_cone),"aim_cone")
    _add_slider(box,"MOUSE / LOOK SENSITIVITY",0.1,1.0,float(_settings.sensitivity),"sensitivity")
    var quality := OptionButton.new()
    for q in ["low","medium","high"]:
        quality.add_item(q.to_upper())
    quality.select(["low","medium","high"].find(str(_settings.graphics)))
    quality.item_selected.connect(func(i: int): _settings.graphics = ["low","medium","high"][i]; setting_changed.emit("graphics",_settings.graphics); save_profile())
    box.add_child(quality)
    _add_back(box)

func _add_slider(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, value: float, key: String) -> void:
    var label := Label.new()
    label.text = label_text
    parent.add_child(label)
    var slider := HSlider.new()
    slider.min_value = minimum
    slider.max_value = maximum
    slider.value = value
    slider.step = 0.01
    slider.value_changed.connect(func(v: float): _settings[key] = v; setting_changed.emit(key,v); save_profile())
    parent.add_child(slider)

func _show_rooms() -> void:
    var box := _new_page("Squad Rooms","Online rooms need the deployed HAX room server. LAN uses Wi-Fi / Ethernet.")
    var room_name := LineEdit.new()
    room_name.placeholder_text = "ROOM NAME"
    room_name.text = "NACAR PRIVATE ROOM"
    box.add_child(room_name)
    var online_create := Button.new()
    online_create.text = "CREATE ONLINE ROOM"
    _style_button(online_create,true)
    online_create.pressed.connect(func(): room_create_requested.emit(room_name.text,selected_mode,selected_map))
    box.add_child(online_create)
    _room_code_input = LineEdit.new()
    _room_code_input.placeholder_text = "ENTER FRIEND ROOM CODE"
    _room_code_input.max_length = 10
    box.add_child(_room_code_input)
    var join := Button.new()
    join.text = "JOIN FRIEND'S ROOM"
    _style_button(join)
    join.pressed.connect(func(): room_join_requested.emit(_room_code_input.text.strip_edges().to_upper()))
    box.add_child(join)
    var port := SpinBox.new()
    port.min_value = 1024
    port.max_value = 65535
    port.value = 24500
    port.prefix = "UDP PORT "
    box.add_child(port)
    var host := Button.new()
    host.text = "HOST WI-FI / LAN"
    _style_button(host,true)
    host.pressed.connect(func(): lan_host_requested.emit(int(port.value)))
    box.add_child(host)
    var address := LineEdit.new()
    address.placeholder_text = "FRIEND'S LOCAL IP ADDRESS"
    box.add_child(address)
    var join_lan := Button.new()
    join_lan.text = "JOIN WI-FI / LAN"
    _style_button(join_lan)
    join_lan.pressed.connect(func(): lan_join_requested.emit(address.text.strip_edges(),int(port.value)))
    box.add_child(join_lan)
    _room_status = Label.new()
    _room_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _room_status.text = "ONLINE: SERVER NOT CONFIGURED  •  LAN: READY"
    box.add_child(_room_status)
    _add_back(box)

func set_room_status(message: String) -> void:
    if is_instance_valid(_room_status):
        _room_status.text = message

func show_main_menu() -> void:
    if is_instance_valid(_hud):
        _hud.queue_free()
        _hud = null
    _build_main_menu()

func show_game_hud(show_mobile := true) -> void:
    _clear_page()
    if is_instance_valid(_hud):
        _hud.queue_free()
    _hud = Control.new()
    _hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _hud.mouse_filter = Control.MOUSE_FILTER_PASS
    _root.add_child(_hud)
    _build_hud()
    if show_mobile:
        _build_mobile_controls()

func _build_hud() -> void:
    var top := HBoxContainer.new()
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 22
    top.offset_top = 14
    top.offset_right = -22
    top.offset_bottom = 66
    _hud.add_child(top)
    _round_label = Label.new()
    _round_label.text = "HAX ISLAND  •  BATTLE ROYALE"
    _round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _round_label.add_theme_font_size_override("font_size",18)
    _round_label.add_theme_color_override("font_color",Color("#fff0df"))
    top.add_child(_round_label)
    _score_label = Label.new()
    _score_label.text = "ELIMS 0  •  16 ALIVE"
    _score_label.add_theme_color_override("font_color",Color("#ff6074"))
    _score_label.add_theme_font_size_override("font_size",17)
    top.add_child(_score_label)
    var pause := Button.new()
    pause.text = "Ⅱ"
    pause.custom_minimum_size = Vector2(54,46)
    _style_button(pause)
    pause.pressed.connect(show_pause_menu)
    top.add_child(pause)

    _zone_label = Label.new()
    _zone_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _zone_label.offset_top = 75
    _zone_label.offset_bottom = 106
    _zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _zone_label.add_theme_font_size_override("font_size",16)
    _zone_label.add_theme_color_override("font_color",Color("#ff667d"))
    _zone_label.text = "SAFE ZONE INITIALIZING"
    _hud.add_child(_zone_label)

    _crosshair = Label.new()
    _crosshair.text = "·"
    _crosshair.add_theme_font_size_override("font_size",26)
    _crosshair.add_theme_color_override("font_color",Color("#ffffff"))
    _crosshair.set_anchors_preset(Control.PRESET_CENTER)
    _crosshair.position = Vector2(-8,-16)
    _hud.add_child(_crosshair)
    var bottom := HBoxContainer.new()
    bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_left = 26
    bottom.offset_top = -88
    bottom.offset_right = -26
    bottom.offset_bottom = -18
    _hud.add_child(bottom)
    _health_label = Label.new()
    _health_label.text = "♥ 100   ◆ 75"
    _health_label.add_theme_font_size_override("font_size",22)
    _health_label.add_theme_color_override("font_color",Color("#ff405e"))
    _health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bottom.add_child(_health_label)
    _ammo_label = Label.new()
    _ammo_label.text = "30 / 180"
    _ammo_label.add_theme_font_size_override("font_size",25)
    _ammo_label.add_theme_color_override("font_color",Color("#ffffff"))
    bottom.add_child(_ammo_label)
    _feed = Label.new()
    _feed.position = Vector2(24,116)
    _feed.custom_minimum_size = Vector2(490,130)
    _feed.add_theme_font_size_override("font_size",14)
    _feed.add_theme_color_override("font_color",Color("#ffd3dc"))
    _hud.add_child(_feed)

func update_battle_royale(radius: float, elapsed: float) -> void:
    if not is_instance_valid(_zone_label):
        return
    var seconds_to_shrink := maxi(0,24 - int(elapsed))
    if elapsed < 24.0:
        _zone_label.text = "SAFE ZONE  •  RADIUS %.0f M  •  SHRINK IN %02d" % [radius,seconds_to_shrink]
    else:
        _zone_label.text = "STORM ACTIVE  •  SAFE RADIUS %.0f M" % radius

func show_match_result(title_text: String, subtitle: String, kills: int, placement: String, rank_reward: int) -> void:
    var overlay := ColorRect.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.005,0.008,0.016,0.76)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.add_child(overlay)
    _result_panel = PanelContainer.new()
    _result_panel.set_anchors_preset(Control.PRESET_CENTER)
    _result_panel.position = Vector2(-270,-230)
    _result_panel.custom_minimum_size = Vector2(540,460)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#111a28")
    style.border_color = Color("#e3294e")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.content_margin_left = 28
    style.content_margin_right = 28
    style.content_margin_top = 24
    style.content_margin_bottom = 24
    _result_panel.add_theme_stylebox_override("panel",style)
    overlay.add_child(_result_panel)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation",16)
    _result_panel.add_child(stack)
    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",38)
    title.add_theme_color_override("font_color",Color("#ff536e"))
    stack.add_child(title)
    var sub := Label.new()
    sub.text = subtitle
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size",17)
    stack.add_child(sub)
    var stats := Label.new()
    stats.text = "PLACEMENT  %s\nELIMINATIONS  %d\nRANK POINTS  %+d" % [placement,kills,rank_reward]
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.add_theme_font_size_override("font_size",22)
    stats.add_theme_color_override("font_color",Color("#f3e6d6"))
    stack.add_child(stats)
    var home := Button.new()
    home.text = "RETURN TO HAX LOBBY"
    home.custom_minimum_size.y = 58
    _style_button(home,true)
    home.pressed.connect(func():
        if is_instance_valid(overlay):
            overlay.queue_free()
        show_main_menu()
    )
    stack.add_child(home)

func update_hud(health: float, armor: float, ammo: int, reserve: int, round_no: int, kills: int, deaths: int, mode: String) -> void:
    if not is_instance_valid(_hud):
        return
    _health_label.text = "♥ %03d   ◆ %03d" % [roundi(health),roundi(armor)]
    _ammo_label.text = "%02d / %03d" % [ammo,reserve]
    _round_label.text = "%s  •  ROUND %02d" % [mode.to_upper(),round_no]
    _score_label.text = "KILLS %d  •  DEATHS %d" % [kills,deaths]

func add_kill_feed(message: String) -> void:
    if is_instance_valid(_feed):
        _feed.text = message + "\n" + _feed.text

func show_hitmarker(headshot := false) -> void:
    if not is_instance_valid(_crosshair):
        return
    _crosshair.text = "✦" if headshot else "×"
    _crosshair.add_theme_color_override("font_color",Color("#ffd044") if headshot else Color.WHITE)
    await get_tree().create_timer(0.18).timeout
    if is_instance_valid(_crosshair):
        _crosshair.text = "＋"
        _crosshair.add_theme_color_override("font_color",Color("#55ff75"))

func show_pause_menu() -> void:
    if is_instance_valid(_pause_panel):
        _pause_panel.queue_free()
        _pause_panel = null
        pause_requested.emit(false)
        return
    pause_requested.emit(true)
    _pause_panel = PanelContainer.new()
    _pause_panel.set_anchors_preset(Control.PRESET_CENTER)
    _pause_panel.position = Vector2(-210,-145)
    _pause_panel.custom_minimum_size = Vector2(420,290)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#10151f")
    style.border_color = Color("#e31c40")
    style.set_border_width_all(2)
    style.content_margin_left = 22
    style.content_margin_right = 22
    style.content_margin_top = 18
    style.content_margin_bottom = 18
    _pause_panel.add_theme_stylebox_override("panel",style)
    _hud.add_child(_pause_panel)
    var stack := VBoxContainer.new()
    _pause_panel.add_child(stack)
    var label := Label.new()
    label.text = "MISSION PAUSED"
    label.add_theme_font_size_override("font_size",25)
    stack.add_child(label)
    var resume := Button.new()
    resume.text = "RESUME"
    _style_button(resume,true)
    resume.pressed.connect(show_pause_menu)
    stack.add_child(resume)
    var settings := Button.new()
    settings.text = "COMBAT SETTINGS"
    _style_button(settings)
    settings.pressed.connect(_show_settings)
    stack.add_child(settings)
    var leave := Button.new()
    leave.text = "LEAVE MATCH"
    _style_button(leave)
    leave.pressed.connect(func(): pause_requested.emit(false); start_requested.emit("__leave__",""))
    stack.add_child(leave)

func _build_mobile_controls() -> void:
    var layer := Control.new()
    layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.mouse_filter = Control.MOUSE_FILTER_PASS
    _hud.add_child(layer)
    var touch := Control.new()
    touch.set_script(load("res://scripts/ui/touch_controller.gd"))
    touch.move_changed.connect(mobile_move_changed.emit)
    touch.look_changed.connect(mobile_look_changed.emit)
    layer.add_child(touch)

    _add_mobile_action(layer,"FIRE",Rect2(0.84,0.74,0.14,0.19),"fire")
    _add_mobile_action(layer,"AIM",Rect2(0.72,0.82,0.12,0.15),"aim")
    _add_mobile_action(layer,"RELOAD",Rect2(0.86,0.56,0.12,0.15),"reload")
    _add_mobile_action(layer,"JUMP",Rect2(0.70,0.57,0.13,0.16),"jump")
    _add_mobile_action(layer,"CROUCH",Rect2(0.58,0.79,0.12,0.15),"crouch")
    _add_mobile_action(layer,"SWAP",Rect2(0.86,0.39,0.12,0.15),"swap")
    _add_mobile_action(layer,"RUN",Rect2(0.025,0.62,0.13,0.15),"run")

func _add_mobile_action(parent: Control, label_text: String, rect: Rect2, action: String) -> void:
    var button := Button.new()
    button.anchor_left = rect.position.x
    button.anchor_top = rect.position.y
    button.anchor_right = rect.position.x + rect.size.x
    button.anchor_bottom = rect.position.y + rect.size.y
    button.offset_left = 0
    button.offset_top = 0
    button.offset_right = 0
    button.offset_bottom = 0
    button.text = label_text
    button.add_theme_font_size_override("font_size",13 if action != "fire" else 16)
    _style_button(button,action == "fire")
    button.modulate = Color(1,1,1,0.9)
    match action:
        "fire":
            button.button_down.connect(func(): mobile_fire_changed.emit(true))
            button.button_up.connect(func(): mobile_fire_changed.emit(false))
        "aim":
            button.button_down.connect(func(): mobile_aim_changed.emit(true))
            button.button_up.connect(func(): mobile_aim_changed.emit(false))
        "reload":
            button.pressed.connect(func(): setting_changed.emit("reload",true))
        "jump":
            button.button_down.connect(func(): Input.action_press("jump"))
            button.button_up.connect(func(): Input.action_release("jump"))
        "crouch":
            button.pressed.connect(func(): setting_changed.emit("crouch",true))
        "swap":
            button.pressed.connect(func(): setting_changed.emit("weapon_next",true))
        "run":
            button.button_down.connect(func(): Input.action_press("sprint"))
            button.button_up.connect(func(): Input.action_release("sprint"))
    parent.add_child(button)


func _touch_button(text: String,size: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = size
    b.add_theme_font_size_override("font_size",14)
    _style_button(b,text == "FIRE")
    b.modulate = Color(1,1,1,0.88)
    return b
