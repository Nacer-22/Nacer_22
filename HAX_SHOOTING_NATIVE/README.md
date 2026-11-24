# HAX SHOOTING — BY: NACAR_22

Native 3D FPS project built with Godot 4.7.2, plus a separate Node.js WebSocket room service.

## Included gameplay systems
- First-person 3D player controller with mobile touch controls, sprint, jump, crouch, reload and six weapons.
- Four procedural arenas and eight match modes.
- Bot navigation using AStarGrid2D, obstacle re-planning and distance-based combat behavior.
- Respawn resets player world rotation and camera pitch to prevent the round-transition inversion bug.
- Separate head/body hit areas; headshots use a weapon-specific damage multiplier.
- Local cosmetics, weapon selection, credits, profile saving and adjustable aim assist.
- LAN session scaffold using Godot ENet over UDP, and internet room client using WebSocket JSON.
- Six original GLB weapon meshes, three operator GLB meshes, PBR texture maps and generated SFX live in the downloadable source package.

## Build
Install Godot 4.7.2 and Android export templates. For Android, configure OpenJDK 17 and Android SDK Platform 35, Build Tools 35.0.1, NDK r28b. Open `project.godot`, then Project > Export > Android APK.

## Room service
```sh
cd server
npm install
npm test
npm start
```
Set `HAX_SERVER_URL` to the deployed WebSocket endpoint ending in `/ws`.

## Validation
The server rule suite currently has 7 passing Node tests for movement bounds/speed, ray-sphere hit tests, Godot -Z yaw convention, headshot multiplier and fire-rate constraints.

## Alpha status / honest limitations
This is an original playable development foundation, not yet a commercial AAA game. The GLB operators are custom static meshes, not fully rigged/mocap characters. The server is in-memory, single-process and not production-ready for ranked play; line-of-sight, persistent accounts/inventory, anti-cheat telemetry, matchmaking scale and load testing remain. LAN uses Wi-Fi/Ethernet ENet; Bluetooth is not implemented. No APK was built or device-tested in this environment.

Full project archive and all art/audio/binary assets are delivered separately in the conversation's source ZIP.
