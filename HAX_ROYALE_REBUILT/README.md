# HAX SHOOTING — BY: NACAR_22

This is the development area on branch `hax-shooting-dev` of the existing Nacer_22 repository. The branch contains the game project metadata, weapon/mode catalog, server-side combat rules and tests, Railway Docker configuration, deployment notes, and a GitHub Actions check for the committed server-rule subset.

**Important:** the complete native Godot project source tree and binary art/audio assets are delivered separately as the full source ZIP in this conversation. This GitHub branch is not yet a full mirror of every local GDScript and binary asset.

## Native project
- Godot 4.7.2 project metadata and Android export preset.
- Six weapon definitions, eight mode definitions, four maps and cosmetic catalog in `scripts/data/game_data.gd`.
- Android APK package ID: `com.nacar.haxshooting`.
- Full source ZIP includes GDScript gameplay files, scenes, GLB models, PBR maps, WAV effects, tools and docs.

## Room server
- Node.js 22 / WebSocket (`ws`) service.
- Room, movement, shot, head/body hit and fire-rate rules.
- Seven Node unit tests.
- Dockerfile and Railway service config in `server/`.

Run local server rules:
```sh
cd server
npm install
npm test
```

## CI
The repository workflow currently validates the server-rule subset committed to this branch. It does not claim that the full Godot scene has been built by GitHub Actions.

## Status / limitations
This is an Alpha development foundation, not a finished commercial AAA game. The included operator GLB meshes are static and not skeletal animated rigs. The room service is in-memory and is not production-ready for ranked play. LAN movement sync is an early prototype, Bluetooth is not implemented, and the online server has not been deployed. No Android APK was built or device-tested in this environment.

Brand: **HAX SHOOTING — BY: NACAR_22**.
