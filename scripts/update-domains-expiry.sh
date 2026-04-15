#!/bin/bash
#
# Update domains.conf with certificate expiry information
# Adds/updates comments with expiry dates and days remaining
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAINS_FILE="${SCRIPT_DIR}/domains.conf"
DOMAINS_FILE_BACKUP="${DOMAINS_FILE}.backup"

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
cp "$DOMAINS_FILE" "$DOMAINS_FILE_BACKUP"

# Create temp file for new domains.conf
TEMP_DOMAINS=$(mktemp)

# Parse cert info into associative array
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

# Add header with last update time
echo "# Certbot-Netcup Domain Configuration" > "$TEMP_DOMAINS"
echo "# Last expiry check: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TEMP_DOMAINS"
echo "" >> "$TEMP_DOMAINS"

# Process original domains.conf line by line
while IFS= read -r line || [ -n "$line" ]; do
    # If it's a comment (but not our expiry comments), keep it
    if [[ "$line" =~ ^[[:space:]]*#.*Expires: ]] || [[ "$line" =~ ^[[:space:]]*#.*Last\ expiry\ check: ]]; then
        # Skip old expiry comments - we'll regenerate them
        continue
    elif [[ "$line" =~ ^[[:space:]]*# ]]; then
        # Keep other comments
        echo "$line" >> "$TEMP_DOMAINS"
        continue
    elif [[ -z "${line// }" ]]; then
        # Keep empty lines
        echo "" >> "$TEMP_DOMAINS"
        continue
    fi

    # Extract domain name
    domain=$(echo "$line" | xargs)

    # Check if we have expiry info for this domain
    if [ -n "${CERT_EXPIRY[$domain]}" ]; then
        expiry_date="${CERT_EXPIRY[$domain]}"
        days_left="${CERT_DAYS[$domain]}"

        # Determine status icon
        if [ "$days_left" -lt 0 ]; then
            status_icon="❌ EXPIRED"
        elif [ "$days_left" -lt 7 ]; then
            status_icon="⚠️  URGENT"
        elif [ "$days_left" -lt 30 ]; then
            status_icon="⚠️  Soon"
        else
            status_icon="✓"
        fi

        # Add expiry comment before domain
        echo "# ${domain} - Expires: ${expiry_date} (${days_left} days) ${status_icon}" >> "$TEMP_DOMAINS"
    else
        # No certificate found
        echo "# ${domain} - No certificate found ❌" >> "$TEMP_DOMAINS"
    fi

    # Add the domain itself
    echo "$domain" >> "$TEMP_DOMAINS"

done < "$DOMAINS_FILE"

# Replace original file
mv "$TEMP_DOMAINS" "$DOMAINS_FILE"

echo -e "${GREEN}✓ Updated domains.conf with expiry information${NC}"
echo -e "${YELLOW}Backup saved to: ${DOMAINS_FILE_BACKUP}${NC}"
