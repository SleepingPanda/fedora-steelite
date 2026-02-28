#!/bin/bash

set -eoux pipefail

## Remove the symlink and replace with a real directory to make /opt immutable.
rm -rf /opt && mkdir /opt

# ============================================================
# Pinned versions for direct RPM installs
# Check for updates at the links below and bump as needed.
# ============================================================
# https://github.com/TibixDev/winboat/releases
WINBOAT_VERSION="0.9.0"
# https://github.com/Eugeny/tabby/releases
TABBY_VERSION="1.0.229"
# https://github.com/kem-a/appimage-thumbnailer/releases
APPIMAGE_THUMBNAILER_VERSION="3.0.2"

# Repo Configs
tee /etc/yum.repos.d/rpmfusion-free.repo <<'EOF'
[rpmfusion-free]
name=RPM Fusion for Fedora $releasever
baseurl=http://download1.rpmfusion.org/free/fedora/releases/$releasever/Everything/$basearch/os/
enabled=0
enabled_metadata=1
gpgcheck=1
gpgkey=file:///usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-$releasever
EOF

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

# Install packages from repos
dnf5 -y config-manager setopt rpmfusion-nonfree-nvidia-driver.enabled=1
dnf5 -y swap ffmpeg-free --enablerepo=rpmfusion-free ffmpeg --allowerasing
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

# Install direct RPMs — kept in a separate block so failures are easy to isolate
dnf5 install -y "https://github.com/TibixDev/winboat/releases/download/v${WINBOAT_VERSION}/winboat-${WINBOAT_VERSION}-x86_64.rpm"

dnf5 install -y "https://bitwarden.com/download/?app=desktop&platform=linux&variant=rpm"

dnf5 install -y "https://github.com/Eugeny/tabby/releases/download/v${TABBY_VERSION}/tabby-${TABBY_VERSION}-linux-x64.rpm"

dnf5 install -y "https://github.com/kem-a/appimage-thumbnailer/releases/download/v${APPIMAGE_THUMBNAILER_VERSION}/appimage-thumbnailer-v${APPIMAGE_THUMBNAILER_VERSION}-1.x86_64.rpm"

# Misc Removals
dnf5 -y remove '*-firmware' thermald firefox --exclude='nvidia-gpu-firmware' --exclude='amd-ucode-firmware' --exclude='linux-firmware*' --exclude='realtek-firmware'

# Enable Services
systemctl enable ratbagd.service docker.service containerd.service lactd.service podman-auto-update.timer

# Configurations and Rules
tee /usr/lib/sysusers.d/docker.conf <<'EOF'
g docker 998
EOF

tee /etc/modules-load.d/ntsync.conf <<'EOF'
ntsync
EOF

mkdir -p /etc/systemd/journald.conf.d
tee /etc/systemd/journald.conf.d/00-journal-size.conf <<'EOF'
[Journal]
SystemMaxUse=150M
EOF

mkdir -p /etc/systemd/zram-generator.conf.d
tee /etc/systemd/zram-generator.conf.d/00-override.conf <<'EOF'
[zram0]
zram-fraction = 0.75
max-zram-size = 12288
EOF

tee /etc/sysctl.d/99-zram-swap.conf <<'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
EOF

tee /etc/tmpfiles.d/coredump.conf <<'EOF'
d /var/lib/systemd/coredump 0755 root root 3d
EOF

tee /etc/tmpfiles.d/thp.conf <<'EOF'
w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise
w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 409
EOF

tee /etc/udev/rules.d/60-cpu-dma-latency-permissions.rules <<'EOF'
DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
EOF

tee /etc/udev/rules.d/99-scsi-link-power-performance.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}=="*", ATTR{link_power_management_policy}="max_performance"
EOF

tee /etc/udev/rules.d/80-gpu-reset.rules <<'EOF'
ACTION=="change", ENV{DEVNAME}=="/dev/dri/card0", ENV{RESET}=="1", ENV{PID}!="0", RUN+="/sbin/kill -9 %E{PID}"
ACTION=="change", ENV{DEVNAME}=="/dev/dri/card0", ENV{RESET}=="1", ENV{FLAGS}=="1", RUN+="/usr/sbin/systemctl restart sddm"
EOF

grep -E '^gamemode:' /usr/lib/group | tee -a /etc/group
grep -E '^audio:' /usr/lib/group | tee -a /etc/group

tee -a /etc/group <<'EOF'
docker:x:998:
EOF

# Cleanup
dnf5 -y clean all
rm -rf /var/lib/dnf