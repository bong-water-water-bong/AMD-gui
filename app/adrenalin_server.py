#!/usr/bin/env python3
"""Adrenalin replica backend — sysfs GPU control + metrics for Strix Halo (amdgpu).
Stdlib only. Serves the UI and a small JSON API. GPU writes go through sudo -n."""
import json, os, re, glob, signal, subprocess, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SYSFS = "/sys/class/drm"
APP_DIR = os.path.dirname(os.path.abspath(__file__))
PROFILE_DIR = os.path.expanduser("~/.config/adrenalin-profiles")
STRESS_LOG = "/tmp/adrenalin-stress.log"
STRESS = {"proc": None}
GPU_NAME = "AMD Ryzen AI MAX+ 395 (Radeon 8060S)"


def amdgpu():
    for card in sorted(glob.glob(f"{SYSFS}/card*")):
        dev = f"{card}/device"
        try:
            if os.path.realpath(f"{dev}/driver").endswith("amdgpu"):
                return card, dev
        except OSError:
            pass
    return None, None


def hwmon(dev):
    for h in glob.glob(f"{dev}/hwmon/hwmon*"):
        try:
            if open(f"{h}/name").read().strip() == "amdgpu":
                return h
        except OSError:
            pass
    return None


def rd(p):
    try:
        return open(p).read().strip()
    except OSError:
        return None


def sudo_write(path, value):
    r = subprocess.run(["sudo", "-n", "tee", path], input=value.encode(),
                       capture_output=True, timeout=10)
    return r.returncode == 0, r.stderr.decode().strip()


def get_metrics():
    card, dev = amdgpu()
    h = hwmon(dev) if dev else None
    m = {"ok": bool(dev)}
    if not dev:
        return m
    m["busy"] = rd(f"{dev}/gpu_busy_percent")
    m["sclk"] = rd(f"{h}/freq1_input") if h else None
    if m["sclk"]:
        m["sclk"] = str(int(m["sclk"]) // 1000000)  # Hz -> MHz
    m["temp"] = rd(f"{h}/temp1_input") if h else None
    m["power"] = rd(f"{h}/power1_average") if h else None
    m["vram_used"], m["vram_total"] = rd(f"{dev}/mem_info_vram_used"), rd(f"{dev}/mem_info_vram_total")
    m["gtt_used"], m["gtt_total"] = rd(f"{dev}/mem_info_gtt_used"), rd(f"{dev}/mem_info_gtt_total")
    m["mem_busy"] = rd(f"{dev}/mem_busy_percent")
    m["dpm"] = rd(f"{dev}/power_dpm_force_performance_level")
    if m["temp"]:
        m["temp"] = str(int(m["temp"]) // 1000)
    if m["power"]:
        m["power"] = str(round(int(m["power"]) / 1e6, 1))
    return m


def get_tuning():
    card, dev = amdgpu()
    t = {"ok": bool(dev), "locked_od": True, "levels": ["auto", "low", "high", "manual"]}
    if not dev:
        return t
    t["dpm"] = rd(f"{dev}/power_dpm_force_performance_level")
    od = rd(f"{dev}/pp_od_clk_voltage") or ""
    mm = re.search(r"SCLK:\s+(\d+)Mhz\s+(\d+)Mhz", od)
    if mm:
        t["sclk_min"], t["sclk_max"] = mm.group(1), mm.group(2)
    h = hwmon(dev)
    if h:
        cap = rd(f"{h}/power1_cap")
        if cap:
            t["power_cap"] = round(int(cap) / 1e6)
            t["power_cap_min"] = round(int(rd(f"{h}/power1_cap_min") or 0) / 1e6)
            t["power_cap_max"] = round(int(rd(f"{h}/power1_cap_max") or 0) / 1e6)
    return t


def get_info():
    card, dev = amdgpu()
    i = {"gpu": GPU_NAME, "driver": "amdgpu"}
    if dev:
        i["fw"] = rd(f"{dev}/fw_version")
        i["pci"] = rd(f"{dev}/uevent") and [l.split("=")[1] for l in (rd(f"{dev}/uevent") or "").splitlines() if l.startswith("PCI_ID=")][0]
        i["slot"] = rd(f"{dev}/uevent") and [l.split("=")[1] for l in (rd(f"{dev}/uevent") or "").splitlines() if l.startswith("PCI_SLOT_NAME=")][0]
        i["vram_total"] = rd(f"{dev}/mem_info_vram_total")
    return i


def list_profiles():
    os.makedirs(PROFILE_DIR, exist_ok=True)
    out = []
    for f in sorted(glob.glob(f"{PROFILE_DIR}/*.json")):
        try:
            out.append(json.load(open(f)))
        except (json.JSONDecodeError, OSError):
            pass
    return out


def save_profile(name, dpm):
    os.makedirs(PROFILE_DIR, exist_ok=True)
    safe = re.sub(r"[^A-Za-z0-9._-]", "_", name.strip()) or "profile"
    p = {"name": name.strip(), "dpm": dpm, "saved_at": time.strftime("%Y-%m-%d %H:%M:%S")}
    with open(f"{PROFILE_DIR}/{safe}.json", "w") as f:
        json.dump(p, f, indent=2)
    return p


def stress_status():
    if STRESS["proc"] and STRESS["proc"].poll() is None:
        return {"running": True, "pid": STRESS["proc"].pid}
    return {"running": False}


def stress_start():
    if stress_status()["running"]:
        return {"running": True}
    if glob.glob("/usr/bin/vkmark"):
        cmd = ["vkmark", "--present-mode=headless", "--run-forever"]
    elif glob.glob("/usr/bin/glmark2*"):
        cmd = ["glmark2", "--run-forever"]
        env = dict(os.environ, EGL_PLATFORM="surfaceless")
    else:
        return {"error": "no benchmark found (sudo apt install vkmark)"}
    log = open(STRESS_LOG, "w")
    env = dict(os.environ, EGL_PLATFORM="surfaceless")
    STRESS["proc"] = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, env=env)
    return {"running": True, "pid": STRESS["proc"].pid}


def stress_stop():
    if STRESS["proc"] and STRESS["proc"].poll() is None:
        STRESS["proc"].send_signal(signal.SIGTERM)
        try:
            STRESS["proc"].wait(timeout=5)
        except subprocess.TimeoutExpired:
            STRESS["proc"].kill()
    return stress_status()


# Per-process GPU activity: drm fdinfo engine time deltas + per-process VRAM.
PROCS = {"prev": {}, "t": None}


def get_processes():
    now = time.monotonic()
    stats = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        fdir = f"/proc/{pid}/fdinfo"
        try:
            fds = os.listdir(fdir)
        except OSError:
            continue
        best, vram = 0, 0
        for fd in fds:
            try:
                txt = open(f"{fdir}/{fd}").read()
            except OSError:
                continue
            m = re.search(r"drm-engine-gfx:\s*(\d+)", txt)
            if m:
                best = max(best, int(m.group(1)))
            m = re.search(r"drm-total-vram:\s*(\d+)", txt)
            if m:
                vram += int(m.group(1)) * 1024
        if best > 0:
            stats[pid] = (best, vram)
    elapsed = now - PROCS["t"] if PROCS["t"] else 0
    PROCS["t"] = now
    out = []
    for pid, (ns, vram) in stats.items():
        prev = PROCS["prev"].get(pid, 0)
        delta = ns - prev
        if delta <= 0 or elapsed <= 0:
            continue
        try:
            name = open(f"/proc/{pid}/comm").read().strip()
        except OSError:
            name = "?"
        out.append({"pid": int(pid), "name": name,
                    "vram_mb": round(vram / 1048576, 1),
                    "gfx_pct": min(100.0, round(delta / 1e9 / elapsed * 100, 1))})
    PROCS["prev"] = {p: stats[p][0] for p in stats}
    out.sort(key=lambda p: p["gfx_pct"], reverse=True)
    return out


def reset_shader_cache():
    paths = [os.path.expanduser("~/.cache/mesa_shader_cache"),
             os.path.expanduser("~/.cache/mesa")]
    freed = 0
    for p in paths:
        if os.path.isdir(p):
            for root, _, files in os.walk(p):
                for f in files:
                    fp = os.path.join(root, f)
                    try:
                        freed += os.path.getsize(fp)
                        os.unlink(fp)
                    except OSError:
                        pass
    return {"freed_mb": round(freed / 1e6, 1), "cleared": paths}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj, code=200):
        self._send(code, json.dumps(obj).encode())

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self._send(200, open(f"{APP_DIR}/index.html", "rb").read(), "text/html; charset=utf-8")
        elif self.path == "/api/info":
            self._json(get_info())
        elif self.path == "/api/metrics":
            self._json(get_metrics())
        elif self.path == "/api/processes":
            self._json(get_processes())
        elif self.path == "/api/tuning":
            self._json(get_tuning())
        elif self.path == "/api/profiles":
            self._json(list_profiles())
        elif self.path == "/api/stress":
            self._json(stress_status())
        elif self.path == "/api/stress/log":
            self._send(200, open(STRESS_LOG, "rb").read()[-40000:], "text/plain")
        else:
            self._json({"error": "not found"}, 404)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        try:
            data = json.loads(self.rfile.read(n) or b"{}")
        except json.JSONDecodeError:
            data = {}
        if self.path == "/api/tuning":
            if "power_cap" in data:
                h = hwmon(amdgpu()[1])
                if not h or not rd(f"{h}/power1_cap"):
                    return self._json({"error": "no power1_cap on this GPU"}, 400)
                watts = int(data["power_cap"])
                ok, err = sudo_write(f"{h}/power1_cap", str(watts * 1000000))
                return self._json({"ok": ok, "power_cap": watts if ok else None, "error": err or None}, 200 if ok else 500)
            lvl = data.get("dpm")
            if lvl not in get_tuning()["levels"]:
                return self._json({"error": "bad level"}, 400)
            ok, err = sudo_write(f"{amdgpu()[1]}/power_dpm_force_performance_level", lvl)
            return self._json({"ok": ok, "dpm": lvl if ok else None, "error": err or None}, 200 if ok else 500)
        if self.path == "/api/profiles":
            return self._json(save_profile(data.get("name", ""), data.get("dpm", "")))
        if self.path == "/api/profiles/load":
            for p in list_profiles():
                if p["name"] == data.get("name"):
                    ok, err = sudo_write(f"{amdgpu()[1]}/power_dpm_force_performance_level", p["dpm"])
                    return self._json({"ok": ok, "dpm": p["dpm"], "error": err or None})
            return self._json({"error": "profile not found"}, 404)
        if self.path == "/api/profiles/delete":
            for p in list_profiles():
                if p["name"] == data.get("name"):
                    os.unlink(f"{PROFILE_DIR}/{re.sub(r'[^A-Za-z0-9._-]', '_', p['name'])}.json")
                    return self._json({"ok": True})
            return self._json({"error": "not found"}, 404)
        if self.path == "/api/stress/start":
            return self._json(stress_start())
        if self.path == "/api/stress/stop":
            return self._json(stress_stop())
        if self.path == "/api/shader-cache/reset":
            return self._json(reset_shader_cache())
        if self.path == "/api/reset":
            ok, err = sudo_write(f"{amdgpu()[1]}/power_dpm_force_performance_level", "auto")
            return self._json({"ok": ok, "error": err or None})
        self._json({"error": "not found"}, 404)


if __name__ == "__main__":
    port = int(os.environ.get("ADRENALIN_PORT", "8080"))
    with open("/tmp/adrenalin.pid", "w") as f:
        f.write(str(os.getpid()))
    boot_dpm = os.environ.get("ADRENALIN_BOOT_DPM")
    if boot_dpm:
        dev = amdgpu()[1]
        if dev:
            ok, err = sudo_write(f"{dev}/power_dpm_force_performance_level", boot_dpm)
            print(f"boot DPM={boot_dpm} ok={ok} {err or ''}", flush=True)
    print(f"Adrenalin replica on http://0.0.0.0:{port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()
