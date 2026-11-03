"""Deterministic checker-specific comparison, not a camera/hardware proof."""
import json,importlib.util
from pathlib import Path
import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as win
from f3_model import detect
R=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('old_f5',R.parent/'SC2210_HDMI_1080P60_DDR_F5/sim/f3_model.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
def dilate(a,r=2):return win(np.pad(a,r),(r*2+1,r*2+1)).any((-1,-2))
def metric(edge,truth,distance):
    roi=np.zeros(edge.shape,bool);roi[12:-12,12:-12]=True
    e=edge.astype(bool)&roi;t=truth&roi
    tp=(e&dilate(t)).sum();false=(e&~dilate(t)).sum()
    return dict(pixels=int(e.sum()),false=int(false),precision=float(tp/max(1,e.sum())),
      recall=float((t&dilate(e)).sum()/max(1,t.sum())),
      line_rms=float(np.sqrt(np.mean(distance[e&dilate(t)]**2))))
rng=np.random.default_rng(6005);yy,xx=np.indices((256,320));rows=[]
for angle in (0,12,27,45):
 for contrast in (48,128):
  for noise in (4,12,24):
   for threshold in (48,80):
    rad=np.deg2rad(angle);u=(xx-160)*np.cos(rad)+(yy-128)*np.sin(rad)+.37
    v=-(xx-160)*np.sin(rad)+(yy-128)*np.cos(rad)+.21
    cell=32;mask=((np.floor(u/cell)+np.floor(v/cell)).astype(int)&1)
    clean=40+mask*contrast
    # Optical blur plus sensor random noise, 2-pixel ripple and rare impulses.
    clean=win(np.pad(clean,1,mode='edge'),(3,3)).mean((-1,-2))
    y=np.clip(clean+rng.normal(0,noise,clean.shape)+5*((xx&1)*2-1)+3*((yy&1)*2-1),0,255)
    impulse=rng.random(y.shape)<.001;y[impulse]=rng.choice([0,255],impulse.sum());y=np.rint(y).astype(np.int64)
    du=np.minimum(np.mod(u,cell),cell-np.mod(u,cell));dv=np.minimum(np.mod(v,cell),cell-np.mod(v,cell));dist=np.minimum(du,dv)
    truth=dist<.6
    a=metric(old.detect(y,threshold)['edge'],truth,dist);b=metric(detect(y,threshold)['edge'],truth,dist)
    rows.append(dict(angle=angle,contrast=contrast,noise=noise,threshold=threshold,F5=a,F6=b))
summary={version:{k:float(np.mean([r[version][k] for r in rows])) for k in ('false','precision','recall','line_rms')} for version in ('F5','F6')}
(R/'evidence/checker_quality.json').write_text(json.dumps(dict(cases=len(rows),summary=summary,rows=rows),indent=2),encoding='utf-8')
print(json.dumps(summary,indent=2))
assert summary['F6']['false']<summary['F5']['false'],'No noise reduction'
assert summary['F6']['line_rms']<summary['F5']['line_rms'],'No line localization improvement'
assert summary['F6']['recall']>=summary['F5']['recall']-.03,'Too much checker outline loss'
print('PASS CHECKER QUALITY: 48 deterministic cases, noise and localization improved; synthetic benchmark only')
