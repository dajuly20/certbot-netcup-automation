# Certbot-Netcup Certificate Automation

Automated SSL/TLS certificate renewal for multiple domains using Netcup DNS-01 challenge with Let's Encrypt.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
  - [Quick Install (Recommended)](#quick-install-recommended)
  - [Manual Setup](#manual-setup)
  - [Step-by-Step Manual Execution](#step-by-step-manual-execution)
- [Files Structure](#files-structure)
- [Managing Domains](#managing-domains)
- [Remote Host Certificate Sync](#remote-host-certificate-sync)
- [Usage Commands](#usage-commands)
- [Configuration Files](#configuration-files)
- [Makefile Commands Reference](#makefile-commands-reference)
- [How It Works](#how-it-works)
  - [Smart Renewal Process](#smart-renewal-process)
  - [Example Scenario](#example-scenario)
  - [Expiry Tracking Workflow](#expiry-tracking-workflow)
  - [What Happens During Automatic Runs](#what-happens-during-automatic-runs)
- [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)
- [Troubleshooting](#troubleshooting)
- [Testing](#testing)
- [Schedule](#schedule)
- [Git Workflow](#git-workflow)
- [Security Notes](#security-notes)
- [License](#license)
- [Support](#support)

## Overview

This tool automatically renews SSL certificates for all domains listed in `domains.conf` using:
- **Certbot** via Docker for certificate management
- **Netcup DNS API** for DNS-01 challenge validation
- **Systemd timer** for daily automated runs
- **Makefile** for easy installation and management

## Features

- 🚀 **One-command installation** with `make install`
- 🔧 **Interactive setup** for credentials and domains
- 🔄 **Configuration-based** domain management (no script editing)
- 🌐 **Automatic wildcard** certificate support (*.domain.tld)
- ⏰ **Smart renewal** - only renews certificates < X days from expiry
- 📊 **Expiry tracking** - automatically updates domains.conf with expiry dates
- ⚡ **Unified DNS propagation** timeout for all domains
- 🔁 **Automatic Apache reload** after renewal
- 🔄 **Remote host sync** - automatically push certificates to multiple servers
- 📝 **Comprehensive logging** with easy access
- 🔒 **Lock file** to prevent concurrent runs
- 🐙 **Git version control** for configuration tracking
- 📄 **YAML configuration** for easy customization

## Quick Start

```bash
# Clone the repository
git clone https://github.com/dajuly20/certbot-netcup-automation.git
cd certbot-netcup-automation

# See all available commands
make help

# Full installation (interactive)
make install

# Edit domains to manage
make edit-domains

# Test the setup
make renew-dryrun

# Check status
make status
```

## Files Structure

```
certbot-netcup-automation/
├── certbot-netcup-renew.sh      # Main renewal script
├── config.yaml                   # YAML configuration (domains + settings)
├── Makefile                      # Installation and management commands
├── scripts/
│   ├── setup-credentials-interactive.sh  # Interactive credentials wizard
│   ├── setup-systemd.sh                  # Systemd service configurator
│   ├── fix-permissions.sh                # Security permissions fixer
│   ├── edit-domains.sh                   # Interactive domain editor
│   ├── check-expiry.sh                   # Certificate expiry checker
│   ├── update-config-expiry.sh           # Updates config.yaml with expiry info
│   ├── sync-certs.sh                     # Remote certificate sync
│   └── parse-yaml.sh                     # YAML config parser
└── .gitignore                    # Protects sensitive files
```

## Installation

### Quick Install (Recommended)

```bash
make install
```

This will guide you through **all setup steps**:
1. **Setup API Credentials** - Interactive wizard for Netcup credentials
2. **Configure Domains** - Interactive domain editor
3. **Review Configuration** - Optional config.yaml editing (schedule, thresholds, etc.)
4. **Setup Systemd Service** - Configure automatic renewal timer
5. **Verify Installation** - Check that everything is configured correctly

The installer will show you a summary at the end with:
- Number of configured domains
- Renewal threshold setting
- Service schedule
- Next steps to test your setup

### Manual Setup

If you prefer to set up manually:

```bash
# Setup interactively (handles all steps)
make install

# Or manually:
# 1. Setup credentials
make setup-credentials
# 2. Edit domains
make edit-domains
# 3. Review/edit config.yaml
nano config.yaml
```

### Step-by-Step Manual Execution

Want to understand exactly what happens? Here's the complete manual walkthrough:

#### Step 1: Setup Netcup API Credentials

```bash
make setup-credentials
# OR manually:
sudo ./scripts/setup-credentials-interactive.sh
```

**What happens:**
- Opens an interactive wizard (uses whiptail/dialog if available)
- Asks for your Netcup Customer ID, API Key, and API Password
- Creates `/var/lib/letsencrypt/netcup_credentials.ini`
- Sets secure permissions (600, root:root)

**Where to get credentials:**
1. Log in to https://ccp.netcup.net
2. Go to: Master Data → API
3. Create a new API key
4. Copy: Customer ID, API Key, API Password

#### Step 2: Configure Your Domains

```bash
make edit-domains
# OR manually:
./scripts/edit-domains.sh
# OR edit directly:
nano config.yaml
```

**What happens:**
- Opens interactive menu showing current domains with expiry status
- You can add/remove domains directly in config.yaml
- Each domain automatically gets:
  - Base domain certificate (e.g., `example.com`)
  - Wildcard certificate (e.g., `*.example.com`)
  - Expiry tracking fields (updated by `make check-expiry`)

**Interactive menu:**
```
1) Add a new domain
2) Remove a domain
3) Edit config.yaml manually
4) Show all domains with details
5) OK - Keep as is (Exit)
```

#### Step 3: Review/Edit Configuration

```bash
nano config.yaml
```

**What happens:**
- Opens `config.yaml` in your editor
- Key settings to review:
  - `renew_days_before: 30` - When to renew (default: 30 days before expiry)
  - `dns_propagation_timeout: 1800` - DNS wait time (30 minutes)
  - `email: admin@julianw.de` - Your notification email
  - `staging: false` - Set to `true` for testing

**Example config.yaml:**
```yaml
renewal:
  renew_days_before: 30
  dns_propagation_timeout: 1800
  email: admin@julianw.de
  staging: false
```

**Key settings to review:**
- `renew_days_before: 10` - When to renew (days before expiry)
- `dns_propagation_timeout: 1800` - DNS wait time (30 minutes)
- `email: your@email.com` - Your notification email
- `staging: false` - Set to `true` for testing
- `systemd.schedule: "03:30"` - When to run automatic checks (daily at 3:30 AM)

#### Step 4: Test Your Setup

```bash
make renew-dryrun
# OR manually:
sudo systemctl start certbot-netcup.service
```

**What happens (takes ~30-60 minutes):**
1. Checks if Docker is running
2. Verifies credentials file exists
3. Reads domains from `domains.conf`
4. Checks expiry dates of existing certificates
5. Filters domains that need renewal (< X days)
6. Runs Docker container with certbot
7. For each domain:
   - Creates DNS TXT records via Netcup API
   - Waits for DNS propagation (1800s)
   - Let's Encrypt validates domain ownership
   - Issues/renews certificate
8. Reloads Apache to use new certificates
9. Logs everything to `/var/log/certbot-netcup.log`

**Monitor progress:**
```bash
# In another terminal:
tail -f /var/log/certbot-netcup.log
```

#### Step 5: Check Results

```bash
# Check expiry dates (and update domains.conf)
make check-expiry

# View service status
make status

# See recent logs
make logs

# List all certificates
make list-certs
```

## Managing Domains

### Add/Remove Domains Interactively

```bash
make edit-domains
```

This opens an interactive menu where you can:
- Add new domains
- Remove (comment out) domains
- Edit the config file directly
- View all configured domains

### Manual Domain Configuration

Edit `domains.conf` and add your domains (one per line):
```
example.com
another-domain.de
```

Each domain will automatically get both:
- Base domain certificate (`example.com`)
- Wildcard certificate (`*.example.com`)

## Remote Host Certificate Sync

Automatically push certificates to remote servers after renewal. This is useful for multi-server setups where you want to centrally manage certificates.

### Requirements

- Passwordless root SSH access to remote hosts
- Remote hosts must have `/etc/letsencrypt/` directory (will be created automatically)
- `rsync` installed on the local machine

### Setup Remote Host Sync

#### 1. Add a Remote Host

```bash
make add-remote-host
```

This will:
- Prompt for hostname/IP and SSH user
- Test SSH connectivity
- Set up passwordless SSH if needed (via `ssh-copy-id`)
- Add the host to `config.yaml`
- Enable remote sync automatically

#### 2. List Configured Remote Hosts

```bash
make list-remote-hosts
```

#### 3. Manual Certificate Sync

To manually sync certificates to all configured hosts:

```bash
make sync-certs
```

### Configuration

Remote host settings are in `config.yaml`:

```yaml
remote_hosts:
  enabled: true  # Set to true to enable syncing

  hosts:
    - hostname: server1.example.com
      user: root

    - hostname: 192.168.1.100
      user: root

  sync:
    source_path: /etc/letsencrypt/
    destination_path: /etc/letsencrypt/
    rsync_options: "-avz --delete"
    reload_remote_apache: true  # Reload Apache on remote hosts after sync
```

### How It Works

1. After successful certificate renewal, the script checks if remote sync is enabled
2. For each configured host:
   - Verifies SSH access
   - Creates destination directory if needed
   - Syncs `/etc/letsencrypt/` using rsync
   - Optionally reloads Apache on the remote host
3. Logs all operations to `/var/log/certbot-netcup.log`

### Manual SSH Setup

If `make add-remote-host` doesn't work, manually set up SSH access:

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096

# Copy key to remote host
ssh-copy-id root@remote-host.example.com

# Test connection
ssh root@remote-host.example.com 'exit 0'
```

Then manually add the host to `config.yaml` under the `remote_hosts` section.

## Usage Commands

### Test Certificate Renewal

Run a manual renewal (takes ~30 minutes):
```bash
make renew-dryrun  # Test/dry-run mode
make renew         # Production renewal
```

### Check Status

View service and timer status:
```bash
make status
```

### View Logs

Show recent logs:
```bash
make logs
```

Follow logs in real-time:
```bash
sudo tail -f /var/log/certbot-netcup.log
```

### Check Certificate Expiry

View expiry dates for all certificates with color-coded status:
```bash
make check-expiry
```

Shows:
- Days until expiry (negative if already expired)
- Expiry date
- Color-coded status:
  - 🟢 Green (OK): > 30 days
  - 🟡 Yellow (Soon): < 30 days
  - 🔴 Red (URGENT): < 7 days
- Missing certificates for configured domains
- **Automatically updates domains.conf with expiry information**

**Example Output:**
```
Certificate                Days Left       Expiry Date               Status
────────────────────────────────────────────────────────────────────────────────
lisamae.de               56 days         2026-06-10                ✓ OK
julianw.de               90 days         2026-07-14                ✓ OK
wiche.eu                 25 days         2026-05-20                ⚠️  Soon
```

After running, your `domains.conf` will be updated:
```bash
# lisamae.de - Expires: 2026-06-10 (56 days) ✓
lisamae.de
# julianw.de - Expires: 2026-07-14 (90 days) ✓
julianw.de
# wiche.eu - Expires: 2026-05-20 (25 days) ⚠️
wiche.eu
```

## Makefile Commands Reference

### Main Commands
| Command | Description |
|---------|-------------|
| `make install` | **Full guided installation** |
| `make renew-dryrun` | Test: show what would be renewed |
| `make renew` | Actually renew certificates now |
| `make status` | Show service status & next run |
| `make logs` | Show logs (tip: `tail -f` to follow) |
| `make check-expiry` | Check certificate expiry dates |

### Configuration
| Command | Description |
|---------|-------------|
| `make setup-credentials` | Reconfigure Netcup API credentials |
| `make edit-domains` | Edit domains interactively |
| `nano config.yaml` | Edit all settings (schedule, thresholds, etc.) |

### Remote Sync
| Command | Description |
|---------|-------------|
| `make add-remote-host` | Add a remote host for cert sync |
| `make list-remote-hosts` | List configured remote hosts |
| `make sync-certs` | Manually sync certs to remote hosts |

### Other
| Command | Description |
|---------|-------------|
| `make clean` | Remove lock files |
| `make uninstall` | Remove systemd configuration |

## Configuration Files

### config.yaml

Main configuration file with all settings:

```yaml
renewal:
  # Renew certificates when they have less than this many days until expiry
  renew_days_before: 30

  # DNS propagation timeout (in seconds)
  dns_propagation_timeout: 1800

  # Email for Let's Encrypt notifications
  email: admin@julianw.de

  # Use staging server for testing
  staging: false

paths:
  credentials: /var/lib/letsencrypt/netcup_credentials.ini
  log: /var/log/certbot-netcup.log
  domains: domains.conf

docker:
  image: coldfix/certbot-dns-netcup
```

### Domains in config.yaml

**NEW:** Domains are now managed directly in `config.yaml` with full expiry tracking:

```yaml
domains:
  - name: lisamae.de
    expires: 2026-06-18
    days_left: 63
    urgency: "✓ OK"
    last_checked: 2026-04-15T13:48:09

  - name: julianw.de
    expires: 2026-04-15
    days_left: 0
    urgency: "⚠️ URGENT"
    last_checked: 2026-04-15T13:48:09

  - name: wiche.eu
    expires: 2026-07-14
    days_left: 89
    urgency: "✓ OK"
    last_checked: 2026-04-15T13:48:09
```

**Urgency levels:**
- `✓ OK` - More than 30 days
- `⚠️ Soon` - Less than 30 days
- `⚠️ URGENT` - Less than 7 days
- `❌ EXPIRED` - Certificate expired
- `❌ No certificate` - Domain has no certificate yet
- `❓ Not checked yet` - Initial state before first check

**After running `make check-expiry`**, all fields are automatically updated!

## Configuration Options

Edit `config.yaml` to customize all settings:

| Option | Default | Description |
|--------|---------|-------------|
| `renew_days_before` | 30 | **Renew certificates when less than X days remain** |
| `dns_propagation_timeout` | 1800 | Seconds to wait for DNS changes |
| `email` | `admin@julianw.de` | Email for Let's Encrypt notifications |
| `staging` | false | Use staging server for testing |
| `credentials` | `/var/lib/letsencrypt/netcup_credentials.ini` | API credentials location |
| `log` | `/var/log/certbot-netcup.log` | Log file path |

## How It Works

### Smart Renewal Process

1. **Automatic Timer** triggers (default: 03:30, configurable in config.yaml)
2. **Script reads** `config.yaml` for settings (especially `renew_days_before`)
3. **Checks expiry** of all configured domains
4. **Filters domains** - only renews if < X days remaining
5. **Runs certbot** via Docker for filtered domains only
6. **Updates Apache** automatically after successful renewal
7. **Logs everything** to `/var/log/certbot-netcup.log`

### Example Scenario

**Configuration:**
```yaml
renewal:
  renew_days_before: 30
```

**Domains and Status:**
- `lisamae.de` - 56 days until expiry → **SKIPPED** (> 30 days)
- `julianw.de` - 90 days until expiry → **SKIPPED** (> 30 days)
- `wiche.eu` - 25 days until expiry → **RENEWED** (< 30 days)

Only `wiche.eu` will be renewed, saving time and API calls.

### Expiry Tracking Workflow

1. Run `make check-expiry`
2. Script checks all certificate expiry dates
3. Automatically updates `domains.conf` with comments:
   ```bash
   # wiche.eu - Expires: 2026-05-20 (25 days) ⚠️
   wiche.eu
   ```
4. Next renewal run will see this and renew accordingly

### What Happens During Automatic Runs

The systemd timer triggers (default: daily at 03:30, configurable):

#### Automatic Execution Flow:

```
03:30:00  Timer triggers certbot-netcup.service
03:30:01  ├─ Script starts, creates lock file
03:30:02  ├─ Reads config.yaml (renew_days_before: 30)
03:30:03  ├─ Reads domains.conf (5 domains found)
03:30:04  ├─ Checks certificate expiry dates:
          │   • lisamae.de: 56 days → SKIP (> 30)
          │   • julianw.de: 90 days → SKIP (> 30)
          │   • wiche.eu: 25 days → RENEW (< 30) ✓
          │   • fruta-no-es-postre.de: 20 days → RENEW (< 30) ✓
          │   • fruta-no-es-postre.eu: 18 days → RENEW (< 30) ✓
03:30:05  ├─ Docker starts: coldfix/certbot-dns-netcup
03:30:10  ├─ For wiche.eu:
          │   ├─ Creates TXT record: _acme-challenge.wiche.eu
          │   ├─ Waits 1800s for DNS propagation
04:00:10  │   ├─ Let's Encrypt validates
04:00:15  │   └─ Certificate issued ✓
04:00:16  ├─ For fruta-no-es-postre.de:
          │   ├─ Creates TXT record
          │   ├─ Waits 1800s
04:30:16  │   ├─ Let's Encrypt validates
04:30:20  │   └─ Certificate issued ✓
04:30:21  ├─ For fruta-no-es-postre.eu:
          │   ├─ Creates TXT record
          │   ├─ Waits 1800s
05:00:21  │   ├─ Let's Encrypt validates
05:00:25  │   └─ Certificate issued ✓
05:00:26  ├─ Reloads Apache: systemctl reload apache2 ✓
05:00:27  ├─ Removes lock file
05:00:28  └─ Logs: "Certificate renewal completed successfully"

Next run: Tomorrow at 03:30
```

**Key Points:**
- ⚡ **Smart filtering**: Only renews what's needed (saves ~1.5 hours if no renewals)
- 📝 **Everything logged**: Check `/var/log/certbot-netcup.log`
- 🔒 **Lock file**: Prevents overlapping runs
- 🔄 **Automatic Apache reload**: New certs immediately active
- 📧 **Email notifications**: Let's Encrypt sends expiry warnings to configured email

**If all certificates are > 30 days:**
```
03:30:00  Timer triggers
03:30:01  ├─ Script starts
03:30:04  ├─ Checks expiry: All > 30 days
03:30:05  ├─ Logs: "No domains need renewal at this time"
03:30:06  └─ Exits (runtime: 6 seconds)
```

**Check what happened:**
```bash
# View last run
journalctl -u certbot-netcup.service -n 50

# Check if any renewals happened
grep "WILL RENEW" /var/log/certbot-netcup.log | tail -20

# See next scheduled run
systemctl list-timers certbot-netcup.timer
```

## Frequently Asked Questions (FAQ)

### How do I know if it's working?

```bash
# Check service status
make status

# View recent logs
make logs

# Check certificate expiry dates
make check-expiry
```

### When will my certificates be renewed?

Certificates are renewed when they have **less than 30 days** until expiry (configurable in `config.yaml`).

Check when yours will be renewed:
```bash
make check-expiry
```

### What if I want to renew NOW regardless of expiry?

The script respects certbot's `--keep-until-expiring` flag. To force renewal:
1. Temporarily set `renew_days_before: 90` in `config.yaml`
2. Run `make renew-dryrun`
3. Change it back to `30` afterwards

Or use certbot directly:
```bash
sudo certbot renew --force-renewal
```

### How do I add a new domain?

```bash
make edit-domains
# Add your domain in the interactive menu
# Then run:
make renew-dryrun
```

### Can I test without affecting production?

Yes! Edit `config.yaml` and set:
```yaml
staging: true
```

Run `make renew-dryrun`, then check it worked. Set back to `false` for production.

### How long does renewal take?

- Per domain: ~30 minutes (DNS propagation timeout)
- 5 domains: ~2.5 hours
- 0 domains (all fresh): ~5 seconds

### Where are the certificates stored?

```bash
/etc/letsencrypt/live/yourdomain.com/fullchain.pem  # Certificate
/etc/letsencrypt/live/yourdomain.com/privkey.pem    # Private key
```

### How do I view logs?

```bash
make logs                                     # Recent logs
sudo tail -f /var/log/certbot-netcup.log     # Follow in real-time
journalctl -u certbot-netcup.service -n 100  # Systemd logs
```

## Troubleshooting

### Certificate Renewal Fails

Check the log file:
```bash
tail -100 /var/log/certbot-netcup.log
```

Common issues:
- **DNS propagation timeout too short**: Increase `DNS_PROPAGATION_TIMEOUT` in `config.sh`
- **Invalid credentials**: Verify `/var/lib/letsencrypt/netcup_credentials.ini`
- **Domain not on Netcup DNS**: Ensure domain uses Netcup nameservers

### Lock File Issues

If script won't run due to stale lock:
```bash
sudo rm /var/run/certbot-netcup.lock
```

### Apache Reload Fails

Manually reload Apache:
```bash
sudo systemctl reload apache2
```

### View Certificate Expiry

Check when certificates expire:
```bash
sudo certbot certificates
```

## Testing

To test without affecting production certificates:

1. Edit `config.sh` and set `CERTBOT_STAGING=true`
2. Run the script manually
3. Check logs for success
4. Set `CERTBOT_STAGING=false` when ready for production

## Schedule

The renewal runs automatically via systemd timer. The schedule is configurable in `config.yaml`:

```yaml
systemd:
  schedule: "03:30"  # Daily at 3:30 AM (default)
```

You can change this to any valid systemd timer format:
- `"03:30"` - Daily at 3:30 AM
- `"Mon 02:00"` - Mondays at 2 AM
- `"*:0/15"` - Every 15 minutes

After changing, run `make install` to apply the new schedule.

## Git Workflow

Track your configuration changes:

```bash
cd /home/julian/certbot-netcup-automation
git add domains.conf config.sh
git commit -m "Added new domain"
git log
```

## Security Notes

- Never commit credentials files (protected by `.gitignore`)
- Keep credentials file permissions at `600`
- Review logs regularly for unauthorized renewal attempts
- Consider using a dedicated email for Let's Encrypt notifications

## License

This project is for personal use on julianw.de infrastructure.

## Support

Check logs first, then review:
- [Certbot Documentation](https://certbot.eff.org/docs/)
- [Netcup DNS API](https://ccp.netcup.net/run/webservice/servers/endpoint.php)
- [Let's Encrypt Community](https://community.letsencrypt.org/)
