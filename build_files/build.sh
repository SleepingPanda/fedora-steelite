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
# Check for updates at the links below automatically.
# ============================================================
# https://github.com/TibixDev/winboat/releases
WINBOAT_VERSION=$(curl -s "https://api.github.com/repos/TibixDev/winboat/releases/latest" | grep -oP '"tag_name"\s*:\s*"\K[^"]+' | head -1 | grep -oP '(?<=v).*')
# https://github.com/Eugeny/tabby/releases
TABBY_VERSION=$(curl -s "https://api.github.com/repos/Eugeny/tabby/releases/latest" | grep -oP '"tag_name"\s*:\s*"\K[^"]+' | head -1 | grep -oP '(?<=v).*')
# https://github.com/kem-a/appimage-thumbnailer/releases
APPIMAGE_THUMBNAILER_VERSION=$(curl -s "https://api.github.com/repos/kem-a/appimage-thumbnailer/releases/latest" | grep -oP '"tag_name"\s*:\s*"\K[^"]+' | head -1 | grep -oP '(?<=v).*')
# https://github.com/bitwarden/clients/releases
BITWARDEN_VERSION=$(curl -s "https://api.github.com/repos/bitwarden/clients/releases" | grep -oP '"tag_name"\s*:\s*"\Kdesktop-[^"]+' | head -1 | grep -oP '(?<=desktop-v).*')
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

# rpmfusion-nonfree-nvidia-driver is a Fedora-bundled repo (not defined above)
# and cannot be enabled inline with --enablerepo at install time because dnf5
# requires the repo to be enabled before the swap transaction resolves the
# ffmpeg provider. Setting it globally here is intentional; it is the only repo
# that receives this treatment.
dnf5 -y config-manager setopt rpmfusion-nonfree-nvidia-driver.enabled=1

# Replace the Fedora-bundled ffmpeg stub with the full build from RPM Fusion,
# which includes patented codecs (H.264, AAC, etc.) not shipped by default
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
dnf5 -y install \
    --enablerepo=docker-ce \
    --enablerepo=lact \
    --enablerepo=rpmfusion-free \
    --enablerepo=rpmfusion-nonfree-steam \
    --enablerepo=vscode \
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
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-vaapi \
    ksshaskpass \
    lact \
    libgee \
    libratbag-ratbagd \
    libva-nvidia-driver \
    mangohud \
    python3-pip \
    python3-pyicu \
    rpmdevtools \
    steam

# Install direct RPMs fetched from upstream release pages.
# Kept in separate dnf5 calls so a single failure is easy to identify and retry.

# Winboat — Run Windows apps on Linux with seamless integration 
dnf5 install -y "https://github.com/TibixDev/winboat/releases/download/v${WINBOAT_VERSION}/winboat-${WINBOAT_VERSION}-x86_64.rpm"

# Bitwarden — Bitwarden client app for linux desktops
dnf5 install -y "https://github.com/bitwarden/clients/releases/download/desktop-v${BITWARDEN_VERSION}/Bitwarden-${BITWARDEN_VERSION}-x86_64.rpm"

# Tabby — A terminal for a more modern age
dnf5 install -y "https://github.com/Eugeny/tabby/releases/download/v${TABBY_VERSION}/tabby-${TABBY_VERSION}-linux-x64.rpm"

# AppImage Thumbnailer — Generates AppImage thumbnails for Linux desktops
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

# Memory management — tuned for zswap + disk-backed swap:
#   vm.swappiness=30                 — with zswap, the first eviction tier is
#                                      compressed RAM, not disk. Setting this to
#                                      10 (correct for bare disk swap) defeats
#                                      zswap by refusing to push cold anon pages
#                                      into the fast compressed pool. 30 keeps
#                                      file cache hot without hammering the SSD
#   vm.page-cluster=3                — default read-ahead; sequential reads are
#                                      cheap on NVMe/SSD so pre-faulting 2^3 = 8
#                                      pages amortises I/O cost. Setting this to
#                                      0 (a zram optimisation) actively hurts on
#                                      real disk because pages have locality there
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
vm.swappiness=30
vm.page-cluster=3
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.compaction_proactiveness=0
vm.watermark_boost_factor=0
vm.watermark_scale_factor=125
EOF

# Gaming and development tunables:
#   vm.max_map_count=1048576           — many Proton/Wine games require a high memory
#                                        map count; the default (65530) causes silent
#                                        crashes or launch failures in some titles
#   vm.oom_kill_allocating_task=1      — immediately kill the task that triggered the
#                                        kernel OOM killer. This is the last-resort
#                                        fallback for processes not in a cgroup managed
#                                        by systemd-oomd (see oomd.conf.d below);
#                                        oomd acts first at cgroup granularity, this
#                                        catches anything that slips through
#   fs.inotify.max_user_watches        — VS Code and large dev projects exhaust the
#   fs.inotify.max_user_instances        default limits, causing file watchers to
#                                        silently stop working
#   fs.file-max=2097152                — system-wide cap on open file
#                                        descriptors; large dev environments,
#                                        container runtimes, and parallel
#                                        builds exhaust the default (1,048,576)
#   kernel.perf_event_paranoid=1       — allows unprivileged perf access needed by
#                                        MangoHud and other overlay/profiling tools
#   kernel.nmi_watchdog=0              — disables the NMI watchdog, which generates
#                                        periodic NMI interrupts for hang detection;
#                                        unnecessary on a desktop and frees a perf
#                                        counter on each core
#   kernel.sched_autogroup_enabled=1   — group tasks by session so interactive apps
#                                        and games don't compete with build jobs
#   kernel.numa_balancing=0            — NUMA balancing adds overhead with no benefit
#                                        on single-socket desktop systems
#   kernel.split_lock_mitigate=0       — suppress split-lock slowdowns; some older
#                                        Windows game binaries under Proton trigger
#                                        these and suffer severe performance penalties.
#                                        Tradeoff: disables bus-lock detection
#                                        (CVE-2021-33149 class); acceptable on a
#                                        trusted single-user desktop
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

# Scheduler tunables for AMD FX (Bulldozer/Piledriver) module topology.
# Remove this file on any CPU other than AMD FX-series (FX-4xxx/6xxx/8xxx,
# ~2011–2014). On Zen, Intel, or any modern CPU, the upstream defaults are
# better and these values will hurt scheduling latency.
#
#   kernel.sched_latency_ns=10000000      — CFS scheduling period: all runnable
#                                           tasks are guaranteed a slot within
#                                           this window. 10ms vs the 6ms default
#                                           reduces context-switch frequency;
#                                           Bulldozer pays a high per-switch cost
#                                           from shared integer cluster state
#   kernel.sched_min_granularity_ns=3000000 — minimum timeslice before preemption
#                                           (3ms). Longer slices amortise the FX
#                                           switch cost from shared fetch/decode
#                                           state within each two-core module
#   kernel.sched_wakeup_granularity_ns=4000000 — a waking task must lead the
#                                           running task by this much in vruntime
#                                           before it can preempt (4ms vs 1ms
#                                           default). Suppresses thrash from
#                                           threads competing on the same module's
#                                           shared dispatch port
#   kernel.sched_migration_cost_ns=1000000 — treat a task as cache-hot for 1ms
#                                           after it runs; discourages migration
#                                           across module boundaries where L2 is
#                                           not shared, reducing cold-cache misses
tee /etc/sysctl.d/99-amd-fx-scheduler.conf <<'EOF'
kernel.sched_latency_ns=10000000
kernel.sched_min_granularity_ns=3000000
kernel.sched_wakeup_granularity_ns=4000000
kernel.sched_migration_cost_ns=1000000
EOF

# Disable zram — using zswap with a dedicated swap partition on the SSD instead.
# An empty zram-generator.conf overrides any upstream or package-provided config
# that would otherwise create a zram device on first boot.
# See: https://chrisdown.name/2026/03/24/zswap-vs-zram-when-to-use-what.html
> /etc/systemd/zram-generator.conf

# zswap kernel arguments — applied by bootc on fresh installs.
# Existing deployments: run `rpm-ostree kargs --append=...` once manually.
#
#   zswap.enabled=1                — enable the zswap compressed cache
#   zswap.compressor=lz4           — fast, low-latency compression; suitable for
#                                    interactive and gaming workloads where
#                                    decompression latency matters more than ratio
#   zswap.zpool=zsmalloc           — best allocator; groups similar objects for
#                                    high compression ratios. z3fold/zbud are
#                                    removed from upstream kernels
#   zswap.max_pool_percent=20      — allow zswap to use up to 20% of RAM as its
#                                    compressed pool before tiering to disk;
#                                    the dynamic shrinker normally keeps usage
#                                    well below this ceiling
mkdir -p /usr/lib/bootloader.d
tee /usr/lib/bootloader.d/zswap.conf <<'EOF'
zswap.enabled=1 zswap.compressor=lz4 zswap.zpool=zsmalloc zswap.max_pool_percent=20 zswap.shrinker_enabled=1
EOF

# Transparent Huge Pages
# See: https://github.com/max0x7ba/thp-usage
# enabled=always       — all processes are eligible; reduces dTLB misses for
#                        any workload with large anonymous memory regions
# shmem_enabled=advise — only promote shared memory when explicitly requested,
#                        avoiding overhead on small IPC buffers
# defrag=always        — allocate huge pages immediately on fault via synchronous
#                        compaction. With defer+madvise, khugepaged is the only
#                        path to huge pages for most processes; it scans at most
#                        8GB per 79s pass, so short-lived processes (game launches,
#                        parallel builds) get huge pages too late or not at all.
#                        The "compaction stalls hurt latency" argument originates
#                        from database workloads with per-request latency budgets
#                        — not applicable here.
#                        See: github.com/max0x7ba/thp-usage
#
# khugepaged tuning (from thp-usage benchmarks):
#   pages_to_scan=2097152          — scan up to 8GB of VMAs per pass; collapses
#                                    any regions missed during synchronous fault
#   scan_sleep_millisecs=79000     — scan every 79s; infrequent enough to avoid
#                                    competing with foreground work
#   max_ptes_none/shared=64        — allow collapsing regions with up to 64
#                                    unmapped or shared PTEs; increases THP
#                                    coverage on real workloads
#   max_ptes_swap=0                — do not collapse regions with pages currently
#                                    on swap; avoids unnecessary disk I/O
tee /etc/tmpfiles.d/thp.conf <<'EOF'
w! /sys/kernel/mm/transparent_hugepage/enabled                    - - - - always
w! /sys/kernel/mm/transparent_hugepage/shmem_enabled              - - - - advise
w! /sys/kernel/mm/transparent_hugepage/defrag                     - - - - always
w! /sys/kernel/mm/transparent_hugepage/khugepaged/pages_to_scan   - - - - 2097152
w! /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs - - - - 79000
w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none   - - - - 64
w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_shared - - - - 64
w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_swap   - - - - 0
EOF


# =============================================================================
# systemd — OOM, Timeouts & Journal
# =============================================================================
# See: https://raw.githubusercontent.com/OneUptime/blog/refs/heads/master/posts/2026-03-04-systemd-oomd-out-of-memory-management-rhel-9/README.md

# Tune systemd-oomd for slightly earlier intervention than upstream defaults.
#   SwapUsedLimit=85%                    — kill when SSD swap is 85% full; with
#                                          zswap tiering to disk, reaching this
#                                          point means the compressed pool is
#                                          exhausted and disk I/O is the only
#                                          remaining fallback
#   DefaultMemoryPressureDurationSec=20s — act after 20s of sustained pressure
#                                          rather than the upstream default of 30s
mkdir -p /etc/systemd/oomd.conf.d
tee /etc/systemd/oomd.conf.d/00-tuning.conf <<'EOF'
[OOM]
SwapUsedLimit=85%
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

# Grant the 'audio' group access to /dev/cpu_dma_latency so real-time audio
# applications (e.g. JACK, PipeWire) can set low DMA latency without root
tee /etc/udev/rules.d/60-cpu-dma-latency.rules <<'EOF'
DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
EOF


# =============================================================================
# Storage — I/O Schedulers & Link Power
# =============================================================================

# Per-device I/O scheduler policy:
#   NVMe  — bypass the kernel scheduler entirely (device has its own queuing).
#           rq_affinity=2 forces completion on the originating CPU core,
#           avoiding cache-line bouncing across cores.
#           read_ahead_kb=128 suits the mixed random/sequential pattern of
#           game launches and build toolchains.
#   HDDs  — BFQ for latency fairness across competing processes; high
#           read_ahead_kb amortises seek cost on large sequential reads
#           (game asset packs, build artefacts).
#   SSDs  — mq-deadline for low-latency sequential I/O; modest read-ahead.
#   eMMC  — same treatment as SSD.
tee /etc/udev/rules.d/60-ioschedulers.rules <<'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none", ATTR{queue/rq_affinity}="2", ATTR{queue/read_ahead_kb}="128"
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq", ATTR{queue/read_ahead_kb}="2048"
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline", ATTR{queue/read_ahead_kb}="512"
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="mq-deadline", ATTR{queue/read_ahead_kb}="512"
EOF

# Force SCSI/SATA link power management to max_performance, preventing the
# host controller from downclocking links to save power (avoids I/O latency
# spikes on spinning drives and some SSDs)
tee /etc/udev/rules.d/61-scsi-link-power.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}=="*", ATTR{link_power_management_policy}="max_performance"
EOF


# =============================================================================
# Gaming — Controllers & GPU Recovery, etc.
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
#   - On a GPU reset event, kill the owning PID to release the hung context.
#     ENV{PID}!="" guards against an unset PID expanding to an empty string,
#     which would cause `test  -gt 1000` to error and skip the kill silently.
#   - If the display server (SDDM) is involved, restart it to recover the
#     desktop session cleanly
tee /etc/udev/rules.d/80-gpu-reset.rules <<'EOF'
ACTION=="change", SUBSYSTEM=="drm", ENV{RESET}=="1", ENV{PID}!="", ENV{PID}!="0", PROGRAM="/usr/bin/sh -c 'test %E{PID} -gt 1000'", RUN+="/usr/bin/kill -9 %E{PID}"
ACTION=="change", SUBSYSTEM=="drm", ENV{RESET}=="1", ENV{FLAGS}=="1", RUN+="/usr/sbin/systemctl restart sddm"
EOF

# Allow the logged-in user to access /dev/ntsync so Wine/Proton can use
# native NT sync primitives. Without this, the ntsync module is loaded but
# the device is root-only and ignored by Proton at runtime.
tee /etc/udev/rules.d/99-ntsync.rules <<'EOF'
KERNEL=="ntsync", MODE="0660", TAG+="uaccess"
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
# Remove cached package metadata and downloaded RPMs to keep the image lean.
# /var/lib/containers is cleared because akmods may pull container images
# during kernel module builds; those are not needed in the final image.
# =============================================================================
dnf5 -y clean all
rm -f /var/lib/systemd/random-seed
rm -rf \
    /var/lib/dnf \
    /var/lib/containers \
    /var/log/* \
    /tmp/*