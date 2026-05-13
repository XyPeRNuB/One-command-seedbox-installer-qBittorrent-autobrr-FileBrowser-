<div align="center">

```
 ███╗   ███╗ █████╗ ███╗   ███╗██╗   ██╗    ████████╗██╗   ██╗███╗   ██╗██╗███╗   ██╗ ██████╗
 ████╗ ████║██╔══██╗████╗ ████║██║   ██║    ╚══██╔══╝██║   ██║████╗  ██║██║████╗  ██║██╔════╝
 ██╔████╔██║███████║██╔████╔██║██║   ██║       ██║   ██║   ██║██╔██╗ ██║██║██╔██╗ ██║██║  ███╗
 ██║╚██╔╝██║██╔══██║██║╚██╔╝██║██║   ██║       ██║   ██║   ██║██║╚██╗██║██║██║╚██╗██║██║   ██║
 ██║ ╚═╝ ██║██║  ██║██║ ╚═╝ ██║╚██████╔╝       ██║   ╚██████╔╝██║ ╚████║██║██║ ╚████║╚██████╔╝
 ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝        ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝
```

**Seedbox Installer v2.0**

A clean, interactive seedbox installer for Debian/Ubuntu with kernel tuning and pre-configured qBittorrent optimized for private tracker racing. Features install/uninstall support and swizzin-style UI.

[![OS](https://img.shields.io/badge/OS-Debian%2011%2F12%20%7C%20Ubuntu%2020.04%2B-blue?style=flat-square)](https://debian.org)
[![Arch](https://img.shields.io/badge/Arch-ARM64%20%7C%20x86__64-green?style=flat-square)](https://github.com/XyPeRNuB/mamu_tuning)

</div>

---

## 🚀 Quick Install

```bash
bash <(curl -sL https://raw.githubusercontent.com/XyPeRNuB/mamu_tuning/main/install.sh)
```

Or with wget:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/XyPeRNuB/mamu_tuning/main/install.sh)
```

> Run as **root**. Supports Debian 11/12 and Ubuntu 20.04/22.04/24.04 on both ARM64 and x86_64.

---

## 📺 Interface

Interactive whiptail UI — like swizzin. Navigate with arrow keys, Space to select, Enter to confirm.

```
┌─────────────────────────────────────────────────────────────┐
│                   Mamu Seedbox — Apps                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Select apps to install:                                    │
│  [INSTALLED] = already on system, will be skipped           │
│                                                             │
│  [ ] qBittorrent-nox  (torrent client)                      │
│  [ ] rTorrent + ruTorrent  (web UI)                         │
│  [ ] autobrr  (autodl / racing)                             │
│  [ ] Jellyfin  (media server)                               │
│  [ ] FileBrowser  (file manager)                            │
│  [*] Kernel tuning  (BBR + optimizations)                   │
│  [*] Create 4GB swapfile                                    │
│                                                             │
│               <OK>              <Cancel>                    │
└─────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────┐
│                qBittorrent — Version                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  (*) 4.6.7   (recommended, stable)                          │
│  ( ) 4.6.6                                                  │
│  ( ) 4.6.5                                                  │
│  ( ) 4.6.4                                                  │
│  ( ) 4.6.3                                                  │
│  ( ) 4.6.2                                                  │
│  ( ) 4.5.5                                                  │
│  ( ) 4.5.4                                                  │
│                                                             │
│               <OK>              <Cancel>                    │
└─────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────┐
│                 What do you want to do?                     │
│                                                             │
│  (*) Install / Add new apps                                 │
│  ( ) Uninstall / Remove apps                               │
│                                                             │
│               <OK>              <Cancel>                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Apps

| App | Description | Default Port |
|-----|-------------|-------------|
| **qBittorrent-nox** | Torrent client with pre-tuned config | WebUI: `8080` · Peer: `45000` |
| **rTorrent + ruTorrent** | rTorrent daemon with ruTorrent web UI | `8090` |
| **autobrr** | Autodl / torrent racing automation | `7474` |
| **Jellyfin** | Open source media server | `8096` |
| **FileBrowser** | Web-based file manager | `8888` |

> All ports are configurable during install. Already installed apps are detected and skipped automatically.

---

## ⚙️ Kernel Tuning

Clean, proven sysctl tuning — no over-optimization.

### Network
| Setting | Value | Effect |
|---------|-------|--------|
| Congestion control | BBR | Better throughput |
| Queue discipline | FQ | Fair packet pacing |
| rmem_max / wmem_max | 64MB | Balanced socket buffers |
| netdev_max_backlog | 100,000 | Handle packet bursts |
| somaxconn | 524,288 | High connection queue |
| tcp_max_syn_backlog | 524,288 | SYN flood resilience |
| tcp_fastopen | 3 | Faster connection setup |
| tcp_tw_reuse | enabled | Reuse TIME_WAIT sockets |
| tcp_notsent_lowat | 128KB | Reduce bufferbloat |

### System
| Setting | Value | Effect |
|---------|-------|--------|
| File descriptors | 1,048,576 | Handle thousands of torrents |
| pid_max | 4,194,303 | More processes |
| I/O scheduler | mq-deadline | Optimal for SSD/NVMe |
| vm.swappiness | 10 | Keep hot data in RAM |
| Swapfile | 4GB | OOM protection |
| tuned daemon | disabled | Prevents sysctl override |

---

## 🔧 qBittorrent Pre-tuning

Pre-configured with proven racing settings for private trackers.

| Setting | Value | Why |
|---------|-------|-----|
| Async IO threads | = CPU core count | Max parallel disk IO |
| Disk cache | 2048 MB | Fast piece access |
| Protocol | TCP only | Max bandwidth for private trackers |
| Max connections | 500 | TorrentBD recommended |
| Max conn/torrent | 100 | TorrentBD recommended |
| Upload slots | 20 | TorrentBD recommended |
| Upload slots/torrent | 10 | TorrentBD recommended |
| DHT / PeX / LSD | Disabled | Required for private trackers |
| Send buffer watermark | 15360 | Proven racing value |
| Speed limits | Unlimited | Full bandwidth |
| Rate limit overhead | Disabled | Don't count overhead |

---

## 🖥️ Supported Platforms

| OS | Versions | ARM64 | x86_64 |
|----|----------|-------|--------|
| Debian | 11, 12 | ✅ | ✅ |
| Ubuntu | 20.04, 22.04, 24.04 | ✅ | ✅ |

---

## 📋 Requirements

- Fresh VPS or dedicated server
- Root access
- Minimum 1GB RAM (4GB+ recommended)
- Minimum 20GB disk space

---

## 🔁 Re-running the Installer

Safe to run multiple times. Already installed apps are detected and skipped — only new selections get installed.

```bash
bash <(curl -sL https://raw.githubusercontent.com/XyPeRNuB/mamu_tuning/main/install.sh)
```

---

## 📁 File Structure

```
/etc/sysctl.d/99-seedbox.conf       ← kernel tuning settings
/etc/systemd/system/sysctl-seedbox.service  ← apply on boot
/etc/udev/rules.d/60-io-scheduler.rules     ← I/O scheduler
/home/<user>/.config/qBittorrent/   ← qBit config
/home/<user>/rtorrent/              ← rTorrent data
/etc/filebrowser/                   ← FileBrowser config
```

---

<div align="center">
Happy Racing 🏁
</div>
