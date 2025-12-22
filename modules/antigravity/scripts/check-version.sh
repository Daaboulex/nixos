#!/usr/bin/env bash
# Quick version check script - shows current vs latest without updating

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Checking Antigravity versions..."

# Get current version
CURRENT=$(grep -oP 'version = "\K[^"]+' flake.nix | head -1)
echo -e "${GREEN}Current version:${NC} $CURRENT"

# Get latest version
echo "Fetching latest version from antigravity.google..."
if command -v node &>/dev/null && [[ -f "scripts/scrape-version.js" ]]; then
    if node -e "require('playwright-chromium')" 2>/dev/null; then
        LATEST=$(CHROME_BIN=${CHROME_BIN:-/run/current-system/sw/bin/google-chrome-stable} node scripts/scrape-version.js)
        if [[ -n "$LATEST" ]] && [[ "$LATEST" =~ ^[0-9.]+-[0-9]+$ ]]; then
            echo -e "${GREEN}Latest version:${NC}  $LATEST"
            
            if [[ "$CURRENT" == "$LATEST" ]]; then
                echo -e "\n${GREEN}✓ Already at latest version!${NC}"
                exit 0
            else
                echo -e "\n${YELLOW}⚠ Update available!${NC}"
                echo "  Current: $CURRENT"
                echo "  Latest:  $LATEST"
                exit 1
            fi
        else
            echo "Error: Could not parse version from scraper output"
            exit 1
        fi
    else
        echo "Error: playwright-chromium not installed"
        echo "Install with: npm install -g playwright-chromium && npx playwright install chromium"
        exit 1
    fi
else
    echo "Error: Node.js or scrape-version.js not found"
    exit 1
fi
