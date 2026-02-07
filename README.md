# MegaStack

**Your complete self-hosted media + privacy server in one command.**

Created by **Tom Spark** | [youtube.com/@TomSparkReviews](https://youtube.com/@TomSparkReviews)

---

## What is MegaStack?

MegaStack turns a basic server into a complete private media streaming platform with built-in privacy tools. It bundles VPN-protected downloads, automatic media organization, a private streaming server, ad blocking, password management, cloud storage, and more into one easy-to-manage system — all controlled from a web dashboard.

Think of it like building your own private streaming platform and privacy-first home server: automatically find, download, and stream movies, TV shows, and music. Block ads across your network. Sync files between devices. Access everything securely from anywhere. All download traffic is routed through your VPN so your IP address is never exposed.

**No experience needed.** If you can copy-paste one command, you can run MegaStack.

---

## What You Get

| Module | What It Does | Services Included | RAM |
|--------|-------------|-------------------|-----|
| **Core** | The foundation — routes domains, manages containers, gives you a start page | Nginx Proxy Manager, Portainer, Homepage | ~300MB |
| **Dashboard** | Web UI to manage everything from your browser | MegaStack Dashboard | ~80MB |
| **Media** | VPN-protected downloads + private streaming to any device | Gluetun VPN, qBittorrent, Prowlarr, Sonarr, Radarr, Jellyfin | ~1.5GB |
| **Privacy** *(optional)* | Block ads, store passwords, add 2FA to your services | Pi-hole, Vaultwarden, Authelia | ~250MB |
| **Cloud** *(optional)* | Private file sync, calendar, and contacts (your own Google Drive) | Nextcloud, MariaDB, Redis | ~500MB |
| **Monitoring** *(optional)* | Get alerts when something goes down | Uptime Kuma | ~80MB |
| **VPN Access** *(optional)* | Access your server securely from anywhere | WireGuard (wg-easy) | ~30MB |
| **Files** *(optional)* | Web-based file manager for your server | FileBrowser | ~30MB |

**Optional media add-ons** (via Docker profiles): Lidarr (music), SABnzbd (Usenet), FlareSolverr (indexer bypass), Notifiarr (notifications).

**Total idle: ~2.4GB with everything** — runs great on a 4GB server with core + media, or an 8GB server with all modules.

---

## What You Need

- A **server** running **Ubuntu 22.04+** or **Debian 12+**
  - Minimum: 4GB RAM / 2 vCPU
  - Recommended: **8GB RAM / 4 vCPU** (with all optional modules)
- **Root or sudo access** to your server
- An **SSH client** to connect (Terminal on Mac/Linux, Windows Terminal on Windows)
- A **VPN subscription** (required — routes all download traffic through VPN)
- A **domain name** (optional but recommended for SSL/HTTPS)

### VPN Providers

MegaStack routes all download traffic through a commercial VPN via Gluetun. These providers are supported:

| Provider | Link | Deal |
|----------|------|------|
| **NordVPN** | [nordvpn.tomspark.tech](https://nordvpn.tomspark.tech) | 4 extra months FREE |
| **ProtonVPN** | [protonvpn.tomspark.tech](https://protonvpn.tomspark.tech) | 3 months FREE |
| **Surfshark** | [surfshark.tomspark.tech](https://surfshark.tomspark.tech) | 3 extra months FREE |

---

## Installation

### Quick Install

SSH into your server and run:

```bash
curl -sSL https://get.megastack.app/install.sh | sudo bash
```

This automatically:
1. Installs Docker and all required system packages
2. Downloads MegaStack to `/opt/megastack`
3. Sets up your firewall
4. Launches the setup wizard

### Setup Wizard

The wizard walks you through:

1. **Enter your domain/IP** — e.g., `myserver.example.com`
2. **Set your timezone** — e.g., `America/New_York`
3. **VPN credentials** — Your NordVPN/ProtonVPN/Surfshark login
4. **Dashboard password** — Password for the web dashboard
5. **Choose modules** — Pick optional features (privacy, cloud, monitoring, VPN access, files)
6. **Module settings** — Pi-hole password, WireGuard password, etc.

All security keys are generated automatically.

### Manual Install

```bash
git clone https://github.com/tomsparkreview/arr-megastack /opt/megastack
cd /opt/megastack
chmod +x megastack
sudo ./megastack install
```

---

## Using the Dashboard

Open `http://your-server-ip:8443` in your browser.

### Home

- **System gauges** — Live CPU, RAM, disk usage, and server uptime
- **Service cards** — Click any card to open that service's web UI
- **Running list** — See every container's status, CPU, and memory usage
- **Quick actions** — Restart or stop any service with one click

### Apps

- View all services with descriptions and tips
- Each card shows RAM usage and included services

### Logs

- Pick any service to see its live log output
- Real-time streaming via WebSocket

### Settings

- **General** — Timezone, domain
- **VPN & Media** — Update VPN credentials and media paths
- **Privacy** — Pi-hole, Vaultwarden, and Authelia secrets
- **Cloud** — Nextcloud database credentials
- **VPN Access** — WireGuard UI password hash
- **Backups** — Create and download backups

---

## CLI Reference

```bash
megastack help
```

### Common Commands

```bash
# See what's running
megastack status

# Start everything
megastack up

# Stop everything
megastack down

# Restart services
megastack restart

# Update all containers to latest versions
megastack update

# See live logs for a service
megastack logs ms-jellyfin

# Create a backup
megastack backup

# Show all service URLs
megastack urls
```

---

## Setting Up a Domain (Recommended)

Having a domain lets you access services via URLs like `watch.yourdomain.com` instead of `your-ip:8096`.

### Step 1: Point Your Domain

In your domain registrar, create an **A record**:

```
Type: A
Name: * (wildcard) or specific subdomains
Value: your-server-ip
```

### Step 2: Configure Nginx Proxy Manager

1. Open NPM at `http://your-server:81`
2. Default login: `admin@example.com` / `changeme`
3. Click **Proxy Hosts** > **Add Proxy Host**
4. For each service:
   - **Domain**: `watch.yourdomain.com`
   - **Forward Hostname**: `ms-jellyfin` (the container name)
   - **Forward Port**: `8096`
   - Enable **SSL** with Let's Encrypt (free!)

### Suggested Subdomains

| Service | Subdomain | Internal Port |
|---------|-----------|---------------|
| Jellyfin | `watch.yourdomain.com` | 8096 |
| Dashboard | `dash.yourdomain.com` | 8443 |
| qBittorrent | `torrent.yourdomain.com` | 8080 |
| Sonarr | `sonarr.yourdomain.com` | 8989 |
| Radarr | `radarr.yourdomain.com` | 7878 |
| Prowlarr | `prowlarr.yourdomain.com` | 8181 |
| Vaultwarden | `vault.yourdomain.com` | 8222 |
| Nextcloud | `cloud.yourdomain.com` | 8444 |
| Pi-hole | `pihole.yourdomain.com` | 8053 |
| Uptime Kuma | `status.yourdomain.com` | 3001 |
| WireGuard | `vpn.yourdomain.com` | 51821 |
| File Browser | `files.yourdomain.com` | 8086 |

---

## Backups

### From the Dashboard

1. Go to **Settings** > **Backups**
2. Click **Create Backup Now**
3. Download the backup file

### From the CLI

```bash
megastack backup
megastack restore /opt/megastack/backups/megastack-backup-20260206_120000.tar.gz
```

Backups include configuration and settings. **Media files are NOT included** (they're too large). Backups are automatically encrypted when `MS_BACKUP_KEY` is set (done during installation).

---

## Updating

```bash
# Update all services
megastack update

# Update just media containers
megastack update media
```

---

## Troubleshooting

### Downloads aren't working

1. Check if Gluetun (VPN tunnel) is running: look for `ms-gluetun` on the Home page
2. If it's stopped/red, check the logs: `megastack logs ms-gluetun`
3. Common issue: wrong VPN credentials. Update them in **Settings** > **VPN & Media**
4. Verify your VPN subscription is active

### A service won't start

1. Check its logs: `megastack logs ms-servicename`
2. Look for lines containing "error" or "failed"
3. Try restarting: click **Restart** in the dashboard or `docker restart ms-servicename`

### I forgot my dashboard password

```bash
nano /opt/megastack/.env
# Find MS_ADMIN_PASSWORD_HASH= and delete the value
# Save (Ctrl+X, Y, Enter)
megastack restart dashboard
```

---

## Architecture

```
                    ┌────────────────────────────────────┐
                    │     MegaStack Web Dashboard         │
                    │    (manage services, view logs,     │
                    │     toggle modules, backups)        │
                    │              :8443                   │
                    └──────────────┬─────────────────────┘
                                   │
                    ┌──────────────▼────────────────────┐
                    │      Nginx Proxy Manager           │
                    │      :80 / :443 / :81              │
                    │   (routes domains to services)     │
                    └──────────────┬────────────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          │                        │                        │
  ┌───────▼───────┐   ┌───────────▼──────────┐   ┌────────▼────────┐
  │  Media Stack   │   │  Privacy & Security   │   │ Optional Modules │
  │                │   │                       │   │                  │
  │  Gluetun VPN   │   │  Pi-hole (ad block)   │   │  Nextcloud       │
  │  ├ qBittorrent │   │  Vaultwarden (pwds)   │   │  Uptime Kuma     │
  │  ├ Prowlarr    │   │  Authelia (2FA/SSO)   │   │  WireGuard VPN   │
  │  ├ Sonarr      │   │                       │   │  File Browser    │
  │  ├ Radarr      │   └───────────────────────┘   │                  │
  │  └ Jellyfin    │                                └──────────────────┘
  └────────────────┘
```

---

## Security

- **Gluetun kill switch** — if the VPN drops, all download traffic stops immediately
- **All ports are localhost-only** (except 80/443) — services are only accessible through the reverse proxy
- **Auto-generated secrets** — all passwords, tokens, and encryption keys are created during setup
- **Encrypted backups** — backups are AES-256-GCM encrypted with a dedicated key
- **UFW firewall** — the installer automatically configures your firewall
- **No-new-privileges** — containers cannot escalate their permissions
- **Resource limits** — every container has CPU and memory caps

---

## Directory Structure

```
/opt/megastack/
├── megastack                   # CLI tool (symlinked to /usr/local/bin)
├── .env                        # Your configuration (auto-generated secrets)
├── state/
│   └── modules.conf            # Active modules
├── modules/
│   ├── core/                   # Nginx Proxy Manager + Portainer + Homepage
│   ├── dashboard/              # MegaStack Web Dashboard
│   ├── media/                  # Full ARR stack + Jellyfin
│   ├── privacy/                # Pi-hole + Vaultwarden + Authelia (optional)
│   ├── cloud/                  # Nextcloud + MariaDB + Redis (optional)
│   ├── monitoring/             # Uptime Kuma (optional)
│   ├── vpn/                    # WireGuard remote access (optional)
│   └── files/                  # FileBrowser (optional)
├── scripts/                    # Install and setup scripts
├── dashboard/                  # Dashboard web app source
└── backups/                    # Encrypted backup archives
```

---

## FAQ

**Q: How much does this cost?**
A: MegaStack is free and open source. You pay for the server (~$10-30/month), a VPN subscription (~$3-5/month), and optionally a domain (~$10/year).

**Q: Which VPN providers work?**
A: Any provider supported by [Gluetun](https://github.com/qdm12/gluetun-wiki). NordVPN, ProtonVPN, Surfshark, Mullvad, and many more.

**Q: Can I add more services?**
A: MegaStack includes 5 optional modules (privacy, cloud, monitoring, VPN access, file browser) that you can toggle on or off. Media add-ons like Lidarr, SABnzbd, FlareSolverr, and Notifiarr are also available. More can be added via Docker Compose.

**Q: Is this safe to run on the internet?**
A: Yes. All services are behind localhost-only ports and only accessible through the reverse proxy. The VPN kill switch ensures no traffic leaks.

**Q: How do I uninstall?**
A: `megastack down && rm -rf /opt/megastack`.

---

## License

All Rights Reserved — see [LICENSE](LICENSE) for details. No copying, modification, or commercial use without written permission.

---

**MegaStack** — Your media. Your server. Your rules.

Made with care by [Tom Spark](https://youtube.com/@TomSparkReviews)
