#!/bin/bash
set -e

echo "===================================="
echo " Mamu Seedbox Installer"
echo " qBittorrent + FileBrowser + autobrr"
echo "===================================="

SERVER_IP=$(curl -s https://ipinfo.io/ip || curl -s4 ifconfig.me || hostname -I | awk '{print $1}')
echo "Detected server IP: $SERVER_IP"

read -p "qBittorrent WebUI port [8080]: " QBIT_PORT
QBIT_PORT=${QBIT_PORT:-8080}

read -p "qBittorrent username [admin]: " QBIT_USER
QBIT_USER=${QBIT_USER:-admin}

read -s -p "qBittorrent password: " QBIT_PASS
echo ""

read -p "FileBrowser port [8081]: " FB_PORT
FB_PORT=${FB_PORT:-8081}

read -p "autobrr port [7474]: " AUTOBRR_PORT
AUTOBRR_PORT=${AUTOBRR_PORT:-7474}

echo ""
echo "Choose qBittorrent version:"
echo "1) 4.6.7"
echo "2) Debian default"
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

apt update && apt upgrade -y
apt install -y curl wget tar ufw ca-certificates python3

mkdir -p /home/seedbox/downloads
mkdir -p /root/.config/qBittorrent
mkdir -p /opt/autobrr

if [ "$QBIT_CHOICE" = "1" ]; then
  echo "Installing qBittorrent 4.6.7 static build..."
  wget -O /usr/local/bin/qbittorrent-nox \
  "https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.6.7_v2.0.10/${QBT_ARCH}-qbittorrent-nox"
  chmod +x /usr/local/bin/qbittorrent-nox
else
  echo "Installing Debian default qBittorrent..."
  apt install -y qbittorrent-nox
fi

QBIT_BIN=$(command -v qbittorrent-nox)

cat > /etc/systemd/system/qbittorrent.service <<EOF
[Unit]
Description=qBittorrent-nox
After=network.target

[Service]
User=root
ExecStart=$QBIT_BIN --webui-port=$QBIT_PORT
Restart=always
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start qbittorrent || true
sleep 3
systemctl stop qbittorrent || true

QBIT_HASH=$(python3 - <<EOF
import hashlib, os, base64
password = "$QBIT_PASS"
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac("sha512", password.encode(), salt, 100000)
print("@ByteArray(" + base64.b64encode(salt).decode() + ":" + base64.b64encode(dk).decode() + ")")
EOF
)

cat > /root/.config/qBittorrent/qBittorrent.conf <<EOF
[LegalNotice]
Accepted=true

[Preferences]
Connection\\PortRangeMin=50000
Connection\\PortRangeMax=50000
Connection\\UPnP=true
Connection\\GlobalDLLimit=0
Connection\\GlobalUPLimit=0
Connection\\GlobalDLLimitAlt=0
Connection\\GlobalUPLimitAlt=0
Connection\\MaxConnecs=-1
Connection\\MaxConnecsPerTorrent=-1
Connection\\MaxUploads=-1
Connection\\MaxUploadsPerTorrent=-1
Bittorrent\\DHT=false
Bittorrent\\PeX=false
Bittorrent\\LSD=false
Bittorrent\\QueueingSystemEnabled=false
Bittorrent\\uTP=false
WebUI\\Enabled=true
WebUI\\Port=$QBIT_PORT
WebUI\\Username=$QBIT_USER
WebUI\\Password_PBKDF2=$QBIT_HASH
Downloads\\SavePath=/home/seedbox/downloads/
EOF

echo "Installing FileBrowser..."
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

cat > /etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/filebrowser -r /home/seedbox -p $FB_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Installing autobrr..."
cd /opt/autobrr

AUTOBRR_URL=$(curl -s https://api.github.com/repos/autobrr/autobrr/releases/latest \
  | grep browser_download_url \
  | grep -E "autobrr.*${AUTOBRR_ARCH}.*tar.gz" \
  | cut -d '"' -f4 | head -n 1)

if [ -z "$AUTOBRR_URL" ]; then
  echo "Failed to find autobrr download for $AUTOBRR_ARCH"
  exit 1
fi

echo "Downloading: $AUTOBRR_URL"

wget -O autobrr.tar.gz "$AUTOBRR_URL"
tar -xzf autobrr.tar.gz
chmod +x autobrr
ln -sf /opt/autobrr/autobrr /usr/local/bin/autobrr

cat > /etc/systemd/system/autobrr.service <<EOF
[Unit]
Description=autobrr
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/autobrr --host 0.0.0.0 --port $AUTOBRR_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

ufw allow OpenSSH
ufw allow "$QBIT_PORT"
ufw allow "$FB_PORT"
ufw allow "$AUTOBRR_PORT"
ufw allow 50000
ufw --force enable

systemctl daemon-reload
systemctl enable qbittorrent filebrowser autobrr
systemctl restart qbittorrent filebrowser autobrr

echo ""
echo "===================================="
echo "INSTALL COMPLETE"
echo "===================================="
echo "qBittorrent: http://$SERVER_IP:$QBIT_PORT"
echo "FileBrowser: http://$SERVER_IP:$FB_PORT"
echo "autobrr: http://$SERVER_IP:$AUTOBRR_PORT"
echo ""
echo "qBittorrent username: $QBIT_USER"
echo "qBittorrent password: the one you entered"
echo "===================================="