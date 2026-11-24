'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { validateMovement, raySphereDistance, resolveShot, directionFromAngles } = require('../src/game_rules');

test('accepts normal movement and clamps play area', () => {
  const result = validateMovement({x:0,y:0,z:0}, {x:1,y:0,z:0}, 0.1);
  assert.equal(result.ok, true);
  assert.equal(result.position.x, 1);
  const clamped = validateMovement(null, {x:1000,y:100,z:-1000}, 0.1);
  assert.equal(clamped.position.x, 58);
  assert.equal(clamped.position.y, 4);
  assert.equal(clamped.position.z, -58);
});

test('rejects a teleport or excessive movement speed', () => {
  const result = validateMovement({x:0,y:0,z:0}, {x:20,y:0,z:0}, 0.05);
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'movement_speed_exceeded');
});

test('ray sphere intersection returns first forward distance', () => {
  const t = raySphereDistance({x:0,y:0,z:0}, {x:0,y:0,z:1}, {x:0,y:0,z:10}, 1);
  assert.equal(t, 9);
  const miss = raySphereDistance({x:0,y:0,z:0}, {x:0,y:0,z:1}, {x:4,y:0,z:10}, 1);
  assert.equal(miss, Infinity);
});

test('authoritative shot registers target and headshot multiplier', () => {
  const shooter = {id:'p1', position:{x:0,y:0,z:0}, yaw:0, pitch:0, weapon:'hax_ar', ammo:30, lastShotAt:0};
  const target = {id:'p2', position:{x:0,y:0,z:-10}, health:100};
  const result = resolveShot(shooter, [shooter,target], 250);
  assert.equal(result.ok, true);
  assert.equal(result.hit, true);
  assert.equal(result.targetId, 'p2');
  assert.equal(result.headshot, true);
  assert.ok(result.damage > 80);
});

test('rejects unknown weapons and rate-of-fire abuse', () => {
  const shooter = {id:'p1', position:{x:0,y:0,z:0}, yaw:0, pitch:0, weapon:'unknown', ammo:10, lastShotAt:0};
  assert.equal(resolveShot(shooter, [shooter], 300).reason, 'unknown_weapon');
  shooter.weapon = 'hax_ar';
  shooter.lastShotAt = 295;
  assert.equal(resolveShot(shooter, [shooter], 300).reason, 'fire_rate_exceeded');
});

test('Godot yaw zero points down negative Z, matching Camera3D forward', () => {
  const d = directionFromAngles(0, 0);
  assert.ok(Math.abs(d.x) < 1e-9);
  assert.ok(Math.abs(d.z + 1) < 1e-9);
});

test('headshot multiplier is applied without a hidden damage penalty', () => {
  const shooter = {id:'p1', position:{x:0,y:0,z:0}, yaw:0, pitch:0, weapon:'hax_ar', ammo:30, lastShotAt:0};
  const target = {id:'p2', position:{x:0,y:0,z:-10}, health:100};
  const result = resolveShot(shooter, [shooter,target], 250);
  assert.equal(result.ok, true);
  assert.equal(result.hit, true);
  assert.equal(result.headshot, true);
  assert.equal(result.damage, 27 * 3.2);
});
