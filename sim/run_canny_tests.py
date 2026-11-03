"""Reproducible F14 RTL tests using installed Icarus; no hardware programming."""
from pathlib import Path
import subprocess,os,sys
R=Path(__file__).resolve().parent.parent;os.chdir(R)
IV=Path(os.environ.get('IVERILOG_BIN', ''))
EXE='.exe' if os.name=='nt' else ''
(R/'evidence').mkdir(exist_ok=True)
os.environ.update(TMP=str(R/'sim'),TMPDIR=str(R/'sim'),TEMP=str(R/'sim'))
def run(args,log=None):
 p=subprocess.run([str(x) for x in args],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf8',errors='replace')
 if log:(R/'evidence'/log).write_text(p.stdout,encoding='utf8')
 print(p.stdout[-2500:],flush=True)
 if p.returncode or any(s in p.stdout for s in ['ERROR:','FATAL:','FAIL','Traceback']):raise SystemExit(p.returncode or 1)
def sim(name,top,sources,defines=()):
 binary=R/'sim'/f'{name}.vvp'
 run([str(IV/('iverilog'+EXE)) if str(IV)!='.' else 'iverilog'+EXE,'-g2012',*defines,'-s',top,'-o',binary,*sources])
 run([str(IV/('vvp'+EXE)) if str(IV)!='.' else 'vvp'+EXE,'-i',binary],name+'.log')
full='--full' in sys.argv
if '--frontend' in sys.argv:
 text=(R/'sim/tb_f3.sv').read_text().replace('module tb_f3;','module tb_f3_canny;')
 text=text.replace('detail_pipeline #','detail_pipeline_canny #').replace("1'b0,,);","1'b0,,,,,);")
 text=text.replace('PASS F10 VIDEO','PASS F14 FRONTEND')
 (R/'sim/tb_f3_canny.sv').write_text(text)
 run([sys.executable,'-B','sim/f3_vectors.py',*(['--full'] if full else [])])
 sim('canny_frontend_full' if full else 'canny_frontend','tb_f3_canny',
     [*sorted((R/'src/isp').glob('*.v')),R/'src/canny/detail_pipeline_canny.v',R/'sim/tb_f3_canny.sv'],
     ['-DFULL_HD'] if full else [])
else:
 run([sys.executable,'-B','sim/canny_vectors.py',*(['--full'] if full else [])])
 sim('canny_hysteresis_full' if full else 'canny_hysteresis','tb_canny_hysteresis',
     ['src/canny/canny_hysteresis.v','sim/tb_canny_hysteresis.sv'],['-DFULL_HD'] if full else [])
 sim('canny_system_full' if full else 'canny_system','tb_canny_system',
     ['src/canny/canny_fifo.v','src/canny/canny_capture_fifo.v','src/canny/canny_fps.v','src/canny/canny_hysteresis.v','src/canny/canny_system.v','sim/tb_canny_system.sv'],
     ['-DFULL_HD'] if full else [])
 if not full:
  sim('canny_safety','tb_canny_system',
      ['src/canny/canny_fifo.v','src/canny/canny_capture_fifo.v','src/canny/canny_fps.v','src/canny/canny_hysteresis.v','src/canny/canny_system.v','sim/tb_canny_system.sv'],['-DSAFETY'])
  sim('canny_cancel','tb_canny_cancel',['src/canny/canny_hysteresis.v','sim/tb_canny_cancel.sv'])
  sim('canny_capture_fifo','tb_canny_capture_fifo',['src/canny/canny_capture_fifo.v','sim/tb_canny_capture_fifo.sv'])
  sim('canny_fps','tb_canny_fps',['src/canny/canny_fps.v','sim/tb_canny_fps.sv'])
