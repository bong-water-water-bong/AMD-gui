# adrenalin.mojo — AMD Adrenalin replica backend (wire-compatible port of
# adrenalin_server.py). Mojo 1.0.0, stdlib only, no community packages.
#
# Build:  mojo build adrenalin.mojo -o adrenalin_server
# Run:    ./adrenalin_server            (port via ADRENALIN_PORT, default 8080)
# Test:   ./adrenalin_server --selftest
#
# Single-threaded accept loop: sysfs reads are sub-ms; sudo is non-blocking
# (sudo -n never prompts); stress stop reaps lazily. ponytail: if a second
# concurrent client ever stalls polls, upgrade to per-connection pthreads
# via FFI; not before.

from std.ffi import external_call, c_int
from std.sys import exit
from std.memory import Pointer, unsafe_memset
from std.os import env, listdir, makedirs, unlink
from std.os.path import exists, expanduser, getsize, isdir, isfile, join, realpath
from std.os.process import Process
from std.collections.string import atol, atof
from std.time import monotonic
from std.collections import List

struct Server:
    """The whole server: state + handlers. Mojo 1.0 has no module globals,
    so everything lives here and is threaded through main()."""

    # ── constants ──────────────────────────────────────────────────────
    @staticmethod
    def sysfs() -> String: return "/sys/class/drm"
    @staticmethod
    def profile_dir() -> String:
        try:
            return expanduser("~/.config/adrenalin-profiles")
        except:
            return "~/.config/adrenalin-profiles"
    @staticmethod
    def stress_log() -> String: return "/tmp/adrenalin-stress.log"
    @staticmethod
    def sudo_err() -> String: return "/tmp/adrenalin-sudo.err"
    @staticmethod
    def gpu_name() -> String: return "AMD Ryzen AI MAX+ 395 (Radeon 8060S)"
    @staticmethod
    def levels() -> List[String]:
        var l = List[String]()
        l.append("auto"); l.append("low"); l.append("high"); l.append("manual")
        return l^
    @staticmethod
    def max_req() -> Int: return 16384

    # ── mutable state ───────────────────────────────────────────────────
    var stress_proc: Optional[Process]
    var stress_stop_ts: Int
    var procs_prev: Dict[String, Int]
    var procs_t: Int

    def __init__(out self):
        self.stress_proc = None
        self.stress_stop_ts = 0
        self.procs_prev = Dict[String, Int]()
        self.procs_t = 0

    # ── libc helpers ────────────────────────────────────────────────────
    @staticmethod
    def libc_kill(pid: Int, sig: Int) -> Bool:
        return external_call["kill", c_int](c_int(pid), c_int(sig)) == 0

    @staticmethod
    def getpid() -> Int:
        return Int(external_call["getpid", c_int]())

    def write_pid_file(self):
        try:
            var f = open("/tmp/adrenalin.pid", "w")
            f.write_string(String(Server.getpid()))
            f.close()
        except:
            pass

    # ── jsonx: minimal JSON emitter/extractor ───────────────────────────
    @staticmethod
    def jesc(s: String) -> String:
        var out = String()
        for i in range(s.byte_length()):
            var b = s[byte=i : i + 1]
            if b == String('"'):
                out += "\\\""
            elif b == String("\\"):
                out += "\\\\"
            elif b == String("\n"):
                out += "\\n"
            elif b == String("\r"):
                out += "\\r"
            elif b == String("\t"):
                out += "\\t"
            elif ord(b) < 32:
                out += "\\u00" + Server.hex2(ord(b))
            else:
                out += b
        return out

    @staticmethod
    def hex2(v: Int) -> String:
        var hex = "0123456789abcdef"
        return hex[byte=v // 16 : v // 16 + 1] + hex[byte=v % 16 : v % 16 + 1]

    @staticmethod
    def minf(a: Float64, b: Float64) -> Float64:
        return a if a < b else b

    @staticmethod
    def atol_safe(s: String) -> Int:
        try:
            return atol(s)
        except:
            return 0

    @staticmethod
    def atof_safe(s: String) -> Float64:
        try:
            return atof(s)
        except:
            return 0.0

    @staticmethod
    def opt_str(o: Optional[String], fallback: String) -> String:
        if o:
            return o.value()
        return fallback

    @staticmethod
    def jstr(s: String) -> String:
        return '"' + Server.jesc(s) + '"'

    @staticmethod
    def jfloat1(v: Float64) -> String:
        var r = round(v * 10.0) / 10.0
        var s = String(r)
        if s.find(".") < 0:
            return s + ".0"
        return s

    @staticmethod
    def jq_str(o: Optional[String]) -> String:
        if o:
            return Server.jstr(o.value())
        return "null"

    @staticmethod
    def jnum_str(o: Optional[String]) -> String:
        if o:
            return o.value()
        return "null"

    @staticmethod
    @staticmethod
    def wire_name(wk: String) -> String:
        if wk == "vram_used": return "mem_info_vram_used"
        if wk == "vram_total": return "mem_info_vram_total"
        if wk == "gtt_used": return "mem_info_gtt_used"
        if wk == "gtt_total": return "mem_info_gtt_total"
        if wk == "mem_busy": return "mem_busy_percent"
        return "vcn_busy_percent"

    @staticmethod
    def jstr_arr(a: List[String]) -> String:
        var parts = List[String]()
        for s in a:
            parts.append(Server.jstr(s))
        return "[" + ", ".join(parts) + "]"

    @staticmethod
    def join_parts(parts: List[String]) -> String:
        return "{" + ", ".join(parts) + "}"

    # ── file helpers ────────────────────────────────────────────────────
    @staticmethod
    def rd(path: String) -> Optional[String]:
        try:
            var f = open(path, "r")
            var s = f.read()
            f.close()
            return String(s.strip())
        except:
            return None

    @staticmethod
    def file_tail(path: String, maxbytes: Int) -> String:
        try:
            var size = getsize(path)
            var f = open(path, "r")
            if size > maxbytes:
                f.seek(size - maxbytes, 0)
            var s = f.read()
            f.close()
            return s
        except:
            return String()

    # ── sysfs discovery ─────────────────────────────────────────────────
    @staticmethod
    def amdgpu() -> Tuple[String, String]:
        var cards = List[String]()
        try:
            for c in listdir(Server.sysfs()):
                cards.append(c)
        except:
            pass
        for card in cards:
            if not card.startswith("card"):
                continue
            var dev = join(join(Server.sysfs(), card), "device")
            try:
                var drv = realpath(join(dev, "driver"))
                if drv.endswith("amdgpu"):
                    return join(Server.sysfs(), card), dev
            except:
                pass
        return String(), String()

    @staticmethod
    def hwmon(dev: String) -> String:
        try:
            for h in listdir(join(dev, "hwmon")):
                var p = join(join(dev, "hwmon"), h)
                try:
                    var f = open(join(p, "name"), "r")
                    var n = f.read().strip()
                    f.close()
                    if n == "amdgpu":
                        return p
                except:
                    pass
        except:
            pass
        return String()

    @staticmethod
    def all_digits(s: String) -> Bool:
        if s.byte_length() == 0:
            return False
        for i in range(s.byte_length()):
            if not Server.isdigit_byte(s[byte=i : i + 1]):
                return False
        return True

    @staticmethod
    def isdigit_byte(b: StringSpan) -> Bool:
        var c = ord(b)
        return c >= 48 and c <= 57

    @staticmethod
    def parse_sclk(od: String) -> List[String]:
        # "SCLK: 600Mhz 2900Mhz" — two number runs, no regex
        var out = List[String]()
        var i = od.find("SCLK:")
        if i < 0:
            return out^
        var rest = od[byte=i + 5 :]
        var nums = 0
        var j = 0
        while j < rest.byte_length() and nums < 2:
            if Server.isdigit_byte(rest[byte=j : j + 1]):
                var start = j
                while j < rest.byte_length() and Server.isdigit_byte(rest[byte=j : j + 1]):
                    j += 1
                out.append(String(rest[byte=start:j]))
                nums += 1
            else:
                j += 1
        return out^

    @staticmethod
    def parse_u64_after(s: String, needle: String) -> Int:
        var i = s.find(needle)
        if i < 0:
            return 0
        var rest = s[byte=i + needle.byte_length() :]
        var j = 0
        while j < rest.byte_length() and not Server.isdigit_byte(rest[byte=j : j + 1]):
            j += 1
        var start = j
        while j < rest.byte_length() and Server.isdigit_byte(rest[byte=j : j + 1]):
            j += 1
        if j == start:
            return 0
        return Server.atol_safe(String(rest[byte=start:j]))

    # ── sudo write: fixed operands only ─────────────────────────────────
    @staticmethod
    def sudo_write(path: String, value: String) -> Tuple[Bool, String]:
        var cmd = (
            "printf %s '" + value + "' | sudo -n tee '" + path
            + "' 2>" + Server.sudo_err()
        )
        try:
            var p = Process.run("/bin/sh", ["-c", cmd])
            var st = p.wait()
            var err = Server.opt_str(Server.rd(Server.sudo_err()), "")
            if st.exit_code.value() != 0:
                return False, err
            return True, err
        except:
            return False, String("sudo spawn failed")

    # ── metrics / tuning / info ─────────────────────────────────────────
    def get_metrics(self) -> String:
        var card, dev = Server.amdgpu()
        if not dev:
            return '{"ok": false}'
        var h = Server.hwmon(dev)
        var parts = List[String]()
        parts.append('"ok": true')
        parts.append('"busy": ' + Server.jq_str(Server.rd(join(dev, "gpu_busy_percent"))))
        if h:
            var sclk = Server.rd(join(h, "freq1_input"))
            if sclk:
                parts.append('"sclk": "' + String(Server.atol_safe(sclk.value()) // 1000000) + '"')
            var temp = Server.rd(join(h, "temp1_input"))
            if temp:
                parts.append('"temp": "' + String(Server.atol_safe(temp.value()) // 1000) + '"')
            var power = Server.rd(join(h, "power1_average"))
            if power:
                parts.append('"power": "' + Server.jfloat1(Server.atof_safe(power.value()) / 1e6) + '"')
        for wk in ["vram_used", "vram_total", "gtt_used", "gtt_total", "mem_busy", "vcn_busy"]:
            var wire_name = Server.wire_name(wk)
            var v = Server.rd(join(dev, wire_name))
            parts.append(Server.jstr(wk) + ": " + Server.jq_str(v))
        var dpm = Server.rd(join(dev, "power_dpm_force_performance_level"))
        if dpm:
            parts.append('"dpm": ' + Server.jstr(dpm.value()))
        return Server.join_parts(parts)

    def get_tuning(self) -> String:
        var card, dev = Server.amdgpu()
        var parts = List[String]()
        parts.append('"ok": ' + ("true" if dev else "false"))
        parts.append('"locked_od": true')
        parts.append('"levels": ["auto", "low", "high", "manual"]')
        if dev:
            var dpm = Server.rd(join(dev, "power_dpm_force_performance_level"))
            if dpm:
                parts.append('"dpm": ' + Server.jstr(dpm.value()))
            var od = Server.rd(join(dev, "pp_od_clk_voltage"))
            if od:
                var mm = Server.parse_sclk(od.value())
                if mm.__len__() == 2:
                    parts.append('"sclk_min": "' + mm[0] + '"')
                    parts.append('"sclk_max": "' + mm[1] + '"')
            var h = Server.hwmon(dev)
            if h:
                var cap = Server.rd(join(h, "power1_cap"))
                if cap:
                    parts.append('"power_cap": ' + String(Server.atol_safe(cap.value()) // 1000000))
                    var cmin = Server.rd(join(h, "power1_cap_min"))
                    if cmin:
                        parts.append('"power_cap_min": ' + String(Server.atol_safe(cmin.value()) // 1000000))
                    var cmax = Server.rd(join(h, "power1_cap_max"))
                    if cmax:
                        parts.append('"power_cap_max": ' + String(Server.atol_safe(cmax.value()) // 1000000))
        return Server.join_parts(parts)

    def get_info(self) -> String:
        var card, dev = Server.amdgpu()
        var parts = List[String]()
        parts.append('"gpu": ' + Server.jstr(Server.gpu_name()))
        parts.append('"driver": "amdgpu"')
        if dev:
            var fw = Server.rd(join(dev, "fw_version"))
            if fw:
                parts.append('"fw": ' + Server.jstr(fw.value()))
            else:
                parts.append('"fw": null')
            var ue = Server.rd(join(dev, "uevent"))
            if ue:
                for line in ue.value().split("\n"):
                    if line.startswith("PCI_ID="):
                        parts.append('"pci": ' + Server.jstr(String(line[byte=7:])))
                    elif line.startswith("PCI_SLOT_NAME="):
                        parts.append('"slot": ' + Server.jstr(String(line[byte=14:])))
            var vt = Server.rd(join(dev, "mem_info_vram_total"))
            if vt:
                parts.append('"vram_total": ' + Server.jstr(vt.value()))
        return Server.join_parts(parts)

    # ── per-process GPU activity (fdinfo) ───────────────────────────────
    def get_processes(mut self) -> String:
        var now = monotonic()
        var stats = Dict[String, Tuple[Int, Int]]()  # pid -> (engine_ns, vram_bytes)
        var proc_dirs = List[String]()
        try:
            for d in listdir("/proc"):
                proc_dirs.append(d)
        except:
            pass
        for pid in proc_dirs:
            if not Server.all_digits(pid):
                continue
            var fdir = join(join("/proc", pid), "fdinfo")
            var fds = List[String]()
            try:
                for f in listdir(fdir):
                    fds.append(f)
            except:
                continue
            var best = 0
            var vram = 0
            for fd in fds:
                var txt = Server.rd(join(fdir, fd))
                if not txt:
                    continue
                var ns = Server.parse_u64_after(txt.value(), "drm-engine-gfx:")
                if ns > best:
                    best = ns
                vram += Server.parse_u64_after(txt.value(), "drm-total-vram:") * 1024
            if best > 0:
                stats[pid] = (best, vram)
        var elapsed = Float64(now - self.procs_t) / 1e9 if self.procs_t > 0 else 0.0
        self.procs_t = now
        var out = List[String]()
        for pid in stats.keys():
            var prev = self.procs_prev.get(pid, 0)
            var ns = stats.get(pid, (0, 0))[0]
            var delta = ns - prev
            if delta <= 0 or elapsed <= 0.0:
                continue
            var name = Server.opt_str(Server.rd(join(join("/proc", pid), "comm")), "?")
            var pct = Server.minf(100.0, round(Float64(delta) / 1e9 / Float64(elapsed) * 100.0 * 10.0) / 10.0)
            var vmb = Float64(stats.get(pid, (0, 0))[1]) / 1048576.0
            out.append(
                '{"pid": ' + pid + ', "name": ' + Server.jstr(name)
                + ', "vram_mb": ' + Server.jfloat1(vmb)
                + ', "gfx_pct": ' + Server.jfloat1(pct) + "}"
            )
        self.procs_prev.clear()
        for pid in stats.keys():
            self.procs_prev[pid] = stats.get(pid, (0, 0))[0]
        return "[" + ", ".join(out) + "]"

    # ── profiles ────────────────────────────────────────────────────────
    @staticmethod
    def sanitize(name: String) -> String:
        # byte-level scan: no slicing (avoids mid-codepoint spans), non-ASCII
        # bytes map to '_' (Python regex replaced each codepoint with one '_';
        # byte scan yields one '_' per byte — filename-only cosmetic)
        var out = String()
        var p = name.unsafe_ptr()
        for i in range(name.byte_length()):
            var c = Int(p[i])
            if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 46 or c == 95 or c == 45:
                out += chr(c)
            else:
                out += "_"
        if out.byte_length() == 0:
            return "profile"
        return out

    def list_profiles(self) -> String:
        try:
            makedirs(Server.profile_dir(), exist_ok=True)
        except:
            pass
        var names = List[String]()
        try:
            for f in listdir(Server.profile_dir()):
                if f.endswith(".json"):
                    names.append(f)
        except:
            pass
        # insertion sort (tiny lists; List has no sort in 1.0)
        for i in range(1, names.__len__()):
            var key = names[i]
            var j = i - 1
            while j >= 0 and names[j] > key:
                names[j + 1] = names[j]
                j -= 1
            names[j + 1] = key
        var out = List[String]()
        for f in names:
            var txt = Server.rd(join(Server.profile_dir(), f))
            if not txt:
                continue
            var name = Server.extract_string(txt.value(), "name")
            var dpm = Server.extract_string(txt.value(), "dpm")
            var saved = Server.extract_string(txt.value(), "saved_at")
            if not name or not dpm or not saved:
                continue
            out.append(
                '{"name": ' + Server.jstr(name.value()) + ', "dpm": ' + Server.jstr(dpm.value())
                + ', "saved_at": ' + Server.jstr(saved.value()) + "}"
            )
        return "[" + ", ".join(out) + "]"

    def save_profile(self, name_in: String, dpm: String) -> String:
        var name = String(name_in.strip())
        var saved = self.now_str()
        var p = (
            '{\n  "name": ' + Server.jstr(name)
            + ',\n  "dpm": ' + Server.jstr(dpm)
            + ',\n  "saved_at": ' + Server.jstr(saved) + "\n}\n"
        )
        try:
            makedirs(Server.profile_dir(), exist_ok=True)
            var f = open(join(Server.profile_dir(), Server.sanitize(name) + ".json"), "w")
            f.write_string(p)
            f.close()
        except:
            pass
        return '{"name": ' + Server.jstr(name) + ', "dpm": ' + Server.jstr(dpm) + ', "saved_at": ' + Server.jstr(saved) + "}"

    @staticmethod
    def now_str() -> String:
        # no strftime in 1.0 stdlib — one date(1) spawn per save is fine
        var cmd = "date '+%Y-%m-%d %H:%M:%S' > /tmp/adrenalin-now.txt"
        try:
            var p = Process.run("/bin/sh", ["-c", cmd])
            _ = p.wait()
        except:
            pass
        return Server.opt_str(Server.rd("/tmp/adrenalin-now.txt"), "1970-01-01 00:00:00")

    # ── stress test ─────────────────────────────────────────────────────
    def stress_status(mut self) -> String:
        if self.stress_proc:
            try:
                var st = self.stress_proc.value().poll()
                if not st.exit_code:
                    # still running — escalate SIGTERM→SIGKILL after 5 s
                    if self.stress_stop_ts > 0 and Float64(monotonic() - self.stress_stop_ts) / 1e9 > 5.0:
                        Server.libc_kill(Int(self.stress_proc.value().child_pid), 9)
                    return '{"running": true, "pid": ' + String(Int(self.stress_proc.value().child_pid)) + "}"
                self.stress_proc = None
                self.stress_stop_ts = 0
            except:
                pass
        return '{"running": false}'

    def stress_start(mut self) -> String:
        if self.stress_proc:
            return '{"running": true}'
        var cmd = String()
        if isfile("/usr/bin/vkmark"):
            cmd = "exec env EGL_PLATFORM=surfaceless vkmark --present-mode=headless --run-forever > " + Server.stress_log() + " 2>&1"
        else:
            var found = String()
            try:
                for b in listdir("/usr/bin"):
                    if b.startswith("glmark2"):
                        found = b
                        break
            except:
                pass
            if found:
                cmd = "exec env EGL_PLATFORM=surfaceless " + found + " --run-forever > " + Server.stress_log() + " 2>&1"
            else:
                return '{"error": "no benchmark found (sudo apt install vkmark)"}'
        try:
            var p = Process.run("/bin/sh", ["-c", cmd])
            var pid = Int(p.child_pid)
            self.stress_proc = p^
            self.stress_stop_ts = 0
            return '{"running": true, "pid": ' + String(pid) + "}"
        except:
            return '{"error": "spawn failed"}'

    def stress_stop(mut self) -> String:
        if self.stress_proc:
            Server.libc_kill(Int(self.stress_proc.value().child_pid), 15)  # SIGTERM
            self.stress_stop_ts = monotonic()
        return self.stress_status()

    # ── shader cache reset ──────────────────────────────────────────────
    def reset_shader_cache(self) -> String:
        var paths = List[String]()
        paths.append(Server.expand("~/.cache/mesa_shader_cache"))
        paths.append(Server.expand("~/.cache/mesa"))
        var freed = 0
        for p in paths:
            freed += self.walk_unlink(p)
        return '{"freed_mb": ' + Server.jfloat1(Float64(freed) / 1e6) + ', "cleared": ' + Server.jstr_arr(paths) + "}"

    @staticmethod
    def expand(p: String) -> String:
        try:
            return expanduser(p)
        except:
            return p

    def walk_unlink(self, p: String) -> Int:
        var total = 0
        try:
            if not isdir(p):
                return 0
            for e in listdir(p):
                var full = join(p, e)
                if isdir(full):
                    total += self.walk_unlink(full)
                else:
                    try:
                        total += getsize(full)
                        unlink(full)
                    except:
                        pass
        except:
            pass
        return total

    # ── JSON extractor for POST bodies / profile files ──────────────────
    @staticmethod
    def extract_string(body: String, key: String) -> Optional[String]:
        var needle = '"' + key + '"'
        var i = body.find(needle)
        if i < 0:
            return None
        var rest = body[byte=i + needle.byte_length() :]
        var j = 0
        while j < rest.byte_length() and rest[byte=j : j + 1] != String(":"):
            j += 1
        while j < rest.byte_length() and rest[byte=j : j + 1] != String('"'):
            j += 1
        if j >= rest.byte_length():
            return None
        j += 1
        var out = String()
        while j < rest.byte_length():
            var b = rest[byte=j : j + 1]
            if b == String("\\") and j + 1 < rest.byte_length():
                var n = rest[byte=j + 1 : j + 2]
                if n == String('"') or n == String("\\"):
                    out += n
                elif n == String("n"):
                    out += "\n"
                else:
                    out += n
                j += 2
            elif b == String('"'):
                return out
            else:
                out += b
                j += 1
        return None

    @staticmethod
    def extract_int(body: String, key: String) -> Optional[Int]:
        var needle = '"' + key + '"'
        var i = body.find(needle)
        if i < 0:
            return None
        var rest = body[byte=i + needle.byte_length() :]
        var j = 0
        while j < rest.byte_length() and rest[byte=j : j + 1] != String(":"):
            j += 1
        while j < rest.byte_length() and not Server.isdigit_byte(rest[byte=j : j + 1]):
            j += 1
        if j >= rest.byte_length():
            return None
        var start = j
        while j < rest.byte_length() and Server.isdigit_byte(rest[byte=j : j + 1]):
            j += 1
        return Server.atol_safe(String(rest[byte=start:j]))

    # ── HTTP layer (libc sockets, Connection: close) ────────────────────
    @staticmethod
    def reason(code: Int) -> String:
        if code == 200:
            return "OK"
        if code == 400:
            return "Bad Request"
        if code == 404:
            return "Not Found"
        if code == 500:
            return "Internal Server Error"
        if code == 501:
            return "Not Implemented"
        return "OK"

    @staticmethod
    def ptr_to_string(p: Int, n: Int) -> String:
        var s = String()
        var pp = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=p)
        for i in range(n):
            s += chr(Int(pp[i]))
        return s

    @staticmethod
    def index_path() -> String:
        try:
            var exe = realpath("/proc/self/exe")
            var i = exe.rfind("/")
            if i >= 0:
                return exe[byte=0:i] + "/index.html"
        except:
            pass
        return "index.html"

    def handle_client(mut self, c: Int):
        var bufp = external_call["malloc", Int](Server.max_req())
        var total = 0
        var headers_end = -1
        var hp = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=bufp)
        var clen = 0
        while total < Server.max_req():
            var n = external_call["recv", c_int](c, bufp + total, c_int(4096), c_int(0))
            if n <= 0:
                break
            total += Int(n)
            if headers_end < 0:
                for i in range(0, total - 3):
                    if Int(hp[i]) == 13 and Int(hp[i + 1]) == 10 and Int(hp[i + 2]) == 13 and Int(hp[i + 3]) == 10:
                        headers_end = i
                        break
            if headers_end >= 0 and clen == 0:
                # Content-Length from the header block so we know when the body is complete
                var head = Server.ptr_to_string(bufp, headers_end)
                for line in head.split("\r\n"):
                    if line.startswith("Content-Length:") and clen == 0:
                        clen = Server.atol_safe(String(line[byte=15:].strip()))
            if headers_end >= 0 and total >= headers_end + 4 + clen:
                break
        var req = Server.ptr_to_string(bufp, total)
        var code = 400
        var ctype = "text/plain"
        var body = "bad request"
        if headers_end >= 0:
            var head = req[byte=0:headers_end]
            var lines = head.split("\r\n")
            var reqline = lines[0].split(" ")
            if reqline.__len__() >= 2:
                var method = String(reqline[0])
                var path = String(reqline[1])
                var post_body = String()
                if method == "POST" and clen > 0 and headers_end + 4 + clen <= total:
                    post_body = String(req[byte=headers_end + 4 : headers_end + 4 + clen])
                code, ctype, body = self.dispatch(method, path, post_body)
        var resp = (
            "HTTP/1.1 " + String(code) + " " + Server.reason(code) + "\r\n"
            + "Content-Type: " + ctype + "\r\n"
            + "Content-Length: " + String(body.byte_length()) + "\r\n"
            + "Connection: close\r\n\r\n" + body
        )
        var sent = external_call["send", c_int](c, Int(resp.unsafe_ptr()), c_int(resp.byte_length()), c_int(0x4000))
        _ = sent
        _ = external_call["free", c_int](bufp)

    def serve(mut self, port: Int):
        var fd = external_call["socket", c_int](c_int(2), c_int(1), c_int(0))
        if fd < 0:
            print("socket failed")
            return
        var yes_addr = external_call["malloc", Int](4)
        var yesp = Pointer[c_int, MutUntrackedOrigin](unsafe_from_address=yes_addr)
        yesp[0] = 1
        _ = external_call["setsockopt", c_int](fd, c_int(1), c_int(2), yes_addr, c_int(4))
        # SO_RCVTIMEO 10 s: struct timeval = 2×Int64
        var tv = external_call["malloc", Int](16)
        var tvp = Pointer[Int64, MutUntrackedOrigin](unsafe_from_address=tv)
        tvp[0] = 10
        tvp[1] = 0
        var sa = external_call["malloc", Int](16)
        var sap = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=sa)
        unsafe_memset(sap, 0, 16)
        sap[0] = 2  # AF_INET
        var p = UInt16(port)
        sap[2] = UInt8(p >> 8)
        sap[3] = UInt8(p & 0xFF)
        if external_call["bind", c_int](fd, sa, c_int(16)) != 0:
            print("bind failed (port in use?)")
            return
        _ = external_call["listen", c_int](fd, c_int(16))
        print("Adrenalin replica on http://0.0.0.0:" + String(port), flush=True)
        while True:
            var c = external_call["accept", c_int](fd, 0, 0)
            if c < 0:
                continue
            _ = external_call["setsockopt", c_int](c, c_int(1), c_int(20), tv, c_int(16))  # SO_RCVTIMEO
            self.handle_client(Int(c))
            _ = external_call["close", c_int](c)

    # ── router ──────────────────────────────────────────────────────────
    def dispatch(mut self, method: String, path: String, body: String) -> Tuple[Int, String, String]:
        if method == "GET":
            if path == "/" or path == "/index.html":
                try:
                    var f = open(Server.index_path(), "r")
                    var html = f.read()
                    f.close()
                    return 200, "text/html; charset=utf-8", html
                except:
                    return 500, "text/plain", "index.html missing"
            if path == "/api/info":
                return 200, "application/json", self.get_info()
            if path == "/api/metrics":
                return 200, "application/json", self.get_metrics()
            if path == "/api/processes":
                return 200, "application/json", self.get_processes()
            if path == "/api/tuning":
                return 200, "application/json", self.get_tuning()
            if path == "/api/profiles":
                return 200, "application/json", self.list_profiles()
            if path == "/api/stress":
                return 200, "application/json", self.stress_status()
            if path == "/api/stress/log":
                return 200, "text/plain", Server.file_tail(Server.stress_log(), 40000)
            return 404, "application/json", '{"error": "not found"}'
        if method == "POST":
            if path == "/api/tuning":
                var cap = Server.extract_int(body, "power_cap")
                if cap:
                    var card, dev = Server.amdgpu()
                    var h = Server.hwmon(dev) if dev else String()
                    if not h or not isfile(join(h, "power1_cap")):
                        return 400, "application/json", '{"error": "no power1_cap on this GPU"}'
                    var ok, err = Server.sudo_write(join(h, "power1_cap"), String(cap.value() * 1000000))
                    if ok:
                        return 200, "application/json", '{"ok": true, "power_cap": ' + String(cap.value()) + ', "error": null}'
                    return 500, "application/json", '{"ok": false, "power_cap": null, "error": ' + Server.jstr(err) + "}"
                var lvl = Server.extract_string(body, "dpm")
                if lvl:
                    var v = lvl.value()
                    var in_levels = False
                    for l in Server.levels():
                        if l == v:
                            in_levels = True
                    if not in_levels:
                        return 400, "application/json", '{"error": "bad level"}'
                    var card, dev = Server.amdgpu()
                    var ok, err = Server.sudo_write(join(dev, "power_dpm_force_performance_level"), v)
                    if ok:
                        return 200, "application/json", '{"ok": true, "dpm": ' + Server.jstr(v) + ', "error": null}'
                    return 500, "application/json", '{"ok": false, "dpm": null, "error": ' + Server.jstr(err) + "}"
                return 500, "application/json", '{"ok": false, "dpm": null, "error": null}'
            if path == "/api/profiles":
                var name = Server.extract_string(body, "name")
                var dpm = Server.extract_string(body, "dpm")
                if name and dpm:
                    return 200, "application/json", self.save_profile(name.value(), dpm.value())
                return 400, "application/json", '{"error": "bad profile"}'
            if path == "/api/profiles/load":
                var name = Server.extract_string(body, "name")
                if name:
                    var t = self.find_profile_dpm(name.value())
                    if t:
                        var card, dev = Server.amdgpu()
                        var ok, err = Server.sudo_write(join(dev, "power_dpm_force_performance_level"), t.value())
                        return 200, "application/json", '{"ok": ' + ("true" if ok else "false") + ', "dpm": ' + Server.jstr(t.value()) + ', "error": ' + Server.jstr(err) + "}"
                    return 404, "application/json", '{"error": "profile not found"}'
                return 404, "application/json", '{"error": "profile not found"}'
            if path == "/api/profiles/delete":
                var name = Server.extract_string(body, "name")
                if name:
                    var f = self.find_profile_file(name.value())
                    if f:
                        try:
                            unlink(f.value())
                            return 200, "application/json", '{"ok": true}'
                        except:
                            return 500, "application/json", '{"ok": false}'
                    return 404, "application/json", '{"error": "not found"}'
                return 404, "application/json", '{"error": "not found"}'
            if path == "/api/stress/start":
                return 200, "application/json", self.stress_start()
            if path == "/api/stress/stop":
                return 200, "application/json", self.stress_stop()
            if path == "/api/shader-cache/reset":
                return 200, "application/json", self.reset_shader_cache()
            if path == "/api/reset":
                var card, dev = Server.amdgpu()
                var ok, err = Server.sudo_write(join(dev, "power_dpm_force_performance_level"), "auto")
                return 200, "application/json", '{"ok": ' + ("true" if ok else "false") + ', "error": ' + Server.jstr(err) + "}"
            return 404, "application/json", '{"error": "not found"}'
        return 501, "text/plain", "unsupported method"

    def find_profile_dpm(self, name: String) -> Optional[String]:
        var f = self.find_profile_file(name)
        if not f:
            return None
        var txt = Server.rd(f.value())
        if not txt:
            return None
        return Server.extract_string(txt.value(), "dpm")

    def find_profile_file(self, name: String) -> Optional[String]:
        try:
            makedirs(Server.profile_dir(), exist_ok=True)
            for f in listdir(Server.profile_dir()):
                if not f.endswith(".json"):
                    continue
                var txt = Server.rd(join(Server.profile_dir(), f))
                if not txt:
                    continue
                var n = Server.extract_string(txt.value(), "name")
                if n and n.value() == name:
                    return join(Server.profile_dir(), f)
        except:
            pass
        return None

    # ── selftest ────────────────────────────────────────────────────────
    def selftest(self) -> Int:
        var fails = 0
        var m = Server.parse_sclk("OD_RANGE: SCLK: 600Mhz 2900Mhz")
        if m.__len__() == 2 and m[0] == "600" and m[1] == "2900":
            print("PASS parse_sclk")
        else:
            print("FAIL parse_sclk"); fails += 1
        if Server.parse_sclk("no match here").__len__() == 0:
            print("PASS parse_sclk none")
        else:
            print("FAIL parse_sclk none"); fails += 1
        var sane = Server.sanitize("a b/é")
        if sane == "a_b___" or sane == "a_b__":
            print("PASS sanitize")
        else:
            print("FAIL sanitize got", sane); fails += 1
        if Server.sanitize("") == "profile":
            print("PASS sanitize empty")
        else:
            print("FAIL sanitize empty"); fails += 1
        var esc = Server.jstr('a"b\\c')
        if esc == '"a\\"b\\\\c"':
            print("PASS jesc")
        else:
            print("FAIL jesc got", esc); fails += 1
        var e1 = Server.extract_string('{"name": "hi there", "dpm": "high"}', "dpm")
        if e1 and e1.value() == "high":
            print("PASS extract_string")
        else:
            print("FAIL extract_string"); fails += 1
        var e2 = Server.extract_string('{"name": "a \\"quoted\\" name"}', "name")
        if e2 and e2.value() == 'a "quoted" name':
            print("PASS extract_string escapes")
        else:
            print("FAIL extract_string escapes"); fails += 1
        var e3 = Server.extract_int('{"power_cap": 300}', "power_cap")
        if e3 and e3.value() == 300:
            print("PASS extract_int")
        else:
            print("FAIL extract_int"); fails += 1
        var ns = Server.parse_u64_after("drm-engine-gfx:\t78813653802 ns", "drm-engine-gfx:")
        if ns == 78813653802:
            print("PASS fdinfo engine ns")
        else:
            print("FAIL fdinfo ns", ns); fails += 1
        var vram = Server.parse_u64_after("drm-total-vram:\t172080 KiB", "drm-total-vram:")
        if vram == 172080:
            print("PASS fdinfo vram")
        else:
            print("FAIL fdinfo vram", vram); fails += 1
        var w = Server.atol_safe("317000000") // 1000000
        if w == 317:
            print("PASS power cap uW->W")
        else:
            print("FAIL cap", w); fails += 1
        if Server.jfloat1(79.43) == "79.4":
            print("PASS jfloat1")
        else:
            print("FAIL jfloat1", Server.jfloat1(79.43)); fails += 1
        print("SELFTEST PASS" if fails == 0 else "SELFTEST FAIL: " + String(fails))
        return 1 if fails > 0 else 0


def main():
    var argv = List[String]()
    try:
        var p = open("/proc/self/cmdline", "r")
        var raw = p.read()
        p.close()
        for part in raw.split("\0"):
            if part:
                argv.append(String(part))
    except:
        pass
    var srv = Server()
    if argv.__len__() > 1 and argv[1] == "--selftest":
        exit(srv.selftest())
    var boot = env.getenv("ADRENALIN_BOOT_DPM", "")
    if boot:
        var card, dev = Server.amdgpu()
        if dev:
            var ok, err = Server.sudo_write(join(dev, "power_dpm_force_performance_level"), boot)
            print("boot DPM=" + boot + " ok=" + String(ok) + " " + err, flush=True)
    srv.write_pid_file()
    var port = 8080
    var pe = env.getenv("ADRENALIN_PORT", "")
    if pe:
        try:
            port = atol(pe)
        except:
            pass
    srv.serve(port)
