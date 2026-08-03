import io
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEMO = os.path.join(ROOT, "demo")
COLS, ROWS = 200, 50
FPS = 20
STEP = 1000 // FPS
SEGMENTS = [(0, 3000), (8600, 11600), (22600, 25600),
            (32600, 35600), (42600, 45600), (54000, 57000)]


def grab(ms):
    out = subprocess.run([DEMO, "-size", str(COLS), str(ROWS), "-shot", str(ms)],
                         stdout=subprocess.PIPE, check=True).stdout
    return Image.open(io.BytesIO(out)).convert("RGB")


def main():
    scale = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    frames = []
    for a, b in SEGMENTS:
        for ms in range(a, b, STEP):
            im = grab(ms)
            if scale != 1:
                im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            frames.append(im.quantize(colors=255, method=Image.MEDIANCUT))
        sys.stderr.write("segment %d-%d done, %d frames\n" % (a, b, len(frames)))
    dst = os.path.join(ROOT, ".github", "assets", "demo.gif")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    frames[0].save(dst, save_all=True, append_images=frames[1:], loop=0,
                   duration=STEP, disposal=2, optimize=True)
    sys.stderr.write("%s  %d frames  %.1f MB\n"
                     % (dst, len(frames), os.path.getsize(dst) / 1e6))


main()
