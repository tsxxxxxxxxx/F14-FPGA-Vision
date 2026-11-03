"""Estimate a fixed-gain correction from neutral patches in F8 feedback.

Screenshot RGB is not sensor-linear RGB. Predictions below are only a local
linear approximation, not evidence of the new firmware's physical output.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

R = Path(__file__).resolve().parents[1]
OLD = np.array([470, 256, 427])
NEW = np.array([394, 256, 351])
SAMPLES = [
    ("paper", "evidence/calibration/F8_paper.png", [
        (800, 450), (1250, 450), (1650, 450),
        (800, 800), (1250, 800), (1650, 800),
        (800, 1100), (1250, 1100), (1650, 1100)]),
    ("checker", "evidence/calibration/F8_checker.png", [
        (730, 365), (940, 385), (1155, 400),
        (830, 485), (1045, 505), (1250, 515),
        (720, 580), (930, 605), (1140, 620),
        (820, 695), (1030, 710), (1240, 730),
        (710, 795), (920, 815), (1130, 830),
        (805, 900), (1015, 915), (1220, 940)]),
]

rows = []
for label, rel, centers in SAMPLES:
    path = R / rel
    with Image.open(path) as image:
        rgb = np.asarray(image.convert("RGB"))
    patches = []
    for x, y in centers:
        roi = rgb[y-20:y+20, x-20:x+20].reshape(-1, 3).astype(float)
        # All regions must be internal whites, with no overlay or clipped pixels.
        assert roi.shape == (1600, 3)
        assert np.quantile(roi, .01) > 80 and np.quantile(roi, .99) < 245
        red = (roi[:, 0] > 220) & (roi[:, 1] < 80) & (roi[:, 2] < 80)
        assert not red.any()
        patches.append(np.median(roi, axis=0))
    patches = np.array(patches)
    factor = np.median(patches[:, 1:2] / patches, axis=0)
    measured = np.median(patches, axis=0)
    predicted = measured * NEW / OLD
    before = float(np.ptp(measured) / measured[1])
    after = float(np.ptp(predicted) / predicted[1])
    assert after < before and after < .06
    row = dict(label=label, path=rel, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
               centers=centers, patch_size=40, patch_median_rgb=patches.tolist(),
               scene_median_rgb=measured.tolist(), estimated_q8=(OLD*factor).tolist(),
               predicted_screenshot_rgb=predicted.tolist(),
               measured_neutral_spread=before, predicted_neutral_spread=after)
    rows.append(row)
    print(label, "measured", measured, "estimated Q8", OLD*factor,
          "predicted only", np.round(predicted, 2))

selected = np.rint(np.mean([row["estimated_q8"] for row in rows], axis=0)).astype(int)
assert np.array_equal(selected, NEW)
report = dict(old_q8=OLD.tolist(), selected_q8=NEW.tolist(), samples=rows,
              method="Equal weight per scene; median G/channel ratios over 40x40 neutral patches",
              boundary="Screenshot-space local linear approximation only; no RAW calibration, no board proof")
(R/"evidence/feedback_calibration.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("PASS F9 FEEDBACK MODEL: 27 neutral patches, Q8 394/256/351; physical output not verified")
