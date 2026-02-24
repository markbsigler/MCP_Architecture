# Makefile for MCP Architecture Documentation
# Purpose: Build, validate, and maintain consolidated markdown documentation
# Requirements: Python 3.x, Node.js (optional for markdownlint)

# Make configuration
SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help
.SILENT:

# Required tools
PYTHON := python3
NPX := npx

# Detect if running in CI environment (disable colors)
ifeq ($(CI),true)
    RED :=
    GREEN :=
    YELLOW :=
    BLUE :=
    NC :=
else
    # Color output for local development
    RED := \033[0;31m
    GREEN := \033[0;32m
    YELLOW := \033[0;33m
    BLUE := \033[0;34m
    NC := \033[0m
endif

# Content markdown sections (excluding title page & explicit TOC)
CONTENT_SECTIONS = \
	docs/IEEE-42010/views/01-architecture-overview.md \
	docs/IEEE-42010/views/01b-architecture-decisions.md \
	docs/IEEE-42010/views/02-security-architecture.md \
	docs/IEEE-42010/views/02a-data-privacy-compliance.md \
	docs/IEEE-29148/methodology/02b-requirements-engineering.md \
	docs/IEEE-42010/views/03-tool-implementation.md \
	docs/IEEE-42010/views/03a-prompt-implementation.md \
	docs/IEEE-42010/views/03b-resource-implementation.md \
	docs/IEEE-42010/views/03c-sampling-patterns.md \
	docs/IEEE-42010/views/03d-decision-trees.md \
	docs/IEEE-42010/views/03e-integration-patterns.md \
	docs/IEEE-42010/views/03f-elicitation-patterns.md \
	docs/IEEE-42010/views/03g-task-patterns.md \
	docs/IEEE-42010/views/03h-multi-server-orchestration.md \
	docs/IEEE-42010/views/03i-ai-service-provider-gateway.md \
	docs/IEEE-42010/views/04-testing-strategy.md \
	docs/IEEE-42010/views/05-observability.md \
	docs/IEEE-42010/views/06-development-lifecycle.md \
	docs/IEEE-42010/views/06a-performance-scalability.md \
	docs/IEEE-42010/views/07-deployment-patterns.md \
	docs/IEEE-42010/views/08-operational-runbooks.md \
	docs/IEEE-42010/views/09-agentic-best-practices.md \
	docs/IEEE-42010/views/10-migration-guides.md \
	docs/IEEE-42010/views/11-troubleshooting.md \
	docs/IEEE-42010/views/12-cost-optimization.md \
	docs/IEEE-42010/views/13-metrics-kpis.md \
	docs/IEEE-42010/views/14-performance-benchmarks.md \
	docs/IEEE-42010/views/15-mcp-protocol-compatibility.md \
	docs/IEEE-42010/ref/99-quick-reference.md

# Preface sections (generated or static)
PREFIX_SECTIONS = docs/00-title-page.md $(TOC_FILE)

# All sections in final order
ALL_SECTIONS = $(PREFIX_SECTIONS) $(CONTENT_SECTIONS)

# Output files
COMBINED_MD := mcp-architecture.md
TOC_FILE := docs/IEEE-42010/ref/00-table-of-contents.md

#==============================================================================
# PHONY Targets
#==============================================================================

.PHONY: all help build clean rebuild \
        toc md \
        check-deps install-deps \
        lint fix format validate test \
        pre-commit watch

#==============================================================================
# Default & Help
#==============================================================================

all: build

help:
	echo ""
	echo "$(BLUE)MCP Architecture Documentation - Makefile Targets$(NC)"
	echo ""
	echo "$(GREEN)Build Targets:$(NC)"
	echo "  make build         # Build complete markdown documentation (default)"
	echo "  make md            # Alias for build"
	echo "  make toc           # Generate table of contents file"
	echo "  make rebuild       # Clean and rebuild from scratch"
	echo "  make clean         # Remove generated files"
	echo ""
	echo "$(GREEN)Quality Targets:$(NC)"
	echo "  make validate      # Run all validation checks (lint + links)"
	echo "  make lint          # Run linting and link checking"
	echo "  make fix           # Auto-fix linting issues"
	echo "  make format        # Alias for fix"
	echo "  make test          # Run all tests and validations"
	echo "  make pre-commit    # Simulate pre-commit hooks"
	echo ""
	echo "$(GREEN)Dependency Targets:$(NC)"
	echo "  make check-deps    # Check for required tools"
	echo "  make install-deps  # Install missing dependencies"
	echo ""
	echo "$(GREEN)Development Targets:$(NC)"
	echo "  make watch         # Watch files and rebuild on changes"
	echo ""
	echo "$(YELLOW)Current status:$(NC)"
	if [ -f $(COMBINED_MD) ]; then \
		echo "  Output file: $(COMBINED_MD) ($$(wc -c < $(COMBINED_MD) | tr -d ' ') bytes)"; \
	else \
		echo "  Output file: $(COMBINED_MD) (not built)"; \
	fi
	echo ""

#==============================================================================
# Dependency Management
#==============================================================================

# Check for required dependencies
check-deps:
	echo "$(BLUE)[check-deps] Checking required tools...$(NC)"
	missing=0; \
	if ! command -v $(PYTHON) >/dev/null 2>&1; then \
		echo "$(RED)✗ python3 not found$(NC)"; \
		missing=1; \
	else \
		echo "$(GREEN)✓ python3 found: $$($(PYTHON) --version)$(NC)"; \
	fi; \
	if ! command -v node >/dev/null 2>&1; then \
		echo "$(YELLOW)⚠ node not found (optional for markdownlint)$(NC)"; \
	else \
		echo "$(GREEN)✓ node found: $$(node --version)$(NC)"; \
		if ! command -v npm >/dev/null 2>&1; then \
			echo "$(YELLOW)⚠ npm not found (optional for markdownlint)$(NC)"; \
		else \
			echo "$(GREEN)✓ npm found: $$(npm --version)$(NC)"; \
		fi; \
	fi; \
	if [ ! -f scripts/check_links.py ]; then \
		echo "$(RED)✗ scripts/check_links.py not found$(NC)"; \
		missing=1; \
	else \
		echo "$(GREEN)✓ scripts/check_links.py found$(NC)"; \
	fi; \
	if [ ! -f scripts/gen_toc.py ]; then \
		echo "$(RED)✗ scripts/gen_toc.py not found$(NC)"; \
		missing=1; \
	else \
		echo "$(GREEN)✓ scripts/gen_toc.py found$(NC)"; \
	fi; \
	if [ ! -f scripts/rewrite_links.py ]; then \
		echo "$(RED)✗ scripts/rewrite_links.py not found$(NC)"; \
		missing=1; \
	else \
		echo "$(GREEN)✓ scripts/rewrite_links.py found$(NC)"; \
	fi; \
	if [ $$missing -eq 1 ]; then \
		echo "$(RED)[check-deps] Missing required dependencies!$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)[check-deps] All required dependencies found!$(NC)"; \
	fi

# Install missing dependencies
install-deps:
	echo "$(BLUE)[install-deps] Installing dependencies...$(NC)"
	if ! command -v $(PYTHON) >/dev/null 2>&1; then \
		echo "$(RED)Error: python3 is required but not installed.$(NC)"; \
		echo "$(YELLOW)Please install Python 3.x from https://www.python.org/$(NC)"; \
		exit 1; \
	fi
	if command -v npm >/dev/null 2>&1; then \
		echo "$(BLUE)[install-deps] Installing markdownlint-cli...$(NC)"; \
		npm install -g markdownlint-cli || echo "$(YELLOW)Warning: Failed to install markdownlint-cli$(NC)"; \
	else \
		echo "$(YELLOW)[install-deps] npm not found. Skipping markdownlint-cli installation.$(NC)"; \
		echo "$(YELLOW)To install markdownlint, first install Node.js from https://nodejs.org/$(NC)"; \
	fi
	echo "$(GREEN)[install-deps] Dependency installation complete!$(NC)"

#==============================================================================
# Quality & Validation
#==============================================================================

# Run all validation checks
validate: check-deps lint
	echo "$(GREEN)[validate] All validation checks passed!$(NC)"

# Run linting and link checking
lint: check-deps
	echo "$(BLUE)[lint] Running link checker...$(NC)"
	if $(PYTHON) scripts/check_links.py; then \
		echo "$(GREEN)[lint] Link checker passed ✓$(NC)"; \
	else \
		echo "$(RED)[lint] Link checker failed ✗$(NC)"; \
		exit 1; \
	fi
	echo "$(BLUE)[lint] Running markdownlint...$(NC)"
	if command -v $(NPX) >/dev/null 2>&1; then \
		if $(NPX) markdownlint 'docs/**/*.md' 'README.md' --config .markdownlint.json; then \
			echo "$(GREEN)[lint] Markdownlint passed ✓$(NC)"; \
		else \
			echo "$(RED)[lint] Markdownlint found issues ✗$(NC)"; \
			echo "$(YELLOW)Run 'make fix' to auto-fix linting issues$(NC)"; \
			exit 1; \
		fi; \
	else \
		echo "$(YELLOW)[lint] markdownlint not available (run: make install-deps)$(NC)"; \
	fi
	echo "$(GREEN)[lint] Lint check complete!$(NC)"

# Auto-fix linting issues
fix:
	echo "$(BLUE)[fix] Auto-fixing linting issues...$(NC)"
	if command -v $(NPX) >/dev/null 2>&1; then \
		$(NPX) markdownlint --fix 'docs/**/*.md' 'README.md' --config .markdownlint.json && \
		echo "$(GREEN)[fix] Auto-fix complete! Run 'make lint' to verify.$(NC)"; \
	else \
		echo "$(RED)[fix] markdownlint-cli not available. Run 'make install-deps' first.$(NC)"; \
		exit 1; \
	fi

# Alias for fix
format: fix

# Run all tests and validations
test: validate
	echo "$(GREEN)[test] All tests passed!$(NC)"

# Simulate pre-commit hooks
pre-commit: check-deps
	echo "$(BLUE)[pre-commit] Running pre-commit checks...$(NC)"
	echo "$(BLUE)[pre-commit] Checking dependencies...$(NC)"
	$(MAKE) check-deps
	echo "$(BLUE)[pre-commit] Checking internal links...$(NC)"
	if $(PYTHON) scripts/check_links.py; then \
		echo "$(GREEN)✓ Link checker passed$(NC)"; \
	else \
		echo "$(RED)✗ Link checker failed$(NC)"; \
		exit 1; \
	fi
	echo "$(BLUE)[pre-commit] Running markdownlint...$(NC)"
	if command -v $(NPX) >/dev/null 2>&1; then \
		if $(NPX) markdownlint 'docs/**/*.md' 'README.md' --config .markdownlint.json; then \
			echo "$(GREEN)✓ Markdownlint passed$(NC)"; \
		else \
			echo "$(RED)✗ Markdownlint failed$(NC)"; \
			exit 1; \
		fi; \
	fi
	echo "$(BLUE)[pre-commit] Verifying critical files...$(NC)"
	critical_files="README.md CONTRIBUTING.md LICENSE"; \
	for f in $$critical_files; do \
		if [ ! -f "$$f" ]; then \
			echo "$(RED)✗ Missing critical file: $$f$(NC)"; \
			exit 1; \
		fi; \
	done
	echo "$(GREEN)✓ All critical files present$(NC)"
	echo "$(GREEN)[pre-commit] Pre-commit checks passed!$(NC)"

#==============================================================================
# Build Targets
#==============================================================================

# Main build target
build: md

# Generate explicit TOC before concatenating
md: check-deps toc $(COMBINED_MD)
	echo "$(GREEN)[md] Documentation build complete!$(NC)"
$(COMBINED_MD): $(TOC_FILE) $(ALL_SECTIONS)
	echo "$(BLUE)[md] Combining $(words $(ALL_SECTIONS)) sections -> $(COMBINED_MD)$(NC)"
	rm -f $(COMBINED_MD)
	first=1; \
	for f in $(ALL_SECTIONS); do \
	  if [ ! -f "$$f" ]; then \
	    echo "$(RED)Error: Missing section file: $$f$(NC)"; \
	    exit 1; \
	  fi; \
	  if [ $$first -eq 0 ]; then echo "\n\n<section class=\"section-break\"></section>\n" >> $(COMBINED_MD); fi; \
	  $(PYTHON) scripts/rewrite_links.py $$f >> $(COMBINED_MD) || { echo "$(RED)Error processing $$f$(NC)"; exit 1; }; \
	  first=0; \
	done
	echo "$(GREEN)[md] Generated $(COMBINED_MD) ($$(wc -c < $(COMBINED_MD) | tr -d ' ') bytes) ✓$(NC)"

# Build the explicit table of contents file from headings
toc: check-deps $(TOC_FILE)

$(TOC_FILE): $(CONTENT_SECTIONS) scripts/gen_toc.py
	echo "$(BLUE)[toc] Generating table of contents...$(NC)"
	missing=0; \
	for f in $(CONTENT_SECTIONS); do \
	  if [ ! -f "$$f" ]; then \
	    echo "$(RED)Error: Missing content file: $$f$(NC)"; \
	    missing=1; \
	  fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
	  echo "$(RED)[toc] Cannot generate TOC due to missing files$(NC)"; \
	  exit 1; \
	fi
	$(PYTHON) scripts/gen_toc.py $(CONTENT_SECTIONS) || { echo "$(RED)[toc] Failed to generate TOC$(NC)"; exit 1; }
	echo "$(GREEN)[toc] Generated $(TOC_FILE) ✓$(NC)"

#==============================================================================
# Cleanup & Rebuild
#==============================================================================

clean:
	echo "$(BLUE)[clean] Removing generated files...$(NC)"
	if [ -f $(COMBINED_MD) ]; then \
		rm -f $(COMBINED_MD); \
		echo "$(GREEN)[clean] Removed $(COMBINED_MD) ✓$(NC)"; \
	else \
		echo "$(YELLOW)[clean] $(COMBINED_MD) does not exist$(NC)"; \
	fi
	if [ -f $(TOC_FILE) ]; then \
		rm -f $(TOC_FILE); \
		echo "$(GREEN)[clean] Removed $(TOC_FILE) ✓$(NC)"; \
	fi
	# Clean legacy TOC location if exists
	if [ -f docs/00-table-of-contents.md ]; then \
		rm -f docs/00-table-of-contents.md; \
		echo "$(GREEN)[clean] Removed legacy TOC file ✓$(NC)"; \
	fi
	echo "$(GREEN)[clean] Cleanup complete!$(NC)"

rebuild: clean build
	echo "$(GREEN)[rebuild] Rebuild complete!$(NC)"

#==============================================================================
# Development Targets
#==============================================================================

# Watch files and rebuild on changes (requires fswatch or inotifywait)
watch:
	echo "$(BLUE)[watch] Starting file watcher...$(NC)"
	if command -v fswatch >/dev/null 2>&1; then \
		echo "$(GREEN)[watch] Using fswatch. Press Ctrl+C to stop.$(NC)"; \
		fswatch -o docs/ scripts/ | while read -r event; do \
			echo "$(YELLOW)[watch] Change detected, rebuilding...$(NC)"; \
			$(MAKE) build || echo "$(RED)[watch] Build failed!$(NC)"; \
		done; \
	elif command -v inotifywait >/dev/null 2>&1; then \
		echo "$(GREEN)[watch] Using inotifywait. Press Ctrl+C to stop.$(NC)"; \
		while inotifywait -r -e modify,create,delete docs/ scripts/; do \
			echo "$(YELLOW)[watch] Change detected, rebuilding...$(NC)"; \
			$(MAKE) build || echo "$(RED)[watch] Build failed!$(NC)"; \
		done; \
	else \
		echo "$(RED)[watch] No file watcher found. Install fswatch (macOS) or inotify-tools (Linux).$(NC)"; \
		echo "$(YELLOW)macOS: brew install fswatch$(NC)"; \
		echo "$(YELLOW)Linux: apt-get install inotify-tools$(NC)"; \
		exit 1; \
	fi
