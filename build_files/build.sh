#!/bin/bash
# =============================================================================
# System Build Script
# Configures a Fedora-based system with development tools, gaming packages,
# Docker, and various system optimizations.
# =============================================================================

set -eoux pipefail

# Replace the /opt symlink with a real directory so the path becomes immutable
# (prevents downstream layers from accidentally writing through a symlink)
rm -rf /opt && mkdir /opt

# ============================================================
# Pinned versions for direct RPM installs
# Check for updates at the links below and bump as needed.
# ============================================================
# https://github.com/TibixDev/winboat/releases
WINBOAT_VERSION="0.9.0"
# https://github.com/Eugeny/tabby/releases
TABBY_VERSION="1.0.230"
# https://github.com/kem-a/appimage-thumbnailer/releases
APPIMAGE_THUMBNAILER_VERSION="4.0.0"
# https://github.com/bitwarden/clients/releases
BITWARDEN_VERSION="2026.2.1"

# =============================================================================
# Repo Configuration
# Each block imports the signing key and drops a .repo file into yum.repos.d.
# All repos are disabled by default (enabled=0) and opted into only at install
# time via --enablerepo, keeping the base system's metadata footprint small.
# =============================================================================

# RPM Fusion Free — provides open-source media codecs (ffmpeg, gstreamer, etc.)
tee /etc/yum.repos.d/rpmfusion-free.repo <<'EOF'
[rpmfusion-free]
name=RPM Fusion for Fedora $releasever
baseurl=http://download1.rpmfusion.org/free/fedora/releases/$releasever/Everything/$basearch/os/
enabled=0
enabled_metadata=1
gpgcheck=1
gpgkey=file:///usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-$releasever
EOF

# Docker CE — upstream Docker engine, CLI, and compose plugin
rpm --import https://download.docker.com/linux/fedora/gpg
tee /etc/yum.repos.d/docker-ce.repo <<'EOF'
[docker-ce]
name=Docker CE
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=0
enabled_metadata=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF

# Visual Studio Code — Microsoft's official VS Code repo
rpm --import https://packages.microsoft.com/keys/microsoft.asc
tee /etc/yum.repos.d/vscode.repo <<'EOF'
[vscode]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=0
enabled_metadata=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# LACT (Linux GPU Control Application) — GPU overclocking and monitoring
rpm --import https://download.copr.fedorainfracloud.org/results/ilyaz/LACT/pubkey.gpg
tee /etc/yum.repos.d/lact.repo <<'EOF'
[lact]
name=LACT
baseurl=https://download.copr.fedorainfracloud.org/results/ilyaz/LACT/fedora-$releasever-$basearch/
enabled=0
enabled_metadata=1
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/ilyaz/LACT/pubkey.gpg
EOF


# =============================================================================
# Package Installation
# =============================================================================

# Replace the Fedora-bundled ffmpeg stub with the full build from RPM Fusion,
# which includes patented codecs (H.264, AAC, etc.) not shipped by default
dnf5 -y config-manager setopt rpmfusion-nonfree-nvidia-driver.enabled=1
dnf5 -y swap ffmpeg-free --enablerepo=rpmfusion-free ffmpeg --allowerasing

# Install all repo-based packages in a single transaction for efficiency.
# Repos are enabled inline rather than globally to avoid polluting the default
# metadata cache.
#
# Development tools:
#   android-tools             — ADB/fastboot for Android device management
#   code                      — Visual Studio Code editor
#   python3-pip               — Python package installer
#   python3-pyicu             — Python bindings for ICU (Unicode/locale support)
#   rpmdevtools               — RPM packaging utilities
#
# Docker:
#   containerd.io             — container runtime required by Docker CE
#   docker-ce / cli / plugins — Docker engine, CLI, buildx, and compose
#
# Gaming:
#   gamescope                 — Valve's micro-compositor for gaming sessions
#   libratbag-ratbagd         — gaming mouse configuration daemon
#   mangohud                  — in-game performance overlay
#   steam                     — Valve Steam client
#
# GPU & Media:
#   akmods                    — builds kernel modules (e.g. NVIDIA) on upgrade
#   gstreamer1-plugin-*       — additional codec support (H.264, ugly/bad sets)
#   gstreamer1-vaapi          — VA-API hardware video decode/encode via GStreamer
#   lact                      — AMD GPU control application
#   libgee                    — GLib collection library (LACT dependency)
#   libva-nvidia-driver       — VA-API backend for NVIDIA GPUs
#
# System:
#   glycin-thumbnailer        — GNOME image thumbnailer
#   ksshaskpass               — KDE SSH passphrase dialog (integrates with KWallet)
#   nvme-cli                  — NVMe drive management and monitoring CLI
#   webkit2gtk4.1             — WebKit rendering engine for embedded web content
dnf5 -y install \
    --enablerepo=docker-ce \
    --enablerepo=lact \
    --enablerepo=rpmfusion-free \
    --enablerepo=rpmfusion-nonfree-steam \
    --enablerepo=vscode \
    adwaita-icon-theme \
    akmods \
    android-tools \
    code \
    containerd.io \
    docker-ce \
    docker-ce-cli \
    docker-buildx-plugin \
    docker-compose-plugin \
    gamescope \
    glycin-thumbnailer \
    gnome-themes-extra \
    gstreamer1-plugin-openh264 \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-plugins-ugly-free \
    gstreamer1-vaapi \
    ksshaskpass \
    lact \
    libgee \
    libratbag-ratbagd \
    libva-nvidia-driver \
    mangohud \
    nvme-cli \
    python3-pip \
    python3-pyicu \
    rpmdevtools \
    steam \
    webkit2gtk4.1

# Install direct RPMs fetched from upstream release pages.
# Kept in separate dnf5 calls so a single failure is easy to identify and retry.

# Winboat — Wine/Proton game launcher GUI
dnf5 install -y "https://github.com/TibixDev/winboat/releases/download/v${WINBOAT_VERSION}/winboat-${WINBOAT_VERSION}-x86_64.rpm"

# Bitwarden — password manager desktop client
dnf5 install -y "https://github.com/bitwarden/clients/releases/download/desktop-v${BITWARDEN_VERSION}/Bitwarden-${BITWARDEN_VERSION}-x86_64.rpm"

# Tabby — modern GPU-accelerated terminal emulator
dnf5 install -y "https://github.com/Eugeny/tabby/releases/download/v${TABBY_VERSION}/tabby-${TABBY_VERSION}-linux-x64.rpm"

# AppImage Thumbnailer — generates thumbnails for AppImage files in file managers
dnf5 install -y "https://github.com/kem-a/appimage-thumbnailer/releases/download/v${APPIMAGE_THUMBNAILER_VERSION}/appimage-thumbnailer-v${APPIMAGE_THUMBNAILER_VERSION}-1.x86_64.rpm"


# =============================================================================
# Package Removal
# Strip out packages that are unnecessary in this image to reduce size.
# Critical firmware blobs (NVIDIA, AMD µcode, linux-firmware, Realtek) and
# the kernel are explicitly excluded so hardware support is not broken.
# =============================================================================
dnf5 -y remove '*-firmware' thermald firefox \
    --exclude='nvidia-gpu-firmware' \
    --exclude='amd-ucode-firmware' \
    --exclude='linux-firmware*' \
    --exclude='realtek-firmware' \
    --exclude='kernel' \
    --exclude='kernel-*'


# =============================================================================
# System Groups
# Create system groups with fixed GIDs so bind-mounted socket permissions are
# consistent across rebuilds.
# =============================================================================
tee /usr/lib/sysusers.d/steelite.conf <<'EOF'
g docker  998
EOF


# =============================================================================
# Kernel Modules
# =============================================================================

# Load the ntsync module at boot — provides a native futex-based NT sync
# mechanism that improves Wine/Proton synchronization performance
tee /etc/modules-load.d/ntsync.conf <<'EOF'
ntsync
EOF

# Disable NVMe power management latency tolerance — prevents the controller
# from downclocking during I/O bursts
tee /etc/modprobe.d/nvme.conf <<'EOF'
options nvme_core default_ps_max_latency_us=0
EOF


# =============================================================================
# Kernel Tunables (sysctl)
# =============================================================================

# Memory management — tuned for ZRAM swap:
#   vm.swappiness=150                — high swappiness is correct for ZRAM; unlike
#                                      slow disk swap, ZRAM is RAM-speed compressed
#                                      memory so the kernel should use it freely.
#                                      Kernels 5.8+ support values up to 200.
#   vm.page-cluster=0                — disable swap read-ahead; ZRAM has no seek
#                                      penalty so prefetching clusters is pure waste
#   vm.vfs_cache_pressure=50         — balanced inode/dentry cache reclaim
#   vm.dirty_ratio=10                — flush dirty pages when 10% of RAM is dirty
#   vm.dirty_background_ratio=5      — start background writeback at 5%
#   vm.compaction_proactiveness=0    — disable proactive compaction; it runs in the
#                                      background and causes latency spikes that are
#                                      especially noticeable in games
#   vm.watermark_boost_factor=0      — disable watermark boosting; it triggers
#                                      aggressive reclaim after a spiky allocation,
#                                      wasting CPU on workloads that don't need it
#   vm.watermark_scale_factor=125    — widen the gap between low/high watermarks so
#                                      kswapd wakes less often but reclaims more
#                                      when it does, reducing reclaim churn
tee /etc/sysctl.d/99-memory.conf <<'EOF'
vm.swappiness=10
vm.page-cluster=3
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.compaction_proactiveness=0
vm.watermark_boost_factor=0
vm.watermark_scale_factor=75
EOF

# Gaming and development tunables:
#   vm.max_map_count=1048576           — many Proton/Wine games require a high memory
#                                        map count; the default (65530) causes silent
#                                        crashes or launch failures in some titles
#   vm.oom_kill_allocating_task=1      — immediately kill the process that just
#                                        triggered the OOM
#   fs.inotify.max_user_watches        — VS Code and large dev projects exhaust the
#   fs.inotify.max_user_instances        default limits, causing file watchers to
#                                        silently stop working
#   kernel.perf_event_paranoid=1       — allows unprivileged perf access needed by
#                                        MangoHud and other overlay/profiling tools
#   kernel.nmi_watchdog=0              — disables the NMI watchdog, which generates
#                                        periodic NMI interrupts for hang detection;
#                                        unnecessary on a desktop and frees a perf
#                                        counter on each core
#   kernel.sched_latency_ns            — target scheduling latency for the CFS
#   kernel.sched_min_granularity_ns      runqueue; reducing these values lowers
#   kernel.sched_wakeup_granularity_ns   worst-case response time for interactive
#                                        and gaming workloads at the cost of slightly
#                                        higher scheduler overhead
#   kernel.sched_migration_cost_ns     — FX CPUs expose SMT-like topology but with
#   kernel.sched_autogroup_enabled       shared FPUs; these help the scheduler pack
#                                        work efficiently onto modules
#   kernel.numa_balancing=0            — NUMA balancing adds overhead with no benefit
#                                        on single-socket desktop systems
tee /etc/sysctl.d/99-gaming-dev.conf <<'EOF'
vm.max_map_count=1048576
vm.oom_kill_allocating_task=1
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
fs.file-max=2097152
kernel.perf_event_paranoid=1
kernel.nmi_watchdog=0
kernel.sched_autogroup_enabled=1
kernel.numa_balancing=0
kernel.split_lock_mitigate=0
EOF

tee /etc/sysctl.d/99-amd-fx-scheduler.conf <<'EOF'
# These values are tuned for AMD FX (Bulldozer/Piledriver) module topology.
# On modern CPUs (Zen, Intel), remove this file. Defaults are better.
kernel.sched_latency_ns=10000000
kernel.sched_min_granularity_ns=3000000
kernel.sched_wakeup_granularity_ns=4000000
kernel.sched_migration_cost_ns=1000000
EOF


# =============================================================================
# Memory — Swap, Zswap & Transparent Huge Pages
# =============================================================================
# Using https://bytes.are.sexy/l/zswap_tuning as a reference for these tunables.

# Disable zram — using zswap with a dedicated SSD swap partition instead
mkdir -p /etc/systemd
tee /etc/systemd/zram-generator.conf > /dev/null <<'EOF'
# Intentionally empty — zram disabled in favor of zswap+swapfile
EOF

# zswap kernel args — applied by bootc on fresh installs.
# Existing deployments: run `rpm-ostree kargs --append=...` once manually.
mkdir -p /usr/lib/bootloader.d
tee /usr/lib/bootloader.d/zswap.conf <<'EOF'
zswap.enabled=1 zswap.compressor=lz4 zswap.zpool=zsmalloc zswap.max_pool_percent=15
EOF

# Memory tunables — tuned for zswap + disk-backed swap:
#   vm.swappiness=10       — disk is slow; avoid it, let zswap handle pressure
#   vm.page-cluster=3      — restore default read-ahead (disk benefits, unlike zram)
tee /etc/sysctl.d/99-memory.conf <<'EOF'
vm.swappiness=10
vm.page-cluster=3
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.compaction_proactiveness=0
vm.watermark_boost_factor=0
vm.watermark_scale_factor=125
EOF

# Transparent Huge Pages
# Using hhttps://bytes.are.sexy/l/thp_tuning as a reference for these tunables.
# THP: all processes eligible, but no synchronous compaction (gaming-safe)
# khugepaged: large infrequent scans instead of small frequent ones
tee /etc/tmpfiles.d/thp.conf <<'EOF'
w! /sys/kernel/mm/transparent_hugepage/enabled - - - - always
w! /sys/kernel/mm/transparent_hugepage/shmem_enabled - - - - advise
w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise
w! /sys/kernel/mm/transparent_hugepage/khugepaged/pages_to_scan - - - - 2097152
w! /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs - - - - 79000
w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 64
w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_shared - - - - 64
w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_swap - - - - 0
EOF


# =============================================================================
# systemd — OOM, Timeouts & Journal
# =============================================================================
# Using https://bytes.are.sexy/l/systemd_oomd_tuning as a reference for these
# tunables.

# Tune systemd-oomd to act more aggressively than its conservative defaults.
# Without this, oomd can let memory pressure build too long before killing
# anything, effectively negating its purpose on a gaming system.
#   SwapUsedLimit=85%                — intervene when swap is 85% full
#   DefaultMemoryPressureLimit=80%   — trigger on sustained 80% PSI memory
#                                      pressure (vs. the default 60%)
#   DefaultMemoryPressureDurationSec — act after 20s rather than the default 30s
mkdir -p /etc/systemd/oomd.conf.d
tee /etc/systemd/oomd.conf.d/00-tuning.conf <<'EOF'
[OOM]
SwapUsedLimit=85%
DefaultMemoryPressureLimit=80%
DefaultMemoryPressureDurationSec=20s
EOF

# Reduce service start/stop timeouts from the 90s default. On a desktop/gaming
# system a hung unit shouldn't hold up the session or shutdown for that long.
mkdir -p /etc/systemd/system.conf.d
tee /etc/systemd/system.conf.d/00-timeouts.conf <<'EOF'
[Manager]
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=15s
EOF

# Cap the systemd journal at 150 MB to prevent unbounded disk usage
mkdir -p /etc/systemd/journald.conf.d
tee /etc/systemd/journald.conf.d/00-journal-size.conf <<'EOF'
[Journal]
SystemMaxUse=150M
EOF

# Retain core dumps for 3 days, then clean them up automatically
tee /etc/tmpfiles.d/coredump.conf <<'EOF'
d /var/lib/systemd/coredump 0755 root root 3d
EOF


# =============================================================================
# Audio — Realtime Scheduling
# =============================================================================

# Allow the 'audio' group to run threads at realtime priority and lock
# unlimited memory, which PipeWire and JACK require for glitch-free low-latency
# audio. Without these, audio daemons fall back to non-RT scheduling.
mkdir -p /etc/security/limits.d
tee /etc/security/limits.d/99-audio-realtime.conf <<'EOF'
@audio   -  rtprio   95
@audio   -  memlock  unlimited
EOF

# Grant the 'audio' group access to /dev/cpu_dma_latency so real-time audio
# applications (e.g. JACK, PipeWire) can set low DMA latency without root
tee /etc/udev/rules.d/60-cpu-dma-latency.rules <<'EOF'
DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
EOF

# Grant the 'audio' group access to HPET timers so real-time audio applications
# can use them for high-resolution scheduling without root
tee /etc/udev/rules.d/40-hpet-permissions.rules <<'EOF'
KERNEL=="hpet", GROUP="audio"
KERNEL=="rtc0", GROUP="audio"
EOF

# =============================================================================
# Storage — I/O Schedulers & Link Power
# =============================================================================

# Per-device I/O scheduler policy:
#   NVMe  — bypass the kernel scheduler entirely (device has its own queuing)
#   HDDs  — use BFQ for latency fairness across competing processes
#   SSDs  — use mq-deadline for low-latency sequential I/O
tee /etc/udev/rules.d/60-ioschedulers.rules <<'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
EOF

# Force SCSI/SATA link power management to max_performance, preventing the
# host controller from downclocking links to save power (avoids I/O latency
# spikes on spinning drives and some SSDs)
tee /etc/udev/rules.d/61-scsi-link-power.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}=="*", ATTR{link_power_management_policy}="max_performance"
EOF


# =============================================================================
# Gaming — Controllers & GPU Recovery
# =============================================================================

# Grant the 'input' group read/write access to gamepad and joystick nodes so
# emulators and non-Steam games can read controllers without running as root
tee /etc/udev/rules.d/70-gamepad-permissions.rules <<'EOF'
SUBSYSTEM=="input", ATTRS{name}=="*Controller*", GROUP="input", MODE="0660"
SUBSYSTEM=="input", KERNEL=="js[0-9]*", GROUP="input", MODE="0660"
SUBSYSTEM=="input", KERNEL=="event[0-9]*", ATTRS{name}=="*Controller*", GROUP="input", MODE="0660"
EOF

# GPU reset recovery for drm drivers — when the GPU hangs and resets, the
# kernel exposes a RESET event with the PID of the offending process. These
# rules:
#   - On a GPU reset event, kill the owning PID to release the hung context
#   - If the display server (SDDM) is involved, restart it to recover the
#     desktop session cleanly
tee /etc/udev/rules.d/80-gpu-reset.rules <<'EOF'
ACTION=="change", SUBSYSTEM=="drm", ENV{RESET}=="1", ENV{PID}!="0", PROGRAM="/usr/bin/bash -c 'test %E{PID} -gt 1000'", RUN+="/usr/bin/kill -9 %E{PID}"
ACTION=="change", SUBSYSTEM=="drm", ENV{RESET}=="1", ENV{FLAGS}=="1", RUN+="/usr/sbin/systemctl restart sddm"
EOF


# =============================================================================
# Service Enablement
# =============================================================================
systemctl enable \
    containerd.service \
    docker.service \
    lactd.service \
    ratbagd.service \
    systemd-oomd.service


mkdir -p /etc/environment.d
tee /etc/environment.d/50-ssh-askpass.conf <<'EOF'
SSH_ASKPASS=/usr/bin/ksshaskpass
SSH_ASKPASS_REQUIRE=prefer
EOF


# =============================================================================
# Cleanup
# Remove cached package metadata and downloaded RPMs to keep the image lean
# =============================================================================
dnf5 -y clean all
rm -f /var/lib/systemd/random-seed
rm -rf \
    /var/lib/dnf \
    /var/lib/containers \
    /var/log/* \
    /tmp/*