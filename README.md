<div align="center">

```
██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗███████╗
██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║██╔════╝
██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║█████╗  
██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║██╔══╝  
╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗
 ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝
```

**Seedbox Installer v2.0**

A modular, interactive seedbox installer for Debian/Ubuntu with full kernel-level tuning baked in.

[![OS](https://img.shields.io/badge/OS-Debian%2011%2F12%20%7C%20Ubuntu%2020.04%2B-blue?style=flat-square)](https://debian.org)
[![Arch](https://img.shields.io/badge/Arch-ARM64%20%7C%20x86__64-green?style=flat-square)](https://github.com/XyPeRNuB/mamu_tuning)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)

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

The installer uses an interactive whiptail UI — just like swizzin. Navigate with arrow keys, Space to select, Enter to confirm.

```
┌─────────────────────────────────────────────────────────────┐
│                   Mamu Seedbox — Apps                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Select apps to install:                                    │
│  [INSTALLED] = already on system, will be skipped           │
│  (Space to select, Enter to confirm)                        │
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

Full kernel-level tuning applied automatically — no manual config needed.

### Network
| Setting | Value | Effect |
|---------|-------|--------|
| Congestion control | BBR | Aggressive throughput maximization |
| rmem_max / wmem_max | 512MB | Massive socket buffers for high peer counts |
| tcp_rmem / tcp_wmem | 4K → 512MB | Auto-scaling TCP buffers |
| txqueuelen | 10,000 | Huge NIC transmit queue |
| initcwnd / initrwnd | 32 | Fast TCP ramp-up from first packet |
| NIC ring buffer | Maximum | Zero packet drops under load |
| IRQ affinity | All cores | Network interrupts spread across CPUs |
| TSO / GSO / GRO | Disabled | Lower latency on VMs |

### System
| Setting | Value | Effect |
|---------|-------|--------|
| File descriptors | 1,048,576 | Handle thousands of open torrents |
| Conntrack max | 1,048,576 | Handle massive peer swarms |
| I/O scheduler | mq-deadline | Optimal for SSD/NVMe |
| Read-ahead | 4MB | Faster piece reading during seeding |
| CPU governor | performance | No CPU throttling during races |
| vm.swappiness | 10 | Keep hot data in RAM |
| Swapfile | 4GB | OOM protection |

### BDIX Optimization
Special routing optimization for **Bangladesh Internet Exchange** peers. All major BD ISP ranges (40+ subnets) get `initcwnd 64` — double the standard congestion window — for maximum local peering speed.

Includes routing for: Link3, Carnival, BTCL, Grameenphone, Dhaka Fiber Net, BDCOM, and more.

### Boot Persistence
All runtime tuning (txqueuelen, IRQ affinity, CPU governor, ring buffer, initcwnd) is re-applied on every reboot via a systemd boot script. Nothing gets lost after restart.

---

## 🔧 qBittorrent Pre-tuning

qBittorrent is installed with an optimized config out of the box — no manual tweaking needed.

| Setting | Value | Why |
|---------|-------|-----|
| Async IO threads | = CPU core count | Max parallel disk IO |
| Disk cache | RAM / 4 | Fast piece access |
| Send buffer | 512KB | Matched to kernel buffers |
| Max connections | 3,000 | Handle large swarms |
| Upload slots/torrent | 100 | Seed to many peers fast |
| Suggest mode | Enabled | Tell peers what you have |
| uTP mode | TCP preferred | Better for private trackers |
| Multiple connections/IP | Enabled | More peers per host |
| Announce to all tiers | Enabled | Faster tracker announces |

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
- Minimum 1GB RAM (4GB+ recommended for racing)
- Minimum 20GB disk space

---

## 🔁 Re-running the Installer

Safe to run multiple times. Already installed apps are detected automatically and skipped — only new selections get installed.

```bash
# Run again to add more apps
bash <(curl -sL https://raw.githubusercontent.com/XyPeRNuB/mamu_tuning/main/install.sh)
```

---

## 📁 File Structure

```
/etc/sysctl.d/99-seedbox.conf       ← kernel tuning settings
/etc/systemd/system/sysctl-seedbox.service  ← apply on boot
/root/.boot-script.sh               ← runtime tuning on reboot
/etc/udev/rules.d/60-io-scheduler.rules     ← I/O scheduler
/home/<user>/.config/qBittorrent/   ← qBit config
/home/<user>/rtorrent/              ← rTorrent data
/etc/filebrowser/                   ← FileBrowser config
```

---

## 🙏 Credits

- Kernel tuning approach inspired by [jerry048/Dedicated-Seedbox](https://github.com/jerry048/Dedicated-Seedbox)
- UI style inspired by [swizzin/swizzin](https://github.com/swizzin/swizzin)
- qBittorrent static builds by [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static)

---

<div align="center">
Made with ❤️ by <a href="https://github.com/XyPeRNuB">XyPeRNuB</a> · Happy Racing 🏁
</div>
