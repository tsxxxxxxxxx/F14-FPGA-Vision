import argparse
from pathlib import Path
import numpy as np
from baseline_f1 import savehex,packed
from f3_model import detect
from numpy.lib.stride_tricks import sliding_window_view
P=Path(__file__).resolve().parent
a=argparse.ArgumentParser();a.add_argument('--full',action='store_true');args=a.parse_args()
h,w,n=(1080,1920,2) if args.full else (64,96,8);yy,xx=np.indices((h,w));rng=np.random.default_rng(381)
frames=[];outputs=[];stages=[]
for k in range(n):
 y=40+((xx//12+yy//12+k)%2)*48 if k%2==0 else 35+120*(3*xx+2*yy>w*2)
 y=np.clip(y+rng.integers(-5,6,(h,w)),0,255);rgb=np.stack([y,np.clip(y+5*k,0,255),np.clip(y-7*k,0,255)],-1)
 gray=(rgb[:,:,0]*77+rgb[:,:,1]*150+rgb[:,:,2]*29+128)>>8
 s=detect(gray,16 if k==2 else 1024 if k==3 else 80);out=np.repeat((s['edge']*255)[:,:,None],3,2)
 if k%2==0:out[:,:w//2]=np.repeat(gray[:,:w//2,None],3,2)
 else:
  out=np.minimum(255,(rgb*np.array([394,256,351])+128)>>8)
  wide=s['edge'].copy()
  wide[1:-1,1:-1]=sliding_window_view(s['edge'],(3,3)).max(axis=(-1,-2))
  out[wide!=0]=np.array([0,255,255],dtype=np.uint8)
 frames.append(rgb);outputs.append(out);stages.append(s)
suffix='1080p' if args.full else 'small'
savehex(P/f'input_{suffix}.hex',[packed(v) for v in frames]);savehex(P/f'output_{suffix}.hex',[packed(v) for v in outputs])
if not args.full:
 for key in stages[0]:savehex(P/f'{key}_small.hex',[s[key] for s in stages])
print('F10 reference',w,h,n,'WB 394/256/351, centered 3x3 cyan overlay; raw-luma edges unchanged',flush=True)
