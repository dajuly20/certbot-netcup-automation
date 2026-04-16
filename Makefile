.PHONY: help install setup-credentials edit-domains renew-dryrun renew status logs check-expiry add-remote-host list-remote-hosts sync-certs clean uninstall

# Colors for output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m # No Color

# Paths
SCRIPT_DIR := $(shell pwd)
CREDENTIALS_FILE := /var/lib/letsencrypt/netcup_credentials.ini
LOG_FILE := /var/log/certbot-netcup.log
SERVICE_NAME := certbot-netcup.service

help:
	@echo "$(GREEN)Certbot-Netcup Automation - Makefile$(NC)"
	@echo ""
	@echo "$(GREEN)Main Commands:$(NC)"
	@echo "  $(YELLOW)make install$(NC)            - Full guided installation"
	@echo "  $(YELLOW)make renew-dryrun$(NC)       - Test: show what would be renewed"
	@echo "  $(YELLOW)make renew$(NC)              - Actually renew certificates now"
	@echo "  $(YELLOW)make status$(NC)             - Show service status & next run"
	@echo "  $(YELLOW)make logs$(NC)               - Show logs (add -f to follow)"
	@echo "  $(YELLOW)make check-expiry$(NC)       - Check certificate expiry dates"
	@echo ""
	@echo "$(GREEN)Configuration:$(NC)"
	@echo "  $(YELLOW)make setup-credentials$(NC)  - Reconfigure Netcup API credentials"
	@echo "  $(YELLOW)make edit-domains$(NC)       - Edit domains (or edit config.yaml)"
	@echo "  $(YELLOW)nano config.yaml$(NC)        - Edit all settings manually"
	@echo ""
	@echo "$(GREEN)Remote Sync:$(NC)"
	@echo "  $(YELLOW)make add-remote-host$(NC)    - Add a remote host for cert sync"
	@echo "  $(YELLOW)make list-remote-hosts$(NC)  - List configured remote hosts"
	@echo "  $(YELLOW)make sync-certs$(NC)         - Manually sync certs to remote hosts"
	@echo ""
	@echo "$(GREEN)Other:$(NC)"
	@echo "  $(YELLOW)make clean$(NC)              - Remove lock files"
	@echo "  $(YELLOW)make uninstall$(NC)          - Remove systemd configuration"
	@echo ""
	@echo "Quick start: $(GREEN)make install$(NC)"

install:
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Certbot-Netcup Automation - Full Installation$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 1/6: Setup API Credentials$(NC)"
	@$(MAKE) setup-credentials
	@echo ""
	@echo "$(YELLOW)Step 2/6: Configure Domains$(NC)"
	@if [ -n "$$(sed -n '/^domains:/,/^[a-z]/p' config.yaml | grep 'name:')" ]; then \
		echo "Current domains:"; \
		sed -n '/^domains:/,/^[a-z]/p' config.yaml | grep "name:" | sed 's/.*name: //' | nl -w2 -s'. '; \
		echo ""; \
		read -p "Edit domains? [y/N] " -n 1 -r; \
		echo; \
		if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
			$(MAKE) edit-domains || true; \
		else \
			echo "$(GREEN)✓ Keeping current domains$(NC)"; \
		fi; \
	else \
		echo "No domains configured yet. Opening domain editor..."; \
		$(MAKE) edit-domains || true; \
	fi
	@echo ""
	@echo "$(YELLOW)Step 3/6: Review Configuration$(NC)"
	@echo "Current config.yaml settings:"
	@grep -A10 "^renewal:" config.yaml | grep -E "(renew_days_before|dns_propagation_timeout|email|schedule)" || true
	@echo ""
	@read -p "Edit config.yaml? [y/N] (N = keep as is) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$${EDITOR:-nano} config.yaml; \
		echo "$(GREEN)✓ Configuration updated$(NC)"; \
	else \
		echo "$(GREEN)✓ Keeping current configuration$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)Step 4/6: Setup Systemd Service$(NC)"
	@sudo ./scripts/setup-systemd.sh
	@echo ""
	@echo "$(YELLOW)Step 5/6: Verify Installation$(NC)"
	@echo "Verifying credentials..."
	@if [ ! -f "/var/lib/letsencrypt/netcup_credentials.ini" ]; then \
		echo "$(RED)✗ Credentials file not found$(NC)"; \
	else \
		echo "$(GREEN)✓ Credentials file exists$(NC)"; \
		sudo ls -la /var/lib/letsencrypt/netcup_credentials.ini; \
	fi
	@echo ""
	@echo "Checking configured domains..."
	@sed -n '/^domains:/,/^[a-z]/p' config.yaml | grep "name:" | sed 's/.*name: //' | nl -w2 -s'. ' || echo "No domains configured"
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  ✓ Installation Complete!$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Configuration Summary:$(NC)"
	@echo "  Domains:         $$(sed -n '/^domains:/,/^[a-z]/p' config.yaml | grep -c 'name:') domains configured"
	@echo "  Renew threshold: $$(grep renew_days_before config.yaml | awk '{print $$2}') days"
	@echo "  DNS timeout:     $$(grep dns_propagation_timeout config.yaml | awk '{print $$2}')s"
	@echo "  Timer schedule:  $$(grep -A5 '^systemd:' config.yaml | grep 'schedule:' | sed 's/.*: *//' | tr -d '\"')"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Test the setup:        $(GREEN)make renew-dryrun$(NC)"
	@echo "  2. Check expiry dates:    $(GREEN)make check-expiry$(NC)"
	@echo "  3. View service status:   $(GREEN)make status$(NC)"
	@echo "  4. Monitor logs:          $(GREEN)make logs$(NC)"
	@echo ""

setup-credentials:
	@echo "$(YELLOW)Setting up Netcup API credentials...$(NC)"
	@if [ ! -f "$(CREDENTIALS_FILE)" ]; then \
		sudo ./scripts/setup-credentials-interactive.sh; \
	else \
		echo "$(YELLOW)Credentials file already exists: $(CREDENTIALS_FILE)$(NC)"; \
		read -p "Do you want to reconfigure? [y/N] " -n 1 -r; \
		echo; \
		if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
			sudo ./scripts/setup-credentials-interactive.sh; \
		fi; \
	fi

edit-domains:
	@./scripts/edit-domains.sh

renew-dryrun:
	@echo "$(YELLOW)Running certificate renewal check (dry-run)...$(NC)"
	@echo "This will show which domains would be renewed without actually renewing them."
	@echo ""
	@sudo $(SCRIPT_DIR)/certbot-netcup-renew.sh --dry-run

renew:
	@echo "$(YELLOW)Running certificate renewal (this may take 30+ minutes)...$(NC)"
	@echo "Press Ctrl+C to abort, or open another terminal and run:"
	@echo "  sudo tail -f $(LOG_FILE)"
	@echo ""
	@sudo systemctl start $(SERVICE_NAME)
	@sleep 2
	@sudo systemctl status $(SERVICE_NAME) --no-pager || true

status:
	@echo "$(GREEN)Service Status:$(NC)"
	@sudo systemctl status $(SERVICE_NAME) --no-pager || true
	@echo ""
	@echo "$(GREEN)Timer Status:$(NC)"
	@sudo systemctl status certbot-netcup.timer --no-pager || true
	@echo ""
	@echo "$(GREEN)Next Scheduled Run:$(NC)"
	@sudo systemctl list-timers certbot-netcup.timer --no-pager

logs:
	@echo "$(GREEN)Recent logs (last 50 lines):$(NC)"
	@if [ -f "$(LOG_FILE)" ]; then \
		sudo tail -50 $(LOG_FILE); \
	else \
		echo "$(RED)Log file not found: $(LOG_FILE)$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)Systemd journal (last 20 entries):$(NC)"
	@sudo journalctl -u $(SERVICE_NAME) -n 20 --no-pager || true
	@echo ""
	@echo "$(YELLOW)Tip: To follow logs in real-time, run:$(NC)"
	@echo "  sudo tail -f $(LOG_FILE)"

clean:
	@echo "$(YELLOW)Cleaning up lock files...$(NC)"
	@sudo rm -f /var/run/certbot-netcup.lock
	@echo "$(GREEN)Done.$(NC)"

uninstall:
	@echo "$(RED)This will remove the systemd service configuration.$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		sudo systemctl stop certbot-netcup.timer || true; \
		sudo systemctl disable certbot-netcup.timer || true; \
		sudo rm -f /etc/systemd/system/certbot-netcup.service.d/override.conf; \
		sudo systemctl daemon-reload; \
		echo "$(GREEN)Systemd configuration removed.$(NC)"; \
	else \
		echo "$(YELLOW)Uninstall cancelled.$(NC)"; \
	fi

check-expiry:
	@echo "$(GREEN)Installed certificates:$(NC)"
	@sudo certbot certificates 2>/dev/null || echo "$(RED)Certbot not found or no certificates$(NC)"

check-expiry:
	@./scripts/check-expiry.sh

add-remote-host:
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Add Remote Host for Certificate Sync$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Remote hosts receive automatic certificate syncs after renewal.$(NC)"
	@echo "$(YELLOW)Passwordless root SSH access is required.$(NC)"
	@echo ""
	@read -p "Enter hostname or IP: " hostname; \
	read -p "Enter SSH user [root]: " user; \
	user=$${user:-root}; \
	echo ""; \
	echo "Testing SSH connection to $$user@$$hostname..."; \
	if timeout 10 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$$user@$$hostname" 'exit 0' 2>/dev/null; then \
		echo "$(GREEN)✓ SSH connection successful$(NC)"; \
	else \
		echo "$(RED)✗ SSH connection failed$(NC)"; \
		echo "$(YELLOW)Setting up passwordless SSH access...$(NC)"; \
		echo ""; \
		ssh-copy-id "$$user@$$hostname"; \
		echo ""; \
		echo "Testing connection again..."; \
		if timeout 10 ssh -o BatchMode=yes -o ConnectTimeout=5 "$$user@$$hostname" 'exit 0' 2>/dev/null; then \
			echo "$(GREEN)✓ SSH access configured successfully$(NC)"; \
		else \
			echo "$(RED)✗ SSH access still not working$(NC)"; \
			echo "Please manually configure: ssh-copy-id $$user@$$hostname"; \
			exit 1; \
		fi; \
	fi; \
	echo ""; \
	echo "Adding host to config.yaml..."; \
	if grep -q "^remote_hosts:" config.yaml; then \
		if grep -q "enabled: false" config.yaml; then \
			sed -i 's/enabled: false/enabled: true/' config.yaml; \
		fi; \
		if grep -q "#    - hostname:" config.yaml; then \
			sed -i "/hosts:/a\    - hostname: $$hostname\n      user: $$user\n" config.yaml; \
		else \
			sed -i "/hosts:/a\    - hostname: $$hostname\n      user: $$user\n" config.yaml; \
		fi; \
		echo "$(GREEN)✓ Host added to config.yaml$(NC)"; \
		echo ""; \
		echo "$(YELLOW)Configured remote hosts:$(NC)"; \
		$(MAKE) list-remote-hosts; \
	else \
		echo "$(RED)✗ remote_hosts section not found in config.yaml$(NC)"; \
		exit 1; \
	fi

list-remote-hosts:
	@echo "$(GREEN)Configured remote hosts:$(NC)"
	@echo ""
	@if grep -q "enabled: true" config.yaml; then \
		echo "$(GREEN)Remote sync: ENABLED$(NC)"; \
	else \
		echo "$(YELLOW)Remote sync: DISABLED$(NC)"; \
		echo "Run 'make add-remote-host' to enable and add hosts"; \
	fi
	@echo ""
	@awk '/^[[:space:]]*hosts:/{flag=1; next} /^[[:space:]]*sync:/{flag=0} flag && /^[[:space:]]*-[[:space:]]*hostname:/{gsub(/^[[:space:]]*-[[:space:]]*hostname:[[:space:]]*/, ""); hostname=$$0} flag && /^[[:space:]]*user:/{gsub(/^[[:space:]]*user:[[:space:]]*/, ""); print "  • " $$0 "@" hostname}' config.yaml | grep -v "^  • @$$" | sed 's/•/$(GREEN)•$(NC)/' || echo "  No hosts configured"
	@echo ""

sync-certs:
	@echo "$(GREEN)Syncing certificates to remote hosts...$(NC)"
	@sudo ./scripts/sync-certs.sh

# Hidden target for checking sudo
check-sudo:
	@if [ "$$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then \
		echo "$(RED)This target requires sudo privileges.$(NC)"; \
		exit 1; \
	fi
