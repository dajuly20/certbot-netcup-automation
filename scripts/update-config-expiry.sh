#!/bin/bash
#
# Update config.yaml with certificate expiry information
# Reads certificates from certbot and updates the domains section
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"
CONFIG_BACKUP="${CONFIG_FILE}.backup"

# Check if certbot is available
if ! command -v certbot &> /dev/null; then
    echo -e "${RED}Error: certbot not found${NC}"
    exit 1
fi

# Get certificate info
CERT_INFO=$(sudo certbot certificates 2>/dev/null)

if [ -z "$CERT_INFO" ]; then
    echo -e "${YELLOW}No certificates found - cannot update expiry info${NC}"
    exit 0
fi

# Create backup
cp "$CONFIG_FILE" "$CONFIG_BACKUP"

# Parse cert info into associative arrays
declare -A CERT_EXPIRY
declare -A CERT_DAYS

while IFS='|' read -r cert_name expiry days_left; do
    # Extract base domain (remove wildcard prefix if present)
    base_domain=$(echo "$cert_name" | sed 's/^\*\.//')
    CERT_EXPIRY["$base_domain"]="$expiry"
    CERT_DAYS["$base_domain"]="$days_left"
done < <(echo "$CERT_INFO" | awk '
    /Certificate Name:/ { name=$3 }
    /Expiry Date:/ {
        expiry=$3
        # Extract just the date
        split($3, date_parts, "-")
        year=date_parts[1]
        month=date_parts[2]
        day=date_parts[3]

        # Calculate days until expiry
        expiry_epoch=mktime(year" "month" "day" 0 0 0")
        now_epoch=systime()
        days_left=int((expiry_epoch - now_epoch) / 86400)

        print name"|"expiry"|"days_left
    }
')

# Create temporary file for new config
TEMP_CONFIG=$(mktemp)

# Process config.yaml
in_domains_section=false
in_domain_block=false
current_domain=""
timestamp=$(date -Iseconds)

while IFS= read -r line || [ -n "$line" ]; do
    # Check if we're entering domains section
    if [[ "$line" =~ ^domains: ]]; then
        in_domains_section=true
        echo "$line" >> "$TEMP_CONFIG"
        continue
    fi

    # Check if we're leaving domains section (next top-level key)
    if [[ "$in_domains_section" == true ]] && [[ "$line" =~ ^[a-z] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
        in_domains_section=false
    fi

    # If we're in the domains section
    if [[ "$in_domains_section" == true ]]; then
        # Check for domain name line
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
            current_domain="${BASH_REMATCH[1]}"
            in_domain_block=true
            echo "$line" >> "$TEMP_CONFIG"

            # Check if we have expiry info for this domain
            if [ -n "${CERT_EXPIRY[$current_domain]}" ]; then
                days="${CERT_DAYS[$current_domain]}"

                # Determine urgency status
                if [ "$days" -lt 0 ]; then
                    urgency="❌ EXPIRED"
                elif [ "$days" -lt 7 ]; then
                    urgency="⚠️ URGENT"
                elif [ "$days" -lt 30 ]; then
                    urgency="⚠️ Soon"
                else
                    urgency="✓ OK"
                fi

                echo "    expires: ${CERT_EXPIRY[$current_domain]}" >> "$TEMP_CONFIG"
                echo "    days_left: ${days}" >> "$TEMP_CONFIG"
                echo "    urgency: \"${urgency}\"" >> "$TEMP_CONFIG"
                echo "    last_checked: ${timestamp}" >> "$TEMP_CONFIG"

                # Skip the old lines
                read -r line  # skip expires
                read -r line  # skip days_left
                read -r line  # skip urgency
                read -r line  # skip last_checked
            else
                # No certificate found - set to null
                echo "    expires: null" >> "$TEMP_CONFIG"
                echo "    days_left: null" >> "$TEMP_CONFIG"
                echo "    urgency: \"❌ No certificate\"" >> "$TEMP_CONFIG"
                echo "    last_checked: ${timestamp}" >> "$TEMP_CONFIG"

                # Skip old lines
                read -r line 2>/dev/null || true
                read -r line 2>/dev/null || true
                read -r line 2>/dev/null || true
                read -r line 2>/dev/null || true
            fi
            continue
        fi
    fi

    # Write all other lines as-is
    echo "$line" >> "$TEMP_CONFIG"

done < "$CONFIG_FILE"

# Replace original file
mv "$TEMP_CONFIG" "$CONFIG_FILE"

echo -e "${GREEN}✓ Updated config.yaml with expiry information${NC}"
echo -e "${YELLOW}Backup saved to: ${CONFIG_BACKUP}${NC}"

# Show summary
echo ""
echo -e "${YELLOW}Domain Expiry Summary:${NC}"

source "${SCRIPT_DIR}/scripts/parse-yaml.sh"
parse_domains "$CONFIG_FILE"

for domain in "${DOMAINS[@]}"; do
    expiry_data=$(get_domain_expiry "$domain" "$CONFIG_FILE")
    IFS='|' read -r expires days_left <<< "$expiry_data"

    if [ "$expires" = "null" ]; then
        echo -e "  ${RED}❌ $domain - No certificate${NC}"
    elif [ "$days_left" -lt 7 ]; then
        echo -e "  ${RED}⚠️  $domain - $days_left days (URGENT)${NC}"
    elif [ "$days_left" -lt 30 ]; then
        echo -e "  ${YELLOW}⚠️  $domain - $days_left days (Soon)${NC}"
    else
        echo -e "  ${GREEN}✓ $domain - $days_left days${NC}"
    fi
done
