#!/bin/bash

set -eEox pipefail

# Helper Function
install_app() {
    local url="$1"
    local name="$2"
    local tmpdir rpmfile desktop_file chrome_sandbox
    tmpdir=$(mktemp -d)
    rpmfile="$tmpdir/$name.rpm"
    curl -L -o "$rpmfile" "$url"
    rpm2cpio "$rpmfile" | (cd "$tmpdir" && cpio -idmv)
    cp -a "$tmpdir/opt/$name" "/usr/lib/$name"
    cp -a "$tmpdir/usr/share/applications/${name,,}.desktop" "/usr/share/applications/"
    cp -a "$tmpdir/usr/share/icons/hicolor/." "/usr/share/icons/hicolor/"
    desktop_file="/usr/share/applications/${name,,}.desktop"
    if [[ -f "$desktop_file" ]]; then
        sed -i "s|^Exec=/opt/$name|Exec=/usr/lib/$name|g" "$desktop_file"
        sed -i "s|^Icon=/opt/$name|Icon=/usr/lib/$name|g" "$desktop_file"
    fi
    chrome_sandbox="/usr/lib/$name/chrome-sandbox"
    if [[ -f "$chrome_sandbox" ]]; then
        chmod 4755 "$chrome_sandbox"
    fi
    rm -rf "$tmpdir"
}

# Create Repo Files
# FFMPEG and Codecs
tee /etc/yum.repos.d/rpmfusion-free.repo <<'EOF'
[rpmfusion-free]
name=RPM Fusion for Fedora $releasever
baseurl=http://download1.rpmfusion.org/free/fedora/development/$releasever/Everything/$basearch/os/
enabled=0
gpgcheck=1
gpgkey=file:///usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-$releasever
EOF

# Docker CE
rpm --import https://download.docker.com/linux/fedora/gpg
tee /etc/yum.repos.d/docker-ce.repo <<'EOF'
[docker-ce]
name=Docker CE
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=0
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF

# Visual Studio Code
rpm --import https://packages.microsoft.com/keys/microsoft.asc
tee /etc/yum.repos.d/vscode.repo <<'EOF'
[vscode]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=0
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# LACT
rpm --import https://download.copr.fedorainfracloud.org/results/ilyaz/LACT/pubkey.gpg
tee /etc/yum.repos.d/lact.repo <<'EOF'
[lact]
name=LACT
baseurl=https://download.copr.fedorainfracloud.org/results/ilyaz/LACT/fedora-$releasever-$basearch/
enabled=0
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/ilyaz/LACT/pubkey.gpg
EOF

# Install Packages
# Tools, Drivers, Steam, Code, LACT, Docker
dnf5 -y config-manager setopt rpmfusion-nonfree-nvidia-driver.enabled=1
dnf5 -y swap ffmpeg-free --enablerepo=rpmfusion-free ffmpeg --allowerasing
dnf5 -y install --enablerepo=docker-ce --enablerepo=lact --enablerepo=rpmfusion-nonfree-steam --enablerepo=vscode rpmdevtools akmods ksshaskpass libva-nvidia-driver gstreamer1-plugin-openh264 libratbag-ratbagd docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin code lact mangohud gamescope steam

# Misc Removals
dnf5 -y remove '*-firmware' thermald firefox --exclude='nvidia-gpu-firmware' --exclude='amd-ucode-firmware' --exclude='linux-firmware*' --exclude='realtek-firmware'

# WinBoat
install_app "https://github.com/TibixDev/winboat/releases/download/v0.8.7/winboat-0.8.7-x86_64.rpm" winboat

# Bitwarden
install_app "https://bitwarden.com/download/?app=desktop&platform=linux&variant=rpm" Bitwarden

# Enable Services
systemctl enable ratbagd.service docker.service containerd.service lactd.service
systemctl --global enable podman-auto-update.timer

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

tee /etc/tmpfiles.d/coredump.conf <<'EOF'
d /var/lib/systemd/coredump 0755 root root 3d
EOF

tee /etc/tmpfiles.d/thp.conf <<'EOF'
w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise
w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 409
EOF

tee /etc/udev/rules.d/99-cpu-dma-latency.rules <<'EOF'
DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
EOF

tee /etc/udev/rules.d/50-sata.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", \
    ATTR{link_power_management_policy}=="*", \
    ATTR{link_power_management_policy}="max_performance"
EOF

grep -E '^gamemode:' /usr/lib/group | tee -a /etc/group
grep -E '^audio:' /usr/lib/group | tee -a /etc/group
tee -a /etc/group <<'EOF'
docker:x:998:
EOF

# Cleanup
dnf5 -y clean all
rm -rf /var/lib/dnf
