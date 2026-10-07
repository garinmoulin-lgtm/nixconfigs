pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU / memory / disk, shared by every bar (replaces waybar's cpu, memory and disk modules).
Singleton {
    id: root

    property int cpuUsage: 0
    property real memUsedGiB: 0
    property int diskUsed: 0
    property var lastCpu: null

    // cpu + memory: interval = 1 (like your waybar config); reads /proc directly, no processes
    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + (f[4] || 0);
            const total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu !== null) {
                const dt = total - root.lastCpu.total;
                const di = idle - root.lastCpu.idle;
                if (dt > 0)
                    root.cpuUsage = Math.round((1 - di / dt) * 100);
            }
            root.lastCpu = { total: total, idle: idle };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = meminfo.text();
            const total = t.match(/MemTotal:\s+(\d+)/);
            const avail = t.match(/MemAvailable:\s+(\d+)/);
            if (total && avail)
                root.memUsedGiB = (Number(total[1]) - Number(avail[1])) / 1048576;
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
        }
    }

    // disk: interval = 30, path = "/"  (same math as waybar: 100 - available/total)
    Process {
        id: df
        command: ["stat", "-f", "-c", "%b %a", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(" ").map(Number);
                if (p[0] > 0)
                    root.diskUsed = Math.round(100 - p[1] / p[0] * 100);
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }
}
