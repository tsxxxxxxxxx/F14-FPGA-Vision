"""Local source-derived silhouettes and Chinese ROM; no downloaded assets."""
from pathlib import Path
import json,math,hashlib,os
import numpy as np
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1]
NAMES=['圆形','正方形','三角形','梯形','五边形','六边形']
KINDS=['ellipse','rect','triangle','trapezoid','pentagon','hexagon']
COLORS=[(255,64,64),(48,224,96),(255,208,32),(32,208,255),(224,80,255),(255,144,32)]
ANGLES=[-12,-8,-4,0,4,8,12]
G={x['kind']:x for x in json.loads((R/'docs/source_geometry.json').read_text())['shapes']}
FONT=Path(os.environ['F14_FONT'])  # Supply a font you are licensed to use.
def source(cls,size=300):
    g=G[KINDS[cls]];w=size;h=round(size*g['height']/g['width'])
    im=Image.new('L',(512,512),255);d=ImageDraw.Draw(im);x=(512-w)/2;y=(512-h)/2
    if cls==0:d.ellipse((x,y,x+w-1,y+h-1),fill=0)
    elif cls==1:d.rectangle((x,y,x+w-1,y+h-1),fill=0)
    else:
        if cls==2:pts=[(.5,0),(1,1),(0,1)]
        elif cls==3:pts=[(0,1),(498316/2505710,0),(2007393/2505710,0),(1,1)]
        elif cls==4:
            pts=[(math.cos(-math.pi/2+2*math.pi*k/5),math.sin(-math.pi/2+2*math.pi*k/5)) for k in range(5)]
            ax=min(a for a,b in pts);ay=min(b for a,b in pts);bx=max(a for a,b in pts);by=max(b for a,b in pts)
            pts=[((a-ax)/(bx-ax),(b-ay)/(by-ay)) for a,b in pts]
        else:
            inset=min(g['width'],g['height'])*.25/g['width']
            pts=[(inset,0),(1-inset,0),(1,.5),(1-inset,1),(inset,1),(0,.5)]
        d.polygon([(x+a*(w-1),y+b*(h-1)) for a,b in pts],fill=0)
    return im
def normalize(mask):
    yy,xx=np.where(mask);x0,x1,y0,y1=xx.min(),xx.max(),yy.min(),yy.max();w=x1-x0+1;h=y1-y0+1
    a=np.zeros((32,32),np.uint8)
    for y in range(32):
        for x in range(32):
            a[y,x]=sum(int(mask[y0+((4*y+dy)*h>>7),x0+((4*x+dx)*w>>7)]) for dx,dy in ((1,1),(3,1),(1,3),(3,3)))>=2
    return a
def templates():return [normalize(np.asarray(source(c).rotate(a,Image.Resampling.BICUBIC,fillcolor=255))<128) for c in range(6) for a in ANGLES]
def main():
    mats=templates();lines=[f'{sum(int(v)<<i for i,v in enumerate(row)):08x}' for m in mats for row in m]
    (R/'src/isp/shapes_templates.mem').write_text(chr(10).join(lines)+chr(10),encoding='ascii')
    glyphs=[];font=ImageFont.truetype(str(FONT),16)
    for name in NAMES:
        for char in name.ljust(3):
            im=Image.new('L',(16,16),0);d=ImageDraw.Draw(im);b=d.textbbox((0,0),char,font=font)
            d.text(((16-b[2]-b[0])/2,(16-b[3]-b[1])/2),char,font=font,fill=255)
            glyphs.extend(sum((int(v)>80)<<x for x,v in enumerate(row)) for row in np.asarray(im))
    (R/'src/isp/shapes_font.mem').write_text(''.join(f'{v:04x}'+chr(10) for v in glyphs),encoding='ascii')
    preview=Image.new('RGB',(900,520),'white');d=ImageDraw.Draw(preview);f=ImageFont.truetype(str(FONT),26)
    for c in range(6):
        m=source(c);bb=Image.fromarray(255-np.asarray(m)).getbbox();m=m.crop(bb);m.thumbnail((200,185))
        x=(c%3)*300+45;y=(c//3)*260+15;preview.paste(m,(x+(210-m.width)//2,y));d.text((x+40,y+205),NAMES[c],font=f,fill=COLORS[c])
    preview.save(R/'evidence/source_shapes.png')
    (R/'docs/shape_classes.json').write_text(json.dumps([dict(id=c,name=NAMES[c],kind=KINDS[c],color='#%02x%02x%02x'%COLORS[c],angles=ANGLES) for c in range(6)],ensure_ascii=False,indent=2),encoding='utf-8')
    print('Generated 42 source-derived templates and 18 local Chinese glyph cells')
if __name__=='__main__':main()
