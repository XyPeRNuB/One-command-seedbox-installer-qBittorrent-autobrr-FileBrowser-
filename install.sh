#!/bin/bash
set -e

LOG_FILE="/root/wrapper_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo ">> Seedbox Installer"
echo "============================================================"

PUBLIC_IP=$(curl -s https://ipinfo.io/ip || curl -s4 ifconfig.me || hostname -I | awk '{print $1}')

read -p "Username: " USERNAME
if [ -z "$USERNAME" ]; then
  echo "Username cannot be empty."
  exit 1
fi

read -s -p "Password: " PASSWORD
echo ""
if [ -z "$PASSWORD" ]; then
  echo "Password cannot be empty."
  exit 1
fi

read -p "qBittorrent WebUI port [8080]: " QBIT_PORT
QBIT_PORT=${QBIT_PORT:-8080}

read -p "qBittorrent incoming port [45000]: " QBIT_INCOMING_PORT
QBIT_INCOMING_PORT=${QBIT_INCOMING_PORT:-45000}

read -p "FileBrowser port [808]: " FILEBROWSER_PORT
FILEBROWSER_PORT=${FILEBROWSER_PORT:-808}

read -p "autobrr port [7474]: " AUTOBRR_PORT
AUTOBRR_PORT=${AUTOBRR_PORT:-7474}

read -p "QUI port [7476]: " QUI_PORT
QUI_PORT=${QUI_PORT:-7476}

echo ""
echo "Choose qBittorrent version:"
echo "1) Debian default"
echo "2) Static 4.6.7"
read -p "Choice [1]: " QBIT_CHOICE
QBIT_CHOICE=${QBIT_CHOICE:-1}

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  QBT_ARCH="aarch64"
  AUTOBRR_ARCH="arm64"
elif [ "$ARCH" = "x86_64" ]; then
  QBT_ARCH="x86_64"
  AUTOBRR_ARCH="amd64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

echo "Updating system..."
apt update && apt upgrade -y

echo "Installing dependencies and media tools..."
apt install -y curl wget tar unzip git ufw ca-certificates python3 python3-pip \
  qbittorrent-nox ffmpeg mediainfo aria2 mkvtoolnix mktorrent fastfetch tuned

echo "Creating user..."
if ! id "$USERNAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$USERNAME"
fi

echo "$USERNAME:$PASSWORD" | chpasswd

mkdir -p "/home/$USERNAME/qbittorrent/Downloads"
mkdir -p "/home/$USERNAME/.config/qBittorrent"
mkdir -p "/home/$USERNAME/.config/autobrr"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

if [ "$QBIT_CHOICE" = "2" ]; then
  echo "Installing qBittorrent 4.6.7 static build..."
  wget -O /usr/local/bin/qbittorrent-nox \
    "https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.6.7_v2.0.10/${QBT_ARCH}-qbittorrent-nox"
  chmod +x /usr/local/bin/qbittorrent-nox
fi

QBIT_BIN=$(command -v qbittorrent-nox)

QBIT_HASH=$(python3 - <<EOF
import hashlib, os, base64
password = "$PASSWORD"
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac("sha512", password.encode(), salt, 100000)
print("@ByteArray(" + base64.b64encode(salt).decode() + ":" + base64.b64encode(dk).decode() + ")")
EOF
)

echo "Writing qBittorrent config..."
cat > "/home/$USERNAME/.config/qBittorrent/qBittorrent.conf" <<EOF
[Application]
MemoryWorkingSetLimit=2048

[BitTorrent]
Session\\AsyncIOThreadsCount=8
Session\\DefaultSavePath=/home/$USERNAME/qbittorrent/Downloads/
Session\\DiskCacheSize=2048
Session\\Port=$QBIT_INCOMING_PORT
Session\\QueueingSystemEnabled=false
Session\\SendBufferLowWatermark=3072
Session\\SendBufferWatermark=15360
Session\\SendBufferWatermarkFactor=200
Session\\DHTEnabled=false
Session\\PeXEnabled=false
Session\\LSDEnabled=false

[LegalNotice]
Accepted=true

[Meta]
MigrationVersion=6

[Network]
Proxy\\HostnameLookupEnabled=false
Proxy\\Profiles\\BitTorrent=true
Proxy\\Profiles\\Misc=true
Proxy\\Profiles\\RSS=true

[Preferences]
WebUI\\Password_PBKDF2="$QBIT_HASH"
WebUI\\Port=$QBIT_PORT
WebUI\\Username=$USERNAME
EOF

chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

cat > /etc/systemd/system/qbittorrent-nox@.service <<EOF
[Unit]
Description=qBittorrent
After=network.target

[Service]
Type=forking
User=%i
LimitNOFILE=infinity
ExecStart=$QBIT_BIN -d
ExecStop=/usr/bin/killall -w -s 9 qbittorrent-nox
Restart=on-failure
TimeoutStopSec=20
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "Installing FileBrowser..."
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

cat > /etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=File Browser
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/filebrowser \\
  --database /root/filebrowser.db \\
  --root /home/$USERNAME \\
  --address 0.0.0.0 \\
  --port $FILEBROWSER_PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Installing autobrr..."
mkdir -p /opt/autobrr
cd /opt/autobrr

AUTOBRR_URL=$(curl -s https://api.github.com/repos/autobrr/autobrr/releases/latest \
  | grep browser_download_url \
  | grep -E "autobrr.*${AUTOBRR_ARCH}.*tar.gz" \
  | cut -d '"' -f4 | head -n 1)

if [ -z "$AUTOBRR_URL" ]; then
  echo "Failed to find autobrr download for $AUTOBRR_ARCH"
  exit 1
fi

wget -O autobrr.tar.gz "$AUTOBRR_URL"
tar -xzf autobrr.tar.gz
chmod +x autobrr
mv -f autobrr /usr/bin/autobrr

cat > /etc/systemd/system/autobrr@.service <<EOF
[Unit]
Description=autobrr service
After=syslog.target network-online.target

[Service]
Type=simple
User=%i
Group=%i
ExecStart=/usr/bin/autobrr --config=/home/%i/.config/autobrr/

[Install]
WantedBy=multi-user.target
EOF

echo "Installing QUI..."
mkdir -p /opt/qui /etc/qui
cd /opt/qui

QUI_URL=$(curl -s https://api.github.com/repos/autobrr/qui/releases/latest \
  | grep browser_download_url \
  | grep -E "linux.*${AUTOBRR_ARCH}.*tar.gz|${AUTOBRR_ARCH}.*tar.gz" \
  | cut -d '"' -f4 | head -n 1)

if [ -z "$QUI_URL" ]; then
  echo "Failed to find QUI download for $AUTOBRR_ARCH"
  exit 1
fi

wget -O qui.tar.gz "$QUI_URL"
tar -xzf qui.tar.gz
chmod +x qui
mv -f qui /usr/local/bin/qui

cat > /etc/qui/config.toml <<EOF
host = "0.0.0.0"
port = $QUI_PORT
logLevel = "INFO"
EOF

cat > /etc/systemd/system/qui.service <<EOF
[Unit]
Description=Qui - Unified qBittorrent Index
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/qui serve --config-dir /etc/qui/
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
WorkingDirectory=/etc/qui

[Install]
WantedBy=multi-user.target
EOF

echo "Installing extra tools..."
pip3 install --break-system-packages mkbrr || pip3 install mkbrr || true

echo "Applying BBR/fq tuning..."
cat > /etc/sysctl.d/99-seedbox.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max=2097152
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
EOF

sysctl --system || true
tuned-adm profile virtual-guest || true

echo "* soft nofile 1048576" >> /etc/security/limits.conf
echo "* hard nofile 1048576" >> /etc/security/limits.conf

echo "Configuring firewall..."
ufw allow OpenSSH
ufw allow "$QBIT_PORT"
ufw allow "$QBIT_INCOMING_PORT"
ufw allow "$FILEBROWSER_PORT"
ufw allow "$AUTOBRR_PORT"
ufw allow "$QUI_PORT"
ufw --force enable

echo "Starting services..."
systemctl daemon-reload
systemctl enable "qbittorrent-nox@$USERNAME"
systemctl enable "autobrr@$USERNAME"
systemctl enable filebrowser
systemctl enable qui

systemctl restart "qbittorrent-nox@$USERNAME"
systemctl restart "autobrr@$USERNAME"
systemctl restart filebrowser
systemctl restart qui

echo ""
echo "============================================================"
echo ">> Installation Complete"
echo "============================================================"
echo "All selected installation steps have completed."
echo ""
echo " Public IP                  : $PUBLIC_IP"
echo " Username                   : $USERNAME"
echo " Password                   : $PASSWORD"
echo ""
echo " FileBrowser                : http://$PUBLIC_IP:$FILEBROWSER_PORT"
echo " qBittorrent                : http://$PUBLIC_IP:$QBIT_PORT"
echo " Autobrr                    : http://$PUBLIC_IP:$AUTOBRR_PORT"
echo " Qui                        : http://$PUBLIC_IP:$QUI_PORT"
echo ""
echo "Media Tools Installed: ffmpeg, mediainfo, aria2, mkvtoolnix, mktorrent, mkbrr, fastfetch"
echo "Downloads Path: /home/$USERNAME/qbittorrent/Downloads/"
echo ""
echo "[WARN] Full log: $LOG_FILE"
echo "BBR/fq was applied. A reboot may be required for full effect."
echo "============================================================"