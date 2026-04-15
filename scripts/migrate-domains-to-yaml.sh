#!/bin/bash
#
# Migrate domains from domains.conf to config.yaml
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAINS_FILE="${SCRIPT_DIR}/domains.conf"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"

if [ ! -f "$DOMAINS_FILE" ]; then
    echo -e "${RED}Error: domains.conf not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Migrating domains from domains.conf to config.yaml...${NC}"
echo ""

# Read domains from domains.conf
DOMAINS_TO_MIGRATE=()
while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    domain=$(echo "$line" | xargs)
    if [ -n "$domain" ]; then
        DOMAINS_TO_MIGRATE+=("$domain")
        echo -e "  Found: ${domain}"
    fi
done < "$DOMAINS_FILE"

if [ ${#DOMAINS_TO_MIGRATE[@]} -eq 0 ]; then
    echo -e "${YELLOW}No domains found in domains.conf${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Will add ${#DOMAINS_TO_MIGRATE[@]} domains to config.yaml${NC}"
echo ""

# Backup config.yaml
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup-migration"

# Find the domains: section and add domains
TEMP_CONFIG=$(mktemp)
in_domains_section=false
domains_added=false

while IFS= read -r line || [ -n "$line" ]; do
    # Check if we're at the domains section
    if [[ "$line" =~ ^domains: ]]; then
        in_domains_section=true
        domains_added=true
        echo "$line" >> "$TEMP_CONFIG"

        # Add all domains
        for domain in "${DOMAINS_TO_MIGRATE[@]}"; do
            echo "  - name: $domain" >> "$TEMP_CONFIG"
            echo "    expires: null" >> "$TEMP_CONFIG"
            echo "    days_left: null" >> "$TEMP_CONFIG"
            echo "    urgency: \"❓ Not checked yet\"" >> "$TEMP_CONFIG"
            echo "    last_checked: null" >> "$TEMP_CONFIG"
            echo "" >> "$TEMP_CONFIG"
        done
        continue
    fi

    # If in domains section, skip until next top-level section
    if [[ "$in_domains_section" == true ]]; then
        if [[ "$line" =~ ^[a-z] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            in_domains_section=false
        else
            # Skip old domain entries
            continue
        fi
    fi

    echo "$line" >> "$TEMP_CONFIG"
done < "$CONFIG_FILE"

mv "$TEMP_CONFIG" "$CONFIG_FILE"

echo -e "${GREEN}✓ Migration complete!${NC}"
echo -e "${GREEN}✓ Backup saved to: ${CONFIG_FILE}.backup-migration${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Run: ${GREEN}make check-expiry${NC} to update expiry dates"
echo -e "  2. Rename domains.conf to domains.conf.old (it's no longer used)"
echo ""
