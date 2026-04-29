#!/bin/bash
set -e

SERVER_IP=$(curl -s4 ifconfig.me || hostname -I | awk '{print $1}')

apt update && apt upgrade -y

apt install -y curl wget gnupg ca-certificates unzip software-properties-common \
nginx php-fpm php-cli php-curl php-xml php-mbstring php-json php-zip \
rtorrent screen git ufw qbittorrent-nox

mkdir -p /home/seedbox/downloads /home/seedbox/watch /home/seedbox/.session

cat > /etc/systemd/system/qbittorrent.service <<EOF
[Unit]
Description=qBittorrent-nox
After=network.target

[Service]
User=root
ExecStart=/usr/bin/qbittorrent-nox --webui-port=8080
Restart=always
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

cat > /etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/filebrowser -r /home/seedbox -p 8081
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > /root/.rtorrent.rc <<EOF
directory = /home/seedbox/downloads
session = /home/seedbox/.session
schedule2 = watch_directory,5,5,load.start=/home/seedbox/watch/*.torrent
network.port_range.set = 50000-50000
network.port_random.set = no
dht.mode.set = auto
protocol.pex.set = yes
trackers.use_udp.set = yes
encoding.add = UTF-8
scgi_port = 127.0.0.1:5000
EOF

cat > /etc/systemd/system/rtorrent.service <<EOF
[Unit]
Description=rTorrent
After=network.target

[Service]
Type=forking
User=root
ExecStart=/usr/bin/screen -dmS rtorrent /usr/bin/rtorrent
ExecStop=/usr/bin/screen -S rtorrent -X quit
Restart=always

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /var/www/rutorrent
git clone https://github.com/Novik/ruTorrent.git /var/www/rutorrent
chown -R www-data:www-data /var/www/rutorrent

cat > /etc/nginx/sites-available/rutorrent <<EOF
server {
    listen 8082;
    server_name _;

    root /var/www/rutorrent;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }

    location /RPC2 {
        scgi_pass 127.0.0.1:5000;
        include scgi_params;
    }
}
EOF

ln -sf /etc/nginx/sites-available/rutorrent /etc/nginx/sites-enabled/rutorrent
rm -f /etc/nginx/sites-enabled/default

mkdir -p /opt/autobrr
cd /opt/autobrr
wget -O autobrr.tar.gz https://github.com/autobrr/autobrr/releases/latest/download/autobrr_linux_arm64.tar.gz
tar -xzf autobrr.tar.gz
chmod +x autobrr
ln -sf /opt/autobrr/autobrr /usr/local/bin/autobrr

cat > /etc/systemd/system/autobrr.service <<EOF
[Unit]
Description=autobrr
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/autobrr --host 0.0.0.0 --port 7474
Restart=always

[Install]
WantedBy=multi-user.target
EOF

ufw allow OpenSSH
ufw allow 8080
ufw allow 8081
ufw allow 8082
ufw allow 7474
ufw allow 50000
ufw --force enable

systemctl daemon-reload
systemctl enable qbittorrent filebrowser rtorrent nginx autobrr
systemctl restart nginx
systemctl start qbittorrent filebrowser rtorrent autobrr

echo ""
echo "DONE."
echo "qBittorrent: http://$SERVER_IP:8080"
echo "FileBrowser: http://$SERVER_IP:8081"
echo "ruTorrent: http://$SERVER_IP:8082"
echo "autobrr: http://$SERVER_IP:7474"
echo ""
echo "Change passwords immediately."