"""Screenshot replay visualization using oracle boxes checked by RTL regression.
This is a software preview of supplied display screenshots, not board capture.
Original screenshot overlays remain part of the source pixels.
"""
import json
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageFilter
from shapes_assets import R,COLORS,NAMES,FONT
from shapes_vectors import pixel_gate
def main():
    cases=json.loads((R/'evidence/shapes_cases.json').read_text())
    font_rows=[int(x,16) for x in (R/'src/isp/shapes_font.mem').read_text().split()]
    records=[]
    for k in (1,2):
        case=next(x for x in cases if x['name']==f'camera_feedback_{k}')
        original=Image.open(R/f'evidence/camera_view_{k}.png').convert('RGB');rgb=np.asarray(original).copy()
        dark=Image.fromarray((pixel_gate(original)<96).astype(np.uint8)*255)
        edge=(np.asarray(dark.filter(ImageFilter.MaxFilter(3)))>0)&(np.asarray(dark.filter(ImageFilter.MinFilter(3)))==0)
        edge[[0,-1],:]=False;edge[:,[0,-1]]=False
        for c,x0,y0,x1,y1 in case['objects']:
            left=max(0,x0*8-8);right=min(1920,x1*8+16);top=max(0,y0*8-8);bottom=min(1080,y1*8+16)
            region=rgb[top:bottom,left:right];region[edge[top:bottom,left:right]]=COLORS[c]
        for c,x0,y0,x1,y1 in case['objects']:
            tx=x1*8+15 if x1*8+111<1920 else x0*8-104;ty=y0*8
            glyph=np.zeros((16,48),bool)
            for char in range(3):
                for y in range(16):
                    bits=font_rows[c*48+char*16+y]
                    for x in range(16):glyph[y,char*16+x]=bool(bits&(1<<x))
            glyph=np.repeat(np.repeat(glyph,2,axis=0),2,axis=1)
            rgb[ty:ty+32,tx:tx+96]=24;rgb[ty:ty+32,tx:tx+96][glyph]=COLORS[c]
        output=Image.new('RGB',(1920,1150),'#17202e');output.paste(Image.fromarray(rgb),(0,70))
        d=ImageDraw.Draw(output);font=ImageFont.truetype(str(FONT),26)
        text=f'F13 图{k}截图回放预览：六类同时检出；非开发板新实拍'
        if k==1:text+='（原图青色边缘保留）'
        d.text((24,20),text,font=font,fill='white')
        output.save(R/f'evidence/camera_{k}_F13_replay.png')
        records.append(dict(image=k,classes=[NAMES[x[0]] for x in case['objects']],objects=case['objects'],note='Full-frame screenshot-derived input; expected boxes checked by RTL, software display preview'))
    Image.open(R/'evidence/six_shapes_rtl.ppm').save(R/'evidence/six_shapes_rtl.png')
    (R/'evidence/camera_preview.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Generated two source-screenshot replay previews with exact class colors and Chinese ROM glyphs')
if __name__=='__main__':main()
