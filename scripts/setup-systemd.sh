#!/bin/bash
#
# Setup script to update systemd service configuration
# Run this with: sudo ./setup-systemd.sh
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source YAML parser and load config
source "${SCRIPT_DIR}/scripts/parse-yaml.sh"
parse_config "${SCRIPT_DIR}/config.yaml"

SCRIPT_PATH="${SCRIPT_DIR}/certbot-netcup-renew.sh"
SERVICE_OVERRIDE_DIR="/etc/systemd/system/certbot-netcup.service.d"
SERVICE_OVERRIDE_FILE="${SERVICE_OVERRIDE_DIR}/override.conf"
TIMER_OVERRIDE_DIR="/etc/systemd/system/certbot-netcup.timer.d"
TIMER_OVERRIDE_FILE="${TIMER_OVERRIDE_DIR}/override.conf"

echo "Updating systemd service configuration..."

# Create override directories if they don't exist
mkdir -p "${SERVICE_OVERRIDE_DIR}"
mkdir -p "${TIMER_OVERRIDE_DIR}"

# Write service override configuration
cat > "${SERVICE_OVERRIDE_FILE}" << EOF
### Updated by setup-systemd.sh
[Service]
User=root
ExecStart=
ExecStart=${SCRIPT_PATH}
StandardOutput=append:/var/log/certbot-netcup.log
StandardError=append:/var/log/certbot-netcup.log
EOF

echo "✓ Service override written to ${SERVICE_OVERRIDE_FILE}"

# Write timer override configuration
cat > "${TIMER_OVERRIDE_FILE}" << EOF
### Updated by setup-systemd.sh
### Schedule configured in config.yaml (systemd.schedule)
[Timer]
OnCalendar=
OnCalendar=${SYSTEMD_SCHEDULE}
Persistent=true
EOF

echo "✓ Timer override written to ${TIMER_OVERRIDE_FILE}"
echo "✓ Timer schedule set to: ${SYSTEMD_SCHEDULE}"

# Reload systemd
systemctl daemon-reload
echo "✓ Systemd daemon reloaded"

# Enable and start timer
systemctl enable certbot-netcup.timer
systemctl restart certbot-netcup.timer
echo "✓ Timer enabled and restarted"

# Check service status
systemctl status certbot-netcup.service --no-pager || true

echo ""
echo "=== Setup Complete ==="
echo "Service: ${SCRIPT_PATH}"
echo "Schedule: ${SYSTEMD_SCHEDULE} (configured in config.yaml)"
echo ""
echo "Next scheduled run:"
systemctl list-timers certbot-netcup.timer --no-pager
echo ""
echo "To test manually, run:"
echo "  make renew-dryrun  (shows what would be renewed)"
echo "  make renew         (actually renews certificates)"
