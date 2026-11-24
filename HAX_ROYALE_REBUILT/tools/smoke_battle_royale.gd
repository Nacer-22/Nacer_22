extends SceneTree

func _initialize() -> void:
    call_deferred("_run_smoke")

func _check(condition: bool, message: String) -> bool:
    if not condition:
        push_error("HAX_ROYALE_SMOKE_FAILED: " + message)
        quit(1)
        return false
    return true

func _run_smoke() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    if not _check(packed != null, "Main scene could not be loaded"):
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    if not _check(game.player != null, "Player node was not created"):
        return
    if not _check(game.player.get_node_or_null("ThirdPersonOperator") != null, "Third-person operator model container missing"):
        return
    if not _check(game.player.get_node_or_null("ShoulderCameraPivot") != null, "Shoulder camera pivot missing"):
        return
    if not _check(absf(game.player._spring_arm.rotation.y - PI) < 0.01, "Camera boom is not positioned behind operator"):
        return
    if not _check(game.player.lobby_showcase, "3D lobby showcase pose is not active"):
        return
    if not _check(game._lobby_stage != null and game._lobby_stage.visible, "3D lobby stage is missing"):
        return
    if not _check(game.map_factory.map_id == "island", "HAX Island was not loaded for the lobby"):
        return

    game._start_match("battle_royale", "island")
    await process_frame
    await create_timer(0.65).timeout

    if not _check(game.is_match_active, "Battle Royale did not start"):
        return
    if not _check(game.current_mode == "battle_royale", "Wrong playlist selected"):
        return
    if not _check(game.map_factory.map_id == "island", "Battle Royale map mismatch"):
        return
    if not _check(game.player != null and not game.player.lobby_showcase, "Player did not leave lobby camera mode"):
        return
    if not _check(game._bots.size() == 15, "Battle Royale must spawn 15 AI operators plus the player"):
        return
    if not _check(game._loot_nodes.size() >= 18, "Battle Royale loot crates did not spawn"):
        return
    if not _check(game.get_node_or_null("HAX_SAFE_ZONE") != null, "Safe zone ring missing"):
        return
    if not _check(game.nav_grid != null, "AI navigation grid missing"):
        return
    if not _check(game.player.aim_assist_enabled, "Aim assist is disabled"):
        return
    if not _check(game.player.weapon_data.id == "hax_ar", "Assault rifle was not equipped"):
        return
    if not _check(game.player._weapon_visual != null and game.player._weapon_visual.get_child_count() > 0, "Weapon 3D model was not attached"):
        return

    var team_counts: Dictionary = {}
    for bot in game._bots:
        team_counts[bot.team_id] = int(team_counts.get(bot.team_id, 0)) + 1
        if not _check(bot.target != null, "Bot did not select a target"):
            return
        if not _check(bot.global_position.distance_to(game.player.global_position) > 2.0, "Bot spawned on top of the player"):
            return
    if not _check(team_counts.size() >= 2, "Battle Royale AI squads were not created"):
        return

    print("HAX_ROYALE_SMOKE_OK")
    print("map=island mode=battle_royale player=third_person bots=%d loot=%d teams=%d" % [game._bots.size(), game._loot_nodes.size(), team_counts.size()])
    quit(0)
