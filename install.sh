#!/usr/bin/env bash
# ============================================================
#   Mamu Tuning Seedbox Installer v4.0
#   Supports: Debian 10/11/12 · Ubuntu 20.04/22.04/24.04
#   Arch: x86_64 · ARM64
# ============================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ── Colors ───────────────────────────────────────────────────
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; MAGENTA='\033[1;35m'; CYAN='\033[1;36m'
WHITE='\033[1;37m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

LOG_FILE="/root/mamu_install.log"
mkdir -p "$(dirname "$LOG_FILE")"
: > "$LOG_FILE"

# ── Helpers ──────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
ok()      { echo -e "${GREEN}[ OK ]${NC} $1" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
err()     { echo -e "${RED}[ERR ]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

gh_asset_url() {
    local repo="$1" regex="$2"
    curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: mamu-tuning-installer" \
        "https://api.github.com/repos/${repo}/releases/latest" \
        | grep '"browser_download_url"' \
        | grep -E "$regex" \
        | cut -d'"' -f4 | head -1
}

download_file() {
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 \
        -H "User-Agent: mamu-tuning-installer" \
        -o "$2" "$1"
}

install_archive_binary() {
    local archive="$1" bin_name="$2" dest="${3:-/usr/local/bin/$2}"
    local tmpdir bin
    tmpdir="$(mktemp -d)"
    case "$archive" in
        *.zip)           unzip -q "$archive" -d "$tmpdir" >> "$LOG_FILE" 2>&1 ;;
        *.tar.gz|*.tgz)  tar -xzf "$archive" -C "$tmpdir" >> "$LOG_FILE" 2>&1 ;;
        *.tar.xz)        tar -xJf "$archive" -C "$tmpdir" >> "$LOG_FILE" 2>&1 ;;
    esac
    bin="$(find "$tmpdir" -type f -name "$bin_name" | head -1 || true)"
    [[ -z "$bin" ]] && { rm -rf "$tmpdir"; return 1; }
    install -m 755 "$bin" "$dest" >> "$LOG_FILE" 2>&1
    rm -rf "$tmpdir"
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  ARCH_TAG="amd64"; ARCH_GH_RE='(amd64|x86_64)'; ARCH_ALT="x86_64" ;;
        aarch64|arm64) ARCH_TAG="arm64"; ARCH_GH_RE='(arm64|aarch64)'; ARCH_ALT="aarch64" ;;
        *) err "Unsupported architecture: $(uname -m)" ;;
    esac
}

get_public_ip() {
    curl -4 -fsSL https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

run_step() {
    local msg="$1" func="$2"
    echo -ne "  ${DIM}⬡${NC}  $msg..."
    if $func >> "$LOG_FILE" 2>&1; then
        echo -e "\r  ${GREEN}✓${NC}  $msg"
    else
        echo -e "\r  ${YELLOW}!${NC}  $msg ${YELLOW}[warnings - check log]${NC}"
    fi
}

# ── Checks ───────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Run as root."
[[ -f /etc/os-release ]] || err "Cannot detect OS."
source /etc/os-release
[[ "$ID" =~ ^(debian|ubuntu)$ ]] || err "Debian/Ubuntu only."
detect_arch

NCORES=$(nproc)
TOTAL_RAM_MB=$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)

# ============================================================
#  SCREEN 1 — BANNER + WELCOME
# ============================================================
clear
echo -e "${CYAN}${BOLD}"
cat << 'BANNER'

  ███╗   ███╗ █████╗ ███╗   ███╗██╗   ██╗    ████████╗██╗   ██╗███╗   ██╗██╗███╗   ██╗ ██████╗
  ████╗ ████║██╔══██╗████╗ ████║██║   ██║    ╚══██╔══╝██║   ██║████╗  ██║██║████╗  ██║██╔════╝
  ██╔████╔██║███████║██╔████╔██║██║   ██║       ██║   ██║   ██║██╔██╗ ██║██║██╔██╗ ██║██║  ███╗
  ██║╚██╔╝██║██╔══██║██║╚██╔╝██║██║   ██║       ██║   ██║   ██║██║╚██╗██║██║██║╚██╗██║██║   ██║
  ██║ ╚═╝ ██║██║  ██║██║ ╚═╝ ██║╚██████╔╝       ██║   ╚██████╔╝██║ ╚████║██║██║ ╚████║╚██████╔╝
  ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝        ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝

BANNER
echo -e "${NC}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${BOLD}  Seedbox Installer v4.0  ·  Debian/Ubuntu  ·  ARM64 + x86_64${NC}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${DIM}OS: $PRETTY_NAME  |  Arch: $ARCH_TAG  |  CPU: ${NCORES} cores  |  RAM: ${TOTAL_RAM_MB}MB${NC}"
echo ""
echo -e "  ${CYAN}Welcome to Mamu Tuning Seedbox Setup!${NC}"
echo -e "  ${DIM}This will install and configure your seedbox environment.${NC}"
echo ""
read -r -s -p "  Press any key to get started..." key
clear

# ============================================================
#  SCREEN 2 — USERNAME
# ============================================================
USERNAME=$(whiptail --inputbox \
    "Enter a username for your seedbox:" 10 60 "admin" \
    --title "Mamu Tuning — Setup" 3>&1 1>&2 2>&3) || { clear; exit 0; }
[[ -z "$USERNAME" ]] && { whiptail --msgbox "Username cannot be empty!" 8 40; clear; exit 1; }

# ============================================================
#  SCREEN 3 — PASSWORD (skip if user already exists)
# ============================================================
PASSWORD=""
USER_EXISTS=0
id "$USERNAME" &>/dev/null && USER_EXISTS=1

if [[ $USER_EXISTS -eq 1 ]]; then
    whiptail --msgbox "User '$USERNAME' already exists.\nSkipping password setup — using existing account." 10 60 \
        --title "Mamu Tuning — Existing User" 3>&1 1>&2 2>&3 || { clear; exit 0; }
else
    while true; do
        PASSWORD=$(whiptail --passwordbox \
            "Enter a password (minimum 12 characters):" 10 60 \
            --title "Mamu Tuning — Setup" 3>&1 1>&2 2>&3)
        [[ $? -ne 0 ]] && { clear; exit 0; }
        if [[ ${#PASSWORD} -lt 12 ]]; then
            whiptail --msgbox "Password must be at least 12 characters!\nYou entered ${#PASSWORD}." 10 50 \
                --title "Password Too Short" 3>&1 1>&2 2>&3
            continue
        fi
        PASSWORD2=$(whiptail --passwordbox \
            "Confirm password:" 10 60 \
            --title "Mamu Tuning — Setup" 3>&1 1>&2 2>&3)
        [[ $? -ne 0 ]] && { clear; exit 0; }
        if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
            whiptail --msgbox "Passwords do not match! Try again." 8 45 \
                --title "Password Mismatch" 3>&1 1>&2 2>&3
            continue
        fi
        break
    done
fi

# ============================================================
#  SCREEN 4 — INSTALL OR UNINSTALL
# ============================================================
# Detect installed apps
QBT_INSTALLED=0; RT_INSTALLED=0; AB_INSTALLED=0
JF_INSTALLED=0; FB_INSTALLED=0; QUI_INSTALLED=0
command -v qbittorrent-nox &>/dev/null && QBT_INSTALLED=1
command -v rtorrent &>/dev/null && RT_INSTALLED=1
command -v autobrr &>/dev/null && AB_INSTALLED=1
systemctl is-active --quiet jellyfin 2>/dev/null && JF_INSTALLED=1
command -v filebrowser &>/dev/null && FB_INSTALLED=1
command -v qui &>/dev/null && QUI_INSTALLED=1
ANYTHING_INSTALLED=$(( QBT_INSTALLED + RT_INSTALLED + AB_INSTALLED + JF_INSTALLED + FB_INSTALLED + QUI_INSTALLED ))

MODE="install"
if [[ $ANYTHING_INSTALLED -gt 0 ]]; then
    MODE=$(whiptail --menu \
        "What do you want to do?" 12 55 2 \
        "install"   "Install / Add new apps" \
        "uninstall" "Uninstall / Remove apps" \
        --title "Mamu Tuning" 3>&1 1>&2 2>&3) || { clear; exit 0; }
fi

# ============================================================
#  UNINSTALL MODE
# ============================================================
if [[ "$MODE" == "uninstall" ]]; then
    UNINSTALL_OPTS=""
    [[ $QBT_INSTALLED -eq 1 ]] && UNINSTALL_OPTS+="qbittorrent  \"qBittorrent-nox\" OFF "
    [[ $RT_INSTALLED  -eq 1 ]] && UNINSTALL_OPTS+="rtorrent     \"rTorrent + ruTorrent\" OFF "
    [[ $AB_INSTALLED  -eq 1 ]] && UNINSTALL_OPTS+="autobrr      \"autobrr\" OFF "
    [[ $JF_INSTALLED  -eq 1 ]] && UNINSTALL_OPTS+="jellyfin     \"Jellyfin\" OFF "
    [[ $FB_INSTALLED  -eq 1 ]] && UNINSTALL_OPTS+="filebrowser  \"FileBrowser\" OFF "
    [[ $QUI_INSTALLED -eq 1 ]] && UNINSTALL_OPTS+="qui          \"Qui Dashboard\" OFF "

    REMOVE=$(eval whiptail --checklist \
        '"Select apps to uninstall:"' 18 55 8 \
        $UNINSTALL_OPTS \
        --title '"Mamu Tuning — Uninstall"' 3>&1 1>&2 2>&3) || { clear; exit 0; }

    [[ -z "$REMOVE" ]] && { whiptail --msgbox "Nothing selected." 8 40; clear; exit 0; }

    whiptail --yesno "Uninstall selected apps? This cannot be undone." 10 55 \
        --title "Confirm" --yes-button "Uninstall" --no-button "Cancel" \
        3>&1 1>&2 2>&3 || { clear; exit 0; }

    clear
    echo -e "\n${BOLD}${RED}  Uninstalling...${NC}\n"

    if [[ "$REMOVE" == *"qbittorrent"* ]]; then
        info "Removing qBittorrent..."
        systemctl stop "qbittorrent-nox@${USERNAME}" 2>/dev/null || true
        systemctl disable "qbittorrent-nox@${USERNAME}" 2>/dev/null || true
        rm -f /etc/systemd/system/qbittorrent-nox@.service
        rm -f /usr/local/bin/qbittorrent-nox
        ok "qBittorrent removed."
    fi
    if [[ "$REMOVE" == *"rtorrent"* ]]; then
        info "Removing rTorrent + ruTorrent..."
        systemctl stop "rtorrent@${USERNAME}" 2>/dev/null || true
        systemctl disable "rtorrent@${USERNAME}" 2>/dev/null || true
        rm -f /etc/systemd/system/rtorrent@.service
        apt-get remove -y -qq rtorrent 2>/dev/null || true
        rm -rf /var/www/rutorrent
        rm -f /etc/nginx/sites-enabled/rutorrent /etc/nginx/sites-available/rutorrent
        systemctl restart nginx 2>/dev/null || true
        ok "rTorrent + ruTorrent removed."
    fi
    if [[ "$REMOVE" == *"autobrr"* ]]; then
        info "Removing autobrr..."
        systemctl stop "autobrr@${USERNAME}" 2>/dev/null || true
        systemctl disable "autobrr@${USERNAME}" 2>/dev/null || true
        rm -f /etc/systemd/system/autobrr@.service
        rm -f /usr/local/bin/autobrr /usr/local/bin/autobrrd
        ok "autobrr removed."
    fi
    if [[ "$REMOVE" == *"jellyfin"* ]]; then
        info "Removing Jellyfin..."
        systemctl stop jellyfin 2>/dev/null || true
        systemctl disable jellyfin 2>/dev/null || true
        apt-get remove -y -qq jellyfin jellyfin-server jellyfin-web 2>/dev/null || true
        rm -f /etc/apt/sources.list.d/jellyfin.sources
        ok "Jellyfin removed."
    fi
    if [[ "$REMOVE" == *"filebrowser"* ]]; then
        info "Removing FileBrowser..."
        systemctl stop filebrowser 2>/dev/null || true
        systemctl disable filebrowser 2>/dev/null || true
        rm -f /etc/systemd/system/filebrowser.service
        rm -f /usr/local/bin/filebrowser
        ok "FileBrowser removed."
    fi
    if [[ "$REMOVE" == *"qui"* ]]; then
        info "Removing Qui..."
        systemctl stop qui 2>/dev/null || true
        systemctl disable qui 2>/dev/null || true
        rm -f /etc/systemd/system/qui.service
        rm -f /usr/local/bin/qui
        ok "Qui removed."
    fi

    systemctl daemon-reload
    echo ""
    ok "Uninstall complete!"
    exit 0
fi

# ============================================================
#  SCREEN 5 — APP SELECTION
# ============================================================
[[ $QBT_INSTALLED -eq 1 ]] && QBT_LABEL="qBittorrent-nox [INSTALLED]" || QBT_LABEL="qBittorrent-nox"
[[ $RT_INSTALLED  -eq 1 ]] && RT_LABEL="rTorrent + ruTorrent [INSTALLED]" || RT_LABEL="rTorrent + ruTorrent"
[[ $AB_INSTALLED  -eq 1 ]] && AB_LABEL="autobrr [INSTALLED]" || AB_LABEL="autobrr"
[[ $JF_INSTALLED  -eq 1 ]] && JF_LABEL="Jellyfin [INSTALLED]" || JF_LABEL="Jellyfin"
[[ $FB_INSTALLED  -eq 1 ]] && FB_LABEL="FileBrowser [INSTALLED]" || FB_LABEL="FileBrowser"
[[ $QUI_INSTALLED -eq 1 ]] && QUI_LABEL="Qui Dashboard [INSTALLED]" || QUI_LABEL="Qui Dashboard"

SELECTED=$(whiptail --checklist \
    "Select apps to install:\n(Space to select, Enter to confirm)" 22 65 10 \
    "qbt"       "$QBT_LABEL"          ON \
    "rtorrent"  "$RT_LABEL"           OFF \
    "autobrr"   "$AB_LABEL"           ON \
    "jellyfin"  "$JF_LABEL"           OFF \
    "filebrowser" "$FB_LABEL"         ON \
    "qui"       "$QUI_LABEL"          ON \
    "media"     "Media Tools"         ON \
    "tuning"    "Kernel Tuning"       ON \
    "bbr3"      "BBRv3"               ON \
    "swap"      "4GB Swapfile"        ON \
    --title "Mamu Tuning — Apps" 3>&1 1>&2 2>&3) || { clear; exit 0; }

INSTALL_QBT=0; INSTALL_RT=0; INSTALL_AB=0; INSTALL_JF=0
INSTALL_FB=0; INSTALL_QUI=0; INSTALL_MEDIA=0
DO_TUNING=0; ENABLE_BBR3=0; DO_SWAP=0

[[ "$SELECTED" == *"qbt"*        ]] && INSTALL_QBT=1
[[ "$SELECTED" == *"rtorrent"*   ]] && INSTALL_RT=1
[[ "$SELECTED" == *"autobrr"*    ]] && INSTALL_AB=1
[[ "$SELECTED" == *"jellyfin"*   ]] && INSTALL_JF=1
[[ "$SELECTED" == *"filebrowser"* ]] && INSTALL_FB=1
[[ "$SELECTED" == *"qui"*        ]] && INSTALL_QUI=1
[[ "$SELECTED" == *"media"*      ]] && INSTALL_MEDIA=1
[[ "$SELECTED" == *"tuning"*     ]] && DO_TUNING=1
[[ "$SELECTED" == *"bbr3"*       ]] && ENABLE_BBR3=1
[[ "$SELECTED" == *"swap"*       ]] && DO_SWAP=1

# ============================================================
#  SCREEN 6 — QBIT VERSION (if selected)
# ============================================================
QBT_VER="4.6.7"
if [[ $INSTALL_QBT -eq 1 && $QBT_INSTALLED -eq 0 ]]; then
    QBT_VER=$(whiptail --menu \
        "Select qBittorrent version:" 18 55 8 \
        "4.6.7" "4.6.7 (recommended)" \
        "4.6.6" "4.6.6" \
        "4.6.5" "4.6.5" \
        "4.6.4" "4.6.4" \
        "4.6.3" "4.6.3" \
        "4.6.2" "4.6.2" \
        "4.5.5" "4.5.5" \
        "4.5.4" "4.5.4" \
        --title "Mamu Tuning — qBittorrent" 3>&1 1>&2 2>&3) || QBT_VER="4.6.7"

    while true; do
        QBT_CACHE=$(whiptail --inputbox \
            "qBittorrent cache size in MB:" 10 55 "2048" \
            --title "Mamu Tuning — qBittorrent" 3>&1 1>&2 2>&3) || break
        [[ "$QBT_CACHE" =~ ^[0-9]+$ ]] && break
        whiptail --msgbox "Must be a number!" 8 40
    done
    QBT_CACHE="${QBT_CACHE:-2048}"
fi

LIB_VER="v2.0.11"

# ============================================================
#  SCREEN 7 — PORTS
# ============================================================
QBT_WEBUI_PORT="8080"
QBT_PORT="45000"
RT_PORT="8090"
RT_PEER_PORT="49164"
AB_PORT="7474"
JF_PORT="8096"
FB_PORT="808"
QUI_PORT="7476"

if [[ $INSTALL_QBT -eq 1 ]]; then
    QBT_WEBUI_PORT=$(whiptail --inputbox "qBittorrent WebUI port:" 10 55 "8080" \
        --title "Mamu Tuning — Ports" 3>&1 1>&2 2>&3) || QBT_WEBUI_PORT="8080"
    QBT_PORT=$(whiptail --inputbox "qBittorrent peer port:" 10 55 "45000" \
        --title "Mamu Tuning — Ports" 3>&1 1>&2 2>&3) || QBT_PORT="45000"
fi
if [[ $INSTALL_RT -eq 1 ]]; then
    RT_PORT=$(whiptail --inputbox "ruTorrent web port:" 10 55 "8090" \
        --title "Mamu Tuning — Ports" 3>&1 1>&2 2>&3) || RT_PORT="8090"
    RT_PEER_PORT=$(whiptail --inputbox "rTorrent peer port:" 10 55 "49164" \
        --title "Mamu Tuning — Ports" 3>&1 1>&2 2>&3) || RT_PEER_PORT="49164"
fi
if [[ $INSTALL_AB -eq 1 ]]; then
    AB_PORT=$(whiptail --inputbox "autobrr port:" 10 55 "7474" \
        --title "Mamu Tuning — Ports" 3>&1 1>&2 2>&3) || AB_PORT="7474"
fi

# ============================================================
#  SCREEN 8 — DOWNLOAD DIR + SUMMARY CONFIRMATION
# ============================================================
DOWNLOAD_DIR=$(whiptail --inputbox \
    "Download directory:" 10 60 "/home/${USERNAME}/downloads" \
    --title "Mamu Tuning — Setup" 3>&1 1>&2 2>&3) || DOWNLOAD_DIR="/home/${USERNAME}/downloads"

whiptail --yesno \
    "Ready to install!\n\nUser: $USERNAME\nDownloads: $DOWNLOAD_DIR\nqBit: v${QBT_VER} on :${QBT_WEBUI_PORT}\n\nProceed?" \
    14 60 --title "Mamu Tuning — Confirm" \
    3>&1 1>&2 2>&3 || { clear; exit 0; }

clear

# ============================================================
#  INSTALLATION BEGINS
# ============================================================
echo ""
echo -e "  ${CYAN}${BOLD}Mamu Tuning — Installing...${NC}"
echo -e "  ${DIM}Log: $LOG_FILE${NC}"
echo ""

# ── System prep ──────────────────────────────────────────────
_sys_prep() {
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get upgrade -y >> "$LOG_FILE" 2>&1
    apt-get install -y curl wget gnupg2 sudo lsb-release ca-certificates \
        unzip tar jq git ethtool net-tools ufw screen >> "$LOG_FILE" 2>&1
}
run_step "Updating system packages" _sys_prep

# Create user
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash "$USERNAME" >> "$LOG_FILE" 2>&1
    echo "${USERNAME}:${PASSWORD}" | chpasswd >> "$LOG_FILE" 2>&1
    ok "User $USERNAME created."
else
    warn "User $USERNAME already exists."
fi
mkdir -p "$DOWNLOAD_DIR"
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}" 2>/dev/null || true

# ── Firewall ─────────────────────────────────────────────────
_setup_ufw() {
    if ! ufw status | grep -q "Status: active" 2>/dev/null; then
        ufw --force reset >> "$LOG_FILE" 2>&1
        ufw default deny incoming >> "$LOG_FILE" 2>&1
        ufw default allow outgoing >> "$LOG_FILE" 2>&1
        ufw allow ssh >> "$LOG_FILE" 2>&1
    fi
    [[ $INSTALL_QBT -eq 1 ]] && ufw allow "${QBT_WEBUI_PORT}/tcp" >> "$LOG_FILE" 2>&1 || true
    [[ $INSTALL_QBT -eq 1 ]] && ufw allow "${QBT_PORT}/tcp" >> "$LOG_FILE" 2>&1 || true
    [[ $INSTALL_QBT -eq 1 ]] && ufw allow "${QBT_PORT}/udp" >> "$LOG_FILE" 2>&1 || true
    [[ $INSTALL_RT  -eq 1 ]] && ufw allow "${RT_PORT}/tcp" >> "$LOG_FILE" 2>&1 || true
    [[ $INSTALL_RT  -eq 1 ]] && ufw allow "${RT_PEER_PORT}/tcp" >> "$LOG_FILE" 2>&1 || true
    [[ $INSTALL_AB  -eq 1 ]] && ufw allow "${AB_PORT}/tcp" >> "$LOG_FILE" 2>&1 || true
    [[ $INSTALL_JF  -eq 1 ]] && ufw allow "${JF_PORT}/tcp" >> "$LOG_FILE" 2>&1 || true
    [[ $INSTALL_FB  -eq 1 ]] && ufw allow "${FB_PORT}/tcp" >> "$LOG_FILE" 2>&1 || true
    [[ $INSTALL_QUI -eq 1 ]] && ufw allow "${QUI_PORT}/tcp" >> "$LOG_FILE" 2>&1 || true
    ufw --force enable >> "$LOG_FILE" 2>&1
}
run_step "Configuring firewall (UFW)" _setup_ufw

# ── Swap ─────────────────────────────────────────────────────
if [[ $DO_SWAP -eq 1 ]]; then
    _create_swap() {
        if ! swapon --show | grep -q '/swapfile' 2>/dev/null; then
            fallocate -l 4G /swapfile
            chmod 600 /swapfile
            mkswap /swapfile -q
            swapon /swapfile
            grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
        fi
    }
    run_step "Creating 4GB swapfile" _create_swap
fi

# ── Kernel tuning ─────────────────────────────────────────────
if [[ $DO_TUNING -eq 1 ]]; then
    echo ""
    echo -e "  ${MAGENTA}Kernel Tuning${NC}"

    _disable_tuned() {
        systemctl stop tuned 2>/dev/null || true
        systemctl disable tuned 2>/dev/null || true
        sed -i '/@include/d' /etc/sysctl.conf 2>/dev/null || true
        modprobe nf_conntrack 2>/dev/null || true
        echo "nf_conntrack" > /etc/modules-load.d/conntrack.conf
        # Patch Netcup override
        if [[ -f /etc/sysctl.d/99-nc-kernel.conf ]]; then
            cp /etc/sysctl.d/99-nc-kernel.conf /etc/sysctl.d/99-nc-kernel.conf.bak
            cat > /etc/sysctl.d/99-nc-kernel.conf << 'EOF'
vm.dirty_background_ratio = 10
vm.dirty_ratio = 40
kernel.watchdog_thresh = 20
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 524288 134217728
net.ipv4.tcp_wmem = 4096 524288 134217728
EOF
        fi
    }
    run_step "Disabling conflicting services" _disable_tuned

    _apply_sysctl() {
        cat > /etc/sysctl.d/99-mamu-tuning.conf << 'EOF'
# ── Kernel scheduler ──────────────────────────────────────────
kernel.pid_max = 4194303
kernel.sched_migration_cost_ns = 5000000
kernel.sched_autogroup_enabled = 0
kernel.sched_min_granularity_ns = 10000000
kernel.sched_wakeup_granularity_ns = 15000000

# ── File system ───────────────────────────────────────────────
fs.file-max = 2097152
fs.nr_open = 2097152

# ── Memory ────────────────────────────────────────────────────
vm.swappiness = 10
vm.dirty_background_ratio = 5
vm.dirty_ratio = 30
vm.dirty_expire_centisecs = 1000
vm.dirty_writeback_centisecs = 100
vm.vfs_cache_pressure = 50

# ── Network core ──────────────────────────────────────────────
net.core.rmem_default = 524288
net.core.rmem_max = 134217728
net.core.wmem_default = 524288
net.core.wmem_max = 134217728
net.core.optmem_max = 4194304
net.core.netdev_max_backlog = 100000
net.core.netdev_budget = 50000
net.core.netdev_budget_usecs = 8000
net.core.somaxconn = 524288
net.core.rps_sock_flow_entries = 32768

# ── BBR + FQ ──────────────────────────────────────────────────
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# ── TCP buffers ───────────────────────────────────────────────
net.ipv4.tcp_rmem = 4096 524288 134217728
net.ipv4.tcp_wmem = 4096 524288 134217728
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_limit_output_bytes = 1048576
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_syn_backlog = 524288
net.ipv4.tcp_max_tw_buckets = 10240
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# ── TCP retransmission tuning ─────────────────────────────────
# Reduces aggressive retransmission on high-latency connections
net.ipv4.tcp_retries1 = 3
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_orphan_retries = 2
net.ipv4.tcp_syn_retries = 4
net.ipv4.tcp_synack_retries = 5
net.ipv4.tcp_frto = 2
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_reordering = 6
net.ipv4.tcp_max_reordering = 300
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_comp_sack_delay_ns = 250000

# ── Conntrack ─────────────────────────────────────────────────
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_tcp_timeout_established = 600
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 10
EOF
        sysctl -p /etc/sysctl.d/99-mamu-tuning.conf >> "$LOG_FILE" 2>&1 || true
    }
    run_step "Applying kernel sysctl settings" _apply_sysctl

    # ── Multiqueue + RPS/RFS ──────────────────────────────────
    _setup_multiqueue() {
        CPU_COUNT=$(nproc)
        CPU_MASK=$(printf '%x' $(( (1 << CPU_COUNT) - 1 )))

        for IFACE in $(ls /sys/class/net/ | grep -E '^(eth|ens|eno|enp|venet)' 2>/dev/null); do
            # RPS — steer incoming packets across all CPU cores
            for RX in /sys/class/net/${IFACE}/queues/rx-*/rps_cpus; do
                [[ -w "$RX" ]] && echo "$CPU_MASK" > "$RX" 2>/dev/null || true
            done
            # RFS — keep flows on same CPU for cache efficiency
            for RX in /sys/class/net/${IFACE}/queues/rx-*/rps_flow_cnt; do
                [[ -w "$RX" ]] && echo 32768 > "$RX" 2>/dev/null || true
            done
            # XPS — steer outgoing packets to matching TX queue
            TX_COUNT=$(ls /sys/class/net/${IFACE}/queues/ | grep -c '^tx-' 2>/dev/null || echo 1)
            TX_IDX=0
            for TX in /sys/class/net/${IFACE}/queues/tx-*/xps_cpus; do
                [[ -w "$TX" ]] && echo "$(printf '%x' $((1 << TX_IDX % CPU_COUNT)))" > "$TX" 2>/dev/null || true
                TX_IDX=$((TX_IDX + 1))
            done
        done

        # Persist across reboots
        cat > /etc/systemd/system/mamu-multiqueue.service << MQSVC
[Unit]
Description=Mamu Tuning - Multiqueue RPS/RFS/XPS
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/mamu-multiqueue.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
MQSVC

        cat > /etc/mamu-multiqueue.sh << MQSH
#!/bin/bash
CPU_COUNT=\$(nproc)
CPU_MASK=\$(printf '%x' \$(( (1 << CPU_COUNT) - 1 )))
for IFACE in \$(ls /sys/class/net/ | grep -E '^(eth|ens|eno|enp|venet)' 2>/dev/null); do
    for RX in /sys/class/net/\${IFACE}/queues/rx-*/rps_cpus; do
        [[ -w "\$RX" ]] && echo "\$CPU_MASK" > "\$RX" 2>/dev/null || true
    done
    for RX in /sys/class/net/\${IFACE}/queues/rx-*/rps_flow_cnt; do
        [[ -w "\$RX" ]] && echo 32768 > "\$RX" 2>/dev/null || true
    done
    TX_IDX=0
    for TX in /sys/class/net/\${IFACE}/queues/tx-*/xps_cpus; do
        [[ -w "\$TX" ]] && echo "\$(printf '%x' \$((1 << TX_IDX % CPU_COUNT)))" > "\$TX" 2>/dev/null || true
        TX_IDX=\$((TX_IDX + 1))
    done
done
MQSH
        chmod +x /etc/mamu-multiqueue.sh
        systemctl daemon-reload >> "$LOG_FILE" 2>&1
        systemctl enable mamu-multiqueue.service >> "$LOG_FILE" 2>&1
    }
    run_step "Setting up multiqueue RPS/RFS/XPS" _setup_multiqueue

    _setup_limits() {
        grep -q '1048576' /etc/security/limits.conf 2>/dev/null || \
        cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 1048576
* hard nofile 1048576
* soft nproc  65535
* hard nproc  65535
root soft nofile 1048576
root hard nofile 1048576
EOF
        if grep -q '^DefaultLimitNOFILE=' /etc/systemd/system.conf 2>/dev/null; then
            sed -i 's/^DefaultLimitNOFILE=.*/DefaultLimitNOFILE=1048576/' /etc/systemd/system.conf
        else
            sed -i 's/^#DefaultLimitNOFILE=.*/DefaultLimitNOFILE=1048576/' /etc/systemd/system.conf
        fi
        systemctl daemon-reexec >> "$LOG_FILE" 2>&1 || true
    }
    run_step "Setting file descriptor limits" _setup_limits

    _setup_io() {
        DISK=$(lsblk -d -o NAME,TYPE | awk '$2=="disk"{print $1}' | head -1)
        if [[ -n "$DISK" ]]; then
            echo mq-deadline > /sys/block/${DISK}/queue/scheduler 2>/dev/null || true
            echo 256 > /sys/block/${DISK}/queue/nr_requests 2>/dev/null || true
            cat > /etc/udev/rules.d/60-io-scheduler.rules << 'EOF'
ACTION=="add|change", KERNEL=="vd[a-z]|sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="vd[a-z]|sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/nr_requests}="256"
EOF
        fi
    }
    run_step "Setting I/O scheduler (mq-deadline)" _setup_io

    # Persistent sysctl service
    cat > /etc/systemd/system/mamu-sysctl.service << 'EOF'
[Unit]
Description=Mamu Tuning sysctl settings
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/sysctl -p /etc/sysctl.d/99-mamu-tuning.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    systemctl enable mamu-sysctl.service >> "$LOG_FILE" 2>&1

    ok "Kernel tuning complete."
fi

# ── Main seedbox install ──────────────────────────────────────
if [[ $INSTALL_QBT -eq 1 || $INSTALL_AB -eq 1 ]]; then
    echo ""
    echo -e "  ${MAGENTA}Seedbox Installation${NC}"
    warn "This may take several minutes..."

    FLAG_B=""; FLAG_R=""; FLAG_NET=""
    [[ $INSTALL_AB   -eq 1 ]] && FLAG_B="-b"
    [[ $ENABLE_BBR3  -eq 1 ]] && FLAG_NET="-3"

    CMD_FLAGS="-u $USERNAME -p $PASSWORD -c ${QBT_CACHE:-2048} -q $QBT_VER -l $LIB_VER $FLAG_B $FLAG_NET"

    info "Running seedbox installer..."
    if ! bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) $CMD_FLAGS; then
        warn "Seedbox installer had warnings. Check $LOG_FILE"
    else
        ok "qBittorrent + autobrr installed."
    fi
fi

# ── rTorrent + ruTorrent ──────────────────────────────────────
if [[ $INSTALL_RT -eq 1 ]]; then
    echo ""
    echo -e "  ${MAGENTA}rTorrent + ruTorrent${NC}"

    _install_rt_deps() {
        apt-get install -y rtorrent nginx php-fpm php-cli php-curl php-json \
            php-mbstring php-xml php-zip php-gd apache2-utils screen >> "$LOG_FILE" 2>&1
    }
    run_step "Installing rTorrent + dependencies" _install_rt_deps

    _setup_rtorrent() {
        mkdir -p "/home/${USERNAME}/rtorrent/"{downloads,session,watch/load,watch/start}

        cat > "/home/${USERNAME}/.rtorrent.rc" << RTCONF
directory.default.set      = /home/${USERNAME}/rtorrent/downloads
session.path.set           = /home/${USERNAME}/rtorrent/session
schedule2 = watch_load,  10, 10, load.normal=/home/${USERNAME}/rtorrent/watch/load/*.torrent
schedule2 = watch_start, 10, 10, load.start=/home/${USERNAME}/rtorrent/watch/start/*.torrent
network.port_range.set          = ${RT_PEER_PORT}-${RT_PEER_PORT}
network.port_random.set         = no
network.max_open_sockets.set    = 999
network.max_open_files.set      = 600
network.receive_buffer.size.set = 128M
network.send_buffer.size.set    = 128M
network.xmlrpc.size_limit.set   = 20M
network.http.max_open.set       = 99
throttle.max_uploads.set        = 0
throttle.max_uploads.global.set = 500
throttle.min_peers.normal.set   = 1
throttle.max_peers.normal.set   = 300
throttle.min_peers.seed.set     = 0
throttle.max_peers.seed.set     = 100
trackers.numwant.set            = 100
network.scgi.open_local = /var/run/rtorrent/rtorrent.sock
schedule2 = chmod_scgi,0,0,"execute.nothrow=chmod,\"g+w,o=\",/var/run/rtorrent/rtorrent.sock"
system.umask.set = 0022
RTCONF

        chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/rtorrent"
        chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.rtorrent.rc"
        mkdir -p /var/run/rtorrent
        chown "${USERNAME}:www-data" /var/run/rtorrent
        chmod 775 /var/run/rtorrent

        cat > /etc/systemd/system/rtorrent@.service << 'EOF'
[Unit]
Description=rTorrent for %i
After=network.target

[Service]
User=%i
ExecStartPre=/bin/mkdir -p /var/run/rtorrent
ExecStartPre=/bin/chown %i:www-data /var/run/rtorrent
ExecStart=/usr/bin/screen -d -m -S rtorrent /usr/bin/rtorrent
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
    }
    run_step "Configuring rTorrent" _setup_rtorrent

    _install_rutorrent() {
        rm -rf /var/www/rutorrent
        git clone --depth=1 https://github.com/Novik/ruTorrent.git /var/www/rutorrent >> "$LOG_FILE" 2>&1
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
    "ffmpeg"    => "/usr/bin/ffmpeg",
    "mediainfo" => "/usr/bin/mediainfo",
);
RUCONF

        PHP_SOCK=$(ls /var/run/php/php*-fpm.sock 2>/dev/null | head -1 || echo "/var/run/php/php-fpm.sock")
        htpasswd -bc /etc/nginx/.htpasswd "$USERNAME" "$PASSWORD" >> "$LOG_FILE" 2>&1

        cat > /etc/nginx/sites-available/rutorrent << NGINXCONF
server {
    listen ${RT_PORT};
    server_name _;
    root /var/www/rutorrent;
    index index.html index.php;
    charset utf-8;
    client_max_body_size 100M;
    auth_basic "Mamu Tuning Seedbox";
    auth_basic_user_file /etc/nginx/.htpasswd;
    location / { try_files \$uri \$uri/ =404; }
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
        nginx -t >> "$LOG_FILE" 2>&1 && systemctl restart nginx >> "$LOG_FILE" 2>&1
        systemctl daemon-reload >> "$LOG_FILE" 2>&1
        systemctl enable "rtorrent@${USERNAME}" >> "$LOG_FILE" 2>&1
        systemctl start "rtorrent@${USERNAME}" >> "$LOG_FILE" 2>&1 || true
    }
    run_step "Installing ruTorrent" _install_rutorrent
fi

# ── Jellyfin ─────────────────────────────────────────────────
if [[ $INSTALL_JF -eq 1 ]]; then
    echo ""
    echo -e "  ${MAGENTA}Jellyfin${NC}"

    _install_jellyfin() {
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key \
            | gpg --dearmor --yes -o /etc/apt/keyrings/jellyfin.gpg 2>/dev/null
        OS_ID=$(awk -F= '/^ID=/{gsub(/"/,"",$2); print $2}' /etc/os-release)
        OS_CODENAME=$(awk -F= '/^VERSION_CODENAME=/{gsub(/"/,"",$2); print $2}' /etc/os-release)
        cat > /etc/apt/sources.list.d/jellyfin.sources << JFREPO
Types: deb
URIs: https://repo.jellyfin.org/${OS_ID}
Suites: ${OS_CODENAME}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/jellyfin.gpg
JFREPO
        apt-get update -qq >> "$LOG_FILE" 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jellyfin >> "$LOG_FILE" 2>&1
        systemctl enable jellyfin >> "$LOG_FILE" 2>&1
        systemctl start jellyfin >> "$LOG_FILE" 2>&1
    }
    run_step "Installing Jellyfin (may take a few minutes)" _install_jellyfin
fi

# ── FileBrowser ───────────────────────────────────────────────
if [[ $INSTALL_FB -eq 1 ]]; then
    echo ""
    echo -e "  ${MAGENTA}FileBrowser${NC}"

    _install_filebrowser() {
        curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash >> "$LOG_FILE" 2>&1
        cat > /etc/systemd/system/filebrowser.service << EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/filebrowser --database /root/filebrowser.db --root / --address 0.0.0.0 --port ${FB_PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload >> "$LOG_FILE" 2>&1
        if [[ ! -f /root/filebrowser.db ]]; then
            timeout 5s /usr/local/bin/filebrowser --database /root/filebrowser.db --root / --port ${FB_PORT} >/dev/null 2>&1 || true
        fi
        /usr/local/bin/filebrowser users add "$USERNAME" "$PASSWORD" --perm.admin \
            --database /root/filebrowser.db >> "$LOG_FILE" 2>&1 || \
        /usr/local/bin/filebrowser users update "$USERNAME" --password "$PASSWORD" --perm.admin \
            --database /root/filebrowser.db >> "$LOG_FILE" 2>&1 || true
        systemctl enable --now filebrowser >> "$LOG_FILE" 2>&1 || true
    }
    run_step "Installing FileBrowser" _install_filebrowser
fi

# ── Qui ───────────────────────────────────────────────────────
if [[ $INSTALL_QUI -eq 1 ]]; then
    echo ""
    echo -e "  ${MAGENTA}Qui Dashboard${NC}"

    _install_qui() {
        QUI_URL="$(gh_asset_url "autobrr/qui" "linux.*(${ARCH_GH_RE}).*(deb|tar\.gz|tgz|zip)$" || true)"
        [[ -z "${QUI_URL:-}" ]] && QUI_URL="$(gh_asset_url "autobrr/qui" "${ARCH_GH_RE}.*(deb|tar\.gz|tgz|zip)$" || true)"
        [[ -z "${QUI_URL:-}" ]] && { warn "Qui not found for $ARCH_TAG"; return 0; }

        TMPDIR="$(mktemp -d)"
        QUI_FILE="$TMPDIR/$(basename "${QUI_URL%%\?*}")"
        download_file "$QUI_URL" "$QUI_FILE" >> "$LOG_FILE" 2>&1

        case "$QUI_FILE" in
            *.deb) apt-get install -y "$QUI_FILE" >> "$LOG_FILE" 2>&1 ;;
            *)     install_archive_binary "$QUI_FILE" "qui" "/usr/local/bin/qui" ;;
        esac
        rm -rf "$TMPDIR"

        mkdir -p /root/.config/qui
        cat > /root/.config/qui/config.toml << EOF
host = "0.0.0.0"
port = ${QUI_PORT}
EOF
        chmod 700 /root/.config/qui
        chmod 600 /root/.config/qui/config.toml

        cat > /etc/systemd/system/qui.service << 'EOF'
[Unit]
Description=Qui - qBittorrent Dashboard
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/qui serve
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload >> "$LOG_FILE" 2>&1
        systemctl enable --now qui >> "$LOG_FILE" 2>&1 || true
    }
    run_step "Installing Qui Dashboard" _install_qui
fi

# ── Media Tools ───────────────────────────────────────────────
if [[ $INSTALL_MEDIA -eq 1 ]]; then
    echo ""
    echo -e "  ${MAGENTA}Media Tools${NC}"

    _install_base_media() {
        apt-get install -y ffmpeg mediainfo aria2 mkvtoolnix mktorrent >> "$LOG_FILE" 2>&1
    }
    run_step "Installing ffmpeg, mediainfo, aria2, mkvtoolnix, mktorrent" _install_base_media

    _install_mkbrr() {
        MKBRR_URL="$(gh_asset_url "autobrr/mkbrr" "linux.*(${ARCH_GH_RE}).*\.deb$" || true)"
        [[ -z "${MKBRR_URL:-}" ]] && { warn "mkbrr not found"; return 0; }
        TMPDIR="$(mktemp -d)"
        download_file "$MKBRR_URL" "$TMPDIR/mkbrr.deb" >> "$LOG_FILE" 2>&1
        apt-get install -y "$TMPDIR/mkbrr.deb" >> "$LOG_FILE" 2>&1
        rm -rf "$TMPDIR"
    }
    run_step "Installing mkbrr" _install_mkbrr

    _install_fastfetch() {
        FF_URL="$(gh_asset_url "fastfetch-cli/fastfetch" "linux.*(${ARCH_GH_RE}).*(deb|tar\.gz)$" || true)"
        [[ -z "${FF_URL:-}" ]] && { warn "fastfetch not found"; return 0; }
        TMPDIR="$(mktemp -d)"
        FF_FILE="$TMPDIR/$(basename "${FF_URL%%\?*}")"
        download_file "$FF_URL" "$FF_FILE" >> "$LOG_FILE" 2>&1
        case "$FF_FILE" in
            *.deb) apt-get install -y "$FF_FILE" >> "$LOG_FILE" 2>&1 ;;
            *)     install_archive_binary "$FF_FILE" "fastfetch" "/usr/local/bin/fastfetch" ;;
        esac
        rm -rf "$TMPDIR"
    }
    run_step "Installing fastfetch" _install_fastfetch

    _install_bento4() {
        B4_VER="$(curl -fsSL https://www.bento4.com/downloads/ 2>/dev/null | sed -n 's/.*Version \([0-9][0-9.:-]*\).*/\1/p' | head -1 || true)"
        [[ -z "${B4_VER:-}" ]] && { warn "Bento4 version not found"; return 0; }
        B4_FILE="${B4_VER//./-}"
        B4_URL="https://www.bok.net/Bento4/binaries/Bento4-SDK-${B4_FILE}.${ARCH_ALT}-unknown-linux.zip"
        TMPDIR="$(mktemp -d)"
        download_file "$B4_URL" "$TMPDIR/bento4.zip" >> "$LOG_FILE" 2>&1 || { rm -rf "$TMPDIR"; return 0; }
        unzip -o "$TMPDIR/bento4.zip" -d /tmp >> "$LOG_FILE" 2>&1
        cp /tmp/Bento4-SDK-*/bin/* /usr/local/bin/ >> "$LOG_FILE" 2>&1 || true
        rm -rf /tmp/Bento4-SDK-* "$TMPDIR"
    }
    run_step "Installing Bento4" _install_bento4

    # Torrent creator script
    DL_PATH="/home/$USERNAME/qbittorrent/Downloads"
    mkdir -p "$DL_PATH"
    id "$USERNAME" &>/dev/null && chown "$USERNAME:$USERNAME" "$DL_PATH" >> "$LOG_FILE" 2>&1 || true
    if wget -q -O "$DL_PATH/main.py" \
        https://raw.githubusercontent.com/xNabil/torrent-creator/refs/heads/main/main.py >> "$LOG_FILE" 2>&1; then
        chmod +x "$DL_PATH/main.py"
        id "$USERNAME" &>/dev/null && chown "$USERNAME:$USERNAME" "$DL_PATH/main.py" >> "$LOG_FILE" 2>&1 || true
        ok "Torrent creator saved to $DL_PATH/main.py"
    fi
fi

# ============================================================
#  FINAL SUMMARY
# ============================================================
SERVER_IP=$(get_public_ip)

clear
echo -e "${CYAN}${BOLD}"
cat << 'BANNER'

  ███╗   ███╗ █████╗ ███╗   ███╗██╗   ██╗    ████████╗██╗   ██╗███╗   ██╗██╗███╗   ██╗ ██████╗
  ████╗ ████║██╔══██╗████╗ ████║██║   ██║    ╚══██╔══╝██║   ██║████╗  ██║██║████╗  ██║██╔════╝
  ██╔████╔██║███████║██╔████╔██║██║   ██║       ██║   ██║   ██║██╔██╗ ██║██║██╔██╗ ██║██║  ███╗
  ██║╚██╔╝██║██╔══██║██║╚██╔╝██║██║   ██║       ██║   ██║   ██║██║╚██╗██║██║██║╚██╗██║██║   ██║
  ██║ ╚═╝ ██║██║  ██║██║ ╚═╝ ██║╚██████╔╝       ██║   ╚██████╔╝██║ ╚████║██║██║ ╚████║╚██████╔╝
  ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝        ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝

BANNER
echo -e "${NC}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}${BOLD}  Installation Complete!${NC}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
printf "  ${BOLD}%-20s${NC} : %s\n" "User"       "$USERNAME"
printf "  ${BOLD}%-20s${NC} : %s\n" "Password"   "$PASSWORD"
printf "  ${BOLD}%-20s${NC} : %s\n" "Server IP"  "$SERVER_IP"
printf "  ${BOLD}%-20s${NC} : %s\n" "Downloads"  "$DOWNLOAD_DIR"
echo ""

[[ $INSTALL_QBT -eq 1 ]] && printf "  ${CYAN}%-20s${NC} : http://%s:%s\n" "qBittorrent" "$SERVER_IP" "$QBT_WEBUI_PORT"
[[ $INSTALL_RT  -eq 1 ]] && printf "  ${CYAN}%-20s${NC} : http://%s:%s\n" "ruTorrent"   "$SERVER_IP" "$RT_PORT"
[[ $INSTALL_AB  -eq 1 ]] && printf "  ${CYAN}%-20s${NC} : http://%s:%s\n" "autobrr"     "$SERVER_IP" "$AB_PORT"
[[ $INSTALL_QUI -eq 1 ]] && printf "  ${CYAN}%-20s${NC} : http://%s:%s\n" "Qui"         "$SERVER_IP" "$QUI_PORT"
[[ $INSTALL_JF  -eq 1 ]] && printf "  ${CYAN}%-20s${NC} : http://%s:%s\n" "Jellyfin"    "$SERVER_IP" "$JF_PORT"
[[ $INSTALL_FB  -eq 1 ]] && printf "  ${CYAN}%-20s${NC} : http://%s:%s\n" "FileBrowser" "$SERVER_IP" "$FB_PORT"

if [[ $DO_TUNING -eq 1 ]]; then
    echo ""
    echo -e "  ${MAGENTA}${BOLD}Kernel Tuning${NC}"
    printf "  %-20s : %s\n" "Congestion" "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
    printf "  %-20s : %s\n" "rmem_max"   "$(sysctl -n net.core.rmem_max 2>/dev/null)"
    printf "  %-20s : %s\n" "FD limit"   "$(ulimit -n)"
    printf "  %-20s : %s\n" "Multiqueue" "RPS/RFS/XPS enabled on all cores"
    [[ $DO_SWAP -eq 1 ]] && printf "  %-20s : %s\n" "Swap" "$(free -h | awk '/Swap/{print $2}')"
fi

if [[ $INSTALL_MEDIA -eq 1 ]]; then
    echo ""
    echo -e "  ${MAGENTA}${BOLD}Media Tools${NC}"
    echo -e "  ffmpeg · mediainfo · aria2 · mkvtoolnix · mktorrent · mkbrr · fastfetch · Bento4"
    echo -e "  Torrent Creator: /home/$USERNAME/qbittorrent/Downloads/main.py"
fi

echo ""
echo -e "  ${YELLOW}⚠  Reboot recommended to apply all tuning.${NC}"
[[ $ENABLE_BBR3 -eq 1 ]] && echo -e "  ${YELLOW}⚠  BBRv3 selected — reboot required.${NC}"
echo -e "  ${YELLOW}⚠  Change passwords after first login!${NC}"
echo ""
echo -e "  ${GREEN}${BOLD}  Happy Racing! 🏁${NC}"
echo ""
