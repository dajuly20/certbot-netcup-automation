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

SCRIPT_PATH="/home/julian/certbot-netcup-automation/certbot-netcup-renew.sh"
OVERRIDE_DIR="/etc/systemd/system/certbot-netcup.service.d"
OVERRIDE_FILE="${OVERRIDE_DIR}/override.conf"

echo "Updating systemd service configuration..."

# Create override directory if it doesn't exist
mkdir -p "${OVERRIDE_DIR}"

# Write new override configuration
cat > "${OVERRIDE_FILE}" << EOF
### Updated by setup-systemd.sh
[Service]
User=root
ExecStart=
ExecStart=${SCRIPT_PATH}
StandardOutput=append:/var/log/certbot-netcup.log
StandardError=append:/var/log/certbot-netcup.log
EOF

echo "✓ Override configuration written to ${OVERRIDE_FILE}"

# Reload systemd
systemctl daemon-reload
echo "✓ Systemd daemon reloaded"

# Check service status
systemctl status certbot-netcup.service --no-pager || true

echo ""
echo "=== Setup Complete ==="
echo "Service is now configured to use: ${SCRIPT_PATH}"
echo ""
echo "Next scheduled run:"
systemctl list-timers certbot-netcup.timer --no-pager
echo ""
echo "To test manually, run:"
echo "  sudo systemctl start certbot-netcup.service"
