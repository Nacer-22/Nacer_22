extends SceneTree

func _initialize() -> void:
    call_deferred("_run_smoke")

func _run_smoke() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    assert(packed != null, "Main scene could not be loaded")
    var game := packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    assert(game.player != null, "Player node was not created")
    assert(game.player.get_node_or_null("ThirdPersonOperator") != null, "Third-person operator model container missing")
    assert(game.player.get_node_or_null("ShoulderCameraPivot") != null, "Shoulder camera pivot missing")
    assert(absf(game.player._spring_arm.rotation.y - PI) < 0.01, "Camera boom is not positioned behind operator")
    assert(game.player.lobby_showcase, "3D lobby showcase pose is not active")
    assert(game._lobby_stage != null and game._lobby_stage.visible, "3D lobby stage is missing")
    assert(game.map_factory.map_id == "island", "HAX Island was not loaded for the lobby")

    game._start_match("battle_royale", "island")
    await process_frame
    await create_timer(0.65).timeout

    assert(game.is_match_active, "Battle Royale did not start")
    assert(game.current_mode == "battle_royale", "Wrong playlist selected")
    assert(game.map_factory.map_id == "island", "Battle Royale map mismatch")
    assert(game.player != null and not game.player.lobby_showcase, "Player did not leave lobby camera mode")
    assert(game._bots.size() == 15, "Battle Royale must spawn 15 AI operators plus the player")
    assert(game._loot_nodes.size() >= 18, "Battle Royale loot crates did not spawn")
    assert(game.get_node_or_null("HAX_SAFE_ZONE") != null, "Safe zone ring missing")
    assert(game.nav_grid != null, "AI navigation grid missing")
    assert(game.player.aim_assist_enabled, "Aim assist is disabled")
    assert(game.player.weapon_data.id == "hax_ar", "Assault rifle was not equipped")
    assert(game.player._weapon_visual != null and game.player._weapon_visual.get_child_count() > 0, "Weapon 3D model was not attached")

    var team_counts: Dictionary = {}
    for bot in game._bots:
        team_counts[bot.team_id] = int(team_counts.get(bot.team_id, 0)) + 1
        assert(bot.target != null, "Bot did not select a target")
        assert(bot.global_position.distance_to(game.player.global_position) > 2.0, "Bot spawned on top of the player")
    assert(team_counts.size() >= 2, "Battle Royale AI squads were not created")

    print("HAX_ROYALE_SMOKE_OK")
    print("map=island mode=battle_royale player=third_person bots=%d loot=%d teams=%d" % [game._bots.size(), game._loot_nodes.size(), team_counts.size()])
    quit(0)
