.PHONY: help install setup-credentials fix-permissions setup-systemd edit-domains edit-config test status logs logs-live clean uninstall verify-credentials list-domains list-certs check-expiry

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
	@echo "Available targets:"
	@echo "  $(YELLOW)make install$(NC)            - Full guided installation (all steps)"
	@echo "  $(YELLOW)make setup-credentials$(NC)  - Interactive setup for Netcup API credentials"
	@echo "  $(YELLOW)make edit-domains$(NC)       - Interactive domain editor"
	@echo "  $(YELLOW)make edit-config$(NC)        - Edit config.yaml settings"
	@echo "  $(YELLOW)make fix-permissions$(NC)    - Fix credentials file permissions (600)"
	@echo "  $(YELLOW)make setup-systemd$(NC)      - Configure systemd service and timer"
	@echo "  $(YELLOW)make test$(NC)               - Run certificate renewal manually (test)"
	@echo "  $(YELLOW)make status$(NC)             - Show service and timer status"
	@echo "  $(YELLOW)make logs$(NC)               - Show recent logs"
	@echo "  $(YELLOW)make logs-live$(NC)          - Follow logs in real-time"
	@echo "  $(YELLOW)make list-domains$(NC)       - List configured domains"
	@echo "  $(YELLOW)make verify-credentials$(NC) - Verify credentials configuration"
	@echo "  $(YELLOW)make list-certs$(NC)         - Show installed certificates"
	@echo "  $(YELLOW)make check-expiry$(NC)       - Check certificate expiry dates"
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
	@echo "$(YELLOW)Step 2/6: Fix File Permissions$(NC)"
	@$(MAKE) fix-permissions
	@echo ""
	@echo "$(YELLOW)Step 3/6: Configure Domains$(NC)"
	@if [ -f "domains.conf" ] && [ -n "$$(grep -v '^#' domains.conf | grep -v '^[[:space:]]*$$')" ]; then \
		echo "Current domains:"; \
		grep -v '^#' domains.conf | grep -v '^[[:space:]]*$$' | nl -w2 -s'. '; \
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
	@echo "$(YELLOW)Step 4/6: Review Configuration$(NC)"
	@echo "Current config.yaml settings:"
	@grep -A3 "^renewal:" config.yaml | grep -E "(renew_days_before|dns_propagation_timeout|email)" || true
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
	@echo "$(YELLOW)Step 5/6: Setup Systemd Service$(NC)"
	@$(MAKE) setup-systemd
	@echo ""
	@echo "$(YELLOW)Step 6/6: Verify Installation$(NC)"
	@echo "Verifying credentials..."
	@$(MAKE) verify-credentials
	@echo ""
	@echo "Checking configured domains..."
	@$(MAKE) list-domains
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  ✓ Installation Complete!$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Configuration Summary:$(NC)"
	@echo "  Domains:         $$(grep -v '^#' domains.conf | grep -v '^[[:space:]]*$$' | wc -l) domains configured"
	@echo "  Renew threshold: $$(grep renew_days_before config.yaml | awk '{print $$2}') days"
	@echo "  DNS timeout:     $$(grep dns_propagation_timeout config.yaml | awk '{print $$2}')s"
	@echo "  Service:         certbot-netcup.timer (daily at 03:30)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Test the setup:        $(GREEN)make test$(NC)"
	@echo "  2. Check expiry dates:    $(GREEN)make check-expiry$(NC)"
	@echo "  3. View service status:   $(GREEN)make status$(NC)"
	@echo "  4. Monitor logs:          $(GREEN)make logs-live$(NC)"
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

fix-permissions:
	@echo "$(YELLOW)Fixing credentials file permissions...$(NC)"
	@sudo ./scripts/fix-permissions.sh

setup-systemd:
	@echo "$(YELLOW)Configuring systemd service...$(NC)"
	@sudo ./scripts/setup-systemd.sh

edit-domains:
	@./scripts/edit-domains.sh

edit-config:
	@echo "$(YELLOW)Current config.yaml settings:$(NC)"
	@echo ""
	@grep -A8 "^renewal:" config.yaml || true
	@echo ""
	@echo "$(YELLOW)Key settings:$(NC)"
	@echo "  - renew_days_before: When to renew certificates"
	@echo "  - dns_propagation_timeout: DNS wait time in seconds"
	@echo "  - email: Let's Encrypt notification email"
	@echo ""
	@read -p "Edit config.yaml? [y/N] (N = keep as is) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$${EDITOR:-nano} config.yaml; \
		echo ""; \
		echo "$(GREEN)✓ Configuration updated$(NC)"; \
		echo ""; \
		echo "New settings:"; \
		grep -A8 "^renewal:" config.yaml || true; \
	else \
		echo "$(GREEN)✓ Keeping current configuration$(NC)"; \
	fi

test:
	@echo "$(YELLOW)Running certificate renewal (this may take 30+ minutes)...$(NC)"
	@echo "Press Ctrl+C to abort, or open another terminal and run: make logs-live"
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

logs-live:
	@echo "$(GREEN)Following logs in real-time... (Press Ctrl+C to stop)$(NC)"
	@sudo tail -f $(LOG_FILE)

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

verify-credentials:
	@echo "$(YELLOW)Verifying credentials file...$(NC)"
	@if [ ! -f "$(CREDENTIALS_FILE)" ]; then \
		echo "$(RED)✗ Credentials file not found: $(CREDENTIALS_FILE)$(NC)"; \
		echo "$(YELLOW)Run: make setup-credentials$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Credentials file exists$(NC)"
	@ls -la $(CREDENTIALS_FILE)
	@echo ""
	@echo "$(YELLOW)File permissions should be: -rw------- (600)$(NC)"

list-domains:
	@echo "$(GREEN)Active domains in configuration:$(NC)"
	@grep -v '^#' $(SCRIPT_DIR)/domains.conf | grep -v '^[[:space:]]*$$' | nl -w2 -s'. ' || echo "No domains configured"
	@echo ""
	@echo "$(YELLOW)Each domain gets: example.com + *.example.com$(NC)"

list-certs:
	@echo "$(GREEN)Installed certificates:$(NC)"
	@sudo certbot certificates 2>/dev/null || echo "$(RED)Certbot not found or no certificates$(NC)"

check-expiry:
	@./scripts/check-expiry.sh

# Hidden target for checking sudo
check-sudo:
	@if [ "$$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then \
		echo "$(RED)This target requires sudo privileges.$(NC)"; \
		exit 1; \
	fi
