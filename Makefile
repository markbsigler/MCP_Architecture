# Makefile for building consolidated MCP Architecture markdown only.
# Pure shell/cat pipeline, no Python venv required.

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

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
	docs/04-testing-strategy.md \
	docs/05-observability.md \
	docs/06-development-lifecycle.md \
	docs/06a-performance-scalability.md \
	docs/07-deployment-patterns.md \
	docs/08-operational-runbooks.md \
	docs/09-integration-patterns.md \
	docs/10-agentic-best-practices.md \
	docs/11-decision-trees.md \
	docs/12-migration-guides.md \
	docs/99-quick-reference.md

# Preface sections (generated or static)
PREFIX_SECTIONS = docs/00-title-page.md docs/00-table-of-contents.md

# All sections in final order
ALL_SECTIONS = $(PREFIX_SECTIONS) $(CONTENT_SECTIONS)

COMBINED_MD := mcp-architecture.md

.PHONY: all help toc md clean

all: md

help:
	@echo "Markdown-only targets:"; \
	echo "  make toc      # Generate explicit TOC file"; \
	echo "  make md       # Concatenate sections to project root"; \
	echo "  make clean    # Remove output markdown"; \
	echo "  make lint     # Run linting and link checking";

lint:
	@echo "[lint] running link checker..."
	@python3 scripts/check_links.py || echo "Link checker failed"
	@echo "[lint] running markdownlint..."
	@npx markdownlint 'docs/**/*.md' 'README.md' 2>/dev/null || echo "markdownlint not available (run: npm install -g markdownlint-cli)"

# Generate explicit TOC before concatenating
md: toc $(COMBINED_MD)
$(COMBINED_MD): $(ALL_SECTIONS)
	@echo "[md] combining $(words $(ALL_SECTIONS)) sections -> $(COMBINED_MD)"
	@rm -f $(COMBINED_MD)
	@first=1; \
	for f in $(ALL_SECTIONS); do \
	  if [ $$first -eq 0 ]; then echo "\n\n<section class=\"section-break\"></section>\n" >> $(COMBINED_MD); fi; \
	  python3 scripts/rewrite_links.py $$f >> $(COMBINED_MD); \
	  first=0; \
	done
	@echo "[md] size: $$(wc -c < $(COMBINED_MD)) bytes"

clean:
	@rm -f $(COMBINED_MD)
	@echo "[clean] removed $(COMBINED_MD)"

# Build the explicit table of contents file from headings
toc: docs/00-table-of-contents.md

docs/00-table-of-contents.md: $(CONTENT_SECTIONS) scripts/gen_toc.py
	@echo "[toc] generating explicit TOC"
	@python3 scripts/gen_toc.py $(CONTENT_SECTIONS)
	@echo "[toc] written"
