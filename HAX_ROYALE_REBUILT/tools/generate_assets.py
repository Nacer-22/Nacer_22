#!/usr/bin/env python3
"""Generate HAX SHOOTING GLB models and original short SFX."""
from pathlib import Path
import math, wave, struct
import numpy as np
import trimesh

ROOT=Path(__file__).resolve().parents[1]
A=ROOT/"assets"
COL={"armor":(24,29,39,255),"fabric":(37,42,53,255),"plate":(56,64,77,255),"red":(205,18,49,255),"glow":(255,38,73,255),"steel":(116,129,145,255),"black":(8,11,17,255),"rubber":(16,18,22,255),"gold":(181,133,39,255),"sand":(137,108,70,255),"ice":(126,174,202,255),"toxic":(90,181,73,255)}
class Model:
 def __init__(self): self.scene=trimesh.Scene(); self.i=0
 def add(self,mesh,name,color="armor",metal=.2,rough=.6,pos=(0,0,0),rot=None):
  if rot: mesh.apply_transform(trimesh.transformations.euler_matrix(*rot,axes="sxyz"))
  mesh.apply_translation(pos); c=COL[color]
  mesh.visual=trimesh.visual.TextureVisuals(material=trimesh.visual.material.PBRMaterial(name="hax_"+color,baseColorFactor=c,metallicFactor=metal,roughnessFactor=rough))
  self.scene.add_geometry(mesh,geom_name=name,node_name=f"node_{name}_{self.i}"); self.i+=1
 def box(self,n,s,p,c="armor",metal=.2,rough=.6): self.add(trimesh.creation.box(extents=s),n,c,metal,rough,p)
 def sphere(self,n,r,p,c="armor",scale=(1,1,1)):
  x=trimesh.creation.icosphere(subdivisions=2,radius=r); x.apply_scale(scale); self.add(x,n,c,.2,.62,p)
 def cyl(self,n,r,h,p,c="steel"): self.add(trimesh.creation.cylinder(radius=r,height=h,sections=24),n,c,.7,.32,p)
 def save(self,p):
  p.parent.mkdir(parents=True,exist_ok=True); self.scene.export(p,file_type="glb"); print(p,p.stat().st_size)
def operator(path,variant):
 m=Model(); accent={"nacar":"red","arctic":"ice","toxic":"toxic"}[variant]; fabric={"nacar":"fabric","arctic":"ice","toxic":"sand"}[variant]
 for x,side in [(-.16,"L"),(.16,"R")]:
  m.box("boot_"+side,(.25,.16,.38),(x,.11,-.025),"rubber"); m.box("shin_"+side,(.20,.24,.08),(x,.43,-.095),"plate",.5,.4)
  m.add(trimesh.creation.capsule(height=.46,radius=.105),"calf_"+side,fabric,.12,.8,(x,.43,0))
  m.add(trimesh.creation.capsule(height=.43,radius=.13),"thigh_"+side,"armor",.1,.7,(x,.78,0))
  m.box("knee_"+side,(.21,.18,.12),(x,.60,-.105),accent,.35,.43)
  m.box("pouch_"+side,(.13,.15,.12),(x*1.8,.91,-.12),fabric)
 m.box("pelvis",(.44,.29,.28),(0,1.02,0)); m.sphere("torso",.32,(0,1.43,0),fabric,(1.23,1.25,.82))
 m.box("chest_plate",(.57,.55,.17),(0,1.48,-.15),"plate",.4,.45); m.box("vest",(.55,.49,.13),(0,1.43,-.26),fabric)
 for i,x in enumerate([-.20,-.07,.07,.20]): m.box(f"mag_{i}",(.105,.16,.085),(x,1.37,-.345),"armor"); m.box(f"mag_latch_{i}",(.09,.025,.02),(x,1.45,-.392),accent)
 for x,side in [(-.4,"L"),(.4,"R")]:
  m.sphere("shoulder_"+side,.16,(x,1.68,0),"plate",(1.15,.9,1))
  m.add(trimesh.creation.capsule(height=.34,radius=.105),"arm_"+side,fabric,.1,.8,(x*1.18,1.42,.01))
  m.add(trimesh.creation.capsule(height=.34,radius=.095),"forearm_"+side,"armor",.1,.7,(x*1.23,1,-.02))
  m.box("wrist_"+side,(.18,.1,.19),(x*1.23,.84,-.02),accent)
 m.cyl("neck",.105,.17,(0,1.86,0),"rubber"); m.sphere("head",.18,(0,2.08,-.01),"sand",(.93,1.12,.92))
 m.box("mask",(.28,.18,.13),(0,2.01,-.15)); m.box("eyeL",(.085,.035,.022),(-.075,2.12,-.177),"glow",.1,.18); m.box("eyeR",(.085,.035,.022),(.075,2.12,-.177),"glow",.1,.18)
 m.sphere("helmet",.23,(0,2.23,.02),"armor",(1.16,.72,1)); m.box("visor",(.35,.065,.035),(0,2.15,-.205),accent,.45,.18)
 m.box("backpack",(.42,.51,.2),(0,1.48,.22)); m.box("pack_top",(.32,.11,.22),(0,1.78,.22),accent); m.save(path)
def weapon(path,kind):
 m=Model(); m.box("receiver",(.15,.14,.43),(0,0,-.06),"armor",.68,.32); m.box("upper",(.13,.045,.35),(0,.08,-.1),"steel",.75,.27)
 m.box("handguard",(.13,.12,.33),(0,.01,-.43),"plate",.55,.38); m.box("rail",(.06,.035,.48),(0,.12,-.25),"black",.7,.28)
 m.box("grip",(.105,.24,.13),(0,-.17,.08),"rubber"); m.box("stock",(.13,.13,.28),(0,.01,.28),"rubber")
 m.cyl("barrel",.028,.55,(0,.015,-.79)); m.cyl("muzzle",.04,.1,(0,.015,-1.08),"black")
 if kind=="sniper": m.box("scope",(.1,.14,.34),(0,.22,-.22),"black",.75,.18); m.cyl("scope_lens",.064,.018,(0,.22,-.4),"ice")
 elif kind=="shotgun": m.cyl("tube",.042,.8,(0,.02,-.77)); m.cyl("under_tube",.036,.52,(0,-.09,-.65),"black"); m.box("pump",(.17,.1,.22),(0,-.075,-.55),"fabric")
 else:
  m.box("magazine",(.1,.26,.14),(0,-.18,-.12),"black")
  for z in [-.18,-.12,-.06,0]: m.box("mag_ridge_"+str(z),(.11,.018,.145),(0,-.18,z),"steel")
 m.box("skin_panel",(.08,.045,.16),(.078,.055,-.15),"red",.42,.28)
 for side in [-1,1]:
  m.box("side_rail_"+str(side),(.035,.04,.29),(side*.085,.025,-.42),"steel",.7,.35)
  for n in range(3): m.sphere(f"bolt_{side}_{n}",.012,(side*.083,.07,-.30-n*.09),"gold")
 m.save(path)
def audio(path,kind,seed):
 rng=np.random.default_rng(seed); rate=44100; length={"rifle":.22,"smg":.16,"shotgun":.42,"sniper":.55,"pistol":.20,"reload":.14,"headshot":.16,"ui":.07}[kind]
 n=int(rate*length); t=np.arange(n)/rate; noise=rng.normal(0,1,n)
 if kind in ("reload","ui"): data=np.sin(2*np.pi*(850 if kind=="ui" else 420)*t)*np.exp(-t*18)*.55+noise*np.exp(-t*18)*.02
 elif kind=="headshot": data=(np.sin(2*np.pi*(1100-700*t)*t)*.55+noise*.22)*np.exp(-t*14)
 else:
  env=np.exp(-t*({"shotgun":7,"sniper":8}.get(kind,15))); data=(noise*.56+np.sin(2*np.pi*85*t)*.65)*env
  if kind=="sniper": data+=np.sin(2*np.pi*58*t)*np.exp(-t*4)*.3
 data=np.clip(data*.82,-1,1); path.parent.mkdir(parents=True,exist_ok=True)
 with wave.open(str(path),"wb") as f:
  f.setnchannels(1); f.setsampwidth(2); f.setframerate(rate); f.writeframes(b"".join(struct.pack("<h",int(v*32767)) for v in data))
def main():
 for n,v in [("operator_nacar","nacar"),("operator_arctic","arctic"),("operator_toxic","toxic")]: operator(A/"models/operators"/(n+".glb"),v)
 for n,k in [("hax_ar","rifle"),("viper_smg","smg"),("kraken_12","shotgun"),("phantom_aw","sniper"),("sentinel_p","pistol"),("reaper_dmr","rifle")]: weapon(A/"models/weapons"/(n+".glb"),k)
 for i,k in enumerate(["rifle","smg","shotgun","sniper","pistol","reload","headshot","ui"]):
  fn={"reload":"reload_click","headshot":"headshot","ui":"ui_click"}.get(k,k+"_shot"); audio(A/"audio"/(fn+".wav"),k,20261124+i)
if __name__=="__main__": main()
