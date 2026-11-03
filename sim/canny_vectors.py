"""Independent BFS oracle for exact 8-connected, full-frame Canny hysteresis."""
from pathlib import Path
from collections import deque
import json, sys
import numpy as np
R=Path(__file__).resolve().parent.parent
full="--full" in sys.argv
W,H=(1920,1080) if full else (256,64)
rng=np.random.default_rng(1401080)
cases=[]
def add(name,a):cases.append((name,a.copy()))
z=np.zeros((H,W),dtype=np.uint8)
add("empty",z)
a=z.copy();a[H//2,1:W-1]=1;a[H//2,W//2]=3;add("long_weak_horizontal",a)
a=z.copy();a[1:H-1,W//2]=1;a[H-2,W//2]=3;add("bottom_seed_vertical",a)
a=z.copy()
for y in range(2,H-2,4):
 a[y,2:W-2]=1
 if y+4<H-2:a[y:y+5,W-3 if (y//4)%2==0 else 2]=1
a[2,2]=3;add("serpentine_requires_many_sweeps",a)
a=z.copy()
for y in range(1,H-1):a[y,y%W]=1
a[1,1]=3;add("diagonal_only_connectivity",a)
a=z.copy();a[H//2,1:W-1]=1;add("weak_without_seed_rejected",a)
a=z.copy();a[H//2,1:W-1]=1;a[H//2,1]=3;a[H//2,W//2]=0;add("gap_must_not_be_bridged",a)
a=z.copy();a[0,:]=1;a[-1,:]=1;a[:,0]=1;a[:,-1]=1;a[0,0]=3;add("all_frame_boundaries",a)
a=z.copy();a[1,-1]=3;a[2,0]=1;add("no_row_wrap_connection",a)
a=z.copy();a[:]=1;a[H//2,W//2]=3;add("dense_component",a)
if full:
 cases=[cases[i] for i in [0,1,2,4,6,9]]
if not full:
 for k in range(20):
  a=(rng.random((H,W))<(.12+.035*k)).astype(np.uint8)
  a[rng.random((H,W))<.004]=3;add("random_"+str(k),a)
def oracle(a):
 b=a.copy();q=deque(zip(*np.nonzero(b==3)))
 while q:
  y,x=q.popleft()
  for yy in range(max(0,y-1),min(H,y+2)):
   for xx in range(max(0,x-1),min(W,x+2)):
    if b[yy,xx]==1:b[yy,xx]=3;q.append((yy,xx))
 return b
def pack(a):
 a=a.ravel()
 for i in range(0,len(a),64):yield f'{sum(int(v)<<(2*k) for k,v in enumerate(a[i:i+64])):032x}\n'
suffix="full" if full else "small"
with (R/f"sim/canny_input_{suffix}.hex").open("w") as f,(R/f"sim/canny_expected_{suffix}.hex").open("w") as g:
 for name,a in cases:
  f.writelines(pack(a));g.writelines(pack(oracle(a)))
(R/f"evidence/canny_cases_{suffix}.json").write_text(json.dumps(dict(width=W,height=H,cases=[n for n,a in cases]),indent=2))
print(f"Prepared {len(cases)} {W}x{H} BFS oracle cases",flush=True)
