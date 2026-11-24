'use strict';

const WEAPONS = Object.freeze({
  hax_ar:       { rpm: 690, damage: 27, head: 3.2, range: 115, mag: 30, reserve: 180 },
  viper_smg:    { rpm: 920, damage: 20, head: 3.0, range: 62,  mag: 36, reserve: 216 },
  kraken_12:    { rpm: 92,  damage: 12, head: 2.2, range: 24,  mag: 8, reserve: 56, pellets: 9 },
  phantom_aw:   { rpm: 48,  damage: 82, head: 4.0, range: 240, mag: 5, reserve: 40 },
  sentinel_p:   { rpm: 380, damage: 24, head: 3.0, range: 55,  mag: 15, reserve: 90 },
  reaper_dmr:   { rpm: 220, damage: 48, head: 3.4, range: 180, mag: 12, reserve: 84 }
});

function finiteVector(v) {
  return v && Number.isFinite(v.x) && Number.isFinite(v.y) && Number.isFinite(v.z);
}

function clampPosition(p, limit = 100) {
  return {
    x: Math.max(-limit, Math.min(limit, p.x)),
    y: Math.max(0, Math.min(4, p.y)),
    z: Math.max(-limit, Math.min(limit, p.z))
  };
}

function validateMovement(previous, next, elapsedSeconds, maxSpeed = 12.5) {
  if (!finiteVector(next)) return { ok: false, reason: 'invalid_position' };
  if (!previous) return { ok: true, position: clampPosition(next) };
  const dt = Math.max(0.025, Math.min(0.5, elapsedSeconds));
  const dx = next.x - previous.x;
  const dy = next.y - previous.y;
  const dz = next.z - previous.z;
  const distance = Math.hypot(dx, dy, dz);
  if (distance > maxSpeed * dt + 0.9) return { ok: false, reason: 'movement_speed_exceeded' };
  return { ok: true, position: clampPosition(next) };
}

function raySphereDistance(origin, direction, center, radius) {
  const ox = origin.x - center.x;
  const oy = origin.y - center.y;
  const oz = origin.z - center.z;
  const b = ox * direction.x + oy * direction.y + oz * direction.z;
  const c = ox * ox + oy * oy + oz * oz - radius * radius;
  const discriminant = b * b - c;
  if (discriminant < 0) return Infinity;
  const t = -b - Math.sqrt(discriminant);
  return t >= 0 ? t : Infinity;
}

function directionFromAngles(yaw, pitch) {
  const cp = Math.cos(pitch);
  // Godot Camera3D faces local -Z; yaw=0 therefore points toward world -Z.
  return {
    x: -Math.sin(yaw) * cp,
    y: Math.sin(pitch),
    z: -Math.cos(yaw) * cp
  };
}

function resolveShot(shooter, targets, nowMs) {
  const weapon = WEAPONS[shooter.weapon];
  if (!weapon) return { ok: false, reason: 'unknown_weapon' };
  const interval = 60000 / weapon.rpm;
  if (nowMs - (shooter.lastShotAt || 0) < interval * 0.88) return { ok: false, reason: 'fire_rate_exceeded' };
  if ((shooter.ammo ?? weapon.mag) <= 0) return { ok: false, reason: 'empty_magazine' };
  const origin = shooter.position && finiteVector(shooter.position) ? {x: shooter.position.x, y: shooter.position.y + 1.55, z: shooter.position.z} : null;
  if (!origin || !Number.isFinite(shooter.yaw) || !Number.isFinite(shooter.pitch)) return { ok: false, reason: 'invalid_aim' };
  const direction = directionFromAngles(shooter.yaw, shooter.pitch);
  let closest = null;
  let nearest = weapon.range;
  for (const target of targets) {
    if (target.id === shooter.id || target.health <= 0 || !finiteVector(target.position)) continue;
    const head = {x:target.position.x, y:target.position.y + 1.68, z:target.position.z};
    const body = {x:target.position.x, y:target.position.y + 1.05, z:target.position.z};
    const headT = raySphereDistance(origin, direction, head, 0.27);
    const bodyT = raySphereDistance(origin, direction, body, 0.54);
    const t = Math.min(headT, bodyT);
    if (t < nearest) {
      nearest = t;
      closest = { target, headshot: headT <= bodyT, distance: t };
    }
  }
  if (!closest) return { ok: true, ammo: shooter.ammo - 1, hit: false, damage: 0 };
  const raw = weapon.damage * (closest.headshot ? weapon.head : 1);
  return {
    ok: true,
    ammo: shooter.ammo - 1,
    hit: true,
    targetId: closest.target.id,
    headshot: closest.headshot,
    distance: Number(closest.distance.toFixed(2)),
    damage: Number(raw.toFixed(2))
  };
}

module.exports = { WEAPONS, finiteVector, clampPosition, validateMovement, raySphereDistance, directionFromAngles, resolveShot };
