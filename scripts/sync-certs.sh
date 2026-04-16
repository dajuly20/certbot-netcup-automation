#!/bin/bash
#
# Certificate Sync Script
# Syncs /etc/letsencrypt directory to remote hosts
#

# Source YAML parser and load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/scripts/parse-yaml.sh"
parse_config "${SCRIPT_DIR}/config.yaml"
parse_remote_hosts "${SCRIPT_DIR}/config.yaml"

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S%z')
    echo "${timestamp} [sync-certs] $*"
    if [ -n "${LOG_FILE}" ]; then
        echo "${timestamp} [sync-certs] $*" >> "${LOG_FILE}"
    fi
}

# Check SSH connectivity
check_ssh_access() {
    local host="$1"
    local user="$2"

    log "Checking SSH access to ${user}@${host}..."

    # Try to connect with timeout
    if timeout 10 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${user}@${host}" 'exit 0' 2>/dev/null; then
        log "  ✓ SSH access OK"
        return 0
    else
        log "  ✗ SSH access FAILED"
        log "  Please run: ssh-copy-id ${user}@${host}"
        return 1
    fi
}

# Sync certificates to remote host
sync_to_host() {
    local host="$1"
    local user="$2"
    local source="${REMOTE_SOURCE_PATH}"
    local destination="${REMOTE_DESTINATION_PATH}"
    local rsync_opts="${REMOTE_RSYNC_OPTIONS}"

    log "Syncing certificates to ${user}@${host}..."
    log "  Source: ${source}"
    log "  Destination: ${user}@${host}:${destination}"

    # Create destination directory if it doesn't exist
    log "  Ensuring destination directory exists..."
    if ! ssh -o BatchMode=yes "${user}@${host}" "mkdir -p ${destination}" 2>&1 | tee -a "${LOG_FILE}"; then
        log "  ✗ Failed to create destination directory"
        return 1
    fi

    # Sync with rsync
    log "  Starting rsync..."
    if rsync ${rsync_opts} -e "ssh -o BatchMode=yes" "${source}" "${user}@${host}:${destination%/*}/" 2>&1 | tee -a "${LOG_FILE}"; then
        log "  ✓ Sync completed successfully"

        # Reload Apache on remote host if enabled
        if [ "${REMOTE_RELOAD_APACHE}" = "true" ]; then
            log "  Reloading Apache on remote host..."
            if ssh -o BatchMode=yes "${user}@${host}" "systemctl reload apache2 || service apache2 reload || apachectl graceful" 2>&1 | tee -a "${LOG_FILE}"; then
                log "  ✓ Apache reloaded successfully"
            else
                log "  ⚠ Warning: Could not reload Apache on remote host"
            fi
        fi

        return 0
    else
        log "  ✗ Sync failed"
        return 1
    fi
}

# Main function
main() {
    log "==== Certificate Sync Starting ===="

    # Check if remote sync is enabled
    if [ "${REMOTE_SYNC_ENABLED}" != "true" ]; then
        log "Remote certificate sync is disabled in config.yaml"
        log "Set remote_hosts.enabled: true to enable"
        exit 0
    fi

    # Check if we have any hosts
    if [ ${#REMOTE_HOSTS[@]} -eq 0 ]; then
        log "No remote hosts configured in config.yaml"
        exit 0
    fi

    log "Found ${#REMOTE_HOSTS[@]} remote host(s)"

    # Track success/failure
    SUCCESS_COUNT=0
    FAILURE_COUNT=0
    FAILED_HOSTS=()

    # Process each host
    for host_entry in "${REMOTE_HOSTS[@]}"; do
        # Parse host entry (format: user@hostname)
        if [[ "$host_entry" =~ ^([^@]+)@(.+)$ ]]; then
            user="${BASH_REMATCH[1]}"
            host="${BASH_REMATCH[2]}"
        else
            log "Invalid host entry: ${host_entry}"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            FAILED_HOSTS+=("${host_entry}")
            continue
        fi

        log "Processing: ${user}@${host}"

        # Check SSH access
        if ! check_ssh_access "${host}" "${user}"; then
            log "Skipping ${host} due to SSH access failure"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            FAILED_HOSTS+=("${user}@${host}")
            continue
        fi

        # Sync certificates
        if sync_to_host "${host}" "${user}"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            FAILED_HOSTS+=("${user}@${host}")
        fi

        echo ""  # Blank line between hosts
    done

    # Summary
    log "==== Certificate Sync Complete ===="
    log "Successful: ${SUCCESS_COUNT}"
    log "Failed: ${FAILURE_COUNT}"

    if [ ${FAILURE_COUNT} -gt 0 ]; then
        log "Failed hosts:"
        for failed_host in "${FAILED_HOSTS[@]}"; do
            log "  - ${failed_host}"
        done
        exit 1
    fi

    exit 0
}

# Run main function
main "$@"
