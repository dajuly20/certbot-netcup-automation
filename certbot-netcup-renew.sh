#!/bin/bash
#
# Certbot-Netcup Certificate Renewal Script
# Automatically renews SSL certificates for domains listed in domains.conf
# Only renews certificates that are within X days of expiry
# using Netcup DNS-01 challenge via Docker
#

# Show usage if --help or -h is passed
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    cat << 'EOF'
Certbot-Netcup Certificate Renewal Script

Usage: sudo ./certbot-netcup-renew.sh [OPTIONS]

This script automatically renews SSL certificates for domains configured in
domains.conf, but only if they are within the renewal threshold (configured
in config.yaml).

Options:
  -h, --help     Show this help message

Configuration:
  - Domains:     domains.conf
  - Settings:    config.yaml
  - Logs:        /var/log/certbot-netcup.log

Typically this script is run automatically via systemd timer.
For manual usage, use the Makefile instead:

  make test      Run manual renewal
  make status    Check service status
  make logs      View recent logs
  make help      Show all available commands

EOF
    exit 0
fi

set -e  # Exit on error

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source YAML parser and load config
source "${SCRIPT_DIR}/scripts/parse-yaml.sh"
parse_config "${SCRIPT_DIR}/config.yaml"
parse_apache_reload_commands "${SCRIPT_DIR}/config.yaml"

# Set domains file path
DOMAINS_FILE="${SCRIPT_DIR}/${DOMAINS_FILE_NAME}"

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

# Check if certbot is available (needed to check expiry)
if ! command -v certbot &> /dev/null; then
    log "WARNING: certbot not found in PATH - will renew all domains without expiry check"
    SKIP_EXPIRY_CHECK=true
else
    SKIP_EXPIRY_CHECK=false
fi

# Read domains from config file (skip comments and empty lines)
ALL_DOMAINS=()
while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Trim whitespace
    domain=$(echo "$line" | xargs)

    if [ -n "$domain" ]; then
        ALL_DOMAINS+=("$domain")
    fi
done < "${DOMAINS_FILE}"

# Check if we have any domains
if [ ${#ALL_DOMAINS[@]} -eq 0 ]; then
    error_exit "No domains found in ${DOMAINS_FILE}"
fi

log "Found ${#ALL_DOMAINS[@]} domains in configuration"

# Determine which domains need renewal
DOMAINS_TO_RENEW=()

if [ "$SKIP_EXPIRY_CHECK" = true ]; then
    log "Skipping expiry check - will renew all domains"
    DOMAINS_TO_RENEW=("${ALL_DOMAINS[@]}")
else
    log "Checking which domains need renewal (< ${RENEW_DAYS_BEFORE} days until expiry)"

    # Get certificate info from certbot
    CERT_INFO=$(certbot certificates 2>/dev/null || echo "")

    if [ -z "$CERT_INFO" ]; then
        log "No existing certificates found - will request certificates for all domains"
        DOMAINS_TO_RENEW=("${ALL_DOMAINS[@]}")
    else
        # Parse certificate expiry dates
        declare -A CERT_DAYS_LEFT

        while IFS='|' read -r cert_name days_left; do
            CERT_DAYS_LEFT["$cert_name"]="$days_left"
        done < <(echo "$CERT_INFO" | awk '
            /Certificate Name:/ { name=$3 }
            /Expiry Date:/ {
                # Extract date
                split($3, date_parts, "-")
                year=date_parts[1]
                month=date_parts[2]
                day=date_parts[3]

                # Calculate days until expiry
                expiry_epoch=mktime(year" "month" "day" 0 0 0")
                now_epoch=systime()
                days_left=int((expiry_epoch - now_epoch) / 86400)

                print name"|"days_left
            }
        ')

        # Check each domain
        for domain in "${ALL_DOMAINS[@]}"; do
            days_left="${CERT_DAYS_LEFT[$domain]}"

            if [ -z "$days_left" ]; then
                log "  ${domain}: No certificate found - will request new certificate"
                DOMAINS_TO_RENEW+=("$domain")
            elif [ "$days_left" -lt "$RENEW_DAYS_BEFORE" ]; then
                log "  ${domain}: ${days_left} days left - WILL RENEW"
                DOMAINS_TO_RENEW+=("$domain")
            else
                log "  ${domain}: ${days_left} days left - skipping (> ${RENEW_DAYS_BEFORE} days)"
            fi
        done
    fi
fi

# Check if any domains need renewal
if [ ${#DOMAINS_TO_RENEW[@]} -eq 0 ]; then
    log "No domains need renewal at this time"
    log "All certificates are valid for more than ${RENEW_DAYS_BEFORE} days"
    exit 0
fi

log "Will renew ${#DOMAINS_TO_RENEW[@]} domain(s): ${DOMAINS_TO_RENEW[*]}"

# Build certbot domain arguments
DOMAIN_ARGS=""
for domain in "${DOMAINS_TO_RENEW[@]}"; do
    log "Adding domain: ${domain} (with wildcard)"
    DOMAIN_ARGS="${DOMAIN_ARGS} -d ${domain} -d *.${domain}"
done

# Determine staging flag
STAGING_FLAG=""
if [ "${CERTBOT_STAGING}" = "true" ]; then
    STAGING_FLAG="--staging"
    log "WARNING: Using Let's Encrypt STAGING server (test mode)"
fi

# Log the operation
log "==== Starting certificate renewal ===="
log "Domains to renew: ${DOMAINS_TO_RENEW[*]}"
log "DNS Propagation Timeout: ${DNS_PROPAGATION_TIMEOUT}s"
log "Docker Image: ${DOCKER_IMAGE}"
log "Renew threshold: ${RENEW_DAYS_BEFORE} days"

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
