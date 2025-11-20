# Makefile for building consolidated MCP Architecture markdown only.
# Pure shell/cat pipeline, no Python venv required.

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

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
	docs/01-architecture-overview.md \
	docs/01b-architecture-decisions.md \
	docs/02-security-architecture.md \
	docs/02a-data-privacy-compliance.md \
	docs/02b-requirements-engineering.md \
	docs/03-tool-implementation.md \
	docs/03a-prompt-implementation.md \
	docs/03b-resource-implementation.md \
	docs/03c-sampling-patterns.md \
	docs/03d-decision-trees.md \
	docs/03e-integration-patterns.md \
	docs/04-testing-strategy.md \
	docs/05-observability.md \
	docs/06-development-lifecycle.md \
	docs/06a-performance-scalability.md \
	docs/07-deployment-patterns.md \
	docs/08-operational-runbooks.md \
	docs/09-agentic-best-practices.md \
	docs/10-migration-guides.md \
	docs/11-troubleshooting.md \
	docs/12-cost-optimization.md \
	docs/13-metrics-kpis.md \
	docs/14-performance-benchmarks.md \
	docs/15-mcp-protocol-compatibility.md \
	docs/99-quick-reference.md

# Preface sections (generated or static)
PREFIX_SECTIONS = docs/00-title-page.md docs/00-table-of-contents.md

# All sections in final order
ALL_SECTIONS = $(PREFIX_SECTIONS) $(CONTENT_SECTIONS)

COMBINED_MD := mcp-architecture.md

.PHONY: all help toc md clean check-deps install-deps

all: md

help:
	@echo "Markdown-only targets:"; \
	echo "  make check-deps    # Check for required tools"; \
	echo "  make install-deps  # Install missing dependencies"; \
	echo "  make toc           # Generate explicit TOC file"; \
	echo "  make md            # Concatenate sections to project root"; \
	echo "  make clean         # Remove output markdown"; \
	echo "  make lint          # Run linting and link checking";

# Check for required dependencies
check-deps:
	@echo -e "$(BLUE)[check-deps] Checking required tools...$(NC)"
	@missing=0; \
	if ! command -v $(PYTHON) >/dev/null 2>&1; then \
		echo -e "$(RED)✗ python3 not found$(NC)"; \
		missing=1; \
	else \
		echo -e "$(GREEN)✓ python3 found: $$($(PYTHON) --version)$(NC)"; \
	fi; \
	if ! command -v node >/dev/null 2>&1; then \
		echo -e "$(YELLOW)⚠ node not found (optional for markdownlint)$(NC)"; \
	else \
		echo -e "$(GREEN)✓ node found: $$(node --version)$(NC)"; \
		if ! command -v npm >/dev/null 2>&1; then \
			echo -e "$(YELLOW)⚠ npm not found (optional for markdownlint)$(NC)"; \
		else \
			echo -e "$(GREEN)✓ npm found: $$(npm --version)$(NC)"; \
		fi; \
	fi; \
	if [ ! -f scripts/check_links.py ]; then \
		echo -e "$(RED)✗ scripts/check_links.py not found$(NC)"; \
		missing=1; \
	else \
		echo -e "$(GREEN)✓ scripts/check_links.py found$(NC)"; \
	fi; \
	if [ ! -f scripts/gen_toc.py ]; then \
		echo -e "$(RED)✗ scripts/gen_toc.py not found$(NC)"; \
		missing=1; \
	else \
		echo -e "$(GREEN)✓ scripts/gen_toc.py found$(NC)"; \
	fi; \
	if [ ! -f scripts/rewrite_links.py ]; then \
		echo -e "$(RED)✗ scripts/rewrite_links.py not found$(NC)"; \
		missing=1; \
	else \
		echo -e "$(GREEN)✓ scripts/rewrite_links.py found$(NC)"; \
	fi; \
	if [ $$missing -eq 1 ]; then \
		echo -e "$(RED)[check-deps] Missing required dependencies!$(NC)"; \
		exit 1; \
	else \
		echo -e "$(GREEN)[check-deps] All required dependencies found!$(NC)"; \
	fi

# Install missing dependencies
install-deps:
	@echo -e "$(BLUE)[install-deps] Installing dependencies...$(NC)"
	@if ! command -v $(PYTHON) >/dev/null 2>&1; then \
		echo -e "$(RED)Error: python3 is required but not installed.$(NC)"; \
		echo -e "$(YELLOW)Please install Python 3.x from https://www.python.org/$(NC)"; \
		exit 1; \
	fi
	@if command -v npm >/dev/null 2>&1; then \
		echo -e "$(BLUE)[install-deps] Installing markdownlint-cli...$(NC)"; \
		npm install -g markdownlint-cli || echo -e "$(YELLOW)Warning: Failed to install markdownlint-cli$(NC)"; \
	else \
		echo -e "$(YELLOW)[install-deps] npm not found. Skipping markdownlint-cli installation.$(NC)"; \
		echo -e "$(YELLOW)To install markdownlint, first install Node.js from https://nodejs.org/$(NC)"; \
	fi
	@echo -e "$(GREEN)[install-deps] Dependency installation complete!$(NC)"

lint: check-deps
	@echo -e "$(BLUE)[lint] Running link checker...$(NC)"
	@if $(PYTHON) scripts/check_links.py; then \
		echo -e "$(GREEN)[lint] Link checker passed ✓$(NC)"; \
	else \
		echo -e "$(RED)[lint] Link checker failed ✗$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(BLUE)[lint] Running markdownlint...$(NC)"
	@if command -v $(NPX) >/dev/null 2>&1; then \
		if $(NPX) markdownlint 'docs/**/*.md' 'README.md' --config .markdownlint.json; then \
			echo -e "$(GREEN)[lint] Markdownlint passed ✓$(NC)"; \
		else \
			echo -e "$(RED)[lint] Markdownlint found issues ✗$(NC)"; \
			echo -e "$(YELLOW)Run 'npx markdownlint --fix docs/**/*.md README.md --config .markdownlint.json' to auto-fix$(NC)"; \
			exit 1; \
		fi; \
	else \
		echo -e "$(YELLOW)[lint] markdownlint not available (run: make install-deps)$(NC)"; \
	fi
	@echo -e "$(GREEN)[lint] Lint check complete!$(NC)"

# Generate explicit TOC before concatenating
md: check-deps toc $(COMBINED_MD)
$(COMBINED_MD): $(ALL_SECTIONS)
	@echo -e "$(BLUE)[md] Combining $(words $(ALL_SECTIONS)) sections -> $(COMBINED_MD)$(NC)"
	@rm -f $(COMBINED_MD)
	@first=1; \
	for f in $(ALL_SECTIONS); do \
	  if [ ! -f "$$f" ]; then \
	    echo -e "$(RED)Error: Missing section file: $$f$(NC)"; \
	    exit 1; \
	  fi; \
	  if [ $$first -eq 0 ]; then echo "\n\n<section class=\"section-break\"></section>\n" >> $(COMBINED_MD); fi; \
	  $(PYTHON) scripts/rewrite_links.py $$f >> $(COMBINED_MD) || { echo -e "$(RED)Error processing $$f$(NC)"; exit 1; }; \
	  first=0; \
	done
	@echo -e "$(GREEN)[md] Generated $(COMBINED_MD) (size: $$(wc -c < $(COMBINED_MD)) bytes) ✓$(NC)"

clean:
	@if [ -f $(COMBINED_MD) ]; then \
		rm -f $(COMBINED_MD); \
		echo -e "$(GREEN)[clean] Removed $(COMBINED_MD) ✓$(NC)"; \
	else \
		echo -e "$(YELLOW)[clean] $(COMBINED_MD) does not exist$(NC)"; \
	fi
	@if [ -f docs/00-table-of-contents.md ]; then \
		rm -f docs/00-table-of-contents.md; \
		echo -e "$(GREEN)[clean] Removed generated TOC ✓$(NC)"; \
	fi

# Build the explicit table of contents file from headings
toc: check-deps docs/00-table-of-contents.md

docs/00-table-of-contents.md: $(CONTENT_SECTIONS) scripts/gen_toc.py
	@echo -e "$(BLUE)[toc] Generating table of contents...$(NC)"
	@missing=0; \
	for f in $(CONTENT_SECTIONS); do \
	  if [ ! -f "$$f" ]; then \
	    echo -e "$(RED)Error: Missing content file: $$f$(NC)"; \
	    missing=1; \
	  fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
	  echo -e "$(RED)[toc] Cannot generate TOC due to missing files$(NC)"; \
	  exit 1; \
	fi
	@$(PYTHON) scripts/gen_toc.py $(CONTENT_SECTIONS) || { echo -e "$(RED)[toc] Failed to generate TOC$(NC)"; exit 1; }
	@echo -e "$(GREEN)[toc] Generated docs/00-table-of-contents.md ✓$(NC)"
