#!/usr/bin/env python3
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"assets/textures/hires"
SIZE=2048
LOW=1024
def material(name,base,seed):
 rng=np.random.default_rng(seed); y,x=np.mgrid[0:SIZE,0:SIZE]
 noise=rng.normal(0,13,(SIZE,SIZE))+7*np.sin(x/37)+5*np.cos(y/51)+3*np.sin((x+y)/19)
 rgb=np.stack([np.clip(base[c]+noise,0,255) for c in range(3)],axis=-1).astype(np.uint8)
 OUT.mkdir(parents=True,exist_ok=True)
 Image.fromarray(rgb,"RGB").save(OUT/f"{name}_albedo_2k.jpg",quality=94,subsampling=0)
 gx=np.gradient(noise,axis=1); gy=np.gradient(noise,axis=0)
 norm=np.stack([-gx*1.5+128,-gy*1.5+128,np.full_like(gx,245)],axis=-1)
 Image.fromarray(np.clip(norm,0,255).astype(np.uint8),"RGB").resize((LOW,LOW),Image.Resampling.LANCZOS).save(OUT/f"{name}_normal.png",optimize=True)
 local=np.random.default_rng(seed+50)
 Image.fromarray(np.clip(170+local.normal(0,28,(LOW,LOW)),55,245).astype(np.uint8),"L").save(OUT/f"{name}_roughness.png",optimize=True)
 Image.fromarray(np.clip(230-local.random((LOW,LOW))*55,100,255).astype(np.uint8),"L").save(OUT/f"{name}_ao.png",optimize=True)
def main():
 for name,base,seed in [("concrete",(91,94,101),1),("armor-metal",(55,65,78),2),("floor",(52,56,63),3),("tactical-fabric",(39,44,55),4)]: material(name,base,seed)
if __name__=="__main__": main()
