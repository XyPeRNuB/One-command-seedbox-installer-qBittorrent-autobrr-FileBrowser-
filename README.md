# Mamu Seedbox Installer

One-command installer for a lightweight torrent stack.

## Quick Install

Run this on your VPS:

```bash
bash <(curl -sL https://raw.githubusercontent.com/XyPeRNuB/meh/main/install.sh)
Features
qBittorrent (version selectable)
FileBrowser (web file manager)
autobrr (automation tool)
Automatic service setup (systemd)
Firewall configuration (UFW)
Custom ports, username, and password
What the Script Does
During installation, you will:
Enter your server IP or domain
Choose qBittorrent version
Set WebUI ports
Set username and password
Configure FileBrowser and autobrr
Access After Installation
qBittorrent → http://YOUR_IP:PORT
FileBrowser → http://YOUR_IP:PORT
autobrr → http://YOUR_IP:PORT
Security Notes
Change passwords immediately after install
Consider enabling Fail2Ban
Avoid exposing services publicly without protection
Requirements
Debian or Ubuntu VPS
Root access
Open ports for selected services
Disclaimer

This script is provided as-is.
Use it at your own risk.

Author

Mamu