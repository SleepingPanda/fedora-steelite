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

# LACT (Linux AMDGPU Control Application) — AMD GPU overclocking and monitoring
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
#   akmods                    — builds kernel modules (e.g. NVIDIA) on upgrade
#   android-tools             — ADB/fastboot for Android device management
#   code                      — Visual Studio Code editor
#   containerd.io             — container runtime required by Docker CE
#   docker-ce / cli / plugins — Docker engine, CLI, buildx, and compose
#   gamescope                 — Valve's micro-compositor for gaming sessions
#   glycin-thumbnailer        — GNOME image thumbnailer
#   gstreamer1-plugin-*       — additional codec support (H.264, ugly/bad sets)
#   gstreamer1-vaapi          — VA-API hardware video decode/encode via GStreamer
#   ksshaskpass               — KDE SSH passphrase dialog (integrates with KWallet)
#   lact                      — AMD GPU control application
#   libgee                    — GLib collection library (LACT dependency)
#   libratbag-ratbagd         — gaming mouse configuration daemon
#   libva-nvidia-driver       — VA-API backend for NVIDIA GPUs
#   mangohud                  — in-game performance overlay
#   python3-pip               — Python package installer
#   python3-pyicu             — Python bindings for ICU (Unicode/locale support)
#   rpmdevtools               — RPM packaging utilities
#   steam                     — Valve Steam client
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
    gstreamer1-plugin-openh264 \
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

# Winboat — Wine/Proton game launcher GUI
dnf5 install -y "https://github.com/TibixDev/winboat/releases/download/v${WINBOAT_VERSION}/winboat-${WINBOAT_VERSION}-x86_64.rpm"

# Bitwarden — password manager desktop client
dnf5 install -y "https://bitwarden.com/download/?app=desktop&platform=linux&variant=rpm"

# Tabby — modern GPU-accelerated terminal emulator
dnf5 install -y "https://github.com/Eugeny/tabby/releases/download/v${TABBY_VERSION}/tabby-${TABBY_VERSION}-linux-x64.rpm"

# AppImage Thumbnailer — generates thumbnails for AppImage files in file managers
dnf5 install -y "https://github.com/kem-a/appimage-thumbnailer/releases/download/v${APPIMAGE_THUMBNAILER_VERSION}/appimage-thumbnailer-v${APPIMAGE_THUMBNAILER_VERSION}-1.x86_64.rpm"

# =============================================================================
# Package Removal
# Strip out packages that are unnecessary in this image to reduce size.
# Critical firmware blobs (NVIDIA, AMD µcode, linux-firmware, Realtek) are
# explicitly excluded so hardware support is not broken.
# =============================================================================
dnf5 -y remove '*-firmware' thermald firefox \
    --exclude='nvidia-gpu-firmware' \
    --exclude='amd-ucode-firmware' \
    --exclude='linux-firmware*' \
    --exclude='realtek-firmware'

# =============================================================================
# Service Enablement
# Units are enabled here so they start automatically on first boot.
#   ratbagd              — gaming mouse config daemon (libratbag)
#   docker / containerd  — Docker engine and its container runtime
#   lactd                — LACT AMD GPU daemon
#   podman-auto-update   — timer that keeps Podman containers up to date
# =============================================================================
systemctl enable ratbagd.service docker.service containerd.service lactd.service podman-auto-update.timer systemd-oomd.service

# =============================================================================
# System Configuration
# =============================================================================

# Create the 'docker' system group with a fixed GID (998) so bind-mounted
# socket permissions are consistent across rebuilds
tee /usr/lib/sysusers.d/docker.conf <<'EOF'
g docker 998
EOF

# Load the ntsync kernel module at boot — improves Wine/Proton synchronization
# performance by providing a native futex-based NT sync mechanism
tee /etc/modules-load.d/ntsync.conf <<'EOF'
ntsync
EOF

# Cap the systemd journal at 150 MB to prevent unbounded disk usage
mkdir -p /etc/systemd/journald.conf.d
tee /etc/systemd/journald.conf.d/00-journal-size.conf <<'EOF'
[Journal]
SystemMaxUse=150M
EOF

# ZRAM swap configuration — use 75% of RAM up to 12 GB as a compressed swap
# device, which reduces I/O on SSDs and improves responsiveness under memory
# pressure
mkdir -p /etc/systemd/zram-generator.conf.d
tee /etc/systemd/zram-generator.conf.d/00-override.conf <<'EOF'
[zram0]
zram-fraction = 0.75
max-zram-size = 12288
EOF

# Kernel tuning for ZRAM swap:
#   vm.swappiness=180             — high swappiness is correct for ZRAM; unlike
#                                   slow disk swap, ZRAM is RAM-speed compressed
#                                   memory so the kernel should use it freely.
#                                   Kernels 5.8+ support values up to 200.
#   vm.page-cluster=0             — disable swap read-ahead; ZRAM has no seek
#                                   penalty so prefetching clusters is pure waste
#   vm.vfs_cache_pressure=50      — balanced inode/dentry cache reclaim
#   vm.dirty_ratio=10             — flush dirty pages when 10% of RAM is dirty
#   vm.dirty_background_ratio=5   — start background writeback at 5%
#   vm.max_map_count=1048576      — many Proton/Wine games require a high memory
#                                   map count; the default (65530) causes silent
#                                   crashes or launch failures in some titles
#   fs.inotify.max_user_watches   — VS Code and large dev projects exhaust the
#   fs.inotify.max_user_instances   default limits, causing file watchers to
#                                   silently stop working
#   kernel.perf_event_paranoid=1  — allows unprivileged perf access needed by
#                                   MangoHud and other overlay/profiling tools
tee /etc/sysctl.d/99-zram-swap.conf <<'EOF'
vm.swappiness=180
vm.page-cluster=0
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
EOF

# Retain core dumps for 3 days, then clean them up automatically
tee /etc/tmpfiles.d/coredump.conf <<'EOF'
d /var/lib/systemd/coredump 0755 root root 3d
EOF

# Transparent Huge Pages tuning:
#   defrag=defer+madvise  — only defrag on madvise() calls or async; avoids
#                           stalls in latency-sensitive workloads (games, audio)
#   max_ptes_none=409     — allow khugepaged to collapse more zero-page PTEs,
#                           improving memory efficiency for large allocations
tee /etc/tmpfiles.d/thp.conf <<'EOF'
w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise
w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 409
EOF

# Grant the 'audio' group access to /dev/cpu_dma_latency so real-time audio
# applications (e.g. JACK, PipeWire) can set low DMA latency without root
tee /etc/udev/rules.d/60-cpu-dma-latency-permissions.rules <<'EOF'
DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
EOF

# Force SCSI/SATA link power management to max_performance, preventing the
# host controller from downclocking links to save power (avoids I/O latency
# spikes on spinning drives and some SSDs)
tee /etc/udev/rules.d/99-scsi-link-power-performance.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}=="*", ATTR{link_power_management_policy}="max_performance"
EOF

# Tune systemd-oomd to act more aggressively than its conservative defaults.
# Without this, oomd can let memory pressure build too long before killing
# anything, effectively negating its purpose on a gaming system.
#   SwapUsedLimit=80%                  — intervene when swap is 80% full
#   DefaultMemoryPressureLimit=60%     — trigger on sustained 60% PSI memory
#                                        pressure (vs the default 60%, but
#                                        combined with a shorter duration below
#                                        this makes it much more responsive)
#   DefaultMemoryPressureDurationSec=10s — act after 10s of sustained pressure
#                                          rather than the default 30s
mkdir -p /etc/systemd/oomd.conf.d
tee /etc/systemd/oomd.conf.d/00-tuning.conf <<'EOF'
[OOM]
SwapUsedLimit=80%
DefaultMemoryPressureLimit=60%
DefaultMemoryPressureDurationSec=10s
EOF

# GPU reset rules for /dev/dri/card0:
#   - On a GPU reset event, kill the owning PID to release the hung context
#   - If the display server (SDDM) is involved, restart it to recover the
#     desktop session cleanly
tee /etc/udev/rules.d/80-gpu-reset.rules <<'EOF'
ACTION=="change", ENV{DEVNAME}=="/dev/dri/card0", ENV{RESET}=="1", ENV{PID}!="0", RUN+="/sbin/kill -9 %E{PID}"
ACTION=="change", ENV{DEVNAME}=="/dev/dri/card0", ENV{RESET}=="1", ENV{FLAGS}=="1", RUN+="/usr/sbin/systemctl restart sddm"
EOF

# =============================================================================
# Cleanup
# Remove cached package metadata and downloaded RPMs to keep the image lean
# =============================================================================
dnf5 -y clean all