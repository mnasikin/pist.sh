#!/bin/bash

# pist.sh - VPS Control Panel Auto Installer v1.0
# Supports Quick Mode (non-interactive) and Normal Mode (interactive)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

INSTALL_MODE=""
DETECTED_PANELS=()
IS_FRESH=true

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║        pist.sh VPS Control Panel Auto Installer v1.0       ║"
    echo "║     One Script, Multiple Panels — Quick & Normal Mode      ║"
    echo "║     Repository: https://github.com/mnasikin/pist.sh        ║"
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

    # cPanel
    if [[ -f /usr/local/cpanel/cpanel ]] || systemctl is-active --quiet cpanel 2>/dev/null; then
        DETECTED_PANELS+=("cPanel/WHM")
        IS_FRESH=false
    fi

    # Plesk
    if [[ -f /usr/local/psa/version ]] || command -v plesk &>/dev/null; then
        DETECTED_PANELS+=("Plesk")
        IS_FRESH=false
    fi

    # aaPanel
    if [[ -f /www/server/panel/BT-Panel ]] || [[ -d /www/server/panel ]]; then
        DETECTED_PANELS+=("aaPanel")
        IS_FRESH=false
    fi

    # CyberPanel
    if [[ -f /usr/local/CyberCP/CyberCP/settings.py ]] || command -v cyberpanel &>/dev/null; then
        DETECTED_PANELS+=("CyberPanel")
        IS_FRESH=false
    fi

    # CloudPanel
    if [[ -f /etc/clp/version ]] || [[ -d /home/clp ]]; then
        DETECTED_PANELS+=("CloudPanel")
        IS_FRESH=false
    fi

    # Webmin
    if systemctl is-active --quiet webmin 2>/dev/null || [[ -f /etc/webmin/version ]]; then
        DETECTED_PANELS+=("Webmin")
        IS_FRESH=false
    fi

    # VestaCP
    if [[ -d /usr/local/vesta ]] || command -v v-list-users &>/dev/null; then
        DETECTED_PANELS+=("VestaCP")
        IS_FRESH=false
    fi

    # HestiaCP
    if [[ -d /usr/local/hestia ]] || command -v v-add-user &>/dev/null && [[ -f /usr/local/hestia/conf/hestia.conf ]]; then
        DETECTED_PANELS+=("HestiaCP")
        IS_FRESH=false
    fi

    # CWP
    if [[ -d /usr/local/cwpsrv ]] || [[ -f /usr/local/cwp/.conf ]]; then
        DETECTED_PANELS+=("CentOS Web Panel (CWP)")
        IS_FRESH=false
    fi

    # ISPConfig
    if [[ -d /usr/local/ispconfig ]] || [[ -f /usr/local/ispconfig/interface/lib/config.inc.php ]]; then
        DETECTED_PANELS+=("ISPConfig")
        IS_FRESH=false
    fi

    # Ajenti
    if systemctl is-active --quiet ajenti 2>/dev/null || command -v ajenti-panel &>/dev/null; then
        DETECTED_PANELS+=("Ajenti")
        IS_FRESH=false
    fi

    # Detect common web stacks (no panel, but not fresh)
    STACK_FOUND=()
    command -v nginx &>/dev/null && STACK_FOUND+=("Nginx")
    command -v apache2 &>/dev/null && STACK_FOUND+=("Apache2")
    command -v httpd &>/dev/null && STACK_FOUND+=("Apache/httpd")
    command -v mysql &>/dev/null && STACK_FOUND+=("MySQL")
    command -v mariadb &>/dev/null && STACK_FOUND+=("MariaDB")
    command -v php &>/dev/null && STACK_FOUND+=("PHP")
    command -v docker &>/dev/null && STACK_FOUND+=("Docker")

    if [[ ${#STACK_FOUND[@]} -gt 0 ]]; then
        IS_FRESH=false
    fi
}

# ─────────────────────────────────────────────────────────────
# Display installation status
# ─────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────
# Warn if not fresh and prompt to continue
# ─────────────────────────────────────────────────────────────
warn_if_not_fresh() {
    if [[ "$IS_FRESH" == true ]]; then
        return 0
    fi

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

check_compatibility() {
    declare -gA PANELS

    if [[ "$OS" =~ ^(centos|almalinux|rocky)$ ]] && [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]]; then
        PANELS["cpanel"]="cPanel/WHM (Commercial - License Required)|min: 1 Core, 1GB RAM, 20GB Disk|CentOS/AlmaLinux/Rocky"
    fi

    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]]; then
        if [[ "$OS" =~ ^(centos|ubuntu|debian|almalinux|rocky)$ ]]; then
            PANELS["plesk"]="Plesk Panel (Commercial - Trial Available)|min: 1 Core, 1GB RAM, 4GB Disk|Multi-OS"
        fi
    fi

    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]]; then
        if [[ "$OS" =~ ^(centos|ubuntu|debian|almalinux|rocky)$ ]]; then
            PANELS["aapanel"]="aaPanel (Free)|min: 1 Core, 512MB RAM, 10GB Disk|Ubuntu/Debian/CentOS/AlmaLinux/Rocky"
        fi
    fi

    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]]; then
        if [[ "$OS" =~ ^(centos|ubuntu|almalinux)$ ]]; then
            PANELS["cyberpanel"]="CyberPanel (Free - OpenLiteSpeed)|min: 1 Core, 1GB RAM, 10GB Disk|Ubuntu/CentOS/AlmaLinux"
        fi
    fi

    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 2048 ]]; then
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            PANELS["cloudpanel"]="CloudPanel (Free - Modern)|min: 1 Core, 2GB RAM, 10GB Disk|Ubuntu 22.04/24.04, Debian 11/12"
        fi
    fi

    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 256 ]]; then
        PANELS["webmin"]="Webmin (Free - Lightweight)|min: 1 Core, 256MB RAM|Multi-OS"
    fi

    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]]; then
        if [[ "$OS" =~ ^(centos|ubuntu|debian)$ ]]; then
            PANELS["vestacp"]="VestaCP (Free)|min: 1 Core, 512MB RAM, 3GB Disk|Ubuntu/Debian/CentOS"
        fi
    fi

    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]]; then
        if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
            PANELS["hestiacp"]="HestiaCP (Free - VestaCP Fork)|min: 1 Core, 512MB RAM, 3GB Disk|Ubuntu/Debian"
        fi
    fi

    if [[ "$OS" =~ ^(centos|almalinux|rocky)$ ]] && [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]]; then
        PANELS["cwp"]="CentOS Web Panel (Free)|min: 1 Core, 512MB RAM, 5GB Disk|CentOS/AlmaLinux/Rocky"
    fi

    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 1024 ]]; then
        if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
            PANELS["ispconfig"]="ISPConfig (Free)|min: 1 Core, 1GB RAM, 5GB Disk|Ubuntu/Debian"
        fi
    fi

    if [[ "$CPU_CORES" -ge 1 ]] && [[ "$TOTAL_RAM" -ge 512 ]]; then
        PANELS["ajenti"]="Ajenti (Free - Modern UI)|min: 1 Core, 512MB RAM|Multi-OS"
    fi
}

display_panels() {
    if [ ${#PANELS[@]} -eq 0 ]; then
        echo -e "${RED}[ERROR] No control panel compatible with this server!${NC}"
        echo "Minimum specifications not met or OS not supported."
        exit 1
    fi

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║             AVAILABLE CONTROL PANELS                       ║"
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}\n"

    local i=1
    declare -gA PANEL_NUMBERS

    for key in "${!PANELS[@]}"; do
        IFS='|' read -r name specs os_support <<< "${PANELS[$key]}"
        PANEL_NUMBERS[$i]="$key"

        # Badge: flag if panel already installed
        local badge=""
        for dp in "${DETECTED_PANELS[@]}"; do
            if [[ "$name" == *"$dp"* ]] || [[ "$dp" == *"$(echo "$name" | awk '{print $1}')"* ]]; then
                badge=" ${RED}[ALREADY INSTALLED]${NC}"
                break
            fi
        done

        echo -e "${YELLOW}[$i]${NC} ${CYAN}$name${NC}${badge}"
        echo -e "    Requirements: $specs"
        echo -e "    Supported OS: $os_support"
        echo ""
        ((i++))
    done

    echo -e "${YELLOW}[99]${NC} ${CYAN}Run System Benchmark (YABS)${NC}"
    echo -e "${YELLOW}[0]${NC}  ${RED}Exit${NC}"
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
        echo -e "${GREEN}[QUICK] Proceeding with installation — assuming license is already owned.${NC}"
    else
        read -p "Do you already have a license? (y/n): " has_license
        if [[ "$has_license" != "y" ]]; then
            echo -e "${RED}Installation cancelled. Please purchase a license at https://cpanel.net${NC}"
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
        echo -e "${CYAN}        Defaults: Full install, OpenLiteSpeed, with Memcached & Watchdog.${NC}"
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
        echo "3b639730371ac2a56f8f955dbdf8459d5aaeb425578eb10c6e4d6b76a75de544 install_cloudpanel.sh" | sha256sum -c && \
        bash install_cloudpanel.sh
    else
        echo -e "${CYAN}[NORMAL] Verifying checksum and installing CloudPanel...${NC}"
        echo "3b639730371ac2a56f8f955dbdf8459d5aaeb425578eb10c6e4d6b76a75de544 install_cloudpanel.sh" | sha256sum -c && \
        bash install_cloudpanel.sh
    fi
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
            echo -e "${YELLOW}Installation cancelled.${NC}"
            return 1
        fi
    fi

    curl -O http://vestacp.com/pub/vst-install.sh

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        local vesta_pass
        vesta_pass="$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 14)"
        echo -e "${YELLOW}╔══════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}  Generated Admin Password: ${vesta_pass}  ${NC}"
        echo -e "${YELLOW}  Save this password before continuing!   ${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════╝${NC}"
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
        echo -e "${YELLOW}╔══════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}  HestiaCP Admin Password: ${hestia_pass}  ${NC}"
        echo -e "${YELLOW}  Save this password before continuing!   ${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════╝${NC}"
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
            echo -e "${RED}[ERROR] OS version not supported by CWP.${NC}"
            return 1
            ;;
    esac

    if [[ "$INSTALL_MODE" == "quick" ]]; then
        echo -e "${GREEN}[QUICK] CWP installer runs non-interactively by default — no extra flags needed.${NC}"
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
        cpanel)     install_cpanel     ;;
        plesk)      install_plesk      ;;
        aapanel)    install_aapanel    ;;
        cyberpanel) install_cyberpanel ;;
        cloudpanel) install_cloudpanel ;;
        webmin)     install_webmin     ;;
        vestacp)    install_vestacp    ;;
        hestiacp)   install_hestiacp   ;;
        cwp)        install_cwp        ;;
        ispconfig)  install_ispconfig  ;;
        ajenti)     install_ajenti     ;;
        *)
            echo -e "${RED}[ERROR] Unknown panel: $panel_key${NC}"
            return 1
            ;;
    esac

    echo -e "\n${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installation completed! [${INSTALL_MODE^^} MODE]${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Default panel access URLs:${NC}"
    echo -e "  cPanel      : https://${IP_ADDRESS}:2087"
    echo -e "  Plesk        : https://${IP_ADDRESS}:8443"
    echo -e "  aaPanel      : http://${IP_ADDRESS}:7800"
    echo -e "  CyberPanel   : https://${IP_ADDRESS}:8090"
    echo -e "  CloudPanel   : https://${IP_ADDRESS}:8443"
    echo -e "  Webmin       : https://${IP_ADDRESS}:10000"
    echo -e "  HestiaCP     : https://${IP_ADDRESS}:8083"
    echo -e "  CWP          : https://${IP_ADDRESS}:2087 (after reboot)"
    echo -e "  ISPConfig    : https://${IP_ADDRESS}:8080"
    echo -e "  Ajenti       : https://${IP_ADDRESS}:8000"
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
    display_panels

    read -p "Select the control panel to install (enter number): " choice

    if [[ "$choice" == "0" ]]; then
        echo -e "${YELLOW}Exiting installer...${NC}"
        exit 0
    fi

    if [[ "$choice" == "99" ]]; then
        echo -e "\n${BLUE}[INFO] Running System Benchmark (YABS)...${NC}"
        curl -sL yabs.sh | bash
        exit 0
    fi

    if [[ -n "${PANEL_NUMBERS[$choice]}" ]]; then
        SELECTED_PANEL="${PANEL_NUMBERS[$choice]}"
        IFS='|' read -r name _ _ <<< "${PANELS[$SELECTED_PANEL]}"

        echo -e "\n${CYAN}Selected panel: $name${NC}"

        choose_install_mode "$name"

        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗"
        echo -e "║                  INSTALLATION SUMMARY                      ║"
        echo -e "╚════════════════════════════════════════════════════════════╝${NC}"
        echo -e "  Panel   : ${CYAN}${name}${NC}"
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
