# MegaStack Installation Guide

Step-by-step instructions to install MegaStack on a fresh server.

---

## Prerequisites

Before you start, you need:

- **A server** running **Ubuntu 22.04+** or **Debian 12+** — this can be a VPS, a spare PC, a NUC, or any always-on machine
  - Minimum: 4GB RAM, 2 vCPU, 40GB disk
  - Recommended: 8GB RAM, 4 vCPU (if enabling all modules)
- **Root or sudo access**
- **An SSH client** (Terminal on Mac/Linux, Windows Terminal on Windows) — not needed if installing on your own machine
- **A VPN subscription** (NordVPN, ProtonVPN, Surfshark, Mullvad, or any Gluetun-supported provider)
- **A domain name** (optional — not needed if using Tailscale for access)

---

## Step 1: Connect to Your Server

Open your terminal and SSH into your server:

```bash
ssh root@YOUR_SERVER_IP
```

If you use a non-root user with sudo:

```bash
ssh youruser@YOUR_SERVER_IP
```

---

## Step 2: Install MegaStack

### Option A: Quick Install (Recommended)

Run the one-liner installer:

```bash
curl -sSL https://get.megastack.app/install.sh | sudo bash
```

This automatically:
1. Installs Docker and required system packages
2. Downloads MegaStack to `/opt/megastack`
3. Configures the firewall (ports 22, 80, 443, 51820/udp)
4. Launches the setup wizard

### Option B: Manual Install

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Clone the repository
git clone https://github.com/tomsparkreview/arr-megastack /opt/megastack
cd /opt/megastack

# Install dashboard dependencies
cd dashboard && npm install --production && cd ..

# Make the CLI executable and link it
chmod +x megastack
ln -sf /opt/megastack/megastack /usr/local/bin/megastack

# Run the setup wizard
sudo megastack install
```

---

## Step 3: Setup Wizard

The interactive wizard walks you through configuration. Here's what each screen asks:

### 3.1 Server Address

Enter your server's **IP address** or **domain name**.

- If you don't have a domain yet, use your VPS IP address (e.g., `203.0.113.42`)
- If you have a domain, enter it (e.g., `myserver.example.com`)

### 3.2 Timezone

Enter your timezone in `Continent/City` format:

| Region | Timezone |
|--------|----------|
| US Eastern | `America/New_York` |
| US Central | `America/Chicago` |
| US Pacific | `America/Los_Angeles` |
| UK | `Europe/London` |
| Central Europe | `Europe/Berlin` |
| Japan | `Asia/Tokyo` |
| Australia | `Australia/Sydney` |

### 3.3 VPN Provider

Select your VPN provider from the list. MegaStack routes all download traffic through this VPN.

Supported providers: NordVPN, ProtonVPN, Surfshark, Mullvad, and [many more](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers).

### 3.4 VPN Credentials

**For OpenVPN:** Enter your VPN service username and password.

Where to find these:
- **NordVPN:** Dashboard > Services > Service credentials
- **ProtonVPN:** Settings > OpenVPN/IKEv2 username
- **Surfshark:** Devices > Manual Setup > Credentials
- **Mullvad:** Your account number

**For WireGuard:** Enter your private key and address.

### 3.5 Media Storage

Where to store downloads, movies, and TV shows. Default: `/opt/megastack/modules/media/media`

Change this if you have an external drive or NAS mounted.

### 3.6 Dashboard Password

Set a password for the MegaStack web dashboard. Leave blank to auto-generate one.

### 3.7 Choose Optional Modules

Pick which features to enable:

| Module | What It Does | Default |
|--------|-------------|---------|
| **Privacy** | Pi-hole (ad blocking) + Vaultwarden (passwords) + Authelia (2FA) | ON |
| **Cloud** | Nextcloud (file sync, calendar, contacts) | OFF |
| **Monitoring** | Uptime Kuma (service alerts) | ON |
| **VPN Access** | WireGuard (remote access from anywhere) | OFF |
| **Files** | FileBrowser (web file manager) | OFF |

You can enable/disable these later from the dashboard or CLI.

### 3.8 Module Configuration

Depending on which modules you selected:

- **Privacy:** Set a Pi-hole admin password (or leave blank to auto-generate)
- **VPN Access:** Set a WireGuard web UI password (or leave blank to auto-generate)
- **Cloud:** Database passwords are auto-generated

### 3.9 Deploy

The wizard asks if you want to deploy immediately. Say **Yes** to start all services.

---

## Step 4: Verify Installation

Once deployment completes, open your browser and go to:

```
http://YOUR_SERVER_IP:8443
```

You should see the MegaStack login screen. Enter the password you set (or check the credentials file).

### Find Your Credentials

If you auto-generated passwords, they're saved here:

```bash
cat /opt/megastack/state/initial-credentials.txt
```

**Save these passwords somewhere safe, then delete the file:**

```bash
rm /opt/megastack/state/initial-credentials.txt
```

### Check Service Status

```bash
megastack status
```

All services should show as `running`. If anything is stopped, check the logs:

```bash
megastack logs ms-SERVICE_NAME
```

---

## Step 5: Set Up a Domain (Recommended)

A domain lets you access services via URLs like `watch.yourdomain.com` instead of `your-ip:8096`.

### 5.1 Point Your Domain

In your domain registrar's DNS settings, create an **A record**:

```
Type:  A
Name:  * (wildcard)
Value: YOUR_SERVER_IP
TTL:   300
```

Or create individual A records for each subdomain you want.

### 5.2 Configure Nginx Proxy Manager

1. Open NPM at `http://YOUR_SERVER_IP:81`
2. Default login: `admin@example.com` / `changeme` (change this immediately!)
3. Click **Proxy Hosts** > **Add Proxy Host**
4. For each service:
   - **Domain:** `watch.yourdomain.com`
   - **Forward Hostname:** `ms-jellyfin` (the container name)
   - **Forward Port:** `8096`
   - **SSL:** Enable, select Let's Encrypt, agree to ToS

### 5.3 Suggested Subdomains

| Service | Subdomain | Container | Port |
|---------|-----------|-----------|------|
| Jellyfin | `watch.` | ms-jellyfin | 8096 |
| Dashboard | `dash.` | ms-dashboard | 8443 |
| qBittorrent | `torrent.` | ms-qbittorrent | 8080 |
| Sonarr | `sonarr.` | ms-sonarr | 8989 |
| Radarr | `radarr.` | ms-radarr | 7878 |
| Prowlarr | `prowlarr.` | ms-prowlarr | 8181 |
| Vaultwarden | `vault.` | ms-vaultwarden | 8222 |
| Nextcloud | `cloud.` | ms-nextcloud | 8444 |
| Pi-hole | `pihole.` | ms-pihole | 8053 |
| Uptime Kuma | `status.` | ms-uptime-kuma | 3001 |
| WireGuard | `vpn.` | ms-wg-easy | 51821 |
| File Browser | `files.` | ms-filebrowser | 8086 |

---

## Step 6: Configure Your Media Stack

### 6.1 Add Indexers in Prowlarr

1. Open Prowlarr at `http://YOUR_SERVER_IP:8181`
2. Go to **Indexers** > **Add Indexer**
3. Search for and add your preferred indexers
4. Prowlarr automatically syncs indexers to Sonarr and Radarr

### 6.2 Configure Sonarr (TV Shows)

1. Open Sonarr at `http://YOUR_SERVER_IP:8989`
2. Go to **Settings** > **Download Clients** > Add qBittorrent:
   - Host: `ms-qbittorrent`
   - Port: `8080`
3. Set your quality profiles under **Settings** > **Profiles**
4. Add TV shows via **Series** > **Add New**

### 6.3 Configure Radarr (Movies)

1. Open Radarr at `http://YOUR_SERVER_IP:7878`
2. Same setup as Sonarr — add qBittorrent as download client
3. Add movies via **Movies** > **Add New**

### 6.4 Set Up Jellyfin

1. Open Jellyfin at `http://YOUR_SERVER_IP:8096`
2. Complete the first-run wizard
3. Add media libraries:
   - Movies: `/media/movies`
   - TV Shows: `/media/tv`
4. Install the Jellyfin app on your phone/TV

---

## Post-Install Checklist

- [ ] Change the NPM default password (`admin@example.com` / `changeme`)
- [ ] Save your credentials file and then delete it
- [ ] Set up your domain and SSL certificates
- [ ] Add indexers in Prowlarr
- [ ] Add qBittorrent as a download client in Sonarr and Radarr
- [ ] Complete the Jellyfin first-run wizard
- [ ] Set up the Jellyfin app on your devices
- [ ] If using Pi-hole: change your router's DNS to point to your server
- [ ] If using Vaultwarden: install the Bitwarden browser extension
- [ ] If using WireGuard: create client configs and scan QR codes
- [ ] Create your first backup: `megastack backup`

---

## CLI Quick Reference

```bash
megastack status          # See what's running
megastack up              # Start all enabled modules
megastack down            # Stop everything
megastack restart         # Restart all services
megastack restart media   # Restart just one module
megastack update          # Pull latest images
megastack logs ms-NAME    # View service logs
megastack modules         # List all modules
megastack enable privacy  # Enable a module
megastack disable cloud   # Disable a module
megastack backup          # Create a backup
megastack urls            # Show all service URLs
megastack help            # Full command list
```

---

## Troubleshooting

### Downloads aren't working

1. Check if Gluetun is running: `megastack logs ms-gluetun`
2. Look for "connected" or "error" messages
3. Common cause: wrong VPN credentials — update in Dashboard > Settings > VPN & Media
4. Verify your VPN subscription is active

### A service won't start

```bash
megastack logs ms-SERVICE_NAME
```

Look for lines with "error", "failed", or "permission denied".

### I forgot my dashboard password

```bash
# Clear the password hash — this triggers the "first run" setup
nano /opt/megastack/.env
# Delete the value after MS_ADMIN_PASSWORD_HASH=
# Save: Ctrl+X, Y, Enter
megastack restart dashboard
```

### Port already in use

If another service is using a port MegaStack needs:

```bash
# Find what's using the port
ss -tlnp | grep :PORT_NUMBER

# Stop the conflicting service, then restart MegaStack
megastack restart
```

### Checking firewall rules

```bash
sudo ufw status verbose
```

Expected open ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 51820/udp (WireGuard).

---

## Updating MegaStack

```bash
# Update all container images
megastack update

# Update just one module
megastack update media

# Update MegaStack itself (pull latest code)
cd /opt/megastack && git pull && megastack update
```

---

## Remote Access with Tailscale

If you're running MegaStack on a home machine, Tailscale lets you stream Jellyfin and manage your media stack from anywhere:

```bash
# Install Tailscale on your server
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Or enable the built-in Tailscale module:

```bash
megastack enable tailscale
megastack up
```

Once connected, access Jellyfin, Sonarr, Radarr, and all services from any device on your tailnet — no port forwarding, no domain, no SSL setup needed.

- **Share with family:** Use Tailscale node sharing to let others stream from your Jellyfin
- **Public access:** Use `tailscale funnel` to expose Jellyfin publicly
- **HTTPS:** Use `tailscale serve` for automatic HTTPS on your tailnet

**Note:** Tailscale is for remote access. Your download traffic still routes through Gluetun VPN for privacy — these serve different purposes.

---

## Uninstalling

```bash
megastack down
rm -rf /opt/megastack
rm -f /usr/local/bin/megastack
```
