#!/usr/bin/env bash
# ============================================================
#  Mamu Seedbox Installer v2.0
#  Author: XyPeRNuB
#  Supports: Debian 11/12 · Ubuntu 20.04/22.04/24.04
#  Arch:     x86_64 · ARM64 (aarch64)
#  UI:       whiptail (swizzin-style)
#  Tuning:   Jerry048 kernel stack + custom qBit tuning
# ============================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

info()    { echo -e "  ${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "  ${GREEN}[ OK ]${NC}  $*"; }
warn()    { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "  ${RED}[ERR ]${NC}  $*"; exit 1; }
section() { echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; \
            echo -e "${BOLD}${CYAN}  $* ${NC}"; \
            echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# ── Spinner ──────────────────────────────────────────────────
spinner() {
    local pid=$1 msg=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}${spin:$i:1}${NC}  %s   " "$msg"
        i=$(( (i+1) % ${#spin} ))
        sleep 0.08
    done
    wait "$pid"; local rc=$?
    tput cnorm 2>/dev/null || true
    if [[ $rc -eq 0 ]]; then
        printf "\r  ${GREEN}✓${NC}  %s               \n" "$msg"
    else
        printf "\r  ${RED}✗${NC}  %s ${RED}[FAILED]${NC}\n" "$msg"
        [[ -f /tmp/mamu_err.log ]] && echo -e "${DIM}$(tail -3 /tmp/mamu_err.log)${NC}"
    fi
    return $rc
}

run_step() {
    local msg=$1; shift
    ("$@" >/tmp/mamu_step.log 2>/tmp/mamu_err.log) &
    spinner $! "$msg" || true
}

# ── Root + OS check ──────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Run as root: sudo bash install.sh"
[[ -f /etc/os-release ]] || error "Cannot detect OS."
source /etc/os-release
[[ "$ID" =~ ^(debian|ubuntu)$ ]] || error "Debian/Ubuntu only. Detected: $ID"

# ── System info ──────────────────────────────────────────────
NCORES=$(nproc)
TOTAL_RAM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
CACHE_MB=$(( TOTAL_RAM_MB / 4 ))
ARCH=$(uname -m)
[[ "$ARCH" == "aarch64" ]] && ARCH_LABEL="ARM64" || ARCH_LABEL="x86_64"
[[ "$ARCH" == "aarch64" ]] && QB_ARCH="aarch64" || QB_ARCH="x86_64"
[[ "$ARCH" == "aarch64" ]] && AB_ARCH="arm64"   || AB_ARCH="amd64"

# ── Ensure whiptail ──────────────────────────────────────────
command -v whiptail &>/dev/null || apt-get install -y -qq whiptail

# ============================================================
#  BANNER
# ============================================================
clear
echo -e "${CYAN}${BOLD}"
cat << 'BANNER'

  ███╗   ███╗ █████╗ ███╗   ███╗██╗   ██╗
  ████╗ ████║██╔══██╗████╗ ████║██║   ██║
  ██╔████╔██║███████║██╔████╔██║██║   ██║
  ██║╚██╔╝██║██╔══██║██║╚██╔╝██║██║   ██║
  ██║ ╚═╝ ██║██║  ██║██║ ╚═╝ ██║╚██████╔╝
  ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝
   Seedbox Installer v2.0

BANNER
echo -e "${NC}"
echo -e "  ${DIM}OS: $PRETTY_NAME${NC}"
echo -e "  ${DIM}Arch: $ARCH_LABEL  |  CPU: ${NCORES} cores  |  RAM: ${TOTAL_RAM_MB}MB${NC}"
echo ""
sleep 1

# ============================================================
#  WHIPTAIL UI — CREDENTIALS
# ============================================================
# Username
USERNAME=$(whiptail --inputbox \
    "Enter a username for your seedbox:" 10 60 "admin" \
    --title "Mamu Seedbox — Setup" 3>&1 1>&2 2>&3) || error "Cancelled."
[[ -z "$USERNAME" ]] && error "Username cannot be empty."

# Password
PASSWORD=$(whiptail --passwordbox \
    "Enter a password:" 10 60 \
    --title "Mamu Seedbox — Setup" 3>&1 1>&2 2>&3) || error "Cancelled."
[[ -z "$PASSWORD" ]] && error "Password cannot be empty."

PASSWORD2=$(whiptail --passwordbox \
    "Confirm password:" 10 60 \
    --title "Mamu Seedbox — Setup" 3>&1 1>&2 2>&3) || error "Cancelled."
[[ "$PASSWORD" != "$PASSWORD2" ]] && error "Passwords do not match."

# Download directory
DOWNLOAD_DIR=$(whiptail --inputbox \
    "Download directory:" 10 60 "/home/${USERNAME}/downloads" \
    --title "Mamu Seedbox — Setup" 3>&1 1>&2 2>&3) || error "Cancelled."

# ============================================================
#  WHIPTAIL UI — APP SELECTION (checkbox style like swizzin)
# ============================================================
APPS=$(whiptail --checklist \
    "Select apps to install:\n(Space to select, Enter to confirm)" \
    22 60 10 \
    "qbittorrent"  "qBittorrent-nox (torrent client)"   OFF \
    "rtorrent"     "rTorrent + ruTorrent (web UI)"       OFF \
    "autobrr"      "autobrr (autodl/racing)"             OFF \
    "jellyfin"     "Jellyfin (media server)"             OFF \
    "filebrowser"  "FileBrowser (file manager)"          OFF \
    "tuning"       "Kernel tuning (BBR + optimizations)" ON  \
    "swap"         "Create 4GB swapfile"                 ON  \
    --title "Mamu Seedbox — Apps" 3>&1 1>&2 2>&3) || error "Cancelled."

# Parse selections
INSTALL_QBT=0; INSTALL_RT=0; INSTALL_AB=0
INSTALL_JF=0; INSTALL_FB=0; DO_TUNING=0; DO_SWAP=0

[[ "$APPS" == *"qbittorrent"*  ]] && INSTALL_QBT=1
[[ "$APPS" == *"rtorrent"*     ]] && INSTALL_RT=1
[[ "$APPS" == *"autobrr"*      ]] && INSTALL_AB=1
[[ "$APPS" == *"jellyfin"*     ]] && INSTALL_JF=1
[[ "$APPS" == *"filebrowser"*  ]] && INSTALL_FB=1
[[ "$APPS" == *"tuning"*       ]] && DO_TUNING=1
[[ "$APPS" == *"swap"*         ]] && DO_SWAP=1

# ── Nothing selected ─────────────────────────────────────────
if [[ $INSTALL_QBT -eq 0 && $INSTALL_RT -eq 0 && $INSTALL_AB -eq 0 && \
      $INSTALL_JF -eq 0 && $INSTALL_FB -eq 0 && $DO_TUNING -eq 0 ]]; then
    whiptail --msgbox "Nothing selected. Exiting." 8 40 --title "Mamu Seedbox"
    exit 0
fi

# ============================================================
#  WHIPTAIL UI — VERSION SELECTION (qBittorrent)
# ============================================================
QBT_METHOD="apt"
QBT_WEBUI_PORT="8080"
QBT_PORT="45000"

if [[ $INSTALL_QBT -eq 1 ]]; then
    QBT_METHOD=$(whiptail --menu \
        "qBittorrent install method:" 15 65 2 \
        "apt"    "Debian/Ubuntu repos (older, stable)" \
        "static" "Specific version — static build (recommended)" \
        --title "qBittorrent — Install Method" 3>&1 1>&2 2>&3) || error "Cancelled."

    if [[ "$QBT_METHOD" == "static" ]]; then
        QBT_VER=$(whiptail --menu \
            "Select qBittorrent version:\n(All versions support ARM64 + x86_64)" \
            22 65 10 \
            "4.6.7"  "qBittorrent 4.6.7  (recommended, stable)" \
            "4.6.6"  "qBittorrent 4.6.6" \
            "4.6.5"  "qBittorrent 4.6.5" \
            "4.6.4"  "qBittorrent 4.6.4" \
            "4.6.3"  "qBittorrent 4.6.3" \
            "4.6.2"  "qBittorrent 4.6.2" \
            "4.6.1"  "qBittorrent 4.6.1" \
            "4.6.0"  "qBittorrent 4.6.0" \
            "4.5.5"  "qBittorrent 4.5.5" \
            "4.5.4"  "qBittorrent 4.5.4" \
            --title "qBittorrent — Version" 3>&1 1>&2 2>&3) || error "Cancelled."
    fi

    QBT_WEBUI_PORT=$(whiptail --inputbox \
        "qBittorrent WebUI port:" 10 50 "8080" \
        --title "qBittorrent — Ports" 3>&1 1>&2 2>&3) || error "Cancelled."

    QBT_PORT=$(whiptail --inputbox \
        "qBittorrent peer/listen port:" 10 50 "45000" \
        --title "qBittorrent — Ports" 3>&1 1>&2 2>&3) || error "Cancelled."
fi

# ── rTorrent ports ───────────────────────────────────────────
RT_PORT="8090"
RT_PEER_PORT="49164"
if [[ $INSTALL_RT -eq 1 ]]; then
    RT_PORT=$(whiptail --inputbox \
        "ruTorrent web port:" 10 50 "8090" \
        --title "rTorrent — Ports" 3>&1 1>&2 2>&3) || error "Cancelled."
    RT_PEER_PORT=$(whiptail --inputbox \
        "rTorrent peer port:" 10 50 "49164" \
        --title "rTorrent — Ports" 3>&1 1>&2 2>&3) || error "Cancelled."
fi

# ── autobrr port ─────────────────────────────────────────────
AB_PORT="7474"
if [[ $INSTALL_AB -eq 1 ]]; then
    AB_PORT=$(whiptail --inputbox \
        "autobrr port:" 10 50 "7474" \
        --title "autobrr — Port" 3>&1 1>&2 2>&3) || error "Cancelled."
fi

# ── Jellyfin port ────────────────────────────────────────────
JF_PORT="8096"
if [[ $INSTALL_JF -eq 1 ]]; then
    JF_PORT=$(whiptail --inputbox \
        "Jellyfin port:" 10 50 "8096" \
        --title "Jellyfin — Port" 3>&1 1>&2 2>&3) || error "Cancelled."
fi

# ── FileBrowser port ─────────────────────────────────────────
FB_PORT="8888"
if [[ $INSTALL_FB -eq 1 ]]; then
    FB_PORT=$(whiptail --inputbox \
        "FileBrowser port:" 10 50 "8888" \
        --title "FileBrowser — Port" 3>&1 1>&2 2>&3) || error "Cancelled."
fi

# ── Confirm summary ──────────────────────────────────────────
QBT_VER="${QBT_VER:-apt}"
SUMMARY="User: $USERNAME\nDownloads: $DOWNLOAD_DIR\n\n"
[[ $INSTALL_QBT -eq 1 ]] && SUMMARY+="✓ qBittorrent v${QBT_VER}  WebUI :${QBT_WEBUI_PORT}  Peer :${QBT_PORT}\n"
[[ $INSTALL_RT  -eq 1 ]] && SUMMARY+="✓ rTorrent + ruTorrent  :${RT_PORT}\n"
[[ $INSTALL_AB  -eq 1 ]] && SUMMARY+="✓ autobrr  :${AB_PORT}\n"
[[ $INSTALL_JF  -eq 1 ]] && SUMMARY+="✓ Jellyfin  :${JF_PORT}\n"
[[ $INSTALL_FB  -eq 1 ]] && SUMMARY+="✓ FileBrowser  :${FB_PORT}\n"
[[ $DO_TUNING   -eq 1 ]] && SUMMARY+="✓ Kernel tuning (Jerry's stack)\n"
[[ $DO_SWAP     -eq 1 ]] && SUMMARY+="✓ 4GB swapfile\n"

whiptail --yesno "$SUMMARY\nProceed with installation?" 22 65 \
    --title "Mamu Seedbox — Confirm" --yes-button "Install" --no-button "Cancel" \
    3>&1 1>&2 2>&3 || { echo "Aborted."; exit 0; }

# ============================================================
#  BEGIN INSTALLATION
# ============================================================
clear
echo ""
echo -e "${BOLD}${CYAN}  Starting Mamu Seedbox Installation...${NC}"
echo ""

# ── System update ────────────────────────────────────────────
section "System Preparation"

_system_prep() {
    apt-get update -qq
    apt-get upgrade -y -qq
    apt-get install -y -qq \
        curl wget git unzip tar \
        ca-certificates gnupg lsb-release \
        software-properties-common \
        ufw fail2ban htop iotop \
        net-tools ethtool iproute2 \
        python3 python3-pip \
        apache2-utils build-essential \
        bc jq 2>/dev/null || true
}
run_step "Updating system packages" _system_prep

# ── Create user ──────────────────────────────────────────────
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash "$USERNAME" 2>/dev/null
    echo "${USERNAME}:${PASSWORD}" | chpasswd
    success "User $USERNAME created."
else
    warn "User $USERNAME already exists."
fi

mkdir -p "$DOWNLOAD_DIR"
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}" 2>/dev/null || true

# ── UFW ──────────────────────────────────────────────────────
_setup_ufw() {
    ufw --force reset >/dev/null 2>&1
    ufw default deny incoming >/dev/null 2>&1
    ufw default allow outgoing >/dev/null 2>&1
    ufw allow ssh >/dev/null 2>&1
    [[ $INSTALL_QBT -eq 1 ]] && ufw allow "${QBT_WEBUI_PORT}/tcp" >/dev/null 2>&1
    [[ $INSTALL_QBT -eq 1 ]] && ufw allow "${QBT_PORT}/tcp" >/dev/null 2>&1
    [[ $INSTALL_QBT -eq 1 ]] && ufw allow "${QBT_PORT}/udp" >/dev/null 2>&1
    [[ $INSTALL_RT  -eq 1 ]] && ufw allow "${RT_PORT}/tcp" >/dev/null 2>&1
    [[ $INSTALL_RT  -eq 1 ]] && ufw allow "${RT_PEER_PORT}/tcp" >/dev/null 2>&1
    [[ $INSTALL_AB  -eq 1 ]] && ufw allow "${AB_PORT}/tcp" >/dev/null 2>&1
    [[ $INSTALL_JF  -eq 1 ]] && ufw allow "${JF_PORT}/tcp" >/dev/null 2>&1
    [[ $INSTALL_FB  -eq 1 ]] && ufw allow "${FB_PORT}/tcp" >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1
}
run_step "Configuring firewall (UFW)" _setup_ufw

# ============================================================
#  KERNEL TUNING (Jerry048 stack)
# ============================================================
if [[ $DO_TUNING -eq 1 ]]; then
section "Kernel Tuning"

# ── Swap ─────────────────────────────────────────────────────
if [[ $DO_SWAP -eq 1 ]]; then
    if ! swapon --show | grep -q '/swapfile' 2>/dev/null; then
        _make_swap() {
            fallocate -l 4G /swapfile
            chmod 600 /swapfile
            mkswap /swapfile -q
            swapon /swapfile
            grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
        }
        run_step "Creating 4GB swapfile" _make_swap
    else
        warn "Swapfile already exists."
    fi
fi

# ── Kernel modules ───────────────────────────────────────────
modprobe tcp_bbr    2>/dev/null || true
modprobe nf_conntrack 2>/dev/null || true
echo "tcp_bbr"      > /etc/modules-load.d/bbr.conf
echo "nf_conntrack" > /etc/modules-load.d/conntrack.conf

# ── Kill tuned daemon (overrides sysctl on Netcup/cloud VMs) ─
if systemctl is-active --quiet tuned 2>/dev/null; then
    systemctl stop tuned
    systemctl disable tuned 2>/dev/null || true
    warn "tuned daemon disabled (was overriding network buffers)."
fi

# ── Fix broken @include if present from old installs ─────────
sed -i '/@include/d' /etc/sysctl.conf 2>/dev/null || true

# ── sysctl — Jerry048's exact kernel tuning stack ────────────
_apply_sysctl() {
cat > /etc/sysctl.d/99-seedbox.conf << 'SYSCTL'
# ── NETWORK BUFFERS ────────────────────────────────────────
net.core.rmem_default = 1048576
net.core.rmem_max = 536870912
net.core.wmem_default = 1048576
net.core.wmem_max = 536870912
net.core.optmem_max = 65536
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 65535

# ── TCP ────────────────────────────────────────────────────
net.ipv4.tcp_rmem = 4096 1048576 536870912
net.ipv4.tcp_wmem = 4096 1048576 536870912
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_autocorking = 0

# ── BBR congestion control ─────────────────────────────────
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# ── UDP ────────────────────────────────────────────────────
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# ── Connection tracking ────────────────────────────────────
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_tcp_timeout_established = 600
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 10

# ── File system ────────────────────────────────────────────
fs.file-max = 2097152
fs.nr_open = 2097152
vm.dirty_ratio = 40
vm.dirty_background_ratio = 10
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500

# ── Memory ─────────────────────────────────────────────────
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.max_map_count = 262144

# ── Kernel scheduler (Jerry's values) ─────────────────────
kernel.sched_migration_cost_ns = 5000000
kernel.sched_min_granularity_ns = 10000000
kernel.sched_wakeup_granularity_ns = 15000000
SYSCTL

    # Patch Netcup's sysctl override if present
    if [[ -f /etc/sysctl.d/99-nc-kernel.conf ]]; then
        cp /etc/sysctl.d/99-nc-kernel.conf /etc/sysctl.d/99-nc-kernel.conf.bak
        cat > /etc/sysctl.d/99-nc-kernel.conf << 'NCSYSCTL'
vm.dirty_background_ratio = 10
vm.dirty_ratio = 40
kernel.watchdog_thresh = 20
net.core.rmem_max = 536870912
net.core.wmem_max = 536870912
net.ipv4.tcp_rmem = 4096 1048576 536870912
net.ipv4.tcp_wmem = 4096 1048576 536870912
NCSYSCTL
    fi

    sysctl -p /etc/sysctl.d/99-seedbox.conf >/dev/null 2>&1 || true
}
run_step "Applying kernel sysctl settings" _apply_sysctl

# ── txqueuelen — Jerry's approach ────────────────────────────
_tune_txqueuelen() {
    for iface in $(ls /sys/class/net/ | grep -E '^(eth|ens|eno|enp|venet)'); do
        ip link set "$iface" txqueuelen 10000 2>/dev/null || true
    done
}
run_step "Setting txqueuelen to 10000" _tune_txqueuelen

# ── TSO/GSO/GRO disable (Jerry's approach for VMs) ───────────
_disable_tso() {
    for iface in $(ls /sys/class/net/ | grep -E '^(eth|ens|eno|enp|venet)'); do
        ethtool -K "$iface" tso off gso off gro off 2>/dev/null || true
    done
}
run_step "Disabling TSO/GSO/GRO (VM optimization)" _disable_tso

# ── Initial congestion window (Jerry's approach) ─────────────
_set_initcwnd() {
    DEFAULT_GW=$(ip route | awk '/^default/{print $3}' | head -1)
    DEFAULT_IF=$(ip route | awk '/^default/{print $5}' | head -1)
    if [[ -n "$DEFAULT_GW" && -n "$DEFAULT_IF" ]]; then
        ip route change default via "$DEFAULT_GW" dev "$DEFAULT_IF" \
            initcwnd 32 initrwnd 32 2>/dev/null || true
    fi
}
run_step "Setting initial congestion window to 32" _set_initcwnd

# ── I/O scheduler ────────────────────────────────────────────
_tune_io() {
    DISK=$(lsblk -d -o NAME,TYPE | awk '$2=="disk"{print $1}' | head -1)
    if [[ -n "$DISK" ]]; then
        echo mq-deadline > /sys/block/${DISK}/queue/scheduler 2>/dev/null || true
        echo 256 > /sys/block/${DISK}/queue/nr_requests 2>/dev/null || true
        ROTATIONAL=$(cat /sys/block/${DISK}/queue/rotational 2>/dev/null || echo 1)
        [[ "$ROTATIONAL" == "0" ]] && \
            echo 2 > /sys/block/${DISK}/queue/nomerges 2>/dev/null || true
        cat > /etc/udev/rules.d/60-io-scheduler.rules << 'UDEV'
ACTION=="add|change", KERNEL=="vd[a-z]|sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="vd[a-z]|sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/nr_requests}="256"
UDEV
    fi
}
run_step "Setting I/O scheduler (mq-deadline)" _tune_io

# ── File descriptor limits ───────────────────────────────────
_tune_limits() {
    grep -q '1048576' /etc/security/limits.conf 2>/dev/null || \
    cat >> /etc/security/limits.conf << 'LIMITS'
* soft nofile 1048576
* hard nofile 1048576
* soft nproc  65535
* hard nproc  65535
root soft nofile 1048576
root hard nofile 1048576
LIMITS
    sed -i 's/#DefaultLimitNOFILE=/DefaultLimitNOFILE=1048576/' /etc/systemd/system.conf 2>/dev/null || true
    sed -i 's/#DefaultLimitNPROC=/DefaultLimitNPROC=65535/'     /etc/systemd/system.conf 2>/dev/null || true
    systemctl daemon-reexec >/dev/null 2>&1 || true
}
run_step "Setting file descriptor limits" _tune_limits

# ── Persistent sysctl service ────────────────────────────────
cat > /etc/systemd/system/sysctl-seedbox.service << 'SVC'
[Unit]
Description=Apply Mamu Seedbox sysctl settings
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/sysctl -p /etc/sysctl.d/99-seedbox.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVC
systemctl daemon-reload
systemctl enable sysctl-seedbox.service >/dev/null 2>&1

# ── Boot script (Jerry's approach — re-applies runtime settings) ──
cat > /root/.boot-script.sh << 'BOOTSCRIPT'
#!/bin/bash
# Mamu Seedbox — Boot tuning (re-applies after reboot)
sleep 30

# Re-apply txqueuelen
for iface in $(ls /sys/class/net/ | grep -E '^(eth|ens|eno|enp|venet)'); do
    ip link set "$iface" txqueuelen 10000 2>/dev/null || true
    ethtool -K "$iface" tso off gso off gro off 2>/dev/null || true
done

# Re-apply initial congestion window
DEFAULT_GW=$(ip route | awk '/^default/{print $3}' | head -1)
DEFAULT_IF=$(ip route | awk '/^default/{print $5}' | head -1)
if [[ -n "$DEFAULT_GW" && -n "$DEFAULT_IF" ]]; then
    ip route change default via "$DEFAULT_GW" dev "$DEFAULT_IF" \
        initcwnd 32 initrwnd 32 2>/dev/null || true
fi
BOOTSCRIPT
chmod +x /root/.boot-script.sh

cat > /etc/systemd/system/boot-script.service << 'BOOTSVC'
[Unit]
Description=Mamu Seedbox boot tuning
After=network.target

[Service]
Type=simple
ExecStart=/root/.boot-script.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
BOOTSVC
systemctl enable boot-script.service >/dev/null 2>&1

success "Kernel tuning complete."
fi # end DO_TUNING

# ============================================================
#  QBITTORRENT-NOX
# ============================================================
if [[ $INSTALL_QBT -eq 1 ]]; then
section "qBittorrent-nox"

_install_qbt() {
    if [[ "$QBT_METHOD" == "static" ]]; then
        # Find the release tag matching chosen version from userdocs
        QB_TAG=$(curl -sL \
            "https://api.github.com/repos/userdocs/qbittorrent-nox-static/releases?per_page=50" \
            | grep '"tag_name"' \
            | grep "release-${QBT_VER}_" \
            | head -1 \
            | cut -d'"' -f4)
        # Fallback to latest if specific version not found
        if [[ -z "$QB_TAG" ]]; then
            QB_TAG=$(curl -sL \
                "https://api.github.com/repos/userdocs/qbittorrent-nox-static/releases/latest" \
                | grep '"tag_name"' | cut -d'"' -f4)
            warn "Version ${QBT_VER} not found, using latest: $QB_TAG"
        fi
        QB_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/${QB_TAG}/${QB_ARCH}-qbittorrent-nox"
        curl -sL "$QB_URL" -o /usr/local/bin/qbittorrent-nox
        chmod +x /usr/local/bin/qbittorrent-nox
    else
        apt-get install -y -qq qbittorrent-nox
    fi
}
run_step "Installing qBittorrent-nox" _install_qbt

QB_BIN=$(command -v qbittorrent-nox 2>/dev/null || echo "/usr/local/bin/qbittorrent-nox")
QB_VER=$($QB_BIN --version 2>/dev/null | awk '{print $2}' || echo "unknown")
info "Version: $QB_VER"

# ── systemd service ──────────────────────────────────────────
cat > /etc/systemd/system/qbittorrent-nox@.service << QBTSVC
[Unit]
Description=qBittorrent-nox for %i
After=network.target

[Service]
Type=forking
User=%i
ExecStart=${QB_BIN} -d
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
QBTSVC

# ── Pre-tuned qBittorrent config (Jerry + custom) ────────────
_write_qbt_config() {
    QBT_CONF_DIR="/home/${USERNAME}/.config/qBittorrent"
    mkdir -p "$QBT_CONF_DIR"

    cat > "${QBT_CONF_DIR}/qBittorrent.conf" << QBTCONF
[Application]
MemoryWorkingSetLimit=$(( TOTAL_RAM_MB / 3 ))

[BitTorrent]
Session\AsyncIOThreadsCount=${NCORES}
Session\CoalesceReadWrite=true
Session\ConnectionSpeed=500
Session\DefaultSavePath=${DOWNLOAD_DIR}
Session\DiskCacheSize=${CACHE_MB}
Session\DiskCacheTTL=60
Session\DiskIOReadMode=EnableOSCache
Session\DiskIOWriteMode=EnableOSCache
Session\DiskQueueSize=1024
Session\FilePoolSize=5000
Session\GlobalMaxSeedingMinutes=-1
Session\GlobalUPSpeedLimit=0
Session\GlobalDLSpeedLimit=0
Session\MaxActiveCheckingTorrents=5
Session\MaxActiveTorrents=-1
Session\MaxActiveUploads=-1
Session\MaxActiveDownloads=-1
Session\MaxConnections=3000
Session\MaxConnectionsPerTorrent=300
Session\MaxUploads=-1
Session\MaxUploadsPerTorrent=100
Session\Port=${QBT_PORT}
Session\QueueingSystemEnabled=false
Session\SendBufferLowWatermark=10240
Session\SendBufferWatermark=524288
Session\SendBufferWatermarkFactor=100
Session\SlowTorrentsDownloadRateThreshold=-1
Session\SlowTorrentsInactivityTimer=60
Session\SlowTorrentsUploadRateThreshold=-1
Session\SuggestMode=true
Session\uTPMixedMode=TCP
Session\UseOSCache=true
Session\ValidateHTTPSTrackerCertificate=false
Session\MultiConnectionsPerIp=true
Session\AnnounceToAllTiers=true
Session\AnnounceToAllTrackers=true
Session\PeerTurnover=4
Session\PeerTurnoverCutoff=90
Session\PeerTurnoverInterval=300

[LegalNotice]
Accepted=true

[Meta]
MigrationVersion=6

[Network]
Proxy\HostnameLookupEnabled=false
Proxy\Profiles\BitTorrent=false
Proxy\Profiles\Misc=false
Proxy\Profiles\RSS=false

[Preferences]
WebUI\Port=${QBT_WEBUI_PORT}
WebUI\Username=${USERNAME}
WebUI\LocalHostAuth=false
QBTCONF

    chown -R "${USERNAME}:${USERNAME}" "$QBT_CONF_DIR"
}
run_step "Writing pre-tuned qBittorrent config" _write_qbt_config

systemctl daemon-reload
systemctl enable "qbittorrent-nox@${USERNAME}" >/dev/null 2>&1
systemctl start  "qbittorrent-nox@${USERNAME}"

# ── Set WebUI password via API ────────────────────────────────
sleep 4
QB_API="http://127.0.0.1:${QBT_WEBUI_PORT}"
for i in {1..20}; do
    LOGIN=$(curl -s -c /tmp/qbt_c -b /tmp/qbt_c \
        -d "username=admin&password=adminadmin" \
        "${QB_API}/api/v2/auth/login" 2>/dev/null || true)
    if [[ "$LOGIN" == "Ok." ]]; then
        curl -s -b /tmp/qbt_c -X POST "${QB_API}/api/v2/app/setPreferences" \
            -d "json={\"web_ui_username\":\"${USERNAME}\",\"web_ui_password\":\"${PASSWORD}\"}" \
            >/dev/null 2>&1 || true
        break
    fi
    sleep 2
done
rm -f /tmp/qbt_c
success "qBittorrent running on :${QBT_WEBUI_PORT}"
fi

# ============================================================
#  RTORRENT + RUTORRENT
# ============================================================
if [[ $INSTALL_RT -eq 1 ]]; then
section "rTorrent + ruTorrent"

_install_rtorrent_deps() {
    apt-get install -y -qq \
        rtorrent nginx \
        php-fpm php-cli php-curl php-json \
        php-mbstring php-xml php-zip php-gd \
        ffmpeg mediainfo 2>/dev/null || true
}
run_step "Installing rTorrent + PHP + Nginx" _install_rtorrent_deps

RT_VERSION=$(rtorrent --version 2>&1 | head -1 | awk '{print $NF}' || echo "unknown")
info "rTorrent version: $RT_VERSION"

mkdir -p "/home/${USERNAME}/rtorrent/"{downloads,session,watch/load,watch/start}

cat > "/home/${USERNAME}/.rtorrent.rc" << RTCONF
# Mamu Seedbox — rTorrent config (optimized)
directory.default.set      = /home/${USERNAME}/rtorrent/downloads
session.path.set           = /home/${USERNAME}/rtorrent/session

# Watch directories
schedule2 = watch_load,  10, 10, load.normal=/home/${USERNAME}/rtorrent/watch/load/*.torrent
schedule2 = watch_start, 10, 10, load.start=/home/${USERNAME}/rtorrent/watch/start/*.torrent

# Network
network.port_range.set          = ${RT_PEER_PORT}-${RT_PEER_PORT}
network.port_random.set         = no
network.max_open_sockets.set    = 999
network.max_open_files.set      = 600
network.receive_buffer.size.set = 128M
network.send_buffer.size.set    = 128M
network.xmlrpc.size_limit.set   = 20M
network.http.max_open.set       = 99

# Performance
pieces.memory.max.set           = $(( TOTAL_RAM_MB / 2 ))M
throttle.max_uploads.set        = 0
throttle.max_uploads.global.set = 500
throttle.min_peers.normal.set   = 1
throttle.max_peers.normal.set   = 300
throttle.min_peers.seed.set     = 0
throttle.max_peers.seed.set     = 100
trackers.numwant.set            = 100

# SCGI socket for ruTorrent
network.scgi.open_local = /var/run/rtorrent/rtorrent.sock
schedule2 = chmod_scgi,0,0,"execute.nothrow=chmod,\"g+w,o=\",/var/run/rtorrent/rtorrent.sock"

system.umask.set = 0022
RTCONF

chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/rtorrent"

mkdir -p /var/run/rtorrent
chown "${USERNAME}:www-data" /var/run/rtorrent
chmod 770 /var/run/rtorrent

cat > /etc/systemd/system/rtorrent@.service << 'RTSVC'
[Unit]
Description=rTorrent for %i
After=network.target

[Service]
User=%i
ExecStartPre=/bin/mkdir -p /var/run/rtorrent
ExecStartPre=/bin/chown %i:www-data /var/run/rtorrent
ExecStart=/usr/bin/rtorrent
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
KillMode=process

[Install]
WantedBy=multi-user.target
RTSVC

_install_rutorrent() {
    rm -rf /var/www/rutorrent
    git clone --depth=1 https://github.com/Novik/ruTorrent.git /var/www/rutorrent 2>/dev/null
    chown -R www-data:www-data /var/www/rutorrent

    cat > /var/www/rutorrent/conf/config.php << RUCONF
<?php
\$scgi_port = 0;
\$scgi_host = "unix:///var/run/rtorrent/rtorrent.sock";
\$XMLRPCMountPoint = "/RPC2";
\$topDirectory = "/home/${USERNAME}";
\$saveUploadedTorrents = true;
\$overwriteUploadedTorrents = false;
\$pathToExternals = array(
    "php"       => "/usr/bin/php",
    "curl"      => "/usr/bin/curl",
    "gzip"      => "/bin/gzip",
    "id"        => "/usr/bin/id",
    "stat"      => "/usr/bin/stat",
    "python3"   => "/usr/bin/python3",
    "ffmpeg"    => "/usr/bin/ffmpeg",
    "mediainfo" => "/usr/bin/mediainfo",
);
RUCONF

    PHP_SOCK=$(ls /var/run/php/php*-fpm.sock 2>/dev/null | head -1 || echo "/var/run/php/php-fpm.sock")
    htpasswd -bc /etc/nginx/.htpasswd "$USERNAME" "$PASSWORD" >/dev/null 2>&1

    cat > /etc/nginx/sites-available/rutorrent << NGINXCONF
server {
    listen ${RT_PORT};
    server_name _;
    root /var/www/rutorrent;
    index index.html index.php;
    charset utf-8;
    client_max_body_size 100M;

    auth_basic "Mamu Seedbox";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        try_files \$uri \$uri/ =404;
    }
    location ~ \.php\$ {
        fastcgi_pass unix:${PHP_SOCK};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
    location /RPC2 {
        scgi_pass unix:/var/run/rtorrent/rtorrent.sock;
        include scgi_params;
    }
}
NGINXCONF

    ln -sf /etc/nginx/sites-available/rutorrent /etc/nginx/sites-enabled/rutorrent
    rm -f /etc/nginx/sites-enabled/default
    nginx -t 2>/dev/null && systemctl restart nginx
}
run_step "Installing ruTorrent + configuring Nginx" _install_rutorrent

systemctl daemon-reload
systemctl enable "rtorrent@${USERNAME}" >/dev/null 2>&1
systemctl start  "rtorrent@${USERNAME}"
success "rTorrent + ruTorrent running on :${RT_PORT}"
fi

# ============================================================
#  AUTOBRR
# ============================================================
if [[ $INSTALL_AB -eq 1 ]]; then
section "autobrr"

_install_autobrr() {
    AB_RELEASE=$(curl -sL \
        "https://api.github.com/repos/autobrr/autobrr/releases/latest" \
        | grep '"tag_name"' | cut -d'"' -f4)
    AB_VER="${AB_RELEASE#v}"
    AB_URL="https://github.com/autobrr/autobrr/releases/download/${AB_RELEASE}/autobrr_${AB_VER}_linux_${AB_ARCH}.tar.gz"
    curl -sL "$AB_URL" -o /tmp/autobrr.tar.gz
    tar -xzf /tmp/autobrr.tar.gz -C /usr/local/bin/ autobrr autobrrd 2>/dev/null || \
        tar -xzf /tmp/autobrr.tar.gz -C /usr/local/bin/
    chmod +x /usr/local/bin/autobrr /usr/local/bin/autobrrd 2>/dev/null || true
    rm -f /tmp/autobrr.tar.gz

    mkdir -p "/home/${USERNAME}/.config/autobrr"
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config/autobrr"

    cat > /etc/systemd/system/autobrr@.service << ABSVC
[Unit]
Description=autobrr for %i
After=network.target

[Service]
User=%i
ExecStart=/usr/local/bin/autobrr --config=/home/%i/.config/autobrr/
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
ABSVC
    systemctl daemon-reload
    systemctl enable "autobrr@${USERNAME}" >/dev/null 2>&1
    systemctl start  "autobrr@${USERNAME}"
}
run_step "Installing autobrr" _install_autobrr
success "autobrr running on :${AB_PORT} (finish setup in WebUI)"
fi

# ============================================================
#  JELLYFIN
# ============================================================
if [[ $INSTALL_JF -eq 1 ]]; then
section "Jellyfin"

_install_jellyfin() {
    curl -fsSL https://repo.jellyfin.org/install-debuntu.sh | bash 2>/dev/null
    systemctl enable jellyfin >/dev/null 2>&1
    systemctl start  jellyfin
}
run_step "Installing Jellyfin" _install_jellyfin
success "Jellyfin running on :${JF_PORT} (finish setup in WebUI)"
fi

# ============================================================
#  FILEBROWSER
# ============================================================
if [[ $INSTALL_FB -eq 1 ]]; then
section "FileBrowser"

_install_fb() {
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash 2>/dev/null
    mkdir -p /etc/filebrowser

    cat > /etc/filebrowser/filebrowser.json << FBCONF
{
    "port": ${FB_PORT},
    "baseURL": "",
    "address": "0.0.0.0",
    "log": "stdout",
    "database": "/etc/filebrowser/filebrowser.db",
    "root": "${DOWNLOAD_DIR}"
}
FBCONF

    filebrowser config init   --database /etc/filebrowser/filebrowser.db 2>/dev/null || true
    filebrowser users add "$USERNAME" "$PASSWORD" \
        --perm.admin \
        --database /etc/filebrowser/filebrowser.db 2>/dev/null || true

    cat > /etc/systemd/system/filebrowser.service << 'FBSVC'
[Unit]
Description=FileBrowser
After=network.target

[Service]
ExecStart=/usr/local/bin/filebrowser --config /etc/filebrowser/filebrowser.json
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
FBSVC
    systemctl daemon-reload
    systemctl enable filebrowser >/dev/null 2>&1
    systemctl start  filebrowser
}
run_step "Installing FileBrowser" _install_fb
success "FileBrowser running on :${FB_PORT}"
fi

# ============================================================
#  FINAL SUMMARY
# ============================================================
SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')

clear
echo -e "${GREEN}${BOLD}"
cat << 'DONE'

  ╔══════════════════════════════════════════╗
  ║   Mamu Seedbox — Installation Complete  ║
  ╚══════════════════════════════════════════╝

DONE
echo -e "${NC}"

echo -e "  ${BOLD}User:${NC}       $USERNAME"
echo -e "  ${BOLD}Server IP:${NC}  $SERVER_IP"
echo -e "  ${BOLD}Downloads:${NC}  $DOWNLOAD_DIR"
echo ""

if [[ $INSTALL_QBT -eq 1 ]]; then
echo -e "  ${CYAN}━━ qBittorrent ━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  → http://${SERVER_IP}:${QBT_WEBUI_PORT}"
echo -e "  → User: ${USERNAME}  |  Cache: ${CACHE_MB}MB  |  Threads: ${NCORES}"
echo ""
fi

if [[ $INSTALL_RT -eq 1 ]]; then
echo -e "  ${CYAN}━━ ruTorrent ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  → http://${SERVER_IP}:${RT_PORT}"
echo -e "  → User: ${USERNAME}"
echo ""
fi

if [[ $INSTALL_AB -eq 1 ]]; then
echo -e "  ${CYAN}━━ autobrr ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  → http://${SERVER_IP}:${AB_PORT}"
echo -e "  → Create account on first visit"
echo ""
fi

if [[ $INSTALL_JF -eq 1 ]]; then
echo -e "  ${CYAN}━━ Jellyfin ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  → http://${SERVER_IP}:${JF_PORT}"
echo -e "  → Finish setup in WebUI"
echo ""
fi

if [[ $INSTALL_FB -eq 1 ]]; then
echo -e "  ${CYAN}━━ FileBrowser ━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  → http://${SERVER_IP}:${FB_PORT}"
echo -e "  → User: ${USERNAME}"
echo ""
fi

if [[ $DO_TUNING -eq 1 ]]; then
echo -e "  ${CYAN}━━ Kernel Tuning ━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  → BBR:       $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
echo -e "  → rmem_max:  $(sysctl -n net.core.rmem_max 2>/dev/null)"
echo -e "  → FD limit:  $(ulimit -n)"
echo -e "  → Swap:      $(free -h | awk '/Swap/{print $2}')"
echo ""
fi

echo -e "  ${YELLOW}⚠  Reboot recommended to apply all tuning.${NC}"
echo -e "  ${YELLOW}⚠  Change passwords after first login!${NC}"
echo ""
echo -e "${GREEN}${BOLD}  Happy racing! 🏁${NC}"
echo ""
ENDOFSCRIPT
echo "Done writing script"