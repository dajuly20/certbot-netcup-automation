# Certbot-Netcup Certificate Automation

Automated SSL/TLS certificate renewal for multiple domains using Netcup DNS-01 challenge with Let's Encrypt.

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
make test

# Check status
make status
```

## Files Structure

```
certbot-netcup-automation/
├── certbot-netcup-renew.sh      # Main renewal script
├── config.yaml                   # YAML configuration (replaces config.sh)
├── domains.conf                  # List of domains (auto-annotated with expiry)
├── Makefile                      # Installation and management commands
├── scripts/
│   ├── setup-credentials-interactive.sh  # Interactive credentials wizard
│   ├── setup-systemd.sh                  # Systemd service configurator
│   ├── fix-permissions.sh                # Security permissions fixer
│   ├── edit-domains.sh                   # Interactive domain editor
│   ├── check-expiry.sh                   # Certificate expiry checker
│   ├── update-domains-expiry.sh          # Updates domains.conf with expiry info
│   └── parse-yaml.sh                     # YAML config parser
└── .gitignore                    # Protects sensitive files
```

## Installation

### Quick Install (Recommended)

```bash
make install
```

This will guide you through:
1. Setting up Netcup API credentials
2. Fixing file permissions
3. Configuring systemd service

### Manual Setup

If you prefer to set up manually:

```bash
# 1. Setup credentials interactively
make setup-credentials

# 2. Fix permissions on credentials file
make fix-permissions

# 3. Configure systemd service
make setup-systemd
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

## Usage Commands

### Test Certificate Renewal

Run a manual renewal (takes ~30 minutes):
```bash
make test
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
make logs-live
```

### List Active Domains

See which domains are configured:
```bash
make list-domains
```

### Verify Credentials

Check if credentials are properly configured:
```bash
make verify-credentials
```

### List Installed Certificates

See all certificates managed by certbot:
```bash
make list-certs
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

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make install` | Full installation (interactive setup) |
| `make setup-credentials` | Configure Netcup API credentials |
| `make edit-domains` | Interactive domain editor |
| `make fix-permissions` | Fix credentials file permissions |
| `make setup-systemd` | Configure systemd service |
| `make test` | Run manual certificate renewal |
| `make status` | Show service and timer status |
| `make logs` | Show recent logs |
| `make logs-live` | Follow logs in real-time |
| `make list-domains` | List configured domains |
| `make verify-credentials` | Check credentials configuration |
| `make list-certs` | Show all installed certificates |
| `make check-expiry` | Check certificate expiry dates with color-coded status |
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

### domains.conf

Simple text file with one domain per line. After running `make check-expiry`, it will be automatically annotated with expiry dates:

```bash
# Certbot-Netcup Domain Configuration
# Last expiry check: 2026-04-15 13:15:00

# lisamae.de - Expires: 2026-06-10 (56 days) ✓
lisamae.de
# julianw.de - Expires: 2026-07-14 (90 days) ✓
julianw.de
# wiche.eu - Expires: 2026-05-20 (35 days) ✓
wiche.eu
```

## Configuration Options (Deprecated)

**Note:** `config.sh` has been replaced by `config.yaml`. If you still have `config.sh`, it will be ignored.

Edit `config.yaml` to customize:

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

1. **Daily Timer** triggers at 03:30
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

The renewal runs **daily at 03:30** via systemd timer.

Certbot will only renew certificates within 30 days of expiration (Let's Encrypt default).

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
