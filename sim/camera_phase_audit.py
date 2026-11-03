"""Sensitivity to camera/screenshot sample phase; no region-specific detection."""
import json,numpy as np
from PIL import Image
from shapes_vectors import R,W,H,pixel_gate,oracle
def provisional_labels(mask):
    lab=np.zeros(mask.shape,int);parent=list(range(W*H+1));n=0
    def root(i):
        while parent[i]!=i:i=parent[i]
        return i
    for y in range(H):
        for x in range(W):
            if not mask[y,x]:continue
            v=[root(lab[yy,xx]) for xx,yy in ((x-1,y),(x-1,y-1),(x,y-1),(x+1,y-1)) if 0<=xx<W and 0<=yy<H and lab[yy,xx]]
            if v:
                m=min(v);lab[y,x]=m
                for k in v:parent[k]=m
            else:n+=1;lab[y,x]=n
    return n
def main():
    results=[]
    for k in (1,2):
        full=pixel_gate(Image.open(R/f'evidence/camera_view_{k}.png'))
        for dy in range(8):
            for dx in range(8):
                a=full[dy::8,dx::8];raw=a<96;pad=np.pad(raw,1,mode='edge')
                neighbors=sum(pad[y:y+H,x:x+W].astype(np.uint8) for y in range(3) for x in range(3))
                count=provisional_labels(raw&(neighbors>=4))
                found=oracle(Image.fromarray(a));classes=sorted(x[0] for x in found)
                results.append(dict(image=k,dx=dx,dy=dy,labels=count,classes=classes,pass_six=classes==list(range(6))))
    (R/'evidence/camera_phase_audit.json').write_text(json.dumps(results,indent=2))
    for k in (1,2):
        rows=[x for x in results if x['image']==k]
        print(k,'phases passed',sum(x['pass_six'] for x in rows),'/64; max provisional labels',max(x['labels'] for x in rows))
        failures=[x for x in rows if not x['pass_six'] or x['labels']>95]
        print('failures',failures)
        assert not failures
    print('PASS F13 CAMERA PHASES 128/128 six classes and label capacity')
if __name__=='__main__':main()
