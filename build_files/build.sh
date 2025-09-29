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
dnf5 -y install rpmdevtools akmods
sh <(curl https://terra.fyralabs.com/get.sh)
dnf5 config-manager setopt terra-nvidia.enabled=1
