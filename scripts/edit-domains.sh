#!/bin/bash
#
# Interactive Domain Editor
# Helps manage domains in domains.conf
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAINS_FILE="${SCRIPT_DIR}/domains.conf"

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Domain Configuration Editor${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if file exists
if [ ! -f "$DOMAINS_FILE" ]; then
    echo -e "${RED}ERROR: domains.conf not found at $DOMAINS_FILE${NC}"
    exit 1
fi

# Show current domains
echo -e "${YELLOW}Currently configured domains:${NC}"
echo ""
grep -v '^#' "$DOMAINS_FILE" | grep -v '^[[:space:]]*$' | nl -w2 -s'. '
echo ""

# Menu
while true; do
    echo -e "${YELLOW}What would you like to do?${NC}"
    echo "  1) Add a new domain"
    echo "  2) Remove a domain"
    echo "  3) Edit domains.conf manually"
    echo "  4) Show all domains (including commented)"
    echo "  5) Exit"
    echo ""
    read -p "Choice [1-5]: " choice

    case $choice in
        1)
            echo ""
            read -p "Enter domain to add (e.g., example.com): " new_domain
            if [ -n "$new_domain" ]; then
                # Validate domain format (basic)
                if [[ $new_domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    # Check if already exists
                    if grep -q "^$new_domain$" "$DOMAINS_FILE"; then
                        echo -e "${YELLOW}Domain already exists in config${NC}"
                    else
                        echo "$new_domain" >> "$DOMAINS_FILE"
                        echo -e "${GREEN}✓ Added: $new_domain${NC}"
                        echo -e "${YELLOW}Will manage: $new_domain and *.$new_domain${NC}"
                    fi
                else
                    echo -e "${RED}Invalid domain format${NC}"
                fi
            fi
            echo ""
            ;;
        2)
            echo ""
            read -p "Enter domain to comment out (e.g., example.com): " remove_domain
            if [ -n "$remove_domain" ]; then
                if grep -q "^$remove_domain$" "$DOMAINS_FILE"; then
                    sed -i "s/^$remove_domain$/# $remove_domain/" "$DOMAINS_FILE"
                    echo -e "${GREEN}✓ Commented out: $remove_domain${NC}"
                else
                    echo -e "${RED}Domain not found in active list${NC}"
                fi
            fi
            echo ""
            ;;
        3)
            ${EDITOR:-nano} "$DOMAINS_FILE"
            echo -e "${GREEN}✓ File edited${NC}"
            echo ""
            ;;
        4)
            echo ""
            echo -e "${YELLOW}Full domains.conf content:${NC}"
            cat -n "$DOMAINS_FILE"
            echo ""
            ;;
        5)
            echo "Bye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            echo ""
            ;;
    esac
done
