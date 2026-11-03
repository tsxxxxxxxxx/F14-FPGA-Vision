"""Independent flood-fill oracle; RTL uses label equivalence, not flood fill."""
from collections import deque
import json
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
from shapes_assets import R,source,normalize,templates,NAMES,G,KINDS
W,H=240,135
T=np.asarray(templates()).reshape(6,7,32,32)
def pixel_gate(rgb):
    a=np.asarray(rgb,dtype=np.int16)
    luma=(a[:,:,0]+2*a[:,:,1]+a[:,:,2])>>2
    return np.where((a.max(2)-a.min(2)>48)&(luma<96),128,luma).astype(np.uint8)

def probe_norm(sub,rotation):
    h,w=sub.shape; yy,xx=np.indices((32,32));votes=np.zeros((32,32),int);center=[]
    for dx,dy in ((1,1),(3,1),(1,3),(3,3)):
        px=4*xx+dx;py=4*yy+dy
        rx,ry=((px,py),(127-py,px),(127-px,127-py),(py,127-px))[rotation]
        sampled=sub[(ry*h)>>7,(rx*w)>>7]
        votes+=sampled<3
        center.extend(sampled[14:18,14:18].flat)
    return votes>=2,int(sum(center))

def stamp(im,c,xy,size,angle=0,black=20):
    s=source(c).rotate(angle,Image.Resampling.BICUBIC,fillcolor=255)
    bb=Image.fromarray(255-np.asarray(s)).getbbox();s=s.crop(bb)
    s=s.resize((size,round(size*s.height/s.width)),Image.Resampling.LANCZOS)
    s=s.point(lambda p: black if p<128 else 240)
    im.paste(s,xy)
def oracle(im,debug=False):
    a=np.asarray(im).astype(np.uint16)>>5
    raw=a<3;pad=np.pad(raw,1,mode='edge')
    neighbors=sum(pad[y:y+H,x:x+W].astype(np.uint8) for y in range(3) for x in range(3))
    mask=raw&(neighbors>=4)
    seen=np.zeros_like(mask);found=[];diagnostics=[]
    for y,x in zip(*np.where(mask)):
        if seen[y,x]:continue
        q=deque([(x,y)]);seen[y,x]=1;pts=[]
        while q:
            px,py=q.popleft();pts.append((px,py))
            for xx,yy in ((px-1,py),(px+1,py),(px,py-1),(px,py+1),(px-1,py-1),(px+1,py-1),(px-1,py+1),(px+1,py+1)):
                if 0<=xx<W and 0<=yy<H and mask[yy,xx] and not seen[yy,xx]:seen[yy,xx]=1;q.append((xx,yy))
        x0=min(x for x,y in pts);x1=max(x for x,y in pts);y0=min(y for x,y in pts);y1=max(y for x,y in pts)
        w=x1-x0+1;h=y1-y0+1
        if len(pts)<64 or min(w,h)<10 or x0<3 or y0<3 or x1>=W-3 or y1>=H-3 or len(pts)*4<w*h or max(w,h)>2*min(w,h):continue
        sub=np.where(mask[y0:y1+1,x0:x1+1],0,7);n,_=probe_norm(sub,0)
        _,center=probe_norm(a[y0:y1+1,x0:x1+1],0)
        ring=np.concatenate([a[y0-2,x0-2:x1+3],a[y1+2,x0-2:x1+3],a[y0-1:y1+2,x0-2],a[y0-1:y1+2,x1+2]])
        holes=sum(int(np.count_nonzero(~row[np.flatnonzero(row)[0]:np.flatnonzero(row)[-1]+1])) for row in n if row.any())
        scores=np.full(6,2047)
        for rotation in range(4):
            n,_=probe_norm(sub,rotation)
            rs=np.count_nonzero(T!=n,axis=(2,3)).min(axis=1)
            aw,ah=(h,w) if rotation%2 else (w,h)
            for c in range(6):
                if aw*4>=ah*3 and aw*4<=ah*(5 if c<2 else 6):scores[c]=min(scores[c],rs[c])
        order=np.argsort(scores);c=int(order[0]);best=int(scores[c]);second=int(scores[order[1]])
        contrast=int(ring.sum())*64>=(center+128)*len(ring)
        accept=holes<=12 and best<=112 and second>=best+16 and np.count_nonzero(ring>=3)*8>=len(ring)*7 and contrast
        diagnostics.append(dict(box=[x0,y0,x1,y1],cls=c,best=best,second=second,holes=holes,white=float(np.mean(ring>=3)),contrast=bool(contrast),accept=bool(accept)))
        if accept:found.append(tuple(int(v) for v in (c,x0,y0,x1,y1)))
    return (found,diagnostics) if debug else found
def main():
    cases=[]
    def add(name,im,expected):
        got,diag=oracle(im,True)
        assert sorted(x[0] for x in got)==sorted(expected),(name,expected,got,diag)
        cases.append((name,im,got))
    for angle,size in [(0,38),(-6,42),(7,32)]:
        im=Image.new('L',(W,H),240)
        for c,(x,y) in enumerate([(8,9),(90,9),(173,9),(8,81),(90,81),(173,81)]):stamp(im,c,(x,y),size,angle)
        add(f'all_six_angle_{angle}_size_{size}',im,list(range(6)))
    for c in range(6):
        for size in (20,64):
            im=Image.new('L',(W,H),240);stamp(im,c,(12+c*20,30),size)
            add(f'{c}_size_{size}',im,[c])
    add('blank',Image.new('L',(W,H),240),[])
    im=Image.new('L',(W,H),240);d=ImageDraw.Draw(im)
    d.ellipse((15,20,70,75),outline=20,width=6);d.rectangle((90,20,145,75),outline=20,width=6)
    d.polygon([(180,20),(155,75),(210,75)],outline=20,width=4);add('hollow_shapes',im,[])
    im=Image.new('L',(W,H),240);d=ImageDraw.Draw(im);d.rectangle((10,10,110,30),fill=20);d.line((25,105,210,85),fill=20,width=3)
    d.polygon([(170,30),(175,45),(195,45),(180,55),(185,75),(170,63),(155,75),(160,55),(145,45),(165,45)],fill=20);add('rectangle_line_star',im,[])
    im=Image.new('L',(W,H),64);d=ImageDraw.Draw(im);d.ellipse((40,25,100,85),fill=20);add('insufficient_paper_contrast',im,[])
    im=Image.new('L',(W,H),240);stamp(im,0,(0,30),64);add('clipped_border',im,[])
    im=Image.new('L',(W,H),240);stamp(im,1,(15,20),40,black=120);add('gray_fill',im,[])
    im=Image.new('L',(W,H),240);stamp(im,1,(15,20),50);ImageDraw.Draw(im).ellipse((31,35,48,52),fill=240);add('square_with_hole',im,[])
    im=Image.new('L',(W,H),240);stamp(im,0,(10,20),40);stamp(im,0,(170,60),40);add('same_class_twice',im,[0,0])
    im=Image.new('L',(W,H),240);stamp(im,5,(190,75),40);add('bottom_right_fullscreen',im,[5])
    # Original document uses two columns by three rows, at its actual extents.
    im=Image.new('L',(W,H),240)
    for c,kind in enumerate(KINDS):
        g=G[kind];scale=115/8000000
        stamp(im,c,(70+round((g['x']+52070)*scale),8+round((g['y']+93345)*scale)),round(g['width']*scale))
    add('original_document_layout',im,list(range(6)))
    im.save(R/'evidence/document_layout_sample.png')
    for angle in (-11,11):
        im=Image.new('L',(W,H),240)
        for c,(x,y) in enumerate([(8,9),(90,9),(173,9),(8,81),(90,81),(173,81)]):stamp(im,c,(x,y),36,angle)
        add(f'all_six_angle_{angle}',im,list(range(6)))
    im=Image.new('L',(W,H),240)
    for c,(x,y) in enumerate([(8,9),(90,9),(173,9),(8,81),(90,81),(173,81)]):stamp(im,c,(x,y),38)
    ImageDraw.Draw(im).line((130,50,225,55),fill=20,width=1)
    for x,y in [(20,60),(60,50),(152,12),(230,100),(122,125)]:ImageDraw.Draw(im).point((x,y),fill=20)
    add('six_targets_with_small_clutter',im,list(range(6)))
    for angle in (90,180,270,84,97,174,187,264,277):
        im=Image.new('L',(W,H),240)
        for c,(x,y) in enumerate([(8,9),(90,9),(173,9),(8,81),(90,81),(173,81)]):stamp(im,c,(x,y),32,angle)
        add(f'all_six_quarter_turn_{angle}',im,list(range(6)))
    for paper,ink in ((128,20),(144,48),(176,64)):
        im=Image.new('L',(W,H),240)
        for c,(x,y) in enumerate([(8,9),(90,9),(173,9),(8,81),(90,81),(173,81)]):stamp(im,c,(x,y),32,90)
        im=im.point(lambda p:ink if p<96 else paper)
        add(f'shaded_paper_{paper}_ink_{ink}',im,list(range(6)))
    im=Image.new('L',(W,H),240);stamp(im,1,(40,30),40);ImageDraw.Draw(im).point((60,50),fill=240)
    add('tiny_ink_gap_tolerated',im,[1])
    replay=[]
    for k in (1,2):
        rgb=Image.open(R/f'evidence/camera_view_{k}.png').convert('RGB')
        a=pixel_gate(rgb)[4::8,4::8]
        im=Image.fromarray(a)
        add(f'camera_feedback_{k}',im,list(range(6)))
        replay.append(dict(image=k,objects=cases[-1][2],diagnostics=oracle(im,True)[1]))
        for scale,offset in ((.9,0),(1.1,0),(1,12)):
            b=np.clip(a.astype(float)*scale+offset,0,255).astype(np.uint8)
            add(f'camera_{k}_gain_{scale}_offset_{offset}',Image.fromarray(b),list(range(6)))
    for k,dx,dy in [(1,x,5) for x in (4,5,6,7)]+[(2,x,0) for x in (1,3,4,5,7)]:
        a=pixel_gate(Image.open(R/f'evidence/camera_view_{k}.png'))[dy::8,dx::8]
        add(f'camera_{k}_phase_{dx}_{dy}',Image.fromarray(a),list(range(6)))
    (R/'evidence/camera_replay_oracle.json').write_text(json.dumps(replay,indent=2,default=int))
    pixels=[];expected=[]
    for name,im,objects in cases:
        pixels.extend(f'{int(v):02x}' for v in np.asarray(im).flat)
        expected.append(f'{len(objects):02x}')
        for item in objects:expected.append(''.join(f'{v:02x}' for v in item))
        expected.extend(['ffffffffff']*(8-len(objects)))
    (R/'sim/shapes_input.hex').write_text(chr(10).join(pixels)+chr(10))
    (R/'sim/shapes_first.hex').write_text(chr(10).join(pixels[:W*H])+chr(10))
    (R/'sim/shapes_expected.hex').write_text(chr(10).join(expected)+chr(10))
    (R/'sim/shapes_first_expected.hex').write_text(chr(10).join(expected[:9])+chr(10))
    (R/'sim/shapes_case_count.vh').write_text(chr(96)+f'define SHAPE_CASES {len(cases)}'+chr(10))
    (R/'evidence/shapes_cases.json').write_text(json.dumps([dict(name=n,objects=o) for n,im,o in cases],indent=2))
    cases[0][1].resize((1920,1080)).save(R/'evidence/six_targets_input.png')
    print(f'PASS independent six-shape oracle cases={len(cases)}; includes multiobject, holes, dark background and unknown clutter')
if __name__=='__main__':main()
