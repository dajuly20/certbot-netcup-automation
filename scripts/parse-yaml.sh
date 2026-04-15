#!/bin/bash
#
# Simple YAML parser for config.yaml
# Usage: source scripts/parse-yaml.sh && parse_config
#

parse_config() {
    local config_file="${1:-config.yaml}"

    if [ ! -f "$config_file" ]; then
        echo "ERROR: Config file not found: $config_file" >&2
        return 1
    fi

    # Parse YAML using sed/awk (simple approach, works for our flat structure)
    # More robust would be yq/jq but we want to avoid dependencies

    # Renewal settings
    RENEW_DAYS_BEFORE=$(grep -A1 "^renewal:" "$config_file" | grep "renew_days_before:" | sed 's/.*: *//')
    DNS_PROPAGATION_TIMEOUT=$(grep "dns_propagation_timeout:" "$config_file" | sed 's/.*: *//')
    CERTBOT_EMAIL=$(grep "email:" "$config_file" | sed 's/.*: *//')
    CERTBOT_STAGING=$(grep "staging:" "$config_file" | sed 's/.*: *//')

    # Paths
    CREDENTIALS_FILE=$(grep -A5 "^paths:" "$config_file" | grep "credentials:" | sed 's/.*: *//')
    LOG_FILE=$(grep -A5 "^paths:" "$config_file" | grep "log:" | sed 's/.*: *//')
    LOCK_FILE=$(grep -A5 "^paths:" "$config_file" | grep "lock:" | sed 's/.*: *//')
    DOMAINS_FILE_NAME=$(grep -A5 "^paths:" "$config_file" | grep "domains:" | sed 's/.*: *//')

    # Docker
    DOCKER_IMAGE=$(grep -A2 "^docker:" "$config_file" | grep "image:" | sed 's/.*: *//')

    # Set defaults if not found
    RENEW_DAYS_BEFORE=${RENEW_DAYS_BEFORE:-30}
    DNS_PROPAGATION_TIMEOUT=${DNS_PROPAGATION_TIMEOUT:-1800}
    CERTBOT_EMAIL=${CERTBOT_EMAIL:-admin@julianw.de}
    CERTBOT_STAGING=${CERTBOT_STAGING:-false}
    CREDENTIALS_FILE=${CREDENTIALS_FILE:-/var/lib/letsencrypt/netcup_credentials.ini}
    LOG_FILE=${LOG_FILE:-/var/log/certbot-netcup.log}
    LOCK_FILE=${LOCK_FILE:-/var/run/certbot-netcup.lock}
    DOCKER_IMAGE=${DOCKER_IMAGE:-coldfix/certbot-dns-netcup}

    # Export for use in scripts
    export RENEW_DAYS_BEFORE
    export DNS_PROPAGATION_TIMEOUT
    export CERTBOT_EMAIL
    export CERTBOT_STAGING
    export CREDENTIALS_FILE
    export LOG_FILE
    export LOCK_FILE
    export DOMAINS_FILE_NAME
    export DOCKER_IMAGE
}

# Parse Apache reload commands from YAML
parse_apache_reload_commands() {
    local config_file="${1:-config.yaml}"

    # Extract reload commands (lines after "reload_commands:")
    APACHE_RELOAD_CMDS=()
    while IFS= read -r line; do
        # Extract command after "- "
        cmd=$(echo "$line" | sed 's/^[[:space:]]*- //')
        if [ -n "$cmd" ]; then
            APACHE_RELOAD_CMDS+=("$cmd")
        fi
    done < <(grep -A10 "reload_commands:" "$config_file" | grep "^[[:space:]]*- ")

    export APACHE_RELOAD_CMDS
}

# Parse domains from YAML
parse_domains() {
    local config_file="${1:-config.yaml}"

    DOMAINS=()

    # Extract domain names from YAML
    while IFS= read -r line; do
        # Match lines like "  - name: example.com"
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
            domain="${BASH_REMATCH[1]}"
            DOMAINS+=("$domain")
        fi
    done < <(sed -n '/^domains:/,/^[a-z]/p' "$config_file" | grep "name:")

    export DOMAINS
}

# Get expiry data for a specific domain
get_domain_expiry() {
    local domain="$1"
    local config_file="${2:-config.yaml}"

    # Extract expiry data for specific domain
    local in_domain=false
    local expires=""
    local days_left=""

    while IFS= read -r line; do
        if [[ "$line" =~ name:[[:space:]]*$domain$ ]]; then
            in_domain=true
        elif [[ "$in_domain" == true ]]; then
            if [[ "$line" =~ expires:[[:space:]]*(.+)$ ]]; then
                expires="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ days_left:[[:space:]]*(.+)$ ]]; then
                days_left="${BASH_REMATCH[1]}"
                # Found both, we're done
                echo "${expires}|${days_left}"
                return
            elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]]; then
                # Next domain started, stop
                break
            fi
        fi
    done < <(sed -n '/^domains:/,/^[a-z]/p' "$config_file")

    echo "null|null"
}

