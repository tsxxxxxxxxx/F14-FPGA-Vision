"""Restore licensed local dependencies, without downloading or redistributing them."""
from pathlib import Path
import argparse, hashlib, json

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--vendor-root',type=Path,help='Official 04-1_Ti60_SC2210_HDMI_1080P60 directory')
p.add_argument('--f14-root',type=Path,help='An existing, lawfully obtained complete F14 project')
a=p.parse_args();R=Path(__file__).resolve().parents[1]
manifest=json.loads((R/'dependencies/manifest.json').read_text(encoding='utf8'))
patches=json.loads((R/'dependencies/project_changes.json').read_text(encoding='utf8'))
sha=lambda b:hashlib.sha256(b).hexdigest()
ready=[];missing=[]
for d in manifest:
 target=R/d['path'];data=None
 if target.is_file() and sha(target.read_bytes())==d['sha256']:continue
 if target.exists():raise SystemExit('Refusing to overwrite different file: '+d['path'])
 if a.f14_root:
  f=a.f14_root/d['path']
  if f.is_file() and sha(f.read_bytes())==d['sha256']:data=f.read_bytes()
 if data is None and a.vendor_root and d['method'] in ('copy','patch'):
  f=a.vendor_root/d['base_path']
  if f.is_file() and sha(f.read_bytes())==d['base_sha256']:
   data=f.read_bytes()
   if d['method']=='patch':
    lines=data.splitlines(keepends=True)
    for op in reversed(patches[d['path']]):lines[op['start']:op['end']]=[bytes.fromhex(op['insert_hex'])]
    data=b''.join(lines)
 if data is None:missing.append(d['path'])
 else:
  assert sha(data)==d['sha256'],d['path']
  ready.append((target,data))
if missing:
 print('Missing or different-version dependencies (no files written):')
 print('\n'.join(missing));raise SystemExit(1)
for target,data in ready:
 target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
print(f'PASS: {len(manifest)} dependencies verified; {len(ready)} restored locally.')
