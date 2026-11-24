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
var selected_mode := "tdm"
var selected_map := "red_harbor"
var credits := 5800
var diamonds := 420
var player_level := 18
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
var _settings: Dictionary = {"sensitivity":0.42,"aim_assist":true,"aim_strength":0.32,"aim_cone":8.0,"graphics":"high","volume":0.75}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _profile.load("user://hax_profile.cfg")
    credits = int(_profile.get_value("profile","credits",credits))
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
    shade.color = Color(0.008,0.01,0.02,0.45)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(shade)
    var top := HBoxContainer.new()
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 26
    top.offset_top = 16
    top.offset_right = -26
    top.offset_bottom = 92
    root.add_child(top)
    var logo := TextureRect.new()
    logo.custom_minimum_size = Vector2(74,74)
    logo.texture = load("res://assets/hax_skull_logo.svg")
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    top.add_child(logo)
    var brand := VBoxContainer.new()
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(brand)
    var title := Label.new()
    title.text = "HAX SHOOTING"
    title.add_theme_font_size_override("font_size",32)
    title.add_theme_color_override("font_color",Color.WHITE)
    brand.add_child(title)
    var by := Label.new()
    by.text = "BY: NACAR_22  •  SEASON ZERO"
    by.add_theme_color_override("font_color",Color("#ff536b"))
    brand.add_child(by)
    var balance := Label.new()
    balance.text = "◉ %d     ◆ %d     LV. %d" % [credits,diamonds,player_level]
    balance.add_theme_font_size_override("font_size",18)
    balance.add_theme_color_override("font_color",Color("#ffd47e"))
    top.add_child(balance)
    var column := VBoxContainer.new()
    column.set_anchors_preset(Control.PRESET_CENTER_LEFT)
    column.position = Vector2(36,-218)
    column.custom_minimum_size = Vector2(330,480)
    column.add_theme_constant_override("separation",10)
    root.add_child(column)
    _add_menu_button(column,"▶  PLAY NOW","play",true)
    _add_menu_button(column,"⚔  MULTIPLAYER ROOMS","rooms")
    _add_menu_button(column,"▣  ARMORY & WEAPONS","armory")
    _add_menu_button(column,"♜  OPERATORS & OUTFITS","operators")
    _add_menu_button(column,"◆  STORE & REWARDS","store")
    _add_menu_button(column,"⚙  SETTINGS","settings")
    var footer := Label.new()
    footer.text = "TACTICAL OPERATIONS  //  HAX DIVISION  //  BUILD " + GameData.VERSION
    footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    footer.offset_left = 28
    footer.offset_top = -40
    footer.offset_right = -20
    footer.offset_bottom = -12
    footer.add_theme_color_override("font_color",Color("#c2c3c9"))
    root.add_child(footer)

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

func _new_page(title: String, subtitle := "") -> VBoxContainer:
    page = title.to_lower().replace(" ","_")
    _clear_page()
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.012,0.014,0.02,0.96)
    _root.add_child(shade)
    _main_menu = shade
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(700,560)
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
    var box := _new_page("Select Operation","Choose a mode, arena and difficulty.")
    for mode in GameData.MODES:
        var b := Button.new()
        b.text = "%s   •   %s" % [mode.name,mode.players]
        _style_button(b,mode.id == selected_mode)
        b.pressed.connect(func(): selected_mode = str(mode.id); _show_mode_select())
        box.add_child(b)
    var map_pick := OptionButton.new()
    for game_map in GameData.MAPS:
        map_pick.add_item(str(game_map.name))
    box.add_child(map_pick)
    var deploy := Button.new()
    deploy.text = "DEPLOY INTO BATTLE"
    _style_button(deploy,true)
    deploy.pressed.connect(func():
        selected_map = str(GameData.MAPS[map_pick.selected].id)
        start_requested.emit(selected_mode,selected_map)
    )
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
    _build_main_menu()
    show_game_hud(false)

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
    _round_label.text = "ROUND 01"
    _round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _round_label.add_theme_font_size_override("font_size",18)
    top.add_child(_round_label)
    _score_label = Label.new()
    _score_label.text = "KILLS 0 • DEATHS 0"
    _score_label.add_theme_color_override("font_color",Color("#ff6074"))
    top.add_child(_score_label)
    var pause := Button.new()
    pause.text = "Ⅱ"
    pause.custom_minimum_size = Vector2(52,46)
    _style_button(pause)
    pause.pressed.connect(show_pause_menu)
    top.add_child(pause)
    _crosshair = Label.new()
    _crosshair.text = "＋"
    _crosshair.add_theme_font_size_override("font_size",32)
    _crosshair.add_theme_color_override("font_color",Color("#55ff75"))
    _crosshair.set_anchors_preset(Control.PRESET_CENTER)
    _crosshair.position = Vector2(-12,-18)
    _hud.add_child(_crosshair)
    var bottom := HBoxContainer.new()
    bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_left = 26
    bottom.offset_top = -86
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
    bottom.add_child(_ammo_label)
    _feed = Label.new()
    _feed.position = Vector2(24,90)
    _feed.custom_minimum_size = Vector2(450,100)
    _feed.add_theme_color_override("font_color",Color("#ffd3dc"))
    _hud.add_child(_feed)

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
    layer.gui_input.connect(_on_mobile_gui_input)
    _hud.add_child(layer)
    var left := HBoxContainer.new()
    left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    left.offset_left = 18
    left.offset_top = -190
    left.offset_right = 238
    left.offset_bottom = -18
    layer.add_child(left)
    var dirs := VBoxContainer.new()
    dirs.alignment = BoxContainer.ALIGNMENT_CENTER
    left.add_child(dirs)
    var up := _touch_button("▲",Vector2(64,56))
    up.button_down.connect(func(): mobile_move_changed.emit(Vector2(0,-1)))
    up.button_up.connect(func(): mobile_move_changed.emit(Vector2.ZERO))
    dirs.add_child(up)
    var row := HBoxContainer.new()
    dirs.add_child(row)
    var l := _touch_button("◀",Vector2(64,56))
    l.button_down.connect(func(): mobile_move_changed.emit(Vector2(-1,0)))
    l.button_up.connect(func(): mobile_move_changed.emit(Vector2.ZERO))
    row.add_child(l)
    var down := _touch_button("▼",Vector2(64,56))
    down.button_down.connect(func(): mobile_move_changed.emit(Vector2(0,1)))
    down.button_up.connect(func(): mobile_move_changed.emit(Vector2.ZERO))
    row.add_child(down)
    var right := VBoxContainer.new()
    right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    right.offset_left = -215
    right.offset_top = -220
    right.offset_right = -18
    right.offset_bottom = -18
    layer.add_child(right)
    var fire := _touch_button("FIRE",Vector2(105,88))
    fire.button_down.connect(func(): mobile_fire_changed.emit(true))
    fire.button_up.connect(func(): mobile_fire_changed.emit(false))
    right.add_child(fire)
    var aim := _touch_button("AIM",Vector2(90,52))
    aim.button_down.connect(func(): mobile_aim_changed.emit(true))
    aim.button_up.connect(func(): mobile_aim_changed.emit(false))
    right.add_child(aim)
    var reload := _touch_button("RELOAD",Vector2(90,48))
    reload.pressed.connect(func(): setting_changed.emit("reload",true))
    right.add_child(reload)

func _on_mobile_gui_input(event: InputEvent) -> void:
    if event is InputEventScreenDrag and event.position.x > get_viewport().get_visible_rect().size.x * 0.38:
        mobile_look_changed.emit(event.relative)

func _touch_button(text: String,size: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = size
    b.add_theme_font_size_override("font_size",14)
    _style_button(b,text == "FIRE")
    b.modulate = Color(1,1,1,0.88)
    return b
