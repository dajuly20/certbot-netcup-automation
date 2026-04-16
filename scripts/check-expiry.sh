#!/bin/bash
#
# Check SSL Certificate Expiry Dates
# Shows expiry dates for all configured domains
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"

# Source YAML parser to get domains
source "${SCRIPT_DIR}/scripts/parse-yaml.sh"
parse_domains "$CONFIG_FILE"

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  SSL Certificate Expiry Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if certbot is available
if ! command -v certbot &> /dev/null; then
    echo -e "${RED}Error: certbot not found${NC}"
    echo "Install certbot or run in environment where certbot is available"
    exit 1
fi

# Get all certificates from certbot
echo -e "${YELLOW}Checking all managed certificates...${NC}"
echo ""

# Parse certbot certificates output
CERT_INFO=$(sudo certbot certificates 2>/dev/null)

if [ -z "$CERT_INFO" ]; then
    echo -e "${RED}No certificates found${NC}"
    exit 0
fi

# Create a temporary file to store parsed data
TEMP_FILE=$(mktemp)

# Parse the output
echo "$CERT_INFO" | awk '
    /Certificate Name:/ { name=$3 }
    /Domains:/ {
        domains=$2
        for(i=3; i<=NF; i++) domains=domains" "$i
    }
    /Expiry Date:/ {
        expiry=$3" "$4" "$5
        # Extract just the date
        split($3, date_parts, "-")
        year=date_parts[1]
        month=date_parts[2]
        day=date_parts[3]

        # Calculate days until expiry
        expiry_epoch=mktime(year" "month" "day" 0 0 0")
        now_epoch=systime()
        days_left=int((expiry_epoch - now_epoch) / 86400)

        print name"|"domains"|"expiry"|"days_left
    }
' > "$TEMP_FILE"

# Display results in a nice format
printf "%-25s %-15s %-25s %s\n" "Certificate" "Days Left" "Expiry Date" "Status"
echo "────────────────────────────────────────────────────────────────────────────────"

while IFS='|' read -r cert_name domains expiry days_left; do
    # Color code based on days left
    if [ "$days_left" -lt 7 ]; then
        STATUS_COLOR=$RED
        STATUS="⚠️  URGENT"
    elif [ "$days_left" -lt 30 ]; then
        STATUS_COLOR=$YELLOW
        STATUS="⚠️  Soon"
    else
        STATUS_COLOR=$GREEN
        STATUS="✓ OK"
    fi

    printf "%-25s ${STATUS_COLOR}%-15s${NC} %-25s ${STATUS_COLOR}%s${NC}\n" \
        "$cert_name" "$days_left days" "$expiry" "$STATUS"
done < "$TEMP_FILE"

rm -f "$TEMP_FILE"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Legend:${NC}"
echo -e "  ${GREEN}✓ OK${NC}       - More than 30 days until expiry"
echo -e "  ${YELLOW}⚠️  Soon${NC}    - Less than 30 days until expiry"
echo -e "  ${RED}⚠️  URGENT${NC}  - Less than 7 days until expiry"
echo ""

# Update config.yaml with expiry information
echo -e "${YELLOW}Updating config.yaml with expiry information...${NC}"
"${SCRIPT_DIR}/scripts/update-config-expiry.sh"
echo ""

# Check configured domains vs installed certs
echo -e "${YELLOW}Checking configured domains in config.yaml...${NC}"
echo ""

MISSING_CERTS=()
for domain in "${DOMAINS[@]}"; do
    # Check if certificate exists for this domain
    if ! echo "$CERT_INFO" | grep -q "$domain"; then
        MISSING_CERTS+=("$domain")
    fi
done

if [ ${#MISSING_CERTS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  The following domains in config.yaml don't have certificates yet:${NC}"
    for missing in "${MISSING_CERTS[@]}"; do
        echo "  - $missing"
    done
    echo ""
    echo -e "${YELLOW}Run 'make renew-dryrun' to generate certificates for these domains${NC}"
else
    echo -e "${GREEN}✓ All configured domains have certificates${NC}"
fi

echo ""
