#!/bin/bash
#
# Certbot-Netcup Automation - Global Configuration
#

# DNS propagation timeout (in seconds)
# How long to wait for DNS changes to propagate before validating
# Default: 1800 (30 minutes) - works for most domains
DNS_PROPAGATION_TIMEOUT=1800

# Credentials file location
# This file contains your Netcup API credentials
CREDENTIALS_FILE="/var/lib/letsencrypt/netcup_credentials.ini"

# Log file location
LOG_FILE="/var/log/certbot-netcup.log"

# Lock file to prevent concurrent runs
LOCK_FILE="/var/run/certbot-netcup.lock"

# Docker image to use for certbot
DOCKER_IMAGE="coldfix/certbot-dns-netcup"

# Certbot options
CERTBOT_EMAIL="admin@julianw.de"  # Email for Let's Encrypt notifications
CERTBOT_STAGING=false              # Set to true for testing (uses LE staging server)

# Directory containing this config and domains.conf
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Domains configuration file
DOMAINS_FILE="${SCRIPT_DIR}/domains.conf"

# Apache reload command (tried in order)
APACHE_RELOAD_CMDS=(
    "systemctl reload apache2"
    "service apache2 reload"
    "apachectl graceful"
)
