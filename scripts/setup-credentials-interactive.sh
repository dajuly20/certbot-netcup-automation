#!/bin/bash
#
# Interactive Netcup API Credentials Setup
# Uses whiptail/dialog for a nice user interface
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CREDENTIALS_FILE="/var/lib/letsencrypt/netcup_credentials.ini"
CREDENTIALS_DIR="/var/lib/letsencrypt"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if dialog or whiptail is available
if command -v whiptail &> /dev/null; then
    DIALOG=whiptail
elif command -v dialog &> /dev/null; then
    DIALOG=dialog
else
    # Fallback to basic input if no dialog tool available
    DIALOG=""
fi

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Netcup API Credentials Setup${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Function to get input with dialog or fallback
get_input() {
    local prompt="$1"
    local default="$2"
    local result=""

    if [ -n "$DIALOG" ]; then
        result=$($DIALOG --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3)
    else
        read -p "$prompt [$default]: " result
        result=${result:-$default}
    fi

    echo "$result"
}

# Show info message
show_info() {
    local message="$1"

    if [ -n "$DIALOG" ]; then
        $DIALOG --msgbox "$message" 15 70
    else
        echo -e "${YELLOW}$message${NC}"
        read -p "Press Enter to continue..."
    fi
}

# Show initial info
INFO_MSG="This wizard will help you configure your Netcup API credentials.

You need to obtain these from your Netcup Customer Control Panel (CCP):

1. Log in to https://ccp.netcup.net
2. Go to: Master Data → API
3. Create a new API key if you don't have one
4. Note down:
   - Customer ID (Kundennummer)
   - API Key
   - API Password

Ready to continue?"

if [ -n "$DIALOG" ]; then
    $DIALOG --title "Netcup API Setup" --yesno "$INFO_MSG" 20 70
else
    echo "$INFO_MSG"
    read -p "Continue? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

# Get existing values if file exists
EXISTING_CUSTOMER_ID=""
EXISTING_API_KEY=""
EXISTING_API_PASSWORD=""

if [ -f "$CREDENTIALS_FILE" ]; then
    EXISTING_CUSTOMER_ID=$(grep -oP '(?<=dns_netcup_customer_id\s{2}=\s).*' "$CREDENTIALS_FILE" 2>/dev/null || echo "")
    EXISTING_API_KEY=$(grep -oP '(?<=dns_netcup_api_key\s{6}=\s).*' "$CREDENTIALS_FILE" 2>/dev/null || echo "")
    EXISTING_API_PASSWORD=$(grep -oP '(?<=dns_netcup_api_password\s=\s).*' "$CREDENTIALS_FILE" 2>/dev/null || echo "")
fi

# Get Customer ID
echo -e "${YELLOW}Enter your Netcup Customer ID (Kundennummer):${NC}"
CUSTOMER_ID=$(get_input "Netcup Customer ID (e.g., 123456)" "$EXISTING_CUSTOMER_ID")

if [ -z "$CUSTOMER_ID" ]; then
    echo -e "${RED}ERROR: Customer ID cannot be empty${NC}"
    exit 1
fi

# Get API Key
echo -e "${YELLOW}Enter your Netcup API Key:${NC}"
API_KEY=$(get_input "Netcup API Key (e.g., abcd1234...)" "$EXISTING_API_KEY")

if [ -z "$API_KEY" ]; then
    echo -e "${RED}ERROR: API Key cannot be empty${NC}"
    exit 1
fi

# Get API Password
echo -e "${YELLOW}Enter your Netcup API Password:${NC}"
API_PASSWORD=$(get_input "Netcup API Password" "$EXISTING_API_PASSWORD")

if [ -z "$API_PASSWORD" ]; then
    echo -e "${RED}ERROR: API Password cannot be empty${NC}"
    exit 1
fi

# Confirm before writing
CONFIRM_MSG="Please confirm your credentials:

Customer ID: $CUSTOMER_ID
API Key: ${API_KEY:0:20}...
API Password: ${API_PASSWORD:0:10}...

Write these credentials to $CREDENTIALS_FILE?"

if [ -n "$DIALOG" ]; then
    if ! $DIALOG --title "Confirm Credentials" --yesno "$CONFIRM_MSG" 15 70; then
        echo "Setup cancelled."
        exit 0
    fi
else
    echo -e "${YELLOW}$CONFIRM_MSG${NC}"
    read -p "Continue? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

# Create directory if it doesn't exist
mkdir -p "$CREDENTIALS_DIR"

# Write credentials file
echo -e "${YELLOW}Writing credentials to $CREDENTIALS_FILE...${NC}"

cat > "$CREDENTIALS_FILE" << EOF
dns_netcup_customer_id  = $CUSTOMER_ID
dns_netcup_api_key      = $API_KEY
dns_netcup_api_password = $API_PASSWORD
EOF

# Set proper permissions
chmod 600 "$CREDENTIALS_FILE"
chown root:root "$CREDENTIALS_FILE"

echo -e "${GREEN}✓ Credentials file created successfully${NC}"
echo -e "${GREEN}✓ Permissions set to 600 (secure)${NC}"
echo -e "${GREEN}✓ Owner set to root:root${NC}"
echo ""
echo -e "${GREEN}Setup complete!${NC}"

# Show final info
FINAL_MSG="Credentials have been saved securely.

File: $CREDENTIALS_FILE
Permissions: 600 (read/write for root only)

Next steps:
1. Edit domains.conf to add your domains
2. Run: make test
3. Check logs: make logs"

if [ -n "$DIALOG" ]; then
    $DIALOG --title "Setup Complete" --msgbox "$FINAL_MSG" 15 70
else
    echo -e "${GREEN}$FINAL_MSG${NC}"
fi

exit 0
