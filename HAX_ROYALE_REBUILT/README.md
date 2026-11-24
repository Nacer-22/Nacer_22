# HAX SHOOTING ROYALE — BY: NACAR_22

Independent Android game project rebuilt under `HAX_ROYALE_REBUILT/`.

**Identity:** HAX SHOOTING ROYALE  
**Author branding:** BY: NACAR_22  
**Version:** 1.0.0  
**Android application ID:** `com.nacar.haxroyale`  
**Engine:** Godot 4.7.2  
**Target:** Android ARM64 + ARM32, landscape orientation

## Gameplay in this rebuild

- Third-person over-the-shoulder camera and a visible operator model, with a 3D operator showcase stage in the lobby.
- HAX Island battle-royale map plus Red Harbor, Dust Front, Night City and Frostline playlists/maps.
- Fifteen AI opponents in the offline Battle Royale match (sixteen operators including the player), with squad teams, bot-vs-bot engagements, navigation obstacle handling, and a shrinking storm.
- Loot pickups for ammunition, medkits, armor and weapon changes, plus a timed supply drop.
- Six weapon families with generated 3D models, fire/reload handling, spread/recoil, head/body hit zones and configurable aim assist.
- Operator outfits and weapon finishes, local saved credits/XP/rank progression, and interactive menu/loadout/settings screens.
- Landscape mobile controls: left virtual joystick, right-side camera swipe, fire, aim, reload, jump, crouch, sprint, weapon swap and pause.
- Other offline playlists: team deathmatch, free-for-all, domination, sniper, zombies, training and ranked arena.

## Build

The CI workflow generates the character/weapon meshes, audio and PBR textures, imports the Godot project, runs headless startup and a full Battle Royale smoke test, exports an Android APK, signs it with a temporary CI test key, verifies the signature, and uploads the APK and source archive.

Required local tools: Godot 4.7.2 export templates, JDK 17, Android Platform 35, Build Tools 35.0.1, NDK 28.1.13356709, Python dependencies from `tools/requirements.txt`.

## Multiplayer and networking limits

- The game contains WebSocket room-server and LAN/Wi-Fi session code. The online server URL is intentionally blank until the room service can be deployed and configured.
- Railway rejected a new service/project because the connected workspace reached its free-plan resource provisioning limit; the existing website service was not modified.
- LAN uses ENet over the local Wi-Fi/Ethernet network. This is not Bluetooth support.
- Native Bluetooth multiplayer is not implemented.
- Online rooms, synchronized combat and remote player presentation still require live-device multi-client QA before being described as production-ready.
- No claim is made that this is feature-equivalent to Free Fire or PUBG, or that its visual fidelity is AAA.

## Licensing and attribution

The project retains the upstream license/credits for the code and assets it uses. See `hax/credits.md` where present and the source repository attribution. Generated project-specific assets are part of the game project; do not redistribute third-party assets as a separate asset pack.

## Current validation scope

CI checks project import, headless startup, scripted third-person lobby state, map/match setup, AI count, loot, safe-zone and weapon state, and Android export/signature. It does not substitute for testing on actual Android devices, checking FPS/thermal performance, or live online/Bluetooth multiplayer sessions.
