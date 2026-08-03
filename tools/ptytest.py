import os, pty, signal, struct, fcntl, termios, time, select, sys
pid, fd = pty.fork()
if pid == 0:
    os.execv("./demo", ["./demo", "-fps"] + sys.argv[1:])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 50, 200, 0, 0))
total = 0; frames = 0; buf = b""
t0 = time.time()
while time.time() - t0 < 4.0:
    r,_,_ = select.select([fd], [], [], 0.2)
    if not r: continue
    try: d = os.read(fd, 1 << 20)
    except OSError: break
    if not d: break
    total += len(d); buf += d
    frames += buf.count(b"\x1b[?2026h"); buf = buf[-16:]
el = time.time() - t0
os.kill(pid, signal.SIGINT)
time.sleep(0.4)
tail = b""
try:
    while True:
        r,_,_ = select.select([fd],[],[],0.2)
        if not r: break
        d = os.read(fd, 65536)
        if not d: break
        tail += d
except OSError: pass
w = os.waitpid(pid, os.WNOHANG)
print("frames=%d  elapsed=%.2fs  fps=%.1f  MB=%.1f  MB/s=%.1f" % (frames, el, frames/el, total/1e6, total/1e6/el))
print("restore seq present:", b"\x1b[?1049l" in tail, " exit:", w)
