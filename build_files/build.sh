#!/bin/bash

set -ouex pipefail

# libratbag
dnf5 install -y libratbag-ratbagd 
systemctl enable ratbagd.service
# Bitwarden
mv /opt{,.bak}
mkdir /opt
dnf5 install -y "https://bitwarden.com/download/?app=desktop&platform=linux&variant=rpm"
mv /opt/Bitwarden /usr/lib/Bitwarden
ln -sf /usr/lib/Bitwarden/bitwarden /usr/bin/bitwarden
ln -sf /usr/lib/Bitwarden/bitwarden-app /usr/bin/bitwarden-app
chmod 4755 /usr/lib/Bitwarden/chrome-sandbox
sed -i 's|^Exec=/opt/Bitwarden|Exec=/usr/bin|g' /usr/share/applications/bitwarden.desktop
rmdir /opt
mv /opt{.bak,}
# Visual Studio Code
rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc' | tee /etc/yum.repos.d/vscode.repo > /dev/null
dnf5 install -y code
# Steam
dnf5 install -y --enablerepo=rpmfusion-nonfree-steam mangohud gamescope steam
# tools for building and enabling akmod keys
dnf5 install -y rpmdevtools akmods
# NVIDIA driver
dnf5 install -y --enablerepo=rpmfusion-nonfree-release --enablerepo=rpmfusion-free-release akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver
# Update kernel arguments to activate driver, disable nouveau and nova, and disable kernel mitigations
dnf5 kernel-args add "rd.driver.blacklist=nouveau,nova_core" "modprobe.blacklist=nouveau,nova_core" "nvidia-drm.modeset=1" "mitigations=off"
