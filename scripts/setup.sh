#!/usr/bin/env bash
# ==========================================
# MegaStack - Interactive Setup Wizard
# Configures modules, generates .env, deploys stack
# ==========================================

set -euo pipefail

MS_ROOT="${MS_ROOT:-/opt/megastack}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/tui.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[Setup]${NC} $*"; }
log_ok() { echo -e "${GREEN}[Setup]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[Setup]${NC} $*"; }
log_error() { echo -e "${RED}[Setup]${NC} $*"; }

# Generate a random secret
gen_secret() {
    openssl rand -hex 32
}

gen_password() {
    openssl rand -base64 16 | tr -d '/+=' | head -c 16
}

# Hash password using bcrypt via Node.js (if available) or Python
# SECURITY: Password passed via environment variable to prevent shell injection
hash_password() {
    local password="$1"
    # Try Node.js first (bcryptjs is already installed in dashboard)
    if command -v node &>/dev/null && [[ -f "${MS_ROOT}/dashboard/node_modules/bcryptjs/index.js" ]]; then
        MS_HASH_INPUT="$password" MS_BCRYPT_PATH="${MS_ROOT}/dashboard/node_modules/bcryptjs" \
            node -e "const b=require(process.env.MS_BCRYPT_PATH);console.log(b.hashSync(process.env.MS_HASH_INPUT,12))"
        return
    fi
    # Fallback to Python bcrypt
    if python3 -c "import bcrypt" &>/dev/null; then
        MS_HASH_INPUT="$password" \
            python3 -c "import os,bcrypt;print(bcrypt.hashpw(os.environ['MS_HASH_INPUT'].encode(),bcrypt.gensalt(12)).decode())"
        return
    fi
    # Last resort: htpasswd (already safe - uses argument, not interpolation)
    if command -v htpasswd &>/dev/null; then
        htpasswd -nbBC 12 "" "${password}" | cut -d: -f2
        return
    fi
    # Absolute fallback: SHA-256 (will be auto-upgraded on first login)
    log_warn "bcrypt not available - using SHA-256 (will be upgraded on first login)"
    echo -n "${password}" | openssl dgst -sha256 | awk '{print $2}'
}

# --- Welcome ---

tui_msgbox "MegaStack Setup" "Welcome to MegaStack!

This wizard will set up your media server step by step.

You'll enter your VPN credentials, domain name, and a few settings.

Don't worry - you can change everything later from the dashboard.
All passwords will be auto-generated if you leave them blank.

Press OK to get started."

# --- System Settings ---

log_info "Configuring system settings..."

MS_DOMAIN=$(tui_input "Server Address" \
    "Enter your server's IP address or domain name.

If you don't have a domain yet, enter your VPS IP address.
(Find it in your hosting provider's control panel.)

Example IP: 203.0.113.42
Example domain: myserver.com" \
    "localhost")

TZ=$(tui_input "Timezone" \
    "Enter your timezone (Continent/City format).

Common examples:
  America/New_York     (US Eastern)
  America/Chicago      (US Central)
  America/Los_Angeles  (US Pacific)
  Europe/London        (UK)
  Europe/Berlin        (Central Europe)
  Asia/Tokyo           (Japan)
  Australia/Sydney     (Australia)" \
    "UTC")

# --- VPN Configuration (mandatory for media) ---

log_info "Configuring VPN for media downloads..."

VPN_PROVIDER=$(tui_menu "VPN Provider" \
    "MegaStack routes downloads through a commercial VPN
to protect your IP address. You NEED an active VPN subscription.

Don't have one yet? Sign up through Tom's links for a discount:" \
    "nordvpn"    "NordVPN (4 extra months FREE!) - nordvpn.tomspark.tech" \
    "protonvpn"  "ProtonVPN (3 months FREE!) - protonvpn.tomspark.tech" \
    "surfshark"  "Surfshark (3 extra months FREE!) - surfshark.tomspark.tech" \
    "mullvad"    "Mullvad VPN")
VPN_PROVIDER=$(echo "${VPN_PROVIDER}" | tr -d '"')

VPN_TYPE=$(tui_menu "VPN Protocol" "Select VPN protocol:" \
    "openvpn"   "OpenVPN (works with all providers)" \
    "wireguard" "WireGuard (faster, check if your provider supports it)")
VPN_TYPE=$(echo "${VPN_TYPE}" | tr -d '"')

VPN_USER=""
VPN_PASSWORD=""
WIREGUARD_PRIVATE_KEY=""
WIREGUARD_ADDRESSES=""

if [[ "${VPN_TYPE}" == "openvpn" ]]; then
    VPN_USER=$(tui_input "VPN Username" \
        "Enter your VPN SERVICE username (not your account email).

Where to find it:
  NordVPN:   Dashboard > Services > Service credentials
  ProtonVPN: Settings > OpenVPN/IKEv2 username
  Surfshark: Devices > Manual Setup > Credentials
  Mullvad:   Just your account number" \
        "")
    VPN_PASSWORD=$(tui_password "VPN Password" "Enter your VPN service password:")
else
    WIREGUARD_PRIVATE_KEY=$(tui_input "WireGuard Key" "Enter your WireGuard private key:" "")
    WIREGUARD_ADDRESSES=$(tui_input "WireGuard Address" "Enter your WireGuard address:" "10.2.0.2/32")
fi

SERVER_COUNTRIES=$(tui_input "VPN Server" "Enter preferred VPN server country:" "United States")

MEDIA_ROOT="${MS_ROOT}/modules/media/media"
MEDIA_ROOT=$(tui_input "Media Storage" "Where should media files be stored? (downloads, movies, TV):" "${MEDIA_ROOT}")

# --- Dashboard Password ---

log_info "Setting up dashboard access..."

ADMIN_PASSWORD=$(tui_password "Dashboard Password" "Set a password for your MegaStack Dashboard (leave blank to auto-generate):")

if [[ -z "${ADMIN_PASSWORD}" ]]; then
    ADMIN_PASSWORD=$(gen_password)
fi

MS_ADMIN_PASSWORD_HASH=$(hash_password "${ADMIN_PASSWORD}")
MS_SESSION_SECRET=$(gen_secret)
MS_BACKUP_KEY=$(gen_secret)

# --- Module Selection ---

log_info "Selecting optional modules..."

SELECTED_MODULES=$(tui_checklist "Choose Your Features" \
    "Pick which optional features you want on your server.
Core, Dashboard, and Media are always enabled." \
    "privacy"    "Block ads + store passwords + protect logins"         "ON" \
    "cloud"      "Private file sync (like Google Drive, but yours)"    "OFF" \
    "monitoring" "Get alerts if a service goes down"                    "ON" \
    "vpn"        "Access your server securely from anywhere"           "OFF" \
    "files"      "Web-based file manager (browse/upload via browser)"  "OFF")

# Clean up whiptail output (removes quotes)
SELECTED_MODULES=$(echo "${SELECTED_MODULES}" | tr -d '"')

# --- Module-specific Configuration ---

# Privacy settings
PIHOLE_PASSWORD=""
VAULTWARDEN_ADMIN_TOKEN=""
AUTHELIA_JWT_SECRET=""
AUTHELIA_SESSION_SECRET=""
AUTHELIA_STORAGE_ENCRYPTION_KEY=""

if echo "${SELECTED_MODULES}" | grep -q "privacy"; then
    log_info "Configuring privacy module..."

    PIHOLE_PASSWORD=$(tui_password "Pi-hole Password" "Set a password for the Pi-hole ad-blocker admin panel (leave blank to auto-generate):")
    if [[ -z "${PIHOLE_PASSWORD}" ]]; then
        PIHOLE_PASSWORD=$(gen_password)
    fi

    VAULTWARDEN_ADMIN_TOKEN=$(gen_secret)
    AUTHELIA_JWT_SECRET=$(gen_secret)
    AUTHELIA_SESSION_SECRET=$(gen_secret)
    AUTHELIA_STORAGE_ENCRYPTION_KEY=$(gen_secret)

    # Generate Authelia configuration
    if [[ -f "${MS_ROOT}/templates/authelia-config.yml.tmpl" ]]; then
        mkdir -p "${MS_ROOT}/modules/privacy/config/authelia"
        sed \
            -e "s|{{MS_DOMAIN}}|${MS_DOMAIN}|g" \
            -e "s|{{AUTHELIA_JWT_SECRET}}|${AUTHELIA_JWT_SECRET}|g" \
            -e "s|{{AUTHELIA_SESSION_SECRET}}|${AUTHELIA_SESSION_SECRET}|g" \
            -e "s|{{AUTHELIA_STORAGE_ENCRYPTION_KEY}}|${AUTHELIA_STORAGE_ENCRYPTION_KEY}|g" \
            "${MS_ROOT}/templates/authelia-config.yml.tmpl" \
            > "${MS_ROOT}/modules/privacy/config/authelia/configuration.yml"
        log_ok "Authelia configuration generated."
    fi
fi

# Cloud settings
NEXTCLOUD_DB_ROOT_PASSWORD=""
NEXTCLOUD_DB_PASSWORD=""

if echo "${SELECTED_MODULES}" | grep -q "cloud"; then
    log_info "Configuring cloud module..."
    NEXTCLOUD_DB_ROOT_PASSWORD=$(gen_secret)
    NEXTCLOUD_DB_PASSWORD=$(gen_secret)
    log_ok "Nextcloud database passwords auto-generated."
fi

# WireGuard VPN Access settings
WG_PASSWORD=""
WG_PASSWORD_HASH=""

if echo "${SELECTED_MODULES}" | grep -q "vpn"; then
    log_info "Configuring VPN access module..."

    WG_PASSWORD=$(tui_password "WireGuard UI Password" "Set a password for the WireGuard VPN management panel (leave blank to auto-generate):")
    if [[ -z "${WG_PASSWORD}" ]]; then
        WG_PASSWORD=$(gen_password)
    fi
    # Generate bcrypt hash for wg-easy
    if command -v docker &>/dev/null; then
        WG_PASSWORD_HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "${WG_PASSWORD}" 2>/dev/null | tail -1 || echo "${WG_PASSWORD}")
    else
        WG_PASSWORD_HASH="${WG_PASSWORD}"
        log_warn "Docker not available to generate bcrypt hash for wg-easy. Password stored as plaintext."
    fi
fi

# --- Write modules.conf ---

mkdir -p "${MS_ROOT}/state"
{
    echo "core"
    echo "dashboard"
    echo "media"
    for module in ${SELECTED_MODULES}; do
        echo "${module}"
    done
} > "${MS_ROOT}/state/modules.conf"

log_ok "Modules configured: core dashboard media ${SELECTED_MODULES}"

# --- Generate .env ---

log_info "Generating configuration file..."

cat > "${MS_ROOT}/.env" << ENVEOF
# ==========================================
# MEGASTACK - Generated Configuration
# Generated: $(date)
# DO NOT share this file - it contains secrets!
# ==========================================

# --- SYSTEM ---
TZ=${TZ}
MS_ROOT=${MS_ROOT}
MS_DOMAIN=${MS_DOMAIN}

# --- DASHBOARD ---
MS_ADMIN_PASSWORD_HASH=${MS_ADMIN_PASSWORD_HASH}
MS_SESSION_SECRET=${MS_SESSION_SECRET}
# Backup encryption key - keep this safe! Without it, encrypted backups are unrecoverable.
MS_BACKUP_KEY=${MS_BACKUP_KEY}

# --- VPN (Media) ---
VPN_PROVIDER=${VPN_PROVIDER}
VPN_TYPE=${VPN_TYPE}
VPN_USER=${VPN_USER}
VPN_PASSWORD=${VPN_PASSWORD}
WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY}
WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES}
SERVER_COUNTRIES=${SERVER_COUNTRIES}
MEDIA_ROOT=${MEDIA_ROOT}

# --- PRIVACY MODULE ---
PIHOLE_PASSWORD=${PIHOLE_PASSWORD}
VAULTWARDEN_ADMIN_TOKEN=${VAULTWARDEN_ADMIN_TOKEN}
VAULTWARDEN_DOMAIN=https://vault.${MS_DOMAIN}
AUTHELIA_JWT_SECRET=${AUTHELIA_JWT_SECRET}
AUTHELIA_SESSION_SECRET=${AUTHELIA_SESSION_SECRET}
AUTHELIA_STORAGE_ENCRYPTION_KEY=${AUTHELIA_STORAGE_ENCRYPTION_KEY}

# --- CLOUD MODULE ---
NEXTCLOUD_DB_ROOT_PASSWORD=${NEXTCLOUD_DB_ROOT_PASSWORD}
NEXTCLOUD_DB_PASSWORD=${NEXTCLOUD_DB_PASSWORD}

# --- VPN ACCESS MODULE ---
WG_PASSWORD_HASH=${WG_PASSWORD_HASH}

# --- OPTIONAL ---
NOTIFIARR_API_KEY=
ENVEOF

chmod 600 "${MS_ROOT}/.env"
log_ok "Configuration saved to ${MS_ROOT}/.env"

# --- Save credentials to a secure file ---

CREDS_FILE="${MS_ROOT}/state/initial-credentials.txt"
{
    echo "================================================"
    echo "  MegaStack Credentials - SAVE THESE SECURELY!"
    echo "  Generated: $(date)"
    echo "  Delete this file after saving your passwords."
    echo "================================================"
    echo ""
    echo "Dashboard: https://${MS_DOMAIN}"
    echo "Password:  ${ADMIN_PASSWORD}"
    echo ""
    if echo "${SELECTED_MODULES}" | grep -q "privacy"; then
        echo "Pi-hole Admin: https://pihole.${MS_DOMAIN}/admin"
        echo "Password: ${PIHOLE_PASSWORD}"
        echo ""
    fi
    if echo "${SELECTED_MODULES}" | grep -q "vpn"; then
        echo "WireGuard VPN UI: https://vpn.${MS_DOMAIN}"
        echo "Password: ${WG_PASSWORD}"
        echo ""
    fi
} > "${CREDS_FILE}"
chmod 600 "${CREDS_FILE}"

# --- Generate Homepage Config ---

if [[ -f "${MS_ROOT}/templates/homepage-services.yml.tmpl" ]]; then
    mkdir -p "${MS_ROOT}/modules/core/config/homepage"
    echo "# Auto-generated by MegaStack setup" > "${MS_ROOT}/modules/core/config/homepage/services.yaml"
    echo "# Homepage will auto-discover services via Docker labels" >> "${MS_ROOT}/modules/core/config/homepage/services.yaml"
fi

# --- Create Media Directories ---

log_info "Creating media directories..."
mkdir -p "${MEDIA_ROOT}"/{downloads,movies,tv,music}
log_ok "Media directories created at ${MEDIA_ROOT}"

# --- Deploy ---

if tui_yesno "Deploy" "Configuration complete! Deploy MegaStack now?"; then
    log_info "Deploying MegaStack..."
    echo ""
    "${MS_ROOT}/megastack" up
else
    log_info "Setup complete. Run 'megastack up' when ready to deploy."
fi

# --- Summary ---

echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}  MegaStack Setup Complete!${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""
echo -e "  ${BOLD}Your credentials have been saved to:${NC}"
echo -e "  ${CREDS_FILE}"
echo ""
echo -e "  ${YELLOW}Read that file, save the passwords somewhere safe,${NC}"
echo -e "  ${YELLOW}then delete it: rm ${CREDS_FILE}${NC}"
echo ""
echo -e "  ${BOLD}Dashboard:${NC} https://${MS_DOMAIN}"
echo -e "  ${BOLD}CLI:${NC} megastack status | megastack help"
echo ""

# Log install
mkdir -p "${MS_ROOT}/state"
echo "[$(date)] Setup completed. Modules: core dashboard media ${SELECTED_MODULES}" >> "${MS_ROOT}/state/install.log"
