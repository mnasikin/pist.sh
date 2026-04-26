#!/bin/bash

# pterodactyl_installer.sh - Pterodactyl Panel + Wings Installer
# Interactive installer for supported Ubuntu and Debian releases.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Helpers
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
dim()     { echo -e "${DIM}$*${NC}"; }

title() {
  echo ""
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  printf "${GREEN}║${NC} %-58s ${GREEN}║${NC}\n" "$*"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
}

confirm() {
  local prompt="$1"
  local answer
  read -rp "$(echo -e "${YELLOW}  ${prompt} [y/N]: ${NC}")" answer
  [[ "${answer,,}" == "y" ]]
}

# Prompt with a fallback default.
# Usage: prompt_default VAR_NAME "Prompt text" "default_value"
prompt_default() {
  local var_name="$1"
  local prompt_text="$2"
  local default_val="$3"
  local input
  read -rp "$(echo -e "${YELLOW}  ${prompt_text} ${DIM}[default: ${default_val}]${NC}${YELLOW}: ${NC}")" input
  if [[ -z "$input" ]]; then
    eval "${var_name}='${default_val}'"
    dim "  -> Using default: ${default_val}"
  else
    eval "${var_name}='${input}'"
  fi
}

# Password prompt with confirmation
prompt_password() {
  local var_name="$1"
  local prompt_text="$2"
  local val confirm
  while true; do
    read -rsp "$(echo -e "${YELLOW}  ${prompt_text}: ${NC}")" val; echo
    read -rsp "$(echo -e "${YELLOW}  Confirm password: ${NC}")" confirm; echo
    if [[ "$val" == "$confirm" ]]; then
      eval "${var_name}='${val}'"
      break
    fi
    warn "Passwords do not match. Please try again."
  done
}

# Choose from a numbered list.
# Usage: choose_from VAR_NAME "Title" item1 item2 item3...
choose_from() {
  local var_name="$1"
  local prompt_text="$2"
  shift 2
  local items=("$@")
  echo -e "${YELLOW}  ${prompt_text}:${NC}"
  for i in "${!items[@]}"; do
    echo -e "    ${CYAN}$((i+1)))${NC} ${items[$i]}"
  done
  local choice
  while true; do
    read -rp "$(echo -e "${YELLOW}  Choice [1-${#items[@]}]: ${NC}")" choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#items[@]} )); then
      eval "${var_name}='${items[$((choice-1))]}'"
      dim "  -> Selected: ${items[$((choice-1))]}"
      break
    fi
    warn "Invalid selection."
  done
}

print_banner() {
  clear
  echo -e "${CYAN}"
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║    Pterodactyl Panel + Wings Installer for pist.sh v1.3    ║"
  echo "║        Interactive Setup for Supported Debian/Ubuntu       ║"
  echo "║     Repository: https://github.com/mnasikin/pist.sh        ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

print_banner

# Root check
[[ "$EUID" -ne 0 ]] && error "Script must be run as root.\n  Try: sudo bash $0"

# Detect OS
title "Operating System Detection"

[[ -f /etc/os-release ]] || error "Unable to read /etc/os-release."
source /etc/os-release
OS_ID="${ID}"
OS_VERSION="${VERSION_ID}"

success "Detected OS: ${BOLD}${OS_ID} ${OS_VERSION}${NC}"

# PHP configuration
title "PHP Configuration"

echo -e "  ${DIM}Pterodactyl requires PHP 8.1+. Recommended: 8.3${NC}"
echo ""

PHP_VERSIONS=("8.3 (recommended)" "8.2" "8.1")
choose_from PHP_CHOICE "Choose PHP version" "${PHP_VERSIONS[@]}"

# Extract the version number only.
PHP_VERSION=$(echo "$PHP_CHOICE" | grep -oP '8\.[0-9]+')
success "PHP version to install: ${BOLD}${PHP_VERSION}${NC}"

# Database configuration
title "Database Configuration"

DB_ENGINES=("MariaDB (recommended)" "MySQL")
choose_from DB_CHOICE "Choose database engine" "${DB_ENGINES[@]}"

if [[ "$DB_CHOICE" == "MariaDB (recommended)" ]]; then
  DB_ENGINE="mariadb"
  DB_VERSIONS=("latest (recommended)" "10.11" "10.6")
  choose_from DB_VER_CHOICE "Choose MariaDB version" "${DB_VERSIONS[@]}"
  if [[ "$DB_VER_CHOICE" == "latest (recommended)" ]]; then
    DB_VERSION="latest"
  else
    DB_VERSION="$DB_VER_CHOICE"
  fi
else
  DB_ENGINE="mysql"
  DB_VERSIONS=("8.0 (recommended)" "8.4")
  choose_from DB_VER_CHOICE "Choose MySQL version" "${DB_VERSIONS[@]}"
  DB_VERSION=$(echo "$DB_VER_CHOICE" | grep -oP '[0-9]+\.[0-9]+')
fi

echo ""
prompt_default DB_NAME     "Database name"     "panel"
prompt_default DB_USER     "Database username" "pterodactyl"
prompt_default DB_HOST     "Database host"     "127.0.0.1"
prompt_default DB_PORT_VAL "Database port"     "3306"
prompt_password DB_PASSWORD "Password for database user '${DB_USER}'"

success "Database: ${BOLD}${DB_ENGINE} | db=${DB_NAME} | user=${DB_USER}${NC}"

# Redis configuration
title "Redis Configuration"

prompt_default REDIS_HOST "Redis host"  "127.0.0.1"
prompt_default REDIS_PORT "Redis port"  "6379"

echo ""
echo -e "  ${YELLOW}Redis password (optional, press Enter to skip):${NC}"
read -rsp "  Redis password: " REDIS_PASS; echo
if [[ -z "$REDIS_PASS" ]]; then
  REDIS_PASS="null"
  dim "  -> No Redis password"
fi

success "Redis: ${BOLD}${REDIS_HOST}:${REDIS_PORT}${NC}"

# Timezone configuration
title "Timezone Configuration"

echo -e "  ${DIM}Examples: Asia/Jakarta, Asia/Makassar, Asia/Jayapura, UTC${NC}"
echo ""
prompt_default TIMEZONE "Timezone" "Asia/Jakarta"

# Validate timezone
if ! timedatectl list-timezones 2>/dev/null | grep -qx "$TIMEZONE"; then
  warn "Timezone '${TIMEZONE}' is not recognized by the system. It will still be used, but please double-check it."
else
  success "Timezone: ${BOLD}${TIMEZONE}${NC}"
fi

# Panel and app configuration
title "Panel Configuration"

prompt_default APP_NAME "Panel application name" "Pterodactyl"

echo ""
echo -e "  ${YELLOW}SSL mode:${NC}"
echo -e "    ${CYAN}1)${NC} Use a domain + Certbot (HTTPS) — recommended"
echo -e "    ${CYAN}2)${NC} Use bare IP (HTTP) — for testing"
read -rp "$(echo -e "  ${YELLOW}Choice [1/2]: ${NC}")" SSL_CHOICE

USE_SSL=false
DOMAIN=""
LE_EMAIL=""

if [[ "$SSL_CHOICE" == "1" ]]; then
  USE_SSL=true
  echo ""
  read -rp "$(echo -e "  ${YELLOW}Panel domain (example: panel.example.com): ${NC}")" DOMAIN
  [[ -z "$DOMAIN" ]] && error "Domain cannot be empty."
  read -rp "$(echo -e "  ${YELLOW}Email Let's Encrypt: ${NC}")" LE_EMAIL
  [[ -z "$LE_EMAIL" ]] && error "Email cannot be empty for Certbot."
  APP_URL="https://${DOMAIN}"
else
  warn "HTTP mode selected. This is not recommended for production."
  DOMAIN=$(hostname -I | awk '{print $1}')
  APP_URL="http://${DOMAIN}"
  info "Using IP address: ${DOMAIN}"
fi

# Nginx port configuration
title "Nginx Port Configuration"

if [[ "$USE_SSL" == "true" ]]; then
  prompt_default NGINX_HTTP_PORT  "Port HTTP (redirect ke HTTPS)" "80"
  prompt_default NGINX_HTTPS_PORT "Port HTTPS"                   "443"
else
  prompt_default NGINX_HTTP_PORT "Port HTTP" "80"
  NGINX_HTTPS_PORT=""
fi

success "Nginx ports: ${BOLD}HTTP=${NGINX_HTTP_PORT}$([ -n "${NGINX_HTTPS_PORT}" ] && echo " | HTTPS=${NGINX_HTTPS_PORT}")${NC}"

# ============================================================
# Admin user configuration
title "Create Panel Admin User"

read -rp "$(echo -e "  ${YELLOW}Admin email: ${NC}")" ADMIN_EMAIL
[[ -z "$ADMIN_EMAIL" ]] && error "Admin email cannot be empty."

prompt_default ADMIN_USERNAME   "Username admin"  "admin"
prompt_default ADMIN_FIRSTNAME  "First name"      "Admin"
prompt_default ADMIN_LASTNAME   "Last name"       "User"

echo ""
echo -e "  ${DIM}Password should be at least 8 characters, with mixed case and numbers${NC}"
prompt_password ADMIN_PASSWORD "Admin password"

# Configuration summary
title "Configuration Summary"

echo -e "  ${BOLD}OS${NC}            : ${OS_ID} ${OS_VERSION}"
echo -e "  ${BOLD}PHP${NC}           : ${PHP_VERSION}"
echo -e "  ${BOLD}Database${NC}      : ${DB_ENGINE} ${DB_VERSION} | db=${DB_NAME} | user=${DB_USER} | ${DB_HOST}:${DB_PORT_VAL}"
echo -e "  ${BOLD}Redis${NC}         : ${REDIS_HOST}:${REDIS_PORT} | password=$([ "$REDIS_PASS" == "null" ] && echo "none" || echo "****")"
echo -e "  ${BOLD}Timezone${NC}      : ${TIMEZONE}"
echo -e "  ${BOLD}App Name${NC}      : ${APP_NAME}"
echo -e "  ${BOLD}Panel URL${NC}     : ${APP_URL}"
echo -e "  ${BOLD}Nginx port${NC}    : HTTP=${NGINX_HTTP_PORT}$([ -n "${NGINX_HTTPS_PORT}" ] && echo " | HTTPS=${NGINX_HTTPS_PORT}")"
echo -e "  ${BOLD}Admin${NC}         : ${ADMIN_USERNAME} <${ADMIN_EMAIL}>"
echo ""

confirm "Start installation?" || { info "Installation cancelled."; exit 0; }

# Install dependencies
title "Install System Dependencies"

apt-get update -y
apt-get install -y \
  software-properties-common curl apt-transport-https \
  ca-certificates gnupg lsb-release unzip tar git wget cron

# PHP repository
info "Adding PHP repository..."
if [[ "$OS_ID" == "ubuntu" ]]; then
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
elif [[ "$OS_ID" == "debian" ]]; then
  curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg \
    https://packages.sury.org/php/apt.gpg
  echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/php.list
fi

# Redis repository
info "Adding Redis repository..."
curl -fsSL https://packages.redis.io/gpg \
  | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/redis.list

apt-get update -y

# PHP
info "Installing PHP ${PHP_VERSION}..."
apt-get install -y \
  "php${PHP_VERSION}" \
  "php${PHP_VERSION}-common" \
  "php${PHP_VERSION}-cli" \
  "php${PHP_VERSION}-gd" \
  "php${PHP_VERSION}-mysql" \
  "php${PHP_VERSION}-mbstring" \
  "php${PHP_VERSION}-bcmath" \
  "php${PHP_VERSION}-xml" \
  "php${PHP_VERSION}-fpm" \
  "php${PHP_VERSION}-curl" \
  "php${PHP_VERSION}-zip"

# Nginx and Redis
apt-get install -y nginx redis-server

# Configure Redis port and password when non-default values are used.
if [[ "$REDIS_PORT" != "6379" ]] || [[ "$REDIS_PASS" != "null" ]]; then
  info "Configuring Redis..."
  sed -i "s/^port .*/port ${REDIS_PORT}/" /etc/redis/redis.conf
  if [[ "$REDIS_PASS" != "null" ]]; then
    sed -i "s/^# requirepass .*/requirepass ${REDIS_PASS}/" /etc/redis/redis.conf
    sed -i "s/^requirepass .*/requirepass ${REDIS_PASS}/" /etc/redis/redis.conf
  fi
  systemctl restart redis-server
fi

success "System dependencies installed."

# Install database
title "Install and Configure Database"

if [[ "$DB_ENGINE" == "mariadb" ]]; then
  if [[ "$DB_VERSION" != "latest" ]]; then
    # Add a specific MariaDB repository version when requested.
    info "Adding MariaDB ${DB_VERSION} repository..."
    curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup \
      | bash -s -- --mariadb-server-version="mariadb-${DB_VERSION}"
    apt-get update -y
  fi
  apt-get install -y mariadb-server
  systemctl enable --now mariadb
  DB_CLI="mariadb -u root"
else
  # MySQL
  info "Adding MySQL ${DB_VERSION} repository..."
  if [[ "$OS_ID" == "ubuntu" ]]; then
    apt-get install -y mysql-server
  else
    # Debian uses the official MySQL APT repository.
    wget -q https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb -O /tmp/mysql-apt-config.deb
    DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/mysql-apt-config.deb
    apt-get update -y
    apt-get install -y mysql-server
  fi
  systemctl enable --now mysql
  DB_CLI="mysql -u root"
fi

info "Creating database and user..."
${DB_CLI} <<EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'${DB_HOST}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

success "Database '${DB_NAME}' and user '${DB_USER}' created."

# Install Composer
title "Install Composer"

curl -sS https://getcomposer.org/installer \
  | php -- --install-dir=/usr/local/bin --filename=composer

success "Composer installed."

# Download panel files
title "Download Pterodactyl Panel"

mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

curl -Lo panel.tar.gz \
  https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
rm -f panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

success "Panel files downloaded."

# Set up environment
title "Set Up Environment"

cd /var/www/pterodactyl

cp .env.example .env
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

php artisan key:generate --force

# Build the Redis URL string.
if [[ "$REDIS_PASS" != "null" ]]; then
  REDIS_URL="redis://:${REDIS_PASS}@${REDIS_HOST}:${REDIS_PORT}"
else
  REDIS_URL="redis://${REDIS_HOST}:${REDIS_PORT}"
fi

php artisan p:environment:setup \
  --author="${ADMIN_EMAIL}" \
  --url="${APP_URL}" \
  --timezone="${TIMEZONE}" \
  --cache=redis \
  --session=redis \
  --queue=redis \
  --redis-host="${REDIS_HOST}" \
  --redis-pass="${REDIS_PASS}" \
  --redis-port="${REDIS_PORT}" \
  --settings-ui=true

php artisan p:environment:database \
  --host="${DB_HOST}" \
  --port="${DB_PORT_VAL}" \
  --database="${DB_NAME}" \
  --username="${DB_USER}" \
  --password="${DB_PASSWORD}"

# Set APP_NAME in .env
sed -i "s|^APP_NAME=.*|APP_NAME=\"${APP_NAME}\"|" .env

# Run migrations
info "Running database migrations (this may take a while)..."
php artisan migrate --seed --force

success "Environment setup and migrations completed."

# Create admin user
title "Create Admin User"

if php artisan p:user:make \
  --email="${ADMIN_EMAIL}" \
  --username="${ADMIN_USERNAME}" \
  --name-first="${ADMIN_FIRSTNAME}" \
  --name-last="${ADMIN_LASTNAME}" \
  --password="${ADMIN_PASSWORD}" \
  --admin=1; then
  success "Admin user '${ADMIN_USERNAME}' created."
else
  warn "Admin user creation failed. The account may already exist, so the installer will continue."
fi

# File permissions
title "Set File Permissions"

chown -R www-data:www-data /var/www/pterodactyl/*

success "File permissions updated."

# Crontab and queue worker
title "Set Up Crontab and Queue Worker"

systemctl enable --now cron

CURRENT_CRONTAB="$(crontab -l 2>/dev/null || true)"
PTERODACTYL_CRON="* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"

if ! grep -Fqx "$PTERODACTYL_CRON" <<< "$CURRENT_CRONTAB"; then
  if [[ -n "$CURRENT_CRONTAB" ]]; then
    printf "%s\n%s\n" "$CURRENT_CRONTAB" "$PTERODACTYL_CRON" | crontab -
  else
    printf "%s\n" "$PTERODACTYL_CRON" | crontab -
  fi
fi

cat > /etc/systemd/system/pteroq.service <<SVCEOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable --now pteroq.service

success "Queue worker enabled."

# Nginx configuration
title "Configure Nginx"

PHP_FPM_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"

generate_nginx_location_blocks() {
cat <<LOCEOF
    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.access.log;
    error_log  /var/log/nginx/pterodactyl.error.log error;

    client_max_body_size 100m;
    client_body_timeout  120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:${PHP_FPM_SOCK};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
LOCEOF
}

if [[ "$USE_SSL" == "true" ]]; then
  apt-get install -y certbot python3-certbot-nginx

  # Temporary HTTP config for the Certbot challenge.
  cat > /etc/nginx/sites-available/pterodactyl <<NGINXEOF
server {
    listen ${NGINX_HTTP_PORT};
    server_name ${DOMAIN};
    $(generate_nginx_location_blocks)
}
NGINXEOF

  ln -sf /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/pterodactyl
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx

  info "Generating SSL certificate for ${DOMAIN}..."
  certbot certonly --nginx \
    -d "${DOMAIN}" \
    --email "${LE_EMAIL}" \
    --agree-tos \
    --no-eff-email

  # Full SSL configuration.
  cat > /etc/nginx/sites-available/pterodactyl <<NGINXEOF
server {
    listen ${NGINX_HTTP_PORT};
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen ${NGINX_HTTPS_PORT} ssl http2;
    server_name ${DOMAIN};

    ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_session_cache   shared:SSL:10m;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    $(generate_nginx_location_blocks)
}
NGINXEOF

else
  cat > /etc/nginx/sites-available/pterodactyl <<NGINXEOF
server {
    listen ${NGINX_HTTP_PORT};
    server_name ${DOMAIN};

    $(generate_nginx_location_blocks)
}
NGINXEOF
fi

ln -sf /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/pterodactyl
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl enable --now nginx && systemctl reload nginx

success "Nginx configured."

# Docker and Wings
title "Install Docker"

curl -sSL https://get.docker.com/ | CHANNEL=stable bash
systemctl enable --now docker

success "Docker installed."

title "Install Wings"

mkdir -p /etc/pterodactyl

ARCH="$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
curl -L -o /usr/local/bin/wings \
  "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${ARCH}"
chmod u+x /usr/local/bin/wings

cat > /etc/systemd/system/wings.service <<'WINGSEOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
WINGSEOF

systemctl daemon-reload
systemctl enable wings

success "Wings binary and service installed."

# Completed
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║    PTERODACTYL INSTALL COMPLETE!         ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Panel URL${NC}  : ${APP_URL}"
echo -e "  ${BOLD}App Name${NC}   : ${APP_NAME}"
echo -e "  ${BOLD}Admin user${NC} : ${ADMIN_USERNAME} <${ADMIN_EMAIL}>"
echo -e "  ${BOLD}PHP${NC}        : ${PHP_VERSION}"
echo -e "  ${BOLD}Database${NC}   : ${DB_ENGINE} | db=${DB_NAME}"
echo -e "  ${BOLD}Timezone${NC}   : ${TIMEZONE}"
echo ""
echo -e "${YELLOW}  NEXT STEPS (manual):${NC}"
echo -e "  ${CYAN}1.${NC} Open the panel in your browser and sign in with the admin account"
echo -e "  ${CYAN}2.${NC} Go to Admin > Nodes > Create New"
echo -e "  ${CYAN}3.${NC} After creating the node, copy the generated config"
echo -e "  ${CYAN}4.${NC} Save it to: /etc/pterodactyl/config.yml"
echo -e "  ${CYAN}5.${NC} Start Wings: ${BOLD}systemctl start wings${NC}"
echo -e "  ${CYAN}6.${NC} Check status: ${BOLD}systemctl status wings${NC}"
echo ""
echo -e "  ${DIM}Docs: https://pterodactyl.io/panel/1.0/getting_started.html${NC}"
echo ""
