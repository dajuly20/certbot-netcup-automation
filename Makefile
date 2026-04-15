.PHONY: help install setup-credentials fix-permissions setup-systemd edit-domains test status logs logs-live clean uninstall verify-credentials list-domains list-certs

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
	@echo "  $(YELLOW)make install$(NC)            - Full installation (credentials, permissions, systemd)"
	@echo "  $(YELLOW)make setup-credentials$(NC)  - Interactive setup for Netcup API credentials"
	@echo "  $(YELLOW)make edit-domains$(NC)       - Interactive domain editor"
	@echo "  $(YELLOW)make fix-permissions$(NC)    - Fix credentials file permissions (600)"
	@echo "  $(YELLOW)make setup-systemd$(NC)      - Configure systemd service and timer"
	@echo "  $(YELLOW)make test$(NC)               - Run certificate renewal manually (test)"
	@echo "  $(YELLOW)make status$(NC)             - Show service and timer status"
	@echo "  $(YELLOW)make logs$(NC)               - Show recent logs"
	@echo "  $(YELLOW)make logs-live$(NC)          - Follow logs in real-time"
	@echo "  $(YELLOW)make list-domains$(NC)       - List configured domains"
	@echo "  $(YELLOW)make verify-credentials$(NC) - Verify credentials configuration"
	@echo "  $(YELLOW)make list-certs$(NC)         - Show installed certificates"
	@echo "  $(YELLOW)make clean$(NC)              - Remove lock files"
	@echo "  $(YELLOW)make uninstall$(NC)          - Remove systemd configuration"
	@echo ""
	@echo "Quick start: $(GREEN)make install$(NC)"

install:
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Certbot-Netcup Automation - Full Installation$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo ""
	@$(MAKE) setup-credentials
	@echo ""
	@$(MAKE) fix-permissions
	@echo ""
	@$(MAKE) setup-systemd
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Installation Complete!$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit domains.conf to add your domains"
	@echo "  2. Run: $(YELLOW)make test$(NC) to test the setup"
	@echo "  3. Check logs: $(YELLOW)make logs$(NC)"
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

# Hidden target for checking sudo
check-sudo:
	@if [ "$$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then \
		echo "$(RED)This target requires sudo privileges.$(NC)"; \
		exit 1; \
	fi
