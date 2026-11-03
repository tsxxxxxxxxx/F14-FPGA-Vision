"""Use unchanged F12 oracle and F13 oracle on the exact same screenshot crops."""
import importlib.util,json,numpy as np
from PIL import Image
from shapes_vectors import R,pixel_gate,oracle
def main():
    path=R.parent/'SC2210_HDMI_1080P60_SIX_SHAPES_F12/sim/shapes_vectors.py'
    spec=importlib.util.spec_from_file_location('f12_reference',path);old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
    evidence=[]
    for k in (1,2):
        rgb=Image.open(R/f'evidence/camera_view_{k}.png').convert('RGB');a=np.asarray(rgb).astype(int)
        hi=a.max(2);lo=a.min(2)
        f12=np.where((hi<96)&(hi-lo<48),0,np.where(lo>=160,255,128)).astype(np.uint8)
        before=old.oracle(Image.fromarray(f12[4::8,4::8]))
        after=oracle(Image.fromarray(pixel_gate(rgb)[4::8,4::8]))
        evidence.append(dict(image=k,F12=before,F13=after))
        print('Image',k,'F12',before,'F13',after)
    (R/'evidence/camera_before_after.json').write_text(json.dumps(evidence,indent=2,default=int))
if __name__=='__main__':main()
