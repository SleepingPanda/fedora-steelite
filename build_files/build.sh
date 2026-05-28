#!/bin/bash
# =============================================================================
# System Build Script
# Configures a Fedora-based system with development tools, gaming packages,
# Docker, and various system optimizations.
# =============================================================================

set -eoux pipefail
GITHUB_TOKEN=$(cat /run/secrets/github_token)
   [[ -n "$GITHUB_TOKEN" ]] || { echo "ERROR: github_token secret is empty"; exit 1; }


# Replace the /opt symlink with a real directory so the path becomes mutable
# (prevents downstream layers from accidentally writing through a symlink)
rm -rf /opt && mkdir /opt


# ============================================================
# Check for updates at the links below automatically.
# ============================================================

# https://github.com/Eugeny/tabby/releases
TABBY_VERSION=$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" \
     "https://api.github.com/repos/Eugeny/tabby/releases/latest" | \
     jq -r '.tag_name' | sed 's/^v//')


# https://github.com/kem-a/appimage-thumbnailer/releases
APPIMAGE_THUMBNAILER_VERSION=$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" \
     "https://api.github.com/repos/kem-a/appimage-thumbnailer/releases/latest" | \
     jq -r '.tag_name' | sed 's/^v//')


# https://github.com/bitwarden/clients/releases
BITWARDEN_VERSION=$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" \
     "https://api.github.com/repos/bitwarden/clients/releases" | \
     jq -r '[.[] | select(.tag_name | startswith("desktop-"))][0].tag_name' | \
     sed 's/^desktop-v//')


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


# RPM Fusion Nonfree NVIDIA — provides the proprietary NVIDIA driver
tee /etc/yum.repos.d/rpmfusion-nonfree-nvidia.repo <<'EOF'
[rpmfusion-nonfree-nvidia]
name=RPM Fusion for Fedora $releasever - Nonfree - NVIDIA driver
baseurl=http://muug.ca/mirror/rpmfusion/nonfree/fedora/releases/$releasever/Everything/$basearch/os/
enabled=1
type=rpm
gpgcheck=1
repo_gpgcheck=0
gpgkey=file:///usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-nonfree-fedora-$releasever
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


# CachyOS kernel addons — provides scx-scheds (sched_ext schedulers) and scx-tools
rpm --import https://download.copr.fedorainfracloud.org/results/bieszczaders/kernel-cachyos-addons/pubkey.gpg
tee /etc/yum.repos.d/cachyos-addons.repo <<'EOF'
[cachyos-addons]
name=CachyOS kernel addons
baseurl=https://download.copr.fedorainfracloud.org/results/bieszczaders/kernel-cachyos-addons/fedora-$releasever-$basearch/
enabled=0
enabled_metadata=1
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/bieszczaders/kernel-cachyos-addons/pubkey.gpg
EOF


# =============================================================================
# Package Installation
# =============================================================================

# Replace the Fedora-bundled ffmpeg stub with the full build from RPM Fusion,
# which includes patented codecs (H.264, AAC, etc.) not shipped by default
dnf5 -y swap ffmpeg-free --enablerepo=rpmfusion-free ffmpeg --allowerasing


# Install all repo-based packages in a single transaction for efficiency.
# Repos are enabled inline rather than globally to avoid polluting the default
# metadata cache.
#
# Development tools:
#   android-tools               — ADB/fastboot for Android device management
#   code                        — Visual Studio Code editor
#   python3-pip                 — Python package installer
#   python3-pyicu               — Python bindings for ICU (Unicode/locale support)
#   rpmdevtools                 — RPM packaging utilities
#
# Docker:
#   containerd.io               — container runtime required by Docker CE
#   docker-ce / cli / plugins   — Docker engine, CLI, buildx, and compose
#
# Gaming:
#   gamescope                   — Valve's micro-compositor for gaming sessions
#   libratbag-ratbagd           — gaming mouse configuration daemon
#   mangohud                    — in-game performance overlay
#   steam                       — Valve Steam client
#
# GPU & Media:
#   akmods                      — builds kernel modules (e.g. NVIDIA) on upgrade
#   ffmpegthumbnailer           — generates video thumbnails for file managers
#   glycin-thumbnailer          — GNOME image thumbnailer
#   gstreamer1-plugin-*         — additional codec support (H.264, ugly/bad sets)
#   gstreamer1-vaapi            — VA-API hardware video decode/encode via GStreamer
#   lact                        — AMD GPU control application
#   libheif-freeworld           — HEIF image format support with patented codecs
#   libheif-tools               — CLI tools for inspecting and converting HEIF files
#   libva-nvidia-driver         — VA-API backend for NVIDIA GPUs
#   pipewire-codec-aptx         — Qualcomm aptX Bluetooth audio codec plugin for PipeWire
#
# System:
#   adw-gtk3-theme              — modern GTK theme for a polished desktop
dnf5 -y install \
    --enablerepo=docker-ce \
    --enablerepo=lact \
    --enablerepo=rpmfusion-free \
    --enablerepo=vscode \
    --enablerepo=cachyos-addons \
    adw-gtk3-theme \
    akmods \
    android-tools \
    code \
    containerd.io \
    docker-ce \
    docker-ce-cli \
    docker-buildx-plugin \
    docker-compose-plugin \
    fuse \
    fuse-libs \
    ffmpegthumbnailer \
    gamescope \
    glycin-thumbnailer \
    gstreamer1-plugin-openh264 \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-vaapi \
    lact \
    libgee \
    libheif-freeworld \
    libheif-tools \
    libratbag-ratbagd \
    libva-nvidia-driver \
    mangohud \
    pipewire-codec-aptx \
    python3-pip \
    python3-pyicu \
    rpmdevtools \
    scx-scheds \
    scx-tools


# Steam pulls in runtime libs older than what the base image ships,
# which would downgrade libgcc/libstdc++ system-wide and break post-install
# scriptlets. Exclude those packages so Steam uses the base image's versions.
dnf5 -y install \
    --enablerepo=rpmfusion-nonfree-steam \
    --exclude='libgcc.x86_64' \
    --exclude='libstdc++.x86_64' \
    --exclude='libgomp.x86_64' \
    --exclude='libatomic.x86_64' \
    --exclude='cpp.x86_64' \
    steam


# Install direct RPMs fetched from upstream release pages.
# Kept in separate dnf5 calls so a single failure is easy to identify and retry.

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

# Disable NVMe power management latency tolerance — prevents the controller
# from downclocking during I/O bursts
tee /etc/modprobe.d/nvme.conf <<'EOF'
options nvme_core default_ps_max_latency_us=0
EOF


# =============================================================================
# Kernel Tunables (sysctl)
# =============================================================================

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


# sched_ext — userspace scheduler via scx_loader
# scx_bpfland: cache-topology aware, good for desktop/gaming. Its L2/L3 affinity
# awareness is particularly relevant on FX's shared-cache module topology.
# The CFS tunables in 99-amd-fx-scheduler.conf are ignored while scx is active;
# they remain as a fallback if scx_loader stops.
mkdir -p /etc/
tee /etc/scx_loader.toml <<'EOF'
default_sched = "scx_bpfland"
default_mode = "Gaming"
EOF


# Mitigations — disable CPU vulnerability mitigations for maximum performance.
tee /usr/lib/bootloader.d/mitigations.conf <<'EOF'
mitigations=off
EOF


# =============================================================================
# systemd
# =============================================================================

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


# Configure the system and git to use ksshaskpass for SSH passphrase prompts.
mkdir -p /etc/environment.d
tee /etc/environment.d/50-ssh-askpass.conf <<'EOF'
SSH_ASKPASS=/usr/bin/ksshaskpass
SSH_ASKPASS_REQUIRE=prefer
GIT_ASKPASS=/usr/bin/ksshaskpass
EOF


## nvidia-vaapi-driver Source:
## https://github.com/elFarto/nvidia-vaapi-driver?tab=readme-ov-file#configuration
tee /etc/environment.d/50-vaapi.conf <<'EOF'
NVD_BACKEND=direct
LIBVA_DRIVER_NAME=nvidia
CUDA_DISABLE_PERF_BOOST=1
EOF


# Increase Nvidia's shader cache size to 12GB
# https://wiki.cachyos.org/configuration/gaming/#increase-maximum-shader-cache-size
tee /etc/environment.d/50-nvidia-cache.conf <<'EOF'
__GL_SHADER_DISK_CACHE_SIZE=12000000000
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


# Allow the logged-in user to access /dev/ntsync so Wine/Proton can use
# native NTsync primitives. Without this, the ntsync module is loaded but
# the device is root-only and ignored by Proton at runtime.
tee /etc/udev/rules.d/99-ntsync.rules <<'EOF'
KERNEL=="ntsync", group="gamemode", MODE="0660", TAG+="uaccess"
EOF


# =============================================================================
# Service Enablement
# =============================================================================
systemctl enable \
    containerd.service \
    docker.service \
    lactd.service \
    ratbagd.service \
    scx_loader.service


# =============================================================================
# Cleanup
# Remove cached package metadata and downloaded RPMs to keep the image lean.
# /var/lib/containers is cleared because akmods may pull container images
# during kernel module builds; those are not needed in the final image.
# =============================================================================
dnf5 -y clean all
rm -rf \
    /var/lib/dnf \
    /var/lib/containers \
    /var/log/* \
    /tmp/*