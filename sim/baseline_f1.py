"""Independent integer reference for fixed clean F1. No HDL output as golden."""
from pathlib import Path
import argparse
import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as windows
P=Path(__file__).resolve().parent

def median(y):
 z=y.copy();z[1:-1,1:-1]=np.median(windows(y,(3,3)),axis=(-1,-2)).astype(np.int64);return z

def blur(y):
 w=windows(y,(3,3));z=y.copy()
 z[1:-1,1:-1]=(np.sum(w*np.array([[1,2,1],[2,4,2],[1,2,1]]),axis=(-1,-2))+8)>>4
 return z

def sobel(y):
 w=windows(y,(3,3));gx=w[:,:,0,2]+2*w[:,:,1,2]+w[:,:,2,2]-w[:,:,0,0]-2*w[:,:,1,0]-w[:,:,2,0]
 gy=w[:,:,2,0]+2*w[:,:,2,1]+w[:,:,2,2]-w[:,:,0,0]-2*w[:,:,0,1]-w[:,:,0,2]
 ax=np.abs(gx);ay=np.abs(gy)
 d=np.where(ay*1024<=ax*424,0,np.where(ax*1024<=ay*424,2,np.where((gx<0)^(gy<0),3,1)))
 z=np.zeros_like(y);z[1:-1,1:-1]=(d<<11)|(ax+ay);return z

def nms(gradient,threshold=80):
 mag=gradient&2047;dire=gradient>>11;w=windows(mag,(3,3));c=mag[1:-1,1:-1];d=dire[1:-1,1:-1]
 before=np.choose(d,[w[:,:,1,0],w[:,:,0,0],w[:,:,0,1],w[:,:,0,2]])
 after=np.choose(d,[w[:,:,1,2],w[:,:,2,2],w[:,:,2,1],w[:,:,2,0]])
 z=np.zeros_like(mag);z[1:-1,1:-1]=(c>before)&(c>=after)&(c>=threshold)
 z[:2,:]=0;z[-2:,:]=0;z[:,:2]=0;z[:,-2:]=0;return z

def clean(candidate):
 w=windows(candidate,(5,5));count=np.sum(w,axis=(-1,-2));c=w[:,:,2,2]
 near=np.sum(w[:,:,1:4,1:4],axis=(-1,-2))-c
 z=np.zeros_like(candidate);z[2:-2,2:-2]=(c!=0)&(count>=4)&(near>=1);return z

def process(rgb,overlay=False,threshold=80):
 rgb=rgb.astype(np.int64);y=(rgb[:,:,0]*77+rgb[:,:,1]*150+rgb[:,:,2]*29+128)>>8
 m=median(y);f=blur(m);grad=sobel(f);candidate=nms(grad,threshold);edge=clean(candidate)
 output=rgb.copy() if overlay else np.repeat(y[:,:,None],3,axis=2)
 if overlay:output[edge!=0]=[255,0,0]
 else:output[:,rgb.shape[1]//2:,:]=255*edge[:,rgb.shape[1]//2:,None]
 return dict(gray=y,median=m,filtered=f,gradient=grad,candidate=candidate,edge=edge,output=output)

def packed(rgb):return (rgb[:,:,0]<<16)|(rgb[:,:,1]<<8)|rgb[:,:,2]
def savehex(path,frames,width=6):
 with path.open('w') as f:
  for a in frames:np.savetxt(f,a.ravel(),fmt=f'%0{width}x')

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--full',action='store_true');a=ap.parse_args()
 h,w,nf=(1080,1920,2) if a.full else (64,96,6)
 yy,xx=np.indices((h,w));rng=np.random.default_rng(221061);frames=[];refs=[]
 thresholds=[80,80,16,1024,80,80]
 for k in range(nf):
  if k==0:y=40+((xx//max(6,w//12)+yy//max(6,h//8))%2)*150+rng.integers(-5,6,(h,w))
  elif k==1:y=35+120*(xx*3+yy*2>w*2)+rng.integers(-9,10,(h,w))
  elif k==2:y=rng.integers(0,256,(h,w))
  elif k==3:y=np.where(((xx//8)+(yy//8))%2,255,0)
  elif k==4:y=np.clip(140+rng.integers(-20,21,(h,w)),0,255)
  else:y=np.where(xx%20<10,254,0)
  y=np.clip(y,0,255);rgb=np.stack([y,np.clip(y+5*k,0,255),np.clip(y-7*k,0,255)],axis=-1)
  frames.append(rgb);refs.append(process(rgb,k%2,thresholds[k]))
 suffix='1080p' if a.full else 'small'
 savehex(P/f'input_{suffix}.hex',[packed(x) for x in frames]);savehex(P/f'output_{suffix}.hex',[packed(r['output']) for r in refs])
 if not a.full:
  for key in refs[0]:
   if key!='output':savehex(P/f'{key}_small.hex',[r[key] for r in refs])
 print('Reference generated fixed clean',w,h,nf,'edges',[int(r['edge'].sum()) for r in refs],flush=True)
if __name__=='__main__':main()
