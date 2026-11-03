"""F2 integer algorithm reference. Independent of RTL outputs; reused Sobel F1.

No brightness adaptation, frame iteration, or fabricated gap filling.
Token layout: robust[5], direction[4:3], agreement[2], strong/accepted[1], candidate[0].
"""
from pathlib import Path
import argparse
import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as windows
from baseline_f1 import sobel as sobel_f1, packed, savehex
P = Path(__file__).resolve().parent

def sobel(y):
    z=sobel_f1(y);w=windows(y,(3,3))
    gx=w[:,:,0,2]+2*w[:,:,1,2]+w[:,:,2,2]-w[:,:,0,0]-2*w[:,:,1,0]-w[:,:,2,0]
    gy=w[:,:,2,0]+2*w[:,:,2,1]+w[:,:,2,2]-w[:,:,0,0]-2*w[:,:,0,1]-w[:,:,0,2]
    d=z[1:-1,1:-1]>>11
    flip=np.where(d==2,gy<0,np.where(d==3,gx>=0,gx<0))
    z[1:-1,1:-1]|=flip.astype(np.int64)<<13
    return z

def selective_median(y):
    w = windows(y, (3, 3)); c = w[:, :, 1, 1]
    med = np.median(w, axis=(-1, -2)).astype(np.int64)
    near = np.abs(w - c[:, :, None, None]) <= 8
    support = near.sum(axis=(-1, -2)) - 1
    # Keep a thin line/corner when at least two neighbours support the center.
    # Otherwise use the median, including low-amplitude flat-field noise.
    protect = (np.abs(c - med) >= 12) & (support >= 2)
    z = y.copy(); z[1:-1, 1:-1] = np.where(protect, c, med)
    return z

def range_filter(y):
    # Existing V3 quantized range-filter arithmetic, constant enable/no noise path.
    w = windows(y, (3, 3)); c = w[:, :, 1, 1]
    total = c * 16; count = np.full_like(c, 16)
    for iy, ix in ((0,0),(0,1),(0,2),(1,0),(1,2),(2,0),(2,1),(2,2)):
        p = w[:, :, iy, ix]; delta = np.abs(p-c)
        rw = np.where(delta<=8, 4, np.where(delta<=16, 2, np.where(delta<=32, 1, 0)))
        weight = rw * (2 if (iy==1 or ix==1) else 1)
        total += p*weight; count += weight
    z=y.copy(); z[1:-1,1:-1]=np.minimum(255,(total*(65536//count)+32768)>>16)
    return z

def dual_nms(detail, stable, threshold=80):
    dm=detail&2047; sm=stable&2047; dr=(detail>>11)&3
    dw=windows(dm,(3,3)); sw=windows(sm,(3,3))
    c=dm[1:-1,1:-1]; d=dr[1:-1,1:-1]
    before=np.choose(d,[dw[:,:,1,0],dw[:,:,0,0],dw[:,:,0,1],dw[:,:,0,2]])
    after=np.choose(d,[dw[:,:,1,2],dw[:,:,2,2],dw[:,:,2,1],dw[:,:,2,0]])
    sb=np.choose(d,[sw[:,:,1,0],sw[:,:,0,0],sw[:,:,0,1],sw[:,:,0,2]])
    sa=np.choose(d,[sw[:,:,1,2],sw[:,:,2,2],sw[:,:,2,1],sw[:,:,2,0]])
    support=np.maximum(sw[:,:,1,1],np.maximum(sb,sa))
    low=(threshold>>1)+(threshold>>2)
    candidate=(c>before)&(c>=after)&(c>=low)&(support>=(low>>1))
    strong=candidate&(c>=threshold)&(support>=threshold)
    robust=candidate&(c>=2*threshold)&(support>=(threshold+(threshold>>1)))
    agree=candidate&(support>=low)
    z=np.zeros_like(dm)
    polarity=((detail[1:-1,1:-1]>>13)&1)<<6
    z[1:-1,1:-1]=np.where(candidate,polarity|(robust.astype(np.int64)<<5)|(d<<3)|(agree.astype(np.int64)<<2)|(strong.astype(np.int64)<<1)|1,0)
    z[:2,:]=0;z[-2:,:]=0;z[:,:2]=0;z[:,-2:]=0
    return z

# Tangent-facing fans for normal directions 0,45,90,135 degrees.
FORWARD=((0,1,2),(1,2,5),(0,3,6),(0,1,3))
BACKWARD=((6,7,8),(3,6,7),(2,5,8),(5,7,8))

def support_stage(tokens, seed=False, qualify=False):
    w=windows(tokens,(3,3)).reshape(tokens.shape[0]-2,tokens.shape[1]-2,9)
    c=w[:,:,4]; d=(c>>3)&3
    orientation=((w>>3)&3)|((w>>4)&4);ori=((c>>3)&3)|((c>>4)&4)
    diff=(orientation-ori[:,:,None])&7
    good=((w&1)!=0)&((diff==0)|(diff==1)|(diff==7))
    aligned=good&((w&4)!=0)&(diff==0)
    accepted=good&((w&2)!=0)
    forward=np.zeros_like(c,dtype=bool); backward=forward.copy(); adjacent=forward.copy(); link=forward.copy()
    for direction in range(4):
        f=FORWARD[direction]; b=BACKWARD[direction]; mask=d==direction
        forward |= mask & np.any(aligned[:,:,f],axis=-1)
        backward |= mask & np.any(aligned[:,:,b],axis=-1)
        adjacent |= mask & np.any(good[:,:,f+b],axis=-1)
        link |= mask & np.any(accepted[:,:,f+b],axis=-1)
    if qualify:
        keep=((c&4)!=0)&forward&backward
        z=np.zeros_like(tokens)
        z[1:-1,1:-1]=np.where((c&1)!=0,(c&123)|(keep.astype(np.int64)<<2),0)
        return z
    if seed:
        keep=(((c&32)!=0)&link)|(((c&4)!=0)&forward&backward)
    else:
        keep=((c&2)!=0)|link
    z=np.zeros_like(tokens)
    z[1:-1,1:-1]=np.where((c&1)!=0,(c&125)|(keep.astype(np.int64)<<1),0)
    return z

def detect(y, threshold=80):
    m=selective_median(y); f=range_filter(m)
    gd=sobel(m); gs=sobel(f); token=dual_nms(gd,gs,threshold)
    qualified=support_stage(token,qualify=True)
    seed=support_stage(qualified,True); link1=support_stage(seed); link2=support_stage(link1)
    link3=support_stage(link2); linked=support_stage(link3)
    edge=(linked>>1)&1
    return dict(median=m,filtered=f,detail_gradient=gd,stable_gradient=gs,candidate=token,qualified=qualified,seed=seed,link1=link1,link2=link2,link3=link3,linked=linked,edge=edge)

def process(rgb,overlay=False,threshold=80):
    rgb=rgb.astype(np.int64);y=(rgb[:,:,0]*77+rgb[:,:,1]*150+rgb[:,:,2]*29+128)>>8
    stages=detect(y,threshold);edge=stages['edge']
    output=rgb.copy() if overlay else np.repeat(y[:,:,None],3,axis=2)
    if overlay:output[edge!=0]=[255,0,0]
    else:output[:,rgb.shape[1]//2:,:]=255*edge[:,rgb.shape[1]//2:,None]
    return dict(gray=y,**stages,output=output)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--full',action='store_true');a=ap.parse_args()
    h,w,nf=(1080,1920,2) if a.full else (64,96,8)
    yy,xx=np.indices((h,w));rng=np.random.default_rng(221062);frames=[];refs=[]
    thresholds=[80,80,16,1024,80,80,80,80]
    for k in range(nf):
        if k==0:y=32+((xx//max(6,w//12)+yy//max(6,h//8))%2)*24+rng.integers(-2,3,(h,w))
        elif k==1:y=35+120*(xx*3+yy*2>w*2)+rng.integers(-9,10,(h,w))
        elif k==2:y=rng.integers(0,256,(h,w))
        elif k==3:y=np.where(((xx//8)+(yy//8))%2,255,0)
        elif k==4:y=np.clip(140+rng.integers(-20,21,(h,w)),0,255)
        elif k==5:y=np.where(xx%20==10,20,180)
        elif k==6:y=80+24*((xx-w//2)**2+(yy-h//2)**2<(min(w,h)//3)**2)
        else:y=np.where((xx==w//2)|(yy==h//2),200,40)
        y=np.clip(y,0,255);rgb=np.stack([y,np.clip(y+5*k,0,255),np.clip(y-7*k,0,255)],axis=-1)
        frames.append(rgb);refs.append(process(rgb,k%2,thresholds[k]))
    suffix='1080p' if a.full else 'small'
    savehex(P/f'input_{suffix}.hex',[packed(x) for x in frames]);savehex(P/f'output_{suffix}.hex',[packed(r['output']) for r in refs])
    if not a.full:
        for key in refs[0]:
            if key!='output':savehex(P/f'{key}_small.hex',[r[key] for r in refs])
    print('Reference generated F2',w,h,nf,'edges',[int(r['edge'].sum()) for r in refs],flush=True)
if __name__=='__main__':main()
