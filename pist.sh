#!/bin/bash

# pist.sh - VPS Control Panel Auto Installer v1.1
# Supports Quick Mode (non-interactive) and Normal Mode (interactive)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_MODE=""
DETECTED_PANELS=()
IS_FRESH=true
PANEL_FILTER=""   # "free", "paid", or "all"

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║      pist.sh — VPS Control Panel Auto Installer v1.2      ║"
    echo "║     One Script, Multiple Panels — Quick & Normal Mode     ║"
    echo "║     Repository: https://github.com/mnasikin/pist.sh       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] Script must be run as root!${NC}"
        echo "Run with: sudo bash $0"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$PRETTY_NAME
    else
        echo -e "${RED}[ERROR] Unable to detect OS${NC}"
        exit 1
    fi
}

is_pterodactyl_supported_os() {
    case "${OS}:${OS_VERSION}" in
        ubuntu:20.04|ubuntu:22.04|ubuntu:24.04|debian:11|debian:12)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

get_specs() {
    echo -e "${BLUE}[INFO] Fetching server specifications...${NC}\n"
    CPU_CORES=$(nproc)
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d ':' -f2 | xargs)
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    RAM_GB=$(echo "scale=2; $TOTAL_RAM/1024" | bc)
    TOTAL_DISK=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    AVAILABLE_DISK=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    ARCH=$(uname -m)
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
}

# ─────────────────────────────────────────────────────────────
# Detect existing control panel installations
# ─────────────────────────────────────────────────────────────
detect_existing_panels() {
    DETECTED_PANELS=()
    IS_FRESH=true

    if [[ -f /usr/local/cpanel/cpanel ]] || systemctl is-active --quiet cpanel 2>/dev/null; then
        DETECTED_PANELS+=("cPanel/WHM"); IS_FRESH=false
    fi
    if [[ -f /usr/local/psa/version ]] || command -v plesk &>/dev/null; then
        DETECTED_PANELS+=("Plesk"); IS_FRESH=false
    fi
    if [[ -f /www/server/panel/BT-Panel ]] || [[ -d /www/server/panel ]]; then
        DETECTED_PANELS+=("aaPanel"); IS_FRESH=false
    fi
    if [[ -f /usr/local/CyberCP/CyberCP/settings.py ]] || command -v cyberpanel &>/dev/null; then
        DETECTED_PANELS+=("CyberPanel"); IS_FRESH=false
    fi
    if [[ -f /etc/clp/version ]] || [[ -d /home/clp ]]; then
        DETECTED_PANELS+=("CloudPanel"); IS_FRESH=false
    fi
    if systemctl is-active --quiet webmin 2>/dev/null || [[ -f /etc/webmin/version ]]; then
        DETECTED_PANELS+=("Webmin"); IS_FRESH=false
    fi
    if [[ -d /usr/local/vesta ]] || command -v v-list-users &>/dev/null; then
        DETECTED_PANELS+=("VestaCP"); IS_FRESH=false
    fi
    if [[ -d /usr/local/hestia ]] || command -v v-add-user &>/dev/null && [[ -f /usr/local/hestia/conf/hestia.conf ]]; then
        DETECTED_PANELS+=("HestiaCP"); IS_FRESH=false
    fi
    if [[ -d /usr/local/cwpsrv ]] || [[ -f /usr/local/cwp/.conf ]]; then
        DETECTED_PANELS+=("CentOS Web Panel (CWP)"); IS_FRESH=false
    fi
    if [[ -d /usr/local/ispconfig ]] || [[ -f /usr/local/ispconfig/interface/lib/config.inc.php ]]; then
        DETECTED_PANELS+=("ISPConfig"); IS_FRESH=false
    fi
    if systemctl is-active --quiet ajenti 2>/dev/null || command -v ajenti-panel &>/dev/null; then
        DETECTED_PANELS+=("Ajenti"); IS_FRESH=false
    fi
    if [[ -d /opt/1panel ]] || [[ -f /usr/bin/1pctl ]]; then
        DETECTED_PANELS+=("1Panel"); IS_FRESH=false
    fi
    if [[ -f /usr/local/webuzo/main/conf/webuzo.conf ]] || [[ -d /usr/local/webuzo ]]; then
        DETECTED_PANELS+=("Webuzo"); IS_FRESH=false
    fi
    if [[ -d /usr/local/directadmin ]] || [[ -f /usr/local/directadmin/directadmin ]]; then
        DETECTED_PANELS+=("DirectAdmin"); IS_FRESH=false
    fi
    if [[ -d /usr/local/interworx ]] || systemctl is-active --quiet iworx 2>/dev/null; then
        DETECTED_PANELS+=("InterWorx"); IS_FRESH=false
    fi
    if [[ -d /usr/local/mgr5 ]] || [[ -f /usr/local/mgr5/bin/core ]]; then
        DETECTED_PANELS+=("ISPmanager"); IS_FRESH=false
    fi
    if [[ -d /usr/local/fastpanel2 ]] || command -v fastpanel &>/dev/null; then
        DETECTED_PANELS+=("FASTPANEL"); IS_FRESH=false
    fi
    if [[ -d /root/.enhance ]] || command -v enhance &>/dev/null; then
        DETECTED_PANELS+=("Enhance"); IS_FRESH=false
    fi
    if [[ -d /usr/local/apiscp ]] || command -v upcp &>/dev/null; then
        DETECTED_PANELS+=("ApisCP"); IS_FRESH=false
    fi
    if [[ -d /etc/virtualmin-benchmark ]] || [[ -f /usr/sbin/virtualmin ]]; then
        DETECTED_PANELS+=("Virtualmin"); IS_FRESH=false
    fi
    if [[ -d /usr/local/openpanel ]] || command -v openpanel &>/dev/null; then
        DETECTED_PANELS+=("OpenPanel"); IS_FRESH=false
    fi
    if [[ -d /data/coolify ]] || docker ps -a | grep -q coolify 2>/dev/null; then
        DETECTED_PANELS+=("Coolify"); IS_FRESH=false
    fi
    if [[ -d /etc/easypanel ]] || docker ps -a | grep -q easypanel 2>/dev/null; then
        DETECTED_PANELS+=("Easypanel"); IS_FRESH=false
    fi
    if [[ -f /etc/yunohost/version ]] || command -v yunohost &>/dev/null; then
        DETECTED_PANELS+=("YunoHost"); IS_FRESH=false
    fi

    STACK_FOUND=()
    command -v nginx    &>/dev/null && STACK_FOUND+=("Nginx")
    command -v apache2  &>/dev/null && STACK_FOUND+=("Apache2")
    command -v httpd    &>/dev/null && STACK_FOUND+=("Apache/httpd")
    command -v mysql    &>/dev/null && STACK_FOUND+=("MySQL")
    command -v mariadb  &>/dev/null && STACK_FOUND+=("MariaDB")
    command -v php      &>/dev/null && STACK_FOUND+=("PHP")
    command -v docker   &>/dev/null && STACK_FOUND+=("Docker")
    [[ ${#STACK_FOUND[@]} -gt 0 ]] && IS_FRESH=false
}

display_install_status() {
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║               INSTALLATION STATUS CHECK                    ║"
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}"

    if [[ "$IS_FRESH" == true ]]; then
        echo -e "  Status  : ${GREEN}✔  Fresh Install — No existing panel or web stack detected${NC}"
        echo -e "  Risk    : ${GREEN}Low — Safe to install any compatible panel${NC}"
    else
        if [[ ${#DETECTED_PANELS[@]} -gt 0 ]]; then
            echo -e "  Status  : ${RED}✘  Control Panel Already Installed${NC}"
            echo -e "  Risk    : ${RED}High — Installing another panel may cause conflicts${NC}"
            echo ""
            echo -e "  ${RED}Detected Panel(s):${NC}"
            for p in "${DETECTED_PANELS[@]}"; do
                echo -e "    ${RED}▸ $p${NC}"
            done
        else
            echo -e "  Status  : ${YELLOW}⚠  Not Fresh — Existing web stack detected${NC}"
            echo -e "  Risk    : ${YELLOW}Medium — A web stack is already installed (no panel detected)${NC}"
        fi
        if [[ ${#STACK_FOUND[@]} -gt 0 ]]; then
            echo ""
            echo -e "  ${YELLOW}Detected Web Stack:${NC}"
            for s in "${STACK_FOUND[@]}"; do
                echo -e "    ${YELLOW}▸ $s${NC}"
            done
        fi
    fi
    echo ""
}

display_specs() {
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║                  SERVER SPECIFICATIONS                     ║"
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}OS:${NC}            $OS_NAME"
    echo -e "${CYAN}Arch:${NC}          $ARCH"
    echo -e "${CYAN}CPU:${NC}           $CPU_MODEL"
    echo -e "${CYAN}CPU Cores:${NC}     $CPU_CORES cores"
    echo -e "${CYAN}RAM:${NC}           ${RAM_GB} GB (${TOTAL_RAM} MB)"
    echo -e "${CYAN}Disk Total:${NC}    ${TOTAL_DISK} GB"
    echo -e "${CYAN}Disk Free:${NC}     ${AVAILABLE_DISK} GB"
    echo -e "${CYAN}IP Address:${NC}    $IP_ADDRESS"
    echo ""
}

warn_if_not_fresh() {
    if [[ "$IS_FRESH" == true ]]; then return 0; fi

    if [[ ${#DETECTED_PANELS[@]} -gt 0 ]]; then
        echo -e "${RED}╔════════════════════════════════════════════════════════════╗"
        echo -e "║                    !! WARNING !!                           ║"
        echo -e "╚════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${RED}  An existing control panel was detected on this server.${NC}"
        echo -e "${RED}  Installing another panel on top of an existing one can:${NC}"
        echo -e "${RED}    ▸ Cause port conflicts and service failures${NC}"
        echo -e "${RED}    ▸ Corrupt existing websites and databases${NC}"
        echo -e "${RED}    ▸ Break the currently installed panel${NC}"
        echo ""
        echo -e "${YELLOW}  Recommendation: Reinstall the OS (fresh) before continuing.${NC}"
        echo ""
        read -p "  Are you sure you want to continue anyway? (yes/no): " force_continue
        if [[ "$force_continue" != "yes" ]]; then
            echo -e "${YELLOW}Installation aborted. Please start with a fresh OS.${NC}"
            exit 0
        fi
        echo -e "${YELLOW}[WARN] Proceeding at your own risk...${NC}\n"
    else
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗"
        echo -e "║                    !! NOTICE !!                            ║"
        echo -e "╚════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${YELLOW}  Existing web stack detected (Nginx/Apache/MySQL/PHP/etc).${NC}"
        echo -e "${YELLOW}  Most control panels recommend a fresh OS installation.${NC}"
        echo -e "${YELLOW}  Continuing may cause service conflicts.${NC}"
        echo ""
        read -p "  Continue installation? (y/n): " stack_continue
        if [[ "$stack_continue" != "y" ]]; then
            echo -e "${YELLOW}Installation aborted.${NC}"
            exit 0
        fi
        echo -e "${YELLOW}[WARN] Proceeding with existing stack present...${NC}\n"
    fi
}

# ─────────────────────────────────────────────────────────────
# Prompt: Free or Paid filter
# ─────────────────────────────────────────────────────────────
choose_panel_filter() {
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║              SELECT PANEL PRICING PREFERENCE               ║"
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}[1]${NC} ${GREEN}Free Panels${NC}    — aaPanel, CyberPanel, CloudPanel, Webmin, VestaCP,"
    echo -e "                    HestiaCP, CWP, ISPConfig, Ajenti, 1Panel, OpenPanel,"
    echo -e "                    Pterodactyl,"
    echo -e "                    Coolify, Easypanel, YunoHost"
    echo ""
    echo -e "  ${YELLOW}[2]${NC} ${RED}Paid Panels${NC}    — cPanel, Plesk, Webuzo, DirectAdmin, InterWorx,"
    echo -e "                    ISPmanager, FASTPANEL, Enhance, ApisCP, Virtualmin Pro"
    echo -e "                    ${MAGENTA}(License / subscription may be required)${NC}"
    echo ""
    echo -e "  ${YELLOW}[3]${NC} ${CYAN}Show All${NC}       — Display all compatible panels"
    echo ""
    read -p "  Your choice (1/2/3) [default: 3]: " filter_choice

    case "$filter_choice" in
        1) PANEL_FILTER="free" ;;
        2) PANEL_FILTER="paid" ;;
        *) PANEL_FILTER="all"  ;;
    esac

    echo ""
}

check_compatibility() {
    declare -gA PANELS
    declare -gA PANEL_TYPE   # key -> "free" or "paid"

    # --- PAID ---
    if [[ "$OS" =~ ^(centos|almalinux|rocky)$ ]] && [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 20 ]]; then
        PANELS["cpanel"]="cPanel/WHM|min: 1 Core, 1GB RAM, 20GB Disk|CentOS/AlmaLinux/Rocky"
        PANEL_TYPE["cpanel"]="paid"
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 4 ]]; then
        if [[ "$OS" =~ ^(centos|ubuntu|debian|almalinux|rocky)$ ]]; then
            PANELS["plesk"]="Plesk|min: 1 Core, 1GB RAM, 4GB Disk|Multi-OS"
            PANEL_TYPE["plesk"]="paid"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 5 ]]; then
        if [[ "$OS" =~ ^(centos|ubuntu|almalinux|rocky)$ ]]; then
            PANELS["webuzo"]="Webuzo|min: 1 Core, 1GB RAM, 5GB Disk|Ubuntu/CentOS/AlmaLinux/Rocky"
            PANEL_TYPE["webuzo"]="paid"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 2 ]]; then
        if [[ "$OS" =~ ^(centos|ubuntu|almalinux|rocky|debian)$ ]]; then
            PANELS["directadmin"]="DirectAdmin|min: 1 Core, 1GB RAM, 2GB Disk|Multi-OS"
            PANEL_TYPE["directadmin"]="paid"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" =~ ^(centos|almalinux|rocky)$ ]]; then
            PANELS["interworx"]="InterWorx|min: 1 Core, 1GB RAM, 10GB Disk|RHEL/CentOS/Alma/Rocky"
            PANEL_TYPE["interworx"]="paid"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" =~ ^(ubuntu|debian|almalinux|rocky)$ ]]; then
            PANELS["ispmanager"]="ISPmanager|min: 1 Core, 1GB RAM, 10GB Disk|Ubuntu/Debian/Alma/Rocky"
            PANEL_TYPE["ispmanager"]="paid"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" =~ ^(ubuntu|debian|centos|almalinux|rocky|debian)$ ]]; then
            PANELS["fastpanel"]="FASTPANEL|min: 1 Core, 1GB RAM, 10GB Disk|Multi-OS"
            PANEL_TYPE["fastpanel"]="paid"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 2048 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" == "ubuntu" ]]; then
            PANELS["enhance"]="Enhance|min: 1 Core, 2GB RAM, 10GB Disk|Ubuntu Only (Docker)"
            PANEL_TYPE["enhance"]="paid"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 2048 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" =~ ^(centos|almalinux|rocky)$ ]]; then
            PANELS["apiscp"]="ApisCP|min: 1 Core, 2GB RAM, 10GB Disk|RHEL/CentOS/Alma/Rocky"
            PANEL_TYPE["apiscp"]="paid"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" =~ ^(ubuntu|debian|centos|almalinux|rocky)$ ]]; then
            PANELS["virtualmin"]="Virtualmin Pro|min: 1 Core, 1GB RAM, 10GB Disk|Multi-OS"
            PANEL_TYPE["virtualmin"]="paid"
        fi
    fi

    # --- FREE ---
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" =~ ^(centos|ubuntu|debian|almalinux|rocky)$ ]]; then
            PANELS["aapanel"]="aaPanel|min: 1 Core, 512MB RAM, 10GB Disk|Ubuntu/Debian/CentOS/AlmaLinux/Rocky"
            PANEL_TYPE["aapanel"]="free"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" =~ ^(centos|ubuntu|almalinux)$ ]]; then
            PANELS["cyberpanel"]="CyberPanel|min: 1 Core, 1GB RAM, 10GB Disk|Ubuntu/CentOS/AlmaLinux"
            PANEL_TYPE["cyberpanel"]="free"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 2048 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            PANELS["cloudpanel"]="CloudPanel|min: 1 Core, 2GB RAM, 10GB Disk|Ubuntu 22.04/24.04, Debian 11/12"
            PANEL_TYPE["cloudpanel"]="free"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 256 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        PANELS["webmin"]="Webmin|min: 1 Core, 256MB RAM, 10GB Disk|Multi-OS"
        PANEL_TYPE["webmin"]="free"
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]] && [[ "$AVAILABLE_DISK" -ge 3 ]]; then
        if [[ "$OS" =~ ^(centos|ubuntu|debian)$ ]]; then
            PANELS["vestacp"]="VestaCP|min: 1 Core, 512MB RAM, 3GB Disk|Ubuntu/Debian/CentOS"
            PANEL_TYPE["vestacp"]="free"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]] && [[ "$AVAILABLE_DISK" -ge 3 ]]; then
        if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
            PANELS["hestiacp"]="HestiaCP|min: 1 Core, 512MB RAM, 3GB Disk|Ubuntu/Debian"
            PANEL_TYPE["hestiacp"]="free"
        fi
    fi
    if [[ "$OS" =~ ^(centos|almalinux|rocky)$ ]] && [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]] && [[ "$AVAILABLE_DISK" -ge 5 ]]; then
        PANELS["cwp"]="CWP|min: 1 Core, 512MB RAM, 5GB Disk|CentOS/AlmaLinux/Rocky"
        PANEL_TYPE["cwp"]="free"
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 5 ]]; then
        if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
            PANELS["ispconfig"]="ISPConfig|min: 1 Core, 1GB RAM, 5GB Disk|Ubuntu/Debian"
            PANEL_TYPE["ispconfig"]="free"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        PANELS["ajenti"]="Ajenti|min: 1 Core, 512MB RAM, 10GB Disk|Multi-OS"
        PANEL_TYPE["ajenti"]="free"
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" =~ ^(ubuntu|debian|centos|rocky|almalinux)$ ]]; then
            PANELS["1panel"]="1Panel|min: 1 Core, 1GB RAM, 10GB Disk|Ubuntu/Debian/CentOS/Rocky/AlmaLinux"
            PANEL_TYPE["1panel"]="free"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
            PANELS["openpanel"]="OpenPanel|min: 1 Core, 1GB RAM, 10GB Disk|Ubuntu/Debian"
            PANEL_TYPE["openpanel"]="free"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 2048 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if is_pterodactyl_supported_os; then
            PANELS["pterodactyl"]="Pterodactyl|min: 1 Core, 2GB RAM, 10GB Disk|Ubuntu 20.04/22.04/24.04, Debian 11/12"
            PANEL_TYPE["pterodactyl"]="free"
        fi
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 2048 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        PANELS["coolify"]="Coolify|min: 1 Core, 2GB RAM, 10GB Disk|Multi-OS (Docker)"
        PANEL_TYPE["coolify"]="free"
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 2048 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        PANELS["easypanel"]="Easypanel|min: 1 Core, 2GB RAM, 10GB Disk|Multi-OS (Docker)"
        PANEL_TYPE["easypanel"]="free"
    fi
    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]] && [[ "$AVAILABLE_DISK" -ge 10 ]]; then
        if [[ "$OS" == "debian" ]]; then
            PANELS["yunohost"]="YunoHost|min: 1 Core, 512MB RAM, 10GB Disk|Debian Only"
            PANEL_TYPE["yunohost"]="free"
        fi
    fi
}

# ─────────────────────────────────────────────────────────────
# Display panels — single column for free/paid filter, two-column for all
# ─────────────────────────────────────────────────────────────
display_panels() {
    if [ ${#PANELS[@]} -eq 0 ]; then
        echo -e "${RED}[ERROR] No control panel compatible with this server!${NC}"
        echo "Minimum specifications not met or OS not supported."
        exit 1
    fi

    declare -gA PANEL_NUMBERS
    declare -ga FREE_ENTRIES=()
    declare -ga PAID_ENTRIES=()
    local idx=1

    local ordered_keys=(cpanel plesk webuzo directadmin interworx ispmanager fastpanel enhance apiscp virtualmin aapanel cyberpanel cloudpanel webmin vestacp hestiacp cwp ispconfig ajenti 1panel openpanel pterodactyl coolify easypanel yunohost)

    for key in "${ordered_keys[@]}"; do
        [[ -z "${PANELS[$key]+x}" ]] && continue

        if [[ "$PANEL_FILTER" == "free" && "${PANEL_TYPE[$key]}" == "paid" ]]; then continue; fi
        if [[ "$PANEL_FILTER" == "paid" && "${PANEL_TYPE[$key]}" == "free" ]]; then continue; fi

        IFS='|' read -r name specs os_support <<< "${PANELS[$key]}"
        PANEL_NUMBERS[$idx]="$key"

        local already=""
        for dp in "${DETECTED_PANELS[@]}"; do
            local first_word
            first_word=$(echo "$name" | awk '{print $1}')
            if [[ "$name" == *"$dp"* ]] || [[ "$dp" == *"$first_word"* ]]; then
                already=" ★"
                break
            fi
        done

        local label="${idx}. ${name}${already}"

        if [[ "${PANEL_TYPE[$key]}" == "free" ]]; then
            FREE_ENTRIES+=("$label|$key")
        else
            PAID_ENTRIES+=("$label|$key")
        fi
        ((idx++))
    done

    if [[ ${#PANEL_NUMBERS[@]} -eq 0 ]]; then
        echo -e "${RED}[ERROR] No panels available for the selected filter.${NC}"
        exit 1
    fi

    # ── Table dimensions ─────────────────────────────────────
    local CW=28
    local SCW=$(( CW * 2 + 3 ))

    # Two-column separators
    local SEP_TOP SEP_MID SEP_BOT
    SEP_TOP="╔$(printf '═%.0s' $(seq 1 $CW))╦$(printf '═%.0s' $(seq 1 $CW))╗"
    SEP_MID="╠$(printf '═%.0s' $(seq 1 $CW))╬$(printf '═%.0s' $(seq 1 $CW))╣"
    SEP_BOT="╚$(printf '═%.0s' $(seq 1 $CW))╩$(printf '═%.0s' $(seq 1 $CW))╝"

    pad_cell_wide() {
        local text="$1"
        local stripped
        stripped=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
        local visible_len=${#stripped}
        local pad=$(( SCW - visible_len - 2 ))
        [[ $pad -lt 0 ]] && pad=0
        printf "║ %b%*s║\n" "$text" "$pad" ""
    }

    pad_cell() {
        local text="$1"
        local stripped
        stripped=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
        local visible_len=${#stripped}
        local pad=$(( CW - visible_len - 2 ))
        [[ $pad -lt 0 ]] && pad=0
        printf "║ %b%*s " "$text" "$pad" ""
    }

    print_row() {
        pad_cell "$1"
        pad_cell "$2"
        echo "║"
    }

    # Single-column separators
    local SEP_TOP_S SEP_MID_S SEP_BOT_S
    SEP_TOP_S="╔$(printf '═%.0s' $(seq 1 $SCW))╗"
    SEP_MID_S="╠$(printf '═%.0s' $(seq 1 $SCW))╣"
    SEP_BOT_S="╚$(printf '═%.0s' $(seq 1 $SCW))╝"

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║                 AVAILABLE CONTROL PANELS                   ║"
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}"

    if [[ "$PANEL_FILTER" == "free" ]]; then
        echo -e "${GREEN}  Showing: Free Panels only${NC}\n"

        echo -e "${GREEN}${SEP_TOP_S}${NC}"
        pad_cell_wide "${GREEN}  ✦ FREE PANELS${NC}"
        echo -e "${GREEN}${SEP_MID_S}${NC}"

        for (( r=0; r<${#FREE_ENTRIES[@]}; r++ )); do
            local fl
            IFS='|' read -r fl _ <<< "${FREE_ENTRIES[$r]}"
            pad_cell_wide "${CYAN}  ${fl}${NC}"
            if [[ $(( r+1 )) -lt ${#FREE_ENTRIES[@]} ]]; then
                echo -e "${GREEN}${SEP_MID_S}${NC}"
            fi
        done

        echo -e "${GREEN}${SEP_BOT_S}${NC}"

    elif [[ "$PANEL_FILTER" == "paid" ]]; then
        echo -e "${RED}  Showing: Paid Panels only${NC}\n"

        echo -e "${YELLOW}${SEP_TOP_S}${NC}"
        pad_cell_wide "${RED}  ✦ PAID PANELS${NC}"
        echo -e "${YELLOW}${SEP_MID_S}${NC}"

        for (( r=0; r<${#PAID_ENTRIES[@]}; r++ )); do
            local pl
            IFS='|' read -r pl _ <<< "${PAID_ENTRIES[$r]}"
            pad_cell_wide "${YELLOW}  ${pl}${NC}"
            if [[ $(( r+1 )) -lt ${#PAID_ENTRIES[@]} ]]; then
                echo -e "${YELLOW}${SEP_MID_S}${NC}"
            fi
        done

        echo -e "${YELLOW}${SEP_BOT_S}${NC}"

    else
        echo -e "${CYAN}  Showing: All Panels${NC}\n"

        echo -e "${CYAN}${SEP_TOP}${NC}"
        print_row "${GREEN}  ✦ FREE PANELS${NC}" "${RED}  ✦ PAID PANELS${NC}"
        echo -e "${CYAN}${SEP_MID}${NC}"

        local max_rows
        max_rows=$(( ${#FREE_ENTRIES[@]} > ${#PAID_ENTRIES[@]} ? ${#FREE_ENTRIES[@]} : ${#PAID_ENTRIES[@]} ))

        for (( r=0; r<max_rows; r++ )); do
            local fl="" pl=""

            if [[ $r -lt ${#FREE_ENTRIES[@]} ]]; then
                IFS='|' read -r fl _ <<< "${FREE_ENTRIES[$r]}"
                fl="${CYAN}  ${fl}${NC}"
            fi
            if [[ $r -lt ${#PAID_ENTRIES[@]} ]]; then
                IFS='|' read -r pl _ <<< "${PAID_ENTRIES[$r]}"
                pl="${YELLOW}  ${pl}${NC}"
            fi

            print_row "$fl" "$pl"

            if [[ $(( r+1 )) -lt $max_rows ]]; then
                echo -e "${CYAN}${SEP_MID}${NC}"
            fi
        done

        echo -e "${CYAN}${SEP_BOT}${NC}"
    fi

    echo ""
    [[ ${#DETECTED_PANELS[@]} -gt 0 ]] && echo -e "  ${RED}★ = Already installed on this server${NC}"
    echo -e "  ${YELLOW}[99]${NC} ${CYAN}Run System Benchmark (YABS)${NC}"
    echo -e "  ${YELLOW}[0]${NC}  ${RED}Exit${NC}"
    echo ""
}


# ─────────────────────────────────────────────────────────────
# Choose installation mode: Quick or Normal
# ─────────────────────────────────────────────────────────────
choose_install_mode() {
    local panel_display_name="$1"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║               SELECT INSTALLATION MODE                     ║"
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}"
    echo -e "  Panel : ${CYAN}${panel_display_name}${NC}"
    echo ""
    echo -e "  ${YELLOW}[1]${NC} ${GREEN}Quick Mode${NC}   — Non-interactive, uses all defaults, no prompts"
    echo -e "  ${YELLOW}[2]${NC} ${CYAN}Normal Mode${NC}  — Interactive, configure each option manually"
    echo ""
    read -p "  Select mode (1/2) [default: 2]: " mode_choice

    case "$mode_choice" in
        1) INSTALL_MODE="quick"  ;;
        *) INSTALL_MODE="normal" ;;
    esac

    echo -e "\n${BLUE}[INFO] Selected mode: ${INSTALL_MODE^^}${NC}\n"
}

# ─────────────────────────────────────────────────────────────
# Install functions
# ─────────────────────────────────────────────────────────────

install_cpanel() {
    echo -e "${BLUE}[INFO] Installing cPanel/WHM...${NC}"
    echo -e "${YELLOW}[WARNING] cPanel is commercial software — a license is required!${NC}"
    echo -e "${YELLOW}         Pricing starts at \$15.99/month — https://cpanel.net/pricing${NC}\n"

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Proceeding — assuming license is already owned.${NC}"
    else
        read -p "Do you already have a license? (y/n): " has_license
        if [[ "$has_license" != "y" ]]; then
            echo -e "${RED}Installation cancelled. Purchase a license at https://cpanel.net${NC}"
            return 1
        fi
    fi
    cd /home
    curl -o latest -L https://securedownloads.cpanel.net/latest
    sh latest
}

install_plesk() {
    echo -e "${BLUE}[INFO] Installing Plesk Panel...${NC}"
    echo -e "${YELLOW}[WARNING] Plesk is commercial software (15-day trial available)${NC}\n"

    wget https://autoinstall.plesk.com/one-click-installer -O one-click-installer
    chmod +x one-click-installer

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Running Plesk one-click installer — fully automated.${NC}"
        ./one-click-installer
    else
        echo -e "${CYAN}[NORMAL] Running Plesk installer with all version options...${NC}"
        ./one-click-installer --all-versions
    fi
}

install_webuzo() {
    echo -e "${BLUE}[INFO] Installing Webuzo Panel...${NC}"
    echo -e "${YELLOW}[WARNING] Webuzo is commercial software — license required.${NC}"
    echo -e "${YELLOW}          Pricing: https://www.webuzo.com/pricing${NC}\n"

    # Check SELinux
    if [[ -f /usr/sbin/selinuxenabled ]] && selinuxenabled; then
        echo -e "${RED}[ERROR] SELinux is enabled. Please disable it before installing Webuzo.${NC}"
        echo -e "        Run: setenforce 0 && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config"
        return 1
    fi

    wget -N http://files.webuzo.com/install.sh
    chmod 755 install.sh

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Running Webuzo installer automatically...${NC}"
        ./install.sh
    else
        echo -e "${CYAN}[NORMAL] Running Webuzo interactive installer...${NC}"
        ./install.sh
    fi
}

install_directadmin() {
    echo -e "${BLUE}[INFO] Installing DirectAdmin...${NC}"
    echo -e "${YELLOW}[WARNING] DirectAdmin requires a license key or a 60-day trial.${NC}\n"
    bash <(curl -Ss https://www.directadmin.com/setup.sh) auto
}

install_interworx() {
    echo -e "${BLUE}[INFO] Installing InterWorx...${NC}"
    sh <(curl -sL https://updates.interworx.com/interworx/bin/interworx-install.sh)
}

install_ispmanager() {
    echo -e "${BLUE}[INFO] Installing ISPmanager...${NC}"
    wget https://download.ispmanager.com/install.sh -O install_ispmanager.sh
    sh install_ispmanager.sh
}

install_fastpanel() {
    echo -e "${BLUE}[INFO] Installing FASTPANEL...${NC}"
    wget http://repo.fastpanel.direct/install_fastpanel.sh -O - | bash -
}

install_enhance() {
    echo -e "${BLUE}[INFO] Installing Enhance Control Panel...${NC}"
    if [[ "$OS" != "ubuntu" ]]; then
        echo -e "${RED}[ERROR] Enhance only supports Ubuntu 22.04/24.04.${NC}"; return 1
    fi
    curl https://cli.enhance.com/install.sh | sh
}

install_apiscp() {
    echo -e "${BLUE}[INFO] Installing ApisCP...${NC}"
    curl -sL https://get.apiscp.com | bash
}

install_virtualmin() {
    echo -e "${BLUE}[INFO] Installing Virtualmin Pro...${NC}"
    wget https://software.virtualmin.com/gpl/scripts/install.sh -O install_virtualmin.sh
    sh install_virtualmin.sh
}

install_aapanel() {
    echo -e "${BLUE}[INFO] Installing aaPanel...${NC}"
    wget -O install_aapanel.sh "https://www.aapanel.com/script/install_7.0_en.sh"

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Running aaPanel installer — 'aapanel' flag skips interactive prompts.${NC}"
        bash install_aapanel.sh aapanel
    else
        echo -e "${CYAN}[NORMAL] Running aaPanel installer — interactive mode.${NC}"
        bash install_aapanel.sh
    fi
}

install_cyberpanel() {
    echo -e "${BLUE}[INFO] Installing CyberPanel...${NC}"

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Running CyberPanel non-interactive installer...${NC}"
        echo -e "${CYAN}        Defaults: Full install, OpenLiteSpeed, Memcached & Watchdog.${NC}"
        sh <(curl -sL https://cyberpanel.net/install.sh || wget -qO - https://cyberpanel.net/install.sh) \
            --no-interactive 1 1 y n y n y y
    else
        echo -e "${CYAN}[NORMAL] Running CyberPanel interactive installer...${NC}"
        sh <(curl -sL https://cyberpanel.net/install.sh || wget -qO - https://cyberpanel.net/install.sh)
    fi
}

install_cloudpanel() {
    echo -e "${BLUE}[INFO] Installing CloudPanel...${NC}"

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        echo -e "${RED}[ERROR] CloudPanel only supports Ubuntu 22.04/24.04 and Debian 11/12.${NC}"
        return 1
    fi
    curl -sS https://installer.cloudpanel.io/ce/v2/install.sh -o install_cloudpanel.sh

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Verifying checksum and installing CloudPanel automatically...${NC}"
    else
        echo -e "${CYAN}[NORMAL] Verifying checksum and installing CloudPanel...${NC}"
    fi
    echo "3b639730371ac2a56f8f955dbdf8459d5aaeb425578eb10c6e4d6b76a75de544 install_cloudpanel.sh" | sha256sum -c && \
    bash install_cloudpanel.sh
}

install_webmin() {
    echo -e "${BLUE}[INFO] Installing Webmin...${NC}"
    curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
    sh setup-repos.sh --force

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Installing Webmin — DEBIAN_FRONTEND=noninteractive.${NC}"
        if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y webmin
        else
            yum install -y webmin
        fi
    else
        echo -e "${CYAN}[NORMAL] Installing Webmin...${NC}"
        if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
            apt-get install -y webmin
        else
            yum install -y webmin
        fi
    fi
}

install_vestacp() {
    echo -e "${BLUE}[INFO] Installing VestaCP...${NC}"
    echo -e "${YELLOW}[WARNING] VestaCP is no longer actively maintained. Consider HestiaCP instead.${NC}\n"

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Proceeding with VestaCP installation without confirmation.${NC}"
    else
        read -p "Continue with VestaCP installation? (y/n): " continue_install
        if [[ "$continue_install" != "y" ]]; then
            echo -e "${YELLOW}Installation cancelled.${NC}"; return 1
        fi
    fi
    curl -O http://vestacp.com/pub/vst-install.sh

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        local vesta_pass
        vesta_pass="$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 14)"
        echo -e "${YELLOW}╔══════════════════════════════════════════╗"
        echo -e "  Generated Admin Password: ${vesta_pass}"
        echo -e "  Save this password before continuing!"
        echo -e "╚══════════════════════════════════════════╝${NC}"
        sleep 5
        bash vst-install.sh --force \
            --email "admin@$(hostname -f)" \
            --password "$vesta_pass" \
            --hostname "$(hostname -f)"
    else
        bash vst-install.sh
    fi
}

install_hestiacp() {
    echo -e "${BLUE}[INFO] Installing HestiaCP...${NC}"
    wget https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Running HestiaCP non-interactive installer with --force flag.${NC}"
        local hestia_pass
        hestia_pass="$(openssl rand -base64 14 | tr -dc 'A-Za-z0-9' | head -c 16)"
        echo -e "${YELLOW}╔══════════════════════════════════════════╗"
        echo -e "  HestiaCP Admin Password: ${hestia_pass}"
        echo -e "  Save this password before continuing!"
        echo -e "╚══════════════════════════════════════════╝${NC}"
        sleep 6
        bash hst-install.sh \
            --force \
            --email "admin@$(hostname -f)" \
            --password "$hestia_pass" \
            --hostname "$(hostname -f)"
    else
        echo -e "${CYAN}[NORMAL] Running HestiaCP interactive installer...${NC}"
        bash hst-install.sh
    fi
}

install_cwp() {
    echo -e "${BLUE}[INFO] Installing CentOS Web Panel (CWP)...${NC}"
    local CWP_MAJOR
    CWP_MAJOR=$(echo "$OS_VERSION" | cut -d. -f1)
    cd /usr/local/src

    case "$CWP_MAJOR" in
        7) wget http://centos-webpanel.com/cwp-el7-latest ; sh cwp-el7-latest ;;
        8) wget http://centos-webpanel.com/cwp-el8-latest ; sh cwp-el8-latest ;;
        9) wget http://centos-webpanel.com/cwp-el9-latest ; sh cwp-el9-latest ;;
        *)
            echo -e "${RED}[ERROR] OS version not supported by CWP.${NC}"; return 1 ;;
    esac

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] CWP installer runs non-interactively by default.${NC}"
    else
        echo -e "${CYAN}[NORMAL] CWP installer running. Server will reboot automatically when done.${NC}"
    fi
}

install_ispconfig() {
    echo -e "${BLUE}[INFO] Installing ISPConfig...${NC}"

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Running ISPConfig unattended installer with --no-interaction flag.${NC}"
        wget -O - https://get.ispconfig.org | sh -s -- \
            --use-ftp-ports=40110-40210 \
            --unattended-upgrades \
            --no-interaction \
            --no-dns \
            --no-mail
    else
        echo -e "${CYAN}[NORMAL] Running ISPConfig interactive installer...${NC}"
        wget -O - https://get.ispconfig.org | sh -s -- \
            --use-ftp-ports=40110-40210 \
            --unattended-upgrades
    fi
}

install_ajenti() {
    echo -e "${BLUE}[INFO] Installing Ajenti...${NC}"

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Running Ajenti installer — DEBIAN_FRONTEND=noninteractive.${NC}"
        DEBIAN_FRONTEND=noninteractive curl https://raw.githubusercontent.com/ajenti/ajenti/master/scripts/install.sh | bash -s -
    else
        echo -e "${CYAN}[NORMAL] Running Ajenti installer — interactive.${NC}"
        curl https://raw.githubusercontent.com/ajenti/ajenti/master/scripts/install.sh | bash -s -
    fi
}

install_1panel() {
    echo -e "${BLUE}[INFO] Installing 1Panel...${NC}"
    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] Running 1Panel installer with default settings...${NC}"
        bash -c "$(curl -sSL https://resource.1panel.pro/v2/quick_start.sh)"
    else
        echo -e "${CYAN}[NORMAL] Running 1Panel installer...${NC}"
        bash -c "$(curl -sSL https://resource.1panel.pro/v2/quick_start.sh)"
    fi
}

install_openpanel() {
    echo -e "${BLUE}[INFO] Installing OpenPanel...${NC}"
    bash <(curl -sSL https://openpanel.co/install.sh)
}

install_pterodactyl() {
    local installer_url="https://raw.githubusercontent.com/mnasikin/pist.sh/main/pterodactyl_installer.sh"
    local installer_path="/tmp/pterodactyl_installer.sh"

    if ! is_pterodactyl_supported_os; then
        echo -e "${RED}[ERROR] Pterodactyl supports Ubuntu 20.04/22.04/24.04 and Debian 11/12 only.${NC}"
        return 1
    fi

    echo -e "${BLUE}[INFO] Downloading Pterodactyl installer...${NC}"
    curl -fsSL "$installer_url" -o "$installer_path"
    chmod +x "$installer_path"
    bash "$installer_path"
}

install_coolify() {
    echo -e "${BLUE}[INFO] Installing Coolify...${NC}"
    curl -fsSL https://get.coollabs.io/coolify/install.sh | bash
}

install_easypanel() {
    echo -e "${BLUE}[INFO] Installing Easypanel...${NC}"
    curl -sSL https://get.easypanel.io | bash
}

install_yunohost() {
    echo -e "${BLUE}[INFO] Installing YunoHost...${NC}"
    curl https://install.yunohost.org | bash
}

# ─────────────────────────────────────────────────────────────
# Main installation handler
# ─────────────────────────────────────────────────────────────
perform_installation() {
    local panel_key=$1

    echo -e "${BLUE}[INFO] Updating system packages...${NC}"
    if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
        if [[ "$INSTALL_MODE" == "quick" ]]; then
            DEBIAN_FRONTEND=noninteractive apt-get update -y
            DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
                -o Dpkg::Options::="--force-confold" \
                -o Dpkg::Options::="--force-confdef"
        else
            apt-get update -y && apt-get upgrade -y
        fi
    else
        yum update -y
    fi

    echo -e "\n${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installing: $(echo "$panel_key" | tr '[:lower:]' '[:upper:]')  [${INSTALL_MODE^^} MODE]${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}\n"

    case $panel_key in
        cpanel)      install_cpanel      ;;
        plesk)       install_plesk       ;;
        webuzo)      install_webuzo      ;;
        directadmin) install_directadmin ;;
        interworx)   install_interworx   ;;
        ispmanager)  install_ispmanager  ;;
        fastpanel)   install_fastpanel   ;;
        enhance)     install_enhance     ;;
        apiscp)      install_apiscp      ;;
        virtualmin)  install_virtualmin  ;;
        aapanel)     install_aapanel     ;;
        cyberpanel) install_cyberpanel ;;
        cloudpanel) install_cloudpanel ;;
        webmin)     install_webmin     ;;
        vestacp)    install_vestacp    ;;
        hestiacp)   install_hestiacp   ;;
        cwp)        install_cwp        ;;
        ispconfig)  install_ispconfig  ;;
        ajenti)      install_ajenti      ;;
        1panel)      install_1panel      ;;
        openpanel)   install_openpanel   ;;
        pterodactyl) install_pterodactyl ;;
        coolify)     install_coolify     ;;
        easypanel)   install_easypanel   ;;
        yunohost)    install_yunohost    ;;
        *)
            echo -e "${RED}[ERROR] Unknown panel: $panel_key${NC}"; return 1 ;;
    esac

    echo -e "\n${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installation completed! [${INSTALL_MODE^^} MODE]${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Panel access URL:${NC}"
    case $panel_key in
        cpanel)      echo -e "  cPanel      : https://${IP_ADDRESS}:2087" ;;
        plesk)       echo -e "  Plesk       : https://${IP_ADDRESS}:8443" ;;
        webuzo)      echo -e "  Webuzo      : https://${IP_ADDRESS}:2005" ;;
        directadmin) echo -e "  DirectAdmin : https://${IP_ADDRESS}:2222" ;;
        interworx)   echo -e "  InterWorx   : https://${IP_ADDRESS}:2443" ;;
        ispmanager)  echo -e "  ISPmanager  : https://${IP_ADDRESS}:1500" ;;
        fastpanel)   echo -e "  FASTPANEL   : https://${IP_ADDRESS}:8888" ;;
        enhance)     echo -e "  Enhance     : https://${IP_ADDRESS}:8080" ;;
        apiscp)      echo -e "  ApisCP      : https://${IP_ADDRESS}:2083" ;;
        virtualmin)  echo -e "  Virtualmin  : https://${IP_ADDRESS}:10000" ;;
        aapanel)     echo -e "  aaPanel     : http://${IP_ADDRESS}:7800" ;;
        cyberpanel)  echo -e "  CyberPanel  : https://${IP_ADDRESS}:8090" ;;
        cloudpanel)  echo -e "  CloudPanel  : https://${IP_ADDRESS}:8443" ;;
        webmin)      echo -e "  Webmin      : https://${IP_ADDRESS}:10000" ;;
        vestacp)     echo -e "  VestaCP     : https://${IP_ADDRESS}:8083" ;;
        hestiacp)    echo -e "  HestiaCP    : https://${IP_ADDRESS}:8083" ;;
        cwp)         echo -e "  CWP         : https://${IP_ADDRESS}:2031 (after reboot)" ;;
        ispconfig)   echo -e "  ISPConfig   : https://${IP_ADDRESS}:8080" ;;
        ajenti)      echo -e "  Ajenti      : https://${IP_ADDRESS}:8000" ;;
        1panel)      echo -e "  1Panel      : Check console output for random port and entrance" ;;
        openpanel)   echo -e "  OpenPanel   : https://${IP_ADDRESS}:2083" ;;
        pterodactyl) echo -e "  Pterodactyl : Use the domain or IP configured during the installer" ;;
        coolify)     echo -e "  Coolify     : https://${IP_ADDRESS}:8000" ;;
        easypanel)   echo -e "  Easypanel   : http://${IP_ADDRESS}:3000" ;;
        yunohost)    echo -e "  YunoHost    : https://${IP_ADDRESS}/admin" ;;
    esac
    echo ""
}

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────
main() {
    print_banner
    check_root
    detect_os
    get_specs
    display_specs
    detect_existing_panels
    display_install_status
    warn_if_not_fresh
    check_compatibility
    choose_panel_filter
    display_panels

    read -p "Select the control panel to install (enter number): " choice

    if [[ "$choice" == "0" ]]; then
        echo -e "${YELLOW}Exiting installer...${NC}"; exit 0
    fi

    if [[ "$choice" == "99" ]]; then
        echo -e "\n${BLUE}[INFO] Running System Benchmark (YABS)...${NC}"
        curl -sL yabs.sh | bash; exit 0
    fi

    if [[ -n "${PANEL_NUMBERS[$choice]}" ]]; then
        SELECTED_PANEL="${PANEL_NUMBERS[$choice]}"
        IFS='|' read -r name _ _ <<< "${PANELS[$SELECTED_PANEL]}"
        local panel_type="${PANEL_TYPE[$SELECTED_PANEL]}"

        echo -e "\n${CYAN}Selected panel: $name${NC}"

        choose_install_mode "$name"

        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗"
        echo -e "║                  INSTALLATION SUMMARY                      ║"
        echo -e "╚════════════════════════════════════════════════════════════╝${NC}"
        echo -e "  Panel   : ${CYAN}${name}${NC}"
        echo -e "  Type    : $([ "$panel_type" == "free" ] && echo "${GREEN}Free${NC}" || echo "${RED}Paid (License Required)${NC}")"
        echo -e "  Mode    : ${CYAN}${INSTALL_MODE^^}${NC}"
        echo -e "  Server  : ${CYAN}${IP_ADDRESS}${NC}"
        echo -e "  OS      : ${CYAN}${OS_NAME}${NC}"
        echo -e "  Status  : $([ "$IS_FRESH" == true ] && echo "${GREEN}Fresh Install${NC}" || echo "${YELLOW}Not Fresh${NC}")"
        echo ""

        read -p "Proceed with installation? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
            perform_installation "$SELECTED_PANEL"
        else
            echo -e "${YELLOW}Installation cancelled.${NC}"
        fi
    else
        echo -e "${RED}[ERROR] Invalid selection!${NC}"
        exit 1
    fi
}

main
