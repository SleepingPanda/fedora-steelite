#!/bin/bash

set -eEox pipefail

# Helper Function
install_app() {
    local url="$1"
    local name="$2"
    local tmpdir rpmfile

    tmpdir=$(mktemp -d)
    rpmfile="$tmpdir/$name.rpm"
    curl -L -o "$rpmfile" "$url"
    rpm2cpio "$rpmfile" | (cd "$tmpdir" && cpio -idmv)
    mv "$tmpdir/opt/$name" "/usr/lib/$name"
    ln -sfn "/usr/lib/$name" "/opt/$name"
    rm -rf "$tmpdir"
}

# Misc Tools
dnf5 -y install rpmdevtools akmods ksshaskpass libva-nvidia-driver gstreamer1-plugin-openh264
dnf5 -y config-manager setopt rpmfusion-nonfree-nvidia-driver.enabled=1

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
