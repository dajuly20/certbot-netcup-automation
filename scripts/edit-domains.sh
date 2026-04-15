#!/bin/bash
#
# Interactive Domain Editor for config.yaml
# Helps manage domains in the domains section
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"
CONFIG_BACKUP="${CONFIG_FILE}.backup-edit"

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Domain Configuration Editor (config.yaml)${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}ERROR: config.yaml not found at $CONFIG_FILE${NC}"
    exit 1
fi

# Source YAML parser
source "${SCRIPT_DIR}/scripts/parse-yaml.sh"
parse_domains "$CONFIG_FILE"

# Show current domains
echo -e "${YELLOW}Currently configured domains:${NC}"
echo ""
if [ ${#DOMAINS[@]} -eq 0 ]; then
    echo "  No domains configured yet"
else
    for i in "${!DOMAINS[@]}"; do
        domain="${DOMAINS[$i]}"
        expiry_data=$(get_domain_expiry "$domain" "$CONFIG_FILE")
        IFS='|' read -r expires days_left <<< "$expiry_data"

        if [ "$days_left" != "null" ] && [ -n "$days_left" ]; then
            echo "  $((i+1)). $domain ($days_left days left)"
        else
            echo "  $((i+1)). $domain (not checked yet)"
        fi
    done
fi
echo ""

# Menu
while true; do
    echo -e "${YELLOW}What would you like to do?${NC}"
    echo "  1) Add a new domain"
    echo "  2) Remove a domain"
    echo "  3) Edit config.yaml manually"
    echo "  4) Show all domains with details"
    echo "  5) OK - Keep as is (Exit)"
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
                    if [[ " ${DOMAINS[@]} " =~ " ${new_domain} " ]]; then
                        echo -e "${YELLOW}Domain already exists in config${NC}"
                    else
                        # Add domain to config.yaml
                        cp "$CONFIG_FILE" "$CONFIG_BACKUP"

                        # Find the domains: section and add new domain
                        awk -v domain="$new_domain" '
                            /^domains:/ {
                                print
                                print "  - name: " domain
                                print "    expires: null"
                                print "    days_left: null"
                                print "    urgency: \"❓ Not checked yet\""
                                print "    last_checked: null"
                                print ""
                                in_domains=1
                                next
                            }
                            in_domains && /^[a-z]/ && !/^  / {
                                in_domains=0
                            }
                            !in_domains || !/^  - name:/ {
                                print
                            }
                        ' "$CONFIG_BACKUP" > "$CONFIG_FILE"

                        echo -e "${GREEN}✓ Added: $new_domain${NC}"
                        echo -e "${YELLOW}Will manage: $new_domain and *.$new_domain${NC}"
                        echo -e "${YELLOW}Run 'make check-expiry' to update expiry info${NC}"

                        # Reload domains
                        parse_domains "$CONFIG_FILE"
                    fi
                else
                    echo -e "${RED}Invalid domain format${NC}"
                fi
            fi
            echo ""
            ;;
        2)
            echo ""
            if [ ${#DOMAINS[@]} -eq 0 ]; then
                echo -e "${YELLOW}No domains to remove${NC}"
            else
                read -p "Enter domain to remove (e.g., example.com): " remove_domain
                if [ -n "$remove_domain" ]; then
                    if [[ " ${DOMAINS[@]} " =~ " ${remove_domain} " ]]; then
                        cp "$CONFIG_FILE" "$CONFIG_BACKUP"

                        # Remove domain and its properties from YAML
                        awk -v domain="$remove_domain" '
                            /- name: '"$remove_domain"'$/ {
                                skip=5  # Skip this line and next 4 (expires, days_left, urgency, last_checked, blank)
                                next
                            }
                            skip > 0 {
                                skip--
                                next
                            }
                            { print }
                        ' "$CONFIG_BACKUP" > "$CONFIG_FILE"

                        echo -e "${GREEN}✓ Removed: $remove_domain${NC}"

                        # Reload domains
                        parse_domains "$CONFIG_FILE"
                    else
                        echo -e "${RED}Domain not found in config${NC}"
                    fi
                fi
            fi
            echo ""
            ;;
        3)
            ${EDITOR:-nano} "$CONFIG_FILE"
            echo -e "${GREEN}✓ File edited${NC}"
            parse_domains "$CONFIG_FILE"
            echo ""
            ;;
        4)
            echo ""
            echo -e "${YELLOW}All domains with details:${NC}"
            echo ""
            for domain in "${DOMAINS[@]}"; do
                expiry_data=$(get_domain_expiry "$domain" "$CONFIG_FILE")
                IFS='|' read -r expires days_left <<< "$expiry_data"

                echo -e "  Domain: ${GREEN}$domain${NC}"
                if [ "$expires" != "null" ] && [ -n "$expires" ]; then
                    echo "    Expires: $expires"
                    echo "    Days left: $days_left"
                else
                    echo "    Status: Not checked yet"
                fi
                echo ""
            done
            ;;
        5)
            echo -e "${GREEN}✓ Keeping current configuration${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            echo ""
            ;;
    esac
done
