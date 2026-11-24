class_name GameData
extends RefCounted

const BRAND := "HAX SHOOTING"
const AUTHOR := "BY: NACAR_22"
const VERSION := "0.3.0-alpha"
const WEAPONS: Array[Dictionary] = [
    {"id":"hax_ar", "name":"HAX-AR 74", "class":"ASSAULT", "damage":27.0, "head":3.2, "rpm":690.0, "mag":30, "reserve":180, "reload":2.1, "range":115.0, "spread":0.012, "recoil":0.75, "color":Color("#a30d22")},
    {"id":"viper_smg", "name":"VIPER SMG", "class":"SMG", "damage":20.0, "head":3.0, "rpm":920.0, "mag":36, "reserve":216, "reload":1.65, "range":62.0, "spread":0.022, "recoil":0.48, "color":Color("#df233b")},
    {"id":"kraken_12", "name":"KRAKEN-12", "class":"SHOTGUN", "damage":12.0, "head":2.2, "rpm":92.0, "mag":8, "reserve":56, "reload":2.8, "range":24.0, "spread":0.085, "pellets":9, "recoil":1.6, "color":Color("#b86b25")},
    {"id":"phantom_aw", "name":"PHANTOM AWM", "class":"SNIPER", "damage":82.0, "head":4.0, "rpm":48.0, "mag":5, "reserve":40, "reload":3.0, "range":240.0, "spread":0.001, "recoil":2.1, "color":Color("#4c86b5")},
    {"id":"sentinel_p", "name":"SENTINEL P9", "class":"PISTOL", "damage":24.0, "head":3.0, "rpm":380.0, "mag":15, "reserve":90, "reload":1.4, "range":55.0, "spread":0.018, "recoil":0.35, "color":Color("#a5abb8")},
    {"id":"reaper_dmr", "name":"REAPER DMR", "class":"MARKSMAN", "damage":48.0, "head":3.4, "rpm":220.0, "mag":12, "reserve":84, "reload":2.4, "range":180.0, "spread":0.003, "recoil":1.0, "color":Color("#8a9b6d")}
]
const MODES: Array[Dictionary] = [
    {"id":"tdm", "name":"TEAM DEATHMATCH", "players":"5 vs 5", "description":"Team score race · 10 minutes", "bots":8},
    {"id":"ffa", "name":"FREE FOR ALL", "players":"8 players", "description":"Every operator for themselves", "bots":7},
    {"id":"domination", "name":"DOMINATION", "players":"5 vs 5", "description":"Capture and hold three zones", "bots":8},
    {"id":"sniper", "name":"SNIPER ELITE", "players":"6 players", "description":"Precision weapons only", "bots":5},
    {"id":"zombies", "name":"NIGHTFALL ZOMBIES", "players":"1–4 players", "description":"Survive escalating infected waves", "bots":6},
    {"id":"battle_royale", "name":"BATTLE ROYALE", "players":"16 operators", "description":"Island drop · looting · shrinking danger zone · last operator standing", "bots":15},
    {"id":"training", "name":"FIRING RANGE", "players":"Solo", "description":"Weapon practice · aim drills", "bots":4},
    {"id":"ranked", "name":"RANKED ARENA", "players":"5 vs 5", "description":"Competitive rounds · seasonal rating", "bots":8}
]
const MAPS: Array[Dictionary] = [
    {"id":"island", "name":"HAX ISLAND", "theme":"OPEN-WORLD COASTAL BATTLE ROYALE", "size":"XL"},
    {"id":"red_harbor", "name":"RED HARBOR", "theme":"INDUSTRIAL PORT", "size":"LARGE"},
    {"id":"dust_front", "name":"DUST FRONT", "theme":"DESERT OUTPOST", "size":"LARGE"},
    {"id":"night_city", "name":"NIGHT CITY", "theme":"URBAN DISTRICT", "size":"LARGE"},
    {"id":"frostline", "name":"FROSTLINE", "theme":"ARCTIC RESEARCH BASE", "size":"MEDIUM"}
]
const OPERATOR_SKINS: Array[Dictionary] = [
    {"id":"nacar_shadow", "name":"NACAR SHADOW", "cost":0, "color":Color("#15171d"), "accent":Color("#d71936")},
    {"id":"crimson_guard", "name":"CRIMSON GUARD", "cost":650, "color":Color("#3a1018"), "accent":Color("#ff304d")},
    {"id":"arctic_ghost", "name":"ARCTIC GHOST", "cost":900, "color":Color("#8aabbc"), "accent":Color("#d7e9f5")},
    {"id":"sand_viper", "name":"SAND VIPER", "cost":1100, "color":Color("#8e7551"), "accent":Color("#d1b27c")},
    {"id":"toxic_reign", "name":"TOXIC REIGN", "cost":1500, "color":Color("#253e31"), "accent":Color("#8aff61")},
    {"id":"royal_reaper", "name":"ROYAL REAPER", "cost":2400, "color":Color("#28202d"), "accent":Color("#d6a5ff")}
]
const WEAPON_SKINS: Array[Dictionary] = [
    {"id":"blackout", "name":"BLACKOUT", "cost":0, "color":Color("#15171c")},
    {"id":"blood_moon", "name":"BLOOD MOON", "cost":500, "color":Color("#a20e2b")},
    {"id":"gold_fang", "name":"GOLD FANG", "cost":1300, "color":Color("#c79b35")},
    {"id":"neon_rift", "name":"NEON RIFT", "cost":1800, "color":Color("#683bba")},
    {"id":"frost_bite", "name":"FROST BITE", "cost":1000, "color":Color("#61a4d7")}
]
static func get_weapon(weapon_id: String) -> Dictionary:
    for weapon in WEAPONS:
        if weapon.id == weapon_id:
            return weapon.duplicate(true)
    return WEAPONS[0].duplicate(true)

static func get_mode(mode_id: String) -> Dictionary:
    for mode in MODES:
        if mode.id == mode_id:
            return mode.duplicate(true)
    return MODES[0].duplicate(true)

static func get_map(map_id: String) -> Dictionary:
    for game_map in MAPS:
        if game_map.id == map_id:
            return game_map.duplicate(true)
    return MAPS[0].duplicate(true)
