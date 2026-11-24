'use strict';
const http = require('node:http');
const crypto = require('node:crypto');
const { WebSocketServer, WebSocket } = require('ws');
const { WEAPONS, validateMovement, resolveShot } = require('./game_rules');

const PORT = Number(process.env.PORT || 8080);
const MAX_ROOMS = 80;
const MAX_PLAYERS = 16;
const SNAPSHOT_MS = 75;
const rooms = new Map();
const clients = new Map();
const server = http.createServer((req,res) => {
  const url = new URL(req.url,'http://localhost');
  res.setHeader('access-control-allow-origin','*');
  res.setHeader('access-control-allow-methods','GET, OPTIONS');
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
  if (url.pathname === '/health') {
    res.writeHead(200,{'content-type':'application/json'});
    return res.end(JSON.stringify({ok:true,service:'HAX_SHOOTING_ROOMS',rooms:rooms.size,clients:clients.size}));
  }
  if (url.pathname === '/api/rooms') {
    res.writeHead(200,{'content-type':'application/json'});
    return res.end(JSON.stringify({rooms:[...rooms.values()].map(publicRoom)}));
  }
  res.writeHead(200,{'content-type':'text/plain; charset=utf-8'});
  res.end('HAX SHOOTING room server. WebSocket endpoint: /ws');
});
const wss = new WebSocketServer({noServer:true,maxPayload:8192});
server.on('upgrade',(req,socket,head)=>{
  const pathname = new URL(req.url,'http://localhost').pathname;
  if (pathname !== '/ws') { socket.destroy(); return; }
  wss.handleUpgrade(req,socket,head,ws=>wss.emit('connection',ws,req));
});
function safeName(value) {
  return String(value || 'OPERATOR').replace(/[^\p{L}\p{N}_ -]/gu,'').trim().slice(0,18) || 'OPERATOR';
}
function makeCode() {
  const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code;
  do { code=Array.from(crypto.randomBytes(6),b=>alphabet[b%alphabet.length]).join(''); } while(rooms.has(code));
  return code;
}
function send(ws,data) { if(ws.readyState===WebSocket.OPEN) ws.send(JSON.stringify(data)); }
function pubPlayer(p) {
  return {id:p.id,name:p.name,position:p.position,yaw:p.yaw,pitch:p.pitch,health:p.health,armor:p.armor,weapon:p.weapon,ammo:p.ammo,reserve:p.reserve,kills:p.kills,deaths:p.deaths};
}
function publicRoom(room) {
  return {code:room.code,name:room.name,mode:room.mode,map:room.map,maxPlayers:room.maxPlayers,players:room.players.size,createdAt:room.createdAt};
}
function broadcast(room,data,except=null) {
  for(const p of room.players.values()) if(p.id!==except) send(p.socket,data);
}
function leave(client) {
  if(!client.roomCode) return;
  const room=rooms.get(client.roomCode);
  if(room) {
    room.players.delete(client.id);
    broadcast(room,{type:'player_left',id:client.id,players:room.players.size});
    if(room.players.size===0) rooms.delete(room.code);
  }
  client.roomCode=null;
}
function enter(client,room) {
  if(room.players.size>=room.maxPlayers) { send(client.socket,{type:'error',message:'ROOM FULL'}); return false; }
  leave(client);
  const p={id:client.id,name:client.name,socket:client.socket,position:{x:0,y:0,z:42},yaw:0,pitch:0,health:100,armor:75,weapon:'hax_ar',ammo:WEAPONS.hax_ar.mag,reserve:WEAPONS.hax_ar.reserve,lastMoveAt:Date.now(),lastShotAt:0,kills:0,deaths:0,respawnAt:0};
  room.players.set(client.id,p);
  client.roomCode=room.code;
  send(client.socket,{type:'room_joined',code:room.code,room:publicRoom(room),players:[...room.players.values()].map(pubPlayer)});
  broadcast(room,{type:'player_joined',player:pubPlayer(p),players:room.players.size},client.id);
  return true;
}
function handle(client,raw) {
  let m;
  try { m=JSON.parse(raw.toString()); } catch { return send(client.socket,{type:'error',message:'INVALID JSON'}); }
  if(!m || typeof m.type!=='string') return;
  const room=client.roomCode ? rooms.get(client.roomCode) : null;
  switch(m.type) {
    case 'hello':
      client.name=safeName(m.name);
      send(client.socket,{type:'server_ready',id:client.id,name:client.name,version:'1.0.0'});
      break;
    case 'create_room': {
      if(rooms.size>=MAX_ROOMS) return send(client.socket,{type:'error',message:'ROOM CAPACITY REACHED'});
      const code=makeCode();
      const r={code,name:safeName(m.roomName||'HAX PRIVATE ROOM'),mode:String(m.mode||'tdm').slice(0,24),map:String(m.map||'red_harbor').slice(0,24),maxPlayers:Math.max(2,Math.min(MAX_PLAYERS,Number(m.maxPlayers)||MAX_PLAYERS)),createdAt:new Date().toISOString(),players:new Map()};
      rooms.set(code,r);
      if(enter(client,r)) send(client.socket,{type:'room_created',code,room:publicRoom(r)});
      break;
    }
    case 'join_room': {
      const code=String(m.code||'').toUpperCase().replace(/[^A-Z0-9]/g,'').slice(0,10);
      const r=rooms.get(code);
      if(!r) return send(client.socket,{type:'error',message:'ROOM NOT FOUND'});
      enter(client,r);
      break;
    }
    case 'leave_room': leave(client); send(client.socket,{type:'left_room'}); break;
    case 'list_rooms':
      send(client.socket,{type:'rooms',rooms:[...rooms.values()].filter(r=>r.players.size<r.maxPlayers).map(publicRoom)});
      break;
    case 'state': {
      if(!room) return;
      const p=room.players.get(client.id);
      if(!p) return;
      const now=Date.now();
      const movement=validateMovement(p.position,m.position,(now-p.lastMoveAt)/1000);
      if(!movement.ok) return send(client.socket,{type:'state_rejected',reason:movement.reason,position:p.position});
      p.position=movement.position;
      if(Number.isFinite(m.yaw)) p.yaw=m.yaw;
      if(Number.isFinite(m.pitch)) p.pitch=Math.max(-1.45,Math.min(1.45,m.pitch));
      if(WEAPONS[m.weapon] && m.weapon!==p.weapon) { p.weapon=m.weapon; p.ammo=WEAPONS[p.weapon].mag; p.reserve=WEAPONS[p.weapon].reserve; }
      p.lastMoveAt=now;
      break;
    }
    case 'shoot': {
      if(!room) return;
      const shooter=room.players.get(client.id);
      if(!shooter) return;
      const result=resolveShot(shooter,[...room.players.values()],Date.now());
      if(!result.ok) return send(client.socket,{type:'shot_rejected',reason:result.reason});
      shooter.ammo=result.ammo; shooter.lastShotAt=Date.now();
      if(result.hit) {
        const target=room.players.get(result.targetId);
        if(target) {
          const absorbed=Math.min(target.armor,result.damage*.55);
          target.armor-=absorbed; target.health=Math.max(0,target.health-(result.damage-absorbed));
          if(target.health<=0) { target.deaths++; shooter.kills++; target.respawnAt=Date.now()+3000; }
          broadcast(room,{type:'match_event',event:'hit',shooterId:shooter.id,targetId:target.id,damage:result.damage,headshot:result.headshot,state:pubPlayer(target)});
        }
      }
      send(client.socket,{type:'shot_result',...result,ammo:shooter.ammo});
      break;
    }
    case 'reload': {
      if(!room) return;
      const p=room.players.get(client.id);
      if(p && WEAPONS[p.weapon]) {
        const amount=Math.min(WEAPONS[p.weapon].mag-p.ammo,p.reserve);
        p.ammo+=amount; p.reserve-=amount;
      }
      send(client.socket,{type:'reload_result',ammo:p?p.ammo:0,reserve:p?p.reserve:0});
      break;
    }
    case 'chat': {
      if(!room) return;
      const message=String(m.message||'').replace(/[\u0000-\u001f]/g,'').trim().slice(0,240);
      if(message) broadcast(room,{type:'chat',id:client.id,name:client.name,message});
      break;
    }
    case 'ping': send(client.socket,{type:'pong',at:Date.now()}); break;
    default: send(client.socket,{type:'error',message:'UNSUPPORTED MESSAGE TYPE'});
  }
}
wss.on('connection',(socket)=>{
  const client={id:crypto.randomUUID(),name:'OPERATOR',socket,roomCode:null,lastMessageAt:0,messageCount:0};
  clients.set(client.id,client);
  socket.on('message',raw=>{
    const now=Date.now();
    if(now-client.lastMessageAt>1000){client.lastMessageAt=now;client.messageCount=0;}
    if(++client.messageCount>100) return socket.close(1008,'RATE LIMIT');
    handle(client,raw);
  });
  socket.on('close',()=>{leave(client);clients.delete(client.id);});
  socket.on('error',()=>{leave(client);clients.delete(client.id);});
  send(socket,{type:'connected',id:client.id,server:'HAX SHOOTING'});
});
const timer=setInterval(()=>{
  for(const room of rooms.values()) {
    if(room.players.size===0) continue;
    for(const p of room.players.values()) {
      if(p.respawnAt && Date.now()>=p.respawnAt) { p.position={x:0,y:0,z:42};p.health=100;p.armor=75;p.respawnAt=0;broadcast(room,{type:'player_respawned',player:pubPlayer(p)}); }
    }
    const snapshot={type:'snapshot',code:room.code,players:[...room.players.values()].map(pubPlayer),at:Date.now()};
    broadcast(room,snapshot);
  }
},SNAPSHOT_MS);
server.listen(PORT,'0.0.0.0',()=>console.log('HAX SHOOTING room service on '+PORT));
function shutdown(){clearInterval(timer);for(const c of clients.values())c.socket.close(1001,'SERVER SHUTDOWN');server.close(()=>process.exit(0));setTimeout(()=>process.exit(0),2500).unref();}
process.on('SIGTERM',shutdown);
process.on('SIGINT',shutdown);
