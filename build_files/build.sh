#!/bin/bash

set -eoux pipefail

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

# Install Packages
dnf5 -y config-manager setopt rpmfusion-nonfree-nvidia-driver.enabled=1
dnf5 -y swap ffmpeg-free --enablerepo=rpmfusion-free ffmpeg --allowerasing
dnf5 -y install --enablerepo=docker-ce --enablerepo=lact --enablerepo=rpmfusion-free --enablerepo=rpmfusion-nonfree-steam --enablerepo=vscode akmods android-tools gamescope ksshaskpass libratbag-ratbagd mangohud rpmdevtools python3-pip python3-pyicu containerd.io docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin lact libva-nvidia-driver gstreamer1-plugin-openh264 gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-vaapi steam code

mv /opt{,.bak}
mkdir /opt
dnf install -y "https://github.com/TibixDev/winboat/releases/download/v0.9.0/winboat-0.9.0-x86_64.rpm"
mv /opt/winboat /usr/lib/winboat
ln -sf /usr/lib/winboat/winboat /usr/bin/winboat
chmod 4755 /usr/lib/winboat/chrome-sandbox
sed -i 's|^Exec=/opt/winboat|Exec=/usr/bin|g' /usr/share/applications/winboat.desktop

dnf install -y "https://bitwarden.com/download/?app=desktop&platform=linux&variant=rpm"
mv /opt/Bitwarden /usr/lib/Bitwarden
ln -sf /usr/lib/Bitwarden/bitwarden /usr/bin/bitwarden
ln -sf /usr/lib/Bitwarden/bitwarden-app /usr/bin/bitwarden-app
chmod 4755 /usr/lib/Bitwarden/chrome-sandbox
sed -i 's|^Exec=/opt/Bitwarden|Exec=/usr/bin|g' /usr/share/applications/bitwarden.desktop

dnf install -y "https://github.com/Eugeny/tabby/releases/download/v1.0.229/tabby-1.0.229-linux-x64.rpm"
mv /opt/Tabby /usr/lib/Tabby
ln -sf /usr/lib/Tabby/tabby /usr/bin/tabby
chmod 4755 /usr/lib/Tabby/chrome-sandbox
sed -i 's|^Exec=/opt/Tabby|Exec=/usr/bin|g' /usr/share/applications/tabby.desktop
rmdir /opt
mv /opt{.bak,}

# Misc Removals
dnf5 -y remove '*-firmware' thermald firefox --exclude='nvidia-gpu-firmware' --exclude='amd-ucode-firmware' --exclude='linux-firmware*' --exclude='realtek-firmware'

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
