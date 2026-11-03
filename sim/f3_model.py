"""Independent integer F3 model; no frame iteration, no image gain."""
import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as win
from reference import range_filter, support_stage, sobel
from baseline_f1 import blur

def median(y):
    w=win(y,(3,3));c=w[:,:,1,1];m=np.median(w,axis=(-1,-2)).astype(np.int64)
    n=np.abs(w-c[:,:,None,None])<=8
    # Opposed support protects thin strokes, not arbitrary pairs of outliers.
    line=(n[:,:,0,0]&n[:,:,2,2])|(n[:,:,0,1]&n[:,:,2,1])|(n[:,:,0,2]&n[:,:,2,0])|(n[:,:,1,0]&n[:,:,1,2])
    z=y.copy();z[1:-1,1:-1]=m;return z

def vector(y):
    w=win(y,(3,3));gx=np.zeros_like(y);gy=gx.copy()
    gx[1:-1,1:-1]=w[:,:,0,2]+2*w[:,:,1,2]+w[:,:,2,2]-w[:,:,0,0]-2*w[:,:,1,0]-w[:,:,2,0]
    gy[1:-1,1:-1]=w[:,:,2,0]+2*w[:,:,2,1]+w[:,:,2,2]-w[:,:,0,0]-2*w[:,:,0,1]-w[:,:,0,2]
    return gx,gy

def nms(y,threshold=80):
    gx,gy=vector(y);mag=np.abs(gx)+np.abs(gy);w=win(mag,(3,3));x=gx[1:-1,1:-1];v=gy[1:-1,1:-1]
    ax=np.abs(x);ay=np.abs(v);horizontal=ax>=ay;same=(x<0)==(v<0)
    major=np.maximum(ax,ay);minor=np.minimum(ax,ay);c=w[:,:,1,1]
    b=np.where(horizontal,w[:,:,1,0],w[:,:,0,1]);a=np.where(horizontal,w[:,:,1,2],w[:,:,2,1])
    db=np.where(same,w[:,:,0,0],np.where(horizontal,w[:,:,2,0],w[:,:,0,2]))
    da=np.where(same,w[:,:,2,2],np.where(horizontal,w[:,:,0,2],w[:,:,2,0]))
    peak=(c*major>b*(major-minor)+db*minor)&(c*major>=a*(major-minor)+da*minor)
    ori=sobel(y)[1:-1,1:-1]>>11;low=max(8,threshold//2)
    candidate=peak&(c>=low);strong=c>=threshold;robust=c>=threshold*2
    agree=c>=((threshold>>1)+(threshold>>2))
    z=np.zeros_like(y);z[1:-1,1:-1]=np.where(candidate,((ori&4)<<4)|((ori&3)<<3)|(robust.astype(int)<<5)|(agree.astype(int)<<2)|(strong.astype(int)<<1)|1,0)
    z[:2]=0;z[-2:]=0;z[:,:2]=0;z[:,-2:]=0;return z

def stage(t,seed=False,qualify=False):
    w=win(t,(3,3)).reshape(t.shape[0]-2,t.shape[1]-2,9);c=w[:,:,4];ori=((w>>3)&3)|((w>>4)&4);co=ori[:,:,4];diff=(ori-co[:,:,None])&7
    good=((w&1)!=0)&((diff==0)|(diff==1)|(diff==7));good[:,:,4]=False
    strong=good&((w&2)!=0);d=(c>>3)&3
    supported=good&((w&4)!=0)
    fs=((0,1,2),(1,2,5),(0,3,6),(0,1,3));bs=((6,7,8),(3,6,7),(2,5,8),(5,7,8))
    both=np.zeros_like(c,dtype=bool);link=both.copy()
    for k in range(4):
        both|=(d==k)&np.any(supported[:,:,fs[k]],-1)&np.any(supported[:,:,bs[k]],-1)
        link|=(d==k)&np.any(strong[:,:,fs[k]+bs[k]],-1)
    if qualify:
        z=np.zeros_like(t);z[1:-1,1:-1]=np.where((c&1)!=0,(c&123)|((both&((c&4)!=0)).astype(int)<<2),0);return z
    keep=(((c&2)!=0)&link)|(((c&4)!=0)&both) if seed else ((c&2)!=0)|link
    z=np.zeros_like(t);z[1:-1,1:-1]=np.where((c&1)!=0,(c&125)|(keep.astype(int)<<1),0);return z

def detect(y,threshold=80):
    m=median(y);w=win(m,(3,3));c=w[:,:,1,1];ridge=np.zeros_like(c,dtype=bool)
    for a,b,p,q in ((1,7,3,5),(3,5,1,7),(0,8,2,6),(2,6,0,8)):
        z=w.reshape(*c.shape,9);da=c-z[:,:,p];db=c-z[:,:,q]
        ridge|=(np.abs(c-z[:,:,a])<=8)&(np.abs(c-z[:,:,b])<=8)&(np.abs(da)>=12)&(np.abs(db)>=12)&((da>0)==(db>0))
    kernel=np.array([[1,2,1],[2,4,2],[1,2,1]])
    total=np.sum(w*kernel,axis=(-1,-2));f=m.copy();f[1:-1,1:-1]=(total+8)>>4
    w2=win(f,(3,3));total2=np.sum(w2*kernel,axis=(-1,-2));f2=f.copy();f2[1:-1,1:-1]=(total2+8)>>4;f=f2
    t=nms(f,threshold);q=stage(t,qualify=True);s=stage(q,True);a=stage(s);b=stage(a)
    return dict(gray=y,median=m,filtered=f,candidate=t,qualified=q,seed=s,link1=a,linked=b,edge=(b>>1)&1)
