#!/bin/bash

set -eEox pipefail

# Helper Function
install_app() {
    local url="$1"
    local name="$2"

    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir "$tmpdir/opt"
    mount --bind "$tmpdir/opt" /opt
    dnf5 -y install "$url"
    umount /opt

    mv "$tmpdir/opt/$name" "/usr/lib/$name"
    ln -sfn "/usr/lib/$name" "/opt/$name"
    rm -rf "$tmpdir"
}

# NVIDIA
KERNEL_VERSION="$(rpm -q --queryformat="%{EVR}.%{ARCH}" kernel-core)"
curl -Lo /tmp/nvidia-install.sh https://raw.githubusercontent.com/ublue-os/main/refs/heads/main/build_files/nvidia-install.sh
chmod +x /tmp/nvidia-install.sh
IMAGE_NAME="kinoite" RPMFUSION_MIRROR="" /tmp/nvidia-install.sh
rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json
ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so
dnf5 config-manager setopt fedora-multimedia.enabled=1 fedora-nvidia.enabled=0

depmod -a "${KERNEL_VERSION}"

# Misc Tools
dnf5 -y install ksshaskpass gstreamer1-plugin-openh264

# Misc Removals
dnf5 -y remove '*-firmware' thermald firefox \
    --exclude='nvidia-gpu-firmware' \
    --exclude='amd-ucode-firmware' \
    --exclude='linux-firmware*' \
    --exclude='realtek-firmware'

# FFMPEG and Codecs
tee /etc/yum.repos.d/rpmfusion-free.repo <<'EOF'
[rpmfusion-free]
name=RPM Fusion for Fedora $releasever
baseurl=http://download1.rpmfusion.org/free/fedora/releases/$releasever/Everything/$basearch/os/
enabled=0
gpgcheck=1
gpgkey=file:///usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-$releasever
EOF
dnf5 -y swap ffmpeg-free --enablerepo=rpmfusion-free ffmpeg --allowerasing

# libratbag
dnf5 -y install libratbag-ratbagd

# Steam
dnf5 -y install --enablerepo=rpmfusion-nonfree-steam mangohud gamescope steam

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
dnf5 -y install --enablerepo=docker-ce docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
echo -e 'g docker 998' | tee /usr/lib/sysusers.d/docker.conf > /dev/null

# Bitwarden
install_app "https://bitwarden.com/download/?app=desktop&platform=linux&variant=rpm" Bitwarden
chmod 4755 /usr/lib/Bitwarden/chrome-sandbox

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
dnf5 -y install --enablerepo=vscode code

# WinBoat
install_app "https://github.com/TibixDev/winboat/releases/download/v0.8.7/winboat-0.8.7-x86_64.rpm" winboat
chmod 4755 /usr/lib/winboat/chrome-sandbox

# Enable Services
systemctl enable ratbagd.service docker.service containerd.service
systemctl --global enable podman-auto-update.timer

dnf5 -y clean all
rm -rf /var/lib/dnf
