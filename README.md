# Fedora STEELITE

A heavily customized, immutable [Fedora Kinoite](https://fedoraproject.org/kinoite/) image built with [bootc](https://containers.github.io/bootc/), designed for developers and gaming enthusiasts who need a turnkey system with sensible defaults.

> **Hardware target:** This image is tuned specifically for **AMD FX (Bulldozer/Piledriver) CPUs** (FX-4xxx/6xxx/8xxx, ~2011–2014). Scheduler tunables, memory settings, and topology hints reflect that architecture. If you're on Zen, Intel, or any modern CPU, fork this repo and remove `build_files/99-amd-fx-scheduler.conf` — those values will hurt scheduling latency on anything else.

## What's Included

### Development & DevOps
- **Docker** (daemon, CLI, buildx, docker-compose)
- **Visual Studio Code**
- **Tabby** terminal emulator
- **Python 3** with pip
- Android SDK tools

### Gaming & Media
- **Steam** with gaming optimizations
- **MangoHUD** for FPS monitoring and overlay
- **Gamescope** Valve micro-compositor for gaming sessions
- **Winboat** for seamless Windows app integration
- **LACT** for GPU metrics, fan control, and overclocking
- **libratbag** for gaming mouse configuration
- Advanced codec support (OpenH.264, VA-API, GStreamer bad/ugly/freeworld)

### Security & System
- **Bitwarden** desktop with biometric and SSH-Agent support
- ntsync kernel module (native NT sync primitives for Wine/Proton)
- zswap compressed swap cache backed by a dedicated swap partition
- Tuned journald, VM, and I/O scheduler behaviour for performance
- Proper audio and input group management

### Hardware Support
- CPU-DMA latency permissions for real-time audio (`/dev/cpu_dma_latency`)
- SCSI/SATA link power management forced to `max_performance`

## System Optimizations

### Memory & Swap
- **zswap**: Compressed in-RAM cache (lz4 + zsmalloc, up to 20% of RAM) backed by a
  dedicated swap partition. Cold anonymous pages are compressed first; disk is only
  hit when the pool is exhausted. `zswap.shrinker_enabled=1` keeps pool usage low
  proactively. See: [zswap vs zram — when to use what](https://chrisdown.name/2026/03/24/zswap-vs-zram-when-to-use-what.html)
- **vm.swappiness=30**: With zswap the first eviction tier is compressed RAM, not disk.
  A value of 10 (correct for bare disk swap) defeats zswap by refusing to push cold pages
  into the fast compressed pool. 30 keeps file cache hot without hammering the SSD.
- **Transparent HugePage**: `enabled=always`, `defrag=always` — all processes are eligible
  and huge pages are allocated immediately on fault via synchronous compaction. The
  conservative `defer+madvise` mode relies on khugepaged, which scans too infrequently
  (≤8 GB/79s) for short-lived workloads like game launches and parallel builds to benefit.
  khugepaged knobs are tuned to match.

### OOM Management
- **systemd-oomd**: Acts at cgroup granularity — kills the heaviest cgroup under sustained
  PSI memory pressure (20s threshold, down from the 30s default) or when swap reaches
  85% full. This is the primary OOM defence.
- **vm.oom_kill_allocating_task=1**: Last-resort fallback for processes not covered by a
  managed cgroup — kills the task that triggered the kernel OOM killer immediately.

### Scheduler (AMD FX only)
- Wider scheduling latency bands and higher migration cost to account for the shared
  integer cluster design of Bulldozer/Piledriver modules. Remove
  `/etc/sysctl.d/99-amd-fx-scheduler.conf` on any other CPU family.

### Storage & I/O
- **NVMe**: no-op scheduler + `rq_affinity=2` (complete on originating CPU core to avoid
  cache-line bouncing) + 128 KB read-ahead
- **HDD**: BFQ scheduler for latency fairness + 2 MB read-ahead to amortise seek cost
- **SSD/eMMC**: mq-deadline + 512 KB read-ahead

### Miscellaneous
- **systemd-journald**: Capped at 150 MB to prevent log bloat
- **Service timeouts**: Start 30s / stop 15s (down from 90s default)
- **Core dumps**: Retained for 3 days under `/var/lib/systemd/coredump`
- **NVMe power management**: `default_ps_max_latency_us=0` prevents the controller
  from downclocking during I/O bursts
- **udev rules**: GPU reset recovery (kills hung PID, restarts SDDM), ntsync device
  access via `TAG+="uaccess"`, gamepad/joystick permissions for the `input` group

## Building

```bash
just build-image
```

Or use `bootc build` directly if you have containerization tools installed.

## Installation

⚠️ **WARNING**: This is not a standard Fedora image. Review [build_files/build.sh](build_files/build.sh) carefully before deploying. The image makes aggressive changes to the base system that may not suit general-purpose use.

If you understand the implications and want to proceed, follow your container host's bootc deployment procedures. This typically involves either:
- Direct bootc deployment on systems that support it
- Building an ISO with bootc-image-builder for traditional installation

## Customization

To customize for your own needs:
1. Fork this repository
2. Edit [build_files/build.sh](build_files/build.sh) to add/remove packages and configurations
3. Remove or replace `/etc/sysctl.d/99-amd-fx-scheduler.conf` if you're not on AMD FX hardware
4. Optionally adjust the base image in [Containerfile](Containerfile)
5. Build and deploy your variant

## License

See [LICENSE](LICENSE) file for details.