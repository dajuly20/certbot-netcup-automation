# Certbot-Netcup Certificate Automation

Automated SSL/TLS certificate renewal for multiple domains using Netcup DNS-01 challenge with Let's Encrypt.

## Overview

This tool automatically renews SSL certificates for all domains listed in `domains.conf` using:
- **Certbot** via Docker for certificate management
- **Netcup DNS API** for DNS-01 challenge validation
- **Systemd timer** for daily automated runs

## Features

- Configuration-based domain management (no script editing needed)
- Automatic wildcard certificate support (*.domain.tld)
- Unified DNS propagation timeout for all domains
- Automatic Apache reload after renewal
- Comprehensive logging
- Lock file to prevent concurrent runs
- Git version control for configuration tracking

## Files

- `certbot-netcup-renew.sh` - Main renewal script
- `config.sh` - Global configuration settings
- `domains.conf` - List of domains to manage
- `.gitignore` - Protects sensitive files from being committed

## Setup

### 1. Credentials

Ensure your Netcup API credentials are configured in:
```
/var/lib/letsencrypt/netcup_credentials.ini
```

The file should contain:
```ini
dns_netcup_customer_id  = YOUR_CUSTOMER_ID
dns_netcup_api_key      = YOUR_API_KEY
dns_netcup_api_password = YOUR_API_PASSWORD
```

**Security**: Set proper permissions:
```bash
sudo chmod 600 /var/lib/letsencrypt/netcup_credentials.ini
sudo chown root:root /var/lib/letsencrypt/netcup_credentials.ini
```

### 2. Configure Domains

Edit `domains.conf` and add your domains (one per line):
```
example.com
another-domain.de
```

Each domain will automatically get both:
- Base domain certificate (`example.com`)
- Wildcard certificate (`*.example.com`)

### 3. Update Systemd Service

Update the systemd service to use the new script:
```bash
sudo systemctl edit certbot-netcup.service
```

Set the ExecStart to:
```ini
[Service]
ExecStart=/home/julian/certbot-netcup-automation/certbot-netcup-renew.sh
```

Reload systemd and restart timer:
```bash
sudo systemctl daemon-reload
sudo systemctl restart certbot-netcup.timer
```

## Usage

### Manual Run

Test the renewal process:
```bash
sudo /home/julian/certbot-netcup-automation/certbot-netcup-renew.sh
```

### Check Automatic Schedule

View timer status:
```bash
systemctl status certbot-netcup.timer
```

View next scheduled run:
```bash
systemctl list-timers certbot-netcup.timer
```

### View Logs

Real-time log monitoring:
```bash
tail -f /var/log/certbot-netcup.log
```

Recent renewal history:
```bash
journalctl -u certbot-netcup.service -n 50
```

## Configuration Options

Edit `config.sh` to customize:

| Option | Default | Description |
|--------|---------|-------------|
| `DNS_PROPAGATION_TIMEOUT` | 1800 | Seconds to wait for DNS changes |
| `CREDENTIALS_FILE` | `/var/lib/letsencrypt/netcup_credentials.ini` | API credentials location |
| `LOG_FILE` | `/var/log/certbot-netcup.log` | Log file path |
| `CERTBOT_EMAIL` | `admin@julianw.de` | Email for Let's Encrypt notifications |
| `CERTBOT_STAGING` | false | Use staging server for testing |

## Adding/Removing Domains

1. Edit `domains.conf`
2. Add or remove domain lines (or comment out with `#`)
3. Save the file
4. Commit changes: `git add domains.conf && git commit -m "Updated domains"`
5. Wait for next scheduled run, or run manually

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
