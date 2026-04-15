#!/bin/bash
#
# Fix permissions on credentials file for security
# Run this with: sudo ./fix-permissions.sh
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

CREDENTIALS_FILE="/var/lib/letsencrypt/netcup_credentials.ini"

if [ ! -f "${CREDENTIALS_FILE}" ]; then
    echo "ERROR: Credentials file not found: ${CREDENTIALS_FILE}"
    exit 1
fi

echo "Fixing permissions on ${CREDENTIALS_FILE}..."

# Show current permissions
echo "Current permissions:"
ls -la "${CREDENTIALS_FILE}"

# Fix permissions
chmod 600 "${CREDENTIALS_FILE}"
chown root:root "${CREDENTIALS_FILE}"

echo ""
echo "New permissions:"
ls -la "${CREDENTIALS_FILE}"

echo ""
echo "✓ Permissions fixed (now 600, owned by root:root)"
echo "✓ This resolves the 'Unsafe permissions' warning"
