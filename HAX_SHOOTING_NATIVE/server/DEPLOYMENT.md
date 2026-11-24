# HAX SHOOTING Room Server — Deployment

Railway root directory: HAX_SHOOTING_NATIVE/server

- Dockerfile-based Node 22 deployment.
- HTTP health endpoint: /health
- WebSocket endpoint: /ws
- Room discovery: /api/rooms
- Set the public WebSocket URL to wss://YOUR-DOMAIN/ws in Godot Project Settings > hax/online_server_url.
- Never put game server variables in subscription services.

Alpha limitations: room state is in-memory, with no durable accounts, regional matchmaking or production anti-cheat. Use only for controlled testing.
