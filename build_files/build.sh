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
echo -e '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc' | tee /etc/yum.repos.d/vscode.repo > /dev/null
dnf5 -y install code
# Steam
dnf5 -y install --enablerepo=rpmfusion-nonfree-steam mangohud gamescope steam
# Misc Tools
dnf5 -y install rpmdevtools
rpm --import https://repos.fyralabs.com/terra42-nvidia/key.asc
echo -e '[terra]\nname=Terra 42 NVIDIA\nbaseurl=https://repos.fyralabs.com/terra42-nvidia/\nenabled=0\ngpgcheck=1\ngpgkey=https://repos.fyralabs.com/terra42-nvidia/key.asc' | tee /etc/yum.repos.d/terra42-nvidia.repo > /dev/null
dnf5 -y --enablerepo=terra42-nvidia install nvidia-driver nvidia-driver-cuda akmod-nvidia
