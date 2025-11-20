#!/bin/bash
# Setup script for MCP Architecture development environment

set -e

echo "🚀 Setting up MCP Architecture development environment..."

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Install git hooks
echo -e "${BLUE}Installing git hooks...${NC}"
if [ -d ".githooks" ]; then
    git config core.hooksPath .githooks
    echo -e "${GREEN}✓ Git hooks configured to use .githooks directory${NC}"
else
    echo -e "${YELLOW}Warning: .githooks directory not found${NC}"
fi

# Check dependencies
echo -e "${BLUE}Checking dependencies...${NC}"
make check-deps || {
    echo -e "${YELLOW}Some dependencies are missing. Run 'make install-deps' to install them.${NC}"
}

# Install markdownlint if npm is available
if command -v npm &> /dev/null; then
    echo -e "${BLUE}Installing markdownlint-cli...${NC}"
    npm install -g markdownlint-cli || echo -e "${YELLOW}Warning: Failed to install markdownlint-cli${NC}"
else
    echo -e "${YELLOW}npm not found. Install Node.js to enable markdownlint checks.${NC}"
fi

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Run 'make check-deps' to verify all dependencies"
echo "  2. Run 'make lint' to check for issues"
echo "  3. Run 'make md' to build consolidated documentation"
echo ""
echo "Pre-commit hooks are now active and will run automatically before each commit."
