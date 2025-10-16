#!/bin/bash

set -eoux pipefail

# libratbag
dnf5 -y install libratbag-ratbagd
systemctl enable ratbagd.service

# Bitwarden
mv /opt{,.bak}
mkdir /opt
dnf5 -y install "https://bitwarden.com/download/?app=desktop&platform=linux&variant=rpm"
mv /opt/Bitwarden /usr/lib/Bitwarden
ln -sf /usr/lib/Bitwarden/bitwarden /usr/bin/bitwarden
ln -sf /usr/lib/Bitwarden/bitwarden-app /usr/bin/bitwarden-app
chmod 4755 /usr/lib/Bitwarden/chrome-sandbox
sed -i 's|^Exec=/opt/Bitwarden|Exec=/usr/bin|g' /usr/share/applications/bitwarden.desktop
rmdir /opt
mv /opt{.bak,}

# Visual Studio Code
rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e '[vscode]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=0\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc' | tee /etc/yum.repos.d/vscode.repo > /dev/null
dnf5 -y install --enablerepo=vscode code

# FFMPEG and Codecs
echo -e '[rpmfusion-free]\nname=RPM Fusion for Fedora $releasever\nbaseurl=http://download1.rpmfusion.org/free/fedora/releases/$releasever/Everything/$basearch/os/\nenabled=0\ngpgcheck=1\ngpgkey=file:///usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-$releasever' | tee /etc/yum.repos.d/rpmfusion-free.repo > /dev/null
dnf5 -y swap ffmpeg-free --enablerepo=rpmfusion-free ffmpeg --allowerasing

# Steam
dnf5 -y install --enablerepo=rpmfusion-nonfree-steam mangohud gamescope steam

# Docker CE
rpm --import https://download.docker.com/linux/fedora/gpg
echo -e '[docker-ce]\nname=Docker CE\nbaseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable\nenabled=0\ngpgcheck=1\ngpgkey=https://download.docker.com/linux/fedora/gpg' | tee /etc/yum.repos.d/docker-ce.repo > /dev/null
dnf5 -y install --enablerepo=docker-ce docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl enable containerd

# Misc Tools
dnf5 -y install rpmdevtools akmods ksshaskpass libva-nvidia-driver gstreamer1-plugin-openh264
dnf5 -y config-manager setopt rpmfusion-nonfree-nvidia-driver.enabled=1

# Misc Fixes
dnf5 -y remove alsa-firmware alsa-sof-firmware amd-gpu-firmware atheros-firmware brcmfmac-firmware cirrus-audio-firmware intel-audio-firmware intel-gpu-firmware intel-vsc-firmware iwlegacy-firmware iwlwifi-dvm-firmware iwlwifi-mld-firmware iwlwifi-mvm-firmware libertas-firmware mt7xxx-firmware nxpwireless-firmware qcom-wwan-firmware tiwilink-firmware thermald firefox

dnf5 -y clean all
