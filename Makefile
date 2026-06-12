# Makefile for jira-cli

PREFIX ?= $(HOME)/.local
SRCDIR = src
LOCALBINDIR = bin
LOCALLIBDIR = lib
MAN_DIR = man
SCRIPTS_DIR = scripts
DEPS_DIR = .deps
VERSION_FILE = VERSION
PACKAGE_NAME = jira-cli
VERSION ?= $(shell tr -d '[:space:]' < $(VERSION_FILE) 2>/dev/null || echo 0.0.0)
UNITTEST = $(DEPS_DIR)/shellunittest/src/unittest-cli.sh

.PHONY: all help install uninstall clean test test-deps check-scripts test-unit coverage package upgrade upgrade-dev deps

all: help

help:
	@echo "jira-cli Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make install         Install current tree to PREFIX=$(PREFIX)"
	@echo "  make upgrade         Latest GitHub release via install-core.sh"
	@echo "  make upgrade-dev     git pull + make install"
	@echo "  make uninstall       Remove from PREFIX"
	@echo "  make deps            Fetch test deps (shellunittest)"
	@echo "  make test-deps       Verify bash, curl, jq, git"
	@echo "  make test            test-deps + Jira env check"
	@echo "  make check-scripts   bash -n on src/, lib/, scripts/"
	@echo "  make test-unit       Run test/ suite"
	@echo "  make coverage        kcov over tests (if installed)"
	@echo "  make package         dist/$(PACKAGE_NAME)-VERSION.tar.gz"
	@echo "  make clean           Remove temp artifacts"

deps:
	@bash $(SCRIPTS_DIR)/ci-setup-deps.sh

install: test-deps
	@bash $(SCRIPTS_DIR)/install-core.sh --prefix "$(PREFIX)" --yes
	@if [ -d $(MAN_DIR) ]; then cp -r $(MAN_DIR) $(PREFIX)/; fi
	@echo "Installed to $(PREFIX). Add: export PATH=\"$(PREFIX)/bin:\$$PATH\""

upgrade:
	@bash $(SCRIPTS_DIR)/install-core.sh --prefix "$(PREFIX)" --yes $(if $(VERSION),--version $(VERSION),)

upgrade-dev:
	@git pull --ff-only
	@$(MAKE) install PREFIX="$(PREFIX)"

uninstall:
	@echo "Uninstalling jira-cli from $(PREFIX)..."
	@rm -f $(PREFIX)/bin/jira $(PREFIX)/bin/jira-* $(PREFIX)/bin/md2jira
	@rm -rf $(PREFIX)/src $(PREFIX)/lib $(PREFIX)/man $(PREFIX)/vendor
	@rm -f $(PREFIX)/VERSION
	@echo "Uninstallation completed."

test-deps:
	@echo "Verifying dependencies..."
	@command -v bash >/dev/null 2>&1 || { echo "ERROR: bash not found"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "ERROR: git not found"; exit 1; }
	@echo "Basic dependencies OK"

test: test-deps
	@if [ -z "$$JIRA_HOST" ]; then echo "JIRA_HOST not set"; else echo "JIRA_HOST=$$JIRA_HOST"; fi

test-unit: deps
	@JIRA_NO_UPDATE_CHECK=1 SHELLUNITTEST_DIR=$(DEPS_DIR)/shellunittest ./test/run_all_tests.sh
	@JIRA_NO_UPDATE_CHECK=1 bash test/test_help.sh

coverage: deps
	@if command -v kcov >/dev/null 2>&1; then \
		rm -rf coverage; \
		JIRA_NO_UPDATE_CHECK=1 kcov --exclude-pattern=/.deps/,/vendor/ coverage ./test/run_all_tests.sh; \
		JIRA_NO_UPDATE_CHECK=1 bash test/test_help.sh; \
	else \
		echo "kcov not installed; running test-unit"; \
		$(MAKE) test-unit; \
	fi

check-scripts:
	@echo "Verifying script syntax..."
	@for script in $(SRCDIR)/*.sh $(LOCALLIBDIR)/*.sh $(SCRIPTS_DIR)/*.sh; do \
		[ -f "$$script" ] || continue; \
		case "$$script" in *.zsh.sh) continue ;; esac; \
		echo "Checking: $$script"; bash -n "$$script" || exit 1; \
	done
	@echo "All scripts have valid syntax"

package:
	@mkdir -p dist
	@tar -czf dist/$(PACKAGE_NAME)-$(VERSION).tar.gz \
		--exclude='lib/helpers.sh' \
		$(LOCALBINDIR) $(SRCDIR) $(LOCALLIBDIR) $(MAN_DIR) \
		Makefile $(VERSION_FILE) $(SCRIPTS_DIR)/install.sh $(SCRIPTS_DIR)/install-core.sh
	@echo "Created dist/$(PACKAGE_NAME)-$(VERSION).tar.gz"

clean:
	@find . -name "*.tmp" -delete
	@find . -name "*~" -delete
	@rm -rf coverage dist
	@echo "Cleanup completed."
