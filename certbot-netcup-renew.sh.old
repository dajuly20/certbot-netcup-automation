#!/bin/bash
#
# Certbot-Netcup Certificate Renewal Script
# Automatically renews SSL certificates for domains listed in domains.conf
# using Netcup DNS-01 challenge via Docker
#

set -e  # Exit on error

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S%z')
    echo "${timestamp} [certbot-netcup-renew.sh] $*" | tee -a "${LOG_FILE}"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    cleanup
    exit 1
}

# Cleanup function
cleanup() {
    if [ -f "${LOCK_FILE}" ]; then
        rm -f "${LOCK_FILE}"
        log "Lock file removed"
    fi
}

# Trap errors and interrupts
trap cleanup EXIT INT TERM

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error_exit "This script must be run as root"
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    error_exit "Docker is not installed or not in PATH"
fi

# Check if Docker daemon is running
if ! docker ps &> /dev/null; then
    error_exit "Docker daemon is not running"
fi

# Check for lock file (prevent concurrent runs)
if [ -f "${LOCK_FILE}" ]; then
    error_exit "Another instance is already running (lock file exists: ${LOCK_FILE})"
fi

# Create lock file
touch "${LOCK_FILE}" || error_exit "Cannot create lock file"
log "Lock file created"

# Check if credentials file exists
if [ ! -f "${CREDENTIALS_FILE}" ]; then
    error_exit "Credentials file not found: ${CREDENTIALS_FILE}"
fi

# Check if domains file exists
if [ ! -f "${DOMAINS_FILE}" ]; then
    error_exit "Domains configuration file not found: ${DOMAINS_FILE}"
fi

# Read domains from config file (skip comments and empty lines)
DOMAINS=()
while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Trim whitespace
    domain=$(echo "$line" | xargs)

    if [ -n "$domain" ]; then
        DOMAINS+=("$domain")
    fi
done < "${DOMAINS_FILE}"

# Check if we have any domains
if [ ${#DOMAINS[@]} -eq 0 ]; then
    error_exit "No domains found in ${DOMAINS_FILE}"
fi

log "Found ${#DOMAINS[@]} domains to process"

# Build certbot domain arguments
DOMAIN_ARGS=""
for domain in "${DOMAINS[@]}"; do
    log "Adding domain: ${domain} (with wildcard)"
    DOMAIN_ARGS="${DOMAIN_ARGS} -d ${domain} -d *.${domain}"
done

# Determine staging flag
STAGING_FLAG=""
if [ "${CERTBOT_STAGING}" = true ]; then
    STAGING_FLAG="--staging"
    log "WARNING: Using Let's Encrypt STAGING server (test mode)"
fi

# Log the operation
log "==== Starting certificate renewal ===="
log "Domains: ${DOMAINS[*]}"
log "DNS Propagation Timeout: ${DNS_PROPAGATION_TIMEOUT}s"
log "Docker Image: ${DOCKER_IMAGE}"

# Run certbot via Docker
log "Starting certbot Docker container..."

docker run --rm \
    -v /etc/letsencrypt:/etc/letsencrypt \
    -v /var/lib/letsencrypt:/var/lib/letsencrypt \
    -v /var/log/letsencrypt:/var/log/letsencrypt \
    "${DOCKER_IMAGE}" \
    certbot certonly \
    --non-interactive \
    --agree-tos \
    --email "${CERTBOT_EMAIL}" \
    --authenticator dns-netcup \
    --dns-netcup-credentials "${CREDENTIALS_FILE}" \
    --dns-netcup-propagation-seconds ${DNS_PROPAGATION_TIMEOUT} \
    --keep-until-expiring \
    --expand \
    ${STAGING_FLAG} \
    ${DOMAIN_ARGS} 2>&1 | tee -a "${LOG_FILE}"

# Check Docker exit status
DOCKER_EXIT_CODE=${PIPESTATUS[0]}
if [ ${DOCKER_EXIT_CODE} -ne 0 ]; then
    error_exit "Certbot failed with exit code ${DOCKER_EXIT_CODE}"
fi

log "Certificates successfully renewed/checked"

# Reload Apache
log "Reloading Apache..."
APACHE_RELOADED=false

for reload_cmd in "${APACHE_RELOAD_CMDS[@]}"; do
    log "Trying: ${reload_cmd}"
    if ${reload_cmd} >> "${LOG_FILE}" 2>&1; then
        log "Apache successfully reloaded via: ${reload_cmd}"
        APACHE_RELOADED=true
        break
    fi
done

if [ "${APACHE_RELOADED}" = false ]; then
    log "WARNING: Could not reload Apache automatically. Please reload manually."
else
    log "==== Certificate renewal completed successfully ===="
fi

exit 0
